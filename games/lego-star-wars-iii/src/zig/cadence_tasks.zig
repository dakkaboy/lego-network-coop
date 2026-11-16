const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
fn reject(op: *const s.Lease, actor: usize, reason: u32) void {
    s.journal.failed = @bitCast(reason);
    s.failed(op, actor, null, reason);
}
pub export fn cadence_prepare_aim_task(actor: usize, task: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    s.aim_task_scope = std.mem.zeroes(s.AimTaskScope);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    if (!s.valid(actor, 0x1440) or !s.valid(task, 0x2c)) {
        reject(&op, actor, 8);
        return;
    }
    const model = read(usize, actor + 8);
    if (!s.valid(model, 0x43)) {
        reject(&op, actor, 8);
        return;
    }
    const class = s.imageClass(read(usize, task), false) orelse {
        reject(&op, actor, 8);
        return;
    };
    s.entities_update();
    if (!s.live(&op)) return;
    var input = std.mem.zeroes(p.SyncAimTaskState);
    input.rng_engine = read(u32, 0xea178c);
    input.clock = read(u32, 0xfb4b6c);
    input.task_class = class;
    input.remaining = read(f32, task + 0x1c);
    input.minimum = read(f32, task + 0x14);
    input.maximum = read(f32, task + 0x18);
    const target = read(usize, task + 0x10);
    if (target != 0 and s.entities_observed_identity(target, &input.target_slot, &input.target_generation) == 0) {
        reject(&op, actor, 8);
        return;
    }
    if (!s.live(&op)) return;
    const local = input;
    const visible: c_int = @intFromBool(read(u8, model + 0x42) != 0);
    const effective = gate.apply(actor, p.SYNC_ACTOR_AIM_TASK, 0, 0, visible, @ptrCast(&input), &s.clonewars_aim_task_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return;
    if (s.journal.host == 0) {
        s.win.store(f32, task + 0x1c, input.remaining);
        s.win.store(u32, 0xea178c, input.rng_engine);
        if (s.clonewars_aim_task_correction[0] == 0 and (local.rng_engine != input.rng_engine or s.bits(local.remaining) != s.bits(input.remaining) or visible != effective)) {
            var slot: u32 = std.math.maxInt(u32);
            var generation: u32 = 0;
            _ = s.entities_observed_identity(actor, &slot, &generation);
            if (!s.live(&op)) return;
            s.clonewars_aim_task_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, local.rng_engine, input.rng_engine, s.bits(local.remaining), s.bits(input.remaining), @bitCast(visible), @bitCast(effective), input.clock, input.task_class };
        }
    }
    s.aim_task_scope = .{ .lease = op, .actor = actor, .task = task, .generation = s.entities_observed_generation(actor), .visible = effective, .prepared = true };
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
pub export fn cadence_prepare_aim_base(task: usize, wrapper: usize, delta: *f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op) or !s.valid(wrapper, 8)) return;
    const actor = read(usize, wrapper + 4);
    if (!s.valid(actor, 0x1440)) return;
    const model = read(usize, actor + 8);
    if (!s.valid(model, 0x38)) return;
    const brain = read(usize, model + 0x34);
    if (!s.valid(brain, 0x19c) or read(u32, brain + 0x198) == 0) return;
    if (!s.valid(task, 0x2c) or !s.valid(@intFromPtr(delta), 4)) {
        reject(&op, actor, 12);
        return;
    }
    const class = s.imageClass(read(usize, task), false) orelse {
        reject(&op, actor, 12);
        return;
    };
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
            return;
        }
        input.callback_class = s.imageClass(read(usize, callback), false) orelse {
            reject(&op, actor, 12);
            return;
        };
    }
    input.elapsed = read(f32, task + 8);
    input.remaining = read(f32, task + 0x1c);
    const local = input;
    _ = gate.apply(actor, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, @ptrCast(&input), &s.clonewars_aim_base_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return;
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
}
