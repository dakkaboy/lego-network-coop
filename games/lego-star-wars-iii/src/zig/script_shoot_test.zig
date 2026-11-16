const std = @import("std");
const source = @import("script_shoot_source.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var world: [0x224]u8 = @splat(0);
var definition: [0x96]u8 = @splat(0);
var model_data: [0x50]u8 = @splat(0);
var brain: [0x1a0]u8 = @splat(0);
var state_data: [0xb0]u8 = @splat(0);
var native_frame_data: [8]usize = @splat(0);
var wrapper: [2]usize = @splat(0);
var classes: [4][4]u32 = std.mem.zeroes([4][4]u32);
var actors: usize = 0;
var arg0: [12]u8 = "TargetGizmo\x00".*;
var arg1: [12]u8 = "synthetic\xc3\xa9\x00".*;
var arg2: [12]u8 = "AvoidCamera\x00".*;
var arguments: [3]usize = @splat(0);
fn codeCaller() callconv(.c) void {}
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn setup() void {
    inline for (.{ &world, &definition, &model_data, &brain, &state_data }) |buffer| @memset(buffer, 0);
    @memset(@as([*]u8, @ptrFromInt(actors))[0..0x2880], 0);
    win.store(usize, 0xfb4a20, @intFromPtr(&world));
    win.store(usize, 0xfb2f60, actors);
    win.store(u32, 0xfb2e3c, 2);
    win.store(u32, 0xfb4b6c, 1627);
    put(&world, 0x220, @intFromPtr(&definition));
    win.store(u16, @intFromPtr(&definition) + 0x94, 7);
    win.store(usize, actors + 8, @intFromPtr(&model_data));
    put(&model_data, 0, @intFromPtr(&classes[0]));
    put(&model_data, 0x34, @intFromPtr(&brain));
    put(&brain, 0, @intFromPtr(&classes[1]));
    put(&brain, 0x198, 1);
    put(&state_data, 0, @intFromPtr(&classes[2]));
    win.store(u16, @intFromPtr(&state_data) + 0xa6, 1);
    model_data[0x42] = 1;
    wrapper = .{ 0, actors };
    arguments = .{ @intFromPtr(&arg0), @intFromPtr(&arg1), @intFromPtr(&arg2) };
    native_frame_data = .{ 0x11223344, @intFromPtr(&codeCaller), @intFromPtr(&world), @intFromPtr(&state_data), @intFromPtr(&wrapper), @intFromPtr(&arguments), 3, 0 };
}
fn resolved() source.Source {
    var out: source.Source = undefined;
    win.SetLastError(0xaabbccdd);
    check(@src(), source.native_script_shoot_source_resolve(actors, @intFromPtr(&state_data), @intFromPtr(&model_data), @intFromPtr(&native_frame_data), &out) == 1 and win.GetLastError() == 0xaabbccdd);
    return out;
}
fn engineTests() void {
    check(@src(), @sizeOf(source.Input) == 56 and @intFromPtr(&image) < 0xfb0000 and @intFromPtr(&image) + image.len > 0xfc0000);
    actors = win.VirtualAlloc(0, 0x3000, 0x3000, 4);
    check(@src(), actors != 0);
    defer _ = win.VirtualFree(actors, 0, 0x8000);
    setup();
    var s = resolved();
    check(@src(), s.actor_ordinal == 0 and s.input.argument_count == 3 and s.input.initialize == 0 and s.input.state_flags == 1);
    for (0..3000) |i| {
        arg1[0] = @intCast('a' + i % 26);
        const a = resolved();
        check(@src(), source.native_script_shoot_source_revalidate(&a) == 1);
        model_data[0x42] ^= 1;
        check(@src(), source.native_script_shoot_source_revalidate(&a) == 1);
        const b = resolved();
        check(@src(), std.mem.eql(u8, std.mem.asBytes(&a.input), std.mem.asBytes(&b.input)));
        arg1[0] ^= 1;
        check(@src(), source.native_script_shoot_source_revalidate(&a) == 0);
        arg1[0] ^= 1;
    }
    setup();
    s = resolved();
    const initial = s.input;
    arg0[0] = 'X';
    const changed = resolved();
    check(@src(), !std.mem.eql(u32, &initial.argument_hash, &changed.input.argument_hash) and source.native_script_shoot_source_revalidate(&s) == 0);
    arg0[0] = 'T';
    setup();
    s = resolved();
    native_frame_data[7] = 0xffffffff;
    const initialized = resolved();
    check(@src(), initialized.input.initialize == 1 and source.native_script_shoot_source_revalidate(&s) == 0);
    setup();
    put(&brain, 0x198, 2);
    s = resolved();
    check(@src(), s.input.brain_admission == 1 and s.brain_admission_raw == 2);
    put(&brain, 0x198, 3);
    check(@src(), source.native_script_shoot_source_revalidate(&s) == 0);
    for (0..15) |mutation| {
        setup();
        s = resolved();
        switch (mutation) {
            0 => {
                wrapper[1] += 0x1440;
            },
            1 => put(&model_data, 0x34, @intFromPtr(&state_data)),
            2 => win.store(usize, actors + 8, @intFromPtr(&state_data)),
            3 => put(&model_data, 0, @intFromPtr(&classes[3])),
            4 => put(&brain, 0, @intFromPtr(&classes[3])),
            5 => put(&state_data, 0, @intFromPtr(&classes[3])),
            6 => win.store(u16, @intFromPtr(&state_data) + 0xa6, 9),
            7 => put(&brain, 0x198, 0),
            8 => {
                native_frame_data[2] = 0;
            },
            9 => {
                native_frame_data[5] = 0;
            },
            10 => {
                native_frame_data[6] = 2;
            },
            11 => win.store(u32, 0xfb4b6c, 1628),
            12 => win.store(usize, 0xfb4a20, @intFromPtr(&definition)),
            13 => win.store(u32, 0xfb2e3c, 1),
            14 => put(&world, 0x220, @intFromPtr(&brain)),
            else => unreachable,
        }
        check(@src(), source.native_script_shoot_source_revalidate(&s) == 0);
    }
    var sentinel: source.Source = undefined;
    @memset(std.mem.asBytes(&sentinel), 0x5a);
    const before = sentinel;
    for (0..9) |invalid| {
        setup();
        var actor = actors;
        var model = @intFromPtr(&model_data);
        var st = @intFromPtr(&state_data);
        var frame = @intFromPtr(&native_frame_data);
        switch (invalid) {
            0 => {
                actor = actors + 1;
            },
            1 => {
                actor = actors + 0x2880;
            },
            2 => {
                model = 0;
            },
            3 => {
                st = 1;
            },
            4 => {
                frame = 1;
            },
            5 => {
                native_frame_data[6] = 257;
            },
            6 => {
                native_frame_data[1] = actors;
            },
            7 => put(&model_data, 0, actors),
            8 => win.store(u32, 0xfb2e3c, 4097),
            else => unreachable,
        }
        win.SetLastError(0x12345678);
        check(@src(), source.native_script_shoot_source_resolve(actor, st, model, frame, &sentinel) == 0 and std.mem.eql(u8, std.mem.asBytes(&before), std.mem.asBytes(&sentinel)) and win.GetLastError() == 0x12345678);
    }
    setup();
    native_frame_data[5] = 0;
    native_frame_data[6] = 0;
    s = resolved();
    check(@src(), s.input.argument_count == 0);
    const guard = win.VirtualAlloc(0, 0x2000, 0x3000, 4);
    check(@src(), guard != 0);
    defer _ = win.VirtualFree(guard, 0, 0x8000);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(guard + 0x1000, 0x1000, 1, &old) != 0);
    setup();
    native_frame_data[5] = guard + 0xffe;
    check(@src(), source.native_script_shoot_source_resolve(actors, @intFromPtr(&state_data), @intFromPtr(&model_data), @intFromPtr(&native_frame_data), &sentinel) == 0);
}
export var caller_fx: [512]u8 align(16) = @splat(0);
export var observed_fx: [512]u8 align(16) = @splat(0);
export var xmm_patterns: [128]u8 align(16) = @splat(0);
export var observed_regs: [9]u32 = @splat(0);
export var branch: u32 = 0;
export var helper_calls: u32 = 0;
export var continuation_calls: u32 = 0;
export var abi_model: [0x50]u8 = @splat(0);
export var abi_state: [0xb0]u8 = @splat(0);
export var native_operand: u8 = 0;
export var entry: usize = 0;
export var fpu_values: [2]f64 = .{ 1.25, 2.5 };
export var mxcsr_value: u32 = 0x3f80;
export var cw: u32 = 0x7f;
export var script_shoot_visible_resume: usize = 0;
export var script_shoot_hidden_resume: usize = 0;
var canonical: i32 = -1;
export fn helper_body(actor: usize, st: usize, model: usize, frame: usize, local: u32) u32 {
    check(@src(), actor == 0x11112222 and st == @intFromPtr(&abi_state) and model == @intFromPtr(&abi_model) and frame == 0x33334444 and local == abi_model[0x42]);
    helper_calls += 1;
    win.SetLastError(0xdeadbeef);
    return if (canonical < 0) local else @intCast(canonical);
}
extern fn visible_cont() void;
extern fn hidden_cont() void;
extern fn original() void;
extern fn invoke() void;
extern fn script_shoot_visibility_thunk() void;
comptime {
    asm (@import("script_shoot_fixture.zig").code);
    asm (@import("cadence_bridge_code.zig").code("script_shoot_visibility_thunk"));
}
fn abiTests() void {
    script_shoot_visible_resume = @intFromPtr(&visible_cont);
    script_shoot_hidden_resume = @intFromPtr(&hidden_cont);
    for (&xmm_patterns, 0..) |*value, i| value.* = @truncate(i * 13 + 7);
    var cases: u32 = 0;
    for (0..1000) |_| for ([_]u8{ 0, 1, 255 }) |local| for ([_]i32{ -1, 0, 1 }) |host| for ([_]u8{ 0, 8 }) |fallback| {
        abi_model[0x42] = local;
        abi_state[0xa6] = fallback;
        canonical = host;
        native_operand = if (host < 0) local else @intCast(host);
        entry = @intFromPtr(&original);
        invoke();
        const regs = observed_regs;
        const fx = observed_fx;
        const expected_branch = branch;
        entry = @intFromPtr(&script_shoot_visibility_thunk);
        win.SetLastError(0x98765432);
        invoke();
        check(@src(), win.GetLastError() == 0x98765432 and branch == expected_branch and abi_model[0x42] == local and abi_state[0xa6] == fallback);
        check(@src(), std.mem.eql(u32, &regs, &observed_regs) and std.mem.eql(u8, &fx, &observed_fx));
        cases += 1;
    };
    check(@src(), cases == 18000 and helper_calls == cases and continuation_calls == 2 * cases);
}
pub fn main() void {
    engineTests();
    abiTests();
}
