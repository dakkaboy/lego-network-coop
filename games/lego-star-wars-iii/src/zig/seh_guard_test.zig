const std = @import("std");
const win = @import("win32.zig");
const guard = @import("seh_guard.zig");
// Intentional native faults must reach SEH instead of Zig's vectored crash reporter.
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
var reached: u32 = 0;
fn raiseCustom(_: usize) callconv(.c) c_int {
    reached = 1;
    win.RaiseException(0xe0011234, 0, 0, null);
    return 77;
}
fn readInvalid(_: usize) callconv(.c) c_int {
    return @bitCast(win.load(u32, 1));
}
fn guardedCustom(_: usize) callconv(.c) c_int {
    _ = guard.memory(0, raiseCustom, -7);
    reached = 2;
    return 99;
}
fn returnContext(value: usize) callconv(.c) c_int {
    return @intCast(value);
}
pub fn main() !void {
    try std.testing.expectEqual(@as(c_int, 31), guard.all(31, returnContext));
    try std.testing.expectEqual(@as(c_int, -7), guard.memory(0, readInvalid, -7));
    try std.testing.expectEqual(@as(c_int, 0), guard.all(0, guardedCustom));
    try std.testing.expectEqual(@as(u32, 1), reached);
    try std.testing.expectEqual(@as(c_int, 32), guard.memory(32, returnContext, -7));
}
