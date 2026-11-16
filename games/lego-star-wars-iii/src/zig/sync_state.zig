const std = @import("std");
pub const p = @import("protocol.zig");
pub const abi = @import("abi.zig");
pub const win = @import("win32.zig");
pub const api = if (@hasDecl(@import("root"), "sync_test_api")) @import("root").sync_test_api else @import("sync_api.zig");
pub const Token = @import("cohort_types.zig").Token;
pub const owner = @import("owner_types.zig");
pub const Npc = @import("npc_input.zig");
pub const Machine = @import("machine_environment.zig").Environment;
pub const load = win.load;
pub const store = win.store;
pub const GlobalStep = extern struct { worlds: u32, ticks: u32, input_taken: c_int };
pub const MainBoundary = @import("sync_boundary.zig").Boundary;
pub const CohortBinding = extern struct {
    version: u32,
    ready: ?*const fn () callconv(.c) c_int,
    bind_metadata: ?*const fn (*const Token) callconv(.c) c_int,
    valid: ?*const fn (*const Token, u32) callconv(.c) c_int,
    abort_metadata: ?*const fn (*const Token) callconv(.c) void,
};
pub const Core = extern struct {
    owner: ?*owner.Scope,
    owner_nonce: u32,
    release: u32,
    host: u32,
    depth_accounted: u32,
    opened: u32,
    bound_mask: u32,
    token: Token,
    engine: usize,
    packet: usize,
    main_calls: u32,
    optional_calls: u32,
    expected_calls: u32,
    expected_plan: u32,
    published: u32,
    session: u32,
    control_stale: u32,
    preload: u32,
    preload_world_calls: u32,
    preload_epoch: u32,
    preload_world: usize,
    preload_flow: p.SyncPreloadReceipt,
};
pub const PrepGate = extern struct { actor: usize, generation: u32, blocked: c_int, cohort: Token };
pub var working = std.mem.zeroes(p.SyncFrame);
pub var sequence: u32 = 0;
pub var expected: u32 = 0;
pub var last_published_sequence: u32 = 0;
pub var interval: abi.SyncEpochCursor = .{ .level = -1, .epoch = 0, .sequence = 0, .active = 0 };
pub var session_active = false;
pub var interval_started = false;
pub var observed_lan_session: u32 = 0;
pub var running = false;
pub var fault: c_int = 0;
pub var lifecycle_release_serial: u32 = 0;
pub var outer_depth: u32 = 0;
pub var tick_thread: u32 = 0;
pub var window_thread: u32 = 0;
pub var deferred_assignment_restore: u32 = 0;
pub var reject_bits: u32 = 0;
pub var global_step = std.mem.zeroes(GlobalStep);
pub var npc_inputs = std.mem.zeroes(Npc.Journal);
pub var hooked = false;
pub var enabled = false;
pub var neutral_background_input = false;
pub var initialized_level: i32 = -1;
pub var latched_input = std.mem.zeroes([2]p.SyncInput);
pub var pending_actor_pressed: [2]u32 = @splat(0);
pub var latched_ready = false;
pub threadlocal var prep_gate_depth: u32 = 0;
pub threadlocal var prep_gates: [64]PrepGate = undefined;
pub var remote_device: [2][0x200]u8 align(16) = std.mem.zeroes([2][0x200]u8);
pub var changed_controller: [2]usize = @splat(0);
pub var saved_device: [2]usize = @splat(0);
pub var saved_device_session: [2]u32 = @splat(0);
pub var changed_actor: [2]usize = @splat(0);
pub var saved_human: [2]u32 = @splat(0);
pub var changed_generation: [2]u32 = @splat(0);
pub var local_input = std.mem.zeroes(p.SyncInput);
pub var previous_local_held: u32 = 0;
pub var local_buffer = std.mem.zeroes(abi.InputBuffer);
pub var remote_pulse = std.mem.zeroes(abi.RemoteInputPulse);
pub var sampled_for_flow = false;
pub var assignment_lease_serial: u64 = 0;
pub var transition_native_entry: u32 = 0;
pub var core = std.mem.zeroes(Core);
pub var preload = blk: {
    var value = std.mem.zeroes(abi.NativePreloadState);
    value.level = -1;
    value.input.level = -1;
    break :blk value;
};
pub var failure_order: u32 = 0;
pub var bindings = std.mem.zeroes([8]CohortBinding);
pub var adapter = std.mem.zeroes(@import("span_types.zig").Adapter);
pub var dependency_install_state: i32 = 0;
pub var base_install_state: i32 = 0;
pub var mapping_configured = false;
pub var mapping_session: u32 = 0;
pub var owned_mapping = false;
pub var main_boundary = std.mem.zeroes(MainBoundary);
pub var main_boundary_serial: u32 = 0;
pub var permission_install_owner: ?*owner.Scope = null;
pub var permission_install_nonce: u32 = 0;
pub var main_boundary_active = false;
pub var registered: u32 = 0;
pub var run_count: u32 = 0;
pub var publish_count: u32 = 0;
pub var module_install_mask: u32 = 0;
pub fn releaseToken() u32 {
    return @atomicLoad(u32, &lifecycle_release_serial, .seq_cst);
}
pub fn releaseChanged(token: u32) bool {
    return releaseToken() != token;
}
pub fn valid(address: usize, bytes: usize) bool {
    var info: win.MemoryInfo = undefined;
    return address != 0 and win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.state == 0x1000 and info.protection & 0x101 == 0 and address +% bytes <= info.base +% info.region_size;
}
pub fn player(slot: usize) usize {
    const value = load(usize, 0xfb4940 + slot * 4);
    return if (valid(value, 0x1440)) value else 0;
}
pub fn controller(slot: usize) usize {
    const actor = player(slot);
    const value = if (actor != 0) load(usize, actor + 0x6cc) else 0;
    return if (valid(value, 0x60)) value else 0;
}
pub fn live() bool {
    if (core.opened == 0 or core.session != api.lan_session_serial() or core.owner == null or win.GetCurrentThreadId() != tick_thread or releaseChanged(core.release) or @atomicLoad(u32, &reject_bits, .seq_cst) != 0 or api.coherent_frame_valid(&core.token, 0x3e) == 0) return false;
    for (bindings, 0..) |binding, i| if (core.bound_mask & (@as(u32, 1) << @intCast(i)) != 0 and binding.valid.?(&core.token, 0x3e) == 0) return false;
    return true;
}
pub fn dispatchAuthority() bool {
    return core.opened != 0 and live() and api.coherent_frame_valid(&core.token, 4) != 0;
}
pub fn captureDispatch(out: *Token) bool {
    if (!live() or api.coherent_frame_valid(&core.token, 4) == 0) return false;
    out.* = core.token;
    return true;
}
pub export var clonewars_npc_input_debug: [16]u32 = std.mem.zeroes([16]u32);
pub export var clonewars_npc_input_failure: [14]u32 = std.mem.zeroes([14]u32);
pub export var clonewars_sync_debug: [20]u32 = std.mem.zeroes([20]u32);
pub export var clonewars_input_override: [4]i32 = std.mem.zeroes([4]i32);
pub export var clonewars_input_override_aim: i32 = 0x8080;
pub export var clonewars_actor_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_actor_pose_corrections: u32 = 0;
pub export var clonewars_input_prep_installed: i32 = 0;
pub export var clonewars_input_prep_failure: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_epoch_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_wait_input_sampling: i32 = 0;
pub export var clonewars_transition_drain_debug: [4]u32 = std.mem.zeroes([4]u32);
pub export var clonewars_input_assignment_failure: [16]u32 = std.mem.zeroes([16]u32);
pub export var clonewars_actor_motion_origin_debug: [12]u32 = std.mem.zeroes([12]u32);
pub export var clonewars_preload_debug: [16]u32 = std.mem.zeroes([16]u32);
pub export var clonewars_preload_transition_drain_debug: [6]u32 = std.mem.zeroes([6]u32);
pub export var clonewars_native_numeric_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_preload_seed_debug: [6]u32 = std.mem.zeroes([6]u32);
pub export var clonewars_preload_flow_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_load_barrier_debug: [12]u32 = std.mem.zeroes([12]u32);
pub export var clonewars_sync_first_reject: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_sync_first_fault: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_coherent_debug: [20]u32 = std.mem.zeroes([20]u32);
pub export var clonewars_coherent_waits: [3]u32 = std.mem.zeroes([3]u32);
pub export var clonewars_preload_track_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_preload_failure: [16]u32 = @splat(0);
