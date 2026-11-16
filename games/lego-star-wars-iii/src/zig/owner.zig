const std = @import("std");
const win = @import("win32.zig");
const root = @import("root");
const testing = if (@hasDecl(root, "owner_test_api")) root.owner_test_api else false;
const types = @import("owner_types.zig");
pub const Input = types.Input;
pub const Callbacks = types.Callbacks;
pub const Scope = types.Scope;
comptime {
    std.debug.assert(@offsetOf(Scope, "target") == 1112);
    std.debug.assert(@offsetOf(Scope, "helper_fx") == 1120);
    std.debug.assert(@offsetOf(Scope, "storage") == 1664);
    std.debug.assert(@offsetOf(Scope, "delegate_esp") == 1744);
    std.debug.assert(@offsetOf(Scope, "delegate_active") == 1748);
    std.debug.assert(@sizeOf(Scope) <= 2048 and @alignOf(Scope) == 16);
}
var configured: i32 = 0;
var disabled: u32 = 0;
var nonce: u32 = 0;
var pending_fault: u32 = 0;
var key: u32 = 0xffffffff;
var target: usize = 0;
var callbacks = std.mem.zeroes(Callbacks);
export const native_owner_default_mxcsr: u32 = 0x1f80;
var fail_set: i32 = 0;
var fail_get: i32 = 0;
var raise_after_set: i32 = 0;
fn readError() u32 {
    return asm volatile ("movl %%fs:52, %[value]"
        : [value] "=r" (-> u32),
        :
        : .{ .memory = true });
}
fn writeError(value: u32) void {
    asm volatile ("movl %[value], %%fs:52"
        :
        : [value] "r" (value),
        : .{ .memory = true });
}
noinline fn helperEnvironment() void {
    asm volatile ("fninit; ldmxcsr (%[value]); cld"
        :
        : [value] "r" (&native_owner_default_mxcsr),
        : .{ .memory = true });
}
fn disable(why: u32) void {
    @atomicStore(u32, &disabled, 1, .seq_cst);
    _ = @cmpxchgStrong(u32, &pending_fault, 0, why + 1, .seq_cst, .seq_cst);
}
fn injection(counter: *i32) bool {
    if (comptime !testing) return false;
    return @atomicLoad(i32, counter, .seq_cst) > 0 and @atomicRmw(i32, counter, .Sub, 1, .seq_cst) == 1;
}
fn checkedGet() ?*Scope {
    const value = if (injection(&fail_get)) blk: {
        win.SetLastError(87);
        break :blk 0;
    } else win.TlsGetValue(key);
    if (value == 0 and win.GetLastError() != 0) disable(1);
    return if (@atomicLoad(u32, &disabled, .seq_cst) != 0 or value == 0) null else @ptrFromInt(value);
}
fn publish(scope: ?*Scope) bool {
    if (injection(&fail_set)) return false;
    const ok = win.TlsSetValue(key, if (scope) |s| @intFromPtr(s) else 0) != 0;
    if (ok and injection(&raise_after_set)) win.RaiseException(0xe0011234, 0, 0, null);
    return ok;
}
pub export fn native_owner_configure(native: usize, cb: ?*const Callbacks) c_int {
    const saved = readError();
    defer writeError(saved);
    if (native == 0 or cb == null or cb.?.version != 1 or cb.?.begin == null or cb.?.end == null or cb.?.reject == null) return 0;
    if (@cmpxchgStrong(i32, &configured, 0, -1, .seq_cst, .seq_cst) != null) return 0;
    key = win.TlsAlloc();
    if (key == 0xffffffff) {
        @atomicStore(i32, &configured, 0, .seq_cst);
        return 0;
    }
    target = native;
    callbacks = cb.?.*;
    @atomicStore(i32, &configured, 1, .seq_cst);
    return 1;
}
pub export fn native_owner_current() ?*Scope {
    const saved = readError();
    defer writeError(saved);
    var scope: ?*Scope = null;
    if (@atomicLoad(u32, &disabled, .seq_cst) == 0 and @atomicLoad(i32, &configured, .seq_cst) == 1) scope = checkedGet();
    return if (@atomicLoad(u32, &disabled, .seq_cst) != 0) null else scope;
}
fn findLive(candidate: ?*const Scope) ?*Scope {
    var scope = native_owner_current();
    for (0..64) |_| {
        const current = scope orelse return null;
        if (current == candidate) return current;
        scope = current.parent;
    }
    return null;
}
pub export fn native_owner_scope_nonce(scope: ?*const Scope) c_uint {
    const current = findLive(scope);
    const result = if (current) |s| s.nonce else 0;
    return if (@atomicLoad(u32, &disabled, .seq_cst) != 0) 0 else result;
}
pub export fn native_owner_scope_usable(scope: ?*const Scope) c_int {
    const saved = readError();
    defer writeError(saved);
    const current = findLive(scope) orelse return 0;
    return @intFromBool(current.thread == win.GetCurrentThreadId() and current.usable != 0 and @atomicLoad(u32, &disabled, .seq_cst) == 0);
}
pub export fn native_owner_scope_valid(scope: ?*const Scope, token: c_uint) c_int {
    const saved = readError();
    defer writeError(saved);
    const current = native_owner_current() orelse return 0;
    return @intFromBool(current == scope and current.thread == win.GetCurrentThreadId() and current.usable != 0 and token != 0 and current.nonce == token and @atomicLoad(u32, &disabled, .seq_cst) == 0);
}
pub export fn native_owner_scope_delegate_esp(scope: ?*const Scope, token: c_uint) u32 {
    const saved = readError();
    defer writeError(saved);
    const current = native_owner_current() orelse return 0;
    if (current != scope or current.thread != win.GetCurrentThreadId() or current.usable == 0 or token == 0 or current.nonce != token or
        @atomicLoad(u32, &current.delegate_active, .monotonic) == 0) return 0;
    const result = current.delegate_esp;
    return if (@atomicLoad(u32, &current.delegate_active, .monotonic) == 0 or @atomicLoad(u32, &disabled, .seq_cst) != 0) 0 else result;
}
fn reject(scope: *Scope, why: c_int) void {
    scope.usable = 0;
    helperEnvironment();
    scope.callbacks.reject.?(scope, scope.parent, why, &scope.storage);
    helperEnvironment();
}
fn notify(scope: ?*Scope) bool {
    const fault = @atomicRmw(u32, &pending_fault, .Xchg, 0, .seq_cst);
    if (fault == 0) return false;
    if (scope) |s| reject(s, @intCast(fault - 1)) else {
        helperEnvironment();
        callbacks.reject.?(null, null, @intCast(fault - 1), null);
        helperEnvironment();
    }
    return true;
}
pub export fn native_owner_poll_fault() c_int {
    const saved = readError();
    var fx: [512]u8 align(16) = undefined;
    asm volatile ("fxsave (%[buffer])"
        :
        : [buffer] "r" (&fx),
        : .{ .memory = true });
    const result = notify(null);
    @import("machine_environment.zig").restoreFx(&fx);
    writeError(saved);
    return @intFromBool(result);
}
pub export fn owner_enter(scope: *Scope) void {
    scope.target = target;
    scope.callbacks = callbacks;
    scope.parent = null;
    scope.nonce = 0;
    scope.thread = win.GetCurrentThreadId();
    scope.depth = 1;
    scope.linked = 0;
    scope.usable = 0;
    scope.begin_entered = 0;
    scope.end_done = 0;
    @memset(&scope.storage, 0);
    scope.delegate_esp = 0;
    scope.delegate_active = 0;
    if (@atomicLoad(u32, &disabled, .seq_cst) != 0) {
        if (!notify(scope)) reject(scope, 1);
        return;
    }
    scope.parent = native_owner_current();
    scope.depth = if (scope.parent) |parent| parent.depth + 1 else 1;
    if (@atomicLoad(u32, &disabled, .seq_cst) != 0) {
        if (!notify(scope)) reject(scope, 1);
        return;
    }
    const next = @atomicRmw(u32, &nonce, .Add, 1, .seq_cst) +% 1;
    if (next == 0) {
        disable(2);
        _ = notify(scope);
        return;
    }
    scope.nonce = next;
    scope.linked = 1;
    if (!publish(scope)) {
        disable(1);
        _ = notify(scope);
        return;
    }
    scope.usable = @intFromBool(scope.depth <= 8);
    if (scope.usable == 0) reject(scope, 0);
    if (@atomicLoad(u32, &disabled, .seq_cst) != 0) {
        if (!notify(scope)) reject(scope, 1);
        return;
    }
    const input: Input = .{ .fx = &scope.in_fx, .regs = &scope.in_regs, .last_error = scope.in_error, .caller_esp = scope.entry_esp };
    scope.begin_entered = 1;
    helperEnvironment();
    scope.callbacks.begin.?(scope, &input, &scope.storage);
    helperEnvironment();
    _ = notify(scope);
}
pub export fn owner_leave(scope: *Scope, unwind: c_int) void {
    const saved = readError();
    defer {
        helperEnvironment();
        writeError(saved);
    }
    scope.delegate_active = 0;
    helperEnvironment();
    if (scope.end_done != 0) return;
    scope.end_done = 1;
    _ = notify(scope);
    if (scope.begin_entered != 0) {
        scope.callbacks.end.?(scope, @intFromBool(unwind != 0), &scope.storage);
        helperEnvironment();
    }
    if (scope.linked != 0) {
        if (@atomicLoad(u32, &disabled, .seq_cst) != 0 or !publish(scope.parent)) {
            disable(1);
            _ = notify(scope);
        }
        scope.linked = 0;
    }
}
fn testFailSet(value: u32) callconv(.c) void {
    @atomicStore(i32, &fail_set, @bitCast(value), .seq_cst);
}
fn testFailGet(value: u32) callconv(.c) void {
    @atomicStore(i32, &fail_get, @bitCast(value), .seq_cst);
}
fn testNonce(value: u32) callconv(.c) void {
    @atomicStore(u32, &nonce, value, .seq_cst);
}
fn testRaise(value: u32) callconv(.c) void {
    @atomicStore(i32, &raise_after_set, @bitCast(value), .seq_cst);
}
comptime {
    if (testing) {
        @export(&testFailSet, .{ .name = "native_owner_test_fail_set" });
        @export(&testFailGet, .{ .name = "native_owner_test_fail_get" });
        @export(&testNonce, .{ .name = "native_owner_test_nonce" });
        @export(&testRaise, .{ .name = "native_owner_test_raise_after_set" });
    }
}
