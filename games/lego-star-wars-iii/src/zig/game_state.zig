const std = @import("std");
const win = @import("win32.zig");
const api = @import("game_api.zig");
const abi = @import("abi.zig");
const p = @import("protocol.zig");
var requested: i32 = -1;
var load_status: i32 = 0;
var last_requested: i32 = -1;
var last_attempt: u32 = 0;
var bootstrap_started: u32 = 0;
var profile_packet = std.mem.zeroes(p.SyncProfile);
var profile_checked: u32 = 0;
var profile_sent: u32 = 0;
var profile_hash: u32 = 0;
var profile_epoch: u32 = 0;
var initial_profile = std.mem.zeroes(abi.ProfileBootstrapHostState);
var received_profile = std.mem.zeroes(abi.ProfileBootstrapClientState);
var initial_profile_staging: [abi.SYNC_PROFILE_BYTES]u8 = @splat(0);
var profile_session: u32 = 0;
var force_requested = false;
var force_loading_seen = false;
var requested_native_entry: u32 = 1;
var tick_requested: i32 = -1;
var tick_seen_gameplay = false;
var initial_request_completed = false;
var request_serial: u32 = 1;
var accepted_serial: u32 = 0;
var last_gameplay_session: u32 = 0;
var committed_level: i32 = -1;
var transition_waiting = false;
var hub_return: struct { session: u32 = 0, epoch: u32 = 0, level: i32 = 0 } = .{};
pub export var clonewars_transition_in_tick: i32 = 0;
pub export var clonewars_transition_context: [60]u32 = @splat(0);
pub export var clonewars_transition_debug: [12]u32 = @splat(0);
pub export var clonewars_profile_bootstrap_debug: [16]u32 = @splat(0);
const root_options = @import("root");
extern fn game_state_test_clock() u32;
fn clockMillis() u32 {
    return if (@hasDecl(root_options, "game_state_test_api") and root_options.game_state_test_api) game_state_test_clock() else GetTickCount();
}
extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn ptr(address: usize) usize {
    return read(usize, address);
}
fn accessible(address: usize, length: usize) bool {
    return win.accessible(address, length, false);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn desiredLevel() i32 {
    return @atomicLoad(i32, &requested, .seq_cst);
}
fn requestedStore(value: i32) void {
    @atomicStore(i32, &requested, value, .seq_cst);
}
fn loadStatus(value: i32) void {
    @atomicStore(i32, &load_status, value, .seq_cst);
}
fn word(value: i32) u32 {
    return @bitCast(value);
}
fn nextRequest() void {
    request_serial +%= 1;
    if (request_serial == 0) request_serial +%= 1;
}
fn nativeDefinition(level: i32) usize {
    const catalog = ptr(0xfb8404);
    const count = read(u32, 0xfb8410);
    if (catalog == 0 or level < 0 or level >= count or count > 4096) return 0;
    const definition = catalog + @as(usize, @intCast(level)) * 0x1b0;
    return if (accessible(definition, 0x1b0) and read(i16, definition + 0x94) == level) definition else 0;
}
fn sceneChainContains(scene_value: usize, descriptor: usize) bool {
    var scene = scene_value;
    for (0..65536) |_| {
        if (scene == 0) break;
        if (scene == descriptor) return true;
        if (!accessible(scene, 0x24)) break;
        scene = ptr(scene + 0x20);
    }
    return false;
}
const PlayedScene = extern struct { next: usize, previous: usize, descriptor: usize };
const PlayedScenes = extern struct { first: usize, last: usize, count: u32 };
pub export fn game_native_scene_entry(manager: usize, level: i32, selector: i32) callconv(.{ .x86_thiscall = .{} }) usize {
    const Find = *const fn (usize, i32, i32) callconv(.{ .x86_thiscall = .{} }) usize;
    const scene = @as(Find, @ptrFromInt(0x7b8630))(manager, level, selector);
    if (scene == 0 or !force_requested or !force_loading_seen or desiredLevel() != level or game_network_level_authorized(level) == 0 or manager != ptr(0xe901f4)) return scene;
    const definition = nativeDefinition(level);
    if (definition == 0 or read(u32, definition + 0x50) & 0xe0 == 0 or !accessible(manager, 0x84)) return scene;
    const history: *PlayedScenes = @ptrFromInt(manager + 0x78);
    var entry = history.first;
    var remaining = history.count;
    while (remaining > 0 and accessible(entry, @sizeOf(PlayedScene))) : (remaining -= 1) {
        const next = ptr(entry);
        if (sceneChainContains(scene, ptr(entry + 8))) {
            const Unlink = *const fn (*PlayedScenes, usize) callconv(.{ .x86_thiscall = .{} }) void;
            const Clear = *const fn (*PlayedScenes) callconv(.{ .x86_thiscall = .{} }) void;
            @as(Unlink, @ptrFromInt(0x654f00))(history, entry);
            var retired: PlayedScenes = .{ .first = entry, .last = entry, .count = 1 };
            @as(Clear, @ptrFromInt(0x7e0220))(&retired);
        }
        entry = next;
    }
    return scene;
}
fn nativeHubDestination() i32 {
    if (api.lan_status() != 3 or api.lan_is_host() == 0 or api.game_sync_status() != 2 or api.game_native_profile_ready() == 0 or read(i32, 0xe6e61c) >= 0 or read(u8, 0xfbc161) != 0 or desiredLevel() >= 0) return -1;
    const root = ptr(0xfb2e60);
    if (!accessible(root, 0x1b7c) or read(i32, root + 0x1b78) != 0xe or !accessible(ptr(0xfbc114), 4) or !accessible(ptr(0xfb087c), 4)) return -1;
    const table = ptr(root);
    if (!accessible(table, 0x188) or ptr(table + 0x184) != 0x4230e0) return -1;
    const Destination = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) usize;
    const definition = @as(Destination, @ptrFromInt(ptr(table + 0x184)))(root);
    if (!accessible(definition, 0x1b0) or read(u32, definition + 0x50) & 0x1000000 == 0) return -1;
    const level: i32 = read(i16, definition + 0x94);
    return if (level != api.game_current_level() and definition == nativeDefinition(level)) level else -1;
}
pub export fn game_can_return_to_hub() c_int {
    return @intFromBool(nativeHubDestination() >= 0);
}
pub export fn game_request_return_to_hub() c_int {
    if (game_can_return_to_hub() == 0) return 0;
    hub_return = .{ .session = api.lan_session_serial(), .epoch = api.game_sync_epoch(), .level = api.game_current_level() };
    return 1;
}
fn isNativeTitles(level: i32) bool {
    const titles = ptr(0xfb8414);
    return accessible(titles, 0x96) and read(i16, titles + 0x94) == level;
}
fn profileOrPartylessReady() bool {
    return api.game_native_profile_ready() != 0 or api.game_native_scene_input_capability(api.game_current_level(), ptr(0xfb4a20)) == 2;
}
pub export fn game_network_level_valid(level: i32) c_int {
    const definition = nativeDefinition(level);
    const titles = ptr(0xfb8414);
    return @intFromBool(definition != 0 and titles != 0 and definition != titles);
}
pub export fn game_network_world_valid(level: i32, world: usize) c_int {
    return @intFromBool(game_network_level_valid(level) != 0 and accessible(world, 0x224) and ptr(world + 0x220) == nativeDefinition(level));
}
pub export fn game_network_world_targeted(level: i32) c_int {
    const desired = desiredLevel();
    return @intFromBool(desired < 0 or desired == level);
}
pub export fn game_native_loader_idle() c_int {
    const queued = read(u32, 0xeb0d18);
    const active = ptr(0xeb0d20);
    asm volatile ("" ::: .{ .memory = true });
    return @intFromBool(@import("loader_policy.zig").jobsIdle(queued, active, read(u32, 0xeb0d18), ptr(0xeb0d20)));
}
pub export fn game_actor_count() c_int {
    const count = read(u32, 0xfb2e3c);
    return if (count <= 4096) @intCast(count) else 0;
}
pub export fn game_request_level(level: i32) void {
    if (!abi.validLevel(level)) return;
    if (desiredLevel() != level) {
        nextRequest();
        accepted_serial = 0;
        force_requested = false;
        force_loading_seen = false;
        requested_native_entry = 1;
        if (api.lan_is_host() == 0) api.lan_publish_ready(0);
    }
    requestedStore(level);
}
pub export fn game_request_reload(level: i32) void {
    if (!abi.validLevel(level)) return;
    nextRequest();
    accepted_serial = 0;
    force_requested = true;
    force_loading_seen = false;
    last_requested = -1;
    requested_native_entry = 1;
    requestedStore(level);
    if (api.lan_is_host() == 0) api.lan_publish_ready(0);
}
pub export fn game_cancel_level_request() void {
    if (desiredLevel() < 0 and @atomicLoad(i32, &tick_requested, .seq_cst) < 0 and !force_requested) return;
    nextRequest();
    accepted_serial = 0;
    force_requested = false;
    force_loading_seen = false;
    last_requested = -1;
    requested_native_entry = 1;
    requestedStore(-1);
    @atomicStore(i32, &tick_requested, -1, .seq_cst);
}
pub export fn game_network_target_level() c_int {
    if (api.lan_status() != 3) return -1;
    return if (api.lan_is_host() != 0) committed_level else if (api.game_sync_epoch() != 0) api.game_sync_epoch_level() else -1;
}
pub export fn game_network_level_authorized(level: i32) c_int {
    if (level < 0 or level != game_network_target_level() or api.game_sync_epoch() == 0 or api.game_sync_epoch_level() != level) return 0;
    return @intFromBool(api.lan_is_host() == 0 or desiredLevel() < 0 or accepted_serial == request_serial);
}
fn resetProfileClock() void {
    profile_checked = 0;
    profile_sent = 0;
    profile_epoch = 0;
    profile_hash = 0;
}
fn commitTarget(level: i32, serial: u32, transitioning: bool) void {
    publishTarget(level, serial, @intFromBool(transitioning));
}
fn publishTarget(level: i32, serial: u32, mode: u32) void {
    const transitioning = mode != 0;
    if (api.lan_status() != 3 or api.lan_is_host() == 0 or game_network_level_valid(level) == 0) return;
    if (serial != 0 and (serial != request_serial or desiredLevel() != level)) return;
    if (api.game_sync_transition_waiting(level, @intFromBool(transitioning)) != 0) {
        transition_waiting = true;
        return;
    }
    const session = api.lan_session_serial();
    const previous_epoch = api.game_sync_epoch();
    const capture = transitioning or initial_profile.captured == 0 or initial_profile.context.session != session or initial_profile.context.epoch != previous_epoch or initial_profile.context.level != level;
    var source_level: i32 = -1;
    var source_phase: i32 = -1;
    var source_clock: u32 = 0;
    if (capture) {
        const profile = ptr(0xfbd8bc);
        if (api.game_native_profile_storage_ready() == 0 or !accessible(profile, abi.SYNC_PROFILE_BYTES) or profile != ptr(0xfbd8bc)) {
            api.lan_publish_ready(0);
            clonewars_profile_bootstrap_debug[13] +%= 1;
            return;
        }
        @memcpy(&initial_profile_staging, bytes(profile, abi.SYNC_PROFILE_BYTES));
        source_level = api.game_current_level();
        source_clock = read(u32, 0xfb4b6c);
        const root = ptr(0xfb2e60);
        if (accessible(root, 0x1b7c)) source_phase = read(i32, root + 0x1b78);
    }
    committed_level = level;
    if (serial != 0) accepted_serial = serial;
    _ = api.game_sync_poll_epoch(level, @intCast(mode));
    const context: abi.ProfileBootstrapContext = .{ .session = session, .epoch = api.game_sync_epoch(), .level = level };
    if (session != api.lan_session_serial() or abi.profile_bootstrap_context_valid(&context) == 0) {
        api.lan_publish_ready(0);
        return;
    }
    if (initial_profile.captured == 0 or initial_profile.context.session != session or initial_profile.context.epoch != context.epoch or initial_profile.context.level != level) {
        if (!capture or abi.profile_bootstrap_host_bind(&initial_profile, &context) == 0 or abi.profile_bootstrap_host_capture(&initial_profile, &context, &initial_profile_staging, abi.SYNC_PROFILE_BYTES, 0) == 0) {
            api.lan_publish_ready(0);
            clonewars_profile_bootstrap_debug[13] +%= 1;
            return;
        }
        resetProfileClock();
        const values = [_]u32{ context.epoch, word(level), session, word(source_level), word(source_phase), source_clock, initial_profile.initial.checksum, initial_profile.initial.sequence };
        @memcpy(clonewars_profile_bootstrap_debug[0..8], &values);
    }
    api.lan_publish_transition(api.game_sync_epoch(), level, api.game_sync_transition_entry());
}
fn hostPublication(current: i32, playing: bool, pending: i32) void {
    const desired = desiredLevel();
    if (desired >= 0) {
        if (accepted_serial == request_serial and committed_level == desired) commitTarget(desired, request_serial, pending >= 0) else if (api.game_sync_transition_waiting(desired, 1) != 0) transition_waiting = true else if (pending == desired) commitTarget(desired, request_serial, true) else api.lan_publish_ready(0);
        return;
    }
    if (game_network_level_valid(pending) != 0) {
        commitTarget(pending, 0, true);
        return;
    }
    const root = ptr(0xfb2e60);
    if (pending < 0 and accessible(root, 0x1b7c) and @import("native_cycle.zig").restarting(read(u32, root + 0x1b78), read(u32, 0xfb4b6c), api.game_sync_sequence(), api.game_sync_scene_initialized(current) != 0)) {
        publishTarget(current, 0, p.SYNC_TRANSITION_NATIVE_CYCLE);
        return;
    }
    if (playing and profileOrPartylessReady() and game_network_level_valid(current) != 0) {
        commitTarget(current, 0, false);
        return;
    }
    if (pending < 0 and isNativeTitles(current)) {
        committed_level = -1;
        accepted_serial = 0;
        _ = api.game_sync_poll_epoch(-1, 0);
        api.lan_publish_transition(0, -1, 0);
        api.lan_publish_ready(0);
    }
}
pub export fn game_load_status() c_int {
    return @atomicLoad(i32, &load_status, .seq_cst);
}
pub export fn game_native_join_party_player(slot: i32, actor: usize, controller: usize) c_int {
    if (slot < 0 or slot >= 2 or !accessible(actor, 0x1440) or !accessible(controller, 0x60)) return 0;
    const index: usize = @intCast(slot);
    if (ptr(0xfb4940 + index * 4) != actor or ptr(actor + 0x6cc) != controller or read(u8, 0xeb1a74 + index * 8) == 0) return 0;
    const framework = ptr(0xfb0afc);
    const devices = ptr(0xfb2e40);
    if (!accessible(framework, 0x888) or read(u32, framework + 0x884) <= index or !accessible(devices, (index + 1) * 4)) return 0;
    const device = ptr(devices + index * 4);
    if (!accessible(device, 0xb0) or read(i32, device) != slot or read(u32, device + 0x88) & 4 == 0 or !std.mem.eql(u8, bytes(0x90bc70, 9), "\x55\x8b\xec\x83\xe4\xf0\x83\xec\x1c")) return 0;
    const Join = *const fn (usize, i32, usize) callconv(.c) void;
    @as(Join, @ptrFromInt(0x90bc70))(actor, slot, device);
    return @intFromBool(ptr(0xfb4940 + index * 4) == actor and ptr(actor + 0x6cc) == controller and ptr(controller) == device and read(u32, actor + 0x50) & 0x200 != 0);
}
pub export fn game_network_profile_ready() c_int {
    const level = game_network_target_level();
    const context: abi.ProfileBootstrapContext = .{ .session = api.lan_session_serial(), .epoch = api.game_sync_epoch(), .level = level };
    if (game_network_level_authorized(level) == 0) return 0;
    if (api.lan_is_host() != 0) return @intFromBool(initial_profile.captured == 1 and initial_profile.context.session == context.session and initial_profile.context.epoch == context.epoch and initial_profile.context.level == level);
    return abi.profile_bootstrap_client_is_applied(&received_profile, &context);
}
pub export fn game_target_level() c_int {
    var level = desiredLevel();
    if (level >= 0) return level;
    level = read(i32, 0xe6e61c);
    if (abi.validLevel(level)) return level;
    level = api.game_current_level();
    if (level >= 0) return level;
    level = read(i32, 0xfb8438);
    return if (abi.validLevel(level)) level else -1;
}
fn pollProfile() void {
    if (api.lan_status() != 3) {
        resetProfileClock();
        profile_session = 0;
        abi.profile_bootstrap_host_reset(&initial_profile);
        abi.profile_bootstrap_client_reset(&received_profile);
        return;
    }
    const session = api.lan_session_serial();
    if (profile_session != session) {
        resetProfileClock();
        profile_session = session;
    }
    const epoch = api.game_sync_epoch();
    if (epoch == 0) return;
    const level = game_network_target_level();
    const context: abi.ProfileBootstrapContext = .{ .session = session, .epoch = epoch, .level = level };
    if (abi.profile_bootstrap_context_valid(&context) == 0 or game_network_level_authorized(level) == 0) return;
    const profile = ptr(0xfbd8bc);
    if (api.game_native_profile_storage_ready() == 0 or !accessible(profile, abi.SYNC_PROFILE_BYTES)) return;
    if (api.lan_is_host() != 0) {
        const now = clockMillis();
        if (now -% profile_checked < 250) return;
        profile_checked = now;
        const initial = abi.profile_bootstrap_host_initial(&initial_profile, &context) orelse return;
        const live = api.game_sync_scene_ready(level) != 0 and api.game_sync_sequence() > 0;
        const data = if (live) bytes(profile, abi.SYNC_PROFILE_BYTES) else &initial.data;
        const hash = abi.checksum(data[0x40..]);
        if (profile_epoch == epoch and profile_sent != 0 and hash == profile_hash and now -% profile_sent < 2000) return;
        profile_packet.epoch = epoch;
        profile_packet.sequence = if (live) api.game_sync_sequence() else 0;
        profile_packet.level = level;
        @memcpy(&profile_packet.data, data);
        profile_packet.checksum = abi.checksum(&profile_packet.data);
        api.lan_publish_profile(&profile_packet);
        profile_hash = hash;
        profile_sent = now;
        profile_epoch = epoch;
        clonewars_profile_bootstrap_debug[8] = profile_packet.checksum;
        clonewars_profile_bootstrap_debug[11] = @intFromBool(live);
    } else if (profileOrPartylessReady()) {
        if (received_profile.context.session != session or received_profile.context.epoch != epoch or received_profile.context.level != level) {
            clonewars_profile_bootstrap_debug[0] = epoch;
            clonewars_profile_bootstrap_debug[1] = word(level);
            clonewars_profile_bootstrap_debug[2] = session;
            clonewars_profile_bootstrap_debug[10] = 0;
            clonewars_profile_bootstrap_debug[14] = 0;
            clonewars_profile_bootstrap_debug[15] = 0;
        }
        if (abi.profile_bootstrap_client_bind(&received_profile, &context) == 0) return;
        const sealed = api.game_sync_scene_ready(level);
        if (abi.profile_bootstrap_client_should_apply(&received_profile, &context, sealed) == 0) return;
        var sequence = api.game_sync_sequence();
        if (sequence == 0) sequence = 0xffffffff;
        if (api.lan_receive_profile(&profile_packet, sequence) == 0 or profile_packet.level != game_network_target_level() or profile_packet.epoch != api.game_sync_epoch() or abi.profile_bootstrap_client_accepts_packet(&received_profile, &context, &profile_packet, sealed) == 0) return;
        // The native save stream serializes this pointer-free block; its configuration header stays local.
        if (!std.mem.eql(u8, bytes(profile + 0x40, abi.SYNC_PROFILE_BYTES - 0x40), profile_packet.data[0x40..])) {
            @memcpy(bytes(profile + 0x40, abi.SYNC_PROFILE_BYTES - 0x40), profile_packet.data[0x40..]);
            @as(*const fn () callconv(.c) void, @ptrFromInt(0x928f10))();
        }
        if (session == api.lan_session_serial() and epoch == api.game_sync_epoch() and level == game_network_target_level() and abi.profile_bootstrap_client_mark_applied(&received_profile, &context) != 0) {
            clonewars_profile_bootstrap_debug[9] = profile_packet.checksum;
            clonewars_profile_bootstrap_debug[10] +%= 1;
            clonewars_profile_bootstrap_debug[12] = profile_packet.sequence;
            if (profile_packet.sequence == 0) {
                clonewars_profile_bootstrap_debug[14] +%= 1;
                clonewars_profile_bootstrap_debug[6] = profile_packet.checksum;
                clonewars_profile_bootstrap_debug[3] = word(api.game_current_level());
                clonewars_profile_bootstrap_debug[5] = read(u32, 0xfb4b6c);
                const root = ptr(0xfb2e60);
                if (accessible(root, 0x1b7c)) clonewars_profile_bootstrap_debug[4] = read(u32, root + 0x1b78);
            } else clonewars_profile_bootstrap_debug[15] +%= 1;
        }
    }
}
fn captureTransitionContext(out: []u32, desired: i32) void {
    const definition = ptr(0xfb8414);
    const values = [_]u32{
        word(desired),       word(api.game_current_level()), if (accessible(definition, 0x96)) word(read(i16, definition + 0x94)) else 0xffffffff,
        read(u32, 0xfb840c), read(u32, 0xfc16b0),            read(u32, 0xfb4c80),
        read(u32, 0xfb4c84), read(u32, 0xfb4c88),            read(u32, 0xfb4c94),
        read(u32, 0xfb4c98), read(u32, 0xfb4c9c),            read(u32, 0xe6bcc8),
        read(u32, 0xe6be2c), read(u32, 0xe6be30),            read(u32, 0xe6c5f0),
        read(u32, 0xfb8484), read(u32, 0xe6e61c),            read(u32, 0xfb4a20),
        read(u32, 0xfb4a1c), read(u8, 0xfbc161),
    };
    @memcpy(out[0..values.len], &values);
}
fn acceptNativeTransition(desired: i32, serial: u32) void {
    if (serial != request_serial or desiredLevel() != desired) return;
    commitTarget(desired, serial, true);
    if (force_requested) force_loading_seen = true;
    loadStatus(1);
}
fn nativeTransition(desired: i32, stage: u32) void {
    if (desired < 0 or desiredLevel() != desired or !profileOrPartylessReady()) return;
    if (api.lan_status() == 3 and api.lan_is_host() == 0 and game_network_profile_ready() == 0) return;
    const serial = request_serial;
    const pending = read(i32, 0xe6e61c);
    if (pending >= 0) {
        if (pending == desired) acceptNativeTransition(desired, serial);
        return;
    }
    const root = ptr(0xfb2e60);
    const catalog = ptr(0xfb8404);
    const count = read(u32, 0xfb8410);
    if (!accessible(root, 0x1b7c) or catalog == 0 or desired >= @as(i32, @bitCast(count)) or ptr(0xfbd8bc) == 0 or ptr(0xfb8414) == 0) return;
    const definition = nativeDefinition(desired);
    if (definition == 0) {
        loadStatus(-1);
        requestedStore(-1);
        return;
    }
    const phase = read(i32, root + 0x1b78);
    if (phase != 0xd and phase != 0xe) return;
    if (last_requested == desired and clockMillis() -% last_attempt < 3000) return;
    const restarting = force_requested and api.game_current_level() == desired;
    clonewars_transition_debug[0] = stage;
    clonewars_transition_debug[4] +%= 1;
    clonewars_transition_debug[6] = word(desired);
    clonewars_transition_debug[7] = word(phase);
    clonewars_transition_debug[8] = win.GetCurrentThreadId();
    clonewars_transition_debug[11] = read(u32, 0xfb4b6c);
    if (stage != 0) clonewars_transition_debug[2] +%= 1;
    captureTransitionContext(clonewars_transition_context[0..20], desired);
    @memset(clonewars_transition_context[40..60], 0xffffffff);
    if (requested_native_entry == 0) {
        // A section exit preserves the party; mission entry discards that path.
        const Queue = *const fn (usize, i32, i32) callconv(.{ .x86_thiscall = .{} }) u8;
        _ = @as(Queue, @ptrFromInt(0x9097e0))(0xe6e618, desired, 0);
    } else {
        const Enter = *const fn (usize, i32, i32, i32) callconv(.c) void;
        @as(Enter, @ptrFromInt(0x8bd740))(definition, -1, -1, 0);
    }
    const accepted = read(i32, 0xe6e61c) == desired;
    if (accepted and restarting and read(u32, 0xfb5170) == 0) win.store(u32, 0xfb5170, 1);
    captureTransitionContext(clonewars_transition_context[20..40], desired);
    if (serial != request_serial or desiredLevel() != desired) return;
    if (accepted) {
        clonewars_transition_debug[3] +%= 1;
        acceptNativeTransition(desired, serial);
    } else loadStatus(1);
    last_requested = desired;
    last_attempt = clockMillis();
}
pub export fn game_native_tick() void {
    const root = ptr(0xfb2e60);
    if (accessible(root, 0x1b7c) and read(i32, root + 0x1b78) == 0xe and profileOrPartylessReady()) tick_seen_gameplay = true;
    clonewars_transition_debug[5] = @intFromBool(tick_seen_gameplay);
    clonewars_transition_debug[10] = @intFromBool(initial_request_completed);
    if (hub_return.session != 0) {
        const session = hub_return.session;
        hub_return.session = 0;
        if (session == api.lan_session_serial() and hub_return.epoch == api.game_sync_epoch() and hub_return.level == api.game_current_level()) {
            const destination = nativeHubDestination();
            if (destination >= 0 and std.mem.eql(u8, bytes(0x8bc790, 7), "\x51\x8b\x0d\x60\x2e\xfb\x00")) {
                @as(*const fn () callconv(.c) void, @ptrFromInt(0x8bc790))();
                if (read(i32, 0xe6e61c) == destination) hostPublication(hub_return.level, true, destination);
                if (transition_waiting) return;
            }
        }
    }
    if (clonewars_transition_in_tick == 0) return;
    const desired = @atomicRmw(i32, &tick_requested, .Xchg, -1, .seq_cst);
    clonewars_transition_debug[9] = 0xffffffff;
    if (desired >= 0) nativeTransition(desired, 1);
}
fn pollClientTransition(current: i32, world_active: bool) void {
    const previous = game_network_target_level();
    const initialized = api.game_sync_scene_initialized(current) != 0;
    const changed = api.game_sync_poll_epoch(-1, 0);
    const destination = game_network_target_level();
    if (destination < 0) {
        game_cancel_level_request();
        return;
    }
    if (changed == 0) return;
    if (api.game_sync_transition_entry() == p.SYNC_TRANSITION_NATIVE_CYCLE and previous == destination and destination == current and initialized) {
        game_cancel_level_request();
        const root = ptr(0xfb2e60);
        if (!accessible(root, 0x1ba8) or game_network_world_valid(current, ptr(0xfb4a20)) == 0) {
            loadStatus(-1);
            api.lan_publish_ready(0);
            return;
        }
        // Re-enter the native state machine without rebuilding the scene's script objects.
        if (read(u32, root + 0x1b78) != 0xa or read(u32, 0xfb4b6c) != 0) {
            const Resume = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
            @as(Resume, @ptrFromInt(0x7e4800))(root + 0x1b44, 0xa);
        }
        loadStatus(2);
        return;
    }
    if (destination != current) {
        game_request_level(destination);
        if (previous >= 0 and !force_requested) requested_native_entry = api.game_sync_transition_entry();
        return;
    }
    if (world_active and (previous < 0 or destination == previous)) {
        game_request_reload(destination);
        return;
    }
    game_cancel_level_request();
}
pub export fn game_poll() void {
    transition_waiting = false;
    const current = api.game_current_level();
    const flow_state = ptr(0xfb2e60);
    const playing = accessible(flow_state, 0x1b7c) and read(i32, flow_state + 0x1b78) == 0xe;
    const starting = accessible(flow_state, 0x1b7c) and read(i32, flow_state + 0x1b78) == 0xd and game_network_world_valid(current, ptr(0xfb4a20)) != 0;
    if (bootstrap_started != 0 and api.lan_status() == 3 and read(u8, 0xeb1a74) == 0) {
        const device = read(i32, 0xeb1a70);
        if (device >= 0 and device < 14 and read(u8, 0xead928 + @as(usize, @intCast(device)) * 144) != 0) @as(*const fn (i32, i32) callconv(.c) void, @ptrFromInt(0x582da0))(0, device);
    }
    const pending = read(i32, 0xe6e61c);
    if (api.lan_status() == 3) {
        const session = api.lan_session_serial();
        const published_epoch = api.lan_epoch();
        if (published_epoch != 0 and published_epoch == api.game_sync_epoch() and api.game_sync_status() == 2) last_gameplay_session = session;
        if (api.lan_is_host() != 0) {
            const reconnecting = last_gameplay_session != 0 and last_gameplay_session != session;
            // The peer's fresh loader cannot replay an opening track the host has already consumed.
            const opening_in_progress = starting and read(u32, 0xfb4b6c) != 0;
            if (session != 0 and published_epoch == 0 and (reconnecting or opening_in_progress) and (playing or starting) and pending < 0 and game_network_level_valid(current) != 0 and desiredLevel() < 0) game_request_reload(current);
            hostPublication(current, playing or starting, pending);
        } else {
            pollClientTransition(current, playing or starting);
            if (game_network_level_valid(pending) != 0 and api.game_sync_epoch_level() == current and api.game_sync_sequence() != 0) transition_waiting = true;
        }
    } else {
        _ = api.game_sync_poll_epoch(-1, 0);
        committed_level = -1;
        accepted_serial = 0;
    }
    if (transition_waiting) return;
    pollProfile();
    api.lan_publish_ready(@intFromBool(api.game_sync_epoch() != 0 and game_network_profile_ready() != 0 and (playing or starting or api.game_sync_scene_ready(current) != 0) and
        ((api.game_sync_sequence() > 0 and api.game_sync_scene_ready(current) != 0) or game_native_loader_idle() != 0) and
        ((api.game_native_profile_ready() != 0 and game_actor_count() > 0) or api.game_native_scene_input_capability(current, ptr(0xfb4a20)) == 2) and
        game_network_level_authorized(current) != 0 and game_load_status() != 1 and pending < 0 and !force_requested));
    const desired = desiredLevel();
    if (desired < 0) return;
    if (!profileOrPartylessReady()) {
        const frontend = ptr(0xfb087c);
        const storage = ptr(0xfb0864);
        const flow = ptr(0xfb2e60);
        const phase = if (accessible(flow, 0x1b7c)) read(i32, flow + 0x1b78) else -1;
        if ((bootstrap_started == 0 or (isNativeTitles(current) and clockMillis() -% bootstrap_started > 3000)) and current >= 0 and (phase == 0xd or phase == 0xe) and accessible(frontend, 0x428) and accessible(storage, 0x24)) {
            const local_device = read(i32, 0xeb1a70);
            if (local_device >= 0 and local_device < 14 and read(u8, 0xead928 + @as(usize, @intCast(local_device)) * 144) != 0) @as(*const fn (i32, i32) callconv(.c) void, @ptrFromInt(0x582da0))(0, local_device);
            win.store(i32, frontend + 0x414, 3);
            win.store(i32, 0xe6059c, -1);
            @as(*const fn (usize) callconv(.{ .x86_thiscall = .{} }) void, @ptrFromInt(0x756ea0))(frontend);
            bootstrap_started = clockMillis();
            loadStatus(3);
        }
        return;
    }
    if (force_requested and pending == desired) force_loading_seen = true;
    if (current == desired and pending < 0 and (playing or (starting and api.game_sync_scene_initialized(current) != 0 and game_native_loader_idle() != 0)) and (!force_requested or force_loading_seen)) {
        commitTarget(desired, request_serial, false);
        requestedStore(-1);
        loadStatus(2);
        last_requested = -1;
        force_requested = false;
        force_loading_seen = false;
        initial_request_completed = true;
        captureTransitionContext(clonewars_transition_context[40..60], desired);
        return;
    }
    if (current == desired and pending < 0 and starting and (!force_requested or force_loading_seen)) {
        if (api.lan_status() == 3 and api.lan_is_host() != 0 and accepted_serial != request_serial) commitTarget(desired, request_serial, force_requested);
        return;
    }
    if (last_requested == desired and clockMillis() -% last_attempt < 3000) return;
    if (clonewars_transition_in_tick != 0 and tick_seen_gameplay and initial_request_completed) {
        const previous = @atomicRmw(i32, &tick_requested, .Xchg, desired, .seq_cst);
        if (previous != desired) clonewars_transition_debug[1] +%= 1;
        clonewars_transition_debug[9] = word(desired);
        return;
    }
    @atomicStore(i32, &tick_requested, -1, .seq_cst);
    clonewars_transition_debug[9] = 0xffffffff;
    nativeTransition(desired, 0);
}
pub export fn game_transition_waiting() c_int {
    return @intFromBool(transition_waiting);
}
