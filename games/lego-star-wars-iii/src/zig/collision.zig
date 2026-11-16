const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const t = @import("collision_types.zig");
const snapshot = @import("collision_snapshot.zig");
const Machine = @import("machine_environment.zig").Environment;
const Query = *const fn (usize, usize, usize, usize, c_int, usize) callconv(.{ .x86_thiscall = .{} }) void;
const Manager = *const fn (usize, usize, usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
var original_query: Query = undefined;
var original_manager: Manager = undefined;
threadlocal var active_query: u32 = 0;
threadlocal var active_manager: u32 = 0;
threadlocal var active_ordinal: u32 = 0;
threadlocal var last_sequence: u32 = 0;
threadlocal var manager_ordinal: u32 = 0;
pub export var clonewars_collision_observer_enabled: i32 = 0;
pub export var clonewars_collision_observer_installed: i32 = 0;
pub export var clonewars_collision_observer_count: u32 = 0;
pub export var clonewars_collision_observer_stride: u32 = @sizeOf(t.Query);
pub export var clonewars_collision_observer_capacity: u32 = 1024;
pub export var clonewars_collision_observer: [1024]t.Query = std.mem.zeroes([1024]t.Query);
pub export var clonewars_collision_geometry_count: u32 = 0;
pub export var clonewars_collision_geometry_stride: u32 = @sizeOf(t.Phase);
pub export var clonewars_collision_geometry_capacity: u32 = 8192;
pub export var clonewars_collision_geometry: [8192]t.Phase = std.mem.zeroes([8192]t.Phase);
pub export var clonewars_collision_debug: [8]u32 = @splat(0);
extern var clonewars_combat_observer_count: u32;
extern fn game_sync_sequence() u32;
extern fn geometry_phase(u32) c_int;
extern fn geometry_manager_ready() void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
const QueryScope = struct { machine: Machine, record: t.Query, previous: u32 };
fn queryInvoke(address: usize) callconv(.c) usize {
    const s: *QueryScope = @ptrFromInt(address);
    const r = &s.record;
    const a = &r.arguments_local;
    active_query = r.id;
    s.machine.restore();
    original_query(r.manager_local, a[0], a[1], a[2], @bitCast(a[3]), a[4]);
    s.machine.capture();
    active_query = s.previous;
    snapshot.geometry(&r.target_after, a[1]);
    snapshot.shot(&r.shot_after, a[0], false);
    r.clock_after = obs.word(0xfb4b6c);
    r.rng_game_after = obs.word(0xe637b4);
    r.rng_engine_after = obs.word(0xea178c);
    r.combat_after = clonewars_combat_observer_count;
    obs.timestamp(&r.qpc_after_low, &r.qpc_after_high);
    obs.publish(&clonewars_collision_observer[(r.id -% 1) % 1024], r);
    clonewars_collision_debug[0] +%= 1;
    if (r.manager_id == 0) clonewars_collision_debug[1] +%= 1;
    return 0;
}
fn queryAbort(address: usize) callconv(.c) void {
    const s: *QueryScope = @ptrFromInt(address);
    active_query = s.previous;
}
fn queryHook(manager: usize, _: usize, shot: usize, target: usize, points: usize, index: c_int, extra: usize) callconv(.{ .x86_fastcall = .{} }) void {
    if (clonewars_collision_observer_enabled == 0) {
        original_query(manager, shot, target, points, index, extra);
        return;
    }
    var s: QueryScope = undefined;
    s.machine.capture();
    s.record = std.mem.zeroes(t.Query);
    s.previous = active_query;
    const r = &s.record;
    r.id = obs.increment(&clonewars_collision_observer_count);
    r.parent = active_query;
    r.manager_id = active_manager;
    r.manager_ordinal = active_ordinal;
    r.thread = win.GetCurrentThreadId();
    r.caller = @truncate(@returnAddress());
    r.sequence = game_sync_sequence();
    r.manager_local = @truncate(manager);
    r.arguments_local = .{ @truncate(shot), @truncate(target), @truncate(points), @bitCast(index), @truncate(extra) };
    obs.timestamp(&r.qpc_before_low, &r.qpc_before_high);
    r.clock = obs.word(0xfb4b6c);
    r.rng_game = obs.word(0xe637b4);
    r.rng_engine = obs.word(0xea178c);
    r.combat_before = clonewars_combat_observer_count;
    r.points_valid = @intFromBool(obs.read(points, std.mem.asBytes(&r.points)));
    snapshot.geometry(&r.target_before, target);
    snapshot.shot(&r.shot_before, shot, false);
    _ = constructor_lexical_seh(@intFromPtr(&s), queryInvoke, queryAbort);
    s.machine.restore();
}
const ManagerScope = struct { machine: Machine, manager: usize, packet: usize, event: usize, context: usize, previous_manager: u32, previous_ordinal: u32, scratch: usize, saved: u32 };
fn managerCleanup(s: *ManagerScope) void {
    if (s.scratch != 0) {
        _ = obs.HeapFree(obs.GetProcessHeap(), 0, s.scratch);
        s.scratch = 0;
    }
    active_manager = s.previous_manager;
    active_ordinal = s.previous_ordinal;
}
fn managerAbort(address: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    managerCleanup(@ptrFromInt(address));
}
fn managerInvoke(address: usize) callconv(.c) usize {
    const s: *ManagerScope = @ptrFromInt(address);
    const allowed = geometry_phase(obs.word(s.packet +% 0xc)) != 0;
    if (allowed) {
        s.machine.restore();
        original_manager(s.manager, s.packet, s.event, s.context);
        s.machine.capture();
    } else clonewars_collision_debug[7] +%= 1;
    for (0..s.saved) |i| {
        const r = &@as([*]t.Phase, @ptrFromInt(s.scratch))[i];
        snapshot.geometry(&r.after, r.before.pointer_local);
        r.clock_after = obs.word(0xfb4b6c);
        r.rng_game_after = obs.word(0xe637b4);
        r.rng_engine_after = obs.word(0xea178c);
        obs.timestamp(&r.qpc_after_low, &r.qpc_after_high);
        obs.publish(&clonewars_collision_geometry[(r.id -% 1) % 8192], r);
        clonewars_collision_debug[5] +%= 1;
    }
    managerCleanup(s);
    return 0;
}
fn managerHook(manager: usize, _: usize, packet: usize, event: usize, context: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    if (clonewars_collision_observer_enabled == 0) {
        const allowed = geometry_phase(obs.word(packet +% 0xc)) != 0;
        machine.restore();
        if (allowed) original_manager(manager, packet, event, context);
        return;
    }
    var s: ManagerScope = .{ .machine = machine, .manager = manager, .packet = packet, .event = event, .context = context, .previous_manager = active_manager, .previous_ordinal = active_ordinal, .scratch = 0, .saved = 0 };
    const sequence = game_sync_sequence();
    if (last_sequence != sequence) {
        last_sequence = sequence;
        manager_ordinal = 0;
    }
    const id = obs.increment(&clonewars_collision_debug[2]);
    manager_ordinal +%= 1;
    const ordinal = manager_ordinal;
    active_manager = id;
    active_ordinal = ordinal;
    const pool = obs.word(0xfb2f60);
    var count = obs.word(0xfb2e3c);
    if (obs.word(packet +% 0xc) != 0) {
        count = 0;
        clonewars_collision_debug[6] +%= 1;
    }
    if (count > 4096) {
        count = 4096;
        clonewars_collision_debug[4] +%= 1;
    }
    if (count != 0) {
        s.scratch = obs.HeapAlloc(obs.GetProcessHeap(), 8, count * @sizeOf(t.Phase));
        if (s.scratch == 0) clonewars_collision_debug[3] +%= 1;
    }
    if (s.scratch != 0) for (0..count) |slot| {
        const actor = pool +% slot *% 0x1440;
        if (obs.word(actor +% 0x50) & 3 != 3) continue;
        const r = &@as([*]t.Phase, @ptrFromInt(s.scratch))[s.saved];
        s.saved += 1;
        r.id = obs.increment(&clonewars_collision_geometry_count);
        r.manager_id = id;
        r.manager_ordinal = ordinal;
        r.thread = win.GetCurrentThreadId();
        r.sequence = sequence;
        r.manager_local = @truncate(manager);
        r.packet_mode = obs.word(packet +% 0xc);
        r.event_word = obs.word(event);
        r.ordinal = @intCast(slot);
        obs.timestamp(&r.qpc_before_low, &r.qpc_before_high);
        r.clock = obs.word(0xfb4b6c);
        r.rng_game = obs.word(0xe637b4);
        r.rng_engine = obs.word(0xea178c);
        snapshot.geometry(&r.before, actor);
    };
    _ = constructor_lexical_seh(@intFromPtr(&s), managerInvoke, managerAbort);
    s.machine.restore();
}
pub export fn collision_observer_install() c_int {
    const addresses = [_]usize{ 0x81e860, 0x863410 };
    const prefixes = [_][]const u8{ "\x55\x8b\xec\x83\xe4\xf0", "\x81\xec\xcc\x00\x00\x00" };
    const hooks = [_]usize{ @intFromPtr(&queryHook), @intFromPtr(&managerHook) };
    for (addresses, prefixes) |address, prefix| if (!win.accessible(address, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..prefix.len], prefix)) {
        clonewars_collision_observer_installed = -1;
        return 0;
    };
    for (addresses, prefixes, hooks, 0..) |address, prefix, hook, i| {
        const bridge = obs.install(address, prefix, hook) orelse {
            clonewars_collision_observer_installed = -1;
            return 0;
        };
        if (i == 0) original_query = @ptrFromInt(bridge) else original_manager = @ptrFromInt(bridge);
        _ = @atomicRmw(i32, &clonewars_collision_observer_installed, .Or, @as(i32, 1) << @intCast(i), .seq_cst);
    }
    geometry_manager_ready();
    return 1;
}
