const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const fixture = @import("projectile_fixture_root.zig");
const control = @import("projectile_control.zig");
const lifecycle = @import("projectile_frame.zig");
const tracking = @import("projectile_tracking.zig");
const install = @import("projectile_input.zig");
const Token = @import("cohort_types.zig").Token;
const support = @import("native_test_support.zig");
const check = support.check;
const win = s.win;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
const manager_root: usize = 0x20000000;
const manager_pool: usize = 0x20010000;
const backing_pool: usize = 0x20020000;
const objects: *[4][0x210]u8 = @ptrFromInt(0x20030000);
const resources: *[4][0x80]u8 = @ptrFromInt(0x20040000);
const actor: usize = 0x20050000;
const origin: *[3]f32 = @ptrFromInt(0x20060000);
const transform: *[16]f32 = @ptrFromInt(0x20070000);
const weapon: *i8 = @ptrFromInt(0x20080000);
const native_input: *[6]u32 = @ptrFromInt(0x20090000);
const center: *[3]f32 = @ptrFromInt(0x200a0000);
const motion: *[3]f32 = @ptrFromInt(0x200b0000);
const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
var token = std.mem.zeroes(Token);
var lease = std.mem.zeroes(t.ControlLease);
var session = std.mem.zeroes(t.Session);
var adapter = std.mem.zeroes(t.Adapter);
var fence = true;
var mode: u32 = 0;
var phase: u32 = 1;
var native_calls: u32 = 0;
var remove_calls: u32 = 0;
var pool_calls: u32 = 0;
var secondary_calls: u32 = 0;
var fire_calls: u32 = 0;
var rejections: u32 = 0;
var observer_begins: u32 = 0;
var observer_ends: u32 = 0;
var observer_aborts: u32 = 0;
var observed_reason: u32 = 0;
var next_object: usize = 0;
var use_launch_bridges = false;
export var projectile_fixture_native_frame: [8]u32 = @splat(0);
export var projectile_fixture_motion_entry: usize = 0;
export var projectile_fixture_motion_source: usize = 0;
export var projectile_fixture_motion_output: usize = 0;
extern fn invoke_center_bridge() usize;
extern fn invoke_motion_bridge() void;
comptime {
    asm (
        \\.text
        \\_invoke_center_bridge:
        \\pushl %ebp
        \\pushl %edi
        \\movl $_projectile_fixture_native_frame,%ebp
        \\movl $0x85ae6a,%eax
        \\call *%eax
        \\movl %edi,%eax
        \\popl %edi
        \\popl %ebp
        \\ret
        \\_invoke_motion_bridge:
        \\pushl %ebp
        \\movl $_projectile_fixture_native_frame,%ebp
        \\pushl _projectile_fixture_motion_source
        \\pushl $0
        \\pushl _projectile_fixture_motion_output
        \\call *_projectile_fixture_motion_entry
        \\addl $12,%esp
        \\popl %ebp
        \\ret
    );
}
export fn coherent_frame_valid(value: *const Token, phases: u32) c_int {
    return @intFromBool(fence and lease.release == token.release and value.frame == token.frame and value.cohort_nonce == token.cohort_nonce and value.epoch == token.epoch and value.sequence == token.sequence and value.release == token.release and phases & (@as(u32, 1) << @intCast(phase)) != 0);
}
export fn coherent_frame_get(out: *Token, phases: u32) c_int {
    if (coherent_frame_valid(&token, phases) == 0) return 0;
    out.* = token;
    return 1;
}
export fn coherent_frame_release() u32 {
    return lease.release;
}
export fn coherent_frame_cancel_atomic(_: u32) void {
    fence = false;
}
export fn span_engine_control_valid(a: *t.Adapter, value: *const t.ControlLease) c_int {
    return @intFromBool(a == &adapter and fence and @import("validation.zig").equal(value, &lease));
}
export fn span_engine_control_get(a: *t.Adapter, out: *t.ControlLease) c_int {
    if (a != &adapter or !fence) return 0;
    out.* = lease;
    return 1;
}
fn readSession(out: *t.Session, _: usize) callconv(.c) c_int {
    out.* = session;
    return 1;
}
fn reject(_: u32, _: *const t.Reject, _: usize) callconv(.c) void {
    rejections += 1;
}
export fn entities_slot(a: usize) c_int {
    return if (a == actor) 0 else -1;
}
export fn entities_generation(a: usize) u32 {
    return if (a == actor) 19 else 0;
}
export fn entities_observed_generation(a: usize) u32 {
    return if (a == actor) 19 else 0;
}
export fn entities_actor(slot: u32, generation: u32) usize {
    return if (slot == 0 and generation == 19) actor else 0;
}
export fn entities_allocation_live(a: usize, generation: u32) c_int {
    return @intFromBool(a == actor and generation == 19);
}
export fn entities_is_retired(_: u32, _: u32) c_int {
    return 0;
}
export fn entities_update() void {}
export fn combat_observer_remove_begin(out: *@import("combat_types.zig").Scope, _: usize, _: usize, _: u32, _: c_int, _: u32) c_int {
    out.* = std.mem.zeroes(@import("combat_types.zig").Scope);
    observer_begins += 1;
    return 1;
}
export fn combat_observer_remove_end(out: *@import("combat_types.zig").Scope, _: c_int) void {
    observer_ends += 1;
    observed_reason = out.record.arguments[4];
}
export fn combat_observer_remove_abort(_: *@import("combat_types.zig").Scope) void {
    observer_aborts += 1;
}
export fn shooter_observer_fire_begin(out: *@import("shooter_types.zig").Scope, _: usize, _: usize, _: c_int, _: usize, _: usize, _: u32) c_int {
    out.* = std.mem.zeroes(@import("shooter_types.zig").Scope);
    observer_begins += 1;
    return 1;
}
export fn shooter_observer_fire_end(_: *@import("shooter_types.zig").Scope) void {
    observer_ends += 1;
}
export fn shooter_observer_fire_abort(_: *@import("shooter_types.zig").Scope) void {
    observer_aborts += 1;
}
export fn shooter_observer_actor_snapshot(out: *@import("shooter_types.zig").Actor, _: usize) void {
    out.* = std.mem.zeroes(@import("shooter_types.zig").Actor);
}
export fn combat_observer_removal_ready() void {}
export fn combat_observer_fire_requested() void {}
export fn combat_observer_projectile_created() void {}
const Primary = *const fn (usize, usize, usize, usize, usize, usize, u32, usize) callconv(.{ .x86_fastcall = .{} }) usize;
const Secondary = *const fn (usize, usize, usize, usize, usize, usize, u32, u32, usize) callconv(.{ .x86_fastcall = .{} }) usize;
const Removal = *const fn (usize, usize, usize, u32, c_int) callconv(.{ .x86_fastcall = .{} }) u8;
const Pool = *const fn (usize, usize, u32, u32, u32) callconv(.{ .x86_fastcall = .{} }) usize;
fn object(i: usize) usize {
    return @intFromPtr(&objects[i]);
}
fn resource(i: usize) usize {
    return @intFromPtr(&resources[i]);
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn primaryCall() usize {
    return @as(Primary, @ptrFromInt(0x44e4a8))(manager_root, 0, actor, @intFromPtr(origin), @intFromPtr(transform), @intFromPtr(weapon), 0, 0);
}
fn nativeCreation(manager: usize, owner: usize, o: usize, tr: usize, w: usize, flags: u32, x: usize) usize {
    const turret = frame.level == 79 or frame.level == 24;
    const expected_weapon = if (turret or frame.level == 73) frame.shots[0].weapon else 7;
    const lab_child = mode == 37;
    const expected_x: f32 = if (frame.level == 74 or lab_child) frame.shots[0].origin[0] else 1;
    const expected_flags: u32 = if (lab_child) 0x20010892 else if (turret) 0x800 else 0;
    check(@src(), manager == manager_root and owner == (if (lab_child) @as(usize, 0) else actor) and
        w != 0 and win.load(i8, w) == expected_weapon and flags == expected_flags and x == 0 and
        win.load(f32, o) == expected_x and win.load(f32, tr) == 1);
    native_calls += 1;
    native_input[0] = win.load(u32, 0xfb4b6c);
    native_input[1] = win.load(u32, 0xe637b4);
    native_input[2] = win.load(u32, 0xea178c);
    native_input[3] = win.load(u32, 0xfb4b74);
    if (mode == 15) win.RaiseException(0xe1459876, 0, 0, null);
    const local_motion = [_]f32{ if (session.host != 0) 4 else 44, 5, 6 };
    if (use_launch_bridges) {
        projectile_fixture_native_frame[3..6].* = .{ owner, o, tr };
        const address = invoke_center_bridge();
        center.* = win.load([3]f32, address);
        projectile_fixture_motion_source = @intFromPtr(&local_motion);
        projectile_fixture_motion_output = @intFromPtr(motion);
        invoke_motion_bridge();
    } else {
        const Source = *const fn (usize, usize, usize, usize) callconv(.c) usize;
        const center_source: Source = @ptrFromInt(fixture.projectile_fixture_target(5));
        const motion_source: Source = @ptrFromInt(fixture.projectile_fixture_target(6));
        center.* = win.load([3]f32, center_source(actor + 0xf28, owner, o, tr));
        motion.* = win.load([3]f32, motion_source(@intFromPtr(&local_motion), owner, o, tr));
    }
    if (mode == 16) win.RaiseException(0xe1459876, 0, 0, null);
    if (mode == 11) {
        win.SetLastError(321);
        return 0;
    }
    check(@src(), next_object < 4);
    const obj = object(next_object);
    put(obj + 8, @intCast(1000 + next_object));
    put(obj + 0x14, resource(next_object));
    win.store(f32, obj + 0xec, 3);
    win.store(f32, obj + 0x12c, 0.25);
    win.store(f32, obj + 0x134, 7);
    win.store(f32, obj + 0x144, 1);
    next_object += 1;
    put(0xe637b4, native_input[1] + 3);
    put(0xea178c, native_input[2] + 5);
    win.SetLastError(321);
    return obj;
}
fn nativePrimary(m: usize, o: usize, position: usize, tr: usize, w: usize, flags: u32, x: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    return nativeCreation(m, o, position, tr, w, flags, x);
}
fn nativeSecondary(m: usize, o: usize, position: usize, tr: usize, w: usize, flags: u32, d: u32, x: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    secondary_calls += 1;
    native_input[4] = d;
    const deferred = mode == 37 or (mode == 10 and frame.level == 74);
    check(@src(), m == if (deferred) manager_pool else manager_root);
    return nativeCreation(manager_root, o, position, tr, w, flags, x);
}
fn nativeRemove(manager: usize, obj: usize, flags: u32, effects: c_int) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), manager == manager_pool and obj == object(0) and flags == 0 and effects == 0);
    remove_calls += 1;
    if (mode == 8 or mode == 33) check(@src(), fixture.projectile_fixture_remember(99, obj) != null);
    win.SetLastError(321);
    return @intFromBool(mode != 7 and mode != 25);
}
fn nativePool(value: usize, a: u32, b: u32, d: u32) callconv(.{ .x86_thiscall = .{} }) usize {
    check(@src(), a == 0 and b == 0 and d == 0 and win.load(usize, value) == backing_pool);
    pool_calls += 1;
    const obj = win.load(usize, value + 4);
    if (mode != 1) {
        var link = manager_pool + 0x28;
        while (win.load(usize, link) != 0 and win.load(usize, link) != obj) link = win.load(usize, link) + 0xc;
        check(@src(), win.load(usize, link) == obj);
        put(link, win.load(u32, obj + 0xc));
        put(manager_pool + 0x2c, win.load(u32, manager_pool + 0x2c) - 1);
    }
    if (mode == 2) {
        put(obj + 8, 1001);
        put(obj + 0xc, win.load(u32, manager_pool + 0x28));
        put(manager_pool + 0x28, obj);
        put(manager_pool + 0x2c, win.load(u32, manager_pool + 0x2c) + 1);
        check(@src(), fixture.projectile_fixture_remember(99, obj) != null);
    }
    if (mode == 3) fence = false;
    if (mode == 4) fixture.projectile_fixture_reset(1);
    return 0xaabbccdd;
}
fn nativeFire(_: usize, a: usize, w: usize, m: c_int, _: usize, _: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), a == actor and win.load(i8, w) == 7 and m == 2);
    fire_calls += 1;
    _ = primaryCall();
    win.SetLastError(321);
}
fn nativeVector(out: *[3]f32, _: usize, value: *const [3]f32) callconv(.c) void {
    out.* = value.*;
}
fn jump(address: usize, value: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, value -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn forward(site: usize, arguments: usize, value: usize) void {
    const start = site - arguments * 4;
    for (0..arguments) |i| @memcpy(bytes(start + i * 4, 4), &[_]u8{ 0xff, 0x74, 0x24, @intCast(arguments * 4) });
    win.store(u8, site, 0xe8);
    put(site + 1, value -% site -% 5);
    win.store(u8, site + 5, 0xc2);
    win.store(u16, site + 6, @intCast(arguments * 4));
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), start, arguments * 4 + 8) != 0);
}
fn setup(host: bool) void {
    fence = true;
    phase = 1;
    native_calls = 0;
    remove_calls = 0;
    pool_calls = 0;
    secondary_calls = 0;
    fire_calls = 0;
    rejections = 0;
    observer_begins = 0;
    observer_ends = 0;
    observer_aborts = 0;
    observed_reason = 0;
    next_object = 0;
    @memset(std.mem.asBytes(frame), 0);
    @memset(std.mem.asBytes(objects), 0);
    @memset(std.mem.asBytes(resources), 0);
    @memset(bytes(manager_root, 0x40), 0);
    @memset(bytes(manager_pool, 0x40), 0);
    @memset(bytes(actor, 0x2000), 0);
    center.* = @splat(0);
    motion.* = @splat(0);
    native_input.* = @splat(0);
    transform.* = @splat(0);
    for ([_]usize{ 0, 5, 10, 15 }) |i| transform[i] = 1;
    put(actor + 0x50, 3);
    win.store(i16, actor + 0xdc0, 12);
    win.store(f32, actor + 0xf28, 7);
    weapon.* = 7;
    session = .{ .epoch = 1, .level = 6, .host = @intFromBool(host), .classification = t.established, .session = 17 };
    lease = std.mem.zeroes(t.ControlLease);
    lease.thread = win.GetCurrentThreadId();
    lease.release = 7;
    lease.epoch = 1;
    lease.level = 6;
    lease.root_serial = 3;
    frame.epoch = 1;
    frame.sequence = 10;
    frame.level = 6;
    token = std.mem.zeroes(Token);
    token.owner = 0x123;
    token.owner_nonce = 5;
    token.cohort_nonce = 11;
    token.thread = win.GetCurrentThreadId();
    token.release = 7;
    token.epoch = 1;
    token.sequence = 10;
    token.frame = @intFromPtr(frame);
    const count: u32 = if (mode <= 9 or mode == 24 or mode == 25 or mode >= 26) 2 else 0;
    fixture.projectile_fixture_setup(&adapter, readSession, reject, count, @intFromPtr(objects), @intFromPtr(resources));
    fixture.projectile_fixture_pool(nativePool);
    put(0xfb4b6c, 100);
    win.store(f32, 0xfb4b74, 0.016);
    put(0xea178c, 123);
    put(0xe637b4, 234);
    put(0xe9019c, manager_root);
    put(manager_root + 0x38, manager_pool);
    put(manager_pool + 0xc, backing_pool);
    put(backing_pool + 0xc, @intFromPtr(frame));
    put(manager_pool + 0x20, backing_pool);
    put(backing_pool + 4, backing_pool);
    put(manager_pool + 0x28, object(0));
    put(manager_pool + 0x2c, count);
    for (0..count) |i| {
        put(object(i) + 0x14, resource(i));
        put(object(i) + 8, @intCast(1000 + i));
        put(object(i) + 0xc, if (i + 1 < count) object(i + 1) else 0);
        s.tracked[i].native_stamp = @intCast(1000 + i);
    }
    const sites = [_]usize{ 0x44e4c0, 0x81f5bb, 0x8633e0, 0x85ba1f, 0x85b33f, 0x8464cf, 0x45a98f };
    const arguments = [_]usize{ 6, 7, 7, 3, 3, 3, 5 };
    const kinds = [_]u32{ 0, 1, 1, 2, 2, 3, 4 };
    for (sites, arguments, kinds) |site, args, kind| forward(site, args, fixture.projectile_fixture_target(kind));
}
fn begin() void {
    check(@src(), control.projectiles_bind_cohort(&token) != 0 and lifecycle.projectiles_begin(frame, @intCast(session.host)) != 0);
    phase = 2;
}
fn invokePrimary(_: usize) callconv(.c) c_int {
    _ = primaryCall();
    return 1;
}
const Snapshot = extern struct {
    exception: c_int,
    dispatch_pending: c_int,
    dispatch_complete: c_int,
    finish: c_int,
    failure_committed: c_int,
    native_calls: u32,
    remove_calls: u32,
    pool_calls: u32,
    secondary_calls: u32,
    fire_calls: u32,
    rejections: u32,
    observer_begins: u32,
    observer_ends: u32,
    observer_aborts: u32,
    observed_reason: u32,
    err: u32,
    native_input: [6]u32,
    debug: [12]u32,
    pool_debug: [8]u32,
    retire_debug: [12]u32,
    fire_debug: [8]u32,
    center_debug: [4]u32,
    failure: [171]u32,
    center: [3]f32,
    motion: [3]f32,
    metadata: fixture.Metadata,
    identity: t.Identity,
    tracked: [4]t.Tracked,
    instances: [4]u32,
    shot_count: u32,
    projectile_count: u32,
    retire_count: u32,
    shots: [2]p.SyncShot,
    projectiles: [4]p.SyncProjectile,
    retires: [2]p.SyncProjectileRetireRequest,
    objects: [4][0x210]u8,
};
fn run(host: bool) Snapshot {
    setup(host);
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    if (!host and (mode == 13 or mode == 14 or mode == 20)) {
        frame.combat_ready = 1;
        frame.shot_count = 1;
        const birth = &frame.shots[0];
        birth.id = 9;
        birth.owner = 0;
        birth.owner_generation = 19;
        birth.weapon = if (mode == 14) 8 else 7;
        birth.origin = origin.*;
        birth.transform = transform.*;
        birth.clock = 99;
        birth.rng_game = 71;
        birth.rng_engine = 73;
        birth.delta = 0.04;
        birth.phase = @intFromBool(mode == 20);
        birth.has_launch_center = 1;
        birth.launch_center = .{ 17, 18, 19 };
        birth.has_launch_motion = 1;
        birth.launch_motion = .{ 21, 22, 23 };
        birth.has_projectile_seed = 1;
        birth.projectile_seed.cast_origin[0] = 3;
        birth.projectile_seed.age = 0.5;
        birth.projectile_seed.expires_at = 11;
        birth.projectile_seed.cast_countdown = 2;
    }
    if (!host and (mode == 24 or mode == 25)) {
        frame.combat_ready = 1;
        frame.projectile_count = if (mode == 25) 2 else 1;
        frame.projectiles[0].id = if (mode == 25) 1 else 2;
        frame.projectiles[1].id = 2;
        frame.projectile_retire_count = 1;
        frame.projectile_retires[0] = .{ .id = 1, .flags = 0, .effects = 0, .caller = 0x85ba24 };
    }
    if ((mode >= 26 and mode <= 33) or mode == 36) {
        for (0..2) |i| {
            win.store(f32, object(i) + 0xa4, @floatFromInt(1 + i));
            win.store(f32, object(i) + 0x13c, 0.5);
            win.store(f32, object(i) + 0x24, @floatFromInt(3 + i));
        }
        if (mode == 27 and host) {
            s.tracked[0].birth.id = 2;
            s.tracked[1].birth.id = 1;
        }
        if (mode == 28) put(object(0) + 8, 1001);
        if (mode == 29) put(object(0) + 0x14, resource(1));
        if (mode == 36) put(object(0) + 8, 0);
        if (!host) {
            frame.combat_ready = 1;
            const first_retired = mode == 30 or mode == 33 or mode == 36;
            frame.projectile_count = if (first_retired) 1 else 2;
            for (frame.projectiles[0..frame.projectile_count], 0..) |*state, i| {
                state.id = @intCast(if (first_retired) 2 else i + 1);
                state.position = .{ @floatFromInt(11 + i), 12, 13 };
                state.transform[0] = 9;
                state.flight[8] = 0.5;
            }
            if (mode == 31) {
                frame.projectiles[0].id = 2;
                frame.projectiles[1].id = 9;
            }
            if (mode == 32) {
                frame.shot_count = 1;
                frame.shots[0].id = 9;
                frame.shots[0].owner = 0;
                frame.shots[0].owner_generation = 19;
            }
        }
    }
    if (mode != 17 and mode != 18 and mode != 19 and mode != 24 and mode != 25) begin();
    win.SetLastError(12345);
    if (mode <= 5) {
        if (mode == 5) {
            put(object(0) + 8, 1001);
        } else {
            const value = [_]usize{ backing_pool, object(0), 0, 0, 0, 0 };
            _ = @as(Pool, @ptrFromInt(0x8464c3))(@intFromPtr(&value), 0, 0, 0, 0);
        }
        _ = tracking.projectiles_observe_live(object(0), &out.identity);
    } else if (mode <= 9) {
        _ = @as(Removal, @ptrFromInt(if (mode == 9) @as(usize, 0x85ba13) else 0x85b333))(manager_pool, 0, object(0), 0, 0);
        if (mode == 9) _ = @as(Removal, @ptrFromInt(0x85ba13))(manager_pool, 0, object(0), 0, 0);
        _ = tracking.projectiles_observe_live(object(0), &out.identity);
    } else if (mode == 17 or mode == 18 or mode == 19) {
        if (mode == 19) session.classification = t.fault;
        _ = support.exceptionCode(0, invokePrimary);
        if (mode == 17 and host) {
            begin();
            check(@src(), frame.shot_count == 1 and frame.shots[0].phase == 1);
        }
    } else if (mode == 20) {
        phase = 2;
    } else if (mode == 21) {
        _ = @as(Secondary, @ptrFromInt(0x81f59f))(manager_root, 0, actor, @intFromPtr(origin), @intFromPtr(transform), @intFromPtr(weapon), 0, 2, 0);
    } else if (mode == 22) {
        @as(t.FireNative, @ptrFromInt(0x45a97b))(actor, actor, @intFromPtr(weapon), 2, 0, 0);
    } else if (mode == 24 or mode == 25) {
        _ = @as(Removal, @ptrFromInt(0x85ba13))(manager_pool, 0, object(0), 0, 0);
        begin();
        out.dispatch_pending = lifecycle.projectiles_dispatch_pending();
        out.dispatch_complete = lifecycle.projectiles_dispatch_complete();
    } else if ((mode >= 26 and mode <= 33) or mode == 36) {
        out.dispatch_pending = lifecycle.projectiles_dispatch_pending();
        out.dispatch_complete = lifecycle.projectiles_dispatch_complete();
        if (mode == 33) out.dispatch_pending = lifecycle.projectiles_dispatch_pending();
        phase = 3;
        out.finish = lifecycle.projectiles_finish();
    } else if (mode == 34 or mode == 35) {
        _ = @as(Removal, @ptrFromInt(0x85ba13))(manager_pool, 0, object(0), @intFromBool(mode == 34), @intFromBool(mode == 35));
    } else {
        const code = support.exceptionCode(0, invokePrimary);
        check(@src(), code == 0 or code == 0xe1459876);
        out.exception = @intFromBool(code != 0);
        if (mode == 23) fixture.projectile_fixture_reset(0);
    }
    out.err = win.GetLastError();
    out.native_calls = native_calls;
    out.remove_calls = remove_calls;
    out.pool_calls = pool_calls;
    out.secondary_calls = secondary_calls;
    out.fire_calls = fire_calls;
    out.rejections = rejections;
    out.observer_begins = observer_begins;
    out.observer_ends = observer_ends;
    out.observer_aborts = observer_aborts;
    out.observed_reason = observed_reason;
    out.native_input = native_input.*;
    out.center = center.*;
    out.motion = motion.*;
    fixture.projectile_fixture_metadata(&out.metadata);
    out.tracked = s.tracked[0..4].*;
    out.instances = s.instance_serial[0..4].*;
    out.shot_count = frame.shot_count;
    out.projectile_count = frame.projectile_count;
    out.retire_count = frame.projectile_retire_count;
    out.shots = frame.shots[0..2].*;
    out.projectiles = frame.projectiles[0..4].*;
    out.retires = frame.projectile_retires[0..2].*;
    out.objects = objects.*;
    out.debug = s.clonewars_projectile_debug;
    out.pool_debug = s.clonewars_projectile_pool_release_debug;
    out.retire_debug = s.clonewars_projectile_retire_debug;
    out.fire_debug = s.clonewars_fire_debug;
    out.center_debug = s.clonewars_shot_center_debug;
    @memcpy(std.mem.asBytes(&out.failure), std.mem.asBytes(&s.clonewars_projectile_failure));
    out.failure_committed = s.clonewars_projectile_failure_committed;
    out.failure[16] = 0;
    out.failure[17] = 0;
    out.debug[10] = 0;
    if (out.failure[2] != 0) {
        check(@src(), out.failure[2] == win.GetCurrentThreadId());
        out.failure[2] = 0;
    }
    return out;
}
fn protect(address: usize, protection: u32) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 0x10000, protection, &old) != 0);
}
fn installedHooks() void {
    mode = 10;
    setup(true);
    const sites = [_]usize{ 0x44e4c0, 0x81f5bb, 0x8633e0, 0x85b33f, 0x85ba1f, 0x85be70, 0x8643a1, 0x8464cf, 0x864424, 0x45a98f, 0x45aa31, 0x45aab5, 0x884b4c, 0x85aa90, 0x85ae6a };
    const targets = [_]usize{ 0x869060, 0x8630f0, 0x8630f0, 0x846460, 0x846460, 0x846460, 0x846460, 0x69c9b0, 0x69c9b0, 0x879710, 0x879710, 0x879710, 0x879710, 0x574af0 };
    var expected: [15][9]u8 = @splat(@splat(0));
    var sizes: [15]usize = @splat(5);
    for (0..14) |i| {
        expected[i][0] = 0xe8;
        std.mem.writeInt(u32, expected[i][1..5], targets[i] -% sites[i] -% 5, .little);
    }
    sizes[14] = 9;
    expected[14] = .{ 0x8b, 0x7d, 0x0c, 0x81, 0xc7, 0x28, 0x0f, 0, 0 };
    for (sites, sizes, expected) |site, size, prefix| {
        protect(site & ~@as(usize, 0xffff), 0x40);
        @memcpy(bytes(site, size), prefix[0..size]);
    }
    win.store(u8, 0x85ae73, 0xc3);
    for (sites, expected) |site, prefix| {
        win.store(u8, site, 0xcc);
        check(@src(), install.projectiles_install() == 0);
        win.store(u8, site, prefix[0]);
        for (sites, sizes, expected) |address, size, original| check(@src(), std.mem.eql(u8, bytes(address, size), original[0..size]));
    }
    for (sites) |site| protect(site & ~@as(usize, 0xffff), 0x20);
    check(@src(), install.projectiles_install() != 0 and control.projectiles_cohort_ready() != 0);
    for (sites) |site| {
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(site, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
    projectile_fixture_motion_entry = sites[13] +% 5 +% win.load(u32, sites[13] + 1);
    use_launch_bridges = true;
    begin();
    _ = primaryCall();
    check(@src(), native_calls == 1 and frame.shot_count == 1 and frame.shots[0].has_launch_center != 0 and center[0] == 7 and motion[0] == 4);
    check(@src(), lifecycle.projectiles_dispatch_pending() == 1 and lifecycle.projectiles_dispatch_complete() != 0);
    phase = 3;
    check(@src(), lifecycle.projectiles_finish() != 0);
    var captured: t.Lease = undefined;
    check(@src(), control.projectiles_frame_lease_get(&captured) != 0 and control.projectiles_abort_frame(&captured) != 0);
    session.host = 0;
    lease.release = 8;
    token.release = 8;
    token.cohort_nonce = 12;
    frame.sequence = 11;
    token.sequence = 11;
    phase = 1;
    next_object = 0;
    fixture.projectile_fixture_setup(&adapter, readSession, reject, 0, @intFromPtr(objects), @intFromPtr(resources));
    win.store(f32, actor + 0xf28, 99);
    begin();
    _ = primaryCall();
    check(@src(), center[0] == 7 and motion[0] == 4 and lifecycle.projectiles_dispatch_pending() == 1 and lifecycle.projectiles_dispatch_complete() != 0);
    phase = 3;
    check(@src(), lifecycle.projectiles_finish() != 0 and control.projectiles_frame_lease_get(&captured) != 0 and control.projectiles_abort_frame(&captured) != 0);
    use_launch_bridges = false;
}
fn replayRetainedShot(level: i32, weapon_id: i32, retired_locally: bool, pool_witness: bool, source: u8) void {
    mode = 10;
    setup(false);
    session.level = level;
    lease.level = level;
    frame.level = level;
    win.store(u16, actor + 0xdc0, switch (level) {
        73 => 333,
        74 => 188,
        else => 466,
    });
    frame.combat_ready = 1;
    frame.shot_count = 1;
    frame.shots[0] = std.mem.zeroes(p.SyncShot);
    frame.shots[0].id = 9;
    frame.shots[0].owner_generation = 19;
    frame.shots[0].source = source;
    frame.shots[0].weapon = weapon_id;
    frame.shots[0].flags = if (level == 73 or level == 74) 0 else 0x800;
    frame.shots[0].origin = if (source == p.SYNC_SHOT_ACTOR_FOLLOWUP)
        .{ -19.98993, 1.521916, 29.51342 }
    else if (level == 74) .{ -20.944128, 1.443787, 28.830505 } else origin.*;
    frame.shots[0].transform = transform.*;
    frame.projectile_count = 1;
    frame.projectiles[0].id = 9;
    if (retired_locally) frame.shot_count = 0;
    begin();
    if (retired_locally) {
        s.tracked[0] = .{ .birth = frame.shots[0], .object = 0, .resource = resource(0), .native_stamp = 1000 };
        s.instance_serial[0] = 1;
        @import("projectile_removal.zig").released_by_native_pool[0] = @intFromBool(pool_witness);
    }
    weapon.* = if (weapon_id == 31) 29 else 31;
    if (level == 79) _ = @as(Primary, @ptrFromInt(0x44e4a8))(manager_root, 0, actor, @intFromPtr(origin), @intFromPtr(transform), @intFromPtr(weapon), 0x800, 0);
    check(@src(), native_calls == 0 and lifecycle.projectiles_dispatch_pending() == 1);
    if (level == 73 and !pool_witness) {
        check(@src(), lifecycle.projectiles_dispatch_complete() == 0 and native_calls == 0);
        return;
    }
    check(@src(), lifecycle.projectiles_dispatch_complete() != 0 and native_calls == 1);
    check(@src(), tracking.find(9) != null and win.load(u32, 0xe637b4) == 234 and win.load(u32, 0xea178c) == 123);
    phase = 3;
    check(@src(), lifecycle.projectiles_finish() != 0);
}
fn extraBombRoomPadmeShot() void {
    mode = 10;
    setup(false);
    session.level = 74;
    lease.level = 74;
    frame.level = 74;
    frame.combat_ready = 1;
    win.store(u16, actor + 0xdc0, 188);
    origin.* = .{ -20.944128, 1.443787, 28.830505 };
    defer origin.* = .{ 1, 2, 3 };
    begin();
    check(@src(), primaryCall() == 0 and native_calls == 0);
    check(@src(), lifecycle.projectiles_dispatch_pending() == 1 and lifecycle.projectiles_dispatch_complete() != 0);
    phase = 3;
    check(@src(), lifecycle.projectiles_finish() != 0);
}

fn missingLaboratoryProjectileChild() void {
    mode = 37;
    setup(false);
    session.level = 73;
    lease.level = 73;
    frame.level = 73;
    frame.combat_ready = 1;
    frame.shot_count = 1;
    const shot = &frame.shots[0];
    shot.* = std.mem.zeroes(p.SyncShot);
    shot.id = 652;
    shot.owner = -1;
    shot.weapon = 7;
    shot.flags = 0x20010892;
    shot.origin = .{ 1.837059, 0.1157198, 40.32833 };
    shot.transform = transform.*;
    shot.source = p.SYNC_SHOT_PROJECTILE_CHILD;
    shot.depth = 1;
    shot.has_projectile_seed = 1;
    frame.projectile_count = 1;
    frame.projectiles[0].id = shot.id;
    begin();
    check(@src(), native_calls == 0 and lifecycle.projectiles_dispatch_pending() == 1);
    check(@src(), lifecycle.projectiles_dispatch_complete() != 0 and native_calls == 1 and tracking.find(652) != null);
    check(@src(), secondary_calls == 1 and native_input[4] == 1);
    phase = 3;
    check(@src(), lifecycle.projectiles_finish() != 0);
}
fn laboratoryConstructorRetention() void {
    mode = 10;
    setup(false);
    session.level = 73;
    lease.level = 73;
    frame.level = 73;
    frame.combat_ready = 1;
    win.store(u16, actor + 0xdc0, 333);
    begin();

    const removal = @import("projectile_removal.zig");
    var call = std.mem.zeroes(removal.Call);
    call.op = control.capture();
    call.manager = manager_pool;
    call.object = object(0);
    call.effects = 1;
    var shot = std.mem.zeroes(p.SyncShot);
    shot.id = 34;
    shot.weapon = 9;
    shot.source = p.SYNC_SHOT_WEAPON;
    shot.clock = win.load(u32, 0xfb4b6c);
    var launch: t.Launch = .{
        .previous = s.launch,
        .operation = &call.op,
        .shot = &shot,
        .owner = actor,
        .origin = @intFromPtr(&shot.origin),
        .transform = @intFromPtr(&shot.transform),
        .center_visited = false,
    };
    s.launch = &launch;
    defer s.launch = launch.previous;
    frame.projectile_count = 1;
    frame.projectiles[0].id = 34;
    check(@src(), removal.retainBlueShadowConstructor(&call, 0x85b344));
    check(@src(), !removal.retainBlueShadowConstructor(&call, 0x8643a6));
    frame.projectiles[0].id = 35;
    check(@src(), !removal.retainBlueShadowConstructor(&call, 0x85b344));
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 5480 and @intFromPtr(&image) < 0x440000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0x440000, 0x450000, 0x570000, 0x810000, 0x840000, 0x850000, 0x860000, 0x870000, 0x880000, 0xe60000, 0xe80000, 0xe90000, 0xea0000, 0xfb0000 }) |a| protect(a, 0x40);
    for (0..12) |i| {
        const address = manager_root + i * 0x10000;
        check(@src(), win.VirtualAlloc(address, if (i == 5) 0x2000 else 0x1000, 0x3000, 4) == address);
    }
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    defer {
        for (0..12) |i| check(@src(), win.VirtualFree(manager_root + i * 0x10000, 0, 0x8000) != 0);
        check(@src(), win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
    }
    origin.* = .{ 1, 2, 3 };
    jump(0x869060, @intFromPtr(&nativePrimary));
    jump(0x8630f0, @intFromPtr(&nativeSecondary));
    jump(0x846460, @intFromPtr(&nativeRemove));
    jump(0x879710, @intFromPtr(&nativeFire));
    jump(0x574af0, @intFromPtr(&nativeVector));
    const expected = [_]u32{ 1184227612, 3653519154, 831828745, 1167328319, 104216886, 275564028, 51245018, 1561956276, 3738845962, 2514759242, 4065893543, 3223139373, 912667847, 3766242889, 520974219, 3276936777, 1061825097, 2236026083, 2072257151, 2913422143, 1786169749, 3115875567, 2819752430, 3355478927, 207234253, 204362351, 3184240380, 3538817967, 2666947112, 2456353711, 1349875915, 1164943846, 3454423909, 3488044731, 34162621, 3251854330, 1844647025, 265165343, 3351582780, 1826683998, 3699909002, 991321486, 2729320674, 2378015128, 487235997, 239090471, 3125607184, 146930926, 3907877963, 858869457, 3231480649, 1133534707, 1378193708, 3822295566, 2750826648, 1690695950, 2176616154, 3048141586, 2960945915, 2053954168, 4129797565, 4283210382, 4268169481, 639256014, 53997330, 1657367054, 1777115394, 2500420199, 2104699677, 4110642207, 2015605353, 1528419423 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i / 2);
        const host = i % 2 != 0;
        const out = run(host);
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("projectile mode={d} host={} hash={d} expected={d}\n", .{ mode, host, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 0) check(@src(), out.pool_calls == 1 and out.tracked[0].object == 0);
        if (mode == 2) check(@src(), out.identity.status == 1 and out.identity.id == 99);
        if (mode == 10 and host) check(@src(), out.shot_count == 1 and out.native_calls == 1);
        if (mode == 15 or mode == 16) check(@src(), out.exception != 0 and out.rejections != 0);
        if (mode == 26) check(@src(), out.finish != 0 and out.projectile_count == 2);
        if (mode == 27 and host) check(@src(), out.finish != 0 and out.projectiles[0].id == 1 and out.projectiles[1].id == 2);
        if (mode == 28) check(@src(), out.finish == 0 and out.failure_committed == 1);
        if (mode == 33 and !host) check(@src(), out.dispatch_pending == 1 and out.finish == 0);
        if (mode == 34 or mode == 35) check(@src(), out.rejections != 0 and out.remove_calls == 0);
    }
    mode = 36;
    for ([_]bool{ true, false }) |host| {
        const out = run(host);
        check(@src(), out.finish != 0 and out.failure_committed == 0);
        check(@src(), out.projectile_count == 1 and out.projectiles[0].id == 2);
        check(@src(), out.tracked[0].birth.id == 0 and out.tracked[1].birth.id == 2 and out.remove_calls == 0);
    }
    replayRetainedShot(79, 31, false, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(79, 29, false, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(79, 29, true, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(24, 31, false, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(73, 9, true, true, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(73, 9, true, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(74, 7, false, false, p.SYNC_SHOT_WEAPON);
    replayRetainedShot(74, 7, false, false, p.SYNC_SHOT_ACTOR_FOLLOWUP);
    extraBombRoomPadmeShot();
    missingLaboratoryProjectileChild();
    laboratoryConstructorRetention();
    installedHooks();
}
