const win = @import("win32.zig");
const root = @import("root");
const real_api = @import("window_api.zig");
const api = if (@hasDecl(root, "window_test_api")) root.window_test_api else real_api;
var window: usize = 0;
var window_thread: u32 = 0;
var drag_active: i32 = 0;
var drag_offset: real_api.Point = .{ .x = 0, .y = 0 };
var last_drag_move: u32 = 0;
var saved_policy: i32 = 0;
var policy_owned = false;
pub export var clonewars_network_window_debug: [8]i32 = @splat(0);
extern fn lan_status() c_int;
fn onWindowThread() bool {
    return window != 0 and window_thread == win.GetCurrentThreadId();
}
fn sessionActive() bool {
    const status = lan_status();
    return status == 1 or status == 2 or status == 3;
}
fn endDrag() void {
    if (@atomicRmw(i32, &drag_active, .Xchg, 0, .seq_cst) == 0) return;
    if (api.GetCapture() == window) _ = api.ReleaseCapture();
}
fn moveDrag(final: bool) bool {
    var cursor: real_api.Point = undefined;
    const tick = api.GetTickCount();
    if (api.GetCursorPos(&cursor) == 0) return false;
    // Throttle mouse traffic so dragging cannot starve simulation or networking.
    if (!final and tick -% last_drag_move < 16) return true;
    last_drag_move = tick;
    if (api.SetWindowPos(window, 0, cursor.x -% drag_offset.x, cursor.y -% drag_offset.y, 0, 0, 0x15) == 0) return false;
    clonewars_network_window_debug[4] +%= 1;
    return true;
}
pub export fn network_window_configure(value: usize) void {
    const thread = api.GetWindowThreadProcessId(value, null);
    if (thread == 0 or thread != win.GetCurrentThreadId()) return;
    window = value;
    window_thread = thread;
}
pub export fn network_window_update() void {
    if (!onWindowThread()) return;
    if (sessionActive()) {
        const current = win.load(i32, 0xe13978);
        if (!policy_owned and (current == 0 or current == 1)) {
            saved_policy = current;
            policy_owned = true;
        }
        if (policy_owned) win.store(i32, 0xe13978, 1);
    } else {
        endDrag();
        if (policy_owned and win.load(i32, 0xe13978) == 1) win.store(i32, 0xe13978, saved_policy);
        policy_owned = false;
    }
    clonewars_network_window_debug[0] = @intFromBool(policy_owned);
    clonewars_network_window_debug[1] = if (policy_owned) win.load(i32, 0xe13978) else -1;
}
pub export fn network_window_input_blocked() c_int {
    return @intFromBool(@atomicLoad(i32, &drag_active, .seq_cst) != 0);
}
pub export fn network_window_message(value: usize, message: u32, wp: usize, _: isize) c_int {
    if (value != window or !onWindowThread()) return 0;
    network_window_update();
    if (!sessionActive()) return 0;
    if (message == 5 and wp == 1) {
        clonewars_network_window_debug[2] +%= 1;
        return 1;
    }
    if (message == 0x215 or message == 0x1f or message == 8 or (message == 0x1c and wp == 0)) {
        endDrag();
        return 0;
    }
    if (message == 0xa1 and wp == 2 and api.GetForegroundWindow() == window) {
        var bounds: real_api.Rect = undefined;
        var cursor: real_api.Point = undefined;
        if (api.GetWindowRect(window, &bounds) == 0 or api.GetCursorPos(&cursor) == 0) return 0;
        drag_offset = .{ .x = cursor.x -% bounds.left, .y = cursor.y -% bounds.top };
        _ = api.SetCapture(window);
        if (api.GetCapture() != window) return 0;
        @atomicStore(i32, &drag_active, 1, .seq_cst);
        last_drag_move = api.GetTickCount() -% 16;
        clonewars_network_window_debug[3] +%= 1;
        return 1;
    }
    if (network_window_input_blocked() == 0) return 0;
    if (message == 0x202) {
        _ = moveDrag(true);
        endDrag();
        return 1;
    }
    if (message == 0x200) {
        if (wp & 1 == 0 or !moveDrag(false)) endDrag();
        return 1;
    }
    return 0;
}
