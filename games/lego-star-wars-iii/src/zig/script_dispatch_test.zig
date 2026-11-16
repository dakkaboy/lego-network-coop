const std = @import("std");
const win = @import("win32.zig");
const dispatch = @import("script_shoot_dispatch.zig");
const Source = @import("script_shoot_types.zig").Dispatch;
const Binding = extern struct { words: [32]usize };
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
var active: i32 = 1;
var admission: i32 = 1;
var bound: i32 = 1;
var valid: i32 = 1;
var fresh: i32 = 1;
var matching: i32 = 1;
var invalid_reason: u32 = 0;
var original_calls: u32 = 0;
var probes: u32 = 0;
var consumes: u32 = 0;
var nesting: u32 = 0;
var throw_original = false;
var throw_begin = false;
var nested = false;
var second_consume = false;
var canonical: u32 = 1;
var model: [0x50]u8 = @splat(0);
var state: [0x20]u8 = @splat(0);
var descriptor: [0x14]u8 = @splat(0);
var handler: [8]u8 = @splat(0);
pub export fn cadence_script_shoot_dispatch_active() i32 {
    return active;
}
pub export fn cadence_script_shoot_dispatch_begin(s: ?*const Source, _: u32, out: *u32, _: *Binding) i32 {
    if (s == null) {
        probes += 1;
        return -1;
    }
    if (throw_begin) win.RaiseException(0xe1357911, 0, 0, null);
    out.* = canonical;
    return bound;
}
pub export fn cadence_script_shoot_dispatch_validate(_: *const Source, _: *const Binding) i32 {
    return valid;
}
pub export fn cadence_script_shoot_dispatch_invalid(_: ?*const Source, _: ?*const Binding, reason: u32) void {
    invalid_reason = reason;
}
pub export fn native_script_shoot_dispatch_initial_admission(_: usize) i32 {
    return admission;
}
pub export fn native_script_shoot_dispatch_source_resolve(_: usize, _: usize, out: *Source) i32 {
    out.* = std.mem.zeroes(Source);
    out.model = @intFromPtr(&model);
    return fresh;
}
pub export fn native_script_shoot_dispatch_source_revalidate(_: *const Source) i32 {
    return fresh;
}
pub export fn native_script_shoot_dispatch_frame_matches(_: *const Source, _: usize, _: usize, _: usize, _: usize) i32 {
    return matching;
}
fn original(a: u32, b: u32, c: u32, d: u32, e: u32, f: u32, g: u32) callconv(.winapi) u32 {
    check(@src(), a == 11 and b == @intFromPtr(&state) and c == 13 and d == 14 and e == 15 and f == 16 and g == 17);
    original_calls += 1;
    if (throw_original) win.RaiseException(0xe1357911, 0, 0, null);
    if (nested and nesting == 0) {
        nesting += 1;
        run();
        nesting -= 1;
    }
    win.SetLastError(0xa1b2c3d4);
    const value = dispatch.native_script_shoot_dispatch_consume(0, 0, @intFromPtr(&model), 0, 1);
    check(@src(), win.GetLastError() == 0xa1b2c3d4);
    consumes += 1;
    if (active != 0 and admission > 0 and bound == 1 and valid > 0 and fresh != 0 and canonical <= 1 and matching != 0) check(@src(), value == canonical);
    if (second_consume) {
        check(@src(), dispatch.native_script_shoot_dispatch_consume(0, 0, @intFromPtr(&model), 0, 1) == 0);
        check(@src(), invalid_reason == 4);
    }
    return 0x87654321;
}
extern fn script_shoot_dispatch_run(*dispatch.Machine) void;
const Stack = extern struct { registers: [9]u32, words: [8]u32 };
fn run() void {
    var stack = std.mem.zeroes(Stack);
    stack.registers[6] = @intFromPtr(&descriptor);
    stack.registers[8] = 0x202;
    stack.words = .{ 0, 11, @intFromPtr(&state), 13, 14, 15, 16, 17 };
    var machine = std.mem.zeroes(dispatch.Machine);
    machine.registers = &stack.registers;
    machine.last_error = 0x11223344;
    asm volatile ("fxsave (%[fx])"
        :
        : [fx] "r" (&machine.fx),
        : .{ .memory = true });
    script_shoot_dispatch_run(&machine);
    check(@src(), stack.registers[7] == 0x87654321 and machine.last_error == 0xa1b2c3d4);
}
fn throwing(_: usize) callconv(.c) i32 {
    run();
    return 0;
}
pub fn main() void {
    win.store(usize, @intFromPtr(&descriptor) + 0x10, @intFromPtr(&handler));
    win.store(u32, @intFromPtr(&handler) + 4, 0x963520);
    model[0x42] = 1;
    dispatch.script_shoot_dispatch_original = @intFromPtr(&original);
    run();
    check(@src(), original_calls == 1 and consumes == 1 and invalid_reason == 0);
    canonical = 0;
    run();
    canonical = 1;
    second_consume = true;
    run();
    second_consume = false;
    invalid_reason = 0;
    nested = true;
    run();
    nested = false;
    check(@src(), invalid_reason == 0);
    active = 0;
    run();
    active = 1;
    admission = 0;
    run();
    admission = 1;
    for (0..5) |mode| {
        invalid_reason = 0;
        switch (mode) {
            0 => admission = -1,
            1 => fresh = 0,
            2 => canonical = 2,
            3 => valid = -1,
            4 => matching = 0,
            else => unreachable,
        }
        run();
        const expected_reason: u32 = if (mode <= 1) 1 else if (mode == 4) 4 else 2;
        check(@src(), invalid_reason == expected_reason);
        admission = 1;
        fresh = 1;
        canonical = 1;
        valid = 1;
        matching = 1;
    }
    for (0..2) |mode| {
        throw_original = mode == 0;
        throw_begin = mode == 1;
        check(@src(), support.exceptionCode(0, throwing) == 0xe1357911);
        throw_original = false;
        throw_begin = false;
        const before = probes;
        check(@src(), dispatch.native_script_shoot_dispatch_consume(0, 0, 0, 0, 1) == 0);
        check(@src(), probes == before + 1);
        run();
    }
}
