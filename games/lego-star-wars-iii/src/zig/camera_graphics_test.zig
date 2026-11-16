const std = @import("std");
const s = @import("camera_state.zig");
const gpu = @import("camera_gpu.zig");
const image = @import("camera_image.zig");
const observe = @import("camera_observe.zig");
const present = @import("camera_present.zig");
const win = s.win;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
const Object = extern struct { table: usize, refs: i32, description: s.Description };
var device_table: [119]usize = undefined;
var surface_table: [22]usize = undefined;
var block_table: [6]usize = undefined;
var device: Object = undefined;
var back: Object = undefined;
var source: Object = undefined;
var temporary: Object = undefined;
var block: Object = undefined;
var current_target: usize = 0;
var saved_target: usize = 0;
var calls: [16]u32 = @splat(0);
var stretches: [8][8]u32 = undefined;
var fail_stretch = false;
var fail_back = false;
var parent: usize = 0;
var root: usize = 0;
var box: usize = 0;
var view: usize = 0;
fn object(raw: usize) *Object {
    return @ptrFromInt(raw);
}
fn address(value: *Object) usize {
    return @intFromPtr(value);
}
fn addRef(raw: usize) callconv(.winapi) u32 {
    object(raw).refs += 1;
    return @intCast(object(raw).refs);
}
fn release(raw: usize) callconv(.winapi) u32 {
    check(@src(), object(raw).refs > 0);
    object(raw).refs -= 1;
    return @intCast(object(raw).refs);
}
fn description(raw: usize, out: *s.Description) callconv(.winapi) i32 {
    out.* = object(raw).description;
    win.SetLastError(888);
    return 0;
}
fn getBack(_: usize, _: u32, _: u32, _: u32, out: *usize) callconv(.winapi) i32 {
    calls[0] += 1;
    if (fail_back) return @bitCast(@as(u32, 0x80004005));
    out.* = address(&back);
    _ = addRef(out.*);
    return 0;
}
fn getTarget(_: usize, _: u32, out: *usize) callconv(.winapi) i32 {
    calls[1] += 1;
    out.* = current_target;
    _ = addRef(out.*);
    return 0;
}
fn setTarget(_: usize, _: u32, target: usize) callconv(.winapi) i32 {
    calls[2] += 1;
    current_target = target;
    win.SetLastError(888);
    return 0;
}
fn getViewport(_: usize, out: *s.Viewport) callconv(.winapi) i32 {
    out.* = .{ .x = 1, .y = 2, .width = 1280, .height = 720, .min_z = 0, .max_z = 1 };
    return 0;
}
fn setViewport(_: usize, _: ?*const s.Viewport) callconv(.winapi) i32 {
    calls[3] += 1;
    return 0;
}
fn getScissor(_: usize, out: *s.Rect) callconv(.winapi) i32 {
    out.* = .{ .left = 3, .top = 4, .right = 1279, .bottom = 719 };
    return 0;
}
fn setScissor(_: usize, _: ?*const s.Rect) callconv(.winapi) i32 {
    return 0;
}
fn getState(_: usize, name: u32, out: *u32) callconv(.winapi) i32 {
    check(@src(), name == 174);
    out.* = 1;
    return 0;
}
fn setState(_: usize, _: u32, _: u32) callconv(.winapi) i32 {
    return 0;
}
fn stretch(_: usize, from: usize, rect: ?*const s.Rect, to: usize, _: ?*const s.Rect, filter: u32) callconv(.winapi) i32 {
    const i = calls[4];
    calls[4] += 1;
    check(@src(), i < stretches.len);
    stretches[i] = .{ from, to, filter, @intFromBool(rect != null), 0, 0, 0, 0 };
    if (rect) |r| stretches[i][4..8].* = .{ @bitCast(r.left), @bitCast(r.top), @bitCast(r.right), @bitCast(r.bottom) };
    return if (fail_stretch) @bitCast(@as(u32, 0x80004005)) else 0;
}
fn create(_: usize, width: u32, height: u32, format: u32, _: u32, _: u32, _: i32, out: *usize, _: usize) callconv(.winapi) i32 {
    calls[5] += 1;
    check(@src(), temporary.refs == 0);
    temporary.description = back.description;
    temporary.description.width = width;
    temporary.description.height = height;
    temporary.description.format = format;
    temporary.refs = 1;
    out.* = address(&temporary);
    return 0;
}
fn stateBlock(_: usize, kind: u32, out: *usize) callconv(.winapi) i32 {
    check(@src(), kind == 1 and block.refs == 0);
    block.refs = 1;
    out.* = address(&block);
    return 0;
}
fn capture(_: usize) callconv(.winapi) i32 {
    calls[6] += 1;
    saved_target = current_target;
    return 0;
}
fn apply(_: usize) callconv(.winapi) i32 {
    calls[7] += 1;
    current_target = saved_target;
    return 0;
}
fn begin(_: usize) callconv(.winapi) i32 {
    calls[8] += 1;
    return 0;
}
fn end(_: usize) callconv(.winapi) i32 {
    calls[9] += 1;
    return 0;
}
fn nativePresent(raw: usize, _: ?*const s.Rect, _: ?*const s.Rect, _: usize, _: usize) callconv(.winapi) i32 {
    check(@src(), raw == address(&device) and win.GetLastError() == 333);
    calls[10] += 1;
    win.SetLastError(444);
    return 77;
}
fn nativeReset(raw: usize, parameters: usize) callconv(.winapi) i32 {
    check(@src(), raw == address(&device) and parameters == 91 and win.GetLastError() == 333);
    calls[11] += 1;
    win.SetLastError(444);
    return 0;
}
export fn lan_status() c_int {
    return 3;
}
export fn network_window_update() void {
    calls[12] += 1;
    win.SetLastError(999);
}
export fn game_sync_inspect() void {
    calls[13] += 1;
    win.SetLastError(999);
}
export fn coop_draw(raw: usize, _: *const [2]s.Hud) void {
    check(@src(), raw == address(&device));
    calls[14] += 1;
}
export fn capture_frame(_: usize) void {
    calls[15] += 1;
}
export fn capture_reset() void {}
export fn coop_fonts_lost() void {}
export fn coop_fonts_reset() void {}
export fn coop_release_fonts() void {}
fn allocate(bytes: usize) usize {
    const result = win.VirtualAlloc(0, bytes, 0x3000, 4);
    check(@src(), result != 0);
    return result;
}
fn configure() void {
    surface_table = @splat(0);
    surface_table[1] = @intFromPtr(&addRef);
    surface_table[2] = @intFromPtr(&release);
    surface_table[12] = @intFromPtr(&description);
    block_table = @splat(0);
    block_table[2] = @intFromPtr(&release);
    block_table[4] = @intFromPtr(&capture);
    block_table[5] = @intFromPtr(&apply);
    const desc = s.Description{ .format = 21, .kind = 1, .usage = 1, .pool = 0, .multisample = 0, .quality = 0, .width = 1280, .height = 720 };
    device = .{ .table = @intFromPtr(&device_table), .refs = 1, .description = desc };
    back = .{ .table = @intFromPtr(&surface_table), .refs = 1, .description = desc };
    source = back;
    temporary = back;
    temporary.refs = 0;
    block = .{ .table = @intFromPtr(&block_table), .refs = 0, .description = desc };
    device_table = @splat(0);
    device_table[16] = @intFromPtr(&nativeReset);
    device_table[17] = @intFromPtr(&nativePresent);
    device_table[18] = @intFromPtr(&getBack);
    device_table[28] = @intFromPtr(&create);
    device_table[34] = @intFromPtr(&stretch);
    device_table[37] = @intFromPtr(&setTarget);
    device_table[38] = @intFromPtr(&getTarget);
    device_table[41] = @intFromPtr(&begin);
    device_table[42] = @intFromPtr(&end);
    device_table[47] = @intFromPtr(&setViewport);
    device_table[48] = @intFromPtr(&getViewport);
    device_table[57] = @intFromPtr(&setState);
    device_table[58] = @intFromPtr(&getState);
    device_table[59] = @intFromPtr(&stateBlock);
    device_table[75] = @intFromPtr(&setScissor);
    device_table[76] = @intFromPtr(&getScissor);
    current_target = address(&source);
    s.game_device = address(&device);
    s.original_present = &nativePresent;
    s.original_reset = &nativeReset;
    s.manager = parent;
    s.focus_manager = parent;
    s.personal_hooks_ready = false;
    s.clonewars_camera_fullclip = 0;
    s.camera_select(1);
    s.clonewars_camera_threads[0] = win.GetCurrentThreadId();
    calls = @splat(0);
    stretches = @splat(@splat(0));
    fail_back = false;
    fail_stretch = false;
}
pub fn main() void {
    parent = allocate(0x2000);
    root = allocate(0x2000);
    box = allocate(0x1000);
    view = allocate(0x1000);
    defer {
        _ = win.VirtualFree(parent, 0, 0x8000);
        _ = win.VirtualFree(root, 0, 0x8000);
        _ = win.VirtualFree(box, 0, 0x8000);
        _ = win.VirtualFree(view, 0, 0x8000);
    }
    check(@src(), @intFromPtr(&owned_image) <= 0xe60000 and @intFromPtr(&owned_image) + owned_image.len >= 0xfb5000);
    s.store(usize, 0xe9018c, root);
    s.store(usize, root + 0x28, box);
    s.store(usize, box + 0x28, parent);
    s.store(usize, 0xfb2e60, root);
    s.store(i32, root + 0x1b78, 14);
    s.store(i32, 0xe6e61c, -1);
    s.store(i32, 0xfb11dc, 2);
    s.store(usize, parent, 0xc3e248);
    s.store(usize, parent + 0x1c, 0xe62090);
    s.store(u32, parent + 0xf20, 2);
    s.store(i32, parent + 0x13c0, -1);
    s.store(usize, parent + 0xf24, view);
    s.store(usize, view, 0xc3dc94);
    s.store(i32, view + 0x2c, 1);
    s.store(i16, view + 0xac, 1);
    s.store([4]f32, view + 4, .{ 0.5, 0, 0.5, 1 });
    configure();
    s.selected_target = address(&source);
    _ = addRef(s.selected_target);
    s.selected_target_player = 1;
    check(@src(), image.crop(address(&device)) == 0 and s.selected_target == 0 and calls[4] == 1 and stretches[0][0] == address(&source) and stretches[0][1] == address(&back) and stretches[0][2] == 2 and back.refs == 1 and source.refs == 1);
    calls = @splat(0);
    check(@src(), image.crop(address(&device)) == 0 and calls[5] == 1 and calls[4] == 2 and std.mem.eql(u32, stretches[0][4..8], &.{ 640, 0, 1280, 720 }));
    check(@src(), temporary.refs == 1 and back.refs == 1);
    calls = @splat(0);
    s.store(f32, view + 4, std.math.nan(f32));
    check(@src(), image.crop(address(&device)) == 0 and calls[0] == 0);
    s.store(f32, view + 4, 0.5);
    s.clonewars_camera_gpu_observation_enabled = 1;
    win.SetLastError(333);
    observe.observeGpu(view, parent, 1, win.GetCurrentThreadId(), false);
    const row = &s.clonewars_camera_gpu_observation[1];
    check(@src(), row[0] != 0 and row[2] == 1 and row[3] == view and row[12] == address(&source) and row[14] == 1280 and row[15] == 720 and row[19] == 1 and row[20] == 2 and row[26] == 3 and row[31] == 1 and win.GetLastError() == 333 and source.refs == 1);
    const serial = row[0];
    observe.observeGpu(view, parent, 2, win.GetCurrentThreadId(), true);
    check(@src(), row[0] == serial);
    s.clonewars_camera_compositor_enabled = 1;
    var call_id: u32 = 0;
    s.store(u32, 0xfb4b6c, 19);
    s.store(u32, 0xfb4b74, 0x3dcccccd);
    observe.camera_compositor_sample(view, parent, 0xab, 0, &call_id);
    observe.camera_compositor_sample(view, parent, 0xcd, 1, &call_id);
    check(@src(), call_id == 1 and s.clonewars_camera_compositor_count == 2 and s.clonewars_camera_compositor_rows[0][28] == 0xab and s.clonewars_camera_compositor_rows[1][28] == 0xcd and s.clonewars_camera_compositor_rows[1][33] == call_id and s.clonewars_camera_compositor_rows[1][34] == 1);
    gpu.releaseTargets();
    s.manager = 0;
    s.frequency = 0;
    s.frame_timer = 0;
    s.frame_deadline = 0;
    calls = @splat(0);
    win.SetLastError(333);
    check(@src(), present.present(address(&device), null, null, 0, 0) == 77 and win.GetLastError() == 444 and calls[6] == 1 and calls[7] == 1 and calls[8] == 1 and calls[9] == 1 and calls[10] == 1 and calls[12] == 1 and calls[13] == 1 and calls[14] == 1 and calls[15] == 1 and current_target == address(&source) and back.refs == 1 and source.refs == 1 and block.refs == 0);
    s.store(usize, 0xf925d4, address(&device));
    present.install();
    check(@src(), device_table[16] == @intFromPtr(&present.reset) and device_table[17] == @intFromPtr(&present.present) and device_table[37] == @intFromPtr(&observe.setTarget));
    s.frequency = 0;
    s.frame_deadline = 0;
    win.SetLastError(333);
    const installed: *const fn (usize, ?*const s.Rect, ?*const s.Rect, usize, usize) callconv(.winapi) i32 = @ptrFromInt(device_table[17]);
    check(@src(), installed(address(&device), null, null, 0, 0) == 77);
    win.SetLastError(333);
    check(@src(), present.reset(address(&device), 91) == 0 and win.GetLastError() == 444 and calls[11] == 1);
    if (s.frame_timer != 0) {
        _ = win.CloseHandle(s.frame_timer);
        s.frame_timer = 0;
    }
    gpu.releaseTraceSurfaces();
    gpu.releaseTargets();
    check(@src(), back.refs == 1 and source.refs == 1 and temporary.refs == 0);
}
