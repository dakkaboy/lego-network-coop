const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const equal = @import("validation.zig").equal;
pub export var clonewars_rider_fire_input_debug: [4]u32 = @splat(0);
pub export var clonewars_rider_fire_input_failure: [10]u32 = @splat(0);
pub export var clonewars_rider_fire_input_correction: [12]u32 = @splat(0);
const Source = struct { parent: usize, model: usize, actor_generation: u32, mount_generation: u32, side: u16, state: p.SyncRiderFireState, visible: u32 };
fn source(actor: usize, mount: usize, timer: usize, caller: usize) ?Source {
    const side: u16 = if (caller == 0x463316) 0 else if (caller == 0x46332b) 1 else return null;
    const offset = @as(usize, 0x364) + @as(usize, side) * 4;
    if (timer < offset or !s.valid(actor, 0x1440) or !s.valid(mount, 0x1440)) return null;
    const parent = timer - offset;
    if (!s.valid(parent, 0x36c) or s.read(usize, parent + 0x35c + @as(usize, side) * 4) != mount or s.read(usize, mount + 0x6fc) != actor) return null;
    const class = s.imageClass(s.read(usize, parent), true) orelse return null;
    if (class != 0x6d83dc) return null;
    const model = s.read(usize, actor + 8);
    if (!s.valid(model, 0x43)) return null;
    var slot: u32 = std.math.maxInt(u32);
    var generation: u32 = 0;
    const actor_generation = s.entities_observed_generation(actor);
    if (s.entities_observed_identity(mount, &slot, &generation) == 0 or actor_generation == 0 or generation == 0 or slot >= p.SYNC_MAX_ACTORS) return null;
    const state: p.SyncRiderFireState = .{ .clock = s.read(u32, 0xfb4b6c), .behavior_class = class, .mount_slot = slot, .mount_generation = generation, .cooldown = s.read(f32, timer) };
    if (!@import("validation.zig").finite(state.cooldown)) return null;
    return .{ .parent = parent, .model = model, .actor_generation = actor_generation, .mount_generation = generation, .side = side, .state = state, .visible = @intFromBool(s.read(u8, model + 0x42) != 0) };
}
fn failed(op: *const s.Lease, actor: usize, mount: usize, timer: usize, caller: usize, reason: u32) void {
    if (!s.live(op)) return;
    clonewars_rider_fire_input_debug[3] +%= 1;
    if (clonewars_rider_fire_input_failure[0] == 0) clonewars_rider_fire_input_failure = .{ reason, op.cohort.epoch, op.cohort.sequence, s.read(u32, 0xfb4b6c), @truncate(actor), @truncate(mount), @truncate(timer), @truncate(caller), 0, 0 };
    s.journal.failed = 21;
    s.failed(op, actor, null, 21);
}
pub export fn cadence_rider_fire_input(actor: usize, mount: usize, timer: usize, caller: usize) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const model = if (s.valid(actor, 12)) s.read(usize, actor + 8) else 0;
    const local_visible: u32 = @intFromBool(s.valid(model, 0x43) and s.read(u8, model + 0x42) != 0);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return local_visible;
    s.entities_update();
    if (!s.live(&op)) return local_visible;
    const before = source(actor, mount, timer, caller) orelse {
        failed(&op, actor, mount, timer, caller, 1);
        return local_visible;
    };
    var state = before.state;
    const visible = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_RIDER_FIRE, before.side, 0, @intCast(before.visible), @ptrCast(&state), &clonewars_rider_fire_input_debug);
    if (!s.live(&op) or s.journal.failed != 0) return local_visible;
    if (!@import("validation.zig").finite(state.cooldown) or visible < 0 or visible > 1) {
        failed(&op, actor, mount, timer, caller, 4);
        return local_visible;
    }
    const now = source(actor, mount, timer, caller) orelse {
        failed(&op, actor, mount, timer, caller, 2);
        return local_visible;
    };
    if (before.parent != now.parent or before.model != now.model or before.actor_generation != now.actor_generation or before.mount_generation != now.mount_generation or before.side != now.side or before.visible != now.visible or !equal(&before.state, &now.state) or !s.win.accessible(timer, 4, true)) {
        failed(&op, actor, mount, timer, caller, 3);
        return local_visible;
    }
    if (s.journal.host == 0) {
        if (before.visible != @as(u32, @intCast(visible)) or @as(u32, @bitCast(before.state.cooldown)) != @as(u32, @bitCast(state.cooldown))) {
            if (clonewars_rider_fire_input_correction[0] == 0) clonewars_rider_fire_input_correction = .{ op.cohort.epoch, op.cohort.sequence, state.clock, state.mount_slot, state.mount_generation, before.visible, @intCast(visible), @bitCast(before.state.cooldown), @bitCast(state.cooldown), before.side, @truncate(actor), @truncate(mount) };
        }
        // Each rider has a native cooldown outside the actor's ordinary weapon state.
        s.win.store(f32, timer, state.cooldown);
    }
    return @intCast(visible);
}
