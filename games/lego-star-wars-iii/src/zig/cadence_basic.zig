const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
extern fn cadence_journal_record(*s.Journal, *const p.SyncCadence) c_int;
extern fn cadence_journal_apply(*s.Journal, ?*const p.SyncCadence, c_int, u32, *u32, *f32) c_int;
pub export fn cadence_apply_period(actor: usize, period: *u32) void {
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    if (!s.valid(actor, 0x1440) or !s.valid(@intFromPtr(period), 4)) {
        s.journal.failed = 4;
        s.failed(&op, actor, null, 4);
        return;
    }
    const elapsed: *align(1) f32 = @ptrFromInt(actor + 0xe28);
    const phase = s.read(u8, actor + 0x57);
    if (s.journal.host != 0) {
        s.entities_update();
        if (!s.live(&op)) return;
        var identity = std.mem.zeroes(p.SyncActor);
        s.entities_describe(&identity, actor);
        if (!s.live(&op)) return;
        const slot = s.entities_slot(actor);
        if (!s.live(&op)) return;
        var entry = std.mem.zeroes(p.SyncCadence);
        entry.slot = @bitCast(slot);
        entry.generation = identity.generation;
        entry.spawn_tag = identity.spawn_tag;
        entry.spawn_source = identity.spawn_source;
        entry.character = s.read(i16, actor + 0xdc0);
        entry.period = period.*;
        entry.phase = phase;
        entry.elapsed = elapsed.*;
        entry.origin = identity.spawn_position;
        if (cadence_journal_record(&s.journal, &entry) == 0) {
            s.failed(&op, actor, &entry, 4);
            return;
        }
        s.clonewars_cadence_debug[0] +%= 1;
    } else {
        const entry = s.journal.peek();
        var identity = std.mem.zeroes(p.SyncActor);
        if (entry) |e| {
            identity.slot = e.slot;
            identity.generation = e.generation;
            identity.spawn_tag = e.spawn_tag;
            identity.spawn_source = e.spawn_source;
            identity.character = e.character;
            identity.spawn_position = e.origin;
        }
        const local_period = period.*;
        const local_elapsed = s.bits(elapsed.*);
        const matches = entry != null and s.entities_resolve_reference(&identity) == actor;
        if (!s.live(&op)) return;
        // Journal ABI accepts a naturally aligned timer; the engine field itself may be unaligned.
        var authoritative_elapsed = elapsed.*;
        if (cadence_journal_apply(&s.journal, entry, @intFromBool(matches), phase, period, &authoritative_elapsed) == 0) {
            s.failed(&op, actor, entry, @bitCast(s.journal.failed));
            return;
        }
        elapsed.* = authoritative_elapsed;
        const e = entry.?;
        s.clonewars_cadence_debug[1] +%= 1;
        s.clonewars_cadence_debug[2] +%= @intFromBool(local_period != e.period);
        s.clonewars_cadence_debug[3] +%= @intFromBool(local_elapsed != s.bits(e.elapsed));
        s.clonewars_cadence_debug[5..15].* = .{ e.slot, e.generation, local_period, e.period, phase, e.phase, local_elapsed, s.bits(e.elapsed), s.journal.frame.?.sequence, s.journal.cursor };
    }
}
fn fireTask(actor: usize, task: usize, allowed: c_int, delta: *f32) c_int {
    const flags = s.read(u16, task + 4);
    if (flags & p.SYNC_FIRE_TASK_QUEUES_SHOT == 0) return allowed;
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return allowed;
    if (!s.valid(task, 0x30) or !s.valid(@intFromPtr(delta), 4)) {
        s.failed(&op, actor, null, 5);
        return 0;
    }
    const action = s.read(u16, task + 6);
    var input = std.mem.zeroes(p.SyncFireTaskState);
    input.repeat = s.read(u8, task + 2);
    input.delta = delta.*;
    input.timers = s.read([4]f32, task + 8);
    input.target = s.read([3]f32, task + 0x20);
    const result = gate.apply(actor, p.SYNC_FIRE_TASK_VISIBILITY, flags, action, allowed, @ptrCast(&input), &s.clonewars_fire_task_gate_debug);
    if (!s.live(&op) or s.journal.failed != 0 or !s.active) return 0;
    if (s.journal.host == 0) {
        s.win.store(u8, task + 2, @truncate(input.repeat));
        s.win.store([4]f32, task + 8, input.timers);
        s.win.store([3]f32, task + 0x20, input.target);
        delta.* = input.delta;
    }
    return result;
}
pub export fn cadence_apply_fire_task_gate(actor: usize, task: usize, allowed: c_int, delta: *f32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return fireTask(actor, task, allowed, delta);
}
pub export fn cadence_apply_attack_support(actor: usize, support: *c_int) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (s.ready(&lease) and s.journal.host == 0) {
        const frame = s.journal.frame.?;
        const cursor = s.fire_task_cursor;
        if (frame.level == 74 and cursor != 0 and cursor <= frame.fire_task_gate_count) {
            const previous = &frame.fire_task_gates[cursor - 1];
            const clock = s.read(u32, 0xfb4b6c);
            const next_is_jar = cursor < frame.fire_task_gate_count and movedOnToJarJar(&frame.fire_task_gates[cursor], previous.slot, clock);
            const declined = previous.kind == p.SYNC_ACTOR_SPELLIT_ADMISSION and previous.flags == 3 and
                previous.action == 0 and previous.value == 0 and previous.payload.state.repeat == clock;
            const bomb_room = next_is_jar and previous.kind == p.SYNC_ACTOR_CHARACTER_MOTION and
                previous.payload.character_motion.clock == clock and s.valid(actor, 0x1440) and
                s.read(f32, actor + 0x24) < -17 and s.read(f32, actor + 0x2c) > 24;
            if (previous.character == 188 and ((declined and (next_is_jar or cursor == frame.fire_task_gate_count)) or bomb_room)) {
                const identity = s.reference(previous);
                if (s.entities_resolve_reference(&identity) == actor and s.live(&lease)) return 1;
            }
        }
    }
    const native = support.*;
    const authoritative = gate.apply(actor, p.SYNC_FIRE_ATTACK_SUPPORT, 0, 0, native, null, &s.clonewars_attack_support_debug);
    if (authoritative != native) support.* = authoritative;
    return 0;
}
fn movedOnToJarJar(next: *const p.SyncFireTaskGate, padme_slot: u32, clock: u32) bool {
    return next.kind == p.SYNC_ACTOR_CHARACTER_MOTION and next.character == 199 and next.slot != padme_slot and
        next.payload.character_motion.clock == clock;
}
fn recordVisibility(actor: usize, local: c_int, result: c_int, correction: *[8]u32, site: u32) void {
    var op: s.Lease = undefined;
    if (result != local and correction[0] == 0 and s.ready(&op)) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = s.entities_observed_identity(actor, &slot, &generation);
        if (s.live(&op)) correction.* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, @bitCast(local), @bitCast(result), s.read(u32, 0xfb4b6c), site };
    }
}
fn visibility(actor: usize, local: c_int, kind: u32, debug: *[4]u32, correction: *[8]u32, site: u32) c_int {
    const result = gate.apply(actor, kind, 0, 0, local, null, debug);
    recordVisibility(actor, local, result, correction, site);
    return result;
}
pub export fn cadence_apply_breakup_visibility(actor: usize, hidden: c_int) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return visibility(actor, hidden, p.SYNC_ACTOR_BREAKUP_VISIBILITY, &s.clonewars_breakup_visibility_debug, &s.clonewars_breakup_visibility_correction, 0x968a94);
}
pub export fn cadence_apply_fall_visibility(actor: usize, visible: c_int) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return visibility(actor, visible, p.SYNC_ACTOR_FALL_VISIBILITY, &s.clonewars_fall_visibility_debug, &s.clonewars_fall_visibility_correction, 0x9c49b3);
}
pub export fn cadence_apply_death_breakup(actor: usize, argument: *u32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local: c_int = @intFromBool(argument.* != 0);
    const result = gate.apply(actor, p.SYNC_ACTOR_DEATH_BREAKUP, 0, 0, local, null, &s.clonewars_death_breakup_debug);
    if (result != local) {
        argument.* = @bitCast(result);
        recordVisibility(actor, local, result, &s.clonewars_death_breakup_correction, 0x968f14);
    }
}
