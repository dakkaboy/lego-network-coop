const std = @import("std");
const s = @import("sync_state.zig");
const input = @import("sync_input.zig");
const win = s.win;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var actors: [2][0x2000]u8 align(16) = undefined;
var controllers: [2][0x100]u8 align(16) = undefined;
var devices: [2][0x200]u8 align(16) = undefined;
var root: [0x2000]u8 align(16) = undefined;
var service: [0x100]u8 align(16) = undefined;
var owner: s.owner.Scope = undefined;
var generations: [2]u32 = .{ 19, 20 };
var blocked = false;
var live = true;
var join = true;
var join_cancel = false;
var remap = false;
var cancelled: u32 = 0;
var published: u32 = 0;
pub const sync_test_api = struct {
    pub fn lan_session_serial() u32 {
        return 17;
    }
    pub fn coherent_frame_valid(_: *const s.Token, _: u32) c_int {
        return @intFromBool(live);
    }
    pub fn coherent_frame_release() u32 {
        return 9;
    }
    pub fn coherent_frame_cancel_atomic(mask: u32) void {
        cancelled |= mask;
    }
    pub fn network_window_input_blocked() c_int {
        return @intFromBool(blocked);
    }
    pub fn entities_local_generation(actor: usize) u32 {
        for (0..2) |i| if (actor == actorAt(i)) return generations[i];
        return 0;
    }
    pub fn entities_allocation_live(actor: usize, generation: u32) c_int {
        return @intFromBool(generation != 0 and generation == entities_local_generation(actor));
    }
    pub fn tags_resolve_controller_owner(actor: usize, generation: u32, controller: usize, out: *usize, allocation: *u32) c_int {
        if (remap and actor == actorAt(0) and generation == 19 and controller == controllerAt(0)) {
            out.* = actorAt(1);
            allocation.* = generations[1];
            return 1;
        }
        return 0;
    }
    pub fn game_native_join_party_player(slot: c_int, _: usize, controller: usize) c_int {
        if (!join) return 0;
        s.store(usize, controller, deviceAt(@intCast(slot)));
        if (join_cancel) live = false;
        return 1;
    }
    pub fn remote_input_trace_reset() void {}
    pub const remote_input_pulse_reset = s.abi.remote_input_pulse_reset;
    pub const input_buffer_reset = s.abi.input_buffer_reset;
    pub const input_buffer_sample = s.abi.input_buffer_sample;
    pub const input_buffer_take = s.abi.input_buffer_take;
    pub fn lan_is_host() c_int {
        return 0;
    }
    pub fn lan_publish_input(_: *const s.p.SyncInput) void {
        published += 1;
    }
};
export fn coherent_frame_valid(token: *const s.Token, phases: u32) c_int {
    return sync_test_api.coherent_frame_valid(token, phases);
}
export fn coherent_frame_cancel_atomic(mask: u32) void {
    sync_test_api.coherent_frame_cancel_atomic(mask);
}
fn actorAt(i: usize) usize {
    return @intFromPtr(&actors[i]);
}
fn controllerAt(i: usize) usize {
    return @intFromPtr(&controllers[i]);
}
fn deviceAt(i: usize) usize {
    return @intFromPtr(&devices[i]);
}
fn setup() void {
    @memset(std.mem.asBytes(&actors), 0);
    @memset(std.mem.asBytes(&controllers), 0);
    @memset(std.mem.asBytes(&devices), 0);
    @memset(&root, 0);
    @memset(&service, 0);
    s.store(usize, 0xfb2e60, @intFromPtr(&root));
    s.store(usize, 0xfb0b70, @intFromPtr(&service));
    s.store(u8, 0xf91eb4, 0);
    for (0..2) |i| {
        s.store(usize, 0xfb4940 + i * 4, actorAt(i));
        s.store(usize, actorAt(i) + 0x6cc, controllerAt(i));
        s.store(u32, actorAt(i) + 0x50, 3);
        s.store(usize, controllerAt(i), deviceAt(i));
        devices[i][0x9b] = 128;
        devices[i][0x9c] = 128;
        devices[i][0x9d] = 128;
        devices[i][0x9e] = 128;
    }
    s.store(i32, 0xeb1a78, 1);
    s.store(u32, 0xe64124, 1);
    s.store(u32, 0xe64128, 2);
    s.store(u32, 0xe6411c, 4);
    s.store(u32, 0xe64120, 8);
    s.core = std.mem.zeroes(s.Core);
    s.core.owner = &owner;
    s.core.opened = 1;
    s.core.session = 17;
    s.core.release = 9;
    s.core.token.epoch = 7;
    s.core.token.frame = @intFromPtr(&s.working);
    s.lifecycle_release_serial = 9;
    s.tick_thread = win.GetCurrentThreadId();
    s.reject_bits = 0;
    s.bindings = std.mem.zeroes(@TypeOf(s.bindings));
    s.working.epoch = 7;
    s.working.sequence = 3;
    s.changed_actor = @splat(0);
    s.changed_controller = @splat(0);
    s.changed_generation = @splat(0);
    s.saved_device = @splat(0);
    s.saved_device_session = @splat(0);
    s.saved_human = @splat(0);
    s.assignment_lease_serial = 0;
    s.previous_local_held = 0;
    s.clonewars_input_override = @splat(0);
    s.clonewars_input_override_aim = 0x8080;
    s.neutral_background_input = false;
    s.clonewars_input_assignment_failure = @splat(0);
    s.clonewars_wait_input_sampling = 0;
    generations = .{ 19, 20 };
    blocked = false;
    live = true;
    join = true;
    join_cancel = false;
    remap = false;
    cancelled = 0;
    published = 0;
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) <= 0xe60000 and @intFromPtr(&owned_image) + owned_image.len >= 0xfb5000);
    setup();
    s.store(u32, controllerAt(0) + 4, 16);
    s.store(u32, controllerAt(0) + 8, 32);
    var value = input.read();
    check(@src(), value.held == 16 and value.pressed == 32 and value.analog_x == 128);
    blocked = true;
    s.previous_local_held = 123;
    value = input.read();
    check(@src(), value.held == 0 and s.previous_local_held == 0);
    blocked = false;
    s.clonewars_input_override = .{ 16, 32, 0xff00, 2 };
    s.clonewars_input_override_aim = 0x1234;
    value = input.read();
    check(@src(), value.held == 25 and value.pressed == 57 and value.analog_x == 0 and value.analog_y == 255 and value.aim_x == 0x34 and value.aim_y == 0x12 and s.clonewars_input_override[3] == 1 and s.clonewars_input_override[1] == 0);
    value = input.read();
    check(@src(), value.held == 25 and value.pressed == 0 and s.clonewars_input_override[3] == 0);
    s.neutral_background_input = true;
    value = input.read();
    check(@src(), value.held == 0 and s.previous_local_held == 0);
    s.neutral_background_input = false;
    s.store(usize, @intFromPtr(&root) + 0x184c, deviceAt(1));
    s.store(u32, deviceAt(1) + 0x70, 64);
    s.store(u32, deviceAt(1) + 0x78, 128);
    devices[1][0x9d] = 255;
    devices[1][0x9e] = 0;
    value = input.read();
    check(@src(), value.held == 70 and value.pressed == 198);
    value = input.read();
    check(@src(), value.pressed == 128);
    s.store(i32, @intFromPtr(&service) + 0x28, 1);
    value = input.read();
    check(@src(), value.held == 0 and s.previous_local_held == 0);
    s.store(i32, @intFromPtr(&service) + 0x28, 0);
    setup();
    const applied = s.p.SyncInput{ .held = 16, .pressed = 32, .analog_x = 41, .analog_y = 201, .aim_x = 77, .aim_y = 99 };
    check(@src(), input.write(1, &applied) == 1 and s.load(usize, controllerAt(1)) == @intFromPtr(&s.remote_device[1]) and s.saved_device[1] == deviceAt(1) and s.changed_actor[1] == actorAt(1));
    check(@src(), s.load(u32, controllerAt(1) + 4) == 48 and s.load(u32, @intFromPtr(&s.remote_device[1]) + 0x78) == 32 and s.remote_device[1][0x9b] == 77 and s.remote_device[1][0x9e] == 201 and s.load(u32, actorAt(1) + 0x50) & 0x200 != 0);
    const serial = s.assignment_lease_serial;
    check(@src(), input.write(1, &applied) == 1 and s.assignment_lease_serial == serial and input.refresh(@intFromPtr(&s.remote_device[1])) == 1);
    input.releaseAssignment(1);
    check(@src(), s.load(usize, controllerAt(1)) == deviceAt(1) and s.load(u32, actorAt(1) + 0x50) & 0x200 == 0 and s.changed_actor[1] == 0);
    setup();
    s.store(i32, 0xeb1a78, -1);
    check(@src(), input.write(1, &applied) == 0 and s.clonewars_input_assignment_failure[2] == 3);
    setup();
    s.store(usize, controllerAt(1), @intFromPtr(&s.remote_device[0]));
    check(@src(), input.write(1, &applied) == 0 and s.clonewars_input_assignment_failure[2] == 4);
    setup();
    s.store(usize, controllerAt(1), @intFromPtr(&s.remote_device[1]));
    s.saved_device[1] = deviceAt(1);
    s.saved_device_session[1] = 16;
    check(@src(), input.write(1, &applied) == 0 and s.clonewars_input_assignment_failure[2] == 5);
    setup();
    s.store(usize, controllerAt(1), 0);
    join = false;
    check(@src(), input.write(1, &applied) == 1 and s.changed_actor[1] == 0 and s.load(usize, controllerAt(1)) == 0);
    join = true;
    check(@src(), input.write(1, &applied) == 1 and s.saved_device[1] == deviceAt(1));
    setup();
    s.store(usize, controllerAt(1), 0);
    join_cancel = true;
    check(@src(), input.write(1, &applied) == 0 and s.changed_actor[1] == 0);
    setup();
    check(@src(), input.write(0, &applied) == 1);
    remap = true;
    input.assignmentRemap(input.assignmentVersion());
    check(@src(), s.changed_actor[0] == actorAt(1) and s.changed_generation[0] == 20);
    setup();
    s.clonewars_wait_input_sampling = 1;
    s.store(u32, controllerAt(0) + 8, 8);
    input.sampleWait();
    check(@src(), s.sampled_for_flow and published == 1 and s.local_input.pressed == 8);
    s.running = true;
    s.latched_ready = true;
    s.pending_actor_pressed = .{ 1, 2 };
    s.remote_pulse.next_hold = 3;
    input.releaseRemote();
    check(@src(), s.lifecycle_release_serial == 10 and cancelled == 1 and s.deferred_assignment_restore == 1 and !s.running and !s.latched_ready and s.remote_pulse.next_hold == 0 and s.pending_actor_pressed[0] == 0 and s.pending_actor_pressed[1] == 0);
}
comptime {
    _ = @import("input.zig");
}
