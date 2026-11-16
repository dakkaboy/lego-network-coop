const std = @import("std");
const trace = @import("trace.zig");
pub const panic = std.debug.FullPanic(fail);
fn fail(message: []const u8, address: ?usize) noreturn {
    _ = message;
    _ = address;
    @trap();
}
pub export fn DllMain(module: *anyopaque, reason: std.os.windows.DWORD, reserved: std.os.windows.LPVOID) callconv(.winapi) std.os.windows.BOOL {
    _ = module;
    _ = reserved;
    if (reason == 1) trace.record(.preload, 5, 7, 1, 3, 4, 9);
    return .TRUE;
}
