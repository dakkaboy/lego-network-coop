const std = @import("std");
const win = @import("win32.zig");
const owner = @import("owner_types.zig");
const installer = @import("span_installer.zig");
const numeric = @import("numeric.zig");
pub const Control = @import("span_types.zig").Control;
pub const Lease = @import("span_types.zig").Lease;
pub const Callbacks = @import("span_types.zig").Callbacks;
pub const Adapter = @import("span_types.zig").Adapter;
const State = extern struct {
    parent: ?*State,
    scope: *owner.Scope,
    receiver: usize,
    nonce: u32,
    serial: u32,
    main: u32,
    optional: u32,
    qualified: u8,
    entered: u8,
    run: u8,
    closed: u8,
    deny: u8,
    finishing: u8,
    control_release: u32,
    control: Control,
    numeric: numeric.Scope,
};
comptime {
    std.debug.assert(@sizeOf(State) <= 64);
}
extern fn native_owner_scope_nonce(*owner.Scope) u32;
extern fn native_owner_scope_valid(?*owner.Scope, u32) c_int;
extern fn native_owner_scope_delegate_esp(*owner.Scope, u32) usize;
extern fn native_owner_current() ?*owner.Scope;
extern fn native_owner_configure(usize, *const owner.Callbacks) c_int;
extern fn native_owner_entry() void;
extern fn coherent_frame_release() u32;
var adapter: ?*Adapter = null;
threadlocal var top: ?*State = null;
pub export var native_span_run_resume: usize = 0;
pub export var native_span_skip_target: usize = 0;
pub export var native_span_exit_resume: usize = 0;
pub export var optional_target: usize = 0;
pub export var main_target: usize = 0;
fn va(offset: usize) usize {
    return adapter.?.image760000 + offset;
}
fn increment(value: *i32) void {
    _ = @atomicRmw(i32, value, .Add, 1, .seq_cst);
}
fn serialRead() u32 {
    return @bitCast(@atomicLoad(i32, &adapter.?.serial, .seq_cst));
}
fn revoke(reason: u32, sticky: bool) void {
    const a = adapter.?;
    var exhausted = false;
    while (true) {
        const old = serialRead();
        if (old == 0xffffffff) {
            exhausted = true;
            break;
        }
        const next = old + 1;
        exhausted = next == 0xffffffff;
        if (@cmpxchgStrong(i32, &a.serial, @bitCast(old), @bitCast(next), .seq_cst, .seq_cst) == null) break;
    }
    if (sticky or exhausted) @atomicStore(i32, &a.sticky, 1, .seq_cst);
    increment(&a.rejected);
    a.callbacks.reject_atomic.?(reason, a.callbacks.user);
    if (exhausted and reason != 4) a.callbacks.reject_atomic.?(4, a.callbacks.user);
}
fn outerQualified(input: *const owner.Input) bool {
    const a = adapter.?;
    const stack = input.caller_esp;
    const receiver = input.regs[6];
    return win.GetCurrentThreadId() == a.window_thread and win.accessible(stack, 12, false) and win.load(usize, stack) == va(0x3db1) and
        win.load(usize, stack + 8) == va(0x3eac) and win.accessible(a.root_global, 4, false) and win.load(usize, a.root_global) == receiver and
        win.accessible(receiver, 4, false) and win.load(usize, receiver) == a.expected_vt;
}
fn begin(scope: *owner.Scope, input: *const owner.Input, storage: ?*anyopaque) callconv(.c) void {
    const p: *State = @ptrCast(@alignCast(storage.?));
    const a = adapter.?;
    p.* = std.mem.zeroes(State);
    p.parent = top;
    p.scope = scope;
    p.nonce = native_owner_scope_nonce(scope);
    p.serial = serialRead();
    p.qualified = @intFromBool(outerQualified(input));
    p.deny = @intFromBool(top != null);
    if (p.deny != 0) revoke(1, false);
    p.receiver = input.regs[6];
    top = p;
    if (p.nonce == 0 or native_owner_scope_valid(scope, p.nonce) == 0) {
        p.deny = 1;
        revoke(6, true);
        return;
    }
    if (p.qualified == 0 or p.deny != 0) {
        increment(&a.unowned);
        return;
    }
    increment(&a.qualified);
    p.control_release = coherent_frame_release();
    if (a.callbacks.control_context.?(&p.control, a.callbacks.user) == 0 or p.control_release != coherent_frame_release()) p.control.established = 0;
    var q: installer.Qualification = .{ .generation = a.installer.generation, .thread = win.GetCurrentThreadId(), .caller_verified = 1, .quiescent = 0, .owner_configured = 1, .main_confirmed = 0 };
    if (a.callbacks.install_safe.?(input.regs[6], input, a.callbacks.user) != 0) {
        q.quiescent = 1;
        if (installer.span_installer_code(&a.installer, &q) == 1) {
            if (a.sticky == 0 and a.callbacks.dependencies_ready.?(a.callbacks.user) != 0 and a.callbacks.main_confirmed.?(win.GetCurrentThreadId(), a.callbacks.user) != 0) {
                q.main_confirmed = 1;
                _ = installer.span_installer_confirm(&a.installer, &q);
            } else @atomicStore(i32, &a.installer.ready, 0, .seq_cst);
        }
    }
}
fn end(scope: *owner.Scope, exit: c_int, storage: ?*anyopaque) callconv(.c) void {
    const p: *State = @ptrCast(@alignCast(storage.?));
    const a = adapter.?;
    numeric.restore(&p.numeric, @intFromPtr(&scope.out_fx));
    if (top == p) top = p.parent;
    if (p.entered != 0) a.callbacks.end.?(scope, p.nonce, exit, @intFromBool(p.serial != serialRead() or (p.run != 0 and p.closed == 0) or p.finishing != 0), a.callbacks.user);
}
fn reject(_: ?*owner.Scope, _: ?*owner.Scope, reason: c_int, _: ?*anyopaque) callconv(.c) void {
    revoke(16 + @as(u32, @intCast(reason)), true);
}
fn activeParent() bool {
    var cursor = top;
    while (cursor) |p| : (cursor = p.parent) {
        if ((p.entered != 0 and p.closed == 0) or p.finishing != 0) return true;
    }
    return false;
}
fn bound(stack: usize) ?*State {
    const p = top orelse return null;
    const s = native_owner_current();
    if (s != p.scope or p.qualified == 0 or p.serial != serialRead() or native_owner_scope_valid(s, p.nonce) == 0) return null;
    const delegate = native_owner_scope_delegate_esp(p.scope, p.nonce);
    if (delegate == 0 or stack != delegate -% 0x4c) {
        increment(&adapter.?.bad_stack);
        return null;
    }
    return p;
}
pub export fn native_span_enter(registers: [*]u32, fx: usize) u32 {
    const a = adapter.?;
    if (top != null and top.?.deny != 0) return 2;
    const p = bound(@intFromPtr(registers) + 36) orelse {
        if (activeParent()) {
            revoke(2, false);
            return 2;
        }
        if (top) |parent| if (parent.qualified != 0) {
            if (parent.serial != serialRead()) return 2;
            const s = native_owner_current();
            if (s == parent.scope and native_owner_scope_valid(s, parent.nonce) != 0) {
                revoke(2, false);
                return 2;
            }
            revoke(6, true);
            return 2;
        };
        return 0;
    };
    if (registers[1] != p.receiver) {
        increment(&a.bad_stack);
        revoke(2, false);
        return 2;
    }
    if (a.sticky != 0) return 2;
    if (p.entered != 0) {
        increment(&a.duplicates);
        revoke(2, false);
        return 2;
    }
    const ready = span_engine_ready(a);
    p.entered = 1;
    const local_numeric = numeric.read(fx);
    var plan = a.callbacks.enter.?(p.scope, p.nonce, @intFromPtr(registers) + 36 + 0x28, registers[1], registers, fx, @intCast(ready), a.callbacks.user);
    numeric.borrow(&p.numeric, local_numeric, fx);
    if (plan > 2) {
        increment(&a.invalid_plan);
        revoke(3, false);
        plan = 2;
    }
    if (plan == 1 and (ready == 0 or span_engine_ready(a) == 0)) {
        revoke(7, false);
        plan = 2;
    }
    if (p.serial != serialRead() or native_owner_scope_valid(p.scope, p.nonce) == 0) {
        p.closed = 1;
        numeric.restore(&p.numeric, fx);
        return 2;
    }
    p.run = @intFromBool(plan == 1);
    p.closed = @intFromBool(plan != 1);
    if (p.run == 0) numeric.restore(&p.numeric, fx);
    return plan;
}
pub export fn native_span_exit(registers: [*]u32, fx: usize) void {
    const p = bound(@intFromPtr(registers) + 36) orelse return;
    if (registers[1] != p.receiver) {
        increment(&adapter.?.bad_stack);
        revoke(5, false);
        return;
    }
    if (p.run != 0 and p.closed == 0) {
        p.closed = 1;
        p.finishing = 1;
        adapter.?.callbacks.finish.?(p.scope, p.nonce, adapter.?.callbacks.user);
        numeric.restore(&p.numeric, fx);
        p.finishing = 0;
    }
}
fn marker(registers: [*]u32, kind: u32, pushed: u32) void {
    const p = bound(@intFromPtr(registers) + 36 + 4 + pushed) orelse return;
    const a = adapter.?;
    if (registers[1] != p.receiver) {
        increment(&a.bad_stack);
        revoke(5, false);
        return;
    }
    if (kind == 1 and (win.load(u32, @intFromPtr(registers) + 40) != @intFromPtr(registers) + 44 + 0x28 or registers[6] != p.receiver + 0x10)) {
        increment(&a.bad_stack);
        revoke(5, false);
        return;
    }
    if (p.run != 0 and p.closed == 0) {
        if (kind == 1) {
            p.main += 1;
            increment(&a.main_count);
        } else {
            p.optional += 1;
            increment(&a.optional_count);
        }
        a.callbacks.marker.?(p.scope, p.nonce, kind, a.callbacks.user);
    }
}
export fn optional_enter(registers: [*]u32, _: usize) void {
    marker(registers, 2, 0);
}
export fn main_enter(registers: [*]u32, _: usize) void {
    marker(registers, 1, 4);
}
extern fn span_entry_thunk() void;
extern fn span_exit_thunk() void;
extern fn span_optional_thunk() void;
extern fn span_main_thunk() void;
fn patch(p: *installer.Patch, address: usize, original: []const u8, target: usize, opcode: u8) void {
    p.address = address;
    p.length = @intCast(original.len);
    @memcpy(p.original[0..original.len], original);
    @memset(p.replacement[0..original.len], 0x90);
    p.replacement[0] = opcode;
    std.mem.writeInt(u32, p.replacement[1..5], @truncate(target -% address -% 5), .little);
}
pub export fn span_engine_prepare(output: ?*Adapter, image: usize, slot: usize, vt: usize, global: usize, main: u32, generation: u32, cb: ?*const Callbacks) c_int {
    const a = output orelse return 0;
    const callbacks = cb orelse return 0;
    if (adapter != null or image == 0 or slot == 0 or vt == 0 or global == 0 or main == 0 or generation == 0 or callbacks.version != 5) return 0;
    inline for (@typeInfo(Callbacks).@"struct".field_names[2..]) |field| if (@field(callbacks, field) == null) return 0;
    const prefix = "\x6a\xff\x68\xe0\xdb\xaa\x00";
    if (slot != vt + 0x1c or !win.accessible(image + 0x1380, 7, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(image + 0x1380))[0..7], prefix)) return 0;
    a.* = std.mem.zeroes(Adapter);
    a.callbacks = callbacks.*;
    a.image760000 = image;
    a.expected_vt = vt;
    a.root_global = global;
    a.window_thread = main;
    a.serial = 1;
    const s = &a.installer;
    s.slot = slot;
    s.original_target = image + 0x1380;
    s.owner_target = @intFromPtr(&native_owner_entry);
    s.code_page = image + 0x1000;
    s.code_size = 0x1000;
    s.forbidden = image + 0x1380;
    s.forbidden_size = 7;
    s.main_thread = main;
    s.generation = generation;
    patch(&s.sites[0], image + 0x1557, "\xf6\x40\x4d\x02\x89\x6c\x24\x48", @intFromPtr(&span_entry_thunk), 0xe9);
    patch(&s.sites[1], image + 0x15a2, "\xe8\xc9\xec\xff\xff", @intFromPtr(&span_optional_thunk), 0xe8);
    patch(&s.sites[2], image + 0x15bc, "\xe8\xbf\xf7\xff\xff", @intFromPtr(&span_main_thunk), 0xe8);
    patch(&s.sites[3], image + 0x15c1, "\x8b\x16\x8b\x42\x30", @intFromPtr(&span_exit_thunk), 0xe9);
    native_span_run_resume = image + 0x155f;
    native_span_skip_target = image + 0x15c1;
    native_span_exit_resume = image + 0x15c6;
    optional_target = image + 0x270;
    main_target = image + 0xd80;
    const owner_callbacks: owner.Callbacks = .{ .version = 1, .begin = begin, .end = end, .reject = reject };
    if (native_owner_configure(s.original_target, &owner_callbacks) == 0) return 0;
    adapter = a;
    return 1;
}
pub export fn span_engine_publish_bootstrap(a: ?*Adapter) c_int {
    return if (a != null and a == adapter) installer.span_installer_bootstrap(&a.?.installer, 1) else -1;
}
pub export fn span_engine_cancel(value: ?*Adapter) void {
    const a = value orelse return;
    if (a != adapter) return;
    while (true) {
        const old = serialRead();
        if (old == 0xffffffff) {
            revoke(4, true);
            return;
        }
        const next = old + 1;
        if (@cmpxchgStrong(i32, &a.serial, @bitCast(old), @bitCast(next), .seq_cst, .seq_cst) != null) continue;
        if (next == 0xffffffff) {
            @atomicStore(i32, &a.sticky, 1, .seq_cst);
            increment(&a.rejected);
            a.callbacks.reject_atomic.?(4, a.callbacks.user);
        }
        return;
    }
}
pub export fn span_engine_ready(value: ?*Adapter) c_int {
    const a = value orelse return 0;
    return @intFromBool(a == adapter and @atomicLoad(i32, &a.sticky, .seq_cst) == 0 and @atomicLoad(i32, &a.installer.ready, .seq_cst) != 0 and a.callbacks.dependencies_ready.?(a.callbacks.user) != 0 and a.callbacks.main_confirmed.?(win.GetCurrentThreadId(), a.callbacks.user) != 0);
}
fn controlBinding(output: *Lease) bool {
    const p = top orelse return false;
    const a = adapter.?;
    if (p.qualified == 0 or p.deny != 0 or a.sticky != 0 or win.GetCurrentThreadId() != a.window_thread or p.serial != serialRead()) return false;
    const s = native_owner_current();
    if (s != p.scope or native_owner_scope_valid(s, p.nonce) == 0) return false;
    const delegate = native_owner_scope_delegate_esp(p.scope, p.nonce);
    if (delegate == 0 or a.callbacks.main_confirmed.?(win.GetCurrentThreadId(), a.callbacks.user) == 0) return false;
    const release = p.control_release;
    if (release == 0 or release == 0xffffffff or coherent_frame_release() != release or p.control.established != 1) return false;
    var first = std.mem.zeroes(Control);
    var second = std.mem.zeroes(Control);
    if (a.callbacks.control_context.?(&first, a.callbacks.user) == 0 or first.established != 1 or first.epoch == 0 or first.epoch != p.control.epoch or first.level != p.control.level or first.established != p.control.established or first.level < 0 or first.level >= 4096) return false;
    const value: Lease = .{ .owner = s, .owner_nonce = p.nonce, .thread = win.GetCurrentThreadId(), .root_serial = p.serial, .release = release, .epoch = first.epoch, .level = first.level, .delegate_esp = delegate };
    if (!bindingLive(p, delegate, release)) return false;
    if (a.callbacks.control_context.?(&second, a.callbacks.user) == 0 or first.epoch != second.epoch or first.level != second.level or first.established != second.established or !bindingLive(p, delegate, release)) return false;
    output.* = value;
    return true;
}
fn bindingLive(p: *State, delegate: usize, release: u32) bool {
    return native_owner_scope_valid(p.scope, p.nonce) != 0 and native_owner_scope_delegate_esp(p.scope, p.nonce) == delegate and adapter.?.sticky == 0 and top == p and p.serial == serialRead() and coherent_frame_release() == release;
}
pub export fn span_engine_control_get(a: ?*Adapter, output: ?*Lease) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const out = output orelse return 0;
    var value: Lease = undefined;
    if (a == null or a != adapter or !controlBinding(&value)) return 0;
    out.* = value;
    return 1;
}
pub export fn span_engine_control_valid(a: ?*Adapter, lease: ?*const Lease) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const expected = lease orelse return 0;
    var value: Lease = undefined;
    if (a == null or a != adapter or !controlBinding(&value)) return 0;
    return @intFromBool(@import("validation.zig").equal(expected, &value));
}
comptime {
    _ = @import("span_asm.zig");
}
