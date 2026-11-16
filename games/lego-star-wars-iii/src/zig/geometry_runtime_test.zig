const std = @import("std");
const g = @import("geometry_state.zig");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const Lease = @import("cohort_types.zig").Lease;
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var frame: *p.SyncFrame = undefined;
var pool: usize = 0;
var token = std.mem.zeroes(Token);
var valid = true;
var mode: u32 = 0;
var describe_calls: u32 = 0;
var generation_calls: u32 = 0;
var physics_cancels: u32 = 0;
var fault: i32 = 0;
var actor_count: i32 = 3;
export fn coherent_frame_valid(value: *const Token, _: u32) c_int {
    return @intFromBool(valid and value.cohort_nonce == token.cohort_nonce);
}
export fn physics_input_install() c_int {
    return 1;
}
export fn physics_input_cancel() void {
    physics_cancels += 1;
}
export fn physics_input_begin(_: *p.SyncFrame, _: c_int) c_int {
    return @intFromBool(mode != 1);
}
export fn physics_input_finish() c_int {
    return @intFromBool(mode != 16);
}
export fn game_actor_count() c_int {
    return actor_count;
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn entities_update() void {
    if (mode == 2) valid = false;
}
export fn entities_describe(out: *p.SyncActor, actor: usize) void {
    describe_calls += 1;
    out.* = std.mem.zeroes(p.SyncActor);
    out.generation = if (mode == 3) 0 else 7;
    out.slot = @intCast((actor - pool) / 0x1440);
}
export fn entities_observed_generation(actor: usize) u32 {
    generation_calls += 1;
    if (mode == 13 and generation_calls == 4) return 8;
    return if (actor != 0) 7 else 0;
}
export fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    if (actor == 0) return 0;
    slot.* = @intCast((actor - pool) / 0x1440);
    generation.* = 7;
    return 1;
}
export fn entities_resolve_reference(owner: *const p.SyncActor) usize {
    return switch (mode) {
        7 => 0,
        8 => pool,
        9 => pool + 1,
        else => pool + owner.slot * 0x1440,
    };
}
fn setup() void {
    frame.* = std.mem.zeroes(p.SyncFrame);
    frame.epoch = 100 + mode;
    frame.sequence = 8;
    token = std.mem.zeroes(Token);
    token.frame = @intFromPtr(frame);
    token.epoch = frame.epoch;
    token.sequence = 8;
    token.cohort_nonce = 100 + mode * 2;
    token.thread = win.GetCurrentThreadId();
    valid = true;
    describe_calls = 0;
    generation_calls = 0;
    physics_cancels = 0;
    fault = 0;
    actor_count = 3;
    @memset(@as([*]u8, @ptrFromInt(pool))[0..0x4000], 0);
    win.store(usize, 0xfb2f60, pool);
    for (0..3) |slot| {
        const actor = pool + slot * 0x1440;
        win.store(u32, actor + 0x50, if (slot == 1) 0 else 3);
        win.store(f32, actor + 0x30, -1);
        win.store(f32, actor + 0x3c, 1);
        win.store(f32, actor + 0x1088, 1);
        win.store(f32, actor + 0x108c, 1);
    }
}
const Snapshot = extern struct { begin: i32, phase: i32, extra: i32, finish: i32, fault: i32, abort_result: i32, retired: i32, count: u32, calls: u32, debug: [20]u32, failure: [14]u32, describes: u32, generations: u32, cancels: u32, entries: [3]p.SyncCollider, bounds: [3][6]f32 };
fn run() Snapshot {
    setup();
    g.clonewars_geometry_debug = @splat(0);
    g.clonewars_geometry_failure = @splat(0);
    var out = std.mem.zeroes(Snapshot);
    var lease: Lease = undefined;
    check(@src(), g.geometry_bind_cohort(&token) != 0 and g.geometry_frame_lease_get(&lease) != 0);
    out.begin = g.geometry_begin(frame, 1);
    if (mode == 4) actor_count = 4097;
    if (mode == 5) win.store(f32, pool + 0x30, 2);
    out.phase = g.geometry_phase(0);
    out.extra = g.geometry_phase(1);
    out.finish = g.geometry_finish();
    check(@src(), g.geometry_abort_frame(&lease) != 0);
    if (mode >= 6 and mode < 16) {
        token.cohort_nonce += 1;
        check(@src(), g.geometry_bind_cohort(&token) != 0 and g.geometry_frame_lease_get(&lease) != 0);
        out.begin = g.geometry_begin(frame, 0);
        win.store(f32, pool + 0x30, -9);
        switch (mode) {
            6 => frame.geometry_calls = 0,
            10 => win.store(u32, pool + 0x1440 + 0x50, 3),
            11 => frame.geometry[0].generation = 0,
            12 => frame.geometry_count = 1,
            14 => frame.geometry[1].slot = 0,
            15 => valid = false,
            else => {},
        }
        out.phase = g.geometry_phase(0);
        out.extra = g.geometry_phase(1);
        out.finish = g.geometry_finish();
        out.abort_result = g.geometry_abort_frame(&lease);
        out.retired = g.geometry_bind_cohort(&token);
    }
    out.fault = fault;
    out.count = frame.geometry_count;
    out.calls = frame.geometry_calls;
    out.describes = describe_calls;
    out.generations = generation_calls;
    out.cancels = physics_cancels;
    out.debug = g.clonewars_geometry_debug;
    out.failure = g.clonewars_geometry_failure;
    out.entries = frame.geometry[0..3].*;
    for (&out.bounds, 0..) |*bounds, i| bounds.* = win.load([6]f32, pool + i * 0x1440 + 0x30);
    return out;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 508 and @intFromPtr(&native_image) < 0xfb2f60 and @intFromPtr(&native_image) + native_image.len > 0xfb2f60);
    frame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(p.SyncFrame), 0x3000, 4));
    pool = win.VirtualAlloc(0, 0x4000, 0x3000, 4);
    check(@src(), @intFromPtr(frame) != 0 and pool != 0);
    defer _ = win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    defer _ = win.VirtualFree(pool, 0, 0x8000);
    for ([_]u32{ 2916160532, 607463621, 2319531077, 3051068797, 2209066107, 2333197369, 3271225861, 1342961386, 3943227770, 1973346168, 1133932687, 3090466106, 1422242468, 1609804096, 297542803, 4194348809, 3295132740 }, 0..) |hash, index| {
        mode = @intCast(index);
        const actual = run();
        var result: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| result = (result ^ byte) *% 16777619;
        if (result != hash) std.debug.print("geometry_runtime mode={d} hash={d} expected={d}\n", .{ mode, result, hash });
        check(@src(), result == hash);
    }
}
comptime {
    _ = @import("geometry.zig");
}
