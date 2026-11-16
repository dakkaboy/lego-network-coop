const std = @import("std");
const decision = @import("decision.zig");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
}
const Attack = *const fn (usize, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) u8;
const pool: usize = 0x20000000;
const held: usize = 0x20010000;
const weapon: usize = 0x20020000;
const definition: usize = 0x20030000;
const pending: usize = 0x20040000;
const controller: usize = 0x20050000;
const effective: usize = 0x20060000;
const checkpoint_args: *[2]u32 = @ptrFromInt(0x20070000);
const checkpoint_regs: *[8]u32 = @ptrFromInt(0x20080000);
var attack: Attack = undefined;
var throwing = false;
var mode: u32 = 0;
var calls: u32 = 0;
var depth: u32 = 0;
export fn game_sync_sequence() u32 {
    return 8;
}
export fn entities_observed_generation(_: usize) u32 {
    return 7;
}
export fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    slot.* = if (mode == 4) std.math.maxInt(u32) else 7;
    generation.* = 9;
    return @intFromBool(actor != 0);
}
export fn shooter_observer_actor_snapshot(out: *@import("shooter_types.zig").Actor, actor: usize) void {
    out.* = std.mem.zeroes(@TypeOf(out.*));
    out.valid = 1;
    out.pointer_local = @intCast(actor);
    out.raw_slot = 0;
    out.network_slot = 7;
    out.network_generation = 9;
    out.character = 321;
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
fn nativeActor(actor: usize) callconv(.c) void {
    check(@src(), actor == pool);
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    win.SetLastError(321);
}
fn nativeAttack(context: usize, a0: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), context == controller);
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    for ([_]u32{ 0x878dc1, 0x878e02, 0x8770ca, 0x8789b9, 0x87844e, 0x878472, 0x876000 }) |site| {
        checkpoint_args.* = .{ if (site == 0x878dc1) held else a0, 71 };
        checkpoint_regs.* = .{ 11, 13, controller, 17, a0, 19, 23, 29 };
        decision.decision_observer_checkpoint(@intFromPtr(checkpoint_args), 9, site, @intFromPtr(checkpoint_regs));
    }
    if (mode == 11 and depth == 0) {
        depth += 1;
        _ = @as(Attack, @ptrFromInt(0x600000))(context, a0, 1, 2, 3, 4, 5, 6, 7, 8, 9);
        depth -= 1;
    }
    win.SetLastError(321);
    return 9;
}
fn setup() void {
    calls = 0;
    depth = 0;
    @memset(@as([*]u8, @ptrFromInt(pool))[0..0x4000], 0);
    put(0xfb2f60, pool);
    put(0xfb2e3c, 2);
    win.store(u16, pool + 0xdc0, 321);
    win.store(u16, pool + 0x1440 + 0xdc0, 33);
    put(pool + 0x2bc, pool + 0x1440);
    put(pool + 0xbdc, if (mode == 8) 1 else pool);
    put(pool + 0x528, if (mode == 7) 1 else held);
    put(pool + 0x142c, if (mode == 9) 1 else pending);
    put(held + 8, weapon);
    put(weapon + 0xac, definition);
    win.store(u8, held + 0x48, 3);
    put(controller + 0xc, effective);
    win.store(f32, effective + 0x28, 0.5);
    put(0xfb4b6c, 31);
    put(0xe637b4, 71);
    put(0xea178c, 79);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(0xe65000, 0x1000, if (mode == 10) 1 else 4, &old) != 0);
}
const Snapshot = extern struct { count: u32, calls: u32, err: u32, result: u8, records: [20][1364]u8 };
fn run(out: *Snapshot) void {
    setup();
    for (0..10) |i| bytes(0x600000 + i * 4, &.{ 0xff, 0x74, 0x24, 0x28 });
    win.store(u8, 0x600028, 0xb8);
    put(0x600029, @intFromPtr(attack));
    bytes(0x60002d, &.{ 0xff, 0xd0, 0xc2, 0x28, 0 });
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x600000, 50) != 0);
    decision.clonewars_decision_observer_count = 0;
    decision.clonewars_decision_observer_enabled = @intFromBool(mode != 0);
    decision.clonewars_decision_observer_slot = if (mode == 1) 8 else if (mode == 4) 0 else 7;
    decision.clonewars_decision_observer_character = if (mode == 2) 33 else 321;
    @memset(std.mem.asBytes(&decision.clonewars_decision_observer)[0 .. 20 * 1364], 0);
    @memset(std.mem.asBytes(out), 0);
    win.SetLastError(1234);
    if (mode == 5) decision.decision_observer_invoke_actor(2, pool, @ptrFromInt(0x600100), 0x9b5190) else out.result = @as(Attack, @ptrFromInt(0x600000))(controller, if (mode == 3) 1 else pool, 1, 2, 3, 4, 5, 6, 7, 8, 9);
    out.err = win.GetLastError();
    out.count = decision.clonewars_decision_observer_count;
    out.calls = calls;
    check(@src(), out.count <= 20);
    @memcpy(std.mem.asBytes(&out.records), std.mem.asBytes(&decision.clonewars_decision_observer)[0 .. 20 * 1364]);
    for (&out.records, 0..) |*record, i| {
        if (i < out.count) check(@src(), std.mem.readInt(u32, record[16..20], .little) == win.GetCurrentThreadId());
        @memset(record[16..20], 0);
        @memset(record[28..44], 0);
    }
}
fn invokeThrow(_: usize) callconv(.c) c_int {
    decision.decision_observer_invoke_actor(2, pool, @ptrFromInt(0x600100), 19);
    return 0;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 27296 and @sizeOf(@TypeOf(decision.clonewars_decision_observer[0])) == 1364 and @intFromPtr(&image) < 0x876a50 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ pool, held, weapon, definition, pending, controller, effective, 0x20070000, 0x20080000 }) |address| check(@src(), win.VirtualAlloc(address, if (address == pool) 0x4000 else 0x1000, 0x3000, 4) == address);
    defer for ([_]usize{ pool, held, weapon, definition, pending, controller, effective, 0x20070000, 0x20080000 }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    var old: u32 = 0;
    for ([_]usize{ 0x600000, 0x870000, 0xfb0000, 0xe60000, 0xea0000 }) |address| check(@src(), win.VirtualProtect(address, 0x10000, if (address == 0x600000 or address == 0x870000) @as(u32, 0x40) else 4, &old) != 0);
    jump(0x600100, @intFromPtr(&nativeActor));
    const sites = [_]usize{ 0x876a50, 0x878dc1, 0x878e02, 0x8770ca, 0x8789b9, 0x87844e, 0x878472 };
    const targets = [_]usize{ 0, 0x79d150, 0x7b0390, 0x7c7a70, 0x7c7a70, 0, 0x88a120 };
    const prefixes = [_][]const u8{ "\x55\x8b\xec\x83\xe4\xf0", "\x83\xc4\x04\x85\xc0", "\x83\xc4\x08\x85\xc0", "\x83\xc4\x04\x84\xc0", "\x83\xc4\x04\x84\xc0", "\xf6\x83\x00\x03\x00\x00\x08", "\x83\xc4\x08\x83\xf8\x02" };
    for (sites, targets, prefixes) |site, target, prefix| {
        bytes(site, prefix);
        if (target != 0) {
            win.store(u8, site - 5, 0xe8);
            put(site - 4, target -% site);
        }
    }
    bytes(sites[0] + 6, &.{ 0x89, 0xec, 0x5d });
    jump(sites[0] + 9, @intFromPtr(&nativeAttack));
    check(@src(), decision.decision_observer_install() != 0);
    attack = @ptrFromInt(sites[0] +% 5 +% win.load(u32, sites[0] + 1));
    const expected = [_]u32{ 3741691395, 3741691395, 3741691395, 3741691395, 3309408673, 1551830940, 3670677857, 4007309175, 1127986377, 346199777, 1279079541, 3205452999 };
    const out = std.heap.c_allocator.create(Snapshot) catch @panic("allocation failed");
    defer std.heap.c_allocator.destroy(out);
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        run(out);
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("decision mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
    }
    mode = 5;
    setup();
    decision.clonewars_decision_observer_enabled = 1;
    decision.clonewars_decision_observer_slot = 7;
    decision.clonewars_decision_observer_character = 321;
    decision.clonewars_decision_observer_count = 0;
    throwing = true;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876);
    throwing = false;
    decision.decision_observer_invoke_actor(2, pool, @ptrFromInt(0x600100), 23);
    check(@src(), decision.clonewars_decision_observer[1].parent == 0);
}
