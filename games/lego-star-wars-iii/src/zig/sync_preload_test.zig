const std = @import("std");
const s = @import("sync_state.zig");
const preload = @import("sync_preload.zig");
const authority = @import("sync_authority.zig");
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var root: [0x2000]u8 align(16) = undefined;
var world: [0x2300]u8 align(16) = undefined;
var engine: [0x1000]u8 align(16) = undefined;
var packet: [0x20]u8 align(16) = undefined;
var actors: [2][0x1440]u8 align(16) = undefined;
var controllers: [2][0x100]u8 align(16) = undefined;
var owner: s.owner.Scope = undefined;
var host = true;
var loader_idle = true;
var receipt_ready = false;
var input_ready = false;
var received_input: s.p.SyncPreloadInput = undefined;
var received_receipt: s.p.SyncPreloadReceipt = undefined;
var published_input: s.p.SyncPreloadInput = undefined;
var published_world: s.p.SyncWorldReady = undefined;
var published_seal: u32 = 0;
var remote_seal: u32 = 0;
var reads: u32 = 0;
var invalidations: u32 = 0;
var clock: u64 = 0;
var clock_jump: u64 = 0;
var polling: u32 = 0;
var published_ready: c_int = 1;
pub const sync_test_platform = struct {
    pub fn now() u64 {
        const value = clock;
        clock +%= clock_jump;
        return value;
    }
    pub fn sleep(ms: u32) void {
        clock += ms;
    }
};
pub const sync_test_api = struct {
    pub fn lan_publish_ready(value: c_int) void {
        published_ready = value;
    }
    pub fn lan_status() c_long {
        return 3;
    }
    pub fn lan_error() c_long {
        return 0;
    }
    pub fn lan_is_host() c_int {
        return @intFromBool(host);
    }
    pub fn lan_session_serial() u32 {
        return 17;
    }
    pub fn lan_remote_level() c_int {
        return 6;
    }
    pub fn lan_peer_ready() c_int {
        return 1;
    }
    pub fn lan_peer_ack() u32 {
        return 0;
    }
    pub fn lan_epoch() u32 {
        return 7;
    }
    pub fn lan_remote_epoch() u32 {
        return 7;
    }
    pub fn game_current_level() c_int {
        return 6;
    }
    pub fn game_actor_count() c_int {
        return 2;
    }
    pub fn game_load_status() c_int {
        return 0;
    }
    pub fn game_native_profile_ready() c_int {
        return 1;
    }
    pub fn game_network_profile_ready() c_int {
        return 1;
    }
    pub fn game_network_target_level() c_int {
        return 6;
    }
    pub fn game_network_level_valid(level: c_int) c_int {
        return @intFromBool(level == 6);
    }
    pub fn game_network_level_authorized(level: c_int) c_int {
        return @intFromBool(level == 6);
    }
    pub fn game_network_world_targeted(level: c_int) c_int {
        return @intFromBool(level == 6);
    }
    pub fn game_network_world_valid(level: c_int, pointer: usize) c_int {
        return @intFromBool(level == 6 and pointer == @intFromPtr(&world));
    }
    pub fn game_native_scene_input_capability(_: c_int, _: usize) c_int {
        return 1;
    }
    pub fn game_native_loader_idle() c_int {
        return @intFromBool(loader_idle);
    }
    pub fn native_owner_current() ?*s.owner.Scope {
        return &owner;
    }
    pub fn native_owner_scope_nonce(_: ?*const s.owner.Scope) u32 {
        return 3;
    }
    pub fn native_owner_scope_valid(pointer: ?*const s.owner.Scope, nonce: u32) c_int {
        return @intFromBool(pointer == &owner and nonce == 3);
    }
    pub fn coherent_frame_release() u32 {
        return 9;
    }
    pub fn coherent_frame_cancel_atomic(_: u32) void {}
    pub fn user_mapping_install_ready() c_int {
        return 1;
    }
    pub fn user_mapping_session_pending() u32 {
        return 0;
    }
    pub fn lan_invalidate_world_ready() void {
        invalidations += 1;
    }
    pub fn lan_publish_world_ready(value: *const s.p.SyncWorldReady) c_int {
        published_world = value.*;
        return 1;
    }
    pub fn lan_remote_world_ready(_: u32, _: c_int, out: *s.p.SyncWorldReady) c_int {
        out.* = published_world;
        return 1;
    }
    pub fn lan_publish_preload(value: *const s.p.SyncPreloadInput) c_int {
        published_input = value.*;
        return 1;
    }
    pub fn lan_receive_preload(_: u32, _: c_int, out: *s.p.SyncPreloadInput) c_int {
        if (!input_ready) return 0;
        out.* = received_input;
        return 1;
    }
    pub fn lan_remote_preload_receipt(_: u32, _: c_int, out: *s.p.SyncPreloadReceipt) c_int {
        reads += 1;
        if (!receipt_ready) return 0;
        out.* = received_receipt;
        return 1;
    }
    pub fn lan_publish_preload_seal(_: u32, _: c_int, serial: u32) c_int {
        published_seal = serial;
        return 1;
    }
    pub fn lan_remote_preload_seal(_: u32, _: c_int) u32 {
        return remote_seal;
    }
    pub fn loading_poll() void {
        polling += 1;
    }
    pub fn game_poll() void {
        polling += 1;
    }
    pub fn game_transition_waiting() c_int {
        return 0;
    }
    pub const preload_phase_active = real.preload_phase_active;
    pub const preload_stage_eligible = real.preload_stage_eligible;
    pub const preload_track_read = real.preload_track_read;
    pub const preload_flow_request_read = real.preload_flow_request_read;
    pub const preload_world_ready_matches = real.preload_world_ready_matches;
    pub const preload_world_roster_matches = real.preload_world_roster_matches;
    pub const preload_state_bind = s.abi.preload_state_bind;
    pub const preload_state_accept = s.abi.preload_state_accept;
    pub const preload_state_peer_receipt = s.abi.preload_state_peer_receipt;
    pub const preload_initial_seal_ready = s.abi.preload_initial_seal_ready;
    pub const preload_state_seal = s.abi.preload_state_seal;
    pub const preload_transition_pending = real.preload_transition_pending;
};
const real = struct {
    extern fn preload_phase_active(u32, c_int) c_int;
    extern fn preload_stage_eligible(u32, c_int, c_int, c_int, c_int) c_int;
    extern fn preload_track_read(?*const s.p.SyncPreloadReceipt, u32, u32, ?*const [2]u32, ?*u32) c_int;
    extern fn preload_flow_request_read(?*const s.p.SyncPreloadReceipt, u32, u32, ?*u32) c_int;
    extern fn preload_world_ready_matches(?*const s.p.SyncWorldReady, ?*const s.p.SyncWorldReady) c_int;
    extern fn preload_world_roster_matches(?*const s.p.SyncWorldReady, ?*const s.p.SyncWorldReady) c_int;
    extern fn preload_transition_pending(?*const s.abi.NativePreloadState, u32, u32, c_int, ?*const s.p.SyncPreloadReceipt) c_int;
};
export fn coherent_frame_valid(_: *const s.Token, _: u32) c_int {
    return 1;
}
export fn coherent_frame_cancel_atomic(_: u32) void {}
fn ready() callconv(.c) c_int {
    return 1;
}
fn setup() void {
    @memset(&root, 0);
    @memset(&world, 0);
    @memset(&engine, 0);
    @memset(&packet, 0);
    @memset(std.mem.asBytes(&actors), 0);
    @memset(std.mem.asBytes(&controllers), 0);
    s.store(usize, 0xfb2e60, @intFromPtr(&root));
    s.store(usize, 0xfb4a20, @intFromPtr(&world));
    s.store(i32, 0xe6e61c, -1);
    s.store(u32, @intFromPtr(&root) + 0x1b78, 14);
    s.store(u32, 0xfb2e3c, 2);
    s.store(usize, 0xfb2f60, @intFromPtr(&actors));
    for (0..2) |i| {
        const actor = @intFromPtr(&actors[i]);
        s.store(u32, actor + 0x50, 3);
        s.store(i16, actor + 0xdc0, @intCast(10 + i));
        s.store(usize, actor + 0x6cc, @intFromPtr(&controllers[i]));
        s.store(usize, 0xfb4940 + i * 4, actor);
    }
    s.store(u32, @intFromPtr(&packet), 0xc37cfc);
    s.store(f32, @intFromPtr(&packet) + 8, 0.02);
    s.store(u32, @intFromPtr(&engine) + 0xe30, 2);
    s.store(u32, 0xfb4b6c, 43);
    s.store(u32, 0xe637b4, 47);
    s.store(u32, 0xea178c, 53);
    s.store(u32, 0xe5f498, 59);
    s.store(f32, 0xfb4b74, 0.03);
    s.store(f32, 0xfb4ad4, 0.1);
    s.interval = .{ .epoch = 7, .sequence = 0, .level = 6, .active = 1 };
    s.initialized_level = 6;
    s.observed_lan_session = 17;
    s.core = std.mem.zeroes(s.Core);
    s.core.owner = &owner;
    s.core.owner_nonce = 3;
    s.core.engine = @intFromPtr(&engine);
    s.core.packet = @intFromPtr(&packet);
    s.preload = std.mem.zeroes(s.abi.NativePreloadState);
    s.preload.level = -1;
    s.preload.input.level = -1;
    s.window_thread = s.win.GetCurrentThreadId();
    s.tick_thread = s.window_thread;
    s.dependency_install_state = 1;
    s.base_install_state = 1;
    s.mapping_configured = true;
    s.hooked = true;
    s.fault = 0;
    s.reject_bits = 0;
    s.registered = 255;
    s.bindings = std.mem.zeroes(@TypeOf(s.bindings));
    for (&s.bindings) |*binding| binding.ready = ready;
    s.deferred_assignment_restore = 0;
    s.sequence = 0;
    s.expected = 0;
    s.clonewars_preload_debug = @splat(0);
    s.clonewars_sync_first_reject = @splat(0);
    s.clonewars_preload_failure = @splat(0);
    s.main_boundary_active = false;
    s.main_boundary_serial = 0;
    s.permission_install_owner = null;
    host = true;
    loader_idle = true;
    receipt_ready = false;
    input_ready = false;
    published_seal = 0;
    remote_seal = 0;
    reads = 0;
    invalidations = 0;
    clock = 0;
    clock_jump = 0;
    polling = 0;
    published_ready = 1;
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) <= 0xe60000 and @intFromPtr(&owned_image) + owned_image.len >= 0xfb5000);
    setup();
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 1 and s.core.preload == 1 and published_input.serial == 1 and published_input.clock == 43 and published_input.rng_effects == 59 and published_world.collider_count == 2);
    check(@src(), preload.game_sync_preload_track_input(&.{ 71, 73 }, 0x3f800000) == 0x3f800000 and preload.game_sync_preload_flow_input(@intFromPtr(&root) + 0x1b44, 3) == 3);
    const host_input = published_input;
    var receipt = s.core.preload_flow;
    receipt.serial = 1;
    receipt.world_calls = 1;
    receipt.end_phase = 14;
    check(@src(), s.abi.preload_state_finish(&s.preload, &receipt) == 1);
    s.core.preload = 0;
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 0 and s.clonewars_preload_debug[12] == 1);
    received_receipt = receipt;
    receipt_ready = true;
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 0 and published_seal == 1 and s.preload.sealed_serial == 1);
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 2 and authority.game_sync_scene_initialized(6) == 1 and authority.game_sync_scene_ready(6) == 1);
    var session: @import("tag_state.zig").Session = undefined;
    check(@src(), authority.tagSession(&session) == 1 and session.classification == 4);
    const sealed_state = s.preload;
    for ([_]bool{ true, false }) |role| {
        host = role;
        s.sequence = 84;
        s.expected = 84;
        s.store(u32, @intFromPtr(&root) + 0x1b78, 10);
        s.store(u32, 0xfb4b6c, 0);
        check(@src(), !preload.tick(@intFromPtr(&root) + 0x1b44) and published_ready == 1 and s.reject_bits == 0 and s.clonewars_preload_failure[0] == 0);
        check(@src(), std.mem.eql(u8, std.mem.asBytes(&s.preload), std.mem.asBytes(&sealed_state)));
    }
    host = true;
    s.sequence = 0;
    s.expected = 0;
    s.store(u32, @intFromPtr(&root) + 0x1b78, 14);
    s.store(u32, 0xfb4b6c, 43);
    check(@src(), !preload.tick(@intFromPtr(&root) + 0x1b44));
    check(@src(), s.clonewars_preload_failure[0] == 3 and s.clonewars_preload_failure[1] == 7 and s.clonewars_preload_failure[3] == 43 and s.clonewars_preload_failure[8] == 1);
    check(@src(), std.mem.eql(u8, std.mem.asBytes(&s.preload), std.mem.asBytes(&sealed_state)) and s.clonewars_sync_first_reject[0] == 31);
    const failure = s.clonewars_preload_failure;
    check(@src(), !preload.tick(@intFromPtr(&root) + 0x1b44) and std.mem.eql(u32, &failure, &s.clonewars_preload_failure));
    setup();
    host = false;
    input_ready = true;
    received_input = host_input;
    received_receipt = receipt;
    receipt_ready = true;
    s.store(u32, 0xfb4b6c, 99);
    s.store(u32, 0xea178c, 101);
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 1 and s.load(u32, 0xfb4b6c) == 43 and s.load(u32, 0xea178c) == 53);
    check(@src(), preload.game_sync_preload_track_input(&.{ 71, 73 }, 0x40000000) == 0x3f800000 and preload.game_sync_preload_flow_input(@intFromPtr(&root) + 0x1b44, 5) == 3 and s.core.preload_flow.track_count == 1 and s.core.preload_flow.flow_count == 1);
    s.core.preload_flow.track_count = 0;
    check(@src(), preload.game_sync_preload_track_input(&.{ 71, 74 }, 0x40000000) == 0x40000000 and s.reject_bits != 0 and s.core.preload_flow.track_count == 0);
    setup();
    host = false;
    input_ready = true;
    received_input = host_input;
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 1);
    clock_jump = 300001;
    check(@src(), preload.game_sync_preload_flow_input(@intFromPtr(&root) + 0x1b44, 5) == 5 and s.reject_bits != 0 and s.core.preload_flow.flow_count == 0 and reads == 1);
    setup();
    loader_idle = false;
    check(@src(), preload.prepare(@intFromPtr(&engine), @intFromPtr(&packet), 1) == 0 and invalidations > 0 and s.core.preload == 0);
    setup();
    check(@src(), preload.tick(@intFromPtr(&root) + 0x1b44) and s.core.preload == 1 and polling == 2 and !s.main_boundary_active);
    setup();
    loader_idle = false;
    clock_jump = 300001;
    check(@src(), !preload.tick(@intFromPtr(&root) + 0x1b44) and s.reject_bits != 0 and polling == 2 and !s.main_boundary_active);
}
comptime {
    _ = @import("preload.zig");
}
