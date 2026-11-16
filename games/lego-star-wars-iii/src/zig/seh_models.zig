const seh = @import("seh_finally.zig");
const win = @import("win32.zig");
extern fn camera_order_leave(usize, c_int) void;
export fn camera_order_leave_guarded(scope: usize, unwind: c_int) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    camera_order_leave(scope, unwind);
}
comptime {
    asm (seh.code("model_producer_c", "model_producer_enter", "model_producer_inner", "model_producer_leave"));
    asm (seh.code("camera_order_c", "camera_order_enter", "camera_order_inner", "camera_order_leave_guarded"));
}
