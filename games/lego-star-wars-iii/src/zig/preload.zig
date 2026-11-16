const std = @import("std");
const abi = @import("abi.zig");
const State = abi.NativePreloadState;
const Input = abi.SyncPreloadInput;
const Receipt = abi.SyncPreloadReceipt;
const Ready = abi.SyncWorldReady;
const capacity = abi.SYNC_MAX_PRELOAD_FLOW_REQUESTS;
const trace = @import("trace.zig");
const profiler = @import("profiler.zig");

fn bound(state: ?*const State) bool {
    const s = state orelse return false;
    return s.session != 0 and s.epoch != 0 and abi.validLevel(s.level) and s.world != 0;
}
fn equal(a: anytype, b: anytype) bool {
    comptime std.debug.assert(@sizeOf(@TypeOf(a.*)) == @sizeOf(@TypeOf(b.*)));
    return std.mem.eql(u8, std.mem.asBytes(a), std.mem.asBytes(b));
}
fn deltaValid(delta: f32) bool {
    return std.math.isFinite(delta) and delta >= 0 and delta <= 0.1;
}
pub fn phaseActive(phase: u32, initialized: bool) bool {
    return phase == 0xd or phase == 0xe or (initialized and (phase == 0xa or phase == 0xb));
}
export fn preload_phase_active(phase: u32, initialized: c_int) c_int {
    return @intFromBool(phaseActive(phase, initialized != 0));
}
export fn preload_stage_eligible(phase: u32, level: c_int, pending: c_int, targeted: c_int, initialized: c_int) c_int {
    return @intFromBool(abi.validLevel(level) and targeted != 0 and pending < 0 and phaseActive(phase, initialized != 0));
}
export fn preload_input_valid(input: ?*const Input) c_int {
    const v = input orelse return 0;
    if (v.epoch == 0) {
        var empty = std.mem.zeroes(Input);
        empty.level = -1;
        return @intFromBool(equal(v, @as(*const Input, &empty)));
    }
    return @intFromBool(abi.validLevel(v.level) and v.serial != 0 and phaseActive(v.root_phase, true) and
        deltaValid(v.delta) and deltaValid(v.engine_delta) and v.engine_mode <= 16 and std.math.isFinite(v.game_time));
}
export fn preload_receipt_valid(receipt: ?*const Receipt) c_int {
    const r = receipt orelse return 0;
    if (r.flow_count > capacity or r.track_count > capacity or r.world_calls > 64 or r.end_phase > 20) return 0;
    if (r.serial == 0 and (r.world_calls != 0 or r.end_phase != 0 or r.flow_count != 0 or r.track_count != 0)) return 0;
    for (r.flow_requests, r.tracks, 0..) |request, track, i| {
        if (i < r.flow_count) {
            if (request != std.math.maxInt(u32) and request > 20) return 0;
        } else if (request != 0) return 0;
        if (i < r.track_count) {
            if (!std.math.isFinite(@as(f32, @bitCast(track.time)))) return 0;
        } else if (track.time != 0 or track.witness[0] != 0 or track.witness[1] != 0) return 0;
    }
    return 1;
}
export fn preload_flow_request_read(receipt: ?*const Receipt, serial: u32, ordinal: u32, request: ?*u32) c_int {
    if (request == null or serial == 0 or ordinal >= capacity or preload_receipt_valid(receipt) == 0) return -1;
    const r = receipt.?;
    if (r.serial < serial) return 0;
    if (r.serial != serial or ordinal >= r.flow_count) return -1;
    request.?.* = r.flow_requests[ordinal];
    return 1;
}
export fn preload_track_read(receipt: ?*const Receipt, serial: u32, ordinal: u32, witness: ?*const [2]u32, time: ?*u32) c_int {
    if (witness == null or time == null or serial == 0 or ordinal >= capacity or preload_receipt_valid(receipt) == 0) return -1;
    const r = receipt.?;
    if (r.serial < serial) return 0;
    if (r.serial != serial or ordinal >= r.track_count) return -1;
    const track = r.tracks[ordinal];
    if (!std.mem.eql(u32, &track.witness, witness.?)) return -1;
    time.?.* = track.time;
    return 1;
}
export fn preload_world_ready_valid(ready: ?*const Ready) c_int {
    const r = ready orelse return 0;
    if (r.epoch == 0) return @intFromBool(r.level == -1 and r.root_phase == 0 and r.completed_serial == 0 and r.collider_count == 0 and r.collider_roster == 0);
    return @intFromBool(abi.validLevel(r.level) and r.collider_count <= abi.SYNC_MAX_ACTORS and
        (r.collider_count != 0 or r.collider_roster == 0) and phaseActive(r.root_phase, r.completed_serial != 0));
}
export fn preload_world_ready_matches(local: ?*const Ready, peer: ?*const Ready) c_int {
    if (preload_world_ready_valid(local) == 0 or preload_world_ready_valid(peer) == 0) return 0;
    const a = local.?;
    const b = peer.?;
    return @intFromBool(a.epoch != 0 and a.epoch == b.epoch and a.level == b.level and a.root_phase == b.root_phase and a.completed_serial == b.completed_serial);
}
export fn preload_world_roster_matches(local: ?*const Ready, peer: ?*const Ready) c_int {
    return @intFromBool(preload_world_ready_matches(local, peer) != 0 and local.?.collider_count == peer.?.collider_count and local.?.collider_roster == peer.?.collider_roster);
}
export fn preload_state_peer_receipt(state: ?*const State, peer: ?*const Receipt) c_int {
    if (!bound(state) or state.?.input.serial == 0 or preload_receipt_valid(peer) == 0) return -1;
    const s = state.?;
    const p = peer.?;
    if (p.serial < s.applied.serial) return 0;
    return if (p.serial == s.input.serial and s.applied.serial == p.serial and equal(p, @as(*const Receipt, &s.applied))) 1 else -1;
}
export fn preload_initial_seal_ready(state: ?*const State, phase: u32) c_int {
    if (!bound(state)) return 0;
    const s = state.?;
    // Phase 0xD can still construct mission entities after assets have loaded.
    return @intFromBool(s.sealed_serial == 0 and s.completed != 0 and phase == 0xe and preload_input_valid(&s.input) != 0 and
        s.input.epoch == s.epoch and s.input.level == s.level and s.input.root_phase == phase and
        s.input.serial != 0 and s.applied.serial == s.input.serial and preload_receipt_valid(&s.applied) != 0 and s.applied.world_calls != 0 and s.applied.end_phase == phase);
}
export fn preload_transition_pending(state: ?*const State, session: u32, epoch: u32, level: c_int, peer: ?*const Receipt) c_int {
    if (!bound(state)) return 0;
    const s = state.?;
    if (s.session != session or s.epoch != epoch or s.level != level or s.input.serial == 0 or s.sealed_serial != 0) return 0;
    if (preload_input_valid(&s.input) == 0 or s.input.epoch != epoch or s.input.level != level) return -1;
    if (s.applied.serial != s.input.serial or peer == null) return 1;
    const received = preload_state_peer_receipt(s, peer);
    return if (received < 0) -1 else @intFromBool(received == 0);
}
export fn preload_state_bind(state: ?*State, session: u32, epoch: u32, level: c_int, world: usize) void {
    const s = state orelse return;
    if (s.session == session and s.epoch == epoch and s.level == level and s.world == world) return;
    @memset(std.mem.asBytes(s), 0);
    s.session = session;
    s.epoch = epoch;
    s.level = level;
    s.world = world;
    s.input.level = -1;
}
fn accept(state: ?*State, source: ?*const Input) c_int {
    if (!bound(state) or state.?.sealed_serial != 0 or preload_input_valid(source) == 0) return 0;
    const s = state.?;
    const v = source.?;
    if (v.epoch == 0 or v.epoch != s.epoch or v.level != s.level) return 0;
    const previous = &s.input;
    if (previous.epoch != 0) {
        if (v.serial == previous.serial) return @intFromBool(equal(previous, v));
        if (previous.serial == std.math.maxInt(u32) or v.serial != previous.serial + 1 or
            s.applied.serial != previous.serial or preload_receipt_valid(&s.applied) == 0) return 0;
    } else if (v.serial != 1 or s.applied.serial != 0) return 0;
    s.input = v.*;
    return 1;
}
fn finish(state: ?*State, receipt: ?*const Receipt) c_int {
    if (!bound(state) or preload_receipt_valid(receipt) == 0) return 0;
    const s = state.?;
    const r = receipt.?;
    if (r.serial == 0 or preload_input_valid(&s.input) == 0 or s.input.epoch != s.epoch or s.input.level != s.level or r.serial != s.input.serial) return 0;
    if (s.applied.serial == r.serial) return @intFromBool(equal(@as(*const Receipt, &s.applied), r));
    if (s.sealed_serial != 0 or s.applied.serial == std.math.maxInt(u32) or r.serial != s.applied.serial + 1) return 0;
    s.applied = r.*;
    if (r.world_calls != 0) s.completed = 1;
    return 1;
}
fn seal(state: ?*State, serial: u32) c_int {
    if (!bound(state) or serial == 0) return 0;
    const s = state.?;
    if (s.completed == 0 or s.input.serial != serial or s.applied.serial != serial or preload_receipt_valid(&s.applied) == 0) return 0;
    if (s.sealed_serial != 0) return @intFromBool(s.sealed_serial == serial);
    s.sealed_serial = serial;
    return 1;
}

export fn preload_state_accept(state: ?*State, source: ?*const Input) c_int {
    const zone = profiler.zone(@src(), "preload.accept");
    defer zone.end();
    const result = accept(state, source);
    trace.record(.preload, if (state) |s| s.epoch else 0, if (source) |v| v.serial else 0, 1, @intCast(result), if (state) |s| s.applied.serial else 0, 0);
    return result;
}
export fn preload_state_finish(state: ?*State, receipt: ?*const Receipt) c_int {
    const zone = profiler.zone(@src(), "preload.finish");
    defer zone.end();
    const result = finish(state, receipt);
    trace.record(.preload, if (state) |s| s.epoch else 0, if (receipt) |v| v.serial else 0, 2, @intCast(result), if (state) |s| s.input.serial else 0, 0);
    return result;
}
export fn preload_state_seal(state: ?*State, serial: u32) c_int {
    const result = seal(state, serial);
    trace.record(.preload, if (state) |s| s.epoch else 0, serial, 3, @intCast(result), if (state) |s| @bitCast(s.completed) else 0, 0);
    return result;
}
