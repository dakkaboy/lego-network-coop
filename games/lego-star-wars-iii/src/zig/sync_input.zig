const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const load = s.load;
const store = s.store;
pub fn assignmentVersion() callconv(.c) u64 {
    return s.assignment_lease_serial;
}
pub fn assignmentRemap(version: u64) callconv(.c) void {
    if (version != s.assignment_lease_serial) return;
    var changed = false;
    for (0..2) |slot| {
        var owner: usize = 0;
        var allocation: u32 = 0;
        if (s.changed_actor[slot] != 0 and api.tags_resolve_controller_owner(s.changed_actor[slot], s.changed_generation[slot], s.changed_controller[slot], &owner, &allocation) != 0 and (owner != s.changed_actor[slot] or allocation != s.changed_generation[slot])) {
            s.changed_actor[slot] = owner;
            s.changed_generation[slot] = allocation;
            changed = true;
        }
    }
    if (changed) s.assignment_lease_serial +%= 1;
}
pub fn releaseAssignment(slot: usize) void {
    const controller = s.changed_controller[slot];
    var actor = s.changed_actor[slot];
    var allocation = s.changed_generation[slot];
    var owner: usize = 0;
    var owner_allocation: u32 = 0;
    if (actor != 0 and api.tags_resolve_controller_owner(actor, allocation, controller, &owner, &owner_allocation) != 0) {
        actor = owner;
        allocation = owner_allocation;
    }
    const owns = api.entities_allocation_live(actor, allocation) != 0 and load(usize, actor + 0x6cc) == controller;
    const owns_device = owns and s.valid(controller, 4) and load(usize, controller) == @intFromPtr(&s.remote_device[slot]);
    if (owns_device) {
        store(usize, controller, s.saved_device[slot]);
        if (actor == s.player(slot)) store(u32, actor + 0x50, (load(u32, actor + 0x50) & ~@as(u32, 0x200)) | s.saved_human[slot]);
    }
    s.changed_controller[slot] = 0;
    s.changed_actor[slot] = 0;
    s.changed_generation[slot] = 0;
    s.assignment_lease_serial +%= 1;
}
pub fn releaseRemote() void {
    assignmentRemap(assignmentVersion());
    @memset(std.mem.asBytes(&s.remote_device), 0);
    _ = @atomicRmw(u32, &s.lifecycle_release_serial, .Add, 1, .seq_cst);
    api.coherent_frame_cancel_atomic(1);
    @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    s.running = false;
    s.latched_ready = false;
    api.remote_input_pulse_reset(&s.remote_pulse);
    api.remote_input_trace_reset();
    s.prep_gate_depth = 0;
    s.pending_actor_pressed = @splat(0);
}
fn axes(held: u32, x: u8, y: u8) u32 {
    var result = held;
    if (x < 43) result |= load(u32, 0xe64124);
    if (x > 212) result |= load(u32, 0xe64128);
    if (y < 43) result |= load(u32, 0xe6411c);
    if (y > 212) result |= load(u32, 0xe64120);
    return result;
}
pub fn read() s.p.SyncInput {
    var input = s.p.SyncInput{ .held = 0, .pressed = 0, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
    if (api.network_window_input_blocked() != 0) {
        s.previous_local_held = 0;
        return input;
    }
    const input_service = load(usize, 0xfb0b70);
    if (load(u8, 0xf91eb4) & 2 != 0 or (s.valid(input_service, 0x2c) and load(i32, input_service + 0x28) != 0)) {
        s.previous_local_held = 0;
        return input;
    }
    const controller = s.controller(0);
    if (controller == 0) return input;
    if (@atomicLoad(i32, &s.clonewars_input_override[3], .seq_cst) > 0) {
        input.held = @bitCast(@atomicLoad(i32, &s.clonewars_input_override[0], .seq_cst));
        input.pressed = @as(u32, @bitCast(@atomicRmw(i32, &s.clonewars_input_override[1], .Xchg, 0, .seq_cst))) | (input.held & ~s.previous_local_held);
        const packed_axes: u32 = @bitCast(@atomicLoad(i32, &s.clonewars_input_override[2], .seq_cst));
        const aim: u32 = @bitCast(@atomicLoad(i32, &s.clonewars_input_override_aim, .seq_cst));
        input.analog_x = @truncate(packed_axes);
        input.analog_y = @truncate(packed_axes >> 8);
        input.aim_x = @truncate(aim);
        input.aim_y = @truncate(aim >> 8);
        input.held = axes(input.held, input.analog_x, input.analog_y);
        input.pressed |= input.held & ~s.previous_local_held;
        s.previous_local_held = input.held;
        _ = @atomicRmw(i32, &s.clonewars_input_override[3], .Sub, 1, .seq_cst);
        return input;
    }
    if (s.neutral_background_input) {
        s.previous_local_held = 0;
        return input;
    }
    input.held = load(u32, controller + 4);
    input.pressed = load(u32, controller + 8);
    var device = load(usize, controller);
    const root = load(usize, 0xfb2e60);
    if (s.valid(root, 0x1850)) {
        const physical = load(usize, root + 0x184c);
        if (s.valid(physical, 0xb0)) {
            device = physical;
            input.held = load(u32, physical + 0x70);
            input.pressed = load(u32, physical + 0x78);
            input.held = axes(input.held, load(u8, physical + 0x9d), load(u8, physical + 0x9e));
            input.pressed |= input.held & ~s.previous_local_held;
            s.previous_local_held = input.held;
        }
    }
    if (s.valid(device, 0x9f)) {
        input.analog_x = load(u8, device + 0x9d);
        input.analog_y = load(u8, device + 0x9e);
        input.aim_x = load(u8, device + 0x9b);
        input.aim_y = load(u8, device + 0x9c);
    }
    return input;
}
pub fn inputSame(slot: usize, actor: usize, controller: usize, allocation: u32, release: u32, assignment: u64) bool {
    return s.live() and !s.releaseChanged(release) and assignment == s.assignment_lease_serial and s.player(slot) == actor and s.controller(slot) == controller and api.entities_allocation_live(actor, allocation) != 0;
}
fn failed(reason: u32, slot: usize, actor: usize, controller: usize, allocation: u32) c_int {
    if (@cmpxchgStrong(u32, &s.clonewars_input_assignment_failure[0], 0, 0xffffffff, .seq_cst, .seq_cst) == null) {
        const values = [16]u32{ s.working.epoch, s.working.sequence, reason, @intCast(slot), actor, controller, allocation, if (s.valid(controller, 4)) load(u32, controller) else 0, s.changed_actor[slot], s.changed_controller[slot], s.changed_generation[slot], s.saved_device[slot], load(u32, 0xeb1a70 + slot * 8), @intFromPtr(&s.remote_device[0]), @intFromPtr(&s.remote_device[1]), api.coherent_frame_release() };
        s.clonewars_input_assignment_failure[1..16].* = values[1..16].*;
        @atomicStore(u32, &s.clonewars_input_assignment_failure[0], values[0], .seq_cst);
    }
    return 0;
}
pub fn deviceSource(observed: usize, shadow: usize, other_shadow: usize, original: usize, original_session: u32, session: u32, out: *usize) c_int {
    if (observed == other_shadow) return 4;
    if (observed == shadow) {
        if (session == 0 or session == 0xffffffff or original_session != session) return 5;
        out.* = original;
    } else out.* = observed;
    return 0;
}
pub fn write(slot: usize, input: *const s.p.SyncInput) c_int {
    if (!s.live()) return 0;
    const controller = s.controller(slot);
    const actor = s.player(slot);
    if (controller == 0 or actor == 0) return failed(1, slot, actor, controller, 0);
    const allocation = api.entities_local_generation(actor);
    if (allocation == 0) return failed(2, slot, actor, controller, allocation);
    if (slot == 1 and load(i32, 0xeb1a78) < 0) return failed(3, slot, actor, controller, allocation);
    if (s.changed_controller[slot] != controller or s.changed_actor[slot] != actor or s.changed_generation[slot] != allocation or load(usize, controller) != @intFromPtr(&s.remote_device[slot])) {
        const original = s.saved_device[slot];
        const original_session = s.saved_device_session[slot];
        const session = api.lan_session_serial();
        releaseAssignment(slot);
        var source: usize = 0;
        const error_code = deviceSource(load(usize, controller), @intFromPtr(&s.remote_device[slot]), @intFromPtr(&s.remote_device[1 - slot]), original, original_session, session, &source);
        if (error_code != 0) return failed(@intCast(error_code), slot, actor, controller, allocation);
        if (source == 0) {
            if (api.game_native_join_party_player(@intCast(slot), actor, controller) == 0) return 1;
            if (!s.live() or api.lan_session_serial() != session or api.entities_allocation_live(actor, allocation) == 0 or s.player(slot) != actor or load(usize, actor + 0x6cc) != controller) return 0;
            source = load(usize, controller);
        }
        if (!s.live() or api.lan_session_serial() != session) return 0;
        @memset(&s.remote_device[slot], 0);
        if (s.valid(source, 0xb0)) @memcpy(s.remote_device[slot][0..0xb0], @as([*]const u8, @ptrFromInt(source))[0..0xb0]);
        s.saved_device[slot] = source;
        s.saved_device_session[slot] = session;
        s.changed_controller[slot] = controller;
        s.changed_actor[slot] = actor;
        s.changed_generation[slot] = allocation;
        s.saved_human[slot] = load(u32, actor + 0x50) & 0x200;
        s.assignment_lease_serial +%= 1;
    }
    store(u8, 0xfb484d + slot * 0x20, 1);
    store(usize, controller, @intFromPtr(&s.remote_device[slot]));
    store(u32, actor + 0x50, load(u32, actor + 0x50) | 0x200);
    const held = input.held | input.pressed;
    store(u32, controller + 4, held);
    store(u32, controller + 8, input.pressed);
    const device = load(usize, controller);
    store(u32, device + 0x70, held);
    store(u32, device + 0x78, input.pressed);
    store(u32, device + 0x88, load(u32, device + 0x88) | 4);
    store(u8, device + 0x9b, input.aim_x);
    store(u8, device + 0x9c, input.aim_y);
    store(u8, device + 0x9d, input.analog_x);
    store(u8, device + 0x9e, input.analog_y);
    return 1;
}
pub fn sampleWait() void {
    s.sampled_for_flow = false;
    if (s.clonewars_wait_input_sampling == 0 or @atomicLoad(i32, &s.clonewars_input_override[3], .seq_cst) > 0) {
        api.input_buffer_reset(&s.local_buffer);
        return;
    }
    const input = read();
    api.input_buffer_sample(&s.local_buffer, &input);
    s.sampled_for_flow = true;
    if (api.lan_is_host() == 0) {
        s.local_input = api.input_buffer_take(&s.local_buffer);
        api.lan_publish_input(&s.local_input);
    }
}
pub fn refresh(device: usize) callconv(.c) c_int {
    if (device == @intFromPtr(&s.remote_device[0]) or device == @intFromPtr(&s.remote_device[1])) return 1;
    const native: *const fn (usize) callconv(.c) c_int = @ptrFromInt(0x57b340);
    return native(device);
}
