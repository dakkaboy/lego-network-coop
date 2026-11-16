const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const platform = @import("sync_platform.zig");
const load = s.load;
const store = s.store;
pub fn candidate(level: i32, phase: u32) bool {
    return api.preload_stage_eligible(phase, level, load(i32, 0xe6e61c), api.game_network_world_targeted(level), @intFromBool(authority.preloadCurrent(level))) != 0 and api.game_network_level_valid(level) != 0;
}
pub fn packetValid(packet: usize) bool {
    const delta = load(f32, packet + 8);
    return load(u32, packet) == 0xc37cfc and load(u32, packet + 4) == 0 and std.math.isFinite(delta) and delta >= 0 and delta <= 0.1;
}
fn waitValid(session: u32, release: u32, root: usize) bool {
    return api.lan_status() == 3 and session == api.lan_session_serial() and release == api.coherent_frame_release() and s.core.preload_epoch == s.interval.epoch and s.core.preload_world == load(usize, 0xfb4a20) and root == load(usize, 0xfb2e60) and api.native_owner_scope_valid(s.core.owner, s.core.owner_nonce) != 0 and s.fault == 0 and @atomicLoad(u32, &s.reject_bits, .seq_cst) == 0;
}
const Kind = enum { flow, track };
fn awaitReceipt(comptime kind: Kind, serial: u32, ordinal: u32, witness: ?*const [2]u32, value: *u32, debug: *[8]u32) bool {
    const session = s.core.session;
    const release = s.core.release;
    const root = load(usize, 0xfb2e60);
    const started = platform.now();
    while (true) {
        if (!waitValid(session, release, root)) {
            authority.reject(31, 0);
            return false;
        }
        var source = std.mem.zeroes(s.p.SyncPreloadReceipt);
        if (api.lan_remote_preload_receipt(s.interval.epoch, s.preload.level, &source) != 0) {
            const result = if (kind == .track) api.preload_track_read(&source, serial, ordinal, witness, value) else blk: {
                debug[7] = source.flow_count;
                break :blk api.preload_flow_request_read(&source, serial, ordinal, value);
            };
            if (result == 1) return true;
            if (result < 0) {
                authority.reject(31, 0);
                return false;
            }
        }
        if (platform.now() -% started > 300000) {
            authority.reject(31, 0);
            return false;
        }
        platform.sleep(1);
        debug[5] +%= 1;
    }
}
pub export fn game_sync_preload_level() c_int {
    return if (s.core.preload != 0) s.preload.level else -1;
}
pub export fn game_sync_preload_track_input(witness: ?*const [2]u32, local: u32) u32 {
    if (s.core.preload == 0) return local;
    const serial = s.preload.input.serial;
    const ordinal = s.core.preload_flow.track_count;
    const debug = &s.clonewars_preload_track_debug;
    debug[0..4].* = .{ s.interval.epoch, serial, ordinal, local };
    if (witness == null or serial == 0 or ordinal >= s.abi.SYNC_MAX_PRELOAD_FLOW_REQUESTS or local & 0x7f800000 == 0x7f800000) {
        authority.reject(31, 0);
        return local;
    }
    var value = local;
    if (api.lan_is_host() == 0 and !awaitReceipt(.track, serial, ordinal, witness, &value, debug)) return value;
    s.core.preload_flow.tracks[ordinal] = .{ .witness = witness.?.*, .time = value };
    s.core.preload_flow.track_count = ordinal + 1;
    debug[4] = value;
    debug[6] +%= 1;
    return value;
}
pub export fn game_sync_preload_flow_input(flow: usize, local: u32) u32 {
    if (s.core.preload == 0) return local;
    const root = load(usize, 0xfb2e60);
    if (root == 0 or flow != root + 0x1b44) return local;
    const serial = s.preload.input.serial;
    const ordinal = s.core.preload_flow.flow_count;
    const debug = &s.clonewars_preload_flow_debug;
    debug[0..4].* = .{ s.interval.epoch, serial, ordinal, local };
    if (serial == 0 or ordinal >= s.abi.SYNC_MAX_PRELOAD_FLOW_REQUESTS or (local != 0xffffffff and local > 20)) {
        authority.reject(31, 0);
        return local;
    }
    var value = local;
    if (api.lan_is_host() == 0 and !awaitReceipt(.flow, serial, ordinal, null, &value, debug)) return value;
    s.core.preload_flow.flow_requests[ordinal] = value;
    debug[4] = value;
    debug[6] +%= 1;
    s.core.preload_flow.flow_count = ordinal + 1;
    return value;
}
pub fn loadBarrier(phase: u32, level: i32, roster_matches: *bool) bool {
    var local = std.mem.zeroes(s.p.SyncWorldReady);
    local.epoch = s.interval.epoch;
    local.level = level;
    local.root_phase = phase;
    local.completed_serial = s.preload.applied.serial;
    var peer = std.mem.zeroes(s.p.SyncWorldReady);
    peer.level = -1;
    roster_matches.* = false;
    const debug = &s.clonewars_load_barrier_debug;
    if (debug[0] != s.interval.epoch) debug.* = @splat(0);
    debug[0..5].* = .{ s.interval.epoch, @bitCast(level), phase, 0, local.completed_serial };
    debug[8] = load(u32, 0xeb0d18);
    debug[9] = @intFromBool(load(usize, 0xeb0d20) != 0);
    if (api.game_native_loader_idle() == 0) {
        api.lan_invalidate_world_ready();
        debug[7] +%= 1;
        return false;
    }
    const slots = load(u32, 0xfb2e3c);
    const pool = load(usize, 0xfb2f60);
    if (slots > s.p.SYNC_MAX_ACTORS or (slots != 0 and !s.valid(pool, slots * 0x1440))) {
        api.lan_invalidate_world_ready();
        return false;
    }
    for (0..slots) |slot| {
        const actor = pool + slot * 0x1440;
        if (load(u32, actor + 0x50) & 3 != 3) continue;
        const character: u32 = load(u16, actor + 0xdc0);
        const key = (character + 1) *% 0x9e3779b1;
        local.collider_roster +%= key ^ (key >> 16);
        local.collider_count += 1;
    }
    if (api.game_native_loader_idle() == 0) {
        api.lan_invalidate_world_ready();
        return false;
    }
    if (api.lan_publish_world_ready(&local) == 0) return false;
    debug[3] = 1;
    const remote = api.lan_remote_world_ready(s.interval.epoch, level, &peer) != 0;
    roster_matches.* = remote and api.preload_world_roster_matches(&local, &peer) != 0;
    debug[5] = if (remote) peer.completed_serial else 0xffffffff;
    debug[6] = if (remote) peer.root_phase else 0;
    if (api.lan_is_host() != 0 and (!remote or api.preload_world_ready_matches(&local, &peer) == 0)) {
        debug[7] +%= 1;
        return false;
    }
    return true;
}
pub fn prepare(receiver: usize, packet: usize, ready_snapshot: u32) u32 {
    if (api.lan_status() != 3) return 2;
    const root = load(usize, 0xfb2e60);
    const level = api.game_current_level();
    if (!s.valid(root, 0x1b7c)) {
        api.lan_invalidate_world_ready();
        return 2;
    }
    const phase = load(u32, root + 0x1b78);
    const pending = load(i32, 0xe6e61c);
    if (!candidate(level, phase)) {
        api.lan_invalidate_world_ready();
        return 2;
    }
    if (s.interval.active == 0 or s.interval.epoch == 0 or s.interval.level != level or api.game_network_level_authorized(level) == 0 or api.game_network_profile_ready() == 0 or s.fault != 0 or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) {
        api.lan_invalidate_world_ready();
        return 0;
    }
    const world = load(usize, 0xfb4a20);
    if (!s.valid(world, 0x22e8) or api.game_network_world_valid(level, world) == 0 or !s.valid(receiver, 0xe34) or !s.valid(packet, 0x18)) {
        api.lan_invalidate_world_ready();
        return 0;
    }
    const session = api.lan_session_serial();
    const release = api.coherent_frame_release();
    if (session == 0) {
        api.lan_invalidate_world_ready();
        return 0;
    }
    if (s.preload.session == session and s.preload.epoch == s.interval.epoch and s.preload.level == level and s.preload.world != 0 and s.preload.world != world) {
        api.lan_invalidate_world_ready();
        authority.reject(31, 0);
        return 0;
    }
    api.preload_state_bind(&s.preload, session, s.interval.epoch, level, world);
    const ready = ready_snapshot != 0 and ((phase == 0xd or phase == 0xe) or (s.preload.sealed_serial != 0 and api.preload_phase_active(phase, 1) != 0)) and pending < 0 and s.initialized_level == level and ((s.player(0) != 0 and s.controller(1) != 0) or authority.sceneWithoutParty(level)) and authority.frameDeliveryReady() and api.lan_remote_level() == level and api.game_load_status() != 1 and authority.game_sync_coherent_blockers() == 0;
    var roster_matches = false;
    if (s.preload.sealed_serial != 0) {
        if (authority.game_sync_sequence() == 0 and (!loadBarrier(phase, level, &roster_matches) or !roster_matches)) return 0;
        return if (ready) 2 else 0;
    }
    if (!packetValid(packet)) {
        api.lan_invalidate_world_ready();
        return 0;
    }
    var remote = std.mem.zeroes(s.p.SyncPreloadReceipt);
    if (api.lan_is_host() != 0 and s.preload.input.serial != 0) {
        if (api.lan_remote_preload_receipt(s.interval.epoch, level, &remote) == 0) {
            s.clonewars_preload_debug[12] +%= 1;
            return 0;
        }
        const received = api.preload_state_peer_receipt(&s.preload, &remote);
        if (received < 0) {
            authority.reject(31, 0);
            return 0;
        }
        if (received == 0) {
            s.clonewars_preload_debug[12] +%= 1;
            return 0;
        }
    }
    if (!loadBarrier(phase, level, &roster_matches)) return 0;
    var source = std.mem.zeroes(s.p.SyncPreloadInput);
    source.epoch = s.interval.epoch;
    source.level = level;
    source.root_phase = phase;
    if (api.lan_is_host() != 0) {
        if (s.preload.input.serial != 0 and roster_matches and api.preload_initial_seal_ready(&s.preload, phase) != 0) {
            if (!ready) return 0;
            if (api.preload_state_seal(&s.preload, remote.serial) == 0 or api.lan_publish_preload_seal(s.interval.epoch, level, remote.serial) == 0) {
                authority.reject(31, 0);
                return 0;
            }
            s.clonewars_preload_debug[14] = remote.serial;
            return 0;
        }
        if (s.preload.applied.serial == 0xffffffff) {
            authority.reject(31, 0);
            return 0;
        }
        source.serial = s.preload.applied.serial + 1;
        source.clock = load(u32, 0xfb4b6c);
        source.rng_game = load(u32, 0xe637b4);
        source.rng_engine = load(u32, 0xea178c);
        source.rng_effects = load(u32, 0xe5f498);
        source.game_time = load(f32, 0xfb4ad4);
        source.delta = load(f32, 0xfb4b74);
        source.engine_delta = load(f32, packet + 8);
        source.engine_mode = load(u32, receiver + 0xe30);
        if (api.game_native_loader_idle() == 0) {
            api.lan_invalidate_world_ready();
            return 0;
        }
        if (api.lan_publish_preload(&source) == 0) return 0;
        if (api.preload_state_accept(&s.preload, &source) == 0) {
            authority.reject(31, 0);
            return 0;
        }
    } else {
        const seal = api.lan_remote_preload_seal(s.interval.epoch, level);
        if (seal != 0) {
            if (api.preload_state_seal(&s.preload, seal) == 0) {
                authority.reject(31, 0);
                return 0;
            }
            s.clonewars_preload_debug[14] = seal;
            return 0;
        }
        if (api.lan_receive_preload(s.interval.epoch, level, &source) == 0 or source.serial == s.preload.applied.serial) {
            s.clonewars_preload_debug[2] +%= 1;
            return 0;
        }
        if (api.game_native_loader_idle() == 0) {
            api.lan_invalidate_world_ready();
            return 0;
        }
        if (api.preload_state_accept(&s.preload, &source) == 0 or source.root_phase != phase or source.engine_mode != load(u32, receiver + 0xe30)) {
            authority.reject(31, 0);
            return 0;
        }
    }
    if (session != api.lan_session_serial() or release != api.coherent_frame_release() or source.epoch != s.interval.epoch or source.level != api.game_current_level() or world != load(usize, 0xfb4a20)) return 0;
    s.core.preload = 1;
    s.core.preload_world = world;
    s.core.preload_epoch = source.epoch;
    s.core.release = release;
    s.core.session = session;
    if (source.serial == 1) {
        s.clonewars_load_barrier_debug[10] = source.clock;
        s.clonewars_load_barrier_debug[11] = source.serial;
    }
    store(u32, 0xfb4b6c, source.clock);
    store(u32, 0xe637b4, source.rng_game);
    store(u32, 0xea178c, source.rng_engine);
    store(u32, 0xe5f498, source.rng_effects);
    store(f32, 0xfb4ad4, source.game_time);
    s.clonewars_preload_seed_debug[0..3].* = .{ source.rng_game, source.rng_engine, source.rng_effects };
    store(f32, 0xfb4b74, source.delta);
    store(f32, packet + 8, source.engine_delta);
    store(u32, packet + 0xc, source.engine_mode);
    store(f32, receiver + 0xe0c, source.engine_delta);
    s.clonewars_preload_debug[3..7].* = .{ source.epoch, @bitCast(level), source.clock, @bitCast(source.engine_delta) };
    s.clonewars_preload_debug[8] = source.serial;
    s.clonewars_preload_debug[13] = phase;
    return 1;
}
const TickFailure = enum(u32) { owner = 1, world = 2, sealed = 3, waiting = 4, polled = 5, timeout = 6 };
fn tickReject(stage: TickFailure, phase: u32, level: i32, world: usize, session: u32) void {
    if (s.clonewars_preload_failure[0] == 0) {
        const root = load(usize, 0xfb2e60);
        s.clonewars_preload_failure = .{
            @backingInt(stage),                                                  s.interval.epoch,                              s.working.sequence,                                   load(u32, 0xfb4b6c),
            phase,                                                               @bitCast(level),                               world,                                                session,
            s.preload.sealed_serial,                                             s.preload.epoch,                               s.preload.world,                                      s.core.opened,
            if (s.valid(root, 0x1b7c)) load(u32, root + 0x1b78) else 0xffffffff, @intFromBool(authority.preloadCurrent(level)), @bitCast(api.game_network_world_valid(level, world)), @bitCast(api.game_transition_waiting()),
        };
    }
    authority.reject(31, 0);
}
pub fn tick(flow: usize) bool {
    if (api.lan_status() != 3 or s.core.opened != 0 or s.core.preload != 0) return true;
    const root = load(usize, 0xfb2e60);
    if (!s.valid(root, 0x1b7c) or flow != root + 0x1b44) return true;
    const phase = load(u32, root + 0x1b78);
    const level = api.game_current_level();
    if (!candidate(level, phase)) return true;
    if (s.core.owner == null or s.win.GetCurrentThreadId() != s.window_thread or s.win.GetCurrentThreadId() != s.tick_thread or api.native_owner_current() != s.core.owner or api.native_owner_scope_valid(s.core.owner, s.core.owner_nonce) == 0) {
        tickReject(.owner, phase, level, load(usize, 0xfb4a20), api.lan_session_serial());
        return false;
    }
    const world = load(usize, 0xfb4a20);
    const session = api.lan_session_serial();
    if (api.game_network_world_valid(level, world) == 0 or session == 0) {
        tickReject(.world, phase, level, world, session);
        return false;
    }
    if (s.preload.sealed_serial != 0 and authority.preloadCurrent(level)) {
        if (s.fault == 0 and @atomicLoad(u32, &s.reject_bits, .seq_cst) == 0 and @import("native_cycle.zig").restarting(phase, load(u32, 0xfb4b6c), authority.game_sync_sequence(), authority.game_sync_scene_initialized(level) != 0)) {
            return false;
        }
        tickReject(.sealed, phase, level, world, session);
        return false;
    }
    const started = platform.now();
    while (true) {
        if (api.lan_status() != 3 or session != api.lan_session_serial() or world != load(usize, 0xfb4a20) or root != load(usize, 0xfb2e60) or flow != root + 0x1b44 or api.game_network_world_valid(level, world) == 0 or api.native_owner_scope_valid(s.core.owner, s.core.owner_nonce) == 0 or s.fault != 0 or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) {
            tickReject(.waiting, phase, level, world, session);
            return false;
        }
        if (s.main_boundary_serial == 0xfffffffe) {
            authority.reject(26, 0);
            return false;
        }
        s.main_boundary_serial +%= 1;
        s.main_boundary = .{ .owner = s.core.owner, .owner_nonce = s.core.owner_nonce, .thread = s.win.GetCurrentThreadId(), .release = api.coherent_frame_release(), .boundary_serial = s.main_boundary_serial };
        s.main_boundary_active = true;
        api.loading_poll();
        api.game_poll();
        s.main_boundary_active = false;
        if (api.game_transition_waiting() != 0) return false;
        if (world != load(usize, 0xfb4a20) or root != load(usize, 0xfb2e60) or phase != load(u32, root + 0x1b78) or session != api.lan_session_serial()) {
            tickReject(.polled, phase, level, world, session);
            return false;
        }
        const result = prepare(s.core.engine, s.core.packet, 0);
        if (result == 1) {
            s.clonewars_preload_debug[15] = phase;
            return true;
        }
        if (result == 2) return true;
        if (@atomicLoad(u32, &s.reject_bits, .seq_cst) != 0 or s.fault != 0 or platform.now() -% started > 300000) {
            tickReject(.timeout, phase, level, world, session);
            return false;
        }
        platform.sleep(1);
    }
}
