const std = @import("std");
const shooter = @import("shooter.zig");
const types = @import("shooter_types.zig");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
}
const Native = *const fn (usize) callconv(.c) void;
const actor: usize = 0x20000000;
const controller: usize = 0x20010000;
const model: usize = 0x20020000;
const resource: usize = 0x20030000;
const actor100: usize = 0x20040000;
const weapon: usize = 0x20050000;
var functions: [3]Native = undefined;
var throwing = false;
var calls: u32 = 0;
export fn entities_observed_generation(_: usize) u32 {
    return 7;
}
export fn entities_observed_identity(_: usize, slot: *u32, generation: *u32) c_int {
    slot.* = 2;
    generation.* = 9;
    return 1;
}
export fn game_sync_sequence() u32 {
    return 8;
}
fn nativeActor(value: usize) callconv(.c) void {
    check(@src(), value == actor);
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    win.store(u32, actor + 0x50, 91);
    win.SetLastError(321);
}
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn bytes(address: usize, value: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(address))[0..value.len], value);
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn hash(data: []const u8) u32 {
    var result: u32 = 2166136261;
    for (data) |byte| result = (result ^ byte) *% 16777619;
    return result;
}
fn run(mode: u32) void {
    shooter.clonewars_shooter_observer_enabled = @intFromBool(mode != 0);
    shooter.clonewars_shooter_observer_character = if (mode == 1) 999 else 321;
    shooter.clonewars_shooter_observer_count = 0;
    @memset(std.mem.asBytes(&shooter.clonewars_shooter_observer), 0);
    calls = 0;
    put(actor + 0x50, 31);
    if (mode < 5) {
        const kind: usize = if (mode < 3) 0 else mode - 2;
        win.SetLastError(123);
        bytes(0x1e000000, &.{ 0xff, 0x74, 0x24, 4, 0xb8 });
        put(0x1e000005, @intFromPtr(functions[kind]));
        bytes(0x1e000009, &.{ 0xff, 0xd0, 0x83, 0xc4, 4, 0xc3 });
        check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x1e000000, 15) != 0);
        @as(Native, @ptrFromInt(0x1e000000))(actor);
        check(@src(), win.GetLastError() == 321 and calls == 1);
    } else {
        var outer = std.mem.zeroes(types.Scope);
        var inner = std.mem.zeroes(types.Scope);
        check(@src(), shooter.shooter_observer_fire_begin(&outer, actor, weapon, 3, controller, model, 17) != 0);
        check(@src(), shooter.shooter_observer_fire_begin(&inner, actor, weapon, 4, model, controller, 19) != 0);
        if (mode == 6) shooter.shooter_observer_fire_abort(&inner) else shooter.shooter_observer_fire_end(&inner);
        shooter.shooter_observer_fire_end(&outer);
    }
    for (&shooter.clonewars_shooter_observer) |*r| {
        if (r.committed != 0) check(@src(), r.thread == win.GetCurrentThreadId());
        r.thread = 0;
        r.qpc_before_low = 0;
        r.qpc_before_high = 0;
        r.qpc_after_low = 0;
        r.qpc_after_high = 0;
    }
}
fn invokeThrow(_: usize) callconv(.c) c_int {
    functions[0](actor);
    return 0;
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0x9b5190 and @intFromPtr(&image) + image.len > 0xfb4b6c and @sizeOf(types.Actor) == 388 and @sizeOf(@TypeOf(shooter.clonewars_shooter_observer)) == 7176192);
    for ([_]usize{ actor, controller, model, resource, actor100, weapon }) |address| check(@src(), win.VirtualAlloc(address, if (address == actor) 0x2000 else 0x1000, 0x3000, 4) == address);
    defer for ([_]usize{ actor, controller, model, resource, actor100, weapon }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    check(@src(), win.VirtualAlloc(0x1e000000, 0x1000, 0x3000, 0x40) == 0x1e000000);
    defer _ = win.VirtualFree(0x1e000000, 0, 0x8000);
    var old: u32 = 0;
    for ([_]usize{ 0xfb0000, 0xe60000, 0xea0000 }) |address| check(@src(), win.VirtualProtect(address, 0x10000, if (address == 0x1e000000) @as(u32, 0x40) else 4, &old) != 0);
    for (0..0x1440) |i| win.store(u8, actor + i, @truncate(i));
    win.store(u16, actor + 0xdc0, 321);
    put(actor + 0x6cc, controller);
    put(actor + 8, model);
    put(actor + 0xf08, resource);
    put(actor + 0x100, actor100);
    win.store(u8, weapon, 0xf9);
    put(0xfb2f60, actor);
    put(0xfb2e3c, 1);
    put(0xfb4b6c, 31);
    put(0xe637b4, 71);
    put(0xea178c, 79);
    var snapshot: types.Actor = undefined;
    shooter.shooter_observer_actor_snapshot(&snapshot, actor);
    check(@src(), hash(std.mem.asBytes(&snapshot)) == 1947550943);
    shooter.shooter_observer_actor_snapshot(&snapshot, 0);
    check(@src(), hash(std.mem.asBytes(&snapshot)) == 2298555853);
    const addresses = [_]usize{ 0x9b5190, 0x9bb240, 0x9b5ce0 };
    for (addresses) |address| check(@src(), win.VirtualProtect(address, 64, 0x40, &old) != 0);
    bytes(addresses[0], &.{ 0x53, 0x55, 0x8b, 0x2d, 0x20, 0x4a, 0xfb, 0, 0x5d, 0x5b });
    jump(addresses[0] + 10, @intFromPtr(&nativeActor));
    bytes(addresses[1], &.{ 0x83, 0xec, 0x18, 0xd9, 0xe8, 0xdd, 0xd8, 0x83, 0xc4, 0x18 });
    jump(addresses[1] + 10, @intFromPtr(&nativeActor));
    bytes(addresses[2], &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0, 0x89, 0xec, 0x5d });
    jump(addresses[2] + 9, @intFromPtr(&nativeActor));
    check(@src(), shooter.shooter_observer_install() != 0);
    for (addresses, 0..) |address, i| functions[i] = @ptrFromInt(address +% 5 +% win.load(u32, address + 1));
    const expected = [_]u32{ 517643717, 517643717, 217635509, 876531271, 1016123556, 2286631936, 4290627497 };
    const counts = [_]u32{ 0, 0, 1, 1, 1, 2, 2 };
    for (expected, 0..) |expected_hash, mode| {
        run(@intCast(mode));
        const actual = hash(std.mem.asBytes(&shooter.clonewars_shooter_observer));
        if (actual != expected_hash) std.debug.print("shooter mode={d} hash={d} expected={d}\n", .{ mode, actual, expected_hash });
        check(@src(), actual == expected_hash and shooter.clonewars_shooter_observer_count == counts[mode]);
    }
    shooter.clonewars_shooter_observer_count = 0;
    shooter.clonewars_shooter_observer_enabled = 1;
    shooter.clonewars_shooter_observer_character = 321;
    throwing = true;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876);
    throwing = false;
    functions[0](actor);
    check(@src(), shooter.clonewars_shooter_observer_count == 2 and shooter.clonewars_shooter_observer[1].parent == 0);
}
