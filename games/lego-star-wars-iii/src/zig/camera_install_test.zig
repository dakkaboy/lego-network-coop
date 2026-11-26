const std = @import("std");
const s = @import("camera_state.zig");
const install = @import("camera_install.zig");
const runtime = @import("camera_runtime.zig");
const order = @import("camera_order.zig");
const win = s.win;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var worker: ?*const fn (usize) callconv(.winapi) u32 = null;
var worker_parameter: usize = 0;
var wrong_thread = false;
var procedure: usize = 0x123456;
var calls: [8]u32 = @splat(0);
var current: usize = 0;
var root: usize = 0;
var box: usize = 0;
var views: [2]usize = undefined;
var targets: [2]usize = undefined;
pub const camera_test_api = struct {
    pub fn GetWindowThreadProcessId(_: usize, pid: ?*u32) u32 {
        if (pid) |out| out.* = win.GetCurrentProcessId();
        return win.GetCurrentThreadId() + @as(u32, @intFromBool(wrong_thread));
    }
    pub fn GetWindowLongW(_: usize, index: c_int) i32 {
        check(@src(), index == -4);
        return @bitCast(procedure);
    }
    pub fn SetWindowLongW(_: usize, index: c_int, value: i32) i32 {
        check(@src(), index == -4);
        const previous = procedure;
        procedure = @bitCast(value);
        return @bitCast(previous);
    }
    pub fn GetModuleHandleW(_: ?[*:0]const u16) usize {
        return 0x400000;
    }
    pub fn GetModuleFileNameA(_: usize, out: [*]u8, size: u32) u32 {
        const path = "D:\\game\\camera.dll";
        check(@src(), size > path.len);
        @memcpy(out[0..path.len], path);
        out[path.len] = 0;
        return path.len;
    }
    pub fn GetModuleFileNameW(_: usize, out: [*]u16, size: u32) u32 {
        const path = std.unicode.utf8ToUtf16LeStringLiteral("D:\\game\\LEGO.exe");
        check(@src(), size > path.len);
        @memcpy(out[0..path.len], path);
        out[path.len] = 0;
        return path.len;
    }
    pub fn CreateFileA(_: [*:0]const u8, _: u32, _: u32, _: usize, _: u32, _: u32, _: usize) usize {
        return std.math.maxInt(usize);
    }
    pub fn GetEnvironmentVariableA(_: [*:0]const u8, _: [*]u8, _: u32) u32 {
        return 0;
    }
    pub fn EnumWindows(callback: *const fn (usize, isize) callconv(.winapi) i32, context: isize) i32 {
        _ = callback(9, context);
        return 1;
    }
    pub fn IsWindowVisible(_: usize) i32 {
        return 1;
    }
    pub fn GetWindow(_: usize, _: u32) usize {
        return 0;
    }
    pub fn IsWindow(_: usize) i32 {
        return 0;
    }
    pub fn GetPrivateProfileIntW(_: [*:0]const u16, _: [*:0]const u16, fallback: c_int, _: [*:0]const u16) u32 {
        return @bitCast(fallback);
    }
    pub fn DisableThreadLibraryCalls(module: usize) i32 {
        check(@src(), module == 91);
        calls[0] += 1;
        return 1;
    }
    pub fn CreateThread(_: usize, _: usize, entry: *const fn (usize) callconv(.winapi) u32, parameter: usize, _: u32, _: ?*u32) usize {
        worker = entry;
        worker_parameter = parameter;
        calls[1] += 1;
        return 0;
    }
};
export fn diagnostics_install(module: usize) void {
    check(@src(), module == 91);
    calls[2] += 1;
}
export fn loading_install() c_int {
    calls[3] += 1;
    return 1;
}
export fn network_window_configure(window: usize) void {
    check(@src(), window == 9);
    calls[4] += 1;
}
export fn coop_set_window(window: usize, _: bool) void {
    check(@src(), window == 9);
    calls[5] += 1;
}
export fn game_sync_prepare_worker(thread: u32) c_int {
    check(@src(), thread == win.GetCurrentThreadId());
    calls[6] += 1;
    return 1;
}
export fn game_current_level() c_int {
    return 0;
}
export fn game_sync_status() c_int {
    return 2;
}
export fn lan_status() c_int {
    return 3;
}
export fn network_window_update() void {}
export fn network_window_message(_: usize, _: u32, _: usize, _: isize) c_int {
    return 0;
}
export fn capture_reset() void {}
export fn capture_frame(_: usize) void {}
export fn game_sync_inspect() void {}
export fn coop_fonts_lost() void {}
export fn coop_fonts_reset() void {}
export fn coop_release_fonts() void {}
export fn coop_toggle() void {}
export fn coop_draw(_: usize, _: *const [2]s.Hud) void {}
export fn coop_input(_: usize, _: u32, _: usize, _: isize) c_int {
    return 0;
}
export fn game_request_reload(_: c_int) void {}
export fn game_request_level(_: c_int) void {}
export fn game_native_section_queue_allowed(_: usize, _: i32) c_int {
    return 1;
}
export fn camera_init_observer_snapshot(_: usize, _: u32, _: c_int) void {}
export fn camera_order_leave_guarded(bridge: *order.Bridge, unwound: c_int) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    order.camera_order_leave(bridge, unwound);
}
fn seed(at: usize, bytes: []const u8) void {
    check(@src(), at >= @intFromPtr(&owned_image) and at + bytes.len <= @intFromPtr(&owned_image) + owned_image.len);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(at, bytes.len, 0x40, &old) != 0);
    @memcpy(@as([*]u8, @ptrFromInt(at))[0..bytes.len], bytes);
    check(@src(), win.VirtualProtect(at, bytes.len, 0x20, &old) != 0);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), at, bytes.len);
}
fn call(at: usize, destination: usize) void {
    var bytes: [5]u8 = undefined;
    bytes[0] = 0xe8;
    std.mem.writeInt(u32, bytes[1..5], @truncate(destination -% at -% 5), .little);
    seed(at, &bytes);
}
fn jump(at: usize, destination: usize) void {
    var bytes: [5]u8 = undefined;
    bytes[0] = 0xe9;
    std.mem.writeInt(u32, bytes[1..5], @truncate(destination -% at -% 5), .little);
    seed(at, &bytes);
}
fn allocate(bytes: usize) usize {
    const result = win.VirtualAlloc(0, bytes, 0x3000, 4);
    check(@src(), result != 0);
    return result;
}
fn nativeOrder(parent: usize, argument: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), parent == current and argument == 93);
    calls[7] += 1;
    for (0..2) |i| {
        const view = s.load(usize, parent + 0xf24 + i * 4);
        s.store(u32, view + 0x34, @intCast(i + 1));
    }
    win.SetLastError(554);
    return 0x1234;
}
pub fn main() void {
    for (s.tables, [_]usize{ 0x784ec0, 0x7751b0, 0x785340 }) |table, target| {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(table, 0x74, 4, &old) != 0);
        s.store(usize, table + 8, target);
    }
    check(@src(), runtime.DllMain(91, 2, 0) == 1 and calls[0] == 0 and worker == null);
    check(@src(), runtime.DllMain(91, 1, 0) == 1 and calls[0] == 1 and calls[1] == 1 and worker != null);
    check(@src(), worker.?(worker_parameter) == 0 and s.game_window == 9 and calls[5] == 1 and calls[6] == 1);
    wrong_thread = true;
    check(@src(), install.camera_install_qualified_main() == 0 and calls[2] == 0);
    wrong_thread = false;
    const prefix = "\x83\xec\x0c\x53\x55\x33\xd2";
    seed(0x77fe40, prefix);
    call(0x7834ed, 0x77fe40);
    for (0..prefix.len) |i| {
        var changed: [7]u8 = prefix[0..7].*;
        changed[i] ^= 1;
        seed(0x77fe40, &changed);
        check(@src(), install.callAt(0x7834ed, 0x77fe40, 0x123456, true, prefix) == 0 and 0x7834ed +% 5 +% s.load(u32, 0x7834ee) == 0x77fe40);
    }
    seed(0x77fe40, prefix);
    seed(0x77fe47, "\x5d\x5b\x83\xc4\x0c");
    jump(0x77fe4c, @intFromPtr(&nativeOrder));
    seed(0x7834e9, "\xff\x74\x24\x04");
    seed(0x7834f2, "\xc2\x04\x00");
    s.store(usize, s.tables[2] + 0x48, 0x775360);
    s.store(usize, s.tables[0] + 0x24, 0x775020);
    seed(0x7815f0, "\x55\x8b\xec\x83\xe4\xf0");
    seed(0x731d00, "\x55\x8b\xec\x83\xe4\xf0\x6a\xff");
    call(0x732bd9, 0x731d00);
    seed(0x7c7d7c, "\x80\x78\x42\x00\x74\x67");
    seed(0x756080, "\x8b\x4c\x24\x04\xa1\x14\x0b\xfb\x00");
    call(0x781659, 0x77afa0);
    check(@src(), install.camera_install_qualified_main() == 1 and s.main_install_state == 1 and calls[2] == 1 and calls[3] == 1 and calls[4] == 1 and s.personal_hooks_ready and s.clonewars_camera_native_order_installed == 1);
    check(@src(), install.camera_install_qualified_main() == 1 and calls[2] == 1);
    for (s.tables) |table| check(@src(), s.load(usize, table + 8) == @intFromPtr(&@import("camera_layout.zig").update));
    check(@src(), s.load(u8, 0x7815f0) == 0xe9 and s.load(u8, 0x756080) == 0xe9 and s.clonewars_saber_host_repair[1] == 1);
    current = allocate(0x2000);
    root = allocate(0x2000);
    box = allocate(0x1000);
    defer {
        _ = win.VirtualFree(current, 0, 0x8000);
        _ = win.VirtualFree(root, 0, 0x8000);
        _ = win.VirtualFree(box, 0, 0x8000);
    }
    s.store(usize, 0xe9018c, root);
    s.store(usize, root + 0x28, box);
    s.store(usize, box + 0x28, current);
    s.store(usize, 0xfb2e60, root);
    s.store(i32, root + 0x1b78, 14);
    s.store(i32, 0xe6e61c, -1);
    s.store(i32, 0xfb11dc, 2);
    s.store(usize, current, 0xc3e248);
    s.store(usize, current + 0x1c, 0xe62090);
    s.store(u32, current + 0xf20, 2);
    s.store(i32, current + 0x13c0, -1);
    for (0..2) |i| {
        views[i] = allocate(0x1000);
        targets[i] = allocate(0x1000);
        s.store(usize, current + 0xf24 + i * 4, views[i]);
        s.store(usize, views[i], 0xc3dc94);
        s.store(u32, views[i] + 0x2c, 1);
        s.store(i16, views[i] + 0xac, @intCast(i));
        s.store(usize, views[i] + 0xb0, current);
        s.store(usize, views[i] + 0xa8, targets[i]);
        s.store(usize, targets[i], 0xc3db4c);
        s.store(usize, targets[i] + 0x10, 0xe62010);
        s.store(usize, targets[i] + 0x44, current);
    }
    defer for (0..2) |i| {
        _ = win.VirtualFree(views[i], 0, 0x8000);
        _ = win.VirtualFree(targets[i], 0, 0x8000);
    };
    s.clonewars_camera_threads[0] = win.GetCurrentThreadId();
    s.camera_select(1);
    s.clonewars_camera_fullclip = 84;
    const installed: *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) u32 = @ptrFromInt(0x7834e9);
    check(@src(), installed(current, 93) == 0x1234 and win.GetLastError() == 554 and calls[7] == 1 and order.depth == 0 and order.presentationReady(current) and std.mem.eql(usize, &s.load([2]usize, current + 0xf24), &views));
}
comptime {
    _ = @import("camera_order_bridge.zig");
    _ = @import("lexical_seh.zig");
    asm (@import("seh_finally.zig").code("camera_order_c", "camera_order_enter", "camera_order_inner", "camera_order_leave_guarded"));
}
