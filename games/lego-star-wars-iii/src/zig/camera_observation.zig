const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const Machine = @import("machine_environment.zig").Environment;
const root = @import("root");
const testing = if (@hasDecl(root, "camera_init_test_api")) root.camera_init_test_api else false;
pub const View = extern struct { pointer_local: u32, raw_valid: u32, type_raw: u32, role_raw: u32, target_local: u32, target_raw_valid: u32, raw: [0xb4]u8, target_raw: [0xe0]u8 };
pub const Role = extern struct { wrapper_local: u32, wrapper_raw_valid: u32, actor_local: u32, actor_flags_raw: u32, controller_local: u32, device_local: u32, join_raw: u32, fields_valid: u32, wrapper_raw: [0x64]u8 };
pub const Record = extern struct {
    committed: u32,
    id: u32,
    stage: u32,
    thread: u32,
    qpc_low: u32,
    qpc_high: u32,
    clock: u32,
    epoch: u32,
    sequence: u32,
    phase: u32,
    parent_local: u32,
    parent_valid: u32,
    state_local: u32,
    mode_raw: u32,
    focus_raw: u32,
    script_phase_raw: u32,
    selected_role_raw: u32,
    cinematic_raw: u32,
    pending_level_raw: u32,
    native_view_count_raw: u32,
    user1_device_raw: u32,
    user1_flags_raw: u32,
    device13_available_raw: u32,
    globals_valid: u32,
    views: [4]View,
    roles: [2]Role,
};
pub export var clonewars_camera_init_enabled: i32 = 0;
pub export var clonewars_camera_init_version: u32 = 1;
pub export var clonewars_camera_init_stride: u32 = @sizeOf(Record);
pub export var clonewars_camera_init_capacity: u32 = 128;
pub export var clonewars_camera_init_count: u32 = 0;
pub export var clonewars_camera_init_records: [128]Record = std.mem.zeroes([128]Record);
pub export var clonewars_camera_late_count: u32 = 0;
pub export var clonewars_camera_late_capacity: u32 = 64;
pub export var clonewars_camera_late_records: [64]Record = std.mem.zeroes([64]Record);
var observing: i32 = 0;
var late_tick: u32 = 0;
var late_started = false;
extern fn camera_init_test_read(u32, usize, u32) c_int;
extern fn camera_init_test_tick() u32;
extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
extern fn game_sync_epoch() u32;
extern fn game_sync_sequence() u32;
fn read(address: usize, output: []u8) bool {
    return if (testing) camera_init_test_read(@truncate(address), @intFromPtr(output.ptr), @intCast(output.len)) != 0 else obs.read(address, output);
}
fn word(address: usize) u32 {
    var result: u32 = 0;
    _ = read(address, std.mem.asBytes(&result));
    return result;
}
fn offsetWord(base: u32, offset: u32) u32 {
    return if (base != 0 and base <= std.math.maxInt(u32) - offset) word(base + offset) else 0;
}
fn rawValue(comptime T: type, raw: []const u8, offset: usize) T {
    return std.mem.bytesToValue(T, raw[offset..][0..@sizeOf(T)]);
}
pub export fn camera_init_observer_snapshot(parent: usize, stage: u32, selected_role: c_int) void {
    if (clonewars_camera_init_enabled == 0) return;
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    if (stage < 1 or stage > 3) return;
    const late = clonewars_camera_init_count >= 128;
    var tick: u32 = 0;
    if (late) {
        if (stage != 3 or clonewars_camera_late_count == std.math.maxInt(u32)) return;
        tick = if (testing) camera_init_test_tick() else GetTickCount();
        if (late_started and tick -% late_tick < 500) return;
    }
    const phase = offsetWord(word(0xfb2e60), 0x1b78);
    if (phase != 14 or @cmpxchgStrong(i32, &observing, 0, 1, .seq_cst, .seq_cst) != null) return;
    defer @atomicStore(i32, &observing, 0, .seq_cst);
    if (late and late_started and tick -% late_tick < 500) return;
    const index = if (late) clonewars_camera_late_count else clonewars_camera_init_count;
    if (!late and index >= 128) return;
    var r = std.mem.zeroes(Record);
    var q: i64 = 0;
    r.globals_valid = if (obs.QueryPerformanceCounter(&q) != 0) 128 else 0;
    const qpc: [2]u32 = @bitCast(q);
    r.id = index + 1;
    r.stage = stage;
    r.thread = win.GetCurrentThreadId();
    r.qpc_low = qpc[0];
    r.qpc_high = qpc[1];
    if (read(0xfb4b6c, std.mem.asBytes(&r.clock))) r.globals_valid |= 1;
    r.epoch = game_sync_epoch();
    r.sequence = game_sync_sequence();
    r.phase = phase;
    r.parent_local = @truncate(parent);
    var raw: [0x1420]u8 = undefined;
    r.parent_valid = @intFromBool(read(parent, &raw));
    if (r.parent_valid != 0) {
        r.state_local = rawValue(u32, &raw, 0x1c);
        r.mode_raw = rawValue(u32, &raw, 0xf20);
        r.focus_raw = rawValue(u32, &raw, 0x13c0);
        r.script_phase_raw = rawValue(u32, &raw, 0x13d8);
    }
    r.selected_role_raw = @bitCast(selected_role);
    var value: u8 = 0;
    if (read(0xfbc161, std.mem.asBytes(&value))) {
        r.cinematic_raw = value;
        r.globals_valid |= 2;
    }
    if (read(0xe6e61c, std.mem.asBytes(&r.pending_level_raw))) r.globals_valid |= 4;
    if (read(0xfb11dc, std.mem.asBytes(&r.native_view_count_raw))) r.globals_valid |= 8;
    if (read(0xeb1a78, std.mem.asBytes(&r.user1_device_raw))) r.globals_valid |= 16;
    if (read(0xeb1a7c, std.mem.asBytes(&r.user1_flags_raw))) r.globals_valid |= 32;
    if (read(0xead928 + 13 * 0x90, std.mem.asBytes(&value))) {
        r.device13_available_raw = value;
        r.globals_valid |= 64;
    }
    for (&r.views, 0..) |*view, i| {
        if (r.parent_valid != 0) view.pointer_local = rawValue(u32, &raw, 0xf24 + i * 4);
        view.raw_valid = @intFromBool(read(view.pointer_local, &view.raw));
        if (view.raw_valid != 0) {
            view.type_raw = rawValue(u32, &view.raw, 0x2c);
            view.role_raw = rawValue(u16, &view.raw, 0xac);
            view.target_local = rawValue(u32, &view.raw, 0xa8);
            view.target_raw_valid = @intFromBool(read(view.target_local, &view.target_raw));
        }
    }
    for (&r.roles, 0..) |*role, i| {
        if (r.parent_valid != 0) {
            role.wrapper_local = rawValue(u32, &raw, 0x13a4 + i * 4);
            role.fields_valid |= 32;
        }
        role.wrapper_raw_valid = @intFromBool(read(role.wrapper_local, &role.wrapper_raw));
        if (read(0xfb4940 + i * 4, std.mem.asBytes(&role.actor_local))) role.fields_valid |= 1;
        if (role.actor_local != 0 and role.actor_local <= std.math.maxInt(u32) - 0x6cc) {
            if (read(role.actor_local + 0x50, std.mem.asBytes(&role.actor_flags_raw))) role.fields_valid |= 2;
            if (read(role.actor_local + 0x6cc, std.mem.asBytes(&role.controller_local))) role.fields_valid |= 4;
        }
        if (read(role.controller_local, std.mem.asBytes(&role.device_local))) role.fields_valid |= 8;
        if (read(0xfb484d + i * 0x20, std.mem.asBytes(&value))) {
            role.join_raw = value;
            role.fields_valid |= 16;
        }
    }
    const target = if (late) &clonewars_camera_late_records[index % 64] else &clonewars_camera_init_records[index];
    obs.publish(target, &r);
    if (late) {
        @atomicStore(u32, &clonewars_camera_late_count, index + 1, .seq_cst);
        late_tick = tick;
        late_started = true;
    } else @atomicStore(u32, &clonewars_camera_init_count, index + 1, .seq_cst);
}
comptime {
    std.debug.assert(@sizeOf(View) == 428 and @sizeOf(Role) == 132 and @sizeOf(Record) == 2072);
}
