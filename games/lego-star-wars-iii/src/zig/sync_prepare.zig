const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const mapping = @import("sync_mapping.zig");
const preload = @import("sync_preload.zig");
const numeric = @import("numeric_input.zig");
const span = @import("span_types.zig");
const load = s.load;
const store = s.store;
pub const FrameWindow = struct {
    session: u32 = 0,
    epoch: u32 = 0,
    ack: u32 = 0,
    measured_at: u64 = 0,
    limit: u32 = 3,

    pub fn update(self: *FrameWindow, session: u32, epoch: u32, ack: u32, now: u64) u32 {
        if (session != self.session or epoch != self.epoch or ack < self.ack) {
            self.* = .{ .session = session, .epoch = epoch, .ack = ack, .measured_at = now };
        } else if (now - self.measured_at >= 500) {
            // Leave room for a 90 ms round trip and some scheduling delay.
            // A slower guest needs fewer queued frames to cover the same time.
            const elapsed = now - self.measured_at;
            const progressed = @as(u64, ack - self.ack);
            const in_flight = (progressed * 120 + elapsed - 1) / elapsed;
            self.limit = @intCast(std.math.clamp(1 + in_flight, 3, 8));
            self.ack = ack;
            self.measured_at = now;
        }
        return self.limit;
    }
};
var host_window: FrameWindow = .{};
pub fn control(out: *span.Control, _: usize) callconv(.c) c_int {
    var status: @import("tag_state.zig").Session = undefined;
    if (authority.tagSession(&status) == 0) return 0;
    out.* = .{ .epoch = status.epoch, .level = status.level, .established = @intFromBool(status.classification == 4) };
    return 1;
}
pub fn confirmed(thread: u32, _: usize) callconv(.c) c_int {
    return @intFromBool(thread == s.tick_thread and thread == s.window_thread);
}
fn plan(regs: [*]const u32, engine: usize, out: *u32) bool {
    const framework = regs[7];
    if (!s.valid(engine, 0xe34) or !s.valid(framework, 0x2c) or load(usize, 0xfb0b70) != framework) return false;
    var early = regs[8] & 0x40 != 0;
    if (!early) early = load(usize, framework + 0x28) == 0;
    out.* = @as(u32, @intFromBool(early)) | @as(u32, @intFromBool(load(usize, 0xfb0b60) != 0)) * 2 | @as(u32, @intFromBool(load(u32, engine + 0xe28) != 0)) * 4;
    return true;
}
fn open(owner: *s.owner.Scope, nonce: u32) bool {
    if (api.coherent_frame_open(&s.core.token, @intFromPtr(owner), nonce, @intFromPtr(&s.working), s.working.epoch, s.working.sequence, api.coherent_frame_release()) == 0) return false;
    s.core.opened = 1;
    for (s.bindings, 0..) |binding, i| {
        s.core.bound_mask |= @as(u32, 1) << @as(u5, @intCast(i));
        if (binding.bind_metadata.?(&s.core.token) == 0 or !s.live()) return false;
    }
    return s.live();
}
fn beginInputs() bool {
    inline for (.{ api.geometry_begin, api.cadence_begin, api.model_input_begin }) |begin| {
        if (!s.live() or begin(&s.working, api.lan_is_host()) == 0) return false;
    }
    if (!s.live() or api.npc_input_begin(&s.npc_inputs, &s.working, api.lan_is_host()) == 0) return false;
    if (!s.live() or api.reaction_begin(&s.working, api.lan_is_host()) == 0) return false;
    return true;
}
fn beginTags(host: c_int) bool {
    const result = api.tags_begin(&s.working, host);
    if (!s.live() or result == -1) return false;
    if (result != 1) {
        if (s.fault == 0) s.fault = 9;
        return false;
    }
    return true;
}
pub fn enter(owner: *s.owner.Scope, nonce: u32, packet: usize, receiver: usize, regs: [*]const u32, fx: usize, ready_snapshot: u32, _: usize) callconv(.c) u32 {
    if (s.core.owner != null) {
        authority.reject(28, 0);
        return 2;
    }
    s.core = std.mem.zeroes(s.Core);
    s.core.owner = owner;
    s.core.owner_nonce = nonce;
    s.core.engine = receiver;
    s.core.packet = packet;
    s.core.depth_accounted = 1;
    s.outer_depth +%= 1;
    @import("sync_profiling.zig").begin();
    @import("sync_trace.zig").point(.prepare, s.interval.epoch, s.sequence, nonce, ready_snapshot, s.outer_depth);
    if (s.main_boundary_serial != 0xffffffff) {
        if (s.main_boundary_serial == 0xfffffffe) {
            authority.reject(26, 0);
            return 2;
        }
        s.main_boundary_serial += 1;
    }
    s.main_boundary = .{ .owner = owner, .owner_nonce = nonce, .thread = s.win.GetCurrentThreadId(), .release = api.coherent_frame_release(), .boundary_serial = s.main_boundary_serial };
    s.main_boundary_active = true;
    const old_release = api.coherent_frame_release();
    const old_session = api.lan_session_serial();
    const old_epoch = s.interval.epoch;
    const old_level = s.interval.level;
    var permission_before = std.mem.zeroes(span.Control);
    _ = control(&permission_before, 0);
    var requested_mapping = false;
    if (!mapping.prepare(&s.main_boundary, &requested_mapping)) {
        s.main_boundary_active = false;
        return 2;
    }
    api.loading_poll();
    api.game_poll();
    if (api.game_transition_waiting() == 0) api.game_native_tick();
    s.main_boundary_active = false;
    if (api.game_transition_waiting() != 0) return 2;
    var permission_after = std.mem.zeroes(span.Control);
    _ = control(&permission_after, 0);
    if (permission_before.epoch != permission_after.epoch or permission_before.level != permission_after.level or permission_before.established != permission_after.established) {
        s.core.control_stale = 1;
        return 2;
    }
    if (requested_mapping or !mapping.pollWitnessSame(regs, receiver, old_release, old_session, old_epoch, old_level)) {
        s.core.control_stale = 1;
        return 2;
    }
    const preload_result = preload.prepare(receiver, packet, ready_snapshot);
    if (preload_result != 2) return if (preload_result != 0) 0 else 2;
    if (ready_snapshot == 0) {
        var warm: @import("tag_state.zig").Session = undefined;
        if (authority.tagSession(&warm) == 0) return 2;
        return if (warm.classification >= 1 and warm.classification <= 3) 0 else 2;
    }
    const root = load(usize, 0xfb2e60);
    if (!s.valid(root, 0x1b7c) or api.preload_phase_active(load(u32, root + 0x1b78), 1) == 0 or load(i32, 0xe6e61c) >= 0 or api.lan_status() != 3 or ((s.player(0) == 0 or s.controller(1) == 0) and !authority.sceneWithoutParty(api.game_current_level()))) return 0;
    const level = api.game_current_level();
    if (s.initialized_level != level or authority.game_sync_scene_ready(level) == 0) return 0;
    if (!s.hooked or !s.valid(packet, 0x18) or !preload.packetValid(packet) or !s.valid(receiver, 0xe34)) return 2;
    if (authority.game_sync_coherent_blockers() != 0 or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) return 2;
    if (api.game_network_level_authorized(level) == 0) {
        api.lan_publish_ready(0);
        return 2;
    }
    api.lan_publish_ready(api.game_network_profile_ready());
    if (api.game_network_profile_ready() == 0 or s.interval.active == 0 or s.interval.level != level or s.interval.epoch == 0 or s.fault != 0 or api.lan_remote_level() != level or !authority.frameDeliveryReady()) return 2;
    var admission: span.Lease = undefined;
    if (api.span_engine_control_get(&s.adapter, &admission) == 0) {
        s.core.control_stale = 1;
        return 2;
    }
    @import("sync_input.zig").sampleWait();
    if (api.span_engine_control_valid(&s.adapter, &admission) == 0) return 2;
    const callback_release = s.releaseToken();
    s.core.release = callback_release;
    s.core.host = @bitCast(api.lan_is_host());
    s.core.session = api.lan_session_serial();
    const environment: *[512]u8 = @ptrFromInt(fx);
    if (s.core.host != 0) {
        s.interval.sequence = s.sequence;
        const ack = api.lan_peer_ack();
        const unacknowledged = api.sync_epoch_unacknowledged(&s.interval, api.lan_epoch(), ack);
        const limit = host_window.update(s.core.session, s.interval.epoch, ack, @import("sync_platform.zig").now());
        s.clonewars_coherent_waits[2] = unacknowledged;
        if (unacknowledged >= limit) {
            s.clonewars_coherent_waits[0] +%= 1;
            return 2;
        }
        s.working = std.mem.zeroes(s.p.SyncFrame);
        s.working.epoch = s.interval.epoch;
        s.sequence +%= 1;
        s.working.sequence = s.sequence;
        s.working.level = level;
        s.interval.sequence = s.sequence;
        s.interval_started = true;
        const current_numeric = numeric.read(environment);
        s.working.numeric_cw = current_numeric.cw;
        s.working.numeric_mxcsr = current_numeric.mxcsr;
        s.working.clock = load(u32, 0xfb4b6c);
        s.working.rng_game = load(u32, 0xe637b4);
        s.working.rng_engine = load(u32, 0xea178c);
        s.working.delta = load(f32, 0xfb4b74);
        s.working.engine_delta = load(f32, packet + 8);
        s.working.engine_mode = load(u32, receiver + 0xe30);
    } else {
        if (api.lan_receive_frame(&s.working) == 0) {
            s.clonewars_coherent_waits[1] +%= 1;
            return 2;
        }
        if (api.sync_epoch_apply(&s.interval, level, s.working.epoch, s.working.level, s.working.sequence) <= 0) {
            s.fault = 4;
            return 2;
        }
        s.expected = s.working.sequence;
        s.interval_started = true;
        if (load(u32, receiver + 0xe30) != s.working.engine_mode) {
            s.fault = 12;
            return 2;
        }
        s.core.expected_calls = s.working.native_span_calls;
        s.core.expected_plan = s.working.native_span_plan;
    }
    if (s.releaseChanged(callback_release) or !open(owner, nonce)) return 2;
    const timers = api.spawn_timers_prepare(&s.core.token, &s.working, @intCast(s.core.host));
    if (!s.live()) return 2;
    if (timers == 0) {
        s.fault = 21;
        return 2;
    }
    if (s.core.host == 0) {
        store(u32, 0xfb4b6c, s.working.clock);
        store(u32, 0xe637b4, s.working.rng_game);
        store(u32, 0xea178c, s.working.rng_engine);
        store(f32, 0xfb4b74, s.working.delta);
        store(f32, packet + 8, s.working.engine_delta);
        store(u32, packet + 0xc, s.working.engine_mode);
        store(f32, receiver + 0xe0c, s.working.engine_delta);
    }
    if (s.core.host != 0) {
        const world_ready = api.world_vars_collect(&s.working);
        if (!s.live()) return 2;
        if (world_ready == 0) {
            if (s.fault == 0) s.fault = 6;
            return 2;
        }
        if (!s.live() or !beginTags(1)) return 2;
        const projectiles = api.projectiles_begin(&s.working, 1);
        if (projectiles == 0 or !s.live() or !beginInputs()) return 2;
    } else {
        if (!beginTags(0)) return 2;
        const world_ready = api.world_vars_apply(&s.working);
        if (!s.live()) return 2;
        if (world_ready == 0) {
            api.tags_cancel();
            if (s.fault == 0) s.fault = 6;
            return 2;
        }
        _ = api.entities_bind_tick(&s.working);
        if (!s.live()) return 2;
        const projectiles = api.projectiles_begin(&s.working, 0);
        if (projectiles == 0 or !s.live() or !beginInputs()) return 2;
    }
    if (!s.live() or api.native_tick_begin(&s.working, @intCast(s.core.host), &s.core.token) == 0 or !s.live()) return 2;
    var actual_plan: u32 = undefined;
    if (!plan(regs, receiver, &actual_plan)) return 2;
    if (s.core.host != 0) s.working.native_span_plan = actual_plan else if (actual_plan != s.core.expected_plan) {
        s.fault = 11;
        return 2;
    }
    s.global_step = std.mem.zeroes(s.GlobalStep);
    s.core.main_calls = 0;
    s.core.optional_calls = 0;
    s.clonewars_coherent_debug[14] = 0;
    s.clonewars_coherent_debug[15] = 0;
    s.clonewars_coherent_debug[16] = actual_plan;
    if (api.coherent_frame_set_phase(&s.core.token, 2) == 0 or !s.live()) return 2;
    s.running = true;
    if (api.native_tick_elapsed_input() == 0 or !s.live()) {
        s.running = false;
        return 2;
    }
    if (api.projectiles_dispatch_pending() < 0 or !s.live()) {
        s.running = false;
        if (s.live()) authority.reject(29, 0);
        return 2;
    }
    const root_module = @import("root");
    if (@hasDecl(root_module, "hit_entry_enabled") and root_module.hit_entry_enabled) {
        @import("hit_entry.zig").hit_entry_poll(&s.core.token);
        if (!s.live() or api.coherent_frame_valid(&s.core.token, 4) == 0) return 2;
    }
    const local_numeric = numeric.read(environment);
    s.clonewars_native_numeric_debug[if (s.core.host != 0) @as(usize, 0) else 1] +%= 1;
    if (local_numeric.cw != s.working.numeric_cw or local_numeric.mxcsr != s.working.numeric_mxcsr) s.clonewars_native_numeric_debug[2] +%= 1;
    s.clonewars_native_numeric_debug[3..8].* = .{ local_numeric.cw, s.working.numeric_cw, local_numeric.mxcsr, s.working.numeric_mxcsr, s.working.sequence };
    if (!numeric.apply(environment, .{ .cw = s.working.numeric_cw, .mxcsr = s.working.numeric_mxcsr })) {
        authority.reject(32, 0);
        return 2;
    }
    s.run_count +%= 1;
    @import("sync_trace.zig").point(.dispatch, s.working.epoch, s.working.sequence, actual_plan, s.core.host, s.core.bound_mask);
    return 1;
}
pub fn marker(owner: *s.owner.Scope, nonce: u32, kind: u32, _: usize) callconv(.c) void {
    if (owner != s.core.owner or nonce != s.core.owner_nonce or !s.live()) return;
    if (kind == 1) s.core.main_calls +%= 1 else if (kind == 2) s.core.optional_calls +%= 1;
    s.clonewars_coherent_debug[14] = s.core.main_calls;
    s.clonewars_coherent_debug[15] = s.core.optional_calls;
    if (s.core.main_calls > 1 or s.core.optional_calls > 1) authority.reject(27, 0);
}
