const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
pub export var clonewars_character_support_release_debug: [10]u32 = @splat(0);
pub export var clonewars_character_support_unknown_count_debug: [1]u32 = @splat(0);
pub export var clonewars_character_support_unknown_debug: [640]u32 = @splat(0);
pub export var clonewars_character_support_failure_debug: [4]u32 = @splat(0);
extern fn entities_allocation_live(usize, u32) c_int;
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
extern fn physics_effect_body_resolve(u32, u32) usize;
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
            if (support == 0) state.support_material_flags = p.SYNC_SUPPORT_ABSENT;
            const support_readable = s.valid(support, 0x1a);
            if (support_readable and @import("support_reference.zig").capture(support, &support_source, &state.support_material_flags)) {
                state.support_frame = support_source[0];
                state.support_event = support_source[1];
                state.support_anchor = read([4]f32, body + 0x110);
                state.support_normal = read([3]f32, body + 0xf0);
                state.support_material_flags |= @as(u32, read(u16, body + 0x102)) | ((read(u32, body + 0xc0) & 1) << 16);
            }
            if (support != 0 and state.support_frame == 0 and s.live(&op)) {
                const offset = (clonewars_character_support_unknown_count_debug[0] & 63) * 10;
                clonewars_character_support_unknown_debug[offset..][0..10].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, state.clock, read(u16, actor + 0xdc0), @truncate(body), @truncate(support), if (support_readable) read(u32, support) else 0, if (support_readable) read(u8, support + 0x19) else 0, read(u32, body + 0xc0), 0 };
                clonewars_character_support_unknown_count_debug[0] +%= 1;
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
        const fault = &s.clonewars_character_motion_failure;
        if (fault[0] == 6 and fault[1] == local.clock) {
            const support_label = if (s.valid(support, 0x20)) read(usize, support + 0x1c) else 0;
            clonewars_character_support_failure_debug = .{ @truncate(actor), @truncate(body), @truncate(support), @truncate(support_label) };
        }
        if (!s.live(&op) or !s.active or s.journal.failed != 0 or s.journal.host != 0) return;
        reason = 7;
        if (entities_allocation_live(actor, allocation) == 0 or read(usize, actor + 8) != model or !s.valid(model, 0x3c) or read(usize, model + 0x38) != body or !s.valid(body, 0xca)) break :input;
        const class = s.imageClass(read(usize, body), true) orelse break :input;
        const acquiring = @import("character_support.zig").canAcquire(&local, &state);
        const releasing = @import("character_support.zig").canRelease(&local, &state);
        if (class != state.body_class or state.clock != read(u32, 0xfb4b6c) or state.rest_counter > 65535 or (!s.supportSame(&local, &state) and !acquiring and !releasing)) break :input;
        if (releasing) {
            reason = 10;
            var current_source: [2]u32 = @splat(0);
            if (local.support_frame != 0 and (!@import("support_reference.zig").source(support, &local, &current_source) or !equal(&current_source, &support_source))) break :input;
            if (!s.live(&op) or s.journal.failed != 0) return;
            if (!@import("character_support.zig").release(body, support, &local, &state)) break :input;
            if (clonewars_character_support_release_debug[0] == 0) {
                var slot: u32 = std.math.maxInt(u32);
                var generation: u32 = 0;
                _ = s.entities_observed_identity(actor, &slot, &generation);
                if (!s.live(&op)) return;
                clonewars_character_support_release_debug[1..10].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, state.clock, slot, generation, local.support_frame, local.support_event, @truncate(support), @truncate(body) };
            }
            clonewars_character_support_release_debug[0] +%= 1;
        }
        if (state.support_frame != 0) {
            reason = 8;
            const canonical_support = if (acquiring) @import("support_reference.zig").resolve(&state) else support;
            if (!s.live(&op) or s.journal.failed != 0) return;
            var current_source: [2]u32 = @splat(0);
            if (acquiring and local.support_frame != 0 and (!@import("support_reference.zig").source(support, &local, &current_source) or !equal(&current_source, &support_source))) break :input;
            if (!s.valid(body, 0x140) or read(usize, body + 0xec) != support or canonical_support == 0 or !@import("support_reference.zig").source(canonical_support, &state, &current_source) or !equal(&current_source, &[_]u32{ state.support_frame, state.support_event })) break :input;
            if (!s.live(&op) or s.journal.failed != 0) return;
            if (!equal(&local.support_anchor, &state.support_anchor) or !equal(&local.support_normal, &state.support_normal) or local.support_material_flags != state.support_material_flags) {
                s.clonewars_character_support_debug[2] +%= 1;
                if (s.clonewars_character_support_debug[3] == 0) {
                    s.clonewars_character_support_debug[3..6].* = .{ state.clock, state.support_frame, state.support_event };
                    @memcpy(std.mem.asBytes(&s.clonewars_character_support_local), std.mem.asBytes(&local)[28..68]);
                    @memcpy(std.mem.asBytes(&s.clonewars_character_support_host), std.mem.asBytes(&state)[28..68]);
                }
            }
            reason = 9;
            if (acquiring) {
                if (!@import("character_support.zig").acquire(body, canonical_support, &local, &state)) break :input;
                s.clonewars_character_support_debug[6] +%= 1;
            } else if (!@import("character_support.zig").replay(body, &local, &state)) break :input;
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
