const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const input = @import("sync_input.zig");
const load = s.load;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
const Prep = struct { actor: usize, alternate: bool, blocked: c_int, bound: bool, token: s.Token, machine: s.Machine, ai: bool };
fn fault(code: c_int) void {
    if (s.fault == 0) s.fault = code;
}
pub fn fail(reason: u32, expected: usize, actual: usize) void {
    if (s.clonewars_input_prep_failure[2] == 0) s.clonewars_input_prep_failure = .{ s.working.epoch, s.working.sequence, reason, s.prep_gate_depth, expected, actual, if (expected != 0) api.entities_observed_generation(expected) else 0, if (actual != 0) api.entities_observed_generation(actual) else 0 };
    fault(16);
}
fn abort(raw: usize) callconv(.c) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const context: *Prep = @ptrFromInt(raw);
    if (!context.bound) return;
    if (api.coherent_frame_close(&context.token) != 0) {
        api.coherent_frame_cancel_atomic(0x10000000);
        @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    }
    while (s.prep_gate_depth != 0) {
        const gate = &s.prep_gates[s.prep_gate_depth - 1];
        if (gate.cohort.cohort_nonce != context.token.cohort_nonce or gate.cohort.owner != context.token.owner or gate.cohort.release != context.token.release) break;
        s.prep_gate_depth -= 1;
    }
}
fn aiNative(actor: usize) callconv(.c) void {
    api.decision_observer_invoke_actor(2, actor, @ptrFromInt(0x8b0f90), 0x9c53f7);
}
fn aiImpl(context: *Prep) void {
    const actor = context.actor;
    var token: s.Token = undefined;
    const authority = s.captureDispatch(&token);
    if (s.running and !authority) {
        api.coherent_frame_cancel_atomic(0x10000000);
        context.machine.restore();
        const native: *const fn (usize) callconv(.c) void = @ptrFromInt(0x8b0f90);
        native(actor);
        context.machine.capture();
        return;
    }
    if (authority) {
        if (s.prep_gate_depth == 64 or !s.valid(actor, 0x1440)) fail(1, 0, actor) else {
            const flags = load(u32, actor + 0x50);
            const blocked = (flags & 0x200 != 0 and flags & 0x800 == 0 and (context.blocked != -1 or load(i32, 0xfbdd2c) == 2)) or load(u32, actor + 0x8e0) & 0x200 != 0;
            s.prep_gates[s.prep_gate_depth] = .{ .actor = actor, .generation = api.entities_observed_generation(actor), .blocked = @intFromBool(blocked), .cohort = token };
            s.prep_gate_depth += 1;
        }
    }
    context.machine.restore();
    if (authority and (actor == s.player(0) or actor == s.player(1))) api.tags_actor_update(actor, aiNative) else aiNative(actor);
    context.machine.capture();
}
fn eligible(actor: usize) bool {
    return actor != 0 and actor != s.player(0) and actor != s.player(1);
}
fn prepImpl(context: *Prep) void {
    const actor = context.actor;
    const alternate = context.alternate;
    var actor_cohort: s.Token = undefined;
    const dispatch = s.dispatchAuthority();
    if (s.running and !dispatch) {
        api.coherent_frame_cancel_atomic(0x10000000);
        context.machine.restore();
        const native: *const fn (usize) callconv(.c) void = @ptrFromInt(0x9ab020);
        native(actor);
        context.machine.capture();
        return;
    }
    if (dispatch and !s.captureDispatch(&actor_cohort)) return;
    s.clonewars_actor_debug[0] +%= 1;
    s.clonewars_actor_debug[if (s.running) @as(usize, 1) else 2] +%= 1;
    var restore_controller: usize = 0;
    var restore_generation: u32 = 0;
    var restore_hero: i32 = -1;
    var restore_scope = std.mem.zeroes(s.Npc.Scope);
    if (s.running and s.latched_ready) for (0..2) |slot| if (actor == s.player(slot)) {
        var sampled = s.latched_input[slot];
        sampled.pressed = s.pending_actor_pressed[slot];
        s.pending_actor_pressed[slot] = 0;
        const blocked = !alternate and context.blocked != 0;
        if (blocked) {
            s.clonewars_actor_debug[7] +%= 1;
            sampled.held = 0;
            sampled.pressed = 0;
        } else {
            if (alternate) {
                restore_controller = load(usize, actor + 0x6cc);
                if (!s.valid(restore_controller, 12)) {
                    fault(2);
                    return;
                }
                if (api.npc_input_scope_capture(&s.npc_inputs, @ptrFromInt(restore_controller + 4), @ptrFromInt(restore_controller + 8), &restore_scope) == 0) return;
                restore_generation = api.entities_observed_generation(actor);
                restore_hero = @intCast(slot);
            }
            if (input.write(slot, &sampled) == 0) {
                fault(2);
                return;
            }
        }
        if (slot == 1) {
            s.clonewars_actor_debug[3] +%= 1;
            if (sampled.pressed != 0) s.clonewars_actor_debug[4] +%= 1;
            s.clonewars_actor_debug[5] = sampled.held;
            s.clonewars_actor_debug[6] = sampled.pressed;
        }
    };
    var npc_controller: usize = 0;
    var npc_scope = std.mem.zeroes(s.Npc.Scope);
    var npc_generation: u32 = 0;
    if (dispatch and eligible(actor)) {
        if (s.npc_inputs.failed != 0) return;
        npc_controller = load(usize, actor + 0x6cc);
        if (!s.valid(npc_controller, 12)) {
            s.clonewars_npc_input_debug[14] +%= 1;
            fault(13);
            return;
        }
        const held: *u32 = @ptrFromInt(npc_controller + 4);
        const pressed: *u32 = @ptrFromInt(npc_controller + 8);
        if (api.lan_is_host() != 0) {
            api.entities_update();
            if (!s.live() or api.npc_input_cohort_valid(&s.npc_inputs, &actor_cohort, 4) == 0) return;
            var identity = std.mem.zeroes(s.p.SyncActor);
            api.entities_describe(&identity, actor);
            if (api.npc_input_cohort_valid(&s.npc_inputs, &actor_cohort, 4) == 0) return;
            const entry = s.p.SyncActorInput{ .slot = @bitCast(api.entities_slot(actor)), .generation = identity.generation, .spawn_tag = identity.spawn_tag, .spawn_source = identity.spawn_source, .character = load(i16, actor + 0xdc0), .held = held.*, .pressed = pressed.*, .origin = identity.spawn_position };
            if (api.npc_input_record(&s.npc_inputs, &entry) == 0) {
                fault(13);
                return;
            }
            s.clonewars_npc_input_debug[0] +%= 1;
        } else {
            const entry = api.npc_input_peek(&s.npc_inputs);
            var identity = std.mem.zeroes(s.p.SyncActor);
            if (entry) |value| {
                identity.slot = value.slot;
                identity.generation = value.generation;
                identity.spawn_tag = value.spawn_tag;
                identity.spawn_source = value.spawn_source;
                identity.character = value.character;
                identity.spawn_position = value.origin;
            }
            s.clonewars_npc_input_debug[3] = if (entry) |value| value.slot else 0xffffffff;
            s.clonewars_npc_input_debug[4] = if (entry) |value| value.generation else 0;
            s.clonewars_npc_input_debug[7] = held.*;
            s.clonewars_npc_input_debug[8] = pressed.*;
            const owner_matches = entry != null and api.entities_resolve_reference(&identity) == actor;
            if (api.npc_input_cohort_valid(&s.npc_inputs, &actor_cohort, 4) == 0 or !s.live()) return;
            if (api.npc_input_apply(&s.npc_inputs, entry, @intFromBool(owner_matches), held, pressed, &npc_scope) == 0) {
                if (s.clonewars_npc_input_failure[0] == 0) {
                    var actual_slot: u32 = 0xffffffff;
                    var actual_generation: u32 = 0;
                    _ = api.entities_observed_identity(actor, &actual_slot, &actual_generation);
                    s.clonewars_npc_input_failure = .{ s.working.epoch, s.working.sequence, s.npc_inputs.cursor, if (entry) |value| value.slot else 0xffffffff, if (entry) |value| value.generation else 0, actual_slot, actual_generation, api.entities_observed_generation(actor), if (entry) |value| value.held else 0, if (entry) |value| value.pressed else 0, held.*, pressed.*, 0, 0 };
                }
                s.clonewars_npc_input_debug[2] +%= 1;
                fault(13);
                return;
            }
            s.clonewars_npc_input_debug[5] = entry.?.held;
            s.clonewars_npc_input_debug[6] = entry.?.pressed;
            s.clonewars_npc_input_debug[9] +%= @intFromBool(npc_scope.held != entry.?.held or npc_scope.pressed != entry.?.pressed);
            s.clonewars_npc_input_debug[10] = s.working.sequence;
            s.clonewars_npc_input_debug[11] = s.npc_inputs.cursor;
            s.clonewars_npc_input_debug[1] +%= 1;
        }
    }
    if (dispatch and (!s.live() or api.npc_input_cohort_valid(&s.npc_inputs, &actor_cohort, 4) == 0)) return;
    if (npc_scope.applied != 0) npc_generation = api.entities_observed_generation(actor);
    const remote_sample = api.remote_input_trace_before(actor, @intFromBool(s.running and actor == s.player(1)));
    context.machine.restore();
    api.decision_observer_invoke_actor(3, actor, @ptrFromInt(0x9ab020), if (alternate) @as(u32, 0x9c33bf) else 0x9c53fd);
    context.machine.capture();
    api.remote_input_trace_after(actor, remote_sample);
    if (dispatch and (!s.live() or api.npc_input_cohort_valid(&s.npc_inputs, &actor_cohort, 4) == 0)) return;
    if (!alternate) return;
    if (npc_scope.applied != 0) {
        restore_scope = npc_scope;
        restore_controller = npc_controller;
        restore_generation = npc_generation;
    }
    if (restore_scope.applied != 0 and api.npc_input_scope_valid(&restore_scope) != 0 and api.entities_allocation_live(actor, restore_generation) != 0 and s.valid(actor, 0x1440) and s.valid(restore_controller, 12) and (if (restore_hero >= 0) actor == s.player(@intCast(restore_hero)) else eligible(actor)) and load(u32, actor + 0x50) & 3 == 3 and restore_generation != 0 and api.entities_observed_generation(actor) == restore_generation and load(usize, actor + 0x6cc) == restore_controller) _ = api.npc_input_restore(&restore_scope, @ptrFromInt(restore_controller + 4), @ptrFromInt(restore_controller + 8));
}
fn invoke(raw: usize) callconv(.c) usize {
    const context: *Prep = @ptrFromInt(raw);
    if (context.ai) aiImpl(context) else prepImpl(context);
    return 0;
}
fn run(actor: usize, alternate: bool, blocked: c_int, ai: bool) void {
    var context: Prep = undefined;
    context.machine.capture();
    context.actor = actor;
    context.alternate = alternate;
    context.blocked = blocked;
    context.bound = s.captureDispatch(&context.token);
    context.ai = ai;
    _ = constructor_lexical_seh(@intFromPtr(&context), invoke, abort);
    context.machine.restore();
}
pub export fn sync_actor_ai_normal(actor: usize, cached_gate: c_int) void {
    run(actor, false, cached_gate, true);
}
pub fn normal(actor: usize) callconv(.c) void {
    if (s.running and !s.dispatchAuthority()) {
        run(actor, false, 0, false);
        return;
    }
    var blocked: c_int = 0;
    if (s.prep_gate_depth != 0) {
        s.prep_gate_depth -= 1;
        const gate = s.prep_gates[s.prep_gate_depth];
        if (api.npc_input_cohort_valid(&s.npc_inputs, &gate.cohort, 4) == 0) {
            api.coherent_frame_cancel_atomic(0x10000000);
            return;
        }
        if (gate.actor != actor or api.entities_allocation_live(actor, gate.generation) == 0) {
            fail(2, gate.actor, actor);
            return;
        }
        blocked = gate.blocked;
    } else if (s.dispatchAuthority()) {
        fail(3, 0, actor);
        return;
    }
    run(actor, false, blocked, false);
}
pub fn prepareAlternate(actor: usize) callconv(.c) void {
    run(actor, true, 0, false);
}
comptime {
    asm (
        \\.text
        \\.globl _sync_actor_ai_normal_hook
        \\_sync_actor_ai_normal_hook:
        \\movl 0xc0(%esp),%eax
        \\pushl %eax
        \\pushl 8(%esp)
        \\call _sync_actor_ai_normal
        \\addl $8,%esp
        \\ret
    );
}
