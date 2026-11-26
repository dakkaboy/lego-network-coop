const std = @import("std");
const p = @import("protocol.zig");
const t = @import("model_types.zig");
const state = @import("model_state.zig");
const capture = @import("model_capture.zig");
const win = @import("win32.zig");
const read = capture.read;
extern fn entities_update() void;
extern fn entities_describe(*p.SyncActor, usize) void;
extern fn entities_slot(usize) c_int;
extern fn entities_resolve_reference(*const p.SyncActor) usize;
extern fn entities_observed_generation(usize) u32;
extern fn model_context_canonicalize(*const p.SyncModelInput, *const p.SyncModelInputContext, *p.SyncModelInputContext, *u32) c_int;
extern fn model_input_journal_record(*t.Journal, *const p.SyncModelInput) c_int;
extern fn model_input_journal_validate(*t.Journal, ?*const p.SyncModelInput, c_int, *const p.SyncModelInput) c_int;
fn hiddenEnemyMotionAction(action: u32) bool {
    return action == 0xffff or action == 1 or action == 10;
}
fn vindiHiddenMotionAction(action: u32) bool {
    return action == 0xffff or action == 29 or action == 92;
}
fn blueShadowB1Motion(level: i32, host: *const p.SyncModelInput, local: *const p.SyncModelInput) bool {
    if ((level != 71 and level != 73 and level != 74) or host.character != 321 or local.character != 321) return false;
    const a = host.context.action;
    const b = local.context.action;
    return (a == 114 and (b == 0xffff or (level == 71 and b == 13))) or
        (b == 114 and (a == 0xffff or (level == 71 and a == 13)));
}
fn resolveInput(entry: *const p.SyncModelInput) usize {
    var reference = std.mem.zeroes(p.SyncActor);
    reference.slot = entry.slot;
    reference.generation = entry.generation;
    reference.spawn_tag = entry.spawn_tag;
    reference.spawn_source = entry.spawn_source;
    reference.character = entry.character;
    reference.spawn_position = entry.origin;
    return entities_resolve_reference(&reference);
}
fn combatDroid(level: i32, character: i32) bool {
    return character == 321 or character == 333 or (level == 70 and character == 337);
}
pub export fn request_mode_source_checkpoint(saved: [*]u32, fx: [*]const u8) void {
    var op: t.Lease = undefined;
    const s = state.qualified(&op) orelse return;
    state.clonewars_model_input_debug[11] +%= 1;
    if (state.journal.failed != 0) return;
    const actor: usize = saved[4];
    const controller: usize = saved[16];
    const provider: usize = saved[12];
    const x = &saved[17];
    const z = &saved[19];
    if (!state.live(&op)) return;
    if (!capture.eligible(actor, controller, provider)) {
        state.clonewars_model_input_debug[5] +%= 1;
        return;
    }
    if (!state.live(&op) or state.scope != s) return;
    if (s.actor != actor or s.source != 0 or s.entry_generation == 0 or entities_observed_generation(actor) != s.entry_generation) {
        state.failed(&op, actor, null, null, 11);
        return;
    }
    var local: p.SyncModelInput = undefined;
    if (!capture.capture(&local, actor, provider, @intFromPtr(x), @intFromPtr(z), @intFromPtr(fx))) {
        state.failed(&op, actor, null, null, 4);
        return;
    }
    if (!state.live(&op) or state.scope != s) return;
    var raw = local;
    var mask: u32 = 0;
    var entry: ?*const p.SyncModelInput = null;
    if (state.journal.host != 0) {
        entities_update();
        if (!state.live(&op) or state.scope != s) return;
        var identity = std.mem.zeroes(p.SyncActor);
        entities_describe(&identity, actor);
        if (!state.live(&op) or state.scope != s) return;
        const slot = entities_slot(actor);
        if (!state.live(&op) or state.scope != s) return;
        local.slot = @bitCast(slot);
        local.generation = identity.generation;
        local.spawn_tag = identity.spawn_tag;
        local.spawn_source = identity.spawn_source;
        local.origin = identity.spawn_position;
        raw = local;
        if (model_context_canonicalize(&local, &raw.context, &local.context, &mask) == 0) {
            state.failed(&op, actor, &raw, &raw, 4);
            return;
        }
        if (model_input_journal_record(&state.journal, &local) == 0) {
            state.failed(&op, actor, &local, &raw, @bitCast(state.journal.failed));
            return;
        }
        s.ordinal = state.journal.frame.?.model_input_count - 1;
        entry = &state.journal.frame.?.model_inputs[s.ordinal];
        state.clonewars_model_input_debug[0] +%= 1;
    } else {
        entry = state.journal.peek();
        var resolved = if (entry) |e| resolveInput(e) else 0;
        if (!state.live(&op) or state.scope != s) return;
        var replay = state.journal;
        const frame = replay.frame.?;
        if (entry) |head| {
            if ((frame.level == 29 or frame.level == 70) and resolved != actor and combatDroid(frame.level, local.character) and
                combatDroid(frame.level, head.character) and head.native_clock == local.native_clock)
            {
                var i = replay.cursor + 1;
                while (i < frame.model_input_count) : (i += 1) {
                    const candidate = &frame.model_inputs[i];
                    if (!combatDroid(frame.level, candidate.character) or candidate.native_clock != local.native_clock) break;
                    if (state.early_entries.isSet(i)) continue;
                    const owner = resolveInput(candidate);
                    if (!state.live(&op) or state.scope != s) return;
                    if (owner != actor) continue;
                    replay.cursor = i;
                    entry = candidate;
                    resolved = owner;
                    break;
                }
            }
        }
        local.slot = if (entry) |e| e.slot else std.math.maxInt(u32);
        local.generation = entities_observed_generation(actor);
        raw = local;
        if (entry) |e| {
            if (e.context.actor_4c_mask != raw.context.actor_4c_mask) {
                state.failed(&op, actor, e, &raw, 9);
                return;
            }
            if (model_context_canonicalize(e, &raw.context, &local.context, &mask) == 0) {
                state.failed(&op, actor, e, &raw, 4);
                return;
            }
            local.context.actor_76 = e.context.actor_76;
            // These actions take the same path through the model producer. Keep the native action intact.
            if (local.context.actor_4c_mask == 1 and
                (blueShadowB1Motion(frame.level, e, &raw) or
                    (frame.level == 64 and hiddenEnemyMotionAction(e.context.action) and hiddenEnemyMotionAction(raw.context.action)) or
                    (frame.level == 73 and e.character == 201 and raw.character == 201 and
                        ((vindiHiddenMotionAction(e.context.action) and vindiHiddenMotionAction(raw.context.action)) or
                            (e.context.action == 29 and (raw.context.action == 1 or raw.context.action == 10)) or
                            (e.context.action == 10 and raw.context.action == 29)))))
            {
                local.context.action = e.context.action;
            }
            if (local.context.actor_4c_mask == 0) {
                local.context.cf4_raw = e.context.cf4_raw;
                local.context.model_42 = e.context.model_42;
            }
        }
        if (model_input_journal_validate(&replay, entry, @intFromBool(entry != null and resolved == actor), &local) == 0) {
            state.failed(&op, actor, entry, &raw, @bitCast(replay.failed));
            return;
        }
        s.ordinal = replay.cursor - 1;
        if (s.ordinal == state.journal.cursor) {
            state.journal.cursor = replay.cursor;
            while (state.journal.cursor < frame.model_input_count and state.early_entries.isSet(state.journal.cursor)) state.journal.cursor += 1;
        } else {
            state.early_entries.set(s.ordinal);
        }
        state.clonewars_model_input_debug[1] +%= 1;
    }
    if (!state.live(&op) or state.scope != s) return;
    const generation = entities_observed_generation(actor);
    if (!state.live(&op) or state.scope != s) return;
    const e = entry.?;
    s.controller = controller;
    s.provider = provider;
    s.generation = generation;
    s.epoch = state.journal.frame.?.epoch;
    s.sequence = state.journal.frame.?.sequence;
    s.native_frame = saved[2];
    s.source = 1;
    s.request = e.*;
    s.local_mode = local.input_mode;
    s.raw_source_context = raw.context;
    s.canonicalized_fields = mask;
    if (state.journal.host == 0) {
        if (e.context.actor_4c_mask == 0 and raw.context.cf4_raw != e.context.cf4_raw) {
            win.store(u32, actor + 0xcf4, e.context.cf4_raw);
            state.clonewars_model_visibility_debug[0] +%= 1;
            state.clonewars_model_visibility_debug[2] = e.native_clock;
            state.clonewars_model_visibility_debug[3] = e.slot;
        }
        const corrected = @as(u32, @bitCast(local.input_x)) != @as(u32, @bitCast(e.input_x)) or @as(u32, @bitCast(local.input_z)) != @as(u32, @bitCast(e.input_z)) or local.input_mode != e.input_mode;
        x.* = @bitCast(e.input_x);
        z.* = @bitCast(e.input_z);
        state.clonewars_model_input_debug[2] +%= @intFromBool(corrected);
        if (corrected and @cmpxchgStrong(u32, &state.clonewars_model_input_first_correction[0], 0, std.math.maxInt(u32), .seq_cst, .seq_cst) == null) {
            state.clonewars_model_input_corrected_host = e.*;
            state.clonewars_model_input_corrected_local = raw;
            var effective = local;
            effective.input_x = e.input_x;
            effective.input_z = e.input_z;
            effective.input_mode = e.input_mode;
            state.clonewars_model_input_effective = effective;
            state.first_actor = actor;
            state.first_controller = controller;
            state.first_generation = s.generation;
            var qpc: [2]u32 = undefined;
            @import("observation.zig").timestamp(&qpc[0], &qpc[1]);
            state.clonewars_model_input_first_correction[1..8].* = .{ state.journal.frame.?.sequence, s.ordinal, e.slot, e.generation, local.native_clock, qpc[0], qpc[1] };
            @atomicStore(u32, &state.clonewars_model_input_first_correction[0], s.epoch, .seq_cst);
        }
    }
    state.clonewars_model_input_debug[7] = state.journal.frame.?.sequence;
    state.clonewars_model_input_debug[8] = if (state.journal.host != 0) state.journal.frame.?.model_input_count else state.journal.cursor;
    state.clonewars_model_input_debug[9] = e.slot;
    state.clonewars_model_input_debug[10] = e.generation;
}
fn consumer(saved: [*]u32, mode: *u32, mov: bool) c_int {
    var op: t.Lease = undefined;
    const s = state.qualified(&op) orelse return 0;
    if (state.journal.failed != 0 or s.source == 0) return 0;
    const actor: usize = saved[4];
    if (!capture.scopeValid(&op, s, actor, saved[16], saved[2]) or saved[12] != s.provider or !capture.valid(s.provider, 0x194)) {
        state.failed(&op, actor, &s.request, null, 12);
        return 0;
    }
    const zero = capture.zero(&s.request);
    if (!mov) {
        if (s.cmp_seen != 0 or s.mov_seen != 0 or zero or saved[7] != s.provider) {
            state.failed(&op, actor, &s.request, null, 13);
            return 0;
        }
        s.cmp_seen = 1;
        s.cmp_native_flags = saved[8] & 0x8d5;
        s.cmp_effective_flags = asm volatile ("cmpl $1, %[canonical]; pushfl; popl %[flags]"
            : [flags] "=r" (-> u32),
            : [canonical] "r" (s.request.input_mode),
            : .{ .cc = true }) & 0x8d5;
    } else {
        if (s.mov_seen != 0 or s.cmp_seen != @intFromBool(!zero)) {
            state.failed(&op, actor, &s.request, null, 13);
            return 0;
        }
        s.mov_seen = 1;
        s.mov_native_mode = saved[7];
    }
    mode.* = s.request.input_mode;
    return 1;
}
pub export fn request_mode_cmp_checkpoint(saved: [*]u32, mode: *u32) c_int {
    return consumer(saved, mode, false);
}
pub export fn request_mode_mov_checkpoint(saved: [*]u32, mode: *u32) c_int {
    return consumer(saved, mode, true);
}
pub export fn request_priority_checkpoint(saved: [*]u32, priority: *u32) c_int {
    var op: t.Lease = undefined;
    const s = state.qualified(&op) orelse return 0;
    if (state.journal.host != 0 or state.journal.failed != 0 or s.source == 0 or s.mov_seen == 0 or s.request.input_mode != 1 or !capture.scopeValid(&op, s, saved[4], saved[16], saved[2])) return 0;
    priority.* = s.request.context.actor_76;
    return 1;
}
pub export fn request_visibility_checkpoint(saved: [*]u32, visibility: *u32) c_int {
    var op: t.Lease = undefined;
    const s = state.qualified(&op) orelse return 0;
    if (state.journal.host != 0 or state.journal.failed != 0 or s.source == 0 or s.mov_seen == 0 or s.request.context.actor_4c_mask != 0) return 0;
    const actor: usize = saved[4];
    const object: usize = saved[7];
    if (!capture.scopeValid(&op, s, actor, saved[16], saved[2]) or read(usize, actor + 8) != object or !capture.valid(object, 0x43)) return 0;
    visibility.* = s.request.context.model_42;
    state.clonewars_model_visibility_debug[1] +%= @intFromBool((read(u8, object + 0x42) != 0) != (visibility.* != 0));
    return 1;
}
pub export fn request_mode_join_checkpoint(saved: [*]u32, _: [*]const u8) void {
    var op: t.Lease = undefined;
    const s = state.qualified(&op) orelse return;
    if (state.journal.failed != 0 or s.source == 0) return;
    if (!capture.scopeValid(&op, s, saved[4], saved[16], saved[2]) or s.mov_seen == 0 or s.cmp_seen != @intFromBool(!capture.zero(&s.request))) {
        state.failed(&op, saved[4], &s.request, null, 14);
        return;
    }
    @import("model_projection.zig").record(&op, s, saved[4], saved[16]);
    if (!state.live(&op) or state.scope != s) return;
    s.projection_complete = 1;
    state.clonewars_model_input_debug[13] +%= 1;
}
