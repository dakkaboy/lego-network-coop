const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const c = @import("projectile_control.zig");
const f = @import("projectile_frame.zig");
const tracking = @import("projectile_tracking.zig");
const removal = @import("projectile_removal.zig");
const Token = @import("cohort_types.zig").Token;
const check = @import("native_test_support.zig").check;
const equal = @import("validation.zig").equal;
const win = s.win;
comptime {
    _ = @import("lexical_seh.zig");
}
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
var frame: *p.SyncFrame = undefined;
var token = std.mem.zeroes(Token);
var lease = std.mem.zeroes(t.ControlLease);
var session = std.mem.zeroes(t.Session);
var adapter = std.mem.zeroes(t.Adapter);
var phase: u32 = 1;
var fence_live = true;
var pool_calls: u32 = 0;
var pool_mode: u32 = 0;
var rejections: u32 = 0;
var manager_root: [0x40]u8 align(4) = @splat(0);
var manager_pool: [0x40]u8 align(4) = @splat(0);
var objects: [p.SYNC_MAX_PROJECTILES][0x210]u8 align(4) = @splat(@splat(0));
var resources: [p.SYNC_MAX_PROJECTILES][0x80]u8 align(4) = @splat(@splat(0));
var backing_pool: [8]u8 align(4) = @splat(0);
export fn coherent_frame_valid(value: *const Token, phases: u32) c_int {
    return @intFromBool(fence_live and lease.release == token.release and value.frame == token.frame and value.cohort_nonce == token.cohort_nonce and value.epoch == token.epoch and value.sequence == token.sequence and value.release == token.release and phases & (@as(u32, 1) << @intCast(phase)) != 0);
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
    fence_live = false;
}
export fn span_engine_control_valid(value: *t.Adapter, control: *const t.ControlLease) c_int {
    return @intFromBool(value == &adapter and fence_live and equal(control, &lease));
}
export fn span_engine_control_get(value: *t.Adapter, out: *t.ControlLease) c_int {
    if (value != &adapter or !fence_live) return 0;
    out.* = lease;
    return 1;
}
fn sessionRead(out: *t.Session, _: usize) callconv(.c) c_int {
    out.* = session;
    return 1;
}
fn reject(_: u32, _: *const t.Reject, _: usize) callconv(.c) void {
    rejections += 1;
}
export fn combat_observer_remove_begin(_: *@import("combat_types.zig").Scope, _: usize, _: usize, _: u32, _: c_int, _: u32) c_int {
    return 0;
}
export fn combat_observer_remove_end(_: *@import("combat_types.zig").Scope, _: c_int) void {}
export fn combat_observer_remove_abort(_: *@import("combat_types.zig").Scope) void {}
export fn combat_observer_fire_requested() void {}
export fn combat_observer_projectile_created() void {}
export fn combat_observer_removal_ready() void {}
export fn shooter_observer_fire_begin(_: *@import("shooter_types.zig").Scope, _: usize, _: usize, _: c_int, _: usize, _: usize, _: u32) c_int {
    return 0;
}
export fn shooter_observer_fire_end(_: *@import("shooter_types.zig").Scope) void {}
export fn shooter_observer_fire_abort(_: *@import("shooter_types.zig").Scope) void {}
export fn shooter_observer_actor_snapshot(out: *@import("shooter_types.zig").Actor, _: usize) void {
    out.* = std.mem.zeroes(@import("shooter_types.zig").Actor);
}
export fn entities_actor(_: u32, _: u32) usize {
    return 0;
}
export fn entities_generation(_: usize) u32 {
    return 0;
}
export fn entities_observed_generation(_: usize) u32 {
    return 0;
}
export fn entities_slot(_: usize) c_int {
    return -1;
}
export fn entities_allocation_live(_: usize, _: u32) c_int {
    return 0;
}
export fn entities_is_retired(_: u32, _: u32) c_int {
    return 0;
}
export fn entities_update() void {}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn object(i: usize) usize {
    return @intFromPtr(&objects[i]);
}
fn setup(host: u32) void {
    s.adapter = null;
    s.last_session = 0;
    s.last_session_epoch = 0;
    s.revoked_session = 0;
    s.revoked_session_epoch = 0;
    s.frame_associated = false;
    f.reset(true);
    s.retire_draining = false;
    s.clonewars_projectile_retire_debug = @splat(0);
    @memset(std.mem.asBytes(frame), 0);
    @memset(std.mem.asBytes(&objects), 0);
    @memset(std.mem.asBytes(&resources), 0);
    rejections = 0;
    fence_live = true;
    phase = 1;
    session = .{ .epoch = 1, .level = 6, .host = host, .classification = t.established, .session = 17 };
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
    s.adapter = &adapter;
    s.session_provider = sessionRead;
    s.reject_provider = reject;
    s.control_user = 0;
    s.main_thread = win.GetCurrentThreadId();
    s.level = 6;
    s.next_id = 2;
    s.next_instance_serial = 102;
    put(0xfb4b6c, 100);
    win.store(f32, 0xfb4b74, 0.016);
    put(0xea178c, 123);
    put(0xe637b4, 234);
    put(0xe9019c, @intFromPtr(&manager_root));
    put(@intFromPtr(&manager_root) + 0x38, @intFromPtr(&manager_pool));
    for (0..2) |i| {
        s.tracked[i].birth.id = @intCast(i + 1);
        s.tracked[i].object = object(i);
        s.tracked[i].resource = @intFromPtr(&resources[i]);
        s.instance_serial[i] = @intCast(100 + i);
        put(object(i) + 0x14, @intFromPtr(&resources[i]));
    }
    check(@src(), c.projectiles_bind_cohort(&token) != 0 and f.projectiles_begin(frame, @intCast(host)) != 0);
    phase = 2;
    pool_calls = 0;
    pool_mode = 0;
    @memset(&manager_pool, 0);
    put(@intFromPtr(&manager_pool) + 0x20, @intFromPtr(&backing_pool));
    put(@intFromPtr(&backing_pool) + 4, @intFromPtr(&backing_pool));
    put(@intFromPtr(&manager_pool) + 0x28, object(0));
    put(@intFromPtr(&manager_pool) + 0x2c, 2);
    for (0..2) |i| {
        put(object(i) + 8, @intCast(1000 + i));
        s.tracked[i].native_stamp = @intCast(1000 + i);
        put(object(i) + 0xc, if (i == 0) object(1) else 0);
    }
}
fn nativeRelease(request: usize, a: u32, b: u32, d: u32) callconv(.{ .x86_thiscall = .{} }) usize {
    pool_calls += 1;
    check(@src(), a == 0 and b == 0 and d == 0 and win.load(usize, request) == @intFromPtr(&backing_pool));
    const obj = win.load(usize, request + 4);
    const manager = @intFromPtr(&manager_pool);
    if (pool_mode != 1) {
        var link = manager + 0x28;
        while (win.load(usize, link) != 0 and win.load(usize, link) != obj) link = win.load(usize, link) + 0xc;
        check(@src(), win.load(usize, link) == obj);
        put(link, win.load(u32, obj + 0xc));
        put(manager + 0x2c, win.load(u32, manager + 0x2c) - 1);
    }
    if (pool_mode == 2) {
        put(obj + 8, win.load(u32, obj + 8) + 1);
        put(obj + 0xc, win.load(u32, manager + 0x28));
        put(manager + 0x28, obj);
        put(manager + 0x2c, win.load(u32, manager + 0x2c) + 1);
        const op = c.capture();
        var birth = std.mem.zeroes(p.SyncShot);
        birth.id = 99;
        birth.owner = -1;
        check(@src(), tracking.remember(&op, &birth, obj) != null);
    }
    if (pool_mode == 3) fence_live = false;
    if (pool_mode == 4) f.reset(true);
    return 0xaabbccdd;
}
fn callPool() usize {
    const request = [_]usize{ @intFromPtr(&backing_pool), object(0), 0, 0, 0, 0 };
    return removal.projectile_pool_release_hook(@intFromPtr(&request), 0, 0, 0, 0);
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0xe60000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0xe90000, 0xea0000, 0xe60000, 0xfb0000 }) |address| {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(address, 0x10000, 0x40, &old) != 0);
    }
    const allocation = win.VirtualAlloc(0, @sizeOf(p.SyncFrame), 0x3000, 4);
    check(@src(), allocation != 0);
    frame = @ptrFromInt(allocation);
    defer check(@src(), win.VirtualFree(allocation, 0, 0x8000) != 0);
    removal.native_pool_release = nativeRelease;
    for (0..2) |host_value| {
        const host: u32 = @intCast(host_value);
        setup(host);
        win.SetLastError(12345);
        check(@src(), callPool() == 0xaabbccdd and win.GetLastError() == 12345);
        check(@src(), pool_calls == 1 and s.tracked[0].object == 0 and s.tracked[0].birth.id == (if (host != 0) @as(u32, 0) else 1) and s.tracked[1].object == object(1));
        setup(host);
        pool_mode = 1;
        check(@src(), callPool() == 0xaabbccdd and pool_calls == 1 and s.tracked[0].object == object(0));
        setup(host);
        pool_mode = 2;
        check(@src(), callPool() == 0xaabbccdd and pool_calls == 1 and s.tracked[0].object == 0);
        const entry = tracking.find(99) orelse @panic("replacement missing");
        check(@src(), entry.object == object(0) and entry.native_stamp == 1001 and s.tracked[1].object == object(1));
        var view: t.Identity = undefined;
        check(@src(), tracking.projectiles_observe_live(object(0), &view) == 1 and view.id == 99);
        setup(host);
        pool_mode = 3;
        check(@src(), callPool() == 0xaabbccdd and pool_calls == 1 and s.tracked[0].object == object(0));
        setup(host);
        pool_mode = 4;
        check(@src(), callPool() == 0xaabbccdd and pool_calls == 1 and s.tracked[0].birth.id == 0 and s.tracked[0].object == 0);
        setup(host);
        put(object(0) + 8, win.load(u32, object(0) + 8) + 1);
        check(@src(), tracking.projectiles_observe_live(object(0), &view) == 7);
    }
    for (0..1000) |i| {
        setup(@intCast(i & 1));
        check(@src(), callPool() == 0xaabbccdd and pool_calls == 1 and s.tracked[0].object == 0 and s.tracked[1].object == object(1));
    }
}
