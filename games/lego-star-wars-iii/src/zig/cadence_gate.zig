const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const equal = @import("validation.zig").equal;
extern fn physics_effect_body_resolve(u32, u32) usize;
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
pub export var clonewars_aim_task_context_failure: [22]u32 = @splat(0);
fn supportAcquisition(local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    if (!@import("character_support.zig").canAcquire(local, expected)) return false;
    if (local.support_frame == 0) return true;
    const body = @import("support_reference.zig").resolve(expected);
    var source: [2]u32 = @splat(0);
    return @import("character_support.zig").accepts(body, expected) and
        @import("support_reference.zig").source(body, expected, &source) and source[0] == expected.support_frame and source[1] == expected.support_event;
}
fn length(kind: u32) usize {
    return switch (kind) {
        p.SYNC_ACTOR_RTS_COMPETITOR => @sizeOf(p.SyncRtsCompetitorState),
        p.SYNC_ACTOR_FORCE_GEOMETRY => @sizeOf(p.SyncForceGeometryState),
        p.SYNC_ACTOR_CHARACTER_MOTION => @sizeOf(p.SyncCharacterMotionState),
        p.SYNC_ACTOR_SPELLIT_NODE => @sizeOf(p.SyncSpellItNodeState),
        p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY => @sizeOf(p.SyncScriptShootState),
        p.SYNC_ACTOR_PRIMARY_PERCEPTION => @sizeOf(p.SyncPrimaryPerceptionState),
        p.SYNC_ACTOR_RIDER_FIRE => @sizeOf(p.SyncRiderFireState),
        p.SYNC_ACTOR_ARENA_RUN_RANDOM => @sizeOf(p.SyncArenaRunRandomState),
        p.SYNC_ACTOR_BARC_SUSPENSION => @sizeOf(p.SyncBarcSuspensionState),
        p.SYNC_ACTOR_BARC_ALIGNMENT => @sizeOf(p.SyncBarcAlignmentState),
        p.SYNC_ACTOR_TUBE_CONTACT => @sizeOf([3]f32),
        p.SYNC_ACTOR_MELEE_CONTACT => @sizeOf(p.SyncMeleeContact),
        p.SYNC_ACTOR_SABER_TARGET => @sizeOf(p.SyncSaberQueue),
        p.SYNC_ACTOR_PROJECTILE_BRANCH => @sizeOf([2]u32),
        p.SYNC_ACTOR_FORCE_ELIGIBILITY => @sizeOf([4]u32),
        else => @sizeOf(p.SyncFireTaskState),
    };
}
fn contextFailure(gate: *const p.SyncFireTaskGate, state: [*]const u8) u32 {
    const data = &gate.payload;
    switch (gate.kind) {
        p.SYNC_ACTOR_FORCE_ELIGIBILITY => if (!std.mem.eql(u8, data.storage[0..4], state[0..4])) return 20,
        p.SYNC_ACTOR_PROJECTILE_BRANCH => if (!std.mem.eql(u8, data.storage[0..8], state[0..8])) return 29,
        p.SYNC_ACTOR_SABER_TARGET => {
            const local = s.read(p.SyncSaberQueue, @intFromPtr(state));
            if (data.saber_target.clock != local.clock or
                (data.saber_target.mode != 0 and data.saber_target.mode != local.mode)) return 28;
        },
        p.SYNC_ACTOR_MELEE_CONTACT => if (!std.mem.eql(u8, data.storage[0..@offsetOf(p.SyncMeleeContact, "impact_time")], state[0..@offsetOf(p.SyncMeleeContact, "impact_time")])) {
            return 27;
        },
        p.SYNC_ACTOR_TUBE_CONTACT => if (!std.mem.eql(u8, data.storage[0..12], state[0..12])) {
            return 26;
        },
        p.SYNC_ACTOR_BARC_SUSPENSION => if (!std.mem.eql(u8, data.storage[0..@sizeOf(p.SyncBarcSuspensionState)], state[0..@sizeOf(p.SyncBarcSuspensionState)])) {
            return 25;
        },
        p.SYNC_ACTOR_BARC_ALIGNMENT => if (!std.mem.eql(u8, data.storage[0..8], state[0..8])) {
            return 24;
        },
        p.SYNC_ACTOR_ARENA_RUN_RANDOM => if (!std.mem.eql(u8, data.storage[0..@sizeOf(p.SyncArenaRunRandomState)], state[0..@sizeOf(p.SyncArenaRunRandomState)])) {
            return 22;
        },
        p.SYNC_ACTOR_RIDER_FIRE => if (!std.mem.eql(u8, data.storage[0..16], state[0..16])) {
            return 21;
        },
        p.SYNC_ACTOR_SPELLIT_ADMISSION, p.SYNC_ACTOR_HAZARD_DEATH => if (!std.mem.eql(u8, data.storage[0..4], state[0..4])) {
            return 20;
        },
        p.SYNC_ACTOR_AIM_TASK => {
            const a = &data.aim;
            const b = s.read(p.SyncAimTaskState, @intFromPtr(state));
            if (!@import("cadence_context.zig").aim(a, &b)) {
                const frame = s.journal.frame.?;
                if (clonewars_aim_task_context_failure[0] != frame.epoch) {
                    clonewars_aim_task_context_failure[0..4].* = .{ frame.epoch, frame.sequence, s.fire_task_cursor, gate.slot };
                    @memcpy(std.mem.sliceAsBytes(clonewars_aim_task_context_failure[4..13]), std.mem.asBytes(a));
                    @memcpy(std.mem.sliceAsBytes(clonewars_aim_task_context_failure[13..22]), std.mem.asBytes(&b));
                }
                return 7;
            }
        },
        p.SYNC_ACTOR_AIM_BASE => {
            const a = &data.aim_base;
            const b = s.read(p.SyncAimBaseState, @intFromPtr(state));
            if (a.clock != b.clock or a.task_class != b.task_class or a.callback_class != b.callback_class) return 12;
        },
        p.SYNC_ACTOR_FORCE_VISIBILITY => if (!std.mem.eql(u8, data.storage[0..@sizeOf(p.SyncForceQueryState)], state[0..@sizeOf(p.SyncForceQueryState)])) {
            return 11;
        },
        p.SYNC_ACTOR_FORCE_GEOMETRY => if (!std.mem.eql(u8, data.storage[0..16], state[0..16])) {
            return 13;
        },
        p.SYNC_ACTOR_CHARACTER_MOTION => {
            const local = s.read(p.SyncCharacterMotionState, @intFromPtr(state));
            const compatible = s.supportSame(&data.character_motion, &local) or supportAcquisition(&local, &data.character_motion) or @import("character_support.zig").canRelease(&local, &data.character_motion);
            if (!std.mem.eql(u8, data.storage[0..8], state[0..8]) or !compatible) {
                s.motionFailure(6, &local, &data.character_motion);
                return 16;
            }
        },
        p.SYNC_ACTOR_SPELLIT_QUERY => if (!std.mem.eql(u8, data.storage[0..12], state[0..12])) {
            return 15;
        },
        p.SYNC_ACTOR_SPELLIT_NODE, p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY => {
            const node = gate.kind == p.SYNC_ACTOR_SPELLIT_NODE;
            const words: usize = if (node) 13 else @sizeOf(p.SyncScriptShootState) / 4;
            if (!std.mem.eql(u8, data.storage[0 .. words * 4], state[0 .. words * 4])) {
                const failure = if (node) &s.clonewars_spellit_node_failure else &s.clonewars_script_shoot_failure;
                if (failure[0] == 0) {
                    var values: [16]u32 = @splat(0);
                    values[0] = s.journal.frame.?.epoch;
                    values[1] = s.journal.frame.?.sequence;
                    values[2] = 1;
                    if (!node) values[3] = s.read(u32, 0xfb4b6c);
                    const first: usize = if (node) 3 else 4;
                    for (0..words) |i| {
                        const a = s.read(u32, @intFromPtr(&data.storage) + i * 4);
                        const b = s.read(u32, @intFromPtr(state) + i * 4);
                        if (a != b) {
                            values[first] = @intCast(i);
                            values[first + 1] = a;
                            values[first + 2] = b;
                            break;
                        }
                    }
                    failure.* = values;
                }
                return if (node) 17 else 18;
            }
        },
        p.SYNC_ACTOR_RTS_COMPETITOR => {
            const b = s.read(p.SyncRtsCompetitorState, @intFromPtr(state));
            if (!@import("cadence_context.zig").competitor(&data.competitor, &b)) return 10;
        },
        else => {},
    }
    return 0;
}
fn combatDroid(character: i32) bool {
    return character == 321 or character == 333;
}
fn blueShadowDroidMotion(character: i32) bool {
    return combatDroid(character) or character == 337;
}
fn droidAim(kind: u32, character: i32) bool {
    return (kind == p.SYNC_ACTOR_AIM_BASE or kind == p.SYNC_ACTOR_AIM_TASK) and combatDroid(character);
}
fn blueShadowDroidDecision(entry: *const p.SyncFireTaskGate) bool {
    return droidAim(entry.kind, entry.character) or (entry.kind == p.SYNC_ACTOR_PRIMARY_PERCEPTION and
        (entry.flags == p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET or entry.flags == p.SYNC_PERCEPTION_SCRIPT_ASSIGNED_TARGET) and combatDroid(entry.character));
}
fn droidDecisionClock(entry: *const p.SyncFireTaskGate) u32 {
    return switch (entry.kind) {
        p.SYNC_ACTOR_AIM_BASE => entry.payload.aim_base.clock,
        p.SYNC_ACTOR_AIM_TASK => entry.payload.aim.clock,
        else => entry.payload.perception.clock,
    };
}
fn forceScan(kind: u32) bool {
    return kind == p.SYNC_ACTOR_FORCE_VISIBILITY or kind == p.SYNC_ACTOR_FORCE_GEOMETRY;
}
fn labCompanionAdmission(character: i32, kind: u32, flags: u16, action: u16) bool {
    return (character == 188 or character == 199) and kind == p.SYNC_ACTOR_SPELLIT_ADMISSION and
        (flags == 4 or flags == 5) and action == 0;
}
pub fn labForceRequestAdmission(clock: u32) ?p.SyncActor {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if (frame.level != 73 or cursor == 0 or cursor >= frame.fire_task_gate_count) return null;
    const previous = &frame.fire_task_gates[cursor - 1];
    if (previous.character != 184 or previous.payload.state.repeat != clock) return null;
    const caster = s.reference(previous);
    if (previous.kind != p.SYNC_ACTOR_SPELLIT_QUERY) {
        if (cursor < 4) return null;
        for ([_]u16{ 4, 5, 2, 3 }, [_]c_int{ 1, 1, 0, 0 }, cursor - 4..cursor) |stage, result, index| {
            const entry = &frame.fire_task_gates[index];
            if (entry.kind != p.SYNC_ACTOR_SPELLIT_ADMISSION or entry.flags != stage or entry.action != 0 or entry.value != result or
                entry.payload.state.repeat != clock or !equal(&caster, &s.reference(entry))) return null;
        }
    }
    return caster;
}

pub fn labForceRequestOwner(clock: u32) ?p.SyncActor {
    const caster = labForceRequestAdmission(clock) orelse return null;
    const next = &s.journal.frame.?.fire_task_gates[s.fire_task_cursor];
    if (next.kind != p.SYNC_ACTOR_FORCE_ELIGIBILITY or next.flags != 0 or !equal(&caster, &s.reference(next))) return null;
    return caster;
}

pub fn labForceRequestFollowedByCompanion(clock: u32) bool {
    const frame = s.journal.frame.?;
    const next = &frame.fire_task_gates[s.fire_task_cursor];
    return labCompanionAdmission(next.character, next.kind, next.flags, next.action) and next.payload.state.repeat == clock;
}
fn afterLabForce(clock: u32) ?usize {
    const caster = labForceRequestOwner(clock) orelse return null;
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    for (0..3) |stage| {
        if (cursor + stage >= frame.fire_task_gate_count) return null;
        const entry = &frame.fire_task_gates[cursor + stage];
        if (entry.kind != p.SYNC_ACTOR_FORCE_ELIGIBILITY or entry.flags != stage or
            !equal(&caster, &s.reference(entry))) return null;
        if (entry.value == 0 and stage < 2) return cursor + stage + 1;
        if (entry.value != 1) return null;
    }
    const target_index = endLabForceScan(frame, cursor + 3, &caster, clock, 1) orelse return null;
    if (target_index >= frame.fire_task_gate_count) return null;
    const target = &frame.fire_task_gates[target_index];
    if (target.kind != p.SYNC_ACTOR_FORCE_ELIGIBILITY or target.flags != 4 or !equal(&caster, &s.reference(target))) return null;
    if (target.value != 0) return target_index + 1;
    return endLabForceScan(frame, target_index + 1, &caster, clock, 2);
}
fn endLabForceScan(frame: *const p.SyncFrame, first: usize, caster: *const p.SyncActor, clock: u32, mode: u32) ?usize {
    var index = first;
    while (index < frame.fire_task_gate_count) : (index += 1) {
        const entry = &frame.fire_task_gates[index];
        if (!forceScan(entry.kind)) break;
        const query = &entry.payload.force;
        if (query.caster_slot != caster.slot or query.caster_generation != caster.generation or query.clock != clock or query.mode != mode) return null;
    }
    return if (index == first) null else index;
}
fn earlyLabCompanion(op: *const s.Lease, actor: usize, flags: u16, clock: u32, start: usize) ?c_int {
    const frame = s.journal.frame.?;
    var index = start;
    while (index < frame.fire_task_gate_count) : (index += 1) {
        const entry = &frame.fire_task_gates[index];
        if (!labCompanionAdmission(entry.character, entry.kind, entry.flags, entry.action) or entry.payload.state.repeat != clock) return null;
        if (entry.flags != flags or s.early_actor_gates.isSet(index)) continue;
        const owner = s.reference(entry);
        if (s.entities_resolve_reference(&owner) == actor and s.live(op)) {
            s.early_actor_gates.set(index);
            return entry.value;
        }
        if (!s.live(op)) return null;
    }
    return null;
}
fn replayEarlyActorGate(op: *const s.Lease, actor: usize, kind: u32, flags: u16, action: u16, local: c_int, state: ?[*]u8, debug: *[4]u32) ?c_int {
    const frame = s.journal.frame.?;
    const head = &frame.fire_task_gates[s.fire_task_cursor];
    const competitor = frame.level == 79 and kind == p.SYNC_ACTOR_RTS_COMPETITOR and head.kind == kind;
    const party_spellit = (frame.level == 73 or frame.level == 74) and (kind == p.SYNC_ACTOR_SPELLIT_ADMISSION or kind == p.SYNC_ACTOR_SPELLIT_QUERY);
    const motion_character = if ((kind == p.SYNC_ACTOR_CHARACTER_MOTION or party_spellit) and state != null and s.valid(actor, 0x1440)) s.read(u16, actor + 0xdc0) else 0;
    const companion = frame.level == 79 and motion_character == 259;
    const lab_companion = labCompanionAdmission(motion_character, kind, flags, action);
    const lab_actor = frame.level == 73 and (motion_character == 138 or lab_companion);
    const lab_clock = if (lab_actor) s.read(u32, @intFromPtr(state.?)) else 0;
    const after_force = if (lab_actor and head.kind == p.SYNC_ACTOR_FORCE_ELIGIBILITY) afterLabForce(lab_clock) else null;
    if (lab_companion and after_force != null) {
        if (earlyLabCompanion(op, actor, flags, lab_clock, after_force.?)) |value| {
            debug[1] +%= 1;
            debug[2] +%= @intFromBool(local != value);
            return value;
        }
    }
    const lab_party = lab_actor and (head.kind == p.SYNC_ACTOR_FORCE_VISIBILITY or after_force != null);
    const corridor_party = frame.level == 74 and motion_character == 184 and s.read(f32, actor + 0x24) < 10 and
        head.kind == p.SYNC_ACTOR_FORCE_VISIBILITY and (kind == p.SYNC_ACTOR_CHARACTER_MOTION or
        (kind == p.SYNC_ACTOR_SPELLIT_ADMISSION and (flags == 4 or flags == 5) and action == 0));
    const blue_shadow_clone = (frame.level == 70 and motion_character == 156 and forceScan(head.kind)) or lab_party or corridor_party;
    const blue_shadow_droid = frame.level == 70 and blueShadowDroidMotion(motion_character) and blueShadowDroidDecision(head);
    const blue_shadow_motion = blue_shadow_clone or blue_shadow_droid;
    const droid_aim = (frame.level == 29 or frame.level == 70) and droidAim(head.kind, head.character) and s.valid(actor, 0x1440) and
        droidAim(kind, s.read(i16, actor + 0xdc0));
    if (!competitor and !companion and !blue_shadow_motion and !droid_aim) return null;
    if ((lab_party and after_force == null) or corridor_party) {
        const force = &head.payload.force;
        const caster = s.entities_actor(force.caster_slot, force.caster_generation);
        const caster_character: u16 = if (corridor_party) 181 else 184;
        if (!s.live(op) or !s.valid(caster, 0x1440) or s.read(u16, caster + 0xdc0) != caster_character or
            force.clock != s.read(u32, @intFromPtr(state.?))) return null;
        if (corridor_party and (caster != s.read(usize, 0xfb4944) or !(s.read(f32, caster + 0x24) < 10))) return null;
    }
    const motion_clock = if (blue_shadow_droid) s.read(u32, @intFromPtr(state.?)) else 0;
    if (blue_shadow_droid and droidDecisionClock(head) != motion_clock) return null;
    if (droid_aim or blue_shadow_droid) {
        const identity = s.reference(head);
        const owner = s.entities_resolve_reference(&identity);
        if (owner == actor or (blue_shadow_droid and owner == 0) or !s.live(op)) return null;
    }
    // Actor updates and targeting checks can run in different orders within a tick.
    var i = after_force orelse s.fire_task_cursor + 1;
    var droid_motion_block = false;
    var lab_motion: ?*const p.SyncFireTaskGate = null;
    while (i < frame.fire_task_gate_count) : (i += 1) {
        const entry = &frame.fire_task_gates[i];
        if (competitor and entry.kind != kind) break;
        if (droid_aim and !droidAim(entry.kind, entry.character)) break;
        if (blue_shadow_clone and after_force == null and lab_motion == null and forceScan(entry.kind)) {
            const caster = &head.payload.force;
            const query = &entry.payload.force;
            if (query.caster_slot != caster.caster_slot or query.caster_generation != caster.caster_generation or query.clock != caster.clock) return null;
            continue;
        }
        if (party_spellit) {
            const clock = if (after_force != null) lab_clock else head.payload.force.clock;
            if (lab_motion) |motion| {
                const clone_stage = (entry.kind == p.SYNC_ACTOR_SPELLIT_ADMISSION or entry.kind == p.SYNC_ACTOR_SPELLIT_QUERY) and
                    entry.slot == motion.slot and entry.generation == motion.generation;
                if ((!clone_stage and !(lab_party and labCompanionAdmission(entry.character, entry.kind, entry.flags, entry.action))) or entry.payload.state.repeat != clock) return null;
                if (s.early_actor_gates.isSet(i)) continue;
            } else {
                const character: i32 = if (corridor_party) 184 else 138;
                if (entry.kind != p.SYNC_ACTOR_CHARACTER_MOTION or entry.character != character or entry.payload.character_motion.clock != clock or !s.early_actor_gates.isSet(i)) return null;
                const identity = s.reference(entry);
                const clone = if (lab_companion) s.read(usize, 0xfb4944) else actor;
                if (clone == 0 or s.entities_resolve_reference(&identity) != clone or !s.live(op)) return null;
                lab_motion = entry;
                continue;
            }
        }
        if (blue_shadow_droid) {
            if (blueShadowDroidDecision(entry)) {
                if (droidDecisionClock(entry) != motion_clock) return null;
                const identity = s.reference(entry);
                const owner = s.entities_resolve_reference(&identity);
                if (droid_motion_block or owner == 0 or owner == actor or !s.live(op)) return null;
                continue;
            }
            if (entry.kind != kind or !blueShadowDroidMotion(entry.character) or entry.payload.character_motion.clock != motion_clock) return null;
            droid_motion_block = true;
        }
        if (s.early_actor_gates.isSet(i)) {
            if (blue_shadow_clone) return null;
            if (blue_shadow_droid) {
                const identity = s.reference(entry);
                if (s.entities_resolve_reference(&identity) == actor or !s.live(op)) return null;
            }
            continue;
        }
        if (!droid_aim and (entry.kind != kind or entry.flags != flags or entry.action != action)) {
            if (blue_shadow_motion) return null;
            continue;
        }
        var identity = s.reference(entry);
        const resolved = s.entities_resolve_reference(&identity);
        if (!s.live(op)) return null;
        if (resolved != actor) {
            if (blue_shadow_clone or (blue_shadow_droid and resolved == 0)) return null;
            continue;
        }
        if (entry.kind != kind or entry.flags != flags or entry.action != action) return null;
        if (state) |pointer| {
            if (contextFailure(entry, pointer) != 0) return null;
            const bytes = length(kind);
            @memcpy(pointer[0..bytes], entry.payload.storage[0..bytes]);
        }
        s.early_actor_gates.set(i);
        debug[1] +%= 1;
        debug[2] +%= @intFromBool(local != entry.value);
        return entry.value;
    }
    return null;
}
fn skipSpellItNoOp(op: *const s.Lease, actor: usize, kind: u32, state: [*]const u8) void {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    const stages = [_]u16{ 4, 5, 2, 3 };
    const outcomes = [_]c_int{ 0, 1, 0, 0 };
    if ((frame.level != 24 and frame.level != 74) or cursor == 0 or cursor + stages.len >= frame.fire_task_gate_count or !s.valid(actor, 0x1440)) return;
    if (frame.level == 24 and s.read(usize, 0xfb3088) != 0) return;
    const previous = &frame.fire_task_gates[cursor - 1];
    const next = &frame.fire_task_gates[cursor + stages.len];
    if (previous.kind != p.SYNC_ACTOR_CHARACTER_MOTION or next.kind != kind or next.slot == previous.slot or next.flags != 0 or next.action != 0 or
        next.character != s.read(i16, actor + 0xdc0)) return;
    const clock = previous.payload.character_motion.clock;
    switch (kind) {
        p.SYNC_ACTOR_CHARACTER_MOTION => {
            const matches_party = if (frame.level == 74) previous.character == 188 and next.character == 199 else previous.character == 176 and next.character == 138;
            if (!matches_party or next.payload.character_motion.clock != clock or
                s.read(p.SyncCharacterMotionState, @intFromPtr(state)).clock != clock) return;
        },
        p.SYNC_ACTOR_RTS_COMPETITOR => {
            if (frame.level != 24 or previous.character != 138 or next.character != 199 or next.payload.competitor.clock != clock +% 1 or
                s.read(p.SyncRtsCompetitorState, @intFromPtr(state)).clock != clock +% 1) return;
        },
        else => return,
    }
    const prior_identity = s.reference(previous);
    for (stages, outcomes, cursor..) |stage, outcome, index| {
        const entry = &frame.fire_task_gates[index];
        if (s.early_actor_gates.isSet(index) or entry.kind != p.SYNC_ACTOR_SPELLIT_ADMISSION or entry.flags != stage or entry.action != 0 or
            entry.value != outcome or entry.payload.state.repeat != clock or !equal(&prior_identity, &s.reference(entry))) return;
    }
    const player = s.read(usize, if (frame.level == 74) 0xfb4940 else 0xfb4944);
    if (s.early_actor_gates.isSet(cursor + stages.len) or player == 0 or s.entities_resolve_reference(&prior_identity) != player or !s.live(op)) return;
    const next_identity = s.reference(next);
    if (s.entities_resolve_reference(&next_identity) != actor or !s.live(op)) return;
    // Native SpellIt exits after both eligibility queries fail, before selecting a gizmo.
    s.fire_task_cursor += stages.len;
}

pub fn replayResoluteSpellItNode(scope: *const s.SpellItScope, state: *p.SyncSpellItNodeState, debug: *[4]u32) enum { matched, absent, mismatch } {
    const frame = s.journal.frame.?;
    const start = scope.node_gate_start;
    if (start == 0 or start > frame.fire_task_gate_count) return .mismatch;
    const query = &frame.fire_task_gates[start - 1];
    if (query.kind != p.SYNC_ACTOR_SPELLIT_QUERY or s.read(u32, @intFromPtr(&query.payload.storage)) != state.clock) return .mismatch;
    const source = s.reference(query);
    if (s.entities_resolve_reference(&source) != scope.actor or !s.live(&scope.lease)) return .mismatch;
    const size = @offsetOf(p.SyncSpellItNodeState, "position");
    for (frame.fire_task_gates[start..frame.fire_task_gate_count], start..) |*entry, index| {
        if (entry.kind != p.SYNC_ACTOR_SPELLIT_NODE or entry.payload.spellit_node.clock != state.clock or
            !equal(&source, &s.reference(entry))) break;
        if (entry.payload.spellit_node.poi_name != state.poi_name or !equal(&entry.payload.spellit_node.resource_name, &state.resource_name)) continue;
        if (index < s.fire_task_cursor or s.early_actor_gates.isSet(index) or
            !std.mem.eql(u8, entry.payload.storage[0..size], std.mem.asBytes(state)[0..size])) return .mismatch;
        state.* = entry.payload.spellit_node;
        s.early_actor_gates.set(index);
        while (s.fire_task_cursor < frame.fire_task_gate_count and s.early_actor_gates.isSet(s.fire_task_cursor)) s.fire_task_cursor += 1;
        debug[1] +%= 1;
        return .matched;
    }
    return .absent;
}

fn padmeSupportNoOp(previous: *const p.SyncFireTaskGate, support: *const p.SyncFireTaskGate, clock: u32) bool {
    return support.kind == p.SYNC_FIRE_ATTACK_SUPPORT and support.character == 188 and support.value == 3 and
        previous.slot == support.slot and previous.generation == support.generation and previous.value == 0 and
        previous.kind == p.SYNC_ACTOR_SPELLIT_QUERY and
        s.read(p.SyncSpellItQueryState, @intFromPtr(&previous.payload.storage)).clock == clock;
}

pub fn skipTrailingPadmeSupport(op: *const s.Lease) void {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if (frame.level != 74 or cursor == 0 or cursor + 1 != frame.fire_task_gate_count) return;
    if (padmeSupportNoOp(&frame.fire_task_gates[cursor - 1], &frame.fire_task_gates[cursor], s.read(u32, 0xfb4b6c)) and s.live(op)) {
        s.fire_task_cursor += 1;
    }
}

fn skipAbsentBlueShadowMotionDecision(op: *const s.Lease, actor: usize, state: [*]const u8) void {
    const frame = s.journal.frame.?;
    const cursor = s.fire_task_cursor;
    if ((frame.level != 71 and frame.level != 73 and frame.level != 74) or cursor == 0 or cursor + 1 >= frame.fire_task_gate_count) return;
    const support = &frame.fire_task_gates[cursor];
    const previous = &frame.fire_task_gates[cursor - 1];
    const next = &frame.fire_task_gates[cursor + 1];
    const clock = s.read(u32, @intFromPtr(state));
    if (previous.slot != support.slot or previous.generation != support.generation or
        previous.value != 0 or next.kind != p.SYNC_ACTOR_CHARACTER_MOTION or next.payload.character_motion.clock != clock) return;
    if (frame.level == 71) {
        if (support.kind != p.SYNC_ACTOR_FORCE_ELIGIBILITY or support.flags != 3 or support.value != 0 or
            previous.kind != p.SYNC_ACTOR_CHARACTER_MOTION or previous.payload.character_motion.clock != clock or
            previous.character != 321 or support.character != 321 or next.character != 321 or next.slot == support.slot) return;
    } else if (support.kind != p.SYNC_FIRE_ATTACK_SUPPORT or support.value != 3) {
        return;
    } else if (frame.level == 73) {
        if (support.character != 201 or previous.kind != p.SYNC_ACTOR_SPELLIT_ADMISSION or previous.flags != 5 or
            previous.payload.state.repeat != clock or (next.character != 321 and next.character != 333)) return;
    } else {
        if (!padmeSupportNoOp(previous, support, clock) or next.character != 199) return;
    }
    const identity = s.reference(next);
    if (s.entities_resolve_reference(&identity) == actor and s.live(op)) s.fire_task_cursor += 1;
}

fn skipHiddenLabAim(op: *const s.Lease, actor: usize, state: [*]const u8) void {
    const frame = s.journal.frame.?;
    if (frame.level != 73 or !s.valid(actor, 0x1440) or s.read(u16, actor + 0xdc0) != 321) return;
    const obi_wan = s.read(usize, 0xfb4944);
    if (!s.valid(obi_wan, 0x1440) or s.read(u16, obi_wan + 0xdc0) != 181) return;
    const initial = s.fire_task_cursor;
    var index = initial;
    const clock = s.read(u32, @intFromPtr(state));
    while (index + 1 < frame.fire_task_gate_count) : (index += 2) {
        const base = &frame.fire_task_gates[index];
        if (base.kind != p.SYNC_ACTOR_AIM_BASE) break;
        const aim = &frame.fire_task_gates[index + 1];
        if (base.character != 321 or aim.kind != p.SYNC_ACTOR_AIM_TASK or aim.value != 0 or
            base.slot != aim.slot or base.generation != aim.generation or base.payload.aim_base.clock != clock or
            aim.payload.aim.clock != clock or base.payload.aim_base.task_class != aim.payload.aim.task_class or
            s.early_actor_gates.isSet(index) or s.early_actor_gates.isSet(index + 1)) return;
        if (s.entities_actor(aim.payload.aim.target_slot, aim.payload.aim.target_generation) != obi_wan or !s.live(op)) return;
    }
    if (index == initial or index >= frame.fire_task_gate_count) return;
    const next = &frame.fire_task_gates[index];
    if (next.kind != p.SYNC_ACTOR_CHARACTER_MOTION or next.payload.character_motion.clock != clock) return;
    const owner = s.reference(next);
    if (s.entities_resolve_reference(&owner) != actor or !s.live(op)) return;
    var pair = initial;
    while (pair < index) : (pair += 2) {
        const base = &frame.fire_task_gates[pair];
        var found = false;
        for (frame.fire_task_gates[index + 1 .. frame.fire_task_gate_count]) |*motion| {
            if (motion.kind != p.SYNC_ACTOR_CHARACTER_MOTION or motion.payload.character_motion.clock != clock) break;
            if (motion.slot == base.slot and motion.generation == base.generation) {
                found = true;
                break;
            }
        }
        if (!found) return;
    }
    s.fire_task_cursor = index;
}

pub fn apply(actor: usize, kind: u32, flags: u16, action: u16, value: c_int, state: ?[*]u8, debug: *[4]u32) c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return value;
    const bytes = length(kind);
    const failure: c_int = switch (kind) {
        p.SYNC_FIRE_TASK_VISIBILITY, p.SYNC_ACTOR_DEATH_BREAKUP, p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY, p.SYNC_ACTOR_HAZARD_DEATH, p.SYNC_ACTOR_RYLOTH_FIGHTER_DEATH, p.SYNC_ACTOR_GEONOSIS_VEHICLE_DEATH, p.SYNC_ACTOR_FORCE_ELIGIBILITY, p.SYNC_ACTOR_TUBE_CONTACT, p.SYNC_ACTOR_MELEE_CONTACT => 0,
        p.SYNC_ACTOR_BREAKUP_VISIBILITY => 1,
        else => value,
    };
    if (s.journal.failed != 0) return failure;
    if (s.journal.host == 0 and (kind == p.SYNC_ACTOR_CHARACTER_MOTION or kind == p.SYNC_ACTOR_RTS_COMPETITOR) and flags == 0 and action == 0) {
        if (state) |pointer| {
            skipSpellItNoOp(&op, actor, kind, pointer);
            if (kind == p.SYNC_ACTOR_CHARACTER_MOTION) {
                skipAbsentBlueShadowMotionDecision(&op, actor, pointer);
                skipHiddenLabAim(&op, actor, pointer);
            }
        }
    }
    if (s.journal.host != 0) {
        s.entities_update();
        if (!s.live(&op)) return failure;
        var identity = std.mem.zeroes(p.SyncActor);
        s.entities_describe(&identity, actor);
        const slot = s.entities_slot(actor);
        if (!s.live(&op)) return failure;
        if (slot >= 0 and slot < p.SYNC_MAX_ACTORS and identity.generation != 0 and s.journal.frame.?.fire_task_gate_count < p.SYNC_MAX_ACTORS) {
            var gate = std.mem.zeroes(p.SyncFireTaskGate);
            gate.slot = @intCast(slot);
            gate.generation = identity.generation;
            gate.spawn_tag = identity.spawn_tag;
            gate.spawn_source = identity.spawn_source;
            gate.character = s.read(i16, actor + 0xdc0);
            gate.flags = flags;
            gate.action = action;
            gate.value = value;
            gate.kind = kind;
            gate.origin = identity.spawn_position;
            if (state) |source| @memcpy(gate.payload.storage[0..bytes], source[0..bytes]);
            s.journal.frame.?.fire_task_gates[s.journal.frame.?.fire_task_gate_count] = gate;
            s.journal.frame.?.fire_task_gate_count += 1;
            debug[0] +%= 1;
            return value;
        }
    } else if (s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count) {
        const gate = &s.journal.frame.?.fire_task_gates[s.fire_task_cursor];
        if (gate.kind == kind and gate.flags == flags and gate.action == action) {
            var identity = s.reference(gate);
            var matches = s.entities_resolve_reference(&identity) == actor;
            if (!matches and kind == p.SYNC_ACTOR_RTS_COMPETITOR and s.entities_bind_native_reference(&identity, actor) != 0) {
                matches = s.entities_actor(identity.slot, identity.generation) == actor;
                if (matches) s.clonewars_rts_competitor_debug[7] +%= 1;
            }
            if (!s.live(&op)) return failure;
            if (matches) {
                const reason = if (state) |pointer| contextFailure(gate, pointer) else 0;
                if (reason != 0) {
                    s.journal.failed = @bitCast(reason);
                    debug[3] +%= 1;
                    s.failed(&op, actor, null, reason);
                    return failure;
                }
                s.fire_task_cursor += 1;
                while (s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count and s.early_actor_gates.isSet(s.fire_task_cursor)) s.fire_task_cursor += 1;
                debug[1] +%= 1;
                debug[2] +%= @intFromBool(value != gate.value);
                if (state) |output| @memcpy(output[0..bytes], gate.payload.storage[0..bytes]);
                return gate.value;
            }
        }
    }
    if (s.journal.host == 0 and s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count) {
        if (replayEarlyActorGate(&op, actor, kind, flags, action, value, state, debug)) |result| return result;
    }
    if (!s.live(&op)) return failure;
    if (s.clonewars_actor_gate_failure[0] == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = s.entities_observed_identity(actor, &slot, &generation);
        const expected = if (s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count) &s.journal.frame.?.fire_task_gates[s.fire_task_cursor] else null;
        s.clonewars_actor_gate_failure = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, s.fire_task_cursor, kind, slot, generation, s.read(u32, 0xfb4b6c), if (expected) |e| e.kind else std.math.maxInt(u32), if (expected) |e| e.slot else std.math.maxInt(u32), if (expected) |e| e.generation else 0, flags, action, if (expected) |e| e.flags else 0, if (expected) |e| e.action else 0, s.journal.frame.?.fire_task_gate_count, 0 };
    }
    s.journal.failed = 5;
    debug[3] +%= 1;
    s.failed(&op, actor, null, 5);
    return failure;
}
