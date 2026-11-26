const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
pub export var clonewars_lab_aim_failure: [12]u32 = @splat(0);
pub export var clonewars_lift_aim_failure: [12]u32 = @splat(0);
fn reject(op: *const s.Lease, actor: usize, reason: u32) void {
    s.journal.failed = @bitCast(reason);
    s.failed(op, actor, null, reason);
}
fn blueShadowAimTarget(actor: usize, target: usize, input: *p.SyncAimTaskState) ?usize {
    const frame = s.journal.frame.?;
    if (frame.level != 70 or read(u16, actor + 0xdc0) != 321 or s.fire_task_cursor >= frame.fire_task_gate_count) return null;
    const expected = &frame.fire_task_gates[s.fire_task_cursor];
    const aim = &expected.payload.aim;
    if (expected.kind != p.SYNC_ACTOR_AIM_TASK or expected.character != 321 or aim.target_slot != 0 or
        (input.target_slot == aim.target_slot and input.target_generation == aim.target_generation)) return null;
    var reconciled = input.*;
    reconciled.target_slot = aim.target_slot;
    reconciled.target_generation = aim.target_generation;
    if (!@import("cadence_context.zig").aim(aim, &reconciled)) return null;
    const last_target = read(usize, actor + 0xbdc);
    if (aim.target_generation == 0) {
        if (input.target_slot != 0 or input.target_generation == 0 or read(u32, actor + 0x50) & 0x10000 == 0 or last_target != target) return null;
        input.* = reconciled;
        return 0;
    }
    const ahsoka = read(usize, 0xfb4940);
    if (last_target != 0 or target == ahsoka or (target != 0 and target != read(usize, 0xfb4944)) or
        !s.valid(ahsoka, 0x1440) or read(u16, ahsoka + 0xdc0) != 191 or read(u8, ahsoka + 0xdde) == 0) return null;
    var slot: u32 = 0;
    var generation: u32 = 0;
    if (s.entities_observed_identity(ahsoka, &slot, &generation) == 0 or slot != aim.target_slot or generation != aim.target_generation) return null;
    input.* = reconciled;
    return ahsoka;
}
fn staleBlueShadowAimTarget(op: *const s.Lease, actor: usize, task_target: usize, input: *p.SyncAimTaskState) ?usize {
    const frame = s.journal.frame.?;
    if (s.journal.host != 0 or s.fire_task_cursor >= frame.fire_task_gate_count) return null;
    const droid = read(i16, actor + 0xdc0);
    const lift = frame.level == 74 and droid == 321 and read(f32, actor + 0x24) > 30;
    const obi_wan = if (frame.level == 73 and (droid == 321 or droid == 333)) read(usize, 0xfb4944) else 0;
    const lab_exit = s.valid(obi_wan, 0x1440) and read(u16, obi_wan + 0xdc0) == 181;
    if (!lift and !lab_exit) return null;
    const expected = &frame.fire_task_gates[s.fire_task_cursor];
    const aim = &expected.payload.aim;
    if (expected.kind != p.SYNC_ACTOR_AIM_TASK or expected.character != droid or aim.target_generation == 0) return null;
    const owner = s.reference(expected);
    if (s.entities_resolve_reference(&owner) != actor or !s.live(op)) return null;
    var reconciled = input.*;
    reconciled.target_slot = aim.target_slot;
    reconciled.target_generation = aim.target_generation;
    if (!@import("cadence_context.zig").aim(aim, &reconciled)) return null;
    const last_target = read(usize, actor + 0xbdc);
    var target = last_target;
    if (lift) {
        target = s.entities_actor(aim.target_slot, aim.target_generation);
        if (target == 0) {
            // After the lift fight, a native aim target can leave the active party while its allocation is retained.
            target = s.entities_retained_actor(aim.target_slot, aim.target_generation);
            if ((target != last_target and target != task_target) or !s.valid(target, 0x1440) or read(u32, target + 0x50) & 3 != 1) return null;
        }
    }
    if (!s.live(op)) return null;
    if (lift) {
        if (!s.valid(target, 0x1440)) return null;
        const character = read(u16, target + 0xdc0);
        if (read(f32, target + 0x24) <= 30 or (character != 181 and character != 184)) return null;
    } else {
        if (aim.target_character != 138) return null;
        if (retainedLabClone(task_target)) {
            target = task_target;
        } else if (!retainedLabClone(last_target)) return null;
    }
    input.* = reconciled;
    return target;
}
fn retainedLabClone(actor: usize) bool {
    return s.valid(actor, 0x1440) and read(u16, actor + 0xdc0) == 138 and
        read(u32, actor + 0x50) & 3 == 1 and s.entities_observed_generation(actor) != 0;
}
fn repeatedLabAim(op: *const s.Lease, actor: usize, target: usize, input: *const p.SyncAimTaskState) bool {
    const frame = s.journal.frame.?;
    if (s.journal.host != 0 or frame.level != 73 or frame.sequence != 1 or s.fire_task_cursor >= frame.fire_task_gate_count or
        read(u16, actor + 0xdc0) != 321 or read(usize, actor + 0xbdc) != target or !s.valid(target, 0x1440) or
        read(u16, target + 0xdc0) != 138 or read(u32, target + 0x50) & 3 != 1) return false;
    const next = &frame.fire_task_gates[s.fire_task_cursor];
    if (next.kind != p.SYNC_ACTOR_FORCE_VISIBILITY or next.payload.force.clock != input.clock or next.payload.force.mode != 1) return false;
    var slot: u32 = 0;
    var generation: u32 = 0;
    if (s.entities_observed_identity(actor, &slot, &generation) == 0 or !s.live(op)) return false;
    var seen = false;
    for (frame.fire_task_gates[0..frame.fire_task_gate_count], 0..) |*entry, index| {
        if (entry.kind != p.SYNC_ACTOR_AIM_TASK or entry.slot != slot or entry.generation != generation) continue;
        if (index >= s.fire_task_cursor) return false;
        const aim = &entry.payload.aim;
        if (aim.target_character != 138) continue;
        var reconciled = input.*;
        reconciled.target_slot = aim.target_slot;
        reconciled.target_generation = aim.target_generation;
        if (@import("cadence_context.zig").aim(aim, &reconciled)) seen = true;
    }
    return seen;
}

pub export fn cadence_prepare_aim_task(actor: usize, task: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    s.aim_task_scope = std.mem.zeroes(s.AimTaskScope);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return 1;
    if (!s.valid(actor, 0x1440) or !s.valid(task, 0x2c)) {
        reject(&op, actor, 8);
        return 1;
    }
    const model = read(usize, actor + 8);
    if (!s.valid(model, 0x43)) {
        reject(&op, actor, 8);
        return 1;
    }
    const class = s.imageClass(read(usize, task), false) orelse {
        reject(&op, actor, 8);
        return 1;
    };
    s.entities_update();
    if (!s.live(&op)) return 1;
    var input = std.mem.zeroes(p.SyncAimTaskState);
    input.rng_engine = read(u32, 0xea178c);
    input.clock = read(u32, 0xfb4b6c);
    input.task_class = class;
    input.remaining = read(f32, task + 0x1c);
    input.minimum = read(f32, task + 0x14);
    input.maximum = read(f32, task + 0x18);
    const target = read(usize, task + 0x10);
    if (s.journal.host != 0 and s.journal.frame.?.level == 73 and s.valid(target, 0x1440) and read(u16, target + 0xdc0) == 138) {
        input.target_character = 138;
    }
    var stale_target_replacement: ?usize = null;
    if (target != 0 and s.entities_observed_identity(target, &input.target_slot, &input.target_generation) == 0) {
        if (repeatedLabAim(&op, actor, target, &input)) return 0;
        stale_target_replacement = staleBlueShadowAimTarget(&op, actor, target, &input) orelse {
            if (s.live(&op)) {
                const frame = s.journal.frame.?;
                if (frame.level == 73 and clonewars_lab_aim_failure[0] != frame.epoch) {
                    clonewars_lab_aim_failure = .{ frame.epoch, frame.sequence, s.fire_task_cursor, input.clock, input.task_class, s.bits(input.minimum), s.bits(input.maximum), @truncate(actor), @truncate(task), @truncate(target), @truncate(read(usize, actor + 0xbdc)), @truncate(read(usize, 0xfb4944)) };
                }
                if (frame.level == 74 and clonewars_lift_aim_failure[0] != frame.epoch) {
                    clonewars_lift_aim_failure = .{ frame.epoch, frame.sequence, s.fire_task_cursor, input.clock, input.task_class, s.bits(input.minimum), s.bits(input.maximum), @truncate(actor), @truncate(task), @truncate(target), @truncate(read(usize, actor + 0xbdc)), @truncate(read(usize, 0xfb4944)) };
                }
                reject(&op, actor, 8);
            }
            return 1;
        };
    }
    if (!s.live(&op)) return 1;
    const local = input;
    const target_correction = if (s.journal.host == 0 and stale_target_replacement == null) blueShadowAimTarget(actor, target, &input) else null;
    const visible: c_int = @intFromBool(read(u8, model + 0x42) != 0);
    const effective = gate.apply(actor, p.SYNC_ACTOR_AIM_TASK, 0, 0, visible, @ptrCast(&input), &s.clonewars_aim_task_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return 1;
    if (s.journal.host == 0) {
        if (stale_target_replacement) |canonical_target| {
            if (read(usize, task + 0x10) != target) {
                reject(&op, actor, 8);
                return 1;
            }
            s.win.store(usize, task + 0x10, canonical_target);
            if (read(usize, actor + 0xbdc) == target) s.win.store(usize, actor + 0xbdc, canonical_target);
        } else if (target_correction) |canonical_target| {
            const saved_target = if (canonical_target == 0) target else 0;
            if (read(usize, task + 0x10) != target or read(usize, actor + 0xbdc) != saved_target) {
                reject(&op, actor, 8);
                return 1;
            }
            s.win.store(usize, task + 0x10, canonical_target);
            if (canonical_target == 0) s.win.store(usize, actor + 0xbdc, 0);
        }
        s.win.store(f32, task + 0x1c, input.remaining);
        s.win.store(u32, 0xea178c, input.rng_engine);
        if (s.clonewars_aim_task_correction[0] == 0 and (stale_target_replacement != null or target_correction != null or local.rng_engine != input.rng_engine or s.bits(local.remaining) != s.bits(input.remaining) or visible != effective)) {
            var slot: u32 = std.math.maxInt(u32);
            var generation: u32 = 0;
            _ = s.entities_observed_identity(actor, &slot, &generation);
            if (!s.live(&op)) return 1;
            s.clonewars_aim_task_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, local.rng_engine, input.rng_engine, s.bits(local.remaining), s.bits(input.remaining), @bitCast(visible), @bitCast(effective), input.clock, input.task_class };
        }
    }
    s.aim_task_scope = .{ .lease = op, .actor = actor, .task = task, .generation = s.entities_observed_generation(actor), .visible = effective, .prepared = true };
    return 1;
}
pub export fn cadence_aim_task_visibility(actor: usize, task: usize, visible: c_int) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return @intFromBool(visible != 0);
    var result: c_int = 0;
    const scope = &s.aim_task_scope;
    if (s.journal.failed == 0 and scope.prepared and scope.actor == actor and scope.task == task and s.live(&scope.lease) and s.entities_observed_generation(actor) == scope.generation) result = scope.visible else if (s.journal.failed == 0) reject(&op, actor, 9);
    scope.prepared = false;
    return result;
}
pub export fn cadence_prepare_rts_competitor(competitor: usize, delta: *f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    if (!s.valid(competitor, 0xd4) or !s.valid(@intFromPtr(delta), 4)) {
        reject(&op, 0, 11);
        return;
    }
    const actor = read(usize, competitor + 0xd0);
    if (!s.valid(actor, 0x1440)) {
        s.clonewars_rts_competitor_debug[4] +%= 1;
        return;
    }
    const component = read(usize, actor + 0x142c);
    if (!s.valid(component, 0x90) or read(usize, component + 0x8c) != competitor) {
        s.clonewars_rts_competitor_debug[4] +%= 1;
        return;
    }
    const class = s.imageClass(read(usize, competitor), false) orelse {
        reject(&op, actor, 11);
        return;
    };
    s.entities_update();
    if (!s.live(&op)) return;
    const allocation = s.entities_observed_generation(actor);
    if (s.entities_allocation_retained(actor, allocation) == 0) {
        reject(&op, actor, 11);
        return;
    }
    var input = std.mem.zeroes(p.SyncRtsCompetitorState);
    input.rng_game = read(u32, 0xe637b4);
    input.rng_engine = read(u32, 0xea178c);
    input.clock = read(u32, 0xfb4b6c);
    input.competitor_class = class;
    input.delta = delta.*;
    const offsets = [_]usize{ 0x60, 0x64, 0x68, 0x6c, 0x70, 0x74, 0x78, 0x7c, 0xa0, 0xa4, 0xa8, 0xac };
    for (offsets, &input.timers) |offset, *timer| timer.* = read(f32, competitor + offset);
    const local = input;
    _ = gate.apply(actor, p.SYNC_ACTOR_RTS_COMPETITOR, 0, 0, 0, @ptrCast(&input), s.clonewars_rts_competitor_debug[0..4]);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return;
    if (s.entities_allocation_retained(actor, allocation) == 0 or read(usize, actor + 0x142c) != component or !s.valid(component, 0x90) or read(usize, component + 0x8c) != competitor or read(usize, competitor + 0xd0) != actor) {
        reject(&op, actor, 11);
        return;
    }
    if (read(u32, actor + 0x50) & 3 != 3) s.clonewars_rts_competitor_debug[if (s.journal.host != 0) 5 else 6] +%= 1;
    if (s.journal.host == 0) {
        if (s.clonewars_rts_competitor_correction[0] == 0 and !equal(&local, &input)) {
            var slot: u32 = std.math.maxInt(u32);
            var generation: u32 = 0;
            _ = s.entities_observed_identity(actor, &slot, &generation);
            if (!s.live(&op)) return;
            s.clonewars_rts_competitor_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, local.rng_engine, input.rng_engine, s.bits(local.timers[0]), s.bits(input.timers[0]), input.clock, input.competitor_class };
        }
        for (offsets, input.timers) |offset, timer| s.win.store(f32, competitor + offset, timer);
        delta.* = input.delta;
        s.win.store(u32, 0xe637b4, input.rng_game);
        s.win.store(u32, 0xea178c, input.rng_engine);
    }
}
fn blueShadowGuestOnlyAim(actor: usize, task: usize) bool {
    const frame = s.journal.frame.?;
    const obi_wan = if (frame.level == 73) read(usize, 0xfb4944) else 0;
    const lab_exit = s.valid(obi_wan, 0x1440) and read(u16, obi_wan + 0xdc0) == 181;
    const lab_resume = frame.level == 73 and (frame.sequence == 1 or lab_exit);
    const droid = read(u16, actor + 0xdc0);
    if (droid != 321 and (droid != 333 or !lab_exit)) return false;
    if (!lab_resume and frame.level != 70) return false;
    if (!lab_resume) {
        const ahsoka = read(usize, 0xfb4940);
        const clone = read(usize, 0xfb4944);
        if (!s.valid(ahsoka, 0x1440) or !s.valid(clone, 0x1440) or
            read(u16, ahsoka + 0xdc0) != 191 or read(u8, ahsoka + 0xdde) != 0 or
            read(u16, clone + 0xdc0) != 156) return false;
        const last_target = read(usize, actor + 0xbdc);
        const target = read(usize, task + 0x10);
        if (read(u8, clone + 0xdde) == 0) {
            if (last_target != 0 or (target != 0 and target != ahsoka and target != clone)) return false;
        } else if (last_target != clone or (target != 0 and target != clone)) return false;
    }
    var slot: u32 = 0;
    var generation: u32 = 0;
    if (s.entities_observed_identity(actor, &slot, &generation) == 0) return false;
    var host_motion = false;
    for (frame.fire_task_gates[0..frame.fire_task_gate_count]) |entry| {
        if (entry.slot != slot or entry.generation != generation) continue;
        if (entry.kind == p.SYNC_ACTOR_AIM_BASE or entry.kind == p.SYNC_ACTOR_AIM_TASK) return false;
        if (entry.kind == p.SYNC_ACTOR_CHARACTER_MOTION and
            (!lab_resume or entry.payload.character_motion.clock == read(u32, 0xfb4b6c))) host_motion = true;
    }
    return host_motion;
}
pub export fn cadence_prepare_aim_base(task: usize, wrapper: usize, delta: *f32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op) or !s.valid(wrapper, 8)) return 1;
    const actor = read(usize, wrapper + 4);
    if (!s.valid(actor, 0x1440)) return 1;
    const model = read(usize, actor + 8);
    if (!s.valid(model, 0x38)) return 1;
    const brain = read(usize, model + 0x34);
    if (!s.valid(brain, 0x19c) or read(u32, brain + 0x198) == 0) return 1;
    if (!s.valid(task, 0x2c) or !s.valid(@intFromPtr(delta), 4)) {
        reject(&op, actor, 12);
        return 1;
    }
    const class = s.imageClass(read(usize, task), false) orelse {
        reject(&op, actor, 12);
        return 1;
    };
    if (s.journal.host == 0 and blueShadowGuestOnlyAim(actor, task)) {
        s.clonewars_aim_base_debug[2] +%= 1;
        return 0;
    }
    var input = std.mem.zeroes(p.SyncAimBaseState);
    input.rng_engine = read(u32, 0xea178c);
    input.rng_game = read(u32, 0xe637b4);
    input.clock = read(u32, 0xfb4b6c);
    input.task_class = class;
    input.delta = delta.*;
    const callback = read(usize, task + 4);
    if (callback != 0) {
        if (!s.valid(callback, 4)) {
            reject(&op, actor, 12);
            return 1;
        }
        input.callback_class = s.imageClass(read(usize, callback), false) orelse {
            reject(&op, actor, 12);
            return 1;
        };
    }
    input.elapsed = read(f32, task + 8);
    input.remaining = read(f32, task + 0x1c);
    const local = input;
    _ = gate.apply(actor, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, @ptrCast(&input), &s.clonewars_aim_base_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return 1;
    if (s.journal.host == 0) {
        s.win.store(f32, task + 8, input.elapsed);
        s.win.store(f32, task + 0x1c, input.remaining);
        delta.* = input.delta;
        s.win.store(u32, 0xea178c, input.rng_engine);
        s.win.store(u32, 0xe637b4, input.rng_game);
        if (!equal(&local, &input)) {
            s.clonewars_aim_base_debug[2] +%= 1;
            if (s.clonewars_aim_base_correction[0] == 0) {
                var slot: u32 = std.math.maxInt(u32);
                var generation: u32 = 0;
                _ = s.entities_observed_identity(actor, &slot, &generation);
                if (s.live(&op)) s.clonewars_aim_base_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, input.clock, input.task_class, input.callback_class, s.bits(local.elapsed), s.bits(input.elapsed), s.bits(local.remaining), s.bits(input.remaining), s.bits(input.delta) };
            }
        }
    }
    return 1;
}
