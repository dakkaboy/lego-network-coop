const std = @import("std");
const game = @import("game_state.zig");
const p = @import("protocol.zig");
const abi = @import("abi.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const game_state_test_api = true;
comptime { _ = @import("profile.zig"); }
export var native_image: [0x1200000]u8 linksection(".text") = @splat(0);
const root: usize = 0x20000000;
const world: usize = 0x20010000;
const catalog: usize = 0x20020000;
const profile: usize = 0x20030000;
const Mock = extern struct {
    status: i32,
    host: i32,
    current: i32,
    sync_level: i32,
    sync_status: i32,
    profile_ready: i32,
    storage_ready: i32,
    capability: i32,
    scene_ready: i32,
    scene_initialized: i32,
    waiting: i32,
    session: u32,
    epoch: u32,
    sequence: u32,
    published_epoch: u32,
    clock: u32,
    published_ready: i32,
    published_level: i32,
    published_native: u32,
    profile_calls: u32,
    enter_calls: u32,
    section_calls: u32,
    apply_calls: u32,
    packet: p.SyncProfile,
    incoming: p.SyncProfile,
    incoming_pending: i32,
};
var mock: Mock = std.mem.zeroes(Mock);
var cycle_epochs = false;
var transition_entry: u32 = 1;
var remote_epoch_pending = false;
var cycle_calls: u32 = 0;
export fn game_state_test_clock() u32 {
    return mock.clock;
}
export fn lan_status() c_int {
    return mock.status;
}
export fn lan_is_host() c_int {
    return mock.host;
}
export fn lan_session_serial() u32 {
    return mock.session;
}
export fn lan_epoch() u32 {
    return mock.published_epoch;
}
export fn lan_publish_ready(value: c_int) void {
    mock.published_ready = value;
}
export fn lan_publish_transition(epoch: u32, level: c_int, entry: u32) void {
    mock.published_epoch = epoch;
    mock.published_level = level;
    mock.published_native = entry;
}
export fn lan_publish_profile(packet: *const p.SyncProfile) void {
    mock.profile_calls += 1;
    mock.packet = packet.*;
}
export fn lan_receive_profile(out: *p.SyncProfile, sequence: u32) c_int {
    if (mock.incoming_pending == 0 or mock.incoming.sequence > sequence) return 0;
    out.* = mock.incoming;
    mock.incoming_pending = 0;
    return 1;
}
export fn game_current_level() c_int {
    return mock.current;
}
export fn game_native_profile_ready() c_int {
    return mock.profile_ready;
}
export fn game_native_profile_storage_ready() c_int {
    return mock.storage_ready;
}
export fn game_native_scene_input_capability(_: c_int, _: usize) c_int {
    return mock.capability;
}
export fn game_sync_status() c_int {
    return mock.sync_status;
}
export fn game_sync_epoch() u32 {
    return mock.epoch;
}
export fn game_sync_sequence() u32 {
    return mock.sequence;
}
export fn game_sync_epoch_level() c_int {
    return mock.sync_level;
}
export fn game_sync_poll_epoch(level: c_int, transitioning: c_int) c_int {
    if (level < 0 and remote_epoch_pending) {
        remote_epoch_pending = false;
        mock.epoch += 1;
        mock.sequence = 0;
        mock.scene_initialized = 0;
        mock.scene_ready = 0;
        return 1;
    }
    if (level >= 0 and (level != mock.sync_level or (cycle_epochs and transitioning != 0 and mock.sequence != 0))) {
        mock.epoch += 1;
        mock.sync_level = level;
        if (cycle_epochs) {
            transition_entry = if (transitioning == p.SYNC_TRANSITION_NATIVE_CYCLE) p.SYNC_TRANSITION_NATIVE_CYCLE else 1;
            mock.sequence = 0;
            mock.scene_initialized = 0;
            mock.scene_ready = 0;
        }
        return 1;
    }
    return 0;
}
export fn game_sync_transition_waiting(_: c_int, _: c_int) c_int {
    return mock.waiting;
}
export fn game_sync_transition_entry() u32 {
    return transition_entry;
}
fn resumeCycle(flow: usize, phase: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), flow == root + 0x1b44 and phase == 10);
    cycle_calls += 1;
    put(root + 0x1b78, phase);
}
export fn game_sync_scene_ready(_: c_int) c_int {
    return mock.scene_ready;
}
export fn game_sync_scene_initialized(_: c_int) c_int {
    return mock.scene_initialized;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn enter(definition: usize, a: c_int, b: c_int, c: c_int) callconv(.c) void {
    check(@src(), a == -1 and b == -1 and c == 0);
    mock.enter_calls += 1;
    win.store(i32, 0xe6e61c, win.load(i16, definition + 0x94));
}
fn section(self: usize, level: c_int, kind: c_int) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), self == 0xe6e618 and kind == 0);
    mock.section_calls += 1;
    win.store(i32, 0xe6e61c, level);
    return 1;
}
fn apply() callconv(.c) void {
    mock.apply_calls += 1;
}
fn jump(address: usize, target: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 5, 0x40, &old) != 0);
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
const Snapshot = extern struct { state: Mock, pending: i32, progress: u32, saved_profile: [abi.SYNC_PROFILE_BYTES]u8 };
var step: usize = 0;
fn hash(value: anytype) u32 {
    var result: u32 = 2166136261;
    for (std.mem.asBytes(value)) |byte| result = (result ^ byte) *% 16777619;
    return result;
}
fn checkpoint() void {
    var snapshot: Snapshot = undefined;
    @memset(std.mem.asBytes(&snapshot), 0);
    snapshot.state = mock;
    snapshot.pending = win.load(i32, 0xe6e61c);
    snapshot.progress = win.load(u32, 0xfb5170);
    @memcpy(&snapshot.saved_profile, @as([*]const u8, @ptrFromInt(profile))[0..abi.SYNC_PROFILE_BYTES]);
    var extra: [93]u32 = @splat(0);
    extra[0..5].* = .{ @bitCast(game.game_load_status()), @bitCast(game.game_target_level()), @bitCast(game.game_network_target_level()), @bitCast(game.game_network_profile_ready()), @bitCast(game.game_transition_waiting()) };
    extra[5..17].* = game.clonewars_transition_debug;
    extra[17..77].* = game.clonewars_transition_context;
    extra[77..93].* = game.clonewars_profile_bootstrap_debug;
    check(@src(), extra[13] == 0 or extra[13] == win.GetCurrentThreadId());
    extra[13] = 0;
    const actual: [2]u32 = .{ hash(&snapshot), hash(&extra) };
    const expected = [_][2]u32{
        .{ 106191433, 3259044890 },  .{ 106191433, 180323706 },   .{ 3670273462, 761182191 },  .{ 214213703, 761182191 },   .{ 1938564640, 2377498681 }, .{ 1938564640, 1180501833 },
        .{ 1938564640, 1591809192 }, .{ 36199728, 2619885078 },   .{ 2204944293, 3218951630 }, .{ 310433884, 3218951630 },  .{ 1283048659, 971479416 },  .{ 1283048659, 3643611768 },
        .{ 3039964826, 3876866729 }, .{ 1283048659, 1204734377 }, .{ 897449446, 2174139873 },  .{ 4190593816, 1342314783 }, .{ 1873109391, 1607491806 }, .{ 3519815510, 1607491806 },
        .{ 4002452098, 3248370551 }, .{ 4223039498, 3248370551 }, .{ 2588020223, 3248370551 },
    };
    check(@src(), step < expected.len);
    if (!std.mem.eql(u32, &actual, &expected[step])) std.debug.print("game state step={d} hashes={any} expected={any}\n", .{ step, actual, expected[step] });
    check(@src(), std.mem.eql(u32, &actual, &expected[step]));
    step += 1;
}
fn poll() void {
    game.game_poll();
    checkpoint();
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 139720 and @intFromPtr(&native_image) < 0x8bd740 and @intFromPtr(&native_image) + native_image.len > 0xfc16b4);
    for ([_][2]usize{ .{ root, 0x3000 }, .{ world, 0x3000 }, .{ catalog, 0x1000 }, .{ profile, 0xc000 } }) |allocation| check(@src(), win.VirtualAlloc(allocation[0], allocation[1], 0x3000, 4) == allocation[0]);
    defer {
        for ([_]usize{ root, world, catalog, profile }) |allocation| check(@src(), win.VirtualFree(allocation, 0, 0x8000) != 0);
    }
    for ([_]usize{ 0xfb0000, 0xfc0000, 0xe60000, 0xeb0000 }) |address| {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(address, 0x10000, 4, &old) != 0);
    }
    jump(0x8bd740, @intFromPtr(&enter));
    jump(0x9097e0, @intFromPtr(&section));
    jump(0x928f10, @intFromPtr(&apply));
    jump(0x7e4800, @intFromPtr(&resumeCycle));
    for (0..4) |i| win.store(i16, catalog + i * 0x1b0 + 0x94, @intCast(i));
    put(0xfb8404, catalog);
    put(0xfb8410, 4);
    put(0xfb8414, catalog);
    put(0xfb4a20, world);
    put(world + 0x220, catalog + 2 * 0x1b0);
    put(0xfb2e60, root);
    put(root + 0x1b78, 14);
    win.store(i32, 0xe6e61c, -1);
    put(0xfbd8bc, profile);
    put(profile, 0x500);
    put(0xfb2e3c, 2);
    win.store(u8, 0xeb1a74, 1);
    mock.status = 3;
    mock.host = 1;
    mock.current = 2;
    mock.sync_level = 2;
    mock.sync_status = 2;
    mock.profile_ready = 1;
    mock.storage_ready = 1;
    mock.capability = 1;
    mock.session = 1;
    mock.epoch = 1;
    mock.clock = 10000;
    mock.published_ready = -1;
    mock.published_level = -1;
    var level: i32 = -1;
    while (level < 5) : (level += 1) {
        check(@src(), game.game_network_level_valid(level) == @intFromBool(level > 0 and level < 4));
        check(@src(), game.game_network_world_valid(level, world) == @intFromBool(level == 2));
    }
    poll();
    check(@src(), game.game_network_profile_ready() != 0 and mock.profile_calls == 1 and mock.packet.sequence == 0);
    game.game_request_level(3);
    checkpoint();
    check(@src(), game.game_network_level_authorized(2) == 0);
    poll();
    check(@src(), mock.enter_calls == 1 and game.game_load_status() == 1 and win.load(i32, 0xe6e61c) == 3);
    poll();
    mock.current = 3;
    put(world + 0x220, catalog + 3 * 0x1b0);
    win.store(i32, 0xe6e61c, -1);
    mock.clock += 300;
    poll();
    check(@src(), game.game_load_status() == 2 and game.game_network_level_authorized(3) != 0);
    game.clonewars_transition_in_tick = 1;
    game.game_native_tick();
    checkpoint();
    game.game_request_reload(3);
    checkpoint();
    mock.clock += 3001;
    poll();
    const before = mock.enter_calls;
    game.game_native_tick();
    checkpoint();
    check(@src(), mock.enter_calls == before + 1 and win.load(u32, 0xfb5170) == 1);
    poll();
    win.store(i32, 0xe6e61c, -1);
    poll();
    game.game_request_level(2);
    checkpoint();
    mock.waiting = 1;
    poll();
    check(@src(), game.game_transition_waiting() != 0);
    mock.waiting = 0;
    game.game_cancel_level_request();
    checkpoint();
    mock.sequence = 17;
    mock.scene_ready = 1;
    mock.clock += 300;
    win.store(u8, profile + 0x80, win.load(u8, profile + 0x80) ^ 1);
    poll();
    check(@src(), mock.packet.sequence == 17);
    mock.status = 0;
    poll();
    check(@src(), game.game_network_profile_ready() == 0 and game.game_network_target_level() == -1);
    mock.status = 3;
    mock.host = 0;
    mock.session += 1;
    mock.sequence = 0;
    mock.scene_ready = 0;
    mock.incoming.epoch = mock.epoch;
    mock.incoming.level = mock.sync_level;
    mock.incoming.sequence = 0;
    @memcpy(&mock.incoming.data, @as([*]const u8, @ptrFromInt(profile))[0..abi.SYNC_PROFILE_BYTES]);
    mock.incoming.data[0x10] = 42;
    mock.incoming.data[0x80] = 0x77;
    mock.incoming.checksum = abi.checksum(&mock.incoming.data);
    mock.incoming_pending = 1;
    const local_header = win.load(u8, profile + 0x10);
    poll();
    check(@src(), game.game_network_profile_ready() != 0 and win.load(u8, profile + 0x10) == local_header and win.load(u8, profile + 0x80) == 0x77 and mock.apply_calls == 1);
    mock.incoming.sequence = 8;
    mock.incoming.data[0x80] = 0x88;
    mock.incoming.checksum = abi.checksum(&mock.incoming.data);
    mock.incoming_pending = 1;
    mock.sequence = 8;
    poll();
    check(@src(), mock.incoming_pending != 0 and mock.apply_calls == 1);
    mock.scene_ready = 1;
    poll();
    check(@src(), mock.incoming_pending == 0 and win.load(u8, profile + 0x80) == 0x88 and mock.apply_calls == 2);
    mock.incoming.sequence = 0;
    mock.incoming_pending = 1;
    poll();
    check(@src(), mock.incoming_pending == 0 and mock.apply_calls == 2);
    mock.incoming.epoch += 1;
    mock.incoming_pending = 1;
    poll();
    check(@src(), mock.apply_calls == 2 and step == 21);
    cycle_epochs = true;
    mock.host = 1;
    mock.epoch = 9;
    mock.published_epoch = 9;
    mock.sequence = 84;
    mock.scene_ready = 1;
    mock.scene_initialized = 1;
    mock.waiting = 1;
    put(root + 0x1b78, 10);
    put(0xfb4b6c, 0);
    const entries = mock.enter_calls;
    const sections = mock.section_calls;
    const ready_before = mock.published_ready;
    game.game_poll();
    check(@src(), game.game_transition_waiting() != 0 and mock.epoch == 9 and mock.sequence == 84 and mock.published_ready == ready_before);
    mock.waiting = 0;
    game.game_poll();
    check(@src(), mock.epoch == 10 and mock.published_epoch == 10 and mock.published_level == 3 and mock.sequence == 0);
    check(@src(), mock.published_native == p.SYNC_TRANSITION_NATIVE_CYCLE);
    check(@src(), mock.enter_calls == entries and mock.section_calls == sections and mock.packet.sequence == 0);
    game.game_poll();
    check(@src(), mock.epoch == 10 and mock.enter_calls == entries and mock.section_calls == sections);
    mock.host = 0;
    mock.incoming_pending = 0;
    for ([_]u32{ 15, 14, 10 }) |phase| {
        mock.scene_initialized = 1;
        mock.scene_ready = 1;
        mock.sequence = 100;
        put(root + 0x1b78, phase);
        put(0xfb4b6c, if (phase == 10) 0 else 105);
        remote_epoch_pending = true;
        const cycles_before = cycle_calls;
        game.game_poll();
        check(@src(), !remote_epoch_pending and cycle_calls == cycles_before + @intFromBool(phase != 10));
        check(@src(), win.load(u32, root + 0x1b78) == 10 and mock.enter_calls == entries and mock.section_calls == sections and game.game_load_status() == 2);
        game.game_poll();
        check(@src(), cycle_calls == cycles_before + @intFromBool(phase != 10));
    }
}
