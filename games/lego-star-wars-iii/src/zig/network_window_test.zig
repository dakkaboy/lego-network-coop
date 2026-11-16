const std = @import("std");
const win = @import("win32.zig");
const types = @import("window_api.zig");
const window = @import("network_window.zig");
const check = @import("native_test_support.zig").check;
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var mode: u32 = 0;
var moves: u32 = 0;
var releases: u32 = 0;
var capture: usize = 0;
var cursor: types.Point = .{ .x = 120, .y = 240 };
var moved: types.Point = .{ .x = 0, .y = 0 };
var status: i32 = 0;
var tick: u32 = 100;
pub export fn lan_status() i32 {
    return status;
}
pub const window_test_api = struct {
    pub fn GetCapture() usize {
        return capture;
    }
    pub fn ReleaseCapture() i32 {
        capture = 0;
        releases += 1;
        return 1;
    }
    pub fn SetCapture(value: usize) usize {
        if (mode != 10) capture = value;
        return 0;
    }
    pub fn GetCursorPos(out: *types.Point) i32 {
        out.* = cursor;
        return @intFromBool(mode != 8 and mode != 17);
    }
    pub fn GetWindowRect(_: usize, out: *types.Rect) i32 {
        out.* = .{ .left = 100, .top = 200, .right = 400, .bottom = 500 };
        return @intFromBool(mode != 9);
    }
    pub fn GetForegroundWindow() usize {
        return if (mode == 11) 0x456 else 0x123;
    }
    pub fn SetWindowPos(value: usize, after: usize, x: i32, y: i32, width: i32, height: i32, flags: u32) i32 {
        check(@src(), value == 0x123 and after == 0 and width == 0 and height == 0 and flags == 0x15);
        moves += 1;
        moved = .{ .x = x, .y = y };
        return @intFromBool(mode != 16);
    }
    pub fn GetWindowThreadProcessId(value: usize, _: ?*u32) u32 {
        return if (value == 0x456) 0 else win.GetCurrentThreadId();
    }
    pub fn GetTickCount() u32 {
        return tick;
    }
};
fn message(value: u32, wp: usize) i32 {
    return window.network_window_message(0x123, value, wp, 0);
}
fn run() void {
    window.network_window_configure(0x123);
    status = 0;
    window.network_window_update();
    window.clonewars_network_window_debug = @splat(0);
    capture = 0;
    moves = 0;
    releases = 0;
    moved = .{ .x = 0, .y = 0 };
    cursor = .{ .x = 120, .y = 240 };
    tick = if (mode == 18) 0xfffffff8 else 100;
    const initial: i32 = if (mode == 1) 1 else if (mode == 2) 2 else 0;
    win.store(i32, 0xe13978, initial);
    status = 3;
    window.network_window_update();
    check(@src(), win.load(i32, 0xe13978) == (if (initial == 2) @as(i32, 2) else 1));
    var results: [5]i32 = @splat(0);
    if (mode == 19) {
        window.network_window_configure(0x456);
        results[0] = window.network_window_message(0x456, 5, 1, 0);
    } else if (mode == 4) {
        results[0] = message(5, 1);
    } else if (mode >= 5) {
        const saved = mode;
        if (mode == 17) mode = 5;
        results[0] = message(0xa1, 2);
        mode = saved;
        results[1] = window.network_window_input_blocked();
        cursor = .{ .x = 150, .y = 290 };
        if (mode >= 12 and mode <= 15) {
            const messages = [_]u32{ 0x215, 0x1f, 8, 0x1c };
            results[2] = message(messages[mode - 12], 0);
        } else if (mode == 20) {
            status = 0;
            window.network_window_update();
        } else {
            results[2] = message(0x200, if (mode == 7) 0 else 1);
            tick +%= 1;
            results[3] = message(0x200, 1);
            results[4] = message(0x202, 0);
        }
    }
    if (mode == 3) win.store(i32, 0xe13978, 2);
    status = 0;
    window.network_window_update();
    const started = mode >= 5 and mode != 8 and mode != 9 and mode != 10 and mode != 11 and mode != 19;
    const completed = mode == 5 or mode == 6 or mode == 18;
    const failed_move = mode == 16;
    const expected_results: [5]i32 = if (completed) .{ 1, 1, 1, 1, 1 } else if (mode == 7 or failed_move or mode == 17) .{ 1, 1, 1, 0, 0 } else if (started) .{ 1, 1, 0, 0, 0 } else if (mode == 4) .{ 1, 0, 0, 0, 0 } else @splat(0);
    check(@src(), std.mem.eql(i32, &results, &expected_results));
    check(@src(), win.load(i32, 0xe13978) == (if (mode == 3) @as(i32, 2) else initial));
    check(@src(), window.network_window_input_blocked() == 0 and capture == 0);
    check(@src(), releases == @intFromBool(started));
    check(@src(), moves == (if (completed) @as(u32, 2) else @intFromBool(failed_move)));
    check(@src(), moved.x == (if (moves > 0) @as(i32, 130) else 0) and moved.y == (if (moves > 0) @as(i32, 250) else 0));
    const expected_debug: [8]i32 = .{ 0, -1, @intFromBool(mode == 4), @intFromBool(started), if (completed) 2 else 0, 0, 0, 0 };
    check(@src(), std.mem.eql(i32, &window.clonewars_network_window_debug, &expected_debug));
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) <= 0xe13978 and @intFromPtr(&owned_image) + owned_image.len > 0xe13978 + 4);
    while (mode < 21) : (mode += 1) run();
}
