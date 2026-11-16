const std = @import("std");
const collision = @import("collision.zig");
const contact = @import("world_contact.zig");
const t = @import("collision_types.zig");
const ct = @import("contact_types.zig");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
export var clonewars_combat_observer_count: u32 = 3;
comptime {
    _ = @import("lexical_seh.zig");
}
const Query = *const fn (usize, usize, usize, usize, c_int, usize) callconv(.{ .x86_thiscall = .{} }) void;
const Manager = *const fn (usize, usize, usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
const Contact = *const fn (usize, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) u8;
const actor: usize = 0x20000000;
const shot: usize = 0x20010000;
const model: usize = 0x20020000;
const resource: usize = 0x20030000;
const definition: usize = 0x20040000;
const manager: usize = 0x20050000;
const packet: usize = 0x20060000;
const event: usize = 0x20070000;
const nodes: usize = 0x20080000;
const object: usize = 0x20090000;
const points: usize = 0x200a0000;
var query: Query = undefined;
var manage: Manager = undefined;
var touch: Contact = undefined;
var mode: u32 = 0;
var query_calls: u32 = 0;
var manager_calls: u32 = 0;
var contact_calls: u32 = 0;
var depth: u32 = 0;
var throwing = false;
var throw_contact = false;
export fn game_sync_epoch() u32 {
    return 7;
}
export fn game_sync_sequence() u32 {
    return 100 + mode;
}
export fn entities_observed_generation(_: usize) u32 {
    return 7;
}
export fn entities_observed_identity(_: usize, slot: *u32, generation: *u32) c_int {
    slot.* = 2;
    generation.* = 9;
    return 1;
}
export fn projectiles_observe_live(_: usize, out: *t.Identity) c_int {
    out.* = .{ .status = if (mode == 5 or mode == 13) 2 else 1, .id = 17, .owner = 2, .weapon = 4, .owner_generation = 9, .resource_local = resource, .instance_serial = 19, .creation_count = 23 };
    return 1;
}
export fn geometry_phase(value: u32) c_int {
    check(@src(), value == @intFromBool(mode == 4));
    return @intFromBool(mode != 3);
}
export fn geometry_manager_ready() void {}
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
fn nativeQuery(m: usize, s: usize, target: usize, pointer: usize, index: c_int, extra: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), m == manager and s == shot and target == (if (mode == 6) @as(usize, 1) else actor) and pointer == points and index == 2 and extra == 71);
    query_calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    put(actor + 0x50, 91);
    win.SetLastError(321);
}
fn nativeManager(m: usize, pointer: usize, e: usize, context: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), m == manager and pointer == packet and e == event and context == 0);
    manager_calls += 1;
    @as(Query, @ptrFromInt(0x1e000000))(manager, shot, if (mode == 6) 1 else actor, points, 2, 71);
}
fn nativeContact(m: usize, a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), m == manager and a0 == shot and a1 == points and a2 == a1 and a3 == a1 + 12 and a4 == 71 and a5 == 79);
    contact_calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    win.store([6]u32, 0x200b0000, .{ a1, a2, a3, a3, 0, 0 });
    win.store([8]u32, 0x200c0000, .{ 0, object, a1, 0, 0, 2, 0, 0 });
    contact.world_contact_query_checkpoint(0x200b0000, 1, 0x81f7bf, 0x200c0000);
    if (mode == 15 and depth == 0) {
        depth += 1;
        _ = @as(Contact, @ptrFromInt(0x1e000200))(m, a0, a1, a2, a3, a4, a5);
        depth -= 1;
    }
    win.SetLastError(321);
    return 1;
}
fn setup() void {
    const wrappers = [_]usize{ 0x1e000000, 0x1e000100, 0x1e000200 };
    const targets = [_]usize{ @intFromPtr(query), @intFromPtr(manage), @intFromPtr(touch) };
    const counts = [_]usize{ 5, 3, 6 };
    for (wrappers, targets, counts) |wrapper, target, count| {
        for (0..count) |j| bytes(wrapper + j * 4, &.{ 0xff, 0x74, 0x24, @intCast(count * 4) });
        const site = wrapper + count * 4;
        win.store(u8, site, 0xb8);
        put(site + 1, target);
        bytes(site + 5, &.{ 0xff, 0xd0, 0xc2, @intCast(count * 4), 0 });
    }
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x1e000000, 0x300) != 0);
    query_calls = 0;
    manager_calls = 0;
    contact_calls = 0;
    depth = 0;
    @memset(@as([*]u8, @ptrFromInt(actor))[0..0x2000], 0);
    @memset(@as([*]u8, @ptrFromInt(nodes))[0..0x1000], 0);
    @memset(@as([*]u8, @ptrFromInt(manager))[0..0x1000], 0);
    put(actor + 0x50, 3);
    win.store(u16, actor + 0xdc0, 321);
    put(actor + 8, model);
    put(actor + 0xf08, resource);
    put(resource + 0x2c, definition);
    put(0xfb2f60, actor);
    put(0xfb2e3c, 1);
    put(0xfb4b6c, 31);
    put(0xe637b4, 71);
    put(0xea178c, 79);
    put(packet + 0xc, @intFromBool(mode == 4));
    const count: usize = if (mode == 11) 65 else if (mode == 12) 0 else 2;
    put(manager + 0x34, if (count != 0) nodes else 0);
    for (0..count) |i| {
        const node = nodes + i * 12;
        put(node, if (i + 1 < count) node + 12 else if (mode == 9) nodes else if (mode == 10) 1 else 0);
        put(node + 8, object);
    }
}
const Snapshot = extern struct { query_calls: u32, manager_calls: u32, contact_calls: u32, queries: u32, phases: u32, contacts: u32, contact_queries: u32, debug: [8]u32, query: [2]t.Query, phase: [2]t.Phase, contact: [2]ct.Entry, contact_query: [2]ct.Query };
fn normalize(value: anytype) void {
    if (value.committed != 0) check(@src(), value.thread == win.GetCurrentThreadId());
    value.thread = 0;
    value.qpc_before_low = 0;
    value.qpc_before_high = 0;
    value.qpc_after_low = 0;
    value.qpc_after_high = 0;
}
fn run(out: *Snapshot) void {
    setup();
    collision.clonewars_collision_observer_enabled = @intFromBool(mode != 0);
    contact.clonewars_world_contact_enabled = @intFromBool(mode != 0);
    collision.clonewars_collision_observer_count = 0;
    collision.clonewars_collision_geometry_count = 0;
    contact.clonewars_world_contact_entry_count = 0;
    contact.clonewars_world_contact_query_count = 0;
    collision.clonewars_collision_debug = @splat(0);
    @memset(std.mem.asBytes(collision.clonewars_collision_observer[0..2]), 0);
    @memset(std.mem.asBytes(collision.clonewars_collision_geometry[0..2]), 0);
    @memset(std.mem.asBytes(contact.clonewars_world_contact_entries[0..2]), 0);
    @memset(std.mem.asBytes(contact.clonewars_world_contact_queries[0..2]), 0);
    if (mode < 8) {
        if (mode < 2 or mode == 5 or mode == 6) @as(Query, @ptrFromInt(0x1e000000))(manager, shot, if (mode == 6) 1 else actor, points, 2, 71) else @as(Manager, @ptrFromInt(0x1e000100))(manager, packet, event, 0);
    } else {
        _ = @as(Contact, @ptrFromInt(0x1e000200))(manager, shot, points, points, points + 12, 71, 79);
    }
    @memset(std.mem.asBytes(out), 0);
    out.query_calls = query_calls;
    out.manager_calls = manager_calls;
    out.contact_calls = contact_calls;
    out.queries = collision.clonewars_collision_observer_count;
    out.phases = collision.clonewars_collision_geometry_count;
    out.contacts = contact.clonewars_world_contact_entry_count;
    out.contact_queries = contact.clonewars_world_contact_query_count;
    out.debug = collision.clonewars_collision_debug;
    out.query = collision.clonewars_collision_observer[0..2].*;
    out.phase = collision.clonewars_collision_geometry[0..2].*;
    out.contact = contact.clonewars_world_contact_entries[0..2].*;
    out.contact_query = contact.clonewars_world_contact_queries[0..2].*;
    for (&out.query) |*r| normalize(r);
    for (&out.phase) |*r| normalize(r);
    for (&out.contact) |*r| normalize(&r.header);
    for (&out.contact_query) |*r| normalize(&r.header);
}
fn invokeThrow(_: usize) callconv(.c) c_int {
    if (throw_contact) {
        _ = @as(Contact, @ptrFromInt(0x1e000200))(manager, shot, points, points, points + 12, 71, 79);
    } else @as(Manager, @ptrFromInt(0x1e000100))(manager, packet, event, 0);
    return 0;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 55660 and @intFromPtr(&image) < 0x810000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ actor, shot, model, resource, definition, manager, packet, event, nodes, object }) |address| check(@src(), win.VirtualAlloc(address, if (address == actor) 0x2000 else 0x1000, 0x3000, 4) == address);
    defer for ([_]usize{ actor, shot, model, resource, definition, manager, packet, event, nodes, object }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    check(@src(), win.VirtualAlloc(points, 0x30000, 0x3000, 4) == points);
    defer _ = win.VirtualFree(points, 0, 0x8000);
    check(@src(), win.VirtualAlloc(0x1e000000, 0x1000, 0x3000, 0x40) == 0x1e000000);
    defer _ = win.VirtualFree(0x1e000000, 0, 0x8000);
    var old: u32 = 0;
    for ([_]usize{ 0x810000, 0x860000, 0xe60000, 0xea0000, 0xfb0000 }) |address| check(@src(), win.VirtualProtect(address, 0x10000, 0x40, &old) != 0);
    bytes(0x81e860, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0, 0x89, 0xec, 0x5d });
    jump(0x81e869, @intFromPtr(&nativeQuery));
    bytes(0x863410, &.{ 0x81, 0xec, 0xcc, 0, 0, 0, 0x81, 0xc4, 0xcc, 0, 0, 0 });
    jump(0x86341c, @intFromPtr(&nativeManager));
    bytes(0x81f6c0, &.{ 0x51, 0x8b, 0x41, 0x34, 0x53, 0x55, 0x56, 0x57, 0x5f, 0x5e, 0x5d, 0x5b, 0x83, 0xc4, 4 });
    jump(0x81f6cf, @intFromPtr(&nativeContact));
    bytes(0x81f7bf, &.{ 0x83, 0xc4, 0x18, 0x85, 0xc0 });
    win.store(u8, 0x81f7ba, 0xe8);
    put(0x81f7bb, @as(usize, 0x78e650) -% 0x81f7bf);
    check(@src(), collision.collision_observer_install() != 0 and contact.world_contact_observer_install() != 0);
    query = @ptrFromInt(0x81e865 +% win.load(u32, 0x81e861));
    manage = @ptrFromInt(0x863415 +% win.load(u32, 0x863411));
    touch = @ptrFromInt(0x81f6c5 +% win.load(u32, 0x81f6c1));
    const expected = [_]u32{ 421509252, 1020036191, 4193220294, 3376689651, 250338738, 3959840171, 1887415853, 3432255526, 1011707119, 2708379729, 2453356732, 1173776345, 4107027933, 3646830005, 2548071883, 3081497837 };
    const out = std.heap.c_allocator.create(Snapshot) catch @panic("allocation failed");
    defer std.heap.c_allocator.destroy(out);
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        run(out);
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("collision mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
    }
    mode = 7;
    setup();
    collision.clonewars_collision_observer_enabled = 1;
    throwing = true;
    throw_contact = false;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876);
    throwing = false;
    query(manager, shot, actor, points, 2, 71);
    const q = collision.clonewars_collision_observer[(collision.clonewars_collision_observer_count - 1) % 1024];
    check(@src(), q.parent == 0 and q.manager_id == 0);
    mode = 8;
    setup();
    contact.clonewars_world_contact_enabled = 1;
    throwing = true;
    throw_contact = true;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876);
    throwing = false;
    _ = touch(manager, shot, points, points, points + 12, 71, 79);
    check(@src(), contact.clonewars_world_contact_entries[(contact.clonewars_world_contact_entry_count - 1) % 128].header.parent == 0);
}
