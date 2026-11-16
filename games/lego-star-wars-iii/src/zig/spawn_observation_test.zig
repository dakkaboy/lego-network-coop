const std = @import("std");
const obs = @import("spawn_observation.zig");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
const p = @import("protocol.zig");
const Identity = @import("entity_types.zig").SpawnIdentity;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
}
const Birth = *const fn (u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32) callconv(.c) usize;
const Produce = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) u32;
const Child = *const fn (usize, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Pair = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
const Gun = *const fn (usize, usize, usize, u32) callconv(.{ .x86_thiscall = .{} }) usize;
const Crew = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) u32;
const Group = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) u8;
const Constructor = *const fn (usize, u32, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) usize;
const Order = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) void;
const pool: usize = 0x20000000;
const producer: usize = 0x20010000;
const entry: usize = 0x20020000;
const recipe: usize = 0x20030000;
const area: usize = 0x20040000;
const flow: usize = 0x20050000;
const definition: usize = 0x20060000;
const order: usize = 0x20070000;
const team: usize = 0x20080000;
const descriptor: usize = 0x20090000;
const group_manager: usize = 0x200a0000;
const bank: usize = 0x200b0000;
const position: usize = 0x200c0000;
const group: usize = group_manager + 0x16e0;
var hooks: [10]usize = @splat(0);
var mode: u32 = 0;
var births: usize = 0;
var noted: usize = 0;
var throwing = false;
var context: Identity = undefined;
var seen: [8]Identity = undefined;
const Note = extern struct { actor: usize, site: u32, source: p.SyncSpawnSource };
var notes: [8]Note = undefined;
export fn game_sync_epoch() u32 {
    return 7;
}
export fn entities_observed_generation(actor: usize) u32 {
    return if (actor != 0) 9 else 0;
}
export fn entities_set_spawn_context(value: Identity) Identity {
    const previous = context;
    context = value;
    return previous;
}
export fn entities_spawn_source(owner: usize, site: *u32) p.SyncSpawnSource {
    if (owner == 0) {
        site.* = 0;
        return .{ .producer = 0, .serial = 0 };
    }
    site.* = if (mode == 16) 0x20001234 else 0x1234;
    return .{ .producer = 31, .serial = if (mode == 15) 0x40000000 else 7 };
}
export fn entities_note_spawn_source(actor: usize, site: u32, source: p.SyncSpawnSource) void {
    check(@src(), noted < notes.len);
    notes[noted] = .{ .actor = actor, .site = site, .source = source };
    noted += 1;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, value: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(address))[0..value.len], value);
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn birthAt(caller: usize, party: u32) usize {
    const start = caller - 53;
    for (0..12) |i| bytes(start + i * 4, &.{ 0xff, 0x74, 0x24, 0x30 });
    win.store(u8, caller - 5, 0xe8);
    put(caller - 4, hooks[0] -% caller);
    bytes(caller, &.{ 0x83, 0xc4, 0x30, 0xc3 });
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), start, 57) != 0);
    return @as(Birth, @ptrFromInt(start))(1, position, 2, recipe, 4, 5, 6, 7, 8, 9, 10, party);
}
fn nativeBirth(_: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) usize {
    check(@src(), births < seen.len);
    seen[births] = context;
    births += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    win.SetLastError(321);
    return pool;
}
fn nativeChild(object: usize, _: u32, _: u32, _: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), object == producer);
    _ = birthAt(0x4e2788, 3);
    put(producer + 0x374, 8);
}
fn nativeProduce(object: usize, count: u32, initial: u32) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), object == producer and count == 2 and initial == 1);
    @as(Child, @ptrFromInt(0x1e000200))(object, position, 71, 79);
    return 91;
}
fn nativePair(object: usize, _: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), object == producer);
    _ = birthAt(0x4e63bd, 3);
}
fn nativeGun(_: usize, _: usize, gun: usize, socket: u32) callconv(.{ .x86_thiscall = .{} }) usize {
    check(@src(), gun == pool and socket == 10);
    return pool;
}
fn nativeMount(rider: usize) callconv(.c) void {
    check(@src(), rider == pool);
    _ = birthAt(0x4df59a, 3);
}
fn nativeCrew(_: usize, vehicle: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), vehicle == pool);
    _ = birthAt(0x47e3df, 3);
    return 1;
}
fn nativeConstructor(object: usize, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.{ .x86_thiscall = .{} }) usize {
    check(@src(), object == order);
    return order;
}
fn nativeOrder(object: usize, _: u32, _: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), object == order);
    _ = birthAt(0x5501f4, 3);
}
fn nativeGroup(object: usize, _: u32) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), object == group);
    _ = birthAt(0x4cb8c1, 3);
    return 1;
}
fn setup() void {
    births = 0;
    noted = 0;
    seen = std.mem.zeroes(@TypeOf(seen));
    notes = std.mem.zeroes(@TypeOf(notes));
    context = .{ .site = 77, .source = .{ .producer = 79, .serial = 83 } };
    @memset(@as([*]u8, @ptrFromInt(producer))[0..0x1000], 0);
    const fields = [_][2]u32{
        .{ producer, if (mode == 6 or mode == 13) 0xae3c44 else 0xae60c4 }, .{ producer + 4, 17 },                     .{ producer + 8, 19 },       .{ producer + 0x68, entry },      .{ producer + 0x6c, 23 },
        .{ entry, 19 },                                                     .{ entry + 4, if (mode == 12) 1 else 23 }, .{ entry + 8, producer },    .{ entry + 12, 4 },               .{ producer + 0x374, 7 },
        .{ producer + 0x98, if (mode == 13) 4 else 2 },                     .{ producer + 0xb0, recipe },              .{ producer + 0x514, pool }, .{ 0xfb2f60, pool },              .{ 0xfb2e3c, 1 },
        .{ 0xfb4a20, area },                                                .{ area + 0x220, definition },             .{ 0xfb2e60, flow },         .{ flow + 0x1b78, 14 },           .{ 0xfb4b6c, 31 },
        .{ 0xe637b4, 71 },                                                  .{ 0xea178c, 79 },                         .{ 0xcec39c, 100 },          .{ order + 0x80, team },          .{ order + 0x5e8, 107 },
        .{ team, if (mode == 14) 1 else 0xaef0fc },                         .{ team + 0x1c, descriptor },              .{ descriptor + 0x30, 2 },   .{ group + 0xcc, group_manager }, .{ group + 0x78, bank },
        .{ group_manager + 0x16dc, 1 },                                     .{ group + 0xec, 0x01000000 },             .{ bank + 0x11c, pool },
    };
    for (fields) |field| put(field[0], field[1]);
    win.store(u16, pool + 0xdc0, 321);
    win.store(u16, definition + 0x94, 9);
}
const Snapshot = extern struct { count: u32, producer_count: u32, births: u32, noted: u32, context: Identity, seen: [8]Identity, notes: [8]Note, records: [8]obs.BirthRecord, producers: [4]obs.ProducerRecord };
fn run() Snapshot {
    setup();
    obs.clonewars_spawn_observer_enabled = @intFromBool(mode != 0 and mode != 3);
    obs.clonewars_spawn_observer_count = 0;
    obs.clonewars_producer_observer_count = 0;
    @memset(std.mem.asBytes(&obs.clonewars_spawn_observer)[0 .. 8 * @sizeOf(obs.BirthRecord)], 0);
    @memset(std.mem.asBytes(&obs.clonewars_producer_observer)[0 .. 4 * @sizeOf(obs.ProducerRecord)], 0);
    obs.spawn_observer_flow(1);
    switch (mode) {
        0...2 => {
            _ = birthAt(0x600123, if (mode == 2) 9 else 3);
        },
        3, 4 => {
            _ = @as(Produce, @ptrFromInt(0x1e000100))(producer, 2, 1);
        },
        5, 12 => @as(Child, @ptrFromInt(0x1e000200))(producer, position, 71, 79),
        6, 13 => @as(Pair, @ptrFromInt(0x1e000300))(producer, descriptor),
        7 => @as(*const fn (usize) callconv(.c) void, @ptrFromInt(0x1e000500))(pool),
        8 => {
            _ = @as(Crew, @ptrFromInt(0x1e000600))(producer, pool);
        },
        9, 14 => {
            _ = @as(Constructor, @ptrFromInt(0x1e000700))(order, 1, 2, 3, 4, 5, 6, 7);
            @as(Order, @ptrFromInt(0x1e000800))(order, 71, 79);
        },
        10 => {
            _ = @as(Group, @ptrFromInt(0x1e000900))(group, 3);
        },
        else => {
            _ = @as(Gun, @ptrFromInt(0x1e000400))(producer, producer, pool, 10);
        },
    }
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    out.count = obs.clonewars_spawn_observer_count;
    out.producer_count = obs.clonewars_producer_observer_count;
    out.births = @intCast(births);
    out.noted = @intCast(noted);
    out.context = context;
    out.seen = seen;
    out.notes = notes;
    @memcpy(&out.records, obs.clonewars_spawn_observer[0..8]);
    @memcpy(&out.producers, obs.clonewars_producer_observer[0..4]);
    for (&out.records) |*record| {
        check(@src(), record.committed == 0 or record.thread == win.GetCurrentThreadId());
        record.thread = 0;
    }
    for (&out.producers) |*record| {
        check(@src(), record.committed == 0 or record.thread == win.GetCurrentThreadId());
        record.thread = 0;
    }
    return out;
}
fn invokeThrow(_: usize) callconv(.c) c_int {
    return @bitCast(@as(Produce, @ptrFromInt(0x1e000100))(producer, 2, 1));
}
pub fn main() void {
    for (0..13) |i| {
        const address = 0x20000000 + i * 0x10000;
        check(@src(), win.VirtualAlloc(address, 0x3000, 0x3000, 4) == address);
    }
    defer {
        for (0..13) |i| check(@src(), win.VirtualFree(0x20000000 + i * 0x10000, 0, 0x8000) != 0);
    }
    check(@src(), win.VirtualAlloc(0x1e000000, 0x1000, 0x3000, 0x40) == 0x1e000000);
    defer check(@src(), win.VirtualFree(0x1e000000, 0, 0x8000) != 0);
    for ([_]usize{ 0x410000, 0x440000, 0x470000, 0x4c0000, 0x4d0000, 0x4e0000, 0x4f0000, 0x550000, 0x600000, 0x9d0000, 0xce0000, 0xe60000, 0xe80000, 0xea0000, 0xfb0000 }) |address| {
        check(@src(), address >= @intFromPtr(&image) and address + 0x10000 <= @intFromPtr(&image) + image.len);
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(address, 0x10000, 0x40, &old) != 0);
    }
    const addresses = [_]usize{ 0x9de240, 0x4fd8f0, 0x4e2730, 0x4df470, 0x47e1a0, 0x556d60, 0x550df0, 0x4cb710 };
    const prefixes = [_][]const u8{ &.{ 0x83, 0xec, 0x20, 0x53, 0x55 }, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 }, &.{ 0x83, 0xec, 0x60, 0xa1, 0xbc, 0xd2, 0xe8, 0 }, &.{ 0x56, 0x8b, 0x35, 0x20, 0x4a, 0xfb, 0 }, &.{ 0x6a, 0xff, 0x68, 0x5c, 0xd8, 0xa9, 0 }, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 }, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 }, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 } };
    const kinds = [_]usize{ 0, 1, 2, 5, 6, 7, 8, 9 };
    const natives = [_]usize{ @intFromPtr(&nativeBirth), @intFromPtr(&nativeProduce), @intFromPtr(&nativeChild), @intFromPtr(&nativeMount), @intFromPtr(&nativeCrew), @intFromPtr(&nativeConstructor), @intFromPtr(&nativeOrder), @intFromPtr(&nativeGroup) };
    for (addresses, prefixes, natives, 0..) |address, prefix, native, i| {
        bytes(address, prefix);
        const cleanup: []const u8 = switch (i) {
            0 => &.{ 0x5d, 0x5b, 0x83, 0xc4, 0x20 },
            2 => &.{ 0x83, 0xc4, 0x60 },
            3 => &.{0x5e},
            4 => &.{ 0x83, 0xc4, 8 },
            else => &.{ 0x89, 0xec, 0x5d },
        };
        bytes(address + prefix.len, cleanup);
        jump(address + prefix.len + cleanup.len, native);
    }
    bytes(0x4e65b7, &.{ 0xe8, 0x74, 0xfd, 0xff, 0xff });
    bytes(0x445671, &.{ 0xe8, 0x9a, 0x58, 0xfd, 0xff });
    jump(0x4e6330, @intFromPtr(&nativePair));
    jump(0x41af10, @intFromPtr(&nativeGun));
    check(@src(), obs.spawn_observer_install() != 0);
    for (addresses, kinds) |address, kind| hooks[kind] = address +% 5 +% win.load(u32, address + 1);
    hooks[3] = 0x4e65bc +% win.load(u32, 0x4e65b8);
    hooks[4] = 0x445676 +% win.load(u32, 0x445672);
    const counts = [_]u8{ 0, 2, 3, 1, 3, 1, 1, 7, 2, 1 };
    for (1..10) |k| {
        const start = 0x1e000000 + k * 0x100;
        for (0..counts[k]) |i| bytes(start + i * 4, &.{ 0xff, 0x74, 0x24, counts[k] * 4 });
        const at = start + counts[k] * 4;
        win.store(u8, at, 0xb8);
        put(at + 1, hooks[k]);
        win.store(u16, at + 5, 0xd0ff);
        if (k == 5) bytes(at + 7, &.{ 0x83, 0xc4, 4, 0xc3 }) else {
            win.store(u8, at + 7, 0xc2);
            win.store(u16, at + 8, @as(u16, counts[k]) * 4);
        }
    }
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x1e000000, 0x1000) != 0);
    check(@src(), @sizeOf(Snapshot) == 2780);
    const expected = [_]u32{ 652091171, 753217965, 234839777, 3134684154, 327346098, 1420152088, 129672446, 2702399625, 438971748, 2092322815, 281353712, 3191321657, 2332818244, 2308917715, 327028043, 1446045924, 1446045924 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        const out = run();
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("spawn observation mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
    }
    mode = 4;
    setup();
    obs.clonewars_spawn_observer_enabled = 1;
    obs.clonewars_spawn_observer_count = 0;
    obs.clonewars_producer_observer_count = 0;
    throwing = true;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876);
    check(@src(), context.site == 77 and context.source.producer == 79 and context.source.serial == 83);
    throwing = false;
    _ = birthAt(0x600123, 3);
    const last = obs.clonewars_spawn_observer[(obs.clonewars_spawn_observer_count - 1) % 256];
    check(@src(), last.parent == 0 and last.producer_event == 0 and last.producer_transaction == 0);
}
