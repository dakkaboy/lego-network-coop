const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const equal = @import("validation.zig").equal;
extern fn physics_effect_body_resolve(u32, u32) usize;
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
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
        else => @sizeOf(p.SyncFireTaskState),
    };
}
fn contextFailure(gate: *const p.SyncFireTaskGate, state: [*]const u8) u32 {
    const data = &gate.payload;
    switch (gate.kind) {
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
            if (!@import("cadence_context.zig").aim(a, &b)) return 7;
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
pub fn apply(actor: usize, kind: u32, flags: u16, action: u16, value: c_int, state: ?[*]u8, debug: *[4]u32) c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return value;
    const bytes = length(kind);
    const failure: c_int = switch (kind) {
        p.SYNC_FIRE_TASK_VISIBILITY, p.SYNC_ACTOR_DEATH_BREAKUP, p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY, p.SYNC_ACTOR_HAZARD_DEATH => 0,
        p.SYNC_ACTOR_BREAKUP_VISIBILITY => 1,
        else => value,
    };
    if (s.journal.failed != 0) return failure;
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
                debug[1] +%= 1;
                debug[2] +%= @intFromBool(value != gate.value);
                if (state) |output| @memcpy(output[0..bytes], gate.payload.storage[0..bytes]);
                return gate.value;
            }
        }
    }
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
