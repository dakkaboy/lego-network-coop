const std = @import("std");
const input = @import("spellit_input.zig");
const state = @import("spellit_hop_state.zig");
const bodies = @import("spellit_bodies.zig");
const types = @import("spellit_types.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
}
const Hop = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Query = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) u32;
const Enabled = *const fn (usize, usize) callconv(.{ .x86_fastcall = .{} }) u32;
const Selection = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) usize;
const gizmo: usize = 0x20000000;
const piece: usize = 0x20010000;
const other: usize = 0x20020000;
const receiver: usize = 0x20030000;
const record: usize = 0x20040000;
const table: usize = 0x20050000;
var hop: Hop = undefined;
var entity: Query = undefined;
var enabled_hook: Enabled = undefined;
var selection: Selection = undefined;
var local_body: types.State = std.mem.zeroes(types.State);
var valid = true;
var proof = true;
var body_proof = true;
var mode: u32 = 0;
var native_calls: u32 = 0;
var input_calls: u32 = 0;
var applies: u32 = 0;
var depth: u32 = 0;
var selection_calls: u32 = 0;
var fault: c_int = 0;
var inputs: [32]p.SyncPhysicsChoice = std.mem.zeroes([32]p.SyncPhysicsChoice);
var entity_result: u32 = 0;
var enabled_result: u32 = 0;
var flags_result: u32 = 0;
var allocations: u32 = 0;
extern "kernel32" fn HeapAlloc(usize, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn HeapFree(usize, u32, usize) callconv(.winapi) c_int;
extern "kernel32" fn SetEnvironmentVariableA([*:0]const u8, [*:0]const u8) callconv(.winapi) c_int;
pub const heap_test_api = struct {
    pub fn HeapAlloc(heap: usize, flags: u32, size: usize) callconv(.winapi) usize {
        const address = allocate(heap, flags, size);
        return address;
    }
    pub fn HeapFree(heap: usize, flags: u32, address: usize) callconv(.winapi) c_int {
        return free(heap, flags, address);
    }
};
fn allocate(heap: usize, flags: u32, size: usize) usize {
    const address = HeapAlloc(heap, flags, size);
    if (address != 0) allocations += 1;
    return address;
}
fn free(heap: usize, flags: u32, address: usize) c_int {
    const result = HeapFree(heap, flags, address);
    if (result != 0) {
        check(@src(), allocations != 0);
        allocations -= 1;
    }
    return result;
}
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn bytes(address: usize, source: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(address))[0..source.len], source);
}
fn hasBodies() bool {
    return mode == 7 or mode == 8 or mode == 9 or mode == 15 or mode == 19 or mode == 20 or mode == 21;
}
export fn coherent_frame_get(token: *Token, phase: u32) c_int {
    check(@src(), phase == 4);
    token.* = std.mem.zeroes(Token);
    token.epoch = 100 + mode;
    token.sequence = 44;
    token.release = 200 + mode;
    return @intFromBool(mode != 1);
}
export fn coherent_frame_valid(_: *const Token, phase: u32) c_int {
    check(@src(), phase == 4);
    return @intFromBool(valid);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn native_spellit_source_resolve(g: usize, out: *types.Source) c_int {
    out.* = std.mem.zeroes(types.Source);
    out.gizmo = g;
    out.key = .{ .name = .{ 1, 2, 3, 4 }, .gizmo_class = 0x8480ac, .gizmo_ordinal = 3 };
    out.piece_count = 1;
    out.piece_head = piece;
    out.piece_tail = piece;
    return @intFromBool(g == gizmo and mode != 2);
}
export fn native_spellit_source_revalidate(_: *const types.Source) c_int {
    return @intFromBool(proof);
}
export fn native_spellit_piece_resolve(_: *const types.Source, value: usize, out: *types.Piece) c_int {
    if (value != piece) return 0;
    out.* = std.mem.zeroes(types.Piece);
    out.piece = value;
    out.receiver = receiver;
    out.live_record = record;
    out.key = .{ .resource = .{ 5, 6, 7, 8 }, .poi_name = .{ 9, 10, 11, 12 }, .poi_ordinal = 3, .poi_count = 4, .receiver_class = 0x820f64, .piece_ordinal = 8 };
    return 1;
}
export fn native_spellit_piece_revalidate(_: *const types.Source, _: *const types.Piece) c_int {
    return @intFromBool(proof);
}
export fn native_spellit_selection_snapshot(_: *const types.Source, count: *u32, key: *[4]u32) c_int {
    count.* = 1;
    key.* = .{ if (mode == 12 and input_calls != 0 and inputs[input_calls - 1].kind == p.SYNC_PHYSICS_SPELLIT_SELECTION) @as(u32, 99) else 1, 2, 3, 4 };
    return @intFromBool(proof);
}
export fn native_spellit_body_resolve(_: *const types.Source, value: usize, out: *types.Body) c_int {
    out.* = std.mem.zeroes(types.Body);
    out.piece = value;
    out.body_class = 0x869eac;
    out.piece_ordinal = 8;
    out.key[0] = 31;
    out.dynamics = if (hasBodies()) @intFromPtr(&local_body) else 0;
    return @intFromBool(hasBodies());
}
export fn native_spellit_body_matches(_: *const types.Source, _: *const types.Body) c_int {
    return @intFromBool(body_proof);
}
export fn native_spellit_body_read(_: *const types.Source, _: *const types.Body, out: *types.State) c_int {
    out.* = local_body;
    return @intFromBool(body_proof);
}
export fn native_spellit_body_apply(_: *const types.Source, _: *const types.Body, value: *const types.State, guard: types.Live, context: usize) c_int {
    check(@src(), guard(context) != 0);
    applies += 1;
    if (mode == 15) win.RaiseException(0xe1459876, 0, 0, null);
    local_body = value.*;
    return @intFromBool(body_proof);
}
export fn physics_world_input(choice: *p.SyncPhysicsChoice, _: *const Token) c_int {
    check(@src(), input_calls < 32 and @import("physics_validation.zig").valid(choice));
    inputs[input_calls] = choice.*;
    input_calls += 1;
    switch (choice.kind) {
        p.SYNC_PHYSICS_SPELLIT_STEP => {
            const value = &choice.payload.spellit_step;
            value.engine_seed = 101;
            value.game_seed = 103;
            value.delta = 0.025;
            value.timer = 0.25;
            switch (mode) {
                3 => return -1,
                4 => {
                    value.gizmo_ordinal += 1;
                },
                5 => put(0xea178c, 777),
                6 => {
                    valid = false;
                },
                else => {},
            }
        },
        p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION => {
            if (mode == 20 and choice.kind == p.SYNC_PHYSICS_SPELLIT_BODY_MOTION) {
                check(@src(), @as(u32, @bitCast(choice.payload.spellit_body.values[7])) == 0 and @as(u32, @bitCast(choice.payload.spellit_body.values[11])) == 0);
            }
            choice.payload.spellit_body.values[0] = 19;
            if (mode == 8) choice.payload.spellit_body.values[0] = std.math.nan(f32);
            if (mode == 9) body_proof = false;
        },
        p.SYNC_PHYSICS_SPELLIT_POSE => {
            choice.payload.spellit_pose.position[0] = 13;
            choice.payload.spellit_pose.last_time = 17;
            if (mode == 11) put(gizmo + 0x21c, other);
        },
        p.SYNC_PHYSICS_SPELLIT_SELECTION => {
            choice.payload.spellit_selection.engine_seed = 107;
        },
        else => {
            choice.payload.world.value = 0;
            if (mode == 10 and choice.kind == p.SYNC_PHYSICS_SPELLIT_ENTITY) return -1;
        },
    }
    win.SetLastError(999);
    return 1;
}
fn nativeEntity(target: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), target == record);
    if (mode == 17) put(gizmo + 0x21c, other);
    if (mode == 18 and depth == 0) {
        depth += 1;
        hop(gizmo, 0x3ccccccd);
        depth -= 1;
    }
    win.SetLastError(321);
    return 1;
}
fn nativeEnabled(target: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), target == receiver);
    win.SetLastError(321);
    return 1;
}
fn nativeSelection(target: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    check(@src(), target == gizmo);
    selection_calls += 1;
    return piece;
}
fn nativeHop(target: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), target == gizmo);
    native_calls += 1;
    if (mode != 1) check(@src(), delta == 0x3ccccccd and win.load(u32, 0xea178c) == 101 and win.load(u16, 0xe637b4) == 103);
    if (mode == 16) win.RaiseException(0xe1459876, 0, 0, null);
    entity_result = entity(record);
    enabled_result = enabled_hook(receiver, table);
    flags_result = input.native_spellit_receiver_flags(if (mode == 14) receiver + 4 else receiver, 0x812d7a);
    input.native_spellit_pose_input(gizmo);
    _ = selection(gizmo);
    win.SetLastError(321);
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn setup() void {
    valid = true;
    proof = true;
    body_proof = true;
    native_calls = 0;
    input_calls = 0;
    applies = 0;
    depth = 0;
    selection_calls = 0;
    fault = 0;
    entity_result = 0;
    enabled_result = 0;
    flags_result = 0;
    @memset(std.mem.asBytes(&inputs), 0);
    @memset(@as([*]u8, @ptrFromInt(gizmo))[0..0x1000], 0);
    @memset(@as([*]u8, @ptrFromInt(piece))[0..0x1000], 0);
    put(gizmo + 0x21c, piece);
    win.store(f32, gizmo + 0x218, 0.5);
    win.store(f32, piece + 0xd0, 3);
    win.store(f32, piece + 0xf4, 5);
    win.store(u8, receiver + 0x183, 4);
    put(table + 0x1c, @intFromPtr(&nativeEnabled));
    put(0xfb4b6c, 31);
    put(0xea178c, 71);
    win.store(u16, 0xe637b4, 73);
    local_body = std.mem.zeroes(types.State);
    local_body.basis[0] = 1;
    if (mode == 20) {
        local_body.linear[3] = @bitCast(@as(u32, 0xffffffff));
        local_body.angular[3] = @bitCast(@as(u32, 0x7fc12345));
    }
    if (mode == 21) local_body.linear[0] = std.math.nan(f32);
}
const Snapshot = extern struct {
    native_calls: u32,
    input_calls: u32,
    applies: u32,
    selections: u32,
    err: u32,
    engine_seed: u32,
    game_seed: u16,
    fault: c_int,
    exception: c_int,
    entity: u32,
    enabled: u32,
    flags: u32,
    debug: [4]u32,
    failure: [12]u32,
    correction: [12]u32,
    body_debug: [4]u32,
    body_correction: [8]u32,
    completion: [8]u32,
    trace_count: u32,
    trace: [40]u32,
    timer: f32,
    position: [3]f32,
    last_time: f32,
    body: types.State,
    inputs: [32]p.SyncPhysicsChoice,
};
fn invoke(_: usize) callconv(.c) c_int {
    hop(gizmo, 0x3d4ccccd);
    return 0;
}
fn run(out: *Snapshot) void {
    setup();
    state.clonewars_spellit_hop_debug = @splat(0);
    state.clonewars_spellit_hop_failure = @splat(0);
    state.clonewars_spellit_hop_correction = @splat(0);
    bodies.clonewars_spellit_body_debug = @splat(0);
    bodies.clonewars_spellit_body_correction = @splat(0);
    state.clonewars_spellit_completion_debug = @splat(0);
    state.clonewars_spellit_native_count = 0;
    @memset(std.mem.asBytes(&state.clonewars_spellit_native_batch), 0);
    const mx: u32 = 0x1f80;
    asm volatile ("fninit; ldmxcsr (%[mx])"
        :
        : [mx] "r" (&mx),
        : .{ .memory = true });
    win.SetLastError(1234);
    @memset(std.mem.asBytes(out), 0);
    var result = support.exceptionResult(0, invoke);
    check(@src(), result.code == 0 or result.code == 0xe1459876);
    if (mode == 19) {
        result = support.exceptionResult(0, invoke);
        check(@src(), result.code == 0 or result.code == 0xe1459876);
    }
    out.exception = @intFromBool(result.code != 0);
    out.err = result.last_error;
    out.native_calls = native_calls;
    out.input_calls = input_calls;
    out.applies = applies;
    out.selections = selection_calls;
    out.fault = fault;
    out.entity = entity_result;
    out.enabled = enabled_result;
    out.flags = flags_result;
    out.engine_seed = win.load(u32, 0xea178c);
    out.game_seed = win.load(u16, 0xe637b4);
    out.timer = win.load(f32, gizmo + 0x218);
    out.last_time = win.load(f32, piece + 0xf4);
    out.position = win.load([3]f32, piece + 0xd0);
    out.body = local_body;
    out.inputs = inputs;
    out.trace_count = state.clonewars_spellit_native_count;
    out.trace = state.clonewars_spellit_native_batch[0];
    out.debug = state.clonewars_spellit_hop_debug;
    out.failure = state.clonewars_spellit_hop_failure;
    out.correction = state.clonewars_spellit_hop_correction;
    out.body_debug = bodies.clonewars_spellit_body_debug;
    out.body_correction = bodies.clonewars_spellit_body_correction;
    out.completion = state.clonewars_spellit_completion_debug;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 3336 and @intFromPtr(&image) < 0x7ab040 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ gizmo, piece, other, receiver, record, table }) |address| check(@src(), win.VirtualAlloc(address, 0x1000, 0x3000, 4) == address);
    defer for ([_]usize{ gizmo, piece, other, receiver, record, table }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    var old: u32 = 0;
    for ([_]usize{ 0x7a0000, 0x7d0000, 0x810000, 0x840000, 0x860000, 0xe60000, 0xea0000, 0xfb0000 }) |address| check(@src(), win.VirtualProtect(address, 0x10000, 0x40, &old) != 0);
    check(@src(), SetEnvironmentVariableA("CLONEWARS_SPELLIT_SOURCE_TRACE", "1") != 0);
    jump(0x840660, @intFromPtr(&nativeHop));
    jump(0x7ab040, @intFromPtr(&nativeEntity));
    jump(0x7da280, @intFromPtr(&nativeSelection));
    const sites = [_]usize{ 0x861019, 0x8407cf, 0x840856, 0x812d87, 0x812dfd, 0x812d7a, 0x812df0, 0x8406b2, 0x8406a7, 0x840790, 0x840b93 };
    const prefixes = [_][]const u8{ "\xe8\x42\xf6\xfd\xff", "\xe8\x6c\xa8\xf6\xff", "\x8b\x42\x1c\xff\xd0", "\x8b\x42\x1c\xff\xd0", "\x8b\x42\x1c\xff\xd0", "\xf6\x81\x83\x01\x00\x00\x04", "\xf6\x81\x83\x01\x00\x00\x04", "\x8b\x8b\x1c\x02\x00\x00", "\xe8\xd4\x9b\xf9\xff", "\xe8\xeb\x9a\xf9\xff", "\xe8\xe8\x96\xf9\xff" };
    for (sites, prefixes) |site, prefix| {
        bytes(site, prefix);
        win.store(u8, site + prefix.len, 0xc3);
    }
    bytes(0x861015, &.{ 0xff, 0x74, 0x24, 4 });
    bytes(0x86101e, &.{ 0xc2, 4, 0 });
    for ([_]usize{ 0x810000, 0x840000, 0x860000 }) |address| check(@src(), win.VirtualProtect(address, 0x10000, 0x20, &old) != 0);
    check(@src(), input.spellit_input_install() != 0);
    var region: win.MemoryInfo = undefined;
    check(@src(), win.VirtualQuery(0x812d87, &region, @sizeOf(win.MemoryInfo)) != 0 and region.protection == 0x20);
    hop = @ptrFromInt(0x861015);
    entity = @ptrFromInt(0x8407cf);
    enabled_hook = @ptrFromInt(0x840856);
    selection = @ptrFromInt(0x8406a7);
    const expected = [_]u32{ 960512901, 4004139605, 133727072, 1018074389, 1122562252, 2772049971, 3004608908, 842667103, 886650404, 850374962, 3602637888, 2719495173, 2776544613, 697266877, 2491731303, 1548176922, 413907095, 1862351190, 3213332461, 4150227436 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        var actual: Snapshot = undefined;
        run(&actual);
        check(@src(), allocations <= 2);
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("spellit input mode={d} hash={d} expected={d} tracefx={x}\n", .{ mode, checksum, hash, actual.trace[39] });
        check(@src(), checksum == hash);
    }
    var actual: Snapshot = undefined;
    mode = 20;
    run(&actual);
    check(@src(), actual.fault == 0 and actual.applies == 1 and actual.native_calls == 1 and actual.exception == 0);
    check(@src(), actual.body.basis[0] == 19 and actual.body.position[0] == 19 and actual.err == 321);
    check(@src(), @as(u32, @bitCast(actual.body.linear[3])) == 0xffffffff and @as(u32, @bitCast(actual.body.angular[3])) == 0x7fc12345);
    mode = 21;
    run(&actual);
    check(@src(), actual.fault == 15 and actual.applies == 0 and actual.native_calls == 0 and actual.failure[2] == 20);
}
