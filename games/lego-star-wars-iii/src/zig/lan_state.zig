const std = @import("std");
const p = @import("protocol.zig");
const t = @import("threading.zig");
extern fn preload_input_valid(?*const p.SyncPreloadInput) c_int;
extern fn preload_receipt_valid(?*const p.SyncPreloadReceipt) c_int;
extern fn preload_world_ready_valid(?*const p.SyncWorldReady) c_int;
extern fn preload_world_ready_matches(*const p.SyncWorldReady, *const p.SyncWorldReady) c_int;
extern fn preload_world_roster_matches(*const p.SyncWorldReady, *const p.SyncWorldReady) c_int;
extern fn sync_frame_size(?*const p.SyncFrame) u32;
extern fn sync_frame_valid(?*const p.SyncFrame, u32) c_int;
const Queue = @import("frame_queue.zig").Queue;
extern fn sync_profile_valid(?*const p.SyncProfile) c_int;
pub const Peer = extern struct {
    epoch: u32 = 0,
    level: i32 = -1,
    ready: i32 = 0,
    input: p.SyncInput = neutral(),
    loading: p.SyncLoading = loading(),
    auto_skip: u32 = 0,
    ack: u32 = 0,
    native_entry: u32 = 0,
    preload: p.SyncPreloadInput = preload(),
    preload_receipt: p.SyncPreloadReceipt = std.mem.zeroes(p.SyncPreloadReceipt),
    preload_seal: u32 = 0,
    world_ready: p.SyncWorldReady = worldReady(),
};
pub const Transition = extern struct { epoch: u32, level: i32, native_entry: u32 };
pub var status: i32 = 0;
pub var error_code: i32 = 0;
pub var generation: u32 = 0;
pub var published_session: u32 = 0;
pub var generation_exhausted: u32 = 0;
pub var host_role: i32 = 0;
pub var local_level: i32 = -1;
pub var remote_level: i32 = -1;
pub var local_state: Peer = .{};
pub var peer_state: Peer = .{};
var once: usize = 0;
var queue_lock: t.CriticalSection = .{};
pub var worker_lock: t.CriticalSection = .{};
var outbound: Queue = .{ .allocator = std.heap.c_allocator };
var inbound: Queue = .{ .allocator = std.heap.c_allocator };
var own_profile: p.SyncProfile = std.mem.zeroes(p.SyncProfile);
var peer_profile: p.SyncProfile = std.mem.zeroes(p.SyncProfile);
var own_profile_pending = false;
var peer_profile_pending = false;
pub const Invalidator = *const fn (u32, usize) callconv(.c) void;
var session_invalidator: ?Invalidator = null;
var session_invalidator_user: usize = 0;
pub fn neutral() p.SyncInput {
    return .{ .held = 0, .pressed = 0, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
}
fn loading() p.SyncLoading {
    var value = std.mem.zeroes(p.SyncLoading);
    value.level = -1;
    return value;
}
fn preload() p.SyncPreloadInput {
    var value = std.mem.zeroes(p.SyncPreloadInput);
    value.level = -1;
    return value;
}
fn worldReady() p.SyncWorldReady {
    var value = std.mem.zeroes(p.SyncWorldReady);
    value.level = -1;
    return value;
}
fn initialize(_: *usize, _: usize, _: usize) callconv(.winapi) i32 {
    t.InitializeCriticalSection(&queue_lock);
    t.InitializeCriticalSection(&worker_lock);
    return 1;
}
pub fn lock() void {
    _ = t.InitOnceExecuteOnce(&once, initialize, 0, 0);
    t.EnterCriticalSection(&queue_lock);
}
pub fn unlock() void {
    t.LeaveCriticalSection(&queue_lock);
}
pub fn clearFrames() void {
    outbound.clear();
    inbound.clear();
}

pub export fn lan_clear_frames() void {
    lock();
    defer unlock();
    clearFrames();
}
fn resetPreload() void {
    local_state.preload = preload();
    local_state.preload_receipt = std.mem.zeroes(p.SyncPreloadReceipt);
    local_state.preload_seal = 0;
    local_state.world_ready = worldReady();
}
fn publishEpoch(epoch: u32) void {
    if (local_state.epoch == epoch) return;
    local_state.epoch = epoch;
    local_state.ack = 0;
    local_state.ready = 0;
    local_state.input = neutral();
    local_state.loading = loading();
    local_state.loading.epoch = epoch;
    resetPreload();
    if (lan_is_host() != 0) outbound.clear();
}
pub export fn lan_publish_epoch(epoch: u32) void {
    lock();
    defer unlock();
    publishEpoch(epoch);
}
pub export fn lan_publish_transition(epoch: u32, level: i32, native_entry: u32) void {
    if (level < -1 or level >= 4096 or native_entry > p.SYNC_TRANSITION_NATIVE_CYCLE) return;
    lock();
    defer unlock();
    if (local_state.epoch != epoch or local_state.level != level) local_state.native_entry = native_entry;
    publishEpoch(epoch);
    if (local_state.level != level) resetPreload();
    local_state.level = level;
    @atomicStore(i32, &local_level, level, .seq_cst);
}
pub fn publicationSnapshot(ticket: u32, own: *Peer, heartbeat: bool, sent_epoch: u32, sent_ack: u32) i32 {
    lock();
    defer unlock();
    if (!active(ticket)) return -1;
    if (!heartbeat and (local_state.ack == 0 or (local_state.epoch == sent_epoch and local_state.ack == sent_ack))) return 0;
    own.* = local_state;
    own.level = local_level;
    local_state.input.pressed = 0;
    return 1;
}
pub export fn lan_epoch() u32 {
    lock();
    defer unlock();
    return local_state.epoch;
}
pub export fn lan_remote_transition() Transition {
    lock();
    defer unlock();
    return .{ .epoch = peer_state.epoch, .level = peer_state.level, .native_entry = peer_state.native_entry };
}
pub export fn lan_remote_epoch() u32 {
    lock();
    defer unlock();
    return peer_state.epoch;
}
pub export fn lan_publish_ack(sequence: u32) void {
    lock();
    defer unlock();
    local_state.ack = sequence;
}
pub export fn lan_peer_ack() u32 {
    lock();
    defer unlock();
    return if (peer_state.epoch == local_state.epoch and peer_state.level == local_state.level) peer_state.ack else 0;
}
pub export fn lan_publish_ready(actors: i32) void {
    lock();
    defer unlock();
    local_state.ready = @intFromBool(actors > 0);
}
pub export fn lan_peer_ready() c_int {
    lock();
    defer unlock();
    return @intFromBool(peer_state.ready != 0 and local_state.epoch != 0 and peer_state.epoch == local_state.epoch);
}
pub export fn lan_invalidate_world_ready() void {
    lock();
    defer unlock();
    local_state.world_ready = worldReady();
}
pub export fn lan_publish_world_ready(value: ?*const p.SyncWorldReady) c_int {
    if (preload_world_ready_valid(value) == 0 or value.?.epoch == 0) return 0;
    const ready = value.?;
    lock();
    defer unlock();
    if (status != 3 or local_state.epoch != ready.epoch or local_state.level != ready.level) return 0;
    local_state.world_ready = ready.*;
    return 1;
}
pub export fn lan_remote_world_ready(epoch: u32, level: i32, output: ?*p.SyncWorldReady) c_int {
    const out = output orelse return 0;
    lock();
    defer unlock();
    const ready = &peer_state.world_ready;
    if (status != 3 or peer_state.epoch != epoch or peer_state.level != level or preload_world_ready_valid(ready) == 0 or ready.epoch != epoch or ready.level != level) return 0;
    out.* = ready.*;
    return 1;
}
pub export fn lan_publish_preload(value: ?*const p.SyncPreloadInput) c_int {
    const input = value orelse return 0;
    if (input.epoch == 0 or preload_input_valid(input) == 0) return 0;
    lock();
    defer unlock();
    const ready = &local_state.world_ready;
    if (lan_is_host() == 0 or status != 3 or local_state.epoch != input.epoch or local_state.level != input.level or peer_state.epoch != input.epoch or peer_state.level != input.level or
        preload_world_ready_matches(ready, &peer_state.world_ready) == 0 or ready.epoch != input.epoch or ready.level != input.level or ready.completed_serial == 0xffffffff or ready.completed_serial + 1 != input.serial or ready.root_phase != input.root_phase) return 0;
    local_state.preload = input.*;
    return 1;
}
pub export fn lan_receive_preload(epoch: u32, level: i32, output: ?*p.SyncPreloadInput) c_int {
    const out = output orelse return 0;
    lock();
    defer unlock();
    const source = &peer_state.preload;
    const ready = &local_state.world_ready;
    if (lan_is_host() != 0 or status != 3 or peer_state.epoch != epoch or source.epoch != epoch or source.level != level or preload_input_valid(source) == 0 or
        ready.epoch != epoch or ready.level != level or ready.completed_serial == 0xffffffff or ready.completed_serial + 1 != source.serial or ready.root_phase != source.root_phase) return 0;
    out.* = source.*;
    return 1;
}
pub export fn lan_publish_preload_receipt(epoch: u32, level: i32, value: ?*const p.SyncPreloadReceipt) c_int {
    if (preload_receipt_valid(value) == 0 or value.?.serial == 0) return 0;
    const receipt = value.?;
    lock();
    defer unlock();
    const source = if (lan_is_host() != 0) &local_state.preload else &peer_state.preload;
    if (status != 3 or local_state.epoch != epoch or local_state.level != level or source.epoch != epoch or source.level != level or source.serial != receipt.serial) return 0;
    local_state.preload_receipt = receipt.*;
    return 1;
}
pub export fn lan_remote_preload_receipt(epoch: u32, level: i32, output: ?*p.SyncPreloadReceipt) c_int {
    const out = output orelse return 0;
    lock();
    defer unlock();
    if (status != 3 or peer_state.epoch != epoch or peer_state.level != level or preload_receipt_valid(&peer_state.preload_receipt) == 0) return 0;
    out.* = peer_state.preload_receipt;
    return 1;
}
pub export fn lan_publish_preload_seal(epoch: u32, level: i32, serial: u32) c_int {
    if (serial == 0) return 0;
    lock();
    defer unlock();
    const ready = &local_state.world_ready;
    const receipt = &local_state.preload_receipt;
    if (lan_is_host() == 0 or status != 3 or local_state.epoch != epoch or local_state.level != level or peer_state.epoch != epoch or peer_state.level != level or
        receipt.serial != serial or peer_state.preload_receipt.serial != serial or !std.mem.eql(u8, std.mem.asBytes(receipt), std.mem.asBytes(&peer_state.preload_receipt)) or
        preload_world_roster_matches(ready, &peer_state.world_ready) == 0 or ready.completed_serial != serial or receipt.end_phase != ready.root_phase or (ready.root_phase != 0xd and ready.root_phase != 0xe)) return 0;
    local_state.preload_seal = serial;
    return 1;
}
pub export fn lan_remote_preload_seal(epoch: u32, level: i32) u32 {
    lock();
    defer unlock();
    return if (status == 3 and peer_state.epoch == epoch and peer_state.level == level) peer_state.preload_seal else 0;
}
pub export fn lan_publish_input(input: *const p.SyncInput) void {
    lock();
    defer unlock();
    const pending = local_state.input.pressed;
    local_state.input = input.*;
    local_state.input.pressed |= pending;
}
pub export fn lan_consume_input() p.SyncInput {
    lock();
    defer unlock();
    const value = if (peer_state.epoch == local_state.epoch) peer_state.input else neutral();
    peer_state.input.pressed = 0;
    return value;
}
pub export fn lan_send_frame(frame: *const p.SyncFrame) c_int {
    if (sync_frame_valid(frame, sync_frame_size(frame)) == 0) return 0;
    lock();
    defer unlock();
    return @intFromBool(outbound.push(frame));
}
pub export fn lan_receive_frame(frame: *p.SyncFrame) c_int {
    lock();
    defer unlock();
    while (inbound.epoch()) |epoch| {
        if (epoch >= local_state.epoch) break;
        _ = inbound.pop(null);
    }
    if (inbound.epoch() != local_state.epoch) return 0;
    return @intFromBool(inbound.pop(frame));
}

pub export fn lan_publish_profile(profile: ?*const p.SyncProfile) void {
    if (sync_profile_valid(profile) == 0) return;
    lock();
    defer unlock();
    own_profile = profile.?.*;
    own_profile_pending = true;
}
pub export fn lan_receive_profile(profile: *p.SyncProfile, max_sequence: u32) c_int {
    lock();
    defer unlock();
    if (peer_profile_pending and peer_profile.epoch < local_state.epoch) peer_profile_pending = false;
    if (!peer_profile_pending or peer_profile.epoch != local_state.epoch or peer_profile.sequence > max_sequence) return 0;
    profile.* = peer_profile;
    peer_profile_pending = false;
    return 1;
}
pub export fn lan_publish_loading(value: *const p.SyncLoading, auto_skip: c_int) void {
    lock();
    defer unlock();
    local_state.loading = value.*;
    local_state.auto_skip = @intFromBool(auto_skip != 0);
}
pub export fn lan_remote_loading() p.SyncLoading {
    lock();
    defer unlock();
    return peer_state.loading;
}
pub export fn lan_remote_auto_skip() c_int {
    lock();
    defer unlock();
    return @intCast(peer_state.auto_skip);
}
pub fn active(ticket: u32) bool {
    return ticket != 0 and @atomicLoad(u32, &generation_exhausted, .seq_cst) == 0 and @atomicLoad(u32, &generation, .seq_cst) == ticket;
}
pub export fn lan_set_session_invalidator(callback: ?Invalidator, user: usize) c_int {
    const cb = callback orelse return 0;
    lock();
    defer unlock();
    if (session_invalidator) |existing| return @intFromBool(existing == cb and session_invalidator_user == user);
    if (generation != 0 or generation_exhausted != 0) return 0;
    session_invalidator = cb;
    session_invalidator_user = user;
    return 1;
}
pub fn advanceGeneration() u32 {
    const old = generation;
    if (generation_exhausted != 0 or old >= 0xfffffffe) {
        if (generation_exhausted == 0) if (session_invalidator) |f| f(0, session_invalidator_user);
        @atomicStore(u32, &published_session, 0, .seq_cst);
        @atomicStore(u32, &generation_exhausted, 1, .seq_cst);
        @atomicStore(i32, &error_code, 534, .seq_cst);
        return 0;
    }
    if (session_invalidator) |f| f(old + 1, session_invalidator_user);
    @atomicStore(u32, &published_session, 0, .seq_cst);
    @atomicStore(u32, &generation, old + 1, .seq_cst);
    return old + 1;
}
pub fn publishSession(ticket: u32) void {
    @atomicStore(u32, &published_session, ticket, .seq_cst);
}
pub export fn lan_session_serial() u32 {
    return @atomicLoad(u32, &published_session, .seq_cst);
}
pub fn sessionStatus(ticket: u32, next: i32, error_code_value: i32) bool {
    lock();
    defer unlock();
    if (!active(ticket)) return false;
    @atomicStore(i32, &error_code, error_code_value, .seq_cst);
    @atomicStore(i32, &status, next, .seq_cst);
    return true;
}
pub fn sessionPeer(ticket: u32, value: *const Peer) bool {
    if (value.native_entry > p.SYNC_TRANSITION_NATIVE_CYCLE) return false;
    lock();
    defer unlock();
    if (!active(ticket)) return false;
    var peer = value.*;
    if (peer.epoch == peer_state.epoch and peer.epoch == local_state.epoch) peer.input.pressed |= peer_state.input.pressed;
    peer_state = peer;
    @atomicStore(i32, &remote_level, peer.level, .seq_cst);
    return true;
}
pub fn sessionInbound(ticket: u32, frame: *const p.SyncFrame) i32 {
    lock();
    defer unlock();
    if (!active(ticket)) return 0;
    return if (inbound.push(frame)) 1 else -1;
}

pub fn takeProfile(ticket: u32, value: *p.SyncProfile) bool {
    lock();
    defer unlock();
    if (!active(ticket) or !own_profile_pending) return false;
    value.* = own_profile;
    own_profile_pending = false;
    return true;
}
pub fn acceptProfile(ticket: u32, value: *const p.SyncProfile) void {
    lock();
    defer unlock();
    if (!active(ticket) or value.epoch < local_state.epoch or value.epoch < peer_profile.epoch) return;
    if (value.epoch == peer_profile.epoch) {
        // Replacing a future snapshot on every host tick can keep it ahead of a slower peer forever.
        if (peer_profile_pending and value.sequence >= peer_profile.sequence) return;
        if (!peer_profile_pending and value.sequence < peer_profile.sequence) return;
    }
    peer_profile = value.*;
    peer_profile_pending = true;
}
pub fn takeFrame(ticket: u32, value: *p.SyncFrame) bool {
    lock();
    defer unlock();
    return active(ticket) and outbound.pop(value);
}

pub fn reset(host: bool) void {
    clearFrames();
    local_state = .{};
    peer_state = .{};
    own_profile_pending = false;
    peer_profile_pending = false;
    peer_profile = std.mem.zeroes(p.SyncProfile);
    @atomicStore(i32, &host_role, @intFromBool(host), .seq_cst);
    @atomicStore(i32, &local_level, -1, .seq_cst);
    @atomicStore(i32, &remote_level, -1, .seq_cst);
    @atomicStore(i32, &error_code, 0, .seq_cst);
    @atomicStore(i32, &status, if (host) 1 else 2, .seq_cst);
}
pub export fn lan_stop() void {
    lock();
    defer unlock();
    const ticket = advanceGeneration();
    @atomicStore(i32, &status, 0, .seq_cst);
    @atomicStore(i32, &remote_level, -1, .seq_cst);
    clearFrames();
    own_profile_pending = false;
    peer_profile_pending = false;
    peer_profile = std.mem.zeroes(p.SyncProfile);
    if (ticket != 0) publishSession(ticket);
}
pub export fn lan_status() i32 {
    return @atomicLoad(i32, &status, .seq_cst);
}
pub export fn lan_error() i32 {
    return @atomicLoad(i32, &error_code, .seq_cst);
}
pub export fn lan_is_host() c_int {
    return @intFromBool(@atomicLoad(i32, &host_role, .seq_cst) != 0);
}
pub export fn lan_publish_level(level: i32) void {
    if (level < -1 or level >= 4096) return;
    lock();
    defer unlock();
    if (local_state.level != level) resetPreload();
    local_state.level = level;
    @atomicStore(i32, &local_level, level, .seq_cst);
}
pub export fn lan_remote_level() i32 {
    return @atomicLoad(i32, &remote_level, .seq_cst);
}
