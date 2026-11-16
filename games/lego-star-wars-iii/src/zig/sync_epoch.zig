const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const input = @import("sync_input.zig");
fn needsTransition(target: i32, transitioning: bool) bool {
    return s.interval.active == 0 or s.interval.level != target or (s.interval_started and transitioning);
}
pub export fn game_sync_transition_waiting(target: c_int, transitioning: c_int) c_int {
    if (s.interval.active == 0 or s.observed_lan_session != api.lan_session_serial() or !needsTransition(target, transitioning != 0)) return 0;
    if (authority.preloadTransitionWaiting()) return 1;
    if (s.last_published_sequence == 0) return 0;
    const ack = api.lan_peer_ack();
    if (ack == s.last_published_sequence) return 0;
    s.clonewars_transition_drain_debug[0] +%= 1;
    s.clonewars_transition_drain_debug[1..4].* = .{ s.interval.epoch, s.last_published_sequence, ack };
    return 1;
}
fn prepare(epoch: u32, level: i32, native_entry: u32) void {
    input.releaseRemote();
    api.projectiles_reset();
    api.tags_reset();
    api.entities_reset_bindings();
    s.running = false;
    s.fault = 0;
    s.sequence = 0;
    s.expected = 0;
    s.last_published_sequence = 0;
    s.clonewars_npc_input_failure = @splat(0);
    s.clonewars_input_prep_failure = @splat(0);
    s.interval_started = false;
    s.previous_local_held = 0;
    api.input_buffer_reset(&s.local_buffer);
    s.sampled_for_flow = false;
    s.interval = .{ .epoch = epoch, .level = level, .active = 1, .sequence = 0 };
    s.transition_native_entry = native_entry;
    api.lan_publish_transition(epoch, level, native_entry);
}
fn suspendPublication() void {
    const previous = s.interval.epoch;
    prepare(0, -1, 0);
    s.interval.epoch = previous;
    s.interval.active = 0;
}
pub export fn game_sync_poll_epoch(target: c_int, transitioning: c_int) c_int {
    if (!authority.mainLifecycleAllowed()) return 0;
    const actual_session = api.lan_session_serial();
    if (actual_session != s.observed_lan_session) {
        input.releaseRemote();
        api.projectiles_reset();
        api.tags_reset();
        api.entities_reset_bindings();
        s.observed_lan_session = actual_session;
        s.session_active = false;
        s.interval.active = 0;
        s.interval_started = false;
        s.sequence = 0;
        s.expected = 0;
        s.last_published_sequence = 0;
    }
    if (api.lan_status() != 3) {
        s.session_active = false;
        s.interval.active = 0;
        s.interval_started = false;
        return 0;
    }
    if (!s.session_active) {
        s.session_active = true;
        if (api.lan_is_host() == 0) s.interval = .{ .level = -1, .epoch = 0, .sequence = 0, .active = 0 };
    }
    if (api.lan_is_host() != 0) {
        if (api.game_network_level_valid(target) == 0) {
            if (s.interval.active != 0 or api.lan_epoch() != 0) {
                suspendPublication();
                return 1;
            }
            return 0;
        }
        if (needsTransition(target, transitioning != 0)) {
            if (s.interval.epoch == 0xffffffff) {
                _ = @atomicRmw(u32, &s.reject_bits, .Or, 0x10000000, .seq_cst);
                api.coherent_frame_cancel_atomic(0x10000000);
                return 0;
            }
            prepare(s.interval.epoch + 1, target, if (transitioning == s.p.SYNC_TRANSITION_NATIVE_CYCLE) s.p.SYNC_TRANSITION_NATIVE_CYCLE else @intFromBool(s.load(u32, 0xfc16b0) != 0));
            return 1;
        }
    } else {
        const remote = api.lan_remote_transition();
        if (remote.epoch == 0) {
            if (s.interval.active != 0) {
                suspendPublication();
                return 1;
            }
            return 0;
        }
        if (remote.epoch > s.interval.epoch and api.game_network_level_valid(remote.level) != 0) {
            prepare(remote.epoch, remote.level, remote.native_entry);
            return 1;
        }
    }
    return 0;
}
pub export fn game_sync_epoch() u32 {
    return if (s.interval.active != 0) s.interval.epoch else 0;
}
pub export fn game_sync_transition_entry() u32 {
    return s.transition_native_entry;
}
pub export fn game_sync_epoch_level() c_int {
    return s.interval.level;
}
