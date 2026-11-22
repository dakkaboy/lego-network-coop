const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
pub export var clonewars_force_target_failure: [20]u32 = @splat(0);
fn hostScannedForceCaster(frame: *const p.SyncFrame, query: *const p.SyncForceQueryState) bool {
    for (frame.fire_task_gates[0..frame.fire_task_gate_count]) |*entry| {
        if (entry.kind != p.SYNC_ACTOR_FORCE_VISIBILITY) continue;
        const host = &entry.payload.force;
        if (host.caster_slot == query.caster_slot and host.caster_generation == query.caster_generation) return true;
    }
    return false;
}
pub export fn cadence_force_target_visibility(candidate: usize, caster: usize, mode: u32, visible: c_int) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return visible;
    if (!s.valid(candidate, 0x1440) or !s.valid(caster, 0x1440)) {
        s.journal.failed = 11;
        s.clonewars_force_target_debug[3] +%= 1;
        s.failed(&op, candidate, null, 11);
        return visible;
    }
    s.entities_update();
    if (!s.live(&op)) return visible;
    var input = std.mem.zeroes(p.SyncForceQueryState);
    input.mode = mode;
    input.clock = s.read(u32, 0xfb4b6c);
    if (s.entities_observed_identity(caster, &input.caster_slot, &input.caster_generation) == 0) {
        s.journal.failed = 11;
        s.clonewars_force_target_debug[3] +%= 1;
        s.failed(&op, candidate, null, 11);
        return visible;
    }
    const local: c_int = @intFromBool(visible != 0);
    const frame = s.journal.frame.?;
    // An extra local scan must not pick a target for a player the host did not scan.
    if (frame.level == 79 and s.journal.host == 0 and s.journal.failed == 0 and
        input.caster_slot < 2 and (mode == 1 or mode == 2) and !hostScannedForceCaster(frame, &input))
    {
        s.clonewars_force_target_debug[2] +%= @intFromBool(local != 0);
        return 0;
    }
    const epoch = frame.epoch;
    const sequence = frame.sequence;
    const controls = frame.inputs;
    const result = gate.apply(candidate, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, local, @ptrCast(&input), &s.clonewars_force_target_debug);
    const failure = &s.clonewars_actor_gate_failure;
    if (clonewars_force_target_failure[0] == 0 and failure[0] == epoch and failure[1] == sequence and failure[3] == p.SYNC_ACTOR_FORCE_VISIBILITY) {
        clonewars_force_target_failure = .{
            epoch,                      sequence,                input.clock,                    mode,                        @truncate(candidate),           @truncate(caster),
            input.caster_slot,          input.caster_generation, s.read(u16, candidate + 0xdc0), s.read(u16, caster + 0xdc0), s.read(u16, candidate + 0x2f4), s.read(u16, caster + 0x2f4),
            controls[0].held,           controls[0].pressed,     controls[1].held,               controls[1].pressed,         s.read(u32, 0xf91eb4),          s.read(u32, candidate + 0x50),
            s.read(u32, caster + 0x50), @intCast(local),
        };
    }
    if (result != local and s.clonewars_force_target_correction[0] == 0 and s.live(&op) and s.journal.failed == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = s.entities_observed_identity(candidate, &slot, &generation);
        if (s.live(&op)) s.clonewars_force_target_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, @bitCast(local), @bitCast(result), input.clock, input.caster_slot, input.caster_generation, mode };
    }
    return result;
}
pub export fn cadence_force_geometry_input(candidate: usize, caster: usize, mode: u32, points: [*]f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    if (!s.valid(candidate, 0x1440) or !s.valid(caster, 0x1440) or !s.valid(@intFromPtr(points), 24)) {
        reject(&op, candidate);
        return;
    }
    s.entities_update();
    if (!s.live(&op)) return;
    var input = std.mem.zeroes(p.SyncForceGeometryState);
    input.mode = mode;
    input.clock = s.read(u32, 0xfb4b6c);
    if (s.entities_observed_identity(caster, &input.caster_slot, &input.caster_generation) == 0) {
        reject(&op, candidate);
        return;
    }
    input.caster_position = points[0..3].*;
    input.candidate_position = points[3..6].*;
    const local = input;
    _ = gate.apply(candidate, p.SYNC_ACTOR_FORCE_GEOMETRY, 0, 0, 0, @ptrCast(&input), &s.clonewars_force_geometry_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0 or s.journal.host != 0) return;
    if (!equal(&local.caster_position, &input.caster_position) or !equal(&local.candidate_position, &input.candidate_position)) {
        s.clonewars_force_geometry_debug[2] +%= 1;
        if (s.clonewars_force_geometry_correction[0] == 0) {
            var slot: u32 = std.math.maxInt(u32);
            var generation: u32 = 0;
            _ = s.entities_observed_identity(candidate, &slot, &generation);
            if (!s.live(&op)) return;
            var values: [20]u32 = @splat(0);
            values[0..8].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, input.clock, input.caster_slot, input.caster_generation, mode };
            values[8..11].* = @bitCast(local.caster_position);
            values[11..14].* = @bitCast(local.candidate_position);
            values[14..17].* = @bitCast(input.caster_position);
            values[17..20].* = @bitCast(input.candidate_position);
            s.clonewars_force_geometry_correction = values;
        }
    }
    points[0..3].* = input.caster_position;
    points[3..6].* = input.candidate_position;
}
fn reject(op: *const s.Lease, actor: usize) void {
    s.journal.failed = 13;
    s.clonewars_force_geometry_debug[3] +%= 1;
    s.failed(op, actor, null, 13);
}
