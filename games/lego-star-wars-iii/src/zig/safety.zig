const std = @import("std");
extern var clonewars_zig_safety_address: usize;
extern var clonewars_zig_safety_message: [256]u8;
pub const panic = std.debug.FullPanic(fail);
fn fail(message: []const u8, address: ?usize) noreturn {
    const length = @min(message.len, clonewars_zig_safety_message.len - 1);
    @memcpy(clonewars_zig_safety_message[0..length], message[0..length]);
    clonewars_zig_safety_message[length] = 0;
    clonewars_zig_safety_address = address orelse 0;
    @trap();
}
