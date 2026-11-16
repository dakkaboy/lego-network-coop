const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
extern fn entities_allocation_live(usize, u32) c_int;
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
pub export fn cadence_character_motion_input(actor: usize, body: usize, velocity: *[4]f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    var state = std.mem.zeroes(p.SyncCharacterMotionState);
    var reason: u32 = 1;
    if (!s.ready(&op)) return;
    input: {
        if (!s.valid(actor, 0x1440) or !s.valid(body, 0xca) or !s.valid(@intFromPtr(velocity), 16)) break :input;
        const model = read(usize, actor + 8);
        if (!s.valid(model, 0x3c) or read(usize, model + 0x38) != body) break :input;
        state.clock = read(u32, 0xfb4b6c);
        reason = 2;
        state.body_class = s.imageClass(read(usize, body), true) orelse break :input;
        state.rest_counter = read(u16, body + 0xc8);
        state.velocity = velocity.*;
        var support: usize = 0;
        var support_source: [2]u32 = @splat(0);
        if (s.valid(body, 0x140)) {
            support = read(usize, body + 0xec);
            if (s.valid(support, 0x1a) and read(u8, support + 0x19) & 0x60 == 0x40 and physics_effect_body_source(support, &support_source) != 0) {
                state.support_frame = support_source[0];
                state.support_event = support_source[1];
                state.support_anchor = read([4]f32, body + 0x110);
                state.support_normal = read([3]f32, body + 0xf0);
                state.support_material_flags = @as(u32, read(u16, body + 0x102)) | ((read(u32, body + 0xc0) & 1) << 16);
            }
        }
        reason = 3;
        if (!@import("fire_validation.zig").supportValid(&state)) break :input;
        reason = 4;
        if (!@import("validation.zig").finite(state.velocity)) break :input;
        reason = 5;
        s.entities_update();
        if (!s.live(&op)) return;
        const allocation = s.entities_observed_generation(actor);
        if (allocation == 0 or entities_allocation_live(actor, allocation) == 0) break :input;
        const local = state;
        if (s.journal.host != 0 and state.support_frame != 0) s.clonewars_character_support_debug[0] +%= 1;
        _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&state), &s.clonewars_character_motion_debug);
        if (!s.live(&op) or !s.active or s.journal.failed != 0 or s.journal.host != 0) return;
        reason = 7;
        if (entities_allocation_live(actor, allocation) == 0 or read(usize, actor + 8) != model or !s.valid(model, 0x3c) or read(usize, model + 0x38) != body or !s.valid(body, 0xca)) break :input;
        const class = s.imageClass(read(usize, body), true) orelse break :input;
        if (class != state.body_class or state.clock != read(u32, 0xfb4b6c) or state.rest_counter > 65535 or !s.supportSame(&local, &state)) break :input;
        if (state.support_frame != 0) {
            reason = 8;
            var current_source: [2]u32 = @splat(0);
            if (!s.valid(body, 0x140) or read(usize, body + 0xec) != support or physics_effect_body_source(support, &current_source) == 0 or !equal(&current_source, &support_source)) break :input;
            if (!equal(&local.support_anchor, &state.support_anchor) or !equal(&local.support_normal, &state.support_normal) or local.support_material_flags != state.support_material_flags) {
                s.clonewars_character_support_debug[2] +%= 1;
                if (s.clonewars_character_support_debug[3] == 0) {
                    s.clonewars_character_support_debug[3..6].* = .{ state.clock, state.support_frame, state.support_event };
                    @memcpy(std.mem.asBytes(&s.clonewars_character_support_local), std.mem.asBytes(&local)[28..68]);
                    @memcpy(std.mem.asBytes(&s.clonewars_character_support_host), std.mem.asBytes(&state)[28..68]);
                }
            }
            reason = 9;
            if (!@import("character_support.zig").replay(body, &local, &state)) break :input;
        }
        if (state.support_frame != 0) s.clonewars_character_support_debug[1] +%= 1;
        if (!equal(&local.velocity, &state.velocity) or local.rest_counter != state.rest_counter) {
            s.clonewars_character_motion_debug[2] +%= 1;
            if (s.clonewars_character_motion_correction[0] == 0) {
                var slot: u32 = std.math.maxInt(u32);
                var generation: u32 = 0;
                _ = s.entities_observed_identity(actor, &slot, &generation);
                if (!s.live(&op)) return;
                var values: [16]u32 = undefined;
                values[0..6].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, state.clock, state.body_class };
                values[6..10].* = @bitCast(local.velocity);
                values[10..14].* = @bitCast(state.velocity);
                values[14..16].* = .{ local.rest_counter, state.rest_counter };
                s.clonewars_character_motion_correction = values;
            }
        }
        velocity.* = state.velocity;
        s.win.store(u16, body + 0xc8, @intCast(state.rest_counter));
        return;
    }
    if (s.live(&op)) {
        s.motionFailure(reason, &state, null);
        s.journal.failed = 16;
        s.clonewars_character_motion_debug[3] +%= 1;
        s.failed(&op, actor, null, 16);
    }
}
