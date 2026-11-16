const s = @import("sync_state.zig");
const api = s.api;
const bindings = @import("sync_registry.zig");
const TagSession = @import("tag_state.zig").Session;
pub fn preloadCurrent(level: i32) bool {
    return s.preload.session == api.lan_session_serial() and s.preload.epoch == s.interval.epoch and s.preload.level == level and s.preload.input.serial != 0 and s.preload.world == s.load(usize, 0xfb4a20) and api.game_network_world_valid(level, s.preload.world) != 0;
}
pub fn frameDeliveryReady() bool {
    // A paused host still needs the client to consume published frames and ACK them.
    return api.lan_peer_ready() != 0 or (api.lan_is_host() == 0 and s.expected != 0 and s.preload.sealed_serial != 0 and preloadCurrent(api.game_current_level()));
}
pub fn sceneWithoutParty(level: i32) bool {
    return api.game_native_scene_input_capability(level, s.load(usize, 0xfb4a20)) == 2;
}
pub export fn game_sync_scene_initialized(level: c_int) c_int {
    return @intFromBool(s.interval.active != 0 and s.interval.level == level and s.preload.completed != 0 and s.preload.applied.serial != 0 and s.initialized_level == level and preloadCurrent(level));
}
pub export fn game_sync_scene_ready(level: c_int) c_int {
    const root = s.load(usize, 0xfb2e60);
    return @intFromBool(s.preload.sealed_serial != 0 and s.interval.active != 0 and preloadCurrent(level) and s.valid(root, 0x1b7c) and api.preload_phase_active(s.load(u32, root + 0x1b78), 1) != 0);
}
pub export fn game_sync_coherent_restore_pending() c_int {
    return @bitCast(@atomicLoad(u32, &s.deferred_assignment_restore, .seq_cst));
}
pub export fn game_sync_coherent_blockers() u32 {
    var bits: u32 = 0;
    if (bindings.game_sync_coherent_missing() != 0) bits |= 1;
    if (!s.hooked) bits |= 2;
    if (game_sync_coherent_restore_pending() != 0) bits |= 4;
    if (s.tick_thread == 0) bits |= 8;
    if (!s.mapping_configured or api.user_mapping_install_ready() == 0 or api.user_mapping_session_pending() != 0) bits |= 512;
    if (s.base_install_state != 1 or s.dependency_install_state != 1) bits |= 16;
    if (s.fault != 0 or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) bits |= 1024;
    const root = @import("root");
    if (@hasDecl(root, "coherent_observers_blocked") and root.coherent_observers_blocked) bits |= 256;
    if (@hasDecl(root, "constructor_query_enabled") and root.constructor_query_enabled) {
        if (@import("constructor_observer.zig").clonewars_constructor_observer_installed != 1 or @import("constructor_query_state.zig").clonewars_constructor_query_installed != 3) bits |= 256;
    }
    return bits;
}
pub fn reject(reason: u32, _: usize) callconv(.c) void {
    @import("sync_trace.zig").point(.reject, s.interval.epoch, s.working.sequence, reason, s.core.opened, s.core.bound_mask);
    if (s.clonewars_sync_first_reject[0] == 0) {
        s.clonewars_sync_first_reject[1..8].* = .{ s.interval.epoch, s.working.sequence, s.load(u32, 0xfb4b6c), s.core.opened, @intFromBool(s.running), @returnAddress(), @atomicRmw(u32, &s.failure_order, .Add, 1, .seq_cst) +% 1 };
        @atomicStore(u32, &s.clonewars_sync_first_reject[0], reason, .seq_cst);
    }
    const bit = @as(u32, 1) << @as(u5, @intCast(reason % 31));
    _ = @atomicRmw(u32, &s.reject_bits, .Or, bit, .seq_cst);
    @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    api.coherent_frame_cancel_atomic(bit);
}
pub fn tagSession(raw: ?*TagSession) callconv(.c) c_int {
    const out = raw orelse return 0;
    if (s.window_thread == 0 or s.win.GetCurrentThreadId() != s.window_thread) return 0;
    out.session = api.lan_session_serial();
    out.epoch = if (s.interval.active != 0) s.interval.epoch else 0;
    out.level = api.game_current_level();
    if (api.lan_status() != 3) {
        out.classification = 1;
        return 1;
    }
    if (out.session == 0 or out.session == 0xffffffff) return 0;
    if (s.fault != 0 or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) {
        out.classification = 0;
        return 1;
    }
    const pending = s.load(i32, 0xe6e61c);
    const target = api.game_network_target_level();
    if (pending >= 0 or (target >= 0 and target != out.level)) {
        out.classification = 3;
        return 1;
    }
    const root = s.load(usize, 0xfb2e60);
    const current_owner = api.native_owner_current();
    const install_root = current_owner == s.permission_install_owner and current_owner != null and api.native_owner_scope_nonce(current_owner) == s.permission_install_nonce;
    const native_phase: i32 = if (s.valid(root, 0x1b7c)) s.load(i32, root + 0x1b78) else -1;
    const sealed = s.preload.sealed_serial != 0 and s.preload.session == out.session and s.preload.epoch == out.epoch and s.preload.level == out.level and s.preload.world == s.load(usize, 0xfb4a20);
    const permitted = sealed and ((api.game_actor_count() > 0 and api.game_native_profile_ready() != 0) or sceneWithoutParty(out.level)) and s.initialized_level == out.level and s.observed_lan_session == out.session and s.dependency_install_state == 1 and !install_root and s.core.control_stale == 0 and s.interval.active != 0 and s.interval.epoch != 0 and s.interval.level == out.level and api.preload_phase_active(@bitCast(native_phase), 1) != 0 and api.game_network_profile_ready() != 0 and api.game_network_level_authorized(out.level) != 0 and api.game_load_status() != 1;
    out.classification = if (permitted) 4 else 2;
    return @intFromBool(out.session == api.lan_session_serial());
}
pub fn projectileSession(raw: ?*@import("projectile_types.zig").Session, _: usize) callconv(.c) c_int {
    const out = raw orelse return 0;
    var tag: TagSession = undefined;
    if (tagSession(&tag) == 0) return 0;
    out.* = .{ .epoch = tag.epoch, .level = tag.level, .host = @bitCast(api.lan_is_host()), .classification = if (tag.classification >= 1 and tag.classification <= 4) tag.classification else 5, .session = tag.session };
    return 1;
}
pub fn projectileReject(reason: u32, _: *const @import("projectile_types.zig").Reject, user: usize) callconv(.c) void {
    reject(reason, user);
}
pub fn preloadTransitionWaiting() bool {
    if (api.lan_is_host() == 0) return false;
    var peer = @import("std").mem.zeroes(s.p.SyncPreloadReceipt);
    const received: ?*const s.p.SyncPreloadReceipt = if (api.lan_remote_preload_receipt(s.interval.epoch, s.interval.level, &peer) != 0) &peer else null;
    const pending = api.preload_transition_pending(&s.preload, api.lan_session_serial(), s.interval.epoch, s.interval.level, received);
    if (pending < 0) {
        reject(31, 0);
        return true;
    }
    if (pending != 0) {
        s.clonewars_preload_transition_drain_debug[0] +%= 1;
        s.clonewars_preload_transition_drain_debug[1..6].* = .{ s.preload.session, s.preload.epoch, s.preload.input.serial, s.preload.applied.serial, if (received != null) peer.serial else 0 };
    }
    return pending != 0;
}
pub export fn game_sync_main_boundary_valid(raw: usize, bytes: u32, _: usize) c_int {
    return @import("sync_boundary.zig").Authority(s).valid(raw, bytes, 0);
}
pub export fn game_sync_main_boundary_get(raw: ?*s.MainBoundary) c_int {
    return @import("sync_boundary.zig").Authority(s).get(raw);
}
pub fn mainLifecycleAllowed() bool {
    return game_sync_main_boundary_valid(@intFromPtr(&s.main_boundary), @sizeOf(s.MainBoundary), 0) != 0;
}
pub fn noteWorldComplete() void {
    if (s.core.preload == 0) return;
    if (s.core.preload_epoch != s.interval.epoch or s.core.session != api.lan_session_serial() or s.core.release != api.coherent_frame_release() or s.core.preload_world != s.load(usize, 0xfb4a20) or api.game_current_level() != s.preload.level) {
        reject(31, 0);
        return;
    }
    s.core.preload_world_calls +%= 1;
}
pub fn noteInitializedLevel(level: i32) void {
    if (s.initialized_level != level and s.core.owner != null and s.core.opened == 0) s.core.control_stale = 1;
    s.initialized_level = level;
}
pub export fn game_sync_install() c_int {
    return 0;
}
pub export fn game_sync_restart_required() c_int {
    return @intFromBool(@atomicLoad(u32, &s.reject_bits, .seq_cst) != 0);
}
pub export fn game_sync_status() c_int {
    if (!s.enabled) return -8;
    if (!s.hooked) return -1;
    if (s.fault != 0) return -s.fault - 1;
    if (api.lan_status() == 3 and game_sync_restart_required() != 0) return -256;
    return if (s.sequence != 0 or s.expected != 0) 2 else 0;
}
pub export fn game_sync_sequence() u32 {
    return if (api.lan_is_host() != 0) s.sequence else s.expected;
}
pub export fn game_sync_inspect() void {
    s.clonewars_epoch_debug = .{ s.interval.epoch, @bitCast(s.interval.level), @bitCast(s.interval.active), @intFromBool(s.interval_started), api.lan_epoch(), api.lan_remote_epoch(), game_sync_sequence(), api.lan_peer_ack() };
    const root = s.load(usize, 0xfb2e60);
    s.clonewars_sync_debug = .{ @bitCast(game_sync_status()), @bitCast(api.lan_status()), @bitCast(api.game_current_level()), @bitCast(api.lan_remote_level()), game_sync_sequence(), @bitCast(api.game_actor_count()), s.working.inputs[0].held, s.working.inputs[1].held, @bitCast(api.lan_peer_ready()), @bitCast(api.game_load_status()), s.working.actor_count, @bitCast(api.lan_error()), s.working.variable_count, @bitCast(s.initialized_level), if (s.valid(root, 0x1b7c)) s.load(u32, root + 0x1b78) else 0xffffffff, @sizeOf(s.p.SyncFrame), s.working.inputs[0].pressed, s.working.inputs[1].pressed, s.local_input.pressed, s.working.shot_count };
}
pub export fn game_sync_native_fault(code: c_int) void {
    if (s.fault != 0) return;
    @import("sync_trace.zig").point(.fault, s.interval.epoch, s.working.sequence, @bitCast(code), @intFromBool(s.running), s.core.bound_mask);
    s.clonewars_sync_first_fault[1..8].* = .{ s.interval.epoch, s.working.sequence, s.load(u32, 0xfb4b6c), s.core.opened, @intFromBool(s.running), @returnAddress(), @atomicRmw(u32, &s.failure_order, .Add, 1, .seq_cst) +% 1 };
    @atomicStore(u32, &s.clonewars_sync_first_fault[0], @bitCast(code), .seq_cst);
    s.fault = code;
}
