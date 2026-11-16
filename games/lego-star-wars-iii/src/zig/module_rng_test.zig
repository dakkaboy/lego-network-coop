const std = @import("std");
const m = @import("module_rng.zig");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var object: usize = 0;
var world: usize = 0;
var container: usize = 0;
var registry: usize = 0;
var handle: usize = 0;
var bound = true;
var valid = true;
var mode: u32 = 0;
var native_calls: u32 = 0;
var input_calls: u32 = 0;
var fault: i32 = 0;
var captured = std.mem.zeroes(p.SyncPhysicsChoice);
const Update = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
var update: Update = undefined;
export fn coherent_frame_get(token: *Token, phases: u32) c_int {
    check(@src(), phases == 4);
    token.* = std.mem.zeroes(Token);
    token.epoch = 7;
    token.sequence = 8;
    return @intFromBool(bound);
}
export fn coherent_frame_valid(_: *const Token, phases: u32) c_int {
    check(@src(), phases == 4);
    return @intFromBool(valid);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn physics_module_input(input: *p.SyncPhysicsChoice, _: *const Token) c_int {
    captured = input.*;
    input_calls += 1;
    input.payload.module.value += 100;
    if (mode == 7) return 0;
    if (mode == 8) put(0xfb4b6c, 42);
    if (mode == 9) win.store(u8, object + 0x14, 'X');
    if (mode == 10) input.payload.module.module_generation += 1;
    if (mode == 11) put(0xea178c, 999);
    if (mode == 15) valid = false;
    win.SetLastError(777);
    return 1;
}
export fn module_native_update(self: usize) void {
    check(@src(), self == object);
    native_calls += 1;
    if (mode == 12) win.RaiseException(0xe1459876, 0, 0, null);
    put(0xea178c, win.load(u32, 0xea178c) + 1);
    win.SetLastError(321);
}
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn setup(jam: bool) void {
    valid = true;
    bound = mode != 1;
    native_calls = 0;
    input_calls = 0;
    fault = 0;
    captured = std.mem.zeroes(p.SyncPhysicsChoice);
    @memset(@as([*]u8, @ptrFromInt(object))[0..0x1000], 0);
    @memset(@as([*]u8, @ptrFromInt(registry))[0..0x1000], 0);
    put(0xfb4b6c, 31);
    put(0xea178c, 71);
    put(0xfb4a20, world);
    put(0xe906b0, registry);
    put(world + 0x22e4, container);
    put(world + 0x400, handle);
    put(container + 0xc, world);
    const record = registry + 8;
    put(object, if (jam) 0xae36e4 else 0xae6b3c);
    put(object + 4, 13);
    put(object + 8, 9);
    put(object + 0x68, record);
    put(object + 0x6c, 11);
    put(record, 9);
    put(record + 4, 11);
    put(record + 8, object);
    put(record + 12, 4);
    if (jam) {
        put(object + 0xac, 5);
        win.store(i16, object + 0xa4, 4);
        win.store(f32, object + 0x98, 0.1);
        win.store(f32, object + 0x9c, 0.2);
        win.store(f32, object + 0xa0, 0.4);
    } else {
        put(object + 0x10, 0xae2df0);
        win.store(u8, object + 0x3c9, 3);
        win.store(u8, object + 0x3ca, 1);
        win.store(u8, object + 0x3c8, 1);
        win.store(u8, object + 0x3d0, 2);
        for (0..3) |j| put(object + 0x98 + j * 0x54, if (j == 2) 0xae2d50 else 0xae2d30);
    }
    if (mode == 2) put(object, 1);
    if (mode == 3) win.store(u8, object + 0x3ca, 4);
    if (mode == 4) put(object + 0x3d4, 0x7fc00001);
    if (mode == 5) win.store(u8, object + 0x3c8, 4);
    if (mode == 6) {
        @memcpy(@as([*]u8, @ptrFromInt(registry + 28))[0..20], @as([*]const u8, @ptrFromInt(registry + 8))[0..20]);
        put(registry + 36, world);
    }
}
const Snapshot = extern struct { debug: [4]u32, failure: [12]u32, correction: [8]u32, jam_debug: [4]u32, jam_correction: [8]u32, seed: u32, clock: u32, called: u32, input_called: u32, error_code: u32, fault: i32, exception: i32, input: p.SyncPhysicsChoice };
fn invoke(_: usize) callconv(.c) c_int {
    update(object);
    return 0;
}
fn run(jam: bool) Snapshot {
    setup(jam);
    m.clonewars_module_rng_debug = @splat(0);
    m.clonewars_module_rng_failure = @splat(0);
    m.clonewars_module_rng_correction = @splat(0);
    m.clonewars_gun_jam_rng_debug = @splat(0);
    m.clonewars_gun_jam_rng_correction = @splat(0);
    win.SetLastError(1234);
    var out = std.mem.zeroes(Snapshot);
    if (jam) {
        m.gun_jam_rng_checkpoint(object, 2);
        out.error_code = win.GetLastError();
    } else {
        const result = support.exceptionResult(0, invoke);
        check(@src(), result.code == 0 or result.code == 0xe1459876);
        out.exception = @intFromBool(result.code != 0);
        out.error_code = result.last_error;
    }
    out.debug = m.clonewars_module_rng_debug;
    out.failure = m.clonewars_module_rng_failure;
    out.correction = m.clonewars_module_rng_correction;
    out.jam_debug = m.clonewars_gun_jam_rng_debug;
    out.jam_correction = m.clonewars_gun_jam_rng_correction;
    out.seed = win.load(u32, 0xea178c);
    out.clock = win.load(u32, 0xfb4b6c);
    out.called = native_calls;
    out.input_called = input_calls;
    out.fault = fault;
    out.input = captured;
    return out;
}
fn expectSnapshot(jam: bool, hash: u32) void {
    var actual = run(jam);
    if (mode == 0) check(@src(), actual.seed == (if (jam) @as(u32, 171) else 172) and actual.error_code == (if (jam) @as(u32, 1234) else 321));
    if (actual.failure[4] != 0) {
        check(@src(), actual.failure[4] == object);
        actual.failure[4] = 0x1004;
    }
    var result: u32 = 2166136261;
    for (std.mem.asBytes(&actual)) |byte| result = (result ^ byte) *% 16777619;
    if (result != hash) std.debug.print("module_rng jam={any} mode={d} hash={d} expected={d} error={d}\n", .{ jam, mode, result, hash, actual.error_code });
    check(@src(), result == hash);
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 260 and @intFromPtr(&native_image) < 0x4acb53 and @intFromPtr(&native_image) + native_image.len > 0xfb4b78);
    for ([_]*usize{ &object, &world, &container, &registry, &handle }, 0..) |out, index| {
        out.* = win.VirtualAlloc(0, if (index == 1) 0x3000 else 0x1000, 0x3000, 4);
        check(@src(), out.* != 0);
    }
    defer for ([_]usize{ object, world, container, registry, handle }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(0x4da6d0, 64, 0x40, &old) != 0);
    const prefix = "\x51\xd9\x05\x74\x4b\xfb\x00\x53\x56\xd9\x5c\x24\x08";
    @memcpy(@as([*]u8, @ptrFromInt(0x4da6d0))[0..prefix.len], prefix);
    win.store(f32, 0xfb4b74, 0.016);
    const call = "\x51\xe8\x00\x00\x00\x00\x83\xc4\x04\x5e\x5b\x59\xc3";
    @memcpy(@as([*]u8, @ptrFromInt(0x4da6dd))[0..call.len], call);
    put(0x4da6df, @intFromPtr(&module_native_update) -% 0x4da6e3);
    put(0xae6b64, 0x4da6d0);
    check(@src(), win.VirtualProtect(0x4acb53, 5, 0x40, &old) != 0);
    @as(*[5]u8, @ptrFromInt(0x4acb53)).* = .{ 0xe8, 0xa8, 0x65, 0x0c, 0 };
    check(@src(), m.module_rng_input_install() != 0);
    update = @ptrFromInt(win.load(usize, 0xae6b64));
    for ([_]u32{ 1035606931, 1726789256, 2939227727, 937778230, 2632572851, 1300648630, 3609232752, 3244550664, 2808598604, 598676749, 598676749, 1026863212, 2458770861 }, 0..) |hash, index| {
        mode = @intCast(index);
        expectSnapshot(false, hash);
    }
    for ([_]u32{ 0, 1, 2, 6, 7, 10, 15 }, [_]u32{ 1551171016, 1568263299, 1146643685, 1146643685, 1816115102, 1816115102, 1816115102 }) |value, hash| {
        mode = value;
        expectSnapshot(true, hash);
    }
}
comptime {
    _ = @import("lexical_seh.zig");
}
