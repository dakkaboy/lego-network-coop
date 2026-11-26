const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
pub export var clonewars_spellit_admission_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_eligibility_debug: [10]u32 = @splat(0);
pub export var clonewars_spellit_manager_debug: [10]u32 = @splat(0);

pub export fn spellit_gungan_action100_admitted(actor: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op) or s.journal.host != 0) return 0;
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if (frame.level != 24 or cursor == 0 or cursor + 2 >= frame.fire_task_gate_count or actor != s.read(usize, 0xfb4944) or
        !s.valid(actor, 0x1440) or s.read(i16, actor + 0xdc0) != 176 or s.read(i16, actor + 0x2f4) != 100 or s.read(i32, 0xe6afb8) != 100) return 0;
    const previous = &frame.fire_task_gates[cursor - 1];
    const clock = s.read(u32, 0xfb4b6c);
    if (previous.kind != p.SYNC_ACTOR_CHARACTER_MOTION or previous.character != 176 or previous.payload.character_motion.clock != clock) return 0;
    const identity = s.reference(previous);
    for ([_]u16{ 4, 5, 2 }, [_]c_int{ 0, 1, 1 }, cursor..) |stage, outcome, index| {
        const entry = &frame.fire_task_gates[index];
        if (s.early_actor_gates.isSet(index) or entry.kind != p.SYNC_ACTOR_SPELLIT_ADMISSION or entry.flags != stage or entry.action != 0 or
            entry.value != outcome or entry.payload.state.repeat != clock or
            !@import("validation.zig").equal(&identity, &s.reference(entry))) return 0;
    }
    return @intFromBool(s.entities_resolve_reference(&identity) == actor and s.live(&op));
}

fn missingManagerStage(op: *const s.Lease, actor: usize, stage: u32, clock: u32) bool {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if (s.journal.host != 0 or (frame.level != 24 and frame.level != 74) or stage < 4 or cursor == 0 or cursor >= frame.fire_task_gate_count) return false;
    const previous = &frame.fire_task_gates[cursor - 1];
    const next = &frame.fire_task_gates[cursor];
    if (previous.kind != p.SYNC_ACTOR_CHARACTER_MOTION or previous.payload.character_motion.clock != clock or previous.slot == next.slot) return false;
    const character = s.read(u16, actor + 0xdc0);
    const motion_order = if (frame.level == 74)
        character == 188 and next.character == 199
    else
        character == 176;
    const next_motion = motion_order and next.kind == p.SYNC_ACTOR_CHARACTER_MOTION and next.payload.character_motion.clock == clock;
    const next_tick = frame.level == 24 and character == 138 and next.kind == p.SYNC_ACTOR_RTS_COMPETITOR and next.payload.competitor.clock == clock +% 1;
    if (!next_motion and !next_tick) return false;
    const identity = s.reference(previous);
    if (s.entities_resolve_reference(&identity) != actor or !s.live(op)) return false;
    // The host moved on after this actor's motion without a manager update.
    for (frame.fire_task_gates[cursor..frame.fire_task_gate_count]) |entry| {
        if (entry.kind == p.SYNC_ACTOR_SPELLIT_ADMISSION and entry.flags >= 4 and entry.slot == previous.slot and
            entry.generation == previous.generation and entry.payload.state.repeat == clock) return false;
    }
    return true;
}

fn absentSwampBuildEligibility(op: *const s.Lease, actor: usize, stage: u32, clock: u32) bool {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if (s.journal.host != 0 or frame.level != 70 or stage != 3 or cursor == 0 or
        cursor != frame.fire_task_gate_count or actor != s.read(usize, 0xfb4944) or
        s.read(i16, actor + 0xdc0) != 156) return false;
    const last = &frame.fire_task_gates[cursor - 1];
    if (last.kind != p.SYNC_ACTOR_CHARACTER_MOTION or last.character != 156 or
        last.payload.character_motion.clock != clock) return false;
    const identity = s.reference(last);
    return s.entities_resolve_reference(&identity) == actor and s.live(op);
}

pub export fn cadence_spellit_admission(actor: usize, kind: u32, stage: u32, local: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return local;
    const local_valid = if (stage == 0) local == 0 or local == actor +% 0xee4 or local == actor +% 0xeec or local == actor +% 0xef0 else local <= 1;
    const valid_kind = if (stage <= 1) kind == 0x24 or kind == 0x25 else kind == 0;
    if (stage > 5 or !valid_kind or !s.valid(actor, 0x1440) or !local_valid) {
        s.journal.failed = 20;
        s.failed(&op, actor, null, 20);
        return local;
    }
    var state = std.mem.zeroes(p.SyncFireTaskState);
    state.repeat = s.read(u32, 0xfb4b6c);
    if (missingManagerStage(&op, actor, stage, state.repeat) or absentSwampBuildEligibility(&op, actor, stage, state.repeat)) return 0;
    const result = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, @intCast(stage), @intCast(kind), @intFromBool(local != 0), @ptrCast(&state), &clonewars_spellit_admission_debug);
    if (stage >= 2 and s.live(&op) and s.journal.failed == 0) {
        const debug = if (stage >= 4) &clonewars_spellit_manager_debug else &clonewars_spellit_eligibility_debug;
        const part = if (stage >= 4) stage - 4 else stage - 2;
        debug[part] +%= 1;
        if ((local != 0) != (result != 0)) {
            debug[part + 2] +%= 1;
            if (debug[4] == 0 and s.valid(actor, 0x1440)) debug[4..10].* = .{ state.repeat, stage, s.read(u16, actor + 0xdc0), s.read(u16, actor + 0x2f4), local, @intFromBool(result != 0) };
        }
    }
    return if ((local != 0) == (result != 0)) local else @bitCast(result);
}
