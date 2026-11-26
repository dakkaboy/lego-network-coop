const std = @import("std");
const s = @import("tick_state.zig");
const install = @import("tick_install.zig");
const win = s.win;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var frame: *s.p.SyncFrame = undefined;
var phase: u5 = 1;
var faults: u32 = 0;
export fn world_vars_cohort_valid(token: *const s.Token, phases: u32) c_int {
    return @intFromBool(token.frame == @intFromPtr(frame) and phases & (@as(u32, 1) << phase) != 0);
}
export fn game_sync_native_fault(code: c_int) void {
    check(@src(), code == 22);
    faults += 1;
}
var rope_actor: usize = 0;
var rope_generation: u32 = 13;
export fn entities_observed_identity(value: usize, slot: *u32, generation: *u32) c_int {
    if (value != rope_actor) return 0;
    slot.* = 2;
    generation.* = rope_generation;
    return 1;
}
export fn entities_slot(_: usize) c_int {
    return -1;
}
export fn entities_generation(_: usize) u32 {
    return 0;
}
export fn entities_bind_native_actor(_: *const s.p.SyncFrame, _: usize) c_int {
    return 0;
}
export fn entities_update() void {}
export fn entities_spawn_source(_: usize, _: *u32) s.p.SyncSpawnSource {
    return .{ .producer = 0, .serial = 0 };
}
export fn entities_bind_native_reference(_: *const s.p.SyncActor, _: usize) c_int {
    return 0;
}
export fn entities_observed_generation(_: usize) u32 {
    return 0;
}
export fn entities_allocation_retained(_: usize, _: u32) c_int {
    return 0;
}
export fn entities_actor(_: u32, _: u32) usize {
    return 0;
}
export fn entities_resolve_identity(_: *const s.p.SyncFrame, _: u32, _: u32) usize {
    return 0;
}
export fn lan_status() c_long {
    return 0;
}
export fn game_sync_status() c_int {
    return 0;
}
export fn game_sync_epoch() u32 {
    return 0;
}
export fn game_sync_preload_level() c_int {
    return -1;
}
export fn game_sync_preload_track_input(_: ?*const [2]u32, sample: u32) u32 {
    return sample;
}
export fn game_sync_preload_flow_input(_: usize, pending: u32) u32 {
    return pending;
}
fn writable(address: usize, bytes: usize) void {
    const first = @intFromPtr(&owned_image);
    check(@src(), address >= first and address + bytes <= first + owned_image.len);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, bytes, 0x40, &old) != 0);
}
fn executable(address: usize, bytes: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, bytes, 0x20, &old) != 0);
}
fn expectProtection(address: usize) void {
    var info: win.MemoryInfo = undefined;
    check(@src(), win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
}
pub fn main() void {
    writable(0x475acb, 10);
    s.store([10]u8, 0x475acb, .{ 0x5f, 0x5e, 0x5d, 0x5b, 0x83, 0xc4, 8, 0xc2, 8, 0 });
    executable(0x475acb, 10);
    writable(0x47699b, 3);
    s.store([3]u8, 0x47699b, .{ 0x83, 0xfe, 4 });
    executable(0x47699b, 3);
    writable(0x8766a5, 8);
    s.store([8]u8, 0x8766a5, .{ 0x83, 0xc4, 8, 0xe8, 0x83, 0xb2, 0xf1, 0xff });
    executable(0x8766a5, 8);
    const patches = install.patches();
    var prefixes: [patches.len + install.hit_rng.len][]const u8 = undefined;
    var addresses: [prefixes.len]usize = undefined;
    for (patches, prefixes[0..patches.len], addresses[0..patches.len]) |patch, *prefix, *address| {
        prefix.* = patch.expected;
        address.* = patch.address;
    }
    var calls: [install.hit_rng.len][5]u8 = undefined;
    for (install.hit_rng, &calls, prefixes[patches.len..], addresses[patches.len..]) |source, *bytes, *prefix, *address| {
        bytes[0] = 0xe8;
        std.mem.writeInt(u32, bytes[1..5], source[1] -% source[0] -% 5, .little);
        prefix.* = bytes;
        address.* = source[0];
    }
    for (prefixes, addresses) |bytes, address| {
        writable(address, bytes.len);
        @memcpy(@as([*]u8, @ptrFromInt(address))[0..bytes.len], bytes);
        executable(address, bytes.len);
    }
    for (0..10) |i| {
        writable(0x475acb, 10);
        s.store(u8, 0x475acb + i, s.load(u8, 0x475acb + i) ^ 1);
        executable(0x475acb, 10);
        check(@src(), install.native_tick_install() == 0);
        writable(0x475acb, 10);
        s.store(u8, 0x475acb + i, s.load(u8, 0x475acb + i) ^ 1);
        executable(0x475acb, 10);
    }
    for (prefixes, addresses, 0..) |prefix, address, changed| for (0..prefix.len) |byte| {
        writable(address, prefix.len);
        const bytes: [*]u8 = @ptrFromInt(address);
        bytes[byte] ^= 1;
        executable(address, prefix.len);
        check(@src(), install.native_tick_install() == 0);
        for (prefixes, addresses, 0..) |expected, at, i| {
            expectProtection(at);
            for (expected, 0..) |value, offset| check(@src(), s.load(u8, at + offset) == value ^ @as(u8, @intFromBool(i == changed and offset == byte)));
        }
        writable(address, prefix.len);
        bytes[byte] ^= 1;
        executable(address, prefix.len);
    };
    check(@src(), install.native_tick_install() == 1);
    for (patches) |patch| {
        expectProtection(patch.address);
        check(@src(), s.load(u8, patch.address) == patch.opcode and patch.address +% 5 +% s.load(u32, patch.address + 1) == patch.target);
        for (5..patch.expected.len) |offset| check(@src(), s.load(u8, patch.address + offset) == 0x90);
    }
    for (install.hit_rng) |source| {
        expectProtection(source[0]);
        check(@src(), s.load(u8, source[0]) == 0xe8);
        const expected: usize = if (source[1] == 0x573100) @intFromPtr(&native_rts_wait_seed_input) else if (source[1] == 0x6d6140) @intFromPtr(&native_pack_hit_int_input) else @intFromPtr(&native_pack_hit_float_input);
        check(@src(), source[0] +% 5 +% s.load(u32, source[0] + 1) == expected);
    }
    check(@src(), install.native_tick_install() == 0);
    frame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(s.p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(frame) != 0);
    defer _ = win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    frame.* = std.mem.zeroes(s.p.SyncFrame);
    frame.epoch = 19;
    frame.sequence = 29;
    var token = std.mem.zeroes(s.Token);
    token.frame = @intFromPtr(frame);
    token.epoch = frame.epoch;
    token.thread = win.GetCurrentThreadId();
    writable(0xfb4b6c, 4);
    s.store(u32, 0xfb4b6c, 71);
    check(@src(), @import("tick_input.zig").native_tick_begin(frame, 1, &token) == 1);
    phase = 2;
    win.SetLastError(91);
    check(@src(), s.decision(0x8888cd, 1) == 1 and win.GetLastError() == 91);
    check(@src(), @import("tick_input.zig").native_tick_finish() == 1 and frame.tick_gate_count == 1);
    phase = 1;
    check(@src(), @import("tick_input.zig").native_tick_begin(frame, 0, &token) == 1);
    phase = 2;
    check(@src(), s.decision(0x8888cd, 0) == 1 and @import("tick_input.zig").native_tick_finish() == 1 and faults == 0);
    phase = 1;
    check(@src(), @import("tick_input.zig").native_tick_begin(frame, 1, &token) == 1);
    phase = 2;
    for (0..s.p.SYNC_MAX_TICK_GATES) |index| {
        s.store(u32, 0xfb4b6c, @intCast(71 + index / 15));
        const value: u32 = @intCast(index % 256);
        check(@src(), s.decision(0x8888cd, value) == value);
    }
    check(@src(), frame.tick_gate_count == s.p.SYNC_MAX_TICK_GATES and @import("tick_input.zig").native_tick_finish() == 1 and faults == 0);
    phase = 1;
    check(@src(), @import("tick_input.zig").native_tick_begin(frame, 0, &token) == 1);
    phase = 2;
    for (0..s.p.SYNC_MAX_TICK_GATES) |index| {
        s.store(u32, 0xfb4b6c, @intCast(71 + index / 15));
        check(@src(), s.decision(0x8888cd, 255) == index % 256);
    }
    check(@src(), @import("tick_input.zig").native_tick_finish() == 1 and faults == 0);
    phase = 1;
    check(@src(), @import("tick_input.zig").native_tick_begin(frame, 1, &token) == 1 and frame.tick_gate_count == 0);
    phase = 2;
    frame.tick_gate_count = s.p.SYNC_MAX_TICK_GATES;
    const last = frame.tick_gates[s.p.SYNC_MAX_TICK_GATES - 1];
    check(@src(), s.decision(0x8888cd, 7) == 7 and faults == 1);
    check(@src(), frame.tick_gate_count == s.p.SYNC_MAX_TICK_GATES and std.meta.eql(last, frame.tick_gates[s.p.SYNC_MAX_TICK_GATES - 1]));
    check(@src(), @import("tick_input.zig").native_tick_finish() == 0);
    arenaRope(&token);
    swampPeriscope(&token);
}

extern fn swamp_periscope_result(usize, u32) u32;

fn swampPeriscope(token: *const s.Token) void {
    const input = @import("tick_input.zig");
    var camera: [0x108]u8 align(4) = @splat(0);
    const address = @intFromPtr(&camera);
    s.store(u32, address, 0xae5724);
    s.store(u32, address + 8, 3472594585);
    frame.level = 70;
    phase = 1;
    check(@src(), input.native_tick_begin(frame, 1, token) != 0);
    phase = 2;
    check(@src(), swamp_periscope_result(address, 0) == 0 and frame.tick_gate_count == 1);
    check(@src(), input.native_tick_finish() != 0 and s.valid.streamValid(frame.tick_gates[0..1]));
    phase = 1;
    check(@src(), input.native_tick_begin(frame, 0, token) != 0);
    phase = 2;
    check(@src(), swamp_periscope_result(address, 1) == 0 and input.native_tick_finish() != 0);
}

extern fn arena_rope_sync(u32, usize, usize) void;

fn arenaRope(token: *const s.Token) void {
    const input = @import("tick_input.zig");
    const site = s.site.ARENA_ROPE_STEP;
    var native_actor: [0x1440]u8 align(16) = @splat(0);
    var rope: [0xb0]u8 align(4) = @splat(0);
    var stack: [0x100]u8 align(16) = @splat(0);
    var marker: u32 = 0xc43ce4;
    rope_actor = @intFromPtr(&native_actor);
    const base = @intFromPtr(&rope);
    const args = @intFromPtr(&stack);
    const endpoint = args + 0xc0;
    const fixed = args + 0x80;
    const host = [3]u32{ 0x3f800000, 0x40000000, 0x40400000 };
    const local = [3]u32{ 0x40800000, 0x40a00000, 0x40c00000 };
    s.store(u16, rope_actor + 0xdc0, 186);
    s.store(u32, base, 0xc46990);
    s.store(u32, base + 0x18, 10);
    s.store(u32, base + 0x98, 4);
    s.store(usize, base + 0x9c, @intFromPtr(&marker));
    s.store(u32, base + 0xa4, 3);
    s.store(usize, base + 0xa8, rope_actor);
    s.store(u32, base + 0xac, 12);
    s.store([3]u32, fixed, host);
    s.store([3]u32, endpoint, host);
    frame.level = 12;
    phase = 1;
    check(@src(), input.native_tick_begin(frame, 1, token) == 1);
    phase = 2;
    arena_rope_sync(site, base, args);
    const gates = frame.tick_gates[0..frame.tick_gate_count];
    check(@src(), input.native_tick_finish() == 1 and gates.len == 9 and s.valid.streamValid(gates));
    check(@src(), !s.valid.streamValid(gates[0..8]) and !s.valid.streamValid(gates[1..]));
    phase = 1;
    check(@src(), input.native_tick_begin(frame, 0, token) == 1);
    phase = 2;
    s.store([3]u32, endpoint, local);
    arena_rope_sync(site, base, args);
    check(@src(), input.native_tick_finish() == 1 and std.meta.eql(s.load([3]u32, endpoint), host));

    for (0..4) |change| {
        phase = 1;
        check(@src(), input.native_tick_begin(frame, 0, token) == 1);
        phase = 2;
        s.store([3]u32, endpoint, local);
        const previous_faults = faults;
        const last = gates[8];
        switch (change) {
            0 => rope_generation += 1,
            1 => s.store(u32, fixed + 4, local[1]),
            2 => gates[8].value = 0x7f800000,
            3 => gates[8].clock += 1,
            else => unreachable,
        }
        arena_rope_sync(site, base, args);
        check(@src(), input.native_tick_finish() == 0 and faults == previous_faults + 1);
        check(@src(), s.cursor == 0 and std.meta.eql(s.load([3]u32, endpoint), local));
        rope_generation = 13;
        s.store([3]u32, fixed, host);
        gates[8] = last;
    }
}
extern fn native_pack_hit_int_input() void;
extern fn native_pack_hit_float_input() void;
extern fn native_rts_wait_seed_input() void;
comptime {
    _ = @import("tick_fixture_root.zig");
}
