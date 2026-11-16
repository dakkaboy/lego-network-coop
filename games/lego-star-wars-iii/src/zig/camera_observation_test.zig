const std = @import("std");
const camera = @import("camera_observation.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const camera_init_test_api = true;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var flow: usize = 0;
var parent: usize = 0;
var views: [4]usize = @splat(0);
var targets: [4]usize = @splat(0);
var actors: [2]usize = @splat(0);
var controllers: [2]usize = @splat(0);
var wrappers: [2]usize = @splat(0);
var mode: u32 = 0;
var tick: u32 = 0;
var nested = false;
export fn game_sync_epoch() u32 {
    return 7;
}
export fn game_sync_sequence() u32 {
    return 8;
}
export fn camera_init_test_tick() u32 {
    return tick;
}
export fn camera_init_test_read(address: u32, output: usize, size: u32) c_int {
    if (mode == 6 and address == 0xeb1a78) return 0;
    if (mode == 8 and address == parent and !nested) {
        nested = true;
        camera.camera_init_observer_snapshot(parent, 3, 1);
        nested = false;
    }
    if (!@import("page_access.zig").regionReadable(address, size)) return 0;
    @memcpy(@as([*]u8, @ptrFromInt(output))[0..size], @as([*]const u8, @ptrFromInt(address))[0..size]);
    win.SetLastError(999);
    return 1;
}
const Snapshot = extern struct {
    count: u32,
    late_count: u32,
    err: u32,
    records: [128]camera.Record,
    late_records: [64]camera.Record,
};
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn run(out: *Snapshot) void {
    nested = false;
    tick = 10000 + mode * 1000;
    camera.clonewars_camera_init_enabled = @intFromBool(mode != 1);
    camera.clonewars_camera_init_count = 0;
    camera.clonewars_camera_late_count = 0;
    @memset(std.mem.asBytes(&camera.clonewars_camera_init_records), 0);
    @memset(std.mem.asBytes(&camera.clonewars_camera_late_records), 0);
    put(flow + 0x1b78, if (mode == 3) 13 else 14);
    put(parent + 0xf24, if (mode == 5) 1 else views[0]);
    put(0xfb4940, if (mode == 7) 0xfffffff0 else actors[0]);
    win.SetLastError(1234);
    const p = if (mode == 4) 0 else parent;
    camera.camera_init_observer_snapshot(p, if (mode == 2) 0 else 1, -1);
    camera.camera_init_observer_snapshot(p, 2, 0);
    camera.camera_init_observer_snapshot(p, if (mode == 2) 4 else 3, 1);
    if (mode >= 9) {
        camera.clonewars_camera_init_count = 128;
        camera.clonewars_camera_late_count = if (mode == 10) std.math.maxInt(u32) else 0;
        camera.camera_init_observer_snapshot(p, 2, 0);
        camera.camera_init_observer_snapshot(p, 3, 0);
        tick += 1;
        camera.camera_init_observer_snapshot(p, 3, 0);
        tick += 499;
        camera.camera_init_observer_snapshot(p, 3, 0);
        if (mode == 9) for (0..70) |_| {
            tick += 500;
            camera.camera_init_observer_snapshot(p, 3, 1);
        };
    }
    out.err = win.GetLastError();
    out.count = camera.clonewars_camera_init_count;
    out.late_count = camera.clonewars_camera_late_count;
    out.records = camera.clonewars_camera_init_records;
    out.late_records = camera.clonewars_camera_late_records;
    for (&out.records) |*r| normalizeRecord(r);
    for (&out.late_records) |*r| normalizeRecord(r);
}
fn normalizeRecord(r: *camera.Record) void {
    if (r.committed != 0) {
        check(@src(), r.thread == win.GetCurrentThreadId() and r.qpc_low | r.qpc_high != 0);
        check(@src(), r.parent_local == (if (mode == 4) @as(usize, 0) else parent));
        for (r.views, 0..) |v, i| if (r.parent_valid != 0) {
            check(@src(), v.pointer_local == (if (mode == 5 and i == 0) @as(usize, 1) else views[i]));
            if (v.raw_valid != 0) check(@src(), v.target_local == targets[i]);
        };
        for (r.roles, 0..) |role, i| {
            check(@src(), role.actor_local == (if (mode == 7 and i == 0) @as(usize, 0xfffffff0) else actors[i]));
            if (role.controller_local != 0) check(@src(), role.controller_local == controllers[i]);
            if (r.parent_valid != 0) check(@src(), role.wrapper_local == wrappers[i]);
        }
    }
    r.qpc_low = 0;
    r.qpc_high = 0;
    r.thread = 0;
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0xe6e61c and @intFromPtr(&image) + image.len > 0xfbc161);
    const allocations = [_]*usize{ &flow, &parent, &views[0], &views[1], &views[2], &views[3], &targets[0], &targets[1], &targets[2], &targets[3], &actors[0], &actors[1], &controllers[0], &controllers[1], &wrappers[0], &wrappers[1] };
    for (allocations, 0..) |address, i| {
        address.* = win.VirtualAlloc(0, if (i == 0) 0x3000 else if (i == 1 or i == 10 or i == 11) 0x2000 else 0x1000, 0x3000, 4);
        check(@src(), address.* != 0);
    }
    defer for (allocations) |address| {
        _ = win.VirtualFree(address.*, 0, 0x8000);
    };
    put(0xfb2e60, flow);
    put(0xfb4b6c, 31);
    win.store(u8, 0xfbc161, 1);
    put(0xe6e61c, 13);
    put(0xfb11dc, 2);
    put(0xeb1a78, 71);
    put(0xeb1a7c, 73);
    win.store(u8, 0xead928 + 13 * 0x90, 1);
    for (views, 0..) |view, i| {
        put(parent + 0xf24 + i * 4, view);
        put(view + 0x2c, i + 1);
        win.store(u16, view + 0xac, @intCast(i));
        put(view + 0xa8, targets[i]);
    }
    for (actors, 0..) |actor, i| {
        put(parent + 0x13a4 + i * 4, wrappers[i]);
        put(0xfb4940 + i * 4, actor);
        put(actor + 0x50, 3);
        put(actor + 0x6cc, controllers[i]);
        put(controllers[i], 71 + i);
        win.store(u8, 0xfb484d + i * 0x20, 1);
    }
    const expected = [_]u32{ 3037364323, 2998804731, 3182973118, 2998804731, 1380835682, 1565758112, 3632526836, 2783059076, 3037364323, 3302795624, 1905420092 };
    const out = std.heap.c_allocator.create(Snapshot) catch @panic("allocation failed");
    defer std.heap.c_allocator.destroy(out);
    for (expected, 0..) |hash, index| {
        mode = @intCast(index);
        run(out);
        check(@src(), out.err == 1234);
        const words: [*]u32 = @ptrCast(out);
        for (words[0 .. @sizeOf(Snapshot) / 4]) |*word| for (allocations, 0..) |pointer, i| {
            if (word.* == pointer.*) {
                word.* = @intCast(0x1000 + i);
                break;
            }
        };
        var actual: u32 = 2166136261;
        for (std.mem.asBytes(out)) |byte| actual = (actual ^ byte) *% 16777619;
        if (actual != hash) std.debug.print("camera mode={d} hash={d} expected={d}\n", .{ mode, actual, hash });
        check(@src(), actual == hash);
    }
}
