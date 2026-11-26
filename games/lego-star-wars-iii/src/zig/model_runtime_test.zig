const std = @import("std");
const p = @import("protocol.zig");
const s = @import("model_state.zig");
const t = @import("model_types.zig");
const input = @import("model_input.zig");
const request = @import("model_request.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("context.zig");
    _ = @import("model.zig");
    _ = @import("model_producer_bridge.zig");
    asm (@import("seh_finally.zig").code("model_producer_c", "model_producer_enter", "model_producer_inner", "model_producer_leave"));
}
extern fn producer_hook(usize) void;
const actor: usize = 0x20000000;
const controller: usize = 0x20010000;
const provider: usize = 0x20020000;
const model_object: usize = 0x20030000;
const resource: usize = 0x20040000;
const definition: usize = 0x20050000;
const base: usize = 0x20060000;
const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
var mode: u32 = 0;
var valid = true;
var fault: c_int = 0;
var cancel_bits: u32 = 0;
var generation: u32 = 19;
var updates: u32 = 0;
var describes: u32 = 0;
var resolves: u32 = 0;
var saved: [32]u32 = @splat(0);
var fx: [512]u8 align(16) = @splat(0);
var native_mode: u32 = 0;
var native_depth: u32 = 0;
var native_calls: u32 = 0;
export fn coherent_frame_valid(_: *const Token, _: u32) c_int {
    return @intFromBool(valid);
}
export fn coherent_frame_cancel_atomic(bits: u32) void {
    cancel_bits |= bits;
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn entities_update() void {
    updates += 1;
}
export fn entities_describe(out: *p.SyncActor, value: usize) void {
    check(@src(), value == actor);
    describes += 1;
    out.* = std.mem.zeroes(p.SyncActor);
    out.generation = generation;
    out.spawn_tag = 23;
    out.spawn_source = .{ .producer = 29, .serial = 31 };
    out.spawn_position[0] = 3;
}
export fn entities_slot(_: usize) c_int {
    return 7;
}
export fn entities_observed_generation(_: usize) u32 {
    return generation;
}
export fn entities_observed_identity(_: usize, slot: *u32, gen: *u32) c_int {
    slot.* = 7;
    gen.* = generation;
    return 1;
}
export fn entities_resolve_reference(reference: *const p.SyncActor) usize {
    resolves += 1;
    if ((mode == 22 and reference.slot == 8) or (mode == 23 and reference.slot == 7)) return actor + 1;
    return if (mode == 13) 0 else actor;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn setup() void {
    valid = true;
    fault = 0;
    cancel_bits = 0;
    updates = 0;
    describes = 0;
    resolves = 0;
    generation = 19;
    for ([_]usize{ actor, controller, provider, model_object, resource, definition, base }) |a| @memset(bytes(a, if (a == actor) 0x2000 else 0x1000), 0);
    saved = @splat(0);
    fx = @splat(0);
    @memset(std.mem.asBytes(frame), 0);
    put(actor + 8, model_object);
    put(actor + 0x50, 3);
    put(actor + 0x6cc, controller);
    win.store(u8, actor + 0x1dd, 255);
    put(actor + 0xf08, resource);
    put(actor + 0xc08, base);
    win.store(i16, actor + 0xdc0, 12);
    win.store(u8, actor + 0x138e, 2);
    win.store(u8, actor + 0x57, 1);
    win.store(f32, actor + 0xe28, 0.5);
    win.store(u16, actor + 0x76, 3);
    put(model_object + 0x34, provider);
    put(resource + 0x2c, definition);
    put(provider + 0xb0, 1);
    win.store(f32, definition + 0x2c, 1);
    win.store(f32, controller + 0x28, 0.25);
    win.store(f32, controller + 0x2c, 1);
    win.store(f32, controller + 0x38, 0.125);
    win.store(u16, controller + 0x26, 71);
    for ([_]usize{ 0xfb4940, 0xfb4944, 0xfc0e80, 0xfb32a8, 0xe63e14, 0xfbcb88 }) |a| put(a, 0);
    put(0xfb4b6c, 43);
    win.store(u16, @intFromPtr(&fx), 0x37f);
    put(@intFromPtr(&fx) + 24, 0x1f80);
    frame.epoch = 100 + mode;
    frame.sequence = 83;
    saved[2] = 0x123456;
    saved[4] = actor;
    saved[7] = provider;
    saved[8] = 0x246;
    saved[12] = provider;
    saved[16] = controller;
    saved[17] = 0x3f000000;
    saved[19] = 0x3f800000;
}
const Snapshot = extern struct {
    begin: c_int,
    finish: c_int,
    abort: c_int,
    cancelled: c_int,
    fault: c_int,
    cancel_bits: u32,
    updates: u32,
    describes: u32,
    resolves: u32,
    x: u32,
    z: u32,
    mode: u32,
    priority: u32,
    visibility: u32,
    cf4: u32,
    debug: [16]u32,
    failure: [16]u32,
    correction: [8]u32,
    visibility_debug: [4]u32,
    outcome: t.Outcome,
    projection_count: u32,
    projection: t.Projection,
    input: p.SyncModelInput,
    failed_host: p.SyncModelInput,
    failed_local: p.SyncModelInput,
    corrected_host: p.SyncModelInput,
    corrected_local: p.SyncModelInput,
    effective: p.SyncModelInput,
};
fn enter(b: *t.Bridge) void {
    @memset(std.mem.asBytes(b), 0);
    b.actor = actor;
    input.model_producer_enter(b);
}
fn source() void {
    request.request_mode_source_checkpoint(&saved, &fx);
}
fn consumers(out: *Snapshot) void {
    if (mode == 6) return;
    if (mode != 2 and mode != 3) _ = request.request_mode_cmp_checkpoint(&saved, &out.mode);
    saved[7] = win.load(u32, provider + 0xb0);
    if (mode != 7) _ = request.request_mode_mov_checkpoint(&saved, &out.mode);
    if (mode == 8) _ = request.request_mode_mov_checkpoint(&saved, &out.mode);
    _ = request.request_priority_checkpoint(&saved, &out.priority);
    if (mode == 41 and s.journal.host == 0) {
        var hidden: u32 = 0;
        check(@src(), request.request_hidden_model_checkpoint(&saved, &hidden) == 1 and hidden == 1);
    }
    saved[7] = model_object;
    _ = request.request_visibility_checkpoint(&saved, &out.visibility);
    if (mode != 9) request.request_mode_join_checkpoint(&saved, &fx);
}
fn tokenFor() Token {
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.cohort_nonce = 2;
    token.thread = win.GetCurrentThreadId();
    token.release = mode + 1;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    return token;
}
fn run() Snapshot {
    setup();
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    s.clonewars_model_input_debug = @splat(0);
    s.clonewars_model_input_failure = @splat(0);
    s.clonewars_model_input_first_correction = @splat(0);
    s.clonewars_model_visibility_debug = @splat(0);
    s.clonewars_model_input_first_outcome = std.mem.zeroes(t.Outcome);
    @memset(std.mem.asBytes(&s.clonewars_model_projection_records), 0);
    s.clonewars_model_projection_count = 0;
    s.clonewars_model_projection_enabled = 1;
    var token = tokenFor();
    var lease: t.Lease = undefined;
    check(@src(), input.model_input_bind_cohort(&token) != 0 and input.model_input_frame_lease_get(&lease) != 0);
    out.begin = input.model_input_begin(frame, 1);
    check(@src(), out.begin != 0);
    var b: t.Bridge = undefined;
    if (mode == 2 or mode == 3) {
        saved[17] = 0;
        saved[19] = if (mode == 3) 0x80000000 else 0;
    }
    if (mode == 4) put(actor + 0x50, 0x203);
    if (mode == 5) win.store(u8, actor + 0x138e, 0);
    if (mode >= 18) {
        frame.level = switch (mode) {
            20 => 63,
            24...28, 33...35, 39...43 => 73,
            29, 32, 37 => 71,
            31 => 74,
            36, 38 => 70,
            else => 64,
        };
        put(actor + 0x4c, 0x400);
        if (mode >= 24) win.store(i16, actor + 0xdc0, if (mode == 35 or mode == 37 or mode == 40 or mode == 42) 333 else if (mode < 28 or (mode >= 33 and mode <= 34) or mode == 43) 201 else 321);
        win.store(u16, actor + 0x2f4, switch (mode) {
            24, 27, 33 => 29,
            34, 38, 41 => 10,
            25 => 92,
            29 => 114,
            32 => 13,
            40 => 102,
            else => 0xffff,
        });
    }
    if (mode == 41) put(provider + 0xb0, 4);
    enter(&b);
    source();
    if (mode == 10) source();
    if (mode == 11) generation += 1;
    consumers(&out);
    input.model_producer_leave(&b, @intFromBool(mode == 12));
    out.input = frame.model_inputs[0];
    out.finish = input.model_input_finish();
    out.abort = input.model_input_abort_frame(&lease);
    if (mode >= 13) {
        token.release += 1;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        check(@src(), input.model_input_bind_cohort(&token) != 0 and input.model_input_frame_lease_get(&lease) != 0 and input.model_input_begin(frame, 0) != 0);
        saved[7] = provider;
        saved[17] = 0x3e800000;
        saved[19] = 0x3f000000;
        put(provider + 0xb0, 2);
        win.store(u16, actor + 0x76, 5);
        put(actor + 0xcf4, 0x3f000000);
        win.store(u8, model_object + 0x42, 1);
        if (mode == 14) put(actor + 0x4c, 0x400);
        if (mode == 41) {
            put(actor + 0x4c, 0);
            put(provider + 0xb0, 4);
        }
        if (mode == 15) put(0xfb4b6c, 44);
        if (mode == 16) frame.model_input_count = 0;
        if (mode >= 18) win.store(u16, actor + 0x2f4, switch (mode) {
            18, 27 => 1,
            19, 20, 33, 39 => 10,
            24, 25, 29, 40, 41 => 0xffff,
            28, 30, 31, 32, 35, 37 => 114,
            34 => 29,
            42 => 102,
            43 => 11,
            36, 38 => 22,
            else => 0x29,
        });
        enter(&b);
        source();
        consumers(&out);
        input.model_producer_leave(&b, 0);
        out.finish = input.model_input_finish();
        out.abort = input.model_input_abort_frame(&lease);
    }
    out.cancelled = input.model_input_cancelled();
    out.fault = fault;
    out.cancel_bits = cancel_bits;
    out.updates = updates;
    out.describes = describes;
    out.resolves = resolves;
    out.x = saved[17];
    out.z = saved[19];
    out.cf4 = win.load(u32, actor + 0xcf4);
    out.debug = s.clonewars_model_input_debug;
    out.failure = s.clonewars_model_input_failure;
    out.correction = s.clonewars_model_input_first_correction;
    out.visibility_debug = s.clonewars_model_visibility_debug;
    out.outcome = s.clonewars_model_input_first_outcome;
    out.projection_count = s.clonewars_model_projection_count;
    out.projection = s.clonewars_model_projection_records[0];
    out.failed_host = s.clonewars_model_input_failed_host;
    out.failed_local = s.clonewars_model_input_failed_local;
    out.corrected_host = s.clonewars_model_input_corrected_host;
    out.corrected_local = s.clonewars_model_input_corrected_local;
    out.effective = s.clonewars_model_input_effective;
    out.correction[6..8].* = .{ 0, 0 };
    out.outcome.qpc = .{ 0, 0 };
    out.projection.qpc = .{ 0, 0 };
    if (out.projection.thread != 0) {
        check(@src(), out.projection.thread == win.GetCurrentThreadId());
        out.projection.thread = 0;
    }
    return out;
}
fn droidModelInputOrder(level: i32, first_character: i16) void {
    mode = 22;
    setup();
    frame.level = level;
    win.store(i16, actor + 0xdc0, 321);
    var token = tokenFor();
    var lease: t.Lease = undefined;
    var bridge: t.Bridge = undefined;
    var output = std.mem.zeroes(Snapshot);
    check(@src(), input.model_input_bind_cohort(&token) != 0 and input.model_input_frame_lease_get(&lease) != 0 and input.model_input_begin(frame, 1) != 0);
    enter(&bridge);
    source();
    consumers(&output);
    input.model_producer_leave(&bridge, 0);
    check(@src(), input.model_input_finish() != 0 and input.model_input_abort_frame(&lease) != 0);
    frame.model_inputs[1] = frame.model_inputs[0];
    frame.model_inputs[0].slot = 8;
    frame.model_inputs[0].character = first_character;
    frame.model_input_count = 2;

    token.release += 1;
    check(@src(), input.model_input_bind_cohort(&token) != 0 and input.model_input_frame_lease_get(&lease) != 0 and input.model_input_begin(frame, 0) != 0);
    saved[7] = provider;
    enter(&bridge);
    source();
    check(@src(), s.scope.?.ordinal == 1 and s.scope.?.request.slot == 7 and s.journal.cursor == 0);
    consumers(&output);
    input.model_producer_leave(&bridge, 0);

    mode = 23;
    win.store(i16, actor + 0xdc0, first_character);
    saved[7] = provider;
    enter(&bridge);
    source();
    check(@src(), s.scope.?.ordinal == 0 and s.scope.?.request.slot == 8 and s.journal.cursor == 2);
    consumers(&output);
    input.model_producer_leave(&bridge, 0);
    check(@src(), input.model_input_finish() != 0 and input.model_input_abort_frame(&lease) != 0 and fault == 0);
}

fn nativeMotion(target: usize) callconv(.c) void {
    check(@src(), target == actor and win.GetLastError() == 1234);
    native_calls += 1;
    if (native_mode == 1) win.RaiseException(0xe1459876, 0, 0, null);
    if (native_mode == 3 and native_depth == 0) {
        native_depth += 1;
        producer_hook(actor);
        native_depth -= 1;
    }
    saved[7] = provider;
    source();
    if (native_mode == 2) win.RaiseException(0xe1459876, 0, 0, null);
    var output: Snapshot = undefined;
    @memset(std.mem.asBytes(&output), 0);
    consumers(&output);
    win.SetLastError(321);
}
fn invokeProducer(_: usize) callconv(.c) c_int {
    @as(*const fn (usize) callconv(.c) void, @ptrFromInt(0x9bf280))(actor);
    return 1;
}
fn protect(address: usize, size: usize, protection: u32) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, size, protection, &old) != 0);
}
fn installedBridge() void {
    const sites = [_]usize{ 0x9bf280, 0x9bf6aa, 0x9bf6d2, 0x9bf903, 0x9bfa25, 0x9bf91c, 0x9bf9e7, 0x9bf9b8 };
    const sizes = [_]usize{ 6, 6, 7, 6, 5, 5, 6, 5 };
    const prefixes = [_][7]u8{ .{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0, 0 }, .{ 0xd9, 0xc0, 0xd9, 0x44, 0x24, 0x20, 0 }, .{ 0x83, 0xb8, 0xb0, 0, 0, 0, 1 }, .{ 0x8b, 0x80, 0xb0, 0, 0, 0, 0 }, .{ 0x8b, 0x43, 8, 0x85, 0xc0, 0, 0 }, .{ 0x66, 0x83, 0x7b, 0x76, 0, 0, 0 }, .{ 0x80, 0x78, 0x42, 0, 0x75, 0x38, 0 }, .{ 0x85, 0x53, 0x4c, 0x75, 0x68, 0, 0 } };
    protect(0x9b0000, 0x10000, 0x40);
    check(@src(), input.model_input_install() == 0);
    for (sites, sizes, prefixes) |site, size, prefix| @memcpy(bytes(site, size), prefix[0..size]);
    @memcpy(bytes(0x9bf286, 4), &[_]u8{ 0x8b, 0xe5, 0x5d, 0xe9 });
    put(0x9bf28a, @intFromPtr(&nativeMotion) -% 0x9bf28e);
    protect(0x9b0000, 0x10000, 0x20);
    check(@src(), input.model_input_install() != 0 and input.model_input_ready() != 0 and input.model_input_install() != 0);
    var info: win.MemoryInfo = undefined;
    check(@src(), win.VirtualQuery(0x9bf280, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    mode = 0;
    for (0..8) |trial| for (0..4) |native_kind| {
        native_mode = @intCast(native_kind);
        setup();
        native_calls = 0;
        native_depth = 0;
        frame.epoch = @intCast(1000 + trial * 4 + native_mode);
        var token = tokenFor();
        token.cohort_nonce = 0;
        token.release = frame.epoch;
        var lease: t.Lease = undefined;
        check(@src(), input.model_input_bind_cohort(&token) != 0 and input.model_input_frame_lease_get(&lease) != 0 and input.model_input_begin(frame, 1) != 0);
        win.SetLastError(1234);
        const result = support.exceptionResult(0, invokeProducer);
        check(@src(), result.code == (if (native_mode == 1 or native_mode == 2) @as(u32, 0xe1459876) else 0));
        if (native_mode == 1 or native_mode == 2) {
            check(@src(), input.model_input_cancelled() != 0 and cancel_bits == 0x8000 and input.model_input_frame_lease_get(&lease) == 0 and input.model_input_finish() == 0);
        } else {
            check(@src(), result.last_error == 321 and frame.model_input_count == (if (native_mode == 3) @as(u32, 2) else 1) and native_calls == (if (native_mode == 3) @as(u32, 2) else 1));
            check(@src(), input.model_input_finish() != 0 and fault == 0 and input.model_input_abort_frame(&lease) != 0);
        }
    };
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 1940 and @intFromPtr(&image) < 0x9b0000 and @intFromPtr(&image) + image.len > 0xfc1000);
    for ([_]usize{ 0xe60000, 0xfb0000, 0xfc0000 }) |a| protect(a, 0x10000, 4);
    for (0..7) |i| {
        const a = actor + i * 0x10000;
        check(@src(), win.VirtualAlloc(a, if (i == 0) 0x2000 else 0x1000, 0x3000, 4) == a);
    }
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    defer {
        for (0..7) |i| check(@src(), win.VirtualFree(actor + i * 0x10000, 0, 0x8000) != 0);
        check(@src(), win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
    }
    const expected = [_]u32{ 1072922230, 2800891459, 4262244881, 3043744676, 4018126628, 3002743772, 3724998256, 776363728, 2672412612, 1172262318, 524348880, 2108500400, 704669909, 3226222591, 1697502798, 680197419, 478273277, 3623405538 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        const out = run();
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("model mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 0 or mode == 2 or mode == 3) check(@src(), out.finish != 0 and out.projection_count == 1);
        if (mode == 17) check(@src(), out.finish != 0 and out.correction[0] != 0 and out.outcome.valid != 0 and out.cf4 == 0);
    }
    for (18..22) |variant| {
        mode = @intCast(variant);
        const out = run();
        if (mode <= 19) {
            check(@src(), out.finish != 0 and out.fault == 0);
            check(@src(), win.load(u16, actor + 0x2f4) == if (mode == 18) @as(u16, 1) else 10);
        } else check(@src(), out.finish == 0 and out.fault == 20 and out.failure[7] == 9);
    }
    for (24..27) |variant| {
        mode = @intCast(variant);
        const out = run();
        if (mode < 26) {
            check(@src(), out.finish != 0 and out.fault == 0);
            check(@src(), win.load(u16, actor + 0x2f4) == 0xffff);
        } else check(@src(), out.finish == 0 and out.fault == 20 and out.failure[7] == 9);
    }
    mode = 27;
    const landing = run();
    check(@src(), landing.finish != 0 and landing.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 1 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 33;
    const projectile_landing = run();
    check(@src(), projectile_landing.finish != 0 and projectile_landing.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 10 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 34;
    const host_projectile_landing = run();
    check(@src(), host_projectile_landing.finish != 0 and host_projectile_landing.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 29 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 35;
    const lab_droid = run();
    check(@src(), lab_droid.finish != 0 and lab_droid.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 114 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 39;
    const lab_b1 = run();
    check(@src(), lab_b1.finish != 0 and lab_b1.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 10 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 40;
    const lab_b2 = run();
    check(@src(), lab_b2.finish != 0 and lab_b2.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 0xffff and win.load(u32, actor + 0x4c) == 0x400);
    mode = 42;
    const lab_b2_inverse = run();
    check(@src(), lab_b2_inverse.finish != 0 and lab_b2_inverse.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 102 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 43;
    const lab_vindi_look = run();
    check(@src(), lab_vindi_look.finish != 0 and lab_vindi_look.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 11 and win.load(u32, actor + 0x4c) == 0x400);
    mode = 41;
    const lab_hidden_b1 = run();
    check(@src(), lab_hidden_b1.finish != 0 and lab_hidden_b1.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 0xffff and win.load(u32, actor + 0x4c) == 0);
    for ([_]u32{ 36, 38 }) |swamp_mode| {
        mode = swamp_mode;
        const swamp_droid = run();
        check(@src(), swamp_droid.finish != 0 and swamp_droid.fault == 0);
        check(@src(), win.load(u16, actor + 0x2f4) == 22 and win.load(u32, actor + 0x4c) == 0x400);
    }
    mode = 37;
    const corridor_droid = run();
    check(@src(), corridor_droid.finish != 0 and corridor_droid.fault == 0);
    check(@src(), win.load(u16, actor + 0x2f4) == 114 and win.load(u32, actor + 0x4c) == 0x400);
    for (28..33) |variant| {
        mode = @intCast(variant);
        const droid = run();
        if (mode == 30) {
            check(@src(), droid.finish == 0 and droid.fault == 20 and droid.failure[7] == 9);
        } else {
            check(@src(), droid.finish != 0 and droid.fault == 0);
            check(@src(), win.load(u16, actor + 0x2f4) == if (mode == 29) @as(u16, 0xffff) else 114);
        }
    }
    droidModelInputOrder(29, 333);
    droidModelInputOrder(70, 333);
    droidModelInputOrder(70, 337);
    droidModelInputOrder(71, 321);
    installedBridge();
}
