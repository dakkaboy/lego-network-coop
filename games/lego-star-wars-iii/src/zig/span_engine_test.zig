const std = @import("std");
const win = @import("win32.zig");
const span = @import("span_engine.zig");
const owner = @import("owner_types.zig");
const check = @import("native_test_support.zig").check;
var callbacks: owner.Callbacks = undefined;
var current: ?*owner.Scope = null;
var adapter: span.Adapter = undefined;
var rejects: u32 = 0;
var reason: u32 = 0;
var enters: u32 = 0;
var markers: u32 = 0;
var finishes: u32 = 0;
var ends: u32 = 0;
var aborted: u32 = 0;
var plan: u32 = 1;
var release: u32 = 5;
var epoch: u32 = 7;
var valid = true;
var dependencies = true;
var cancel_enter = false;
var ready_after_enter = true;
pub export fn native_owner_configure(_: usize, cb: *const owner.Callbacks) i32 {
    callbacks = cb.*;
    return 1;
}
pub export fn native_owner_current() ?*owner.Scope {
    return current;
}
pub export fn native_owner_scope_nonce(s: *owner.Scope) u32 {
    return s.nonce;
}
pub export fn native_owner_scope_valid(s: ?*owner.Scope, nonce: u32) i32 {
    return @intFromBool(valid and s != null and s == current and nonce == s.?.nonce);
}
pub export fn native_owner_scope_delegate_esp(s: *owner.Scope, _: u32) usize {
    return s.delegate_esp;
}
pub export fn native_owner_entry() void {}
pub export fn coherent_frame_release() u32 {
    return release;
}
fn reject(code: u32, _: usize) callconv(.c) void {
    rejects += 1;
    reason = code;
}
fn safe(_: usize, _: *const owner.Input, _: usize) callconv(.c) i32 {
    return 1;
}
fn ready(_: usize) callconv(.c) i32 {
    return @intFromBool(dependencies);
}
fn mainThread(_: u32, _: usize) callconv(.c) i32 {
    return 1;
}
fn control(out: *span.Control, _: usize) callconv(.c) i32 {
    out.* = .{ .epoch = epoch, .level = 2, .established = 1 };
    return 1;
}
fn enter(_: *owner.Scope, _: u32, _: usize, _: usize, _: [*]const u32, fx: usize, is_ready: u32, _: usize) callconv(.c) u32 {
    enters += 1;
    check(@src(), is_ready != 0);
    win.store(u16, fx, 0x37f);
    if (cancel_enter) span.span_engine_cancel(&adapter);
    if (!ready_after_enter) dependencies = false;
    return plan;
}
fn marker(_: *owner.Scope, _: u32, _: u32, _: usize) callconv(.c) void {
    markers += 1;
}
fn finish(_: *owner.Scope, _: u32, _: usize) callconv(.c) void {
    finishes += 1;
}
fn end(_: *owner.Scope, _: u32, _: i32, was_aborted: u32, _: usize) callconv(.c) void {
    ends += 1;
    aborted = was_aborted;
}
extern fn optional_enter([*]u32, usize) void;
extern fn main_enter([*]u32, usize) void;
fn bytes(address: usize, value: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(address))[0..value.len], value);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const mode = if (args.len > 1) try std.fmt.parseInt(u32, args[1], 10) else 0;
    const image = win.VirtualAlloc(0, 0x4000, 0x3000, 4);
    check(@src(), image != 0);
    defer check(@src(), win.VirtualFree(image, 0, 0x8000) != 0);
    bytes(image + 0x1380, &.{ 0x6a, 0xff, 0x68, 0xe0, 0xdb, 0xaa, 0 });
    bytes(image + 0x1557, &.{ 0xf6, 0x40, 0x4d, 2, 0x89, 0x6c, 0x24, 0x48 });
    bytes(image + 0x15a2, &.{ 0xe8, 0xc9, 0xec, 0xff, 0xff });
    bytes(image + 0x15bc, &.{ 0xe8, 0xbf, 0xf7, 0xff, 0xff });
    bytes(image + 0x15c1, &.{ 0x8b, 0x16, 0x8b, 0x42, 0x30 });
    var vtable: [8]usize = @splat(0);
    vtable[7] = image + 0x1380;
    var receiver: [8]usize = @splat(0);
    receiver[0] = @intFromPtr(&vtable);
    var root = @intFromPtr(&receiver);
    const cb: span.Callbacks = .{ .version = 5, .user = 0, .reject_atomic = reject, .install_safe = safe, .dependencies_ready = ready, .main_confirmed = mainThread, .control_context = control, .enter = enter, .marker = marker, .finish = finish, .end = end };
    check(@src(), span.span_engine_prepare(&adapter, image, @intFromPtr(&vtable[7]), @intFromPtr(&vtable), @intFromPtr(&root), win.GetCurrentThreadId(), 3, &cb) != 0);
    check(@src(), span.span_engine_publish_bootstrap(&adapter) == 1);
    var scope = std.mem.zeroes(owner.Scope);
    scope.nonce = 11;
    scope.delegate_active = 1;
    var storage: [80]u32 = @splat(0);
    const regs: [*]u32 = storage[20..].ptr;
    regs[0] = @intFromPtr(&receiver);
    regs[1] = regs[0];
    storage[19] = regs[0];
    regs[4] = @intFromPtr(&receiver) + 0x10;
    regs[8] = @intFromPtr(regs) + 76;
    scope.delegate_esp = @intFromPtr(regs) + 36 + 0x4c;
    var caller = [_]u32{ image + 0x3db1, 0, image + 0x3eac };
    var entry_regs: [9]u32 = @splat(0);
    entry_regs[6] = @intFromPtr(&receiver);
    var fx: [512]u8 align(16) = @splat(0);
    win.store(u16, @intFromPtr(&fx), 0x7f);
    win.store(u32, @intFromPtr(&fx) + 24, 0x1f80);
    scope.out_fx = fx;
    const input: owner.Input = .{ .fx = &fx, .regs = &entry_regs, .last_error = 0, .caller_esp = @intFromPtr(&caller) };
    if (mode == 7) caller[0] ^= 1;
    current = &scope;
    callbacks.begin.?(&scope, &input, &scope.storage);
    if (mode == 7) {
        check(@src(), span.native_span_enter(regs, @intFromPtr(&fx)) == 0);
        callbacks.end.?(&scope, 0, &scope.storage);
        check(@src(), enters == 0 and ends == 0);
        return;
    }
    check(@src(), span.span_engine_ready(&adapter) != 0);
    var lease = std.mem.zeroes(span.Lease);
    win.SetLastError(0x13579);
    check(@src(), span.span_engine_control_get(&adapter, &lease) != 0);
    check(@src(), win.GetLastError() == 0x13579 and span.span_engine_control_valid(&adapter, &lease) != 0);
    switch (mode) {
        1 => plan = 3,
        2 => cancel_enter = true,
        3 => ready_after_enter = false,
        4 => regs[1] ^= 4,
        else => {},
    }
    const entered = span.native_span_enter(regs, @intFromPtr(&fx));
    if (mode >= 1 and mode <= 4) {
        check(@src(), entered == 2);
        const expected_reason: u32 = switch (mode) {
            1 => 3,
            3 => 7,
            4 => 2,
            else => 0,
        };
        check(@src(), reason == expected_reason);
    } else {
        check(@src(), entered == 1);
        switch (mode) {
            5 => check(@src(), span.native_span_enter(regs, @intFromPtr(&fx)) == 2 and reason == 2),
            6 => {
                epoch = 8;
                check(@src(), span.span_engine_control_valid(&adapter, &lease) == 0);
                span.span_engine_cancel(&adapter);
                check(@src(), span.span_engine_control_valid(&adapter, &lease) == 0);
            },
            8 => {
                valid = false;
                check(@src(), span.span_engine_control_valid(&adapter, &lease) == 0);
            },
            9 => {
                release = 6;
                check(@src(), span.span_engine_control_valid(&adapter, &lease) == 0);
            },
            else => {
                optional_enter(storage[19..].ptr, @intFromPtr(&fx));
                main_enter(storage[18..].ptr, @intFromPtr(&fx));
                check(@src(), markers == 2 and adapter.optional_count == 1 and adapter.main_count == 1);
                span.native_span_exit(regs, @intFromPtr(&fx));
                check(@src(), finishes == 1 and win.load(u16, @intFromPtr(&fx)) == 0x7f);
            },
        }
    }
    callbacks.end.?(&scope, 0, &scope.storage);
    current = null;
    check(@src(), span.span_engine_control_valid(&adapter, &lease) == 0);
    if (mode == 0) check(@src(), ends == 1 and aborted == 0);
    if (mode == 5 or mode == 6 or mode == 8 or mode == 9) check(@src(), ends == 1 and aborted == 1);
}
