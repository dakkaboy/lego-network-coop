const std = @import("std");
const win = @import("win32.zig");
const profiling = @import("sync_profiling.zig");
const check = @import("native_test_support.zig").check;
pub const tracy_enabled = true;
pub fn main() void {
    var original: [512]u8 align(16) = @splat(0);
    asm volatile ("fxsave (%[value])"
        :
        : [value] "r" (&original),
        : .{ .memory = true });
    defer @import("machine_environment.zig").restoreFx(&original);
    const cw: u16 = 0x27f;
    asm volatile ("fldcw (%[cw])"
        :
        : [cw] "r" (&cw),
        : .{ .memory = true });
    for (0..32) |_| {
        win.SetLastError(711);
        profiling.begin();
        profiling.end(true);
        var after: u16 = 0;
        asm volatile ("fnstcw (%[cw])"
            :
            : [cw] "r" (&after),
            : .{ .memory = true });
        check(@src(), after == cw and win.GetLastError() == 711);
    }
}
