const std = @import("std");
const s = @import("camera_state.zig");
const api = s.platform;
const log = @import("camera_log.zig").line;
const wide = std.unicode.utf8ToUtf16LeStringLiteral;
const Position = extern struct { window: usize, after: usize, x: i32, y: i32, width: i32, height: i32, flags: u32 };
pub fn backgroundPosition(window: usize, initial_width: i32, initial_height: i32) s.Point {
    var width = initial_width;
    var height = initial_height;
    var rectangle: s.Rect = undefined;
    if ((width <= 0 or height <= 0) and api.GetWindowRect(window, &rectangle) != 0) {
        width = rectangle.right -% rectangle.left;
        height = rectangle.bottom -% rectangle.top;
    }
    if (width <= 0) width = api.GetSystemMetrics(0);
    if (height <= 0) height = api.GetSystemMetrics(1);
    return .{ .x = api.GetSystemMetrics(76) -% width -% 32, .y = api.GetSystemMetrics(77) -% height -% 32 };
}
pub fn displayConfig(buffer: *[260:0]u16) [*:0]const u16 {
    @memset(buffer, 0);
    const length = api.GetModuleFileNameW(0, buffer, 260);
    if (length > 0 and length < 260) if (std.mem.lastIndexOfScalar(u16, buffer[0..length], '\\')) |last| {
        const name = wide("clonewars-display.ini");
        if (last + 1 + name.len < buffer.len) {
            @memcpy(buffer[last + 1 ..][0..name.len], name);
            buffer[last + 1 + name.len] = 0;
        }
    };
    return buffer;
}
fn observe(window: usize, message: u32, clamped: bool) void {
    var values: [16]u32 = @splat(0);
    var pid: u32 = 0;
    const thread = api.GetWindowThreadProcessId(window, &pid);
    const observing = s.win.GetCurrentThreadId();
    values[0..4].* = .{ window, observing, thread, pid };
    values[5] = @intFromPtr(&procedure);
    values[6] = @intFromBool(s.background_capture);
    if (thread == observing and pid == s.win.GetCurrentProcessId()) {
        values[7] |= 1;
        s.win.SetLastError(0);
        const current = api.GetWindowLongW(window, -4);
        const error_code = s.win.GetLastError();
        values[4] = @bitCast(current);
        values[12] = error_code;
        if (current != 0 or error_code == 0) values[7] |= 2;
        if (@as(usize, @bitCast(current)) == @intFromPtr(&procedure)) values[7] |= 8;
        var rectangle: s.Rect = undefined;
        if (api.GetWindowRect(window, &rectangle) != 0) {
            values[7] |= 4;
            values[8..12].* = .{ @bitCast(rectangle.left), @bitCast(rectangle.top), @bitCast(rectangle.right), @bitCast(rectangle.bottom) };
        }
    }
    values[13] = message;
    values[14] = api.GetTickCount();
    values[15] = @intFromBool(clamped);
    _ = @atomicRmw(i32, &s.clonewars_background_window_commit, .Add, 1, .seq_cst);
    s.clonewars_background_window_state = values;
    _ = @atomicRmw(i32, &s.clonewars_background_window_commit, .Add, 1, .seq_cst);
}
fn positionMessage(window: usize, message: u32, wp: usize, lp: isize) isize {
    const result = api.CallWindowProcW(s.previous_proc, window, message, wp, lp);
    if (!s.background_capture) return result;
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    var clamped = false;
    if (message == 0x46 and lp != 0) {
        const position: *Position = @ptrFromInt(@as(usize, @bitCast(lp)));
        const offscreen = backgroundPosition(window, if (position.flags & 1 != 0) 0 else position.width, if (position.flags & 1 != 0) 0 else position.height);
        position.x = offscreen.x;
        position.y = offscreen.y;
        position.after = 1;
        position.flags = (position.flags | 0x10) & ~@as(u32, 6);
        clamped = true;
    }
    observe(window, message, clamped);
    return result;
}
fn requestWindowed(window: usize) void {
    var config: [260:0]u16 = undefined;
    const path = displayConfig(&config);
    var width = api.GetPrivateProfileIntW(wide("Display"), wide("Width"), 2560, path);
    var height = api.GetPrivateProfileIntW(wide("Display"), wide("Height"), 1440, path);
    if (width < 640 or width > 7680 or height < 480 or height > 4320) {
        width = 2560;
        height = 1440;
    }
    const mode: *const fn (usize, u32, u32, u32, u8, u8) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x63f370);
    mode(0xf925d0, width, height, 0, 1, 0);
    const style: u32 = (@as(u32, @bitCast(api.GetWindowLongW(window, -16))) & ~@as(u32, 0x80000000)) | 0x00cf0000;
    _ = api.SetWindowLongW(window, -16, @bitCast(style));
    var rectangle = s.Rect{ .left = 0, .top = 0, .right = @intCast(width), .bottom = @intCast(height) };
    _ = api.AdjustWindowRect(&rectangle, style, 0);
    const window_width = rectangle.right -% rectangle.left;
    const window_height = rectangle.bottom -% rectangle.top;
    const position = if (s.background_capture) backgroundPosition(window, window_width, window_height) else s.Point{ .x = 80, .y = 80 };
    if (!s.background_capture) _ = api.ShowWindow(window, 9);
    _ = api.SetWindowPos(window, if (s.background_capture) 1 else @as(usize, @bitCast(@as(isize, -2))), position.x, position.y, window_width, window_height, 0x20 | @as(u32, if (s.background_capture) 0x10 else 0x40));
    if (s.background_capture) _ = api.ShowWindow(window, 4);
    log(if (s.load(i32, 0xf92730) == 1) "windowed mode enabled from display config" else "windowed mode request failed");
    @import("camera_present.zig").install();
}
pub fn procedure(window: usize, message: u32, wp: usize, lp: isize) callconv(.winapi) isize {
    if (s.network_window_message(window, message, wp, lp) != 0) return 0;
    if (message == 0x46 or message == 0x47) return positionMessage(window, message, wp, lp);
    if (message == 0x24) {
        const result = api.CallWindowProcW(s.previous_proc, window, message, wp, lp);
        s.store([2]i32, @as(usize, @bitCast(lp)) + 32, .{ 8192, 8192 });
        return result;
    }
    if (message == 0x8350) {
        if (lp == 1) s.game_request_reload(@bitCast(wp)) else s.game_request_level(@bitCast(wp));
        return 0;
    }
    if (message == s.renderer_message) {
        @import("camera_present.zig").install();
        return 0;
    }
    if (message == s.window_message) {
        requestWindowed(window);
        return 0;
    }
    const menu_key = wp == 0x79 or wp == 0x7b;
    if ((message == 0x101 or message == 0x105) and menu_key) return 0;
    if (message == 0x112 and wp & 0xfff0 == 0xf100) return 0;
    if (((message == 0x100 or message == 0x104) and menu_key and @as(usize, @bitCast(lp)) & (@as(usize, 1) << 30) == 0) or message == s.menu_message) {
        if (message != s.menu_message) _ = s.coop_input(window, message, wp, lp);
        if (s.menu_closed_at != 0 and api.GetTickCount() -% s.menu_closed_at < 350) return 0;
        s.coop_toggle();
        log("in-game LAN screen toggled");
        s.menu_closed_at = api.GetTickCount();
        return 0;
    }
    const handled = s.coop_input(window, message, wp, lp);
    s.network_window_update();
    if (handled != 0) return @intFromBool(message == 0x20);
    if (s.background_capture and message == 0x100 and @as(usize, @bitCast(lp)) & (@as(usize, 1) << 30) == 0) {
        const scan: u8 = switch (wp) { 0x08 => 0x0e, 0x0d => 0x1c, 0x26 => 0xc8, 0x28 => 0xd0, else => 0 };
        if (scan != 0 and @import("camera_install.zig").queueBackgroundKey(scan)) return 0;
    }
    return api.CallWindowProcW(s.previous_proc, window, message, wp, lp);
}
pub fn find(window: usize, _: isize) callconv(.winapi) i32 {
    var pid: u32 = 0;
    _ = api.GetWindowThreadProcessId(window, &pid);
    var class: [64]u16 = @splat(0);
    const length = if (s.background_capture) api.GetClassNameW(window, &class, class.len) else 0;
    const hidden_owned = s.background_capture and length > 0 and std.mem.eql(u16, class[0..@intCast(length)], wide("TTalesWindow"));
    if (pid == s.win.GetCurrentProcessId() and (api.IsWindowVisible(window) != 0 or hidden_owned) and api.GetWindow(window, 4) == 0) {
        s.game_window = window;
        return 0;
    }
    return 1;
}
