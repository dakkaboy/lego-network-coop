const std = @import("std");
const s = @import("entity_state.zig");
const r = @import("entity_registry.zig");
const spawn = @import("entity_spawn.zig");
const input = @import("entity_input.zig");
const win = s.win;
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
    _ = @import("entity_match.zig");
}
const pool: usize = 0x20000000;
const other_pool: usize = 0x20010000;
const models: usize = 0x20020000;
var mode: u32 = 0;
var next_slot: usize = 0;
var constructor_calls: u32 = 0;
var allocations: u32 = 0;
var host = true;
var proof = true;
var published = false;
var saved: [24]u32 = @splat(0);
var created: usize = 0;
export var entity_fixture_saved: usize = 0;
export var entity_fixture_ctor_target: usize = 0;
extern fn invoke_constructor_target() usize;
comptime {
    asm (
        \\.text
        \\_invoke_constructor_target:
        \\pushl %ebp
        \\pushl %esi
        \\movl _entity_fixture_saved,%edx
        \\pushl 84(%edx)
        \\pushl 80(%edx)
        \\pushl 76(%edx)
        \\pushl 72(%edx)
        \\pushl 68(%edx)
        \\pushl 64(%edx)
        \\pushl 60(%edx)
        \\pushl 56(%edx)
        \\pushl 52(%edx)
        \\pushl 48(%edx)
        \\pushl 44(%edx)
        \\pushl 40(%edx)
        \\movl 4(%edx),%esi
        \\movl 8(%edx),%ebp
        \\call *_entity_fixture_ctor_target
        \\addl $48,%esp
        \\popl %esi
        \\popl %ebp
        \\ret
    );
}
export fn lan_is_host() c_int {
    return @intFromBool(host);
}
export fn game_actor_count() c_int {
    return 8;
}
export fn native_roster_source_resolve(record: usize, args: *const [12]u32, out: *s.Roster) c_int {
    check(@src(), record == 0x12345678 and args[0] == 12);
    out.* = std.mem.zeroes(s.Roster);
    out.ordinal = 2;
    out.count = 8;
    out.level = 12;
    return @intFromBool(mode != 3);
}
export fn native_roster_source_revalidate(value: *const s.Roster, actor: usize) c_int {
    check(@src(), value.ordinal == 2 and value.level == 12);
    return @intFromBool(proof and (actor == 0 or published));
}
export fn native_hub_source_resolve(owner: usize, frame: usize, args: *const [12]u32, out: *s.Hub, reason: *u32) c_int {
    check(@src(), owner == 0x12345678 and frame == models and args[0] == 12);
    out.* = std.mem.zeroes(s.Hub);
    out.owner_id = 0xe101;
    out.serial = 15;
    out.level = 12;
    out.ordinal = 2;
    out.manager_id = 31;
    out.manager_generation = 37;
    reason.* = if (mode == 12) 3 else 0;
    return @intFromBool(mode != 12);
}
export fn native_hub_source_revalidate(_: *const s.Hub) c_int {
    return @intFromBool(proof);
}
fn nativeCreate() callconv(.c) usize {
    allocations += 1;
    if (mode == 18) return models;
    check(@src(), next_slot < 8);
    const actor = pool + next_slot * 0x1440;
    next_slot += 1;
    return actor;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn initialize(actor: usize) void {
    if (actor == models) return;
    put(actor + 0x50, if (mode == 16) 1 else 3);
    win.store(i16, actor + 0xdc0, if (mode == 6) 13 else 12);
    put(actor + 8, @intCast(models + next_slot * 4));
    win.store(f32, actor + 0x24, @floatFromInt(next_slot));
    win.store(i8, actor + 0x55, -1);
}
fn nativeConstructor(a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32, a6: u32, a7: u32, a8: u32, a9: u32, a10: u32, a11: u32) callconv(.c) usize {
    const args = [_]u32{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 };
    check(@src(), args[0] == 12);
    for (args[1..], 1..) |value, i| check(@src(), value == 100 + i);
    constructor_calls += 1;
    if (mode == 10 or mode == 14) win.RaiseException(0xe1459876, 0, 0, null);
    const create: *const fn () callconv(.c) usize = @ptrFromInt(0x9c5ce1);
    var actor = create();
    initialize(actor);
    if (mode == 4) {
        actor = create();
        initialize(actor);
    }
    if (mode == 7 or mode == 13) proof = false;
    if (mode == 17) put(0xfb2f60, other_pool);
    win.SetLastError(321);
    return if (mode == 5) pool + 7 * 0x1440 else actor;
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn call(address: usize, target: usize) void {
    win.store(u8, address, 0xe8);
    put(address + 1, target -% address -% 5);
    win.store(u8, address + 5, 0xc3);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 6) != 0);
}
fn callAt(address: usize) usize {
    return @as(*const fn () callconv(.c) usize, @ptrFromInt(address))();
}
fn setup() void {
    host = true;
    proof = true;
    published = false;
    next_slot = 0;
    constructor_calls = 0;
    allocations = 0;
    @memset(@as([*]u8, @ptrFromInt(pool))[0 .. 8 * 0x1440], 0);
    @memset(@as([*]u8, @ptrFromInt(other_pool))[0 .. 8 * 0x1440], 0);
    @memset(@as([*]u8, @ptrFromInt(models))[0..0x1000], 0);
    saved = @splat(0);
    put(0xfb2f60, pool);
    for (0..8) |i| put(0xfb4940 + i * 4, 0);
    put(0xfb4968, 3);
    saved[1] = 0x12345678;
    saved[2] = models;
    saved[10] = 12;
    for (1..12) |i| saved[10 + i] = @intCast(100 + i);
    r.entities_update();
    s.clonewars_entity_debug = @splat(0);
    s.clonewars_roster_source_debug = @splat(0);
    s.clonewars_hub_source_debug = @splat(0);
    _ = r.entities_set_spawn_context(std.mem.zeroes(s.SpawnIdentity));
    s.original_create = @intFromPtr(&nativeCreate);
    s.birth_counter = if (mode == 19) 0xffffffff else 100;
    call(0x9c5ce1, @intFromPtr(&spawn.entity_create_hook));
    call(0x9c5ef1, @intFromPtr(&spawn.entity_create_hook));
}
fn construct(raw: usize) callconv(.c) c_int {
    created = if (raw != 0) spawn.entity_hub_constructor(&saved) else spawn.entity_roster_constructor(&saved);
    return 0;
}
const Snapshot = extern struct { allocations: u32, constructor_calls: u32, err: u32, generation: u32, site: u32, retained: u32, live: u32, entity_debug: [12]u32, roster_debug: [8]u32, hub_debug: [16]u32, exception: c_int, source: s.p.SyncSpawnSource, described: s.p.SyncActor };
fn run() Snapshot {
    setup();
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    win.SetLastError(1234);
    created = 0;
    if (mode == 0 or mode == 19) {
        created = callAt(0x9c5ef1);
        initialize(created);
    } else if (mode == 1) {
        _ = r.entities_set_spawn_context(.{ .site = 0x1234, .source = .{ .producer = 0xe199, .serial = 29 } });
        created = callAt(0x9c5ce1);
        initialize(created);
    } else if (mode == 15) {
        created = spawn.entity_create_hook();
        initialize(created);
    } else {
        out.exception = @intFromBool(support.exceptionCode(@intFromBool(mode >= 11 and mode <= 14), construct) == 0xe1459876);
        if (mode == 9) {
            published = false;
            out.exception = @intFromBool(support.exceptionCode(0, construct) == 0xe1459876);
        }
    }
    out.err = win.GetLastError();
    published = mode != 8;
    r.entities_update();
    if (mode == 8) {
        proof = false;
        r.entities_update();
    }
    if (out.exception != 0) {
        _ = r.entities_set_spawn_context(.{ .site = 0x9876, .source = .{ .producer = 0xe199, .serial = 31 } });
        created = callAt(0x9c5ce1);
        initialize(created);
        r.entities_update();
    }
    out.allocations = allocations;
    out.constructor_calls = constructor_calls;
    out.generation = r.entities_observed_generation(created);
    out.source = r.entities_spawn_source(created, &out.site);
    out.retained = @intCast(r.entities_allocation_retained(created, out.generation));
    out.live = @intCast(r.entities_allocation_live(created, out.generation));
    r.entities_describe(&out.described, created);
    out.entity_debug = s.clonewars_entity_debug;
    out.roster_debug = s.clonewars_roster_source_debug;
    out.hub_debug = s.clonewars_hub_source_debug;
    return out;
}
fn protect(address: usize, value: u32) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 0x10000, value, &old) != 0);
}
fn installedHooks() void {
    const sites = [_]usize{ 0x7e53d0, 0x9c63ac, 0x8afc3a, 0x8afcbe, 0x4eed96 };
    var prefixes: [5][5]u8 = @splat(@splat(0));
    prefixes[0] = .{ 0xa1, 0x20, 0x4a, 0xfb, 0 };
    prefixes[1] = .{ 0xe8, 0x1f, 0xf0, 0xe1, 0xff };
    for ([_]usize{ 0x7e0000, 0x9c0000, 0x8a0000, 0x4e0000 }) |address| protect(address, 0x40);
    for (2..5) |i| {
        prefixes[i][0] = 0xe8;
        std.mem.writeInt(u32, prefixes[i][1..5], 0x9de240 -% sites[i] -% 5, .little);
    }
    for (sites, prefixes) |site, prefix| @memcpy(@as([*]u8, @ptrFromInt(site))[0..5], &prefix);
    jump(0x7e53d5, @intFromPtr(&nativeCreate));
    for (sites, 0..) |site, bad| {
        win.store(u8, site, 0xcc);
        check(@src(), input.entities_install() == 0);
        win.store(u8, site, prefixes[bad][0]);
        for (sites, prefixes) |address, expected| check(@src(), std.mem.eql(u8, &expected, @as([*]const u8, @ptrFromInt(address))[0..5]));
    }
    for ([_]usize{ 0x7e0000, 0x8a0000, 0x4e0000 }) |address| protect(address, 0x20);
    check(@src(), input.entities_install() != 0 and input.entities_install() != 0);
    for ([_]usize{ 0x7e53d0, 0x8afc3a, 0x4eed96 }) |address| {
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
    entity_fixture_saved = @intFromPtr(&saved);
    const original = s.original_create;
    for (0..3) |kind| {
        mode = if (kind == 2) 11 else 2;
        setup();
        s.original_create = original;
        entity_fixture_ctor_target = sites[kind + 2] +% 5 +% win.load(u32, sites[kind + 2] + 1);
        call(0x9c5ce1, 0x7e53d0);
        win.SetLastError(1234);
        created = invoke_constructor_target();
        check(@src(), created == pool and win.GetLastError() == 321);
        published = true;
        r.entities_update();
        var site: u32 = 0;
        const identity = r.entities_spawn_source(created, &site);
        check(@src(), site == 0x5c5ce6 and identity.producer == (if (kind == 2) @as(u32, 0xe101) else 2) and identity.serial == (if (kind == 2) @as(u32, 15) else 98));
    }
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 464 and @intFromPtr(&image) < 0x7e0000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0x9c0000, 0x9d0000, 0xfb0000 }) |address| protect(address, 0x40);
    for ([_][2]usize{ .{ pool, 8 * 0x1440 }, .{ other_pool, 8 * 0x1440 }, .{ models, 0x1000 } }) |allocation| check(@src(), win.VirtualAlloc(allocation[0], allocation[1], 0x3000, 4) == allocation[0]);
    defer {
        for ([_]usize{ pool, other_pool, models }) |address| check(@src(), win.VirtualFree(address, 0, 0x8000) != 0);
    }
    jump(0x9de240, @intFromPtr(&nativeConstructor));
    const expected = [_]u32{ 46604948, 4074300120, 2833853695, 144943633, 1738743649, 4232313345, 285211624, 285211624, 100644175, 1149681844, 689029168, 408947512, 2155448626, 3893371148, 2194654160, 1671081652, 2851337560, 2100885647, 2280172222, 2297721364 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        const out = run();
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("entity runtime mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 2) check(@src(), out.source.producer == 2 and out.source.serial == 98);
        if (mode == 11) check(@src(), out.source.producer == 0xe101 and out.source.serial == 15);
        if (mode == 10 or mode == 14) check(@src(), out.exception != 0 and out.site == 0x9876 and out.source.producer == 0xe199);
    }
    installedHooks();
}
