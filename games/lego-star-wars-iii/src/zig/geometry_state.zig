const std = @import("std");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const types = @import("geometry_types.zig");
const Journal = types.Journal;
const Batch = types.Batch;
const Token = @import("cohort_types.zig").Token;
const Lease = @import("cohort_types.zig").Lease;
var binding: @import("cohort_binding.zig").Binding = .{};
var journal = std.mem.zeroes(Journal);
var active = false;
var cancelled = false;
var last_epoch: u32 = 0;
pub export var clonewars_geometry_installed: i32 = 0;
pub export var clonewars_geometry_debug: [20]u32 = @splat(0);
pub export var clonewars_geometry_failure: [14]u32 = @splat(0);
extern fn geometry_journal_begin(*Journal, *p.SyncFrame, c_int) void;
extern fn geometry_journal_phase(*Journal, u32, *Batch) c_int;
extern fn geometry_journal_record(*Journal, *const p.SyncCollider) c_int;
extern fn geometry_journal_validate(*Journal, *const p.SyncCollider, c_int) c_int;
extern fn geometry_journal_commit(*Journal, *const Batch) c_int;
extern fn geometry_journal_finish(*const Journal) c_int;
extern fn physics_input_install() c_int;
extern fn physics_input_cancel() void;
extern fn physics_input_begin(*p.SyncFrame, c_int) c_int;
extern fn physics_input_finish() c_int;
extern fn entities_update() void;
extern fn entities_describe(*p.SyncActor, usize) void;
extern fn entities_resolve_reference(*const p.SyncActor) usize;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn entities_observed_generation(usize) u32;
extern fn game_actor_count() c_int;
extern fn game_sync_native_fault(c_int) void;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn live(op: *const Lease) bool {
    return binding.live(op) and journal.frame != null and @intFromPtr(journal.frame.?) == op.cohort.frame;
}
pub export fn geometry_bind_cohort(original: ?*const Token) c_int {
    return @intFromBool(binding.bind(original));
}
pub export fn geometry_frame_lease_get(output: ?*Lease) c_int {
    return @intFromBool(binding.get(output));
}
pub export fn geometry_frame_cancelled(op: ?*const Lease) c_int {
    return @intFromBool(binding.cancelled(op));
}
pub export fn geometry_abort_frame(op: ?*const Lease) c_int {
    if (!binding.detach(op)) return 0;
    active = false;
    cancelled = true;
    physics_input_cancel();
    journal = std.mem.zeroes(Journal);
    return 1;
}
fn fail(op: *const Lease, entry: ?*const p.SyncCollider, actual: usize, mode: u32, batch_count: u32, active_count: u32, reason: c_int) c_int {
    if (!live(op)) return 0;
    if (journal.failed == 0) journal.failed = reason;
    if (clonewars_geometry_failure[0] == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = entities_observed_identity(actual, &slot, &generation);
        if (!live(op)) return 0;
        const local_generation = entities_observed_generation(actual);
        if (!live(op)) return 0;
        clonewars_geometry_failure = .{ journal.frame.?.epoch, journal.frame.?.sequence, journal.ordinal, @bitCast(journal.failed), if (entry) |e| e.slot else std.math.maxInt(u32), if (entry) |e| e.generation else 0, slot, generation, local_generation, batch_count, active_count, mode, journal.cursor, journal.validated };
        clonewars_geometry_debug[15] = journal.frame.?.sequence;
        clonewars_geometry_debug[16] = @bitCast(journal.failed);
    }
    if (!live(op)) return 0;
    clonewars_geometry_debug[5] +%= 1;
    game_sync_native_fault(15);
    return 0;
}
pub export fn geometry_manager_ready() void {
    @atomicStore(i32, &clonewars_geometry_installed, if (physics_input_install() != 0) 1 else -1, .seq_cst);
}
pub export fn geometry_ready() c_int {
    return @intFromBool(clonewars_geometry_installed == 1);
}
pub export fn geometry_cancel() void {
    if (binding.bound or binding.lease.cohort.thread == 0 or binding.lease.cohort.thread != win.GetCurrentThreadId()) return;
    active = false;
    cancelled = true;
    physics_input_cancel();
    journal = std.mem.zeroes(Journal);
}
pub export fn geometry_begin(frame: *p.SyncFrame, host: c_int) c_int {
    if (!binding.begin(@intFromPtr(frame))) return 0;
    const op = binding.lease;
    if (!binding.live(&op)) return 0;
    cancelled = false;
    if (last_epoch != op.cohort.epoch) {
        @memset(&clonewars_geometry_failure, 0);
        last_epoch = op.cohort.epoch;
    }
    geometry_journal_begin(&journal, frame, host);
    active = true;
    return @intFromBool(live(&op) and physics_input_begin(frame, host) != 0);
}
fn identity(entry: *const p.SyncCollider) p.SyncActor {
    var result = std.mem.zeroes(p.SyncActor);
    result.slot = entry.slot;
    result.generation = entry.generation;
    result.spawn_tag = entry.spawn_tag;
    result.spawn_source = entry.spawn_source;
    result.character = entry.character;
    result.spawn_position = entry.origin;
    return result;
}
pub export fn geometry_phase(mode: u32) c_int {
    if (!active) return @intFromBool(!binding.bound);
    var op: Lease = undefined;
    if (!binding.get(&op) or !live(&op) or journal.failed != 0) return 0;
    var batch: Batch = undefined;
    if (geometry_journal_phase(&journal, mode, &batch) == 0) return fail(&op, null, 0, mode, 0, 0, 3);
    clonewars_geometry_debug[if (journal.host != 0) 6 else 7] +%= 1;
    if (mode != 0) {
        clonewars_geometry_debug[8] +%= 1;
        return if (journal.host != 0 or geometry_journal_commit(&journal, &batch) != 0) 1 else fail(&op, null, 0, mode, batch.count, 0, 3);
    }
    entities_update();
    if (!live(&op)) return 0;
    const pool = read(usize, 0xfb2f60);
    const count = game_actor_count();
    if (!live(&op)) return 0;
    if (count < 0 or count > p.SYNC_MAX_ACTORS or (count != 0 and !win.accessible(pool, @as(usize, @intCast(count)) * 0x1440, false))) return fail(&op, null, 0, mode, batch.count, 0, 4);
    const size: u32 = @intCast(count);
    if (journal.host != 0) {
        var recorded: u32 = 0;
        for (0..size) |slot| {
            if (!live(&op)) return 0;
            const actor = pool + slot * 0x1440;
            if (read(u32, actor + 0x50) & 3 != 3) continue;
            var owner = std.mem.zeroes(p.SyncActor);
            entities_describe(&owner, actor);
            if (!live(&op)) return 0;
            const entry = p.SyncCollider{ .manager_ordinal = journal.ordinal, .slot = @intCast(slot), .generation = owner.generation, .spawn_tag = owner.spawn_tag, .spawn_source = owner.spawn_source, .character = read(i16, actor + 0xdc0), .origin = owner.spawn_position, .bounds = read([6]f32, actor + 0x30), .center = read([3]f32, actor + 0xf28), .extents = read([2]f32, actor + 0x1088) };
            if (geometry_journal_record(&journal, &entry) == 0) return fail(&op, &entry, actor, mode, recorded, recorded, 2);
            recorded += 1;
            clonewars_geometry_debug[0] +%= 1;
        }
        clonewars_geometry_debug[17] = recorded;
        clonewars_geometry_debug[18] = recorded;
        return 1;
    }
    var resolved: [p.SYNC_MAX_ACTORS]usize = undefined;
    var generations: [p.SYNC_MAX_ACTORS]u32 = undefined;
    var claimed: [p.SYNC_MAX_ACTORS]bool = @splat(false);
    var active_count: u32 = 0;
    for (0..batch.count) |index| {
        if (!live(&op)) return 0;
        const entry = &journal.frame.?.geometry[batch.start + index];
        const owner = identity(entry);
        const actor = entities_resolve_reference(&owner);
        if (!live(&op)) return 0;
        resolved[index] = actor;
        const offset = actor -% pool;
        const matches = actor != 0 and offset % 0x1440 == 0 and offset / 0x1440 < size and win.accessible(actor, 0x1440, false) and read(u32, actor + 0x50) & 3 == 3;
        if (geometry_journal_validate(&journal, entry, @intFromBool(matches)) == 0) return fail(&op, entry, actor, mode, batch.count, 0, journal.failed);
        const slot = offset / 0x1440;
        if (claimed[slot]) return fail(&op, entry, actor, mode, batch.count, 0, 5);
        claimed[slot] = true;
        generations[index] = entities_observed_generation(actor);
    }
    for (0..size) |slot| if (read(u32, pool + slot * 0x1440 + 0x50) & 3 == 3) {
        active_count += 1;
        if (!claimed[slot]) return fail(&op, null, pool + slot * 0x1440, mode, batch.count, active_count, 6);
    };
    for (0..batch.count) |index| {
        if (!live(&op)) return 0;
        const actor = resolved[index];
        if (!win.accessible(actor, 0x1440, false) or read(u32, actor + 0x50) & 3 != 3 or generations[index] == 0 or entities_observed_generation(actor) != generations[index]) return fail(&op, &journal.frame.?.geometry[batch.start + index], actor, mode, batch.count, active_count, 4);
    }
    if (!live(&op)) return 0;
    if (active_count != batch.count or geometry_journal_commit(&journal, &batch) == 0) return fail(&op, null, 0, mode, batch.count, active_count, 3);
    for (0..batch.count) |index| {
        if (!live(&op)) return 0;
        const entry = &journal.frame.?.geometry[batch.start + index];
        const actor = resolved[index];
        clonewars_geometry_debug[2] +%= @intFromBool(!equal(&read([6]f32, actor + 0x30), &entry.bounds));
        clonewars_geometry_debug[3] +%= @intFromBool(!equal(&read([3]f32, actor + 0xf28), &entry.center));
        clonewars_geometry_debug[4] +%= @intFromBool(!equal(&read([2]f32, actor + 0x1088), &entry.extents));
        win.store([6]f32, actor + 0x30, entry.bounds);
        win.store([3]f32, actor + 0xf28, entry.center);
        win.store([2]f32, actor + 0x1088, entry.extents);
        clonewars_geometry_debug[1] +%= 1;
        clonewars_geometry_debug[13] = entry.slot;
        clonewars_geometry_debug[14] = entry.generation;
    }
    clonewars_geometry_debug[11] = journal.frame.?.sequence;
    clonewars_geometry_debug[12] = journal.ordinal;
    clonewars_geometry_debug[17] = batch.count;
    clonewars_geometry_debug[18] = active_count;
    return 1;
}
pub export fn geometry_finish() c_int {
    var op: Lease = undefined;
    if (!binding.get(&op) or !live(&op) or !active or cancelled or physics_input_finish() == 0) return 0;
    active = false;
    clonewars_geometry_debug[9] +%= 1;
    if (geometry_journal_finish(&journal) == 0) {
        clonewars_geometry_debug[10] +%= 1;
        if (journal.failed == 0) return fail(&op, null, 0, 0, 0, 0, 7);
        return 0;
    }
    return 1;
}
