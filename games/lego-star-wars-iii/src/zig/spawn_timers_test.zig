const std = @import("std");
const timers = @import("spawn_timers.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
const Update = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const BodyUpdate = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Choose = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) f32;
var order_hook: Update = undefined;
var set_hook: Update = undefined;
var choose_hook: Choose = undefined;
var frame: *p.SyncFrame = undefined;
var token: Token = undefined;
var valid = true;
var mode: u32 = 0;
var calls: u32 = 0;
var registry: usize = 0;
var objects: [2]usize = @splat(0);
var team: usize = 0;
var descriptor: usize = 0;
var order: usize = 0;
export fn coherent_frame_get(out: *Token, phase: u32) c_int {
    check(@src(), phase == 4);
    out.* = token;
    return @intFromBool(mode != 26);
}
export fn coherent_frame_valid(_: *const Token, phase: u32) c_int {
    check(@src(), phase == 2 or phase == 4);
    return @intFromBool(valid);
}
export fn rts_visibility_attack_install() c_int {
    return 1;
}
export fn rts_order_input_install() c_int {
    return 1;
}
export fn rts_visibility_input_update(_: usize, _: u32, _: ?Update, _: u32) void {}
export fn rts_body_input_update(_: usize, _: u32, _: u32, _: BodyUpdate) void {}
export fn rts_generator_input_update(_: usize, _: u32, _: Update) void {}
export fn rts_order_input_update(o: usize, delta: u32, original: Update) void {
    check(@src(), o == order and delta == 0x3dcccccd);
    original(o, delta);
}
fn nativeOrder(o: usize, _: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), o == order);
    calls += 1;
    win.SetLastError(321);
}
fn nativeSet(t: usize, index: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), t == team);
    calls += 1;
    win.store(f32, team + 0x1a28 + index * 4, 3);
    win.SetLastError(321);
}
fn nativeChoose(o: usize) callconv(.{ .x86_thiscall = .{} }) f32 {
    check(@src(), o == objects[0]);
    calls += 1;
    win.SetLastError(321);
    return 3;
}
fn put(a: usize, value: usize) void {
    win.store(usize, a, value);
}
fn jump(a: usize, target: usize) void {
    win.store(u8, a, 0xe9);
    put(a + 1, target -% a -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), a, 5) != 0);
}
fn bytes(a: usize, source: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(a))[0..source.len], source);
}
fn zero(a: usize, len: usize) void {
    @memset(@as([*]u8, @ptrFromInt(a))[0..len], 0);
}
fn setup() void {
    @memset(std.mem.asBytes(frame), 0);
    frame.epoch = 7;
    frame.sequence = 1;
    token = std.mem.zeroes(Token);
    token.frame = @intFromPtr(frame);
    token.sequence = 1;
    valid = true;
    calls = 0;
    zero(registry, 0x1000);
    put(0xe906b0, registry);
    for (objects, 0..) |object, i| {
        zero(object, 0x1000);
        const entry = registry + 8 + i * 20;
        const id: usize = if (i == 0) 7 else 3;
        put(object, 0xae60c4);
        put(object + 4, 11);
        put(object + 8, id);
        put(object + 0x68, entry);
        put(object + 0x6c, 9);
        win.store(f32, object + 0x348, @floatFromInt(i + 1));
        put(object + 0x374, 13);
        put(entry, id);
        put(entry + 4, 9);
        put(entry + 8, object);
        put(entry + 12, 4);
    }
    zero(team, 0x2000);
    put(team, 0xaef0fc);
    put(team + 0x1c, descriptor);
    put(descriptor + 0x30, 2);
    put(order + 0x28, team);
    win.store([3]f32, team + 0x1a28, .{ 1, 2, 3 });
}
const Snapshot = extern struct {
    prepare: c_int,
    finish: c_int,
    count: u32,
    team_count: u32,
    choice_count: u32,
    calls: u32,
    err: u32,
    rts_debug: [8]u32,
    module_debug: [8]u32,
    object: [2]f32,
    team: [3]f32,
    result: f32,
    entries: [2]p.SyncSpawnTimer,
    teams: [2]p.SyncRtsTeamTimers,
    choices: [2]p.SyncSpawnTimerChoice,
};
fn run() Snapshot {
    setup();
    timers.clonewars_rts_spawn_timer_debug = @splat(0);
    timers.clonewars_module_spawn_timer_debug = @splat(0);
    var out = std.mem.zeroes(Snapshot);
    switch (mode) {
        1 => put(objects[0] + 0x6c, 8),
        2 => win.store(f32, objects[0] + 0x348, std.math.nan(f32)),
        3 => put(objects[0] + 4, 0),
        4 => put(objects[0], 0),
        5 => put(0xe906b0, 0),
        6 => {
            valid = false;
        },
        7 => {
            frame.sequence = 2;
            token.sequence = 2;
        },
        else => {},
    }
    out.prepare = timers.spawn_timers_prepare(&token, frame, 1);
    if (mode >= 8 and mode < 18) {
        check(@src(), out.prepare != 0);
        frame.spawn_timers[0].remaining = 19;
        frame.spawn_timers[1].remaining = 18;
        switch (mode) {
            9 => {
                frame.spawn_timers[0].id += 1;
            },
            10 => {
                frame.spawn_timers[1].type += 1;
            },
            11 => {
                frame.spawn_timer_count -= 1;
            },
            12 => {
                valid = false;
            },
            13 => {
                token.frame = 0;
            },
            14 => put(0xe906b0, 0),
            15 => put(objects[0] + 8, 99),
            16 => put(objects[0] + 0x68, 0),
            17 => {
                frame.sequence = 2;
            },
            else => {},
        }
        out.prepare = timers.spawn_timers_prepare(&token, frame, 0);
    }
    if (mode >= 18 and mode < 24) {
        check(@src(), out.prepare != 0);
        order_hook(order, 0x3dcccccd);
        check(@src(), timers.rts_spawn_timers_finish(frame) != 0 and timers.spawn_timers_prepare(&token, frame, 0) != 0);
        win.store(f32, team + 0x1a28, 99);
        switch (mode) {
            19 => {
                frame.rts_team_timers[0].slot = 3;
            },
            20 => {
                valid = false;
            },
            21 => {
                token.sequence = 2;
            },
            22 => put(descriptor + 0x30, 8),
            else => {},
        }
        order_hook(order, 0x3dcccccd);
        if (mode == 23) order_hook(order, 0x3dcccccd);
    }
    if (mode >= 24 and mode < 30) {
        check(@src(), out.prepare != 0);
        set_hook(team, 1);
        check(@src(), timers.rts_spawn_timers_finish(frame) != 0 and timers.spawn_timers_prepare(&token, frame, 0) != 0);
        frame.spawn_timer_choices[0].remaining = 2.5;
        switch (mode) {
            25 => {
                frame.spawn_timer_choices[0].selector = 0;
            },
            27 => {
                valid = false;
            },
            28 => {
                frame.spawn_timer_choice_count = 0;
            },
            else => {},
        }
        set_hook(team, 1);
        if (mode == 29) set_hook(team, 1);
    }
    if (mode >= 30) {
        check(@src(), out.prepare != 0);
        out.result = choose_hook(objects[0]);
        check(@src(), timers.rts_spawn_timers_finish(frame) != 0 and timers.spawn_timers_prepare(&token, frame, 0) != 0);
        frame.spawn_timer_choices[0].remaining = 2.5;
        switch (mode) {
            31 => {
                frame.spawn_timer_choices[0].serial += 1;
            },
            32 => put(objects[0] + 0x6c, 99),
            33 => put(objects[0] + 4, 0),
            34 => {
                valid = false;
            },
            35 => {
                frame.spawn_timer_choice_count = 0;
            },
            else => {},
        }
        out.result = choose_hook(objects[0]);
    }
    out.err = win.GetLastError();
    out.finish = timers.rts_spawn_timers_finish(frame);
    out.calls = calls;
    out.count = frame.spawn_timer_count;
    out.team_count = frame.rts_team_timer_count;
    out.choice_count = frame.spawn_timer_choice_count;
    out.entries = frame.spawn_timers[0..2].*;
    out.teams = frame.rts_team_timers[0..2].*;
    out.choices = frame.spawn_timer_choices[0..2].*;
    out.rts_debug = timers.clonewars_rts_spawn_timer_debug;
    out.module_debug = timers.clonewars_module_spawn_timer_debug;
    for (objects, 0..) |object, i| out.object[i] = win.load(f32, object + 0x348);
    out.team = win.load([3]f32, team + 0x1a28);
    return out;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 212 and @intFromPtr(&image) < 0x483a90 and @intFromPtr(&image) + image.len > 0xfb4b6c);
    frame = std.heap.c_allocator.create(p.SyncFrame) catch @panic("allocation failed");
    defer std.heap.c_allocator.destroy(frame);
    const allocations = [_]*usize{ &registry, &objects[0], &objects[1], &team, &descriptor, &order };
    for (allocations, 0..) |address, i| {
        address.* = win.VirtualAlloc(0, if (i == 3) 0x2000 else 0x1000, 0x3000, 4);
        check(@src(), address.* != 0);
    }
    defer for (allocations) |address| {
        _ = win.VirtualFree(address.*, 0, 0x8000);
    };
    var old: u32 = 0;
    for ([_]usize{ 0x5525e0, 0x544b10, 0x547d30, 0x55e2c0, 0x50afc0, 0x504a20, 0x548064, 0x5489d3, 0x483a90 }) |address| check(@src(), win.VirtualProtect(address, 64, 0x40, &old) != 0);
    bytes(0x5525e0, &.{ 0x8b, 0x91, 0x38, 2, 0, 0 });
    for ([_]usize{ 0x544b10, 0x547d30, 0x55e2c0 }) |address| {
        bytes(address, &.{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0, 0x89, 0xec, 0x5d });
        jump(address + 9, @intFromPtr(&nativeOrder));
    }
    bytes(0x50afc0, &.{ 0xd9, 0x05, 0x40, 0x14, 0xae, 0, 0xdd, 0xd8 });
    jump(0x50afc8, @intFromPtr(&nativeSet));
    bytes(0x504a20, &.{ 0xe8, 0x6b, 0xf0, 0xf7, 0xff });
    bytes(0x548064, &.{ 0x8d, 0x44, 0x24, 0x40, 0x50, 0xe8, 0x12, 0x25, 0xfe, 0xff });
    bytes(0x5489d3, &.{ 0x8d, 0x84, 0x24, 0xa0, 0, 0, 0, 0x50, 0xe8, 0xa0, 0x1b, 0xfe, 0xff });
    jump(0x483a90, @intFromPtr(&nativeChoose));
    check(@src(), timers.rts_spawn_timers_install() != 0);
    order_hook = @ptrFromInt(0x55e2c5 +% win.load(usize, 0x55e2c1));
    set_hook = @ptrFromInt(0x50afc5 +% win.load(usize, 0x50afc1));
    choose_hook = @ptrFromInt(0x504a25 +% win.load(usize, 0x504a21));
    const expected = [_]u32{ 2165603456, 911320626, 3254292914, 911320626, 4081806186, 2431598091, 911320626, 2431598091, 1063288480, 3356515763, 1469566147, 701840007, 2170854052, 2170854052, 2170854052, 2170854052, 2170854052, 1189162861, 1380648065, 3103127542, 4046918167, 691353609, 4046918167, 1788657292, 2335920829, 3995987984, 2056483858, 2355714240, 3411027052, 3023105132, 1494248308, 1592082561, 1005690610, 1005690610, 3813465059, 898434319 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        win.SetLastError(1234);
        var actual = run();
        var result: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| result = (result ^ byte) *% 16777619;
        if (result != hash) std.debug.print("spawn timers mode={d} hash={d} expected={d}\n", .{ mode, result, hash });
        check(@src(), result == hash);
    }
    setup();
    zero(registry, 0x1000);
    check(@src(), timers.spawn_timers_prepare(&token, frame, 1) != 0 and frame.spawn_timer_count == 0);
    check(@src(), timers.spawn_timers_prepare(&token, frame, 0) != 0);
}
