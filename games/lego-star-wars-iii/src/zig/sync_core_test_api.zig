const std = @import("std");
pub const s = @import("sync_state.zig");
const fence = @import("frame_fence.zig");
const npc = @import("npc_input.zig");
const check = @import("native_test_support.zig").check;
pub const Mode = enum { normal, bind_failure, tag_cancel, geometry_failure, collect_cancel, projectile_reset, drain_nested, drain_stalled, throw_prep, send_failure };
pub var mode: Mode = .normal;
pub var host = true;
pub var peer_ready = true;
pub var owner: s.owner.Scope = undefined;
pub var owner_alive = true;
pub var root: [0x2000]u8 align(16) = undefined;
pub var world: [0x2300]u8 align(16) = undefined;
pub var engine: [0x1000]u8 align(16) = undefined;
pub var framework: [0x100]u8 align(16) = undefined;
pub var packet: [0x20]u8 align(16) = undefined;
pub var actors: [3][0x1440]u8 align(16) = undefined;
var controllers: [3][0x100]u8 align(16) = undefined;
var devices: [3][0x200]u8 align(16) = undefined;
pub var generations: [3]u32 = .{ 19, 20, 21 };
pub var saved_frame: ?*s.p.SyncFrame = null;
pub var received = false;
pub var sent: u32 = 0;
pub var acknowledged: u32 = 0;
pub var aborted: u32 = 0;
pub var observed: [3][2]u32 = undefined;
pub var projectile_revision: u64 = 0;
pub var tag_revision: u64 = 0;
var projectile_pending: c_int = 0;
var tag_pending: c_int = 0;
pub var projectile_completions: u32 = 0;
pub var tag_completions: u32 = 0;
var projectile_serial: u32 = 0;
pub var events: [64]u32 = undefined;
pub var event_count: usize = 0;
pub fn record(value: u32) void {
    check(@src(), event_count < events.len);
    events[event_count] = value;
    event_count += 1;
}
pub fn actorAt(i: usize) usize {
    return @intFromPtr(&actors[i]);
}
fn index(actor: usize) ?usize {
    for (0..3) |i| if (actor == actorAt(i)) return i;
    return null;
}
pub fn lan_session_serial() u32 {
    return 17;
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
pub fn lan_epoch() u32 {
    return 7;
}
pub fn lan_remote_epoch() u32 {
    return 7;
}
pub fn lan_peer_ack() u32 {
    return 1;
}
pub fn lan_remote_level() c_int {
    return 6;
}
pub fn lan_peer_ready() c_int {
    return @intFromBool(peer_ready);
}
pub fn lan_publish_ready(_: c_int) void {}
pub fn game_current_level() c_int {
    return 6;
}
pub fn game_actor_count() c_int {
    return 3;
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
pub fn game_network_level_authorized(_: c_int) c_int {
    return 1;
}
pub fn game_network_level_valid(_: c_int) c_int {
    return 1;
}
pub fn game_network_world_targeted(_: c_int) c_int {
    return 1;
}
pub fn game_network_world_valid(_: c_int, pointer: usize) c_int {
    return @intFromBool(pointer == @intFromPtr(&world));
}
pub fn game_native_scene_input_capability(_: c_int, _: usize) c_int {
    return 1;
}
pub fn game_native_loader_idle() c_int {
    return 1;
}
pub fn game_transition_waiting() c_int {
    return 0;
}
pub fn game_native_tick() void {}
pub fn loading_poll() void {}
pub fn game_poll() void {}
pub fn native_owner_current() ?*s.owner.Scope {
    return &owner;
}
pub fn native_owner_scope_nonce(_: ?*const s.owner.Scope) u32 {
    return 3;
}
pub export fn native_owner_scope_valid(scope: ?*const s.owner.Scope, nonce: c_uint) c_int {
    return @intFromBool(owner_alive and scope == &owner and nonce == 3);
}
pub const coherent_frame_valid = fence.coherent_frame_valid;
pub const coherent_frame_open = fence.coherent_frame_open;
pub const coherent_frame_close = fence.coherent_frame_close;
pub const coherent_frame_set_phase = fence.coherent_frame_set_phase;
pub const coherent_frame_release = fence.coherent_frame_release;
pub const coherent_frame_cancel_atomic = fence.coherent_frame_cancel_atomic;
pub const coherent_frame_register_main = fence.coherent_frame_register_main;
pub fn user_mapping_install_ready() c_int {
    return 1;
}
pub fn user_mapping_session_pending() c_int {
    return 0;
}
pub fn user_mapping_session_retire(_: u32, _: u32) c_int {
    return 1;
}
pub fn user_mapping_session_begin(_: u32) c_int {
    return 1;
}
pub fn user_mapping_session_drain(_: usize, _: u32, _: u32) c_int {
    return 0;
}
pub fn user_mapping_session_owned_request(_: u32, _: ?*const @import("mapping_types.zig").Request, _: ?*@import("mapping_types.zig").Key) c_int {
    return 1;
}
pub fn user_mapping_session_device_get(_: u32, _: *@import("mapping_types.zig").Observation) c_int {
    return 1;
}
pub fn lan_invalidate_world_ready() void {}
pub fn lan_publish_world_ready(_: *const s.p.SyncWorldReady) c_int {
    return 1;
}
pub fn lan_remote_world_ready(_: u32, _: c_int, _: *s.p.SyncWorldReady) c_int {
    return 0;
}
pub fn lan_publish_preload(_: *const s.p.SyncPreloadInput) c_int {
    return 1;
}
pub fn lan_receive_preload(_: u32, _: c_int, _: *s.p.SyncPreloadInput) c_int {
    return 0;
}
pub fn lan_remote_preload_receipt(_: u32, _: c_int, _: *s.p.SyncPreloadReceipt) c_int {
    return 0;
}
pub fn lan_publish_preload_receipt(_: u32, _: c_int, _: *const s.p.SyncPreloadReceipt) c_int {
    return 1;
}
pub fn lan_publish_preload_seal(_: u32, _: c_int, _: u32) c_int {
    return 1;
}
pub fn lan_remote_preload_seal(_: u32, _: c_int) u32 {
    return 0;
}
const declarations = struct {
    extern fn preload_phase_active(u32, c_int) c_int;
    extern fn preload_stage_eligible(u32, c_int, c_int, c_int, c_int) c_int;
    extern fn preload_track_read(?*const s.p.SyncPreloadReceipt, u32, u32, ?*const [2]u32, ?*u32) c_int;
    extern fn preload_flow_request_read(?*const s.p.SyncPreloadReceipt, u32, u32, ?*u32) c_int;
    extern fn preload_world_ready_matches(?*const s.p.SyncWorldReady, ?*const s.p.SyncWorldReady) c_int;
    extern fn preload_world_roster_matches(?*const s.p.SyncWorldReady, ?*const s.p.SyncWorldReady) c_int;
    extern fn preload_transition_pending(?*const s.abi.NativePreloadState, u32, u32, c_int, ?*const s.p.SyncPreloadReceipt) c_int;
};
pub const preload_phase_active = declarations.preload_phase_active;
pub const preload_stage_eligible = declarations.preload_stage_eligible;
pub const preload_track_read = declarations.preload_track_read;
pub const preload_flow_request_read = declarations.preload_flow_request_read;
pub const preload_world_ready_matches = declarations.preload_world_ready_matches;
pub const preload_world_roster_matches = declarations.preload_world_roster_matches;
pub const preload_transition_pending = declarations.preload_transition_pending;
pub const preload_state_bind = s.abi.preload_state_bind;
pub const preload_state_accept = s.abi.preload_state_accept;
pub const preload_state_finish = s.abi.preload_state_finish;
pub const preload_state_seal = s.abi.preload_state_seal;
pub const preload_initial_seal_ready = s.abi.preload_initial_seal_ready;
pub const preload_state_peer_receipt = s.abi.preload_state_peer_receipt;
pub const sync_epoch_apply = s.abi.sync_epoch_apply;
pub const sync_epoch_unacknowledged = s.abi.sync_epoch_unacknowledged;
pub const input_buffer_reset = s.abi.input_buffer_reset;
pub const input_buffer_sample = s.abi.input_buffer_sample;
pub const input_buffer_take = s.abi.input_buffer_take;
pub const remote_input_execute = s.abi.remote_input_execute;
pub const remote_input_pulse_reset = s.abi.remote_input_pulse_reset;
pub fn lan_publish_input(_: *const s.p.SyncInput) void {}
pub fn lan_consume_input() s.p.SyncInput {
    return .{ .held = 4, .pressed = 8, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
}
pub fn network_window_input_blocked() c_int {
    return 0;
}
pub fn tags_resolve_controller_owner(_: usize, _: u32, _: usize, _: ?*usize, _: ?*u32) c_int {
    return 0;
}
pub fn tags_observe_controller_handoffs(_: ?*const fn () callconv(.c) u64, _: ?*const fn (u64) callconv(.c) void) void {}
pub fn game_native_join_party_player(_: c_int, _: usize, _: usize) c_int {
    return 0;
}
pub fn entities_update() void {
    if (mode == .collect_cancel and s.running == false) fence.coherent_frame_cancel_atomic(0x200);
}
pub fn entities_slot(actor: usize) c_int {
    return if (index(actor)) |i| @intCast(i) else -1;
}
pub fn entities_local_generation(actor: usize) u32 {
    return if (index(actor)) |i| generations[i] else 0;
}
pub const entities_observed_generation = entities_local_generation;
pub fn entities_allocation_live(actor: usize, generation: u32) c_int {
    return @intFromBool(generation != 0 and generation == entities_local_generation(actor));
}
pub fn entities_actor(slot: u32, generation: u32) usize {
    return if (slot < 3 and generations[slot] == generation) actorAt(slot) else 0;
}
pub fn entities_is_retired(_: u32, _: u32) c_int {
    return 0;
}
pub fn entities_bind(_: *const s.p.SyncFrame) c_int {
    return 1;
}
pub fn entities_bind_tick(_: *const s.p.SyncFrame) c_int {
    return 1;
}
pub fn entities_collect_dormant_party(_: *s.p.SyncFrame) c_int {
    return 1;
}
pub fn entities_describe(out: *s.p.SyncActor, actor: usize) void {
    const i = index(actor) orelse unreachable;
    out.* = std.mem.zeroes(s.p.SyncActor);
    out.slot = @intCast(i);
    out.generation = generations[i];
    out.player = if (i < 2) @intCast(i) else -1;
    out.party_slot = if (i < 2) @intCast(i) else -1;
    out.spawn_tag = @intCast(31 + i);
    out.spawn_source = .{ .producer = 42, .serial = @intCast(100 + i) };
    out.character = @intCast(10 + i);
    out.spawn_position = .{ @floatFromInt(i + 1), 2, 3 };
}
pub fn entities_resolve_reference(value: *const s.p.SyncActor) usize {
    return if (value.slot < 3 and value.generation == generations[value.slot] and value.character == 10 + @as(i32, @intCast(value.slot)) and value.spawn_tag == 31 + value.slot and value.spawn_source.producer == 42 and value.spawn_source.serial == 100 + value.slot) actorAt(value.slot) else 0;
}
pub fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    const i = index(actor) orelse return 0;
    slot.* = @intCast(i);
    generation.* = generations[i];
    return 1;
}
pub fn native_actor_rigid_body(_: usize, _: *@import("rigid_types.zig").Binding) c_int {
    return 0;
}
pub fn native_actor_rigid_body_same(_: usize, _: *const @import("rigid_types.zig").Binding) c_int {
    return 0;
}
pub fn native_rigid_body_transform(_: usize, _: [*]const f32) void {}
pub fn sync_frame_size(_: *const s.p.SyncFrame) usize {
    return @sizeOf(s.p.SyncFrame);
}
pub fn sync_frame_valid(_: *const s.p.SyncFrame, _: usize) c_int {
    return 1;
}
pub fn remote_input_trace_reset() void {}
pub fn remote_input_trace_begin(_: *const s.p.SyncFrame, _: c_int, _: ?*const s.p.SyncInput, _: usize) void {}
pub fn remote_input_trace_before(_: usize, _: c_int) c_int {
    return 0;
}
pub fn remote_input_trace_after(_: usize, _: c_int) void {}
pub fn remote_input_trace_finish(_: u32, _: usize) void {}
pub const npc_input_bind_cohort = npc.npc_input_bind_cohort;
pub const npc_input_cohort_valid = npc.npc_input_cohort_valid;
pub const npc_input_begin = npc.npc_input_begin;
pub const npc_input_record = npc.npc_input_record;
pub const npc_input_peek = npc.npc_input_peek;
pub const npc_input_apply = npc.npc_input_apply;
pub const npc_input_restore = npc.npc_input_restore;
pub const npc_input_finish = npc.npc_input_finish;
pub const npc_input_scope_capture = npc.npc_input_scope_capture;
pub const npc_input_scope_valid = npc.npc_input_scope_valid;
pub fn decision_observer_invoke_actor(_: u32, actor: usize, native: *const fn (usize) callconv(.c) void, _: u32) void {
    native(actor);
}
pub fn tags_actor_update(actor: usize, native: *const fn (usize) callconv(.c) void) void {
    native(actor);
}
pub fn object_progress_world_complete(_: usize, _: *const s.Token) c_int {
    return 1;
}
pub fn spawn_observer_flow(_: c_int) void {}
pub fn combat_observer_flow(_: c_int) void {}
pub fn spawn_timers_prepare(_: *const s.Token, _: *s.p.SyncFrame, _: c_int) c_int {
    record(1);
    return 1;
}
pub fn world_vars_collect(_: *s.p.SyncFrame) c_int {
    record(2);
    return 1;
}
pub fn world_vars_apply(_: *const s.p.SyncFrame) c_int {
    record(2);
    return 1;
}
pub fn tags_begin(_: *s.p.SyncFrame, _: c_int) c_int {
    record(3);
    if (mode == .tag_cancel) fence.coherent_frame_cancel_atomic(0x100);
    return 1;
}
pub fn tags_cancel() void {
    fence.coherent_frame_cancel_atomic(0x100);
}
pub fn projectiles_begin(_: *s.p.SyncFrame, _: c_int) c_int {
    record(4);
    return 1;
}
fn Begin(comptime event: u32) type {
    return struct {
        fn call(_: *s.p.SyncFrame, _: c_int) c_int {
            record(event);
            return 1;
        }
    };
}
pub const geometry_begin = Begin(5).call;
pub const cadence_begin = Begin(6).call;
pub const model_input_begin = Begin(7).call;
pub const reaction_begin = Begin(8).call;
pub fn native_tick_begin(_: *s.p.SyncFrame, _: c_int, _: *const s.Token) c_int {
    record(9);
    return 1;
}
pub fn native_tick_elapsed_input() c_int {
    record(10);
    return 1;
}
pub fn native_tick_finish() c_int {
    record(11);
    return 1;
}
pub fn native_tick_cancel(_: *const s.Token) void {
    record(19);
}
pub fn reaction_drain_contact_hits() c_int {
    return 1;
}
pub fn rts_spawn_timers_finish(_: *const s.p.SyncFrame) c_int {
    record(12);
    return 1;
}
fn Finish(comptime event: u32) type {
    return struct {
        fn call() c_int {
            record(event);
            return @intFromBool(!(event == 14 and mode == .geometry_failure));
        }
    };
}
pub const reaction_finish = Finish(13).call;
pub const geometry_finish = Finish(14).call;
pub const model_input_finish = Finish(15).call;
pub const cadence_finish = Finish(16).call;
pub fn model_input_cancelled() c_int {
    return 0;
}
pub fn tags_finish() c_int {
    record(17);
    return 1;
}
pub fn projectiles_finish() c_int {
    record(18);
    if (mode == .projectile_reset) projectile_serial += 1;
    return 1;
}
pub fn projectiles_lifecycle_serial() u32 {
    return projectile_serial;
}
pub fn projectiles_dispatch_pending() c_int {
    return projectile_pending;
}
pub fn tags_dispatch_pending() c_int {
    return tag_pending;
}
pub fn projectiles_dispatch_revision(_: *const s.Token, out: *u64) c_int {
    out.* = projectile_revision;
    return 1;
}
pub fn tags_dispatch_revision(_: *const s.Token, out: *u64) c_int {
    out.* = tag_revision;
    return 1;
}
pub fn projectiles_dispatch_complete() c_int {
    projectile_completions += 1;
    if (mode != .drain_stalled) {
        projectile_pending = 0;
        projectile_revision += 1;
    }
    return 1;
}
pub fn tags_dispatch_complete() c_int {
    tag_completions += 1;
    tag_pending = 0;
    tag_revision += 1;
    if (mode == .drain_nested) projectile_pending = 1;
    return 1;
}
pub fn lan_send_frame(frame: *const s.p.SyncFrame) c_int {
    if (mode == .send_failure) return 0;
    saved_frame.?.* = frame.*;
    sent += 1;
    return 1;
}
pub fn lan_receive_frame(frame: *s.p.SyncFrame) c_int {
    if (received) return 0;
    frame.* = saved_frame.?.*;
    received = true;
    return 1;
}
pub fn lan_publish_ack(sequence: u32) void {
    acknowledged = sequence;
}
pub fn combat_observer_frame_queued(_: u32, _: u32) void {}
pub fn camera_select(_: c_int) void {}
pub fn span_engine_control_get(_: *@import("span_types.zig").Adapter, out: *@import("span_types.zig").Lease) c_int {
    out.* = std.mem.zeroes(@import("span_types.zig").Lease);
    out.release = fence.coherent_frame_release();
    return 1;
}
pub fn span_engine_control_valid(_: *@import("span_types.zig").Adapter, lease: *const @import("span_types.zig").Lease) c_int {
    return @intFromBool(lease.release == fence.coherent_frame_release());
}
fn Cohort(comptime id: u5) type {
    return struct {
        var token = std.mem.zeroes(s.Token);
        fn ready() callconv(.c) c_int {
            return 1;
        }
        fn bind(value: *const s.Token) callconv(.c) c_int {
            token = value.*;
            if (id == 5 and npc.npc_input_bind_cohort(&s.npc_inputs, value) == 0) return 0;
            return @intFromBool(!(id == 3 and mode == .bind_failure));
        }
        fn valid(value: *const s.Token, phases: u32) callconv(.c) c_int {
            return @intFromBool(@import("validation.zig").equal(value, &token) and (if (id == 5) npc.npc_input_cohort_valid(&s.npc_inputs, value, phases) != 0 else true));
        }
        fn abort(value: *const s.Token) callconv(.c) void {
            check(@src(), @import("validation.zig").equal(value, &token));
            aborted |= @as(u32, 1) << id;
            if (id == 5) _ = npc.npc_input_abort_cohort(&s.npc_inputs, value);
        }
    };
}
fn nativeAi(actor: usize) callconv(.c) void {
    if (index(actor).? == 2) {
        const controller = s.load(usize, actor + 0x6cc);
        s.store(u32, controller + 4, if (host) 16 else 64);
        s.store(u32, controller + 8, if (host) 32 else 128);
    }
}
fn nativePrep(actor: usize) callconv(.c) void {
    const i = index(actor).?;
    const controller = s.load(usize, actor + 0x6cc);
    observed[i] = .{ s.load(u32, controller + 4), s.load(u32, controller + 8) };
    if (mode == .throw_prep and i == 2) {
        s.win.SetLastError(712);
        s.win.RaiseException(0xe1234567, 0, 0, null);
    }
}
fn nativeWorld(_: usize, _: usize) callconv(.winapi) void {
    for (0..3) |i| {
        @import("sync_prep.zig").sync_actor_ai_normal(actorAt(i), -1);
        @import("sync_prep.zig").normal(actorAt(i));
    }
    if (mode == .drain_nested or mode == .drain_stalled) {
        projectile_pending = 1;
        if (mode == .drain_nested) tag_pending = 1;
    }
    s.store(u32, 0xe637b4, s.load(u32, 0xe637b4) + @as(u32, if (host) 3 else 7));
    s.win.SetLastError(713);
}
fn nativeTick(_: usize) callconv(.{ .x86_thiscall = .{} }) void {
    s.win.SetLastError(714);
}
fn seed(at: usize, destination: usize) void {
    var old: u32 = 0;
    check(@src(), s.win.VirtualProtect(at, 5, 0x40, &old) != 0);
    s.store(u8, at, 0xe9);
    s.store(u32, at + 1, @truncate(destination -% at -% 5));
    check(@src(), s.win.VirtualProtect(at, 5, 0x20, &old) != 0);
    _ = s.win.FlushInstructionCache(s.win.GetCurrentProcess(), at, 5);
}
pub fn initialize() void {
    check(@src(), fence.coherent_frame_register_main() == 1);
    saved_frame = @ptrFromInt(s.win.VirtualAlloc(0, @sizeOf(s.p.SyncFrame), 0x3000, 4));
    check(@src(), saved_frame != null);
    seed(0x8b0f90, @intFromPtr(&nativeAi));
    seed(0x9ab020, @intFromPtr(&nativePrep));
    seed(0x887ac0, @intFromPtr(&nativeWorld));
    seed(0x889640, @intFromPtr(&nativeTick));
}
pub fn setup(scenario: Mode, is_host: bool) void {
    _ = fence.coherent_frame_close(&s.core.token);
    mode = scenario;
    host = is_host;
    peer_ready = true;
    owner_alive = true;
    received = false;
    sent = 0;
    acknowledged = 0;
    aborted = 0;
    event_count = 0;
    observed = @splat(@splat(0));
    projectile_revision = 0;
    tag_revision = 0;
    projectile_pending = 0;
    tag_pending = 0;
    projectile_completions = 0;
    tag_completions = 0;
    projectile_serial = 0;
    @memset(&root, 0);
    @memset(&world, 0);
    @memset(&engine, 0);
    @memset(&framework, 0);
    @memset(&packet, 0);
    @memset(std.mem.asBytes(&actors), 0);
    @memset(std.mem.asBytes(&controllers), 0);
    @memset(std.mem.asBytes(&devices), 0);
    s.store(usize, 0xfb2e60, @intFromPtr(&root));
    s.store(usize, 0xfb4a20, @intFromPtr(&world));
    s.store(usize, 0xfb0afc, @intFromPtr(&engine));
    s.store(usize, 0xfb0b70, @intFromPtr(&framework));
    s.store(usize, 0xfb0b60, 0);
    s.store(u32, @intFromPtr(&root) + 0x1b78, 14);
    s.store(i32, 0xe6e61c, -1);
    s.store(u32, 0xfbdd2c, 0);
    s.store(u8, 0xe66e7a, 0);
    s.store(u8, 0xf91eb4, 0);
    s.store(u32, 0xfb2e3c, 3);
    s.store(usize, 0xfb2f60, @intFromPtr(&actors));
    s.store(i32, 0xeb1a78, 1);
    for (0..3) |i| {
        const actor = actorAt(i);
        s.store(u32, actor + 0x50, 3);
        s.store(i16, actor + 0xdc0, @intCast(10 + i));
        s.store(i8, actor + 0xdde, 3);
        s.store(u8, actor + 0xddd, 4);
        s.store(usize, actor + 0x6cc, @intFromPtr(&controllers[i]));
        s.store(usize, @intFromPtr(&controllers[i]), @intFromPtr(&devices[i]));
        s.store([3]f32, actor + 0x24, .{ @floatFromInt(i + 1), 2, 3 });
        s.store([3]f32, actor + 0xe2c, .{ @floatFromInt(i + 1), 2, 3 });
        devices[i][0x9b] = 128;
        devices[i][0x9c] = 128;
        devices[i][0x9d] = 128;
        devices[i][0x9e] = 128;
        if (i < 2) s.store(usize, 0xfb4940 + i * 4, actor);
    }
    s.store(u32, @intFromPtr(&packet), 0xc37cfc);
    s.store(f32, @intFromPtr(&packet) + 8, 0.02);
    s.store(u32, @intFromPtr(&engine) + 0xe30, 2);
    s.store(u32, @intFromPtr(&engine) + 0xe28, 1);
    s.store(u8, @intFromPtr(&framework) + 0x4d, 0);
    s.store(u32, 0xfb4b6c, 43);
    s.store(u32, 0xe637b4, 47);
    s.store(u32, 0xea178c, 53);
    s.store(f32, 0xfb4b74, 0.03);
    s.core = std.mem.zeroes(s.Core);
    s.interval = .{ .epoch = 7, .sequence = 1, .level = 6, .active = 1 };
    s.interval_started = true;
    s.observed_lan_session = 17;
    s.sequence = 1;
    s.expected = 1;
    s.last_published_sequence = 1;
    s.lifecycle_release_serial = 9;
    s.reject_bits = 0;
    s.deferred_assignment_restore = 0;
    s.running = false;
    s.fault = 0;
    s.enabled = true;
    s.hooked = true;
    s.outer_depth = 0;
    s.main_boundary_active = false;
    s.main_boundary_serial = 0;
    s.initialized_level = 6;
    s.tick_thread = s.win.GetCurrentThreadId();
    s.window_thread = s.tick_thread;
    s.base_install_state = 1;
    s.dependency_install_state = 1;
    s.mapping_configured = true;
    s.mapping_session = 0;
    s.owned_mapping = false;
    s.permission_install_owner = null;
    s.registered = 255;
    s.module_install_mask = 255;
    s.npc_inputs = std.mem.zeroes(s.Npc.Journal);
    inline for (0..8) |i| {
        const callback = Cohort(@intCast(i));
        s.bindings[i] = .{ .version = 1, .ready = callback.ready, .bind_metadata = callback.bind, .valid = callback.valid, .abort_metadata = callback.abort };
    }
    s.preload = std.mem.zeroes(s.abi.NativePreloadState);
    s.preload.session = 17;
    s.preload.epoch = 7;
    s.preload.level = 6;
    s.preload.world = @intFromPtr(&world);
    s.preload.input.serial = 1;
    s.preload.applied.serial = 1;
    s.preload.completed = 1;
    s.preload.sealed_serial = 1;
    s.changed_actor = @splat(0);
    s.changed_controller = @splat(0);
    s.changed_generation = @splat(0);
    s.saved_device = @splat(0);
    s.saved_device_session = @splat(0);
    s.saved_human = @splat(0);
    s.assignment_lease_serial = 0;
    s.neutral_background_input = false;
    s.previous_local_held = 0;
    s.clonewars_wait_input_sampling = 0;
    s.clonewars_input_override = @splat(0);
    s.latched_ready = false;
    s.pending_actor_pressed = @splat(0);
    s.prep_gate_depth = 0;
    s.clonewars_input_prep_failure = @splat(0);
    s.clonewars_npc_input_failure = @splat(0);
    s.clonewars_sync_first_reject = @splat(0);
    s.clonewars_actor_motion_origin_debug = @splat(0);
}
