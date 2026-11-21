const std = @import("std");
const input = @import("rts_generator_input.zig");
const sources = @import("rts_sources.zig");
const physics = @import("physics_validation.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const f = @import("rts_input_fixture.zig");
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var object: [0x2a8]u8 = @splat(0);
var team: [0x10d4]u8 = @splat(0);
var descriptor: [0x34]u8 = @splat(0);
var resource: [0x10]u8 = @splat(0);
var world: [4]u8 = @splat(0);
var engine: [0xe10]u8 = @splat(0);
var mode: u32 = 0;
var calls: u32 = 0;
var original_calls: u32 = 0;
export fn physics_world_input(choice: *p.SyncPhysicsChoice, _: *const Token) c_int {
    calls += 1;
    check(@src(), physics.valid(choice));
    const value = &choice.payload.rts_generator;
    value.delta = 0.017;
    value.elapsed = 0.25;
    value.countdown = -0.1;
    value.phase_time = 2;
    value.previous_state = 4;
    value.rng_game = 123;
    value.rng_engine = 456;
    value.rng_effects = 789;
    value.timer_delta = 0.023;
    switch (mode) {
        1 => value.index += 1,
        2 => f.alive = false,
        3 => put(&resource, 0xc, 0),
        4 => value.delta = std.math.nan(f32),
        5 => value.state += 1,
        else => {},
    }
    win.SetLastError(999);
    return if (mode == 6) -1 else 1;
}
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn word(base: anytype, offset: usize) u32 {
    return win.load(u32, @intFromPtr(base) + offset);
}
fn original(value: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    original_calls += 1;
    check(@src(), value == @intFromPtr(&object) and @as(f32, @bitCast(delta)) == 0.017);
    check(@src(), word(&object, 0x264) == 4 and word(&object, 0x268) == 4);
    const values = win.load([3]f32, @intFromPtr(&object) + 0x26c);
    check(@src(), values[0] == 0.25 and values[1] == -0.1 and values[2] == 2);
    check(@src(), win.load(u32, 0xe637b4) == 123 and win.load(u32, 0xea178c) == 456 and win.load(u32, 0xe5f498) == 789);
    check(@src(), win.load(f32, @intFromPtr(&engine) + 0xe0c) == 0.023 and win.GetLastError() == 123);
    win.SetLastError(321);
}
fn inactiveOriginal(value: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    original_calls += 1;
    check(@src(), value == @intFromPtr(&object) and delta == 0x3dcccccd and win.GetLastError() == 123);
    check(@src(), word(&object, 0x250) == 0xffffffff and word(&object, 0x264) == 0);
    win.SetLastError(321);
}
pub fn main() void {
    check(@src(), @intFromPtr(&native_image) < 0xfb0000 and @intFromPtr(&native_image) + native_image.len > 0xfc0000);
    win.store(u32, 0xfb4b6c, 100);
    win.store(usize, 0xfb4a20, @intFromPtr(&world));
    win.store(usize, 0xfb0afc, @intFromPtr(&engine));
    put(&object, 0, 0xaed18c);
    put(&object, 0x28, @intFromPtr(&team));
    put(&object, 0x250, 1);
    put(&object, 0x254, 1);
    put(&team, 0, 0xaef0fc);
    put(&team, 0x1c, @intFromPtr(&descriptor));
    put(&team, 0x10d0, @intFromPtr(&resource));
    put(&descriptor, 0x30, 0);
    for (0..7) |index| {
        mode = @intCast(index);
        f.alive = true;
        put(&resource, 0xc, @intFromPtr(&world));
        put(&object, 0x264, 4);
        put(&object, 0x268, 3);
        @memset(object[0x26c..][0..12], 0);
        win.store(f32, @intFromPtr(&engine) + 0xe0c, 0.1);
        const before = original_calls;
        win.SetLastError(123);
        input.rts_generator_input_update(@intFromPtr(&object), 0x3dcccccd, original);
        check(@src(), original_calls == before + @intFromBool(mode == 0) and win.GetLastError() == (if (mode == 0) @as(u32, 321) else 123));
        if (mode != 0) check(@src(), word(&object, 0x268) == 3 and word(&object, 0x26c) == 0 and word(&object, 0x270) == 0);
    }
    f.alive = true;
    put(&resource, 0xc, @intFromPtr(&world));
    var source: sources.Generator = undefined;
    check(@src(), sources.native_rts_generator_source(@intFromPtr(&object), &source) != 0);
    put(&object, 0x250, 2);
    check(@src(), sources.native_rts_generator_source_live(&source) == 0);
    put(&object, 0x250, 1);
    put(&object, 0x254, 2);
    check(@src(), sources.native_rts_generator_source(@intFromPtr(&object), &source) == 0);
    put(&object, 0x254, 1);
    put(&descriptor, 0x30, p.SYNC_MAX_RTS_TEAMS);
    check(@src(), sources.native_rts_generator_source(@intFromPtr(&object), &source) == 0);
    put(&descriptor, 0x30, 0);
    put(&object, 0x250, 0xffffffff);
    put(&object, 0x264, 0);
    put(&object, 0x268, 0);
    check(@src(), sources.inactiveGenerator(@intFromPtr(&object)));
    const before = original_calls;
    const gate_calls = calls;
    win.SetLastError(123);
    input.rts_generator_input_update(@intFromPtr(&object), 0x3dcccccd, inactiveOriginal);
    check(@src(), original_calls == before + 1 and calls == gate_calls and win.GetLastError() == 321);
    check(@src(), input.clonewars_rts_generator_input_debug[7] == 1);
    for ([_]usize{ 0, 0x250, 0x264, 0x268, 0x224 }, [_]u32{ 0xaed18d, 0xfffffffe, 1, 1, 1 }) |offset, invalid| {
        const saved = word(&object, offset);
        put(&object, offset, invalid);
        check(@src(), !sources.inactiveGenerator(@intFromPtr(&object)));
        win.SetLastError(123);
        input.rts_generator_input_update(@intFromPtr(&object), 0x3dcccccd, inactiveOriginal);
        check(@src(), original_calls == before + 1 and calls == gate_calls and win.GetLastError() == 123);
        put(&object, offset, saved);
    }
    var choice = std.mem.zeroes(p.SyncPhysicsChoice);
    choice.kind = p.SYNC_PHYSICS_RTS_GENERATOR;
    choice.site = 0x547d30;
    choice.payload.rts_generator.object_class = 0xaed18c;
    choice.payload.rts_generator.state = 0xffffffff;
    choice.payload.rts_generator.previous_state = 0xffffffff;
    check(@src(), physics.valid(&choice));
    var other = choice;
    other.payload.rts_generator.previous_state = 0;
    other.payload.rts_generator.delta = 0.1;
    check(@src(), physics.sameSource(&choice, &other));
    other.payload.rts_generator.state = 0;
    check(@src(), !physics.sameSource(&choice, &other));
    other = choice;
    other.payload.rts_generator.reserved[4] = 1;
    check(@src(), !physics.valid(&other));
}
