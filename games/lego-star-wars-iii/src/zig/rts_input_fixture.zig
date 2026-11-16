const std = @import("std");
const Token = @import("cohort_types.zig").Token;
const check = @import("native_test_support.zig").check;
pub var enabled = true;
pub var alive = true;
pub var faults: u32 = 0;
export fn coherent_frame_get(token: *Token, _: u32) c_int {
    token.* = std.mem.zeroes(Token);
    token.sequence = 44;
    return @intFromBool(enabled and alive);
}
export fn coherent_frame_valid(token: *const Token, _: u32) c_int {
    return @intFromBool(alive and token.sequence == 44);
}
export fn game_sync_native_fault(reason: c_int) void {
    check(@src(), reason == 15);
    faults += 1;
}
export fn constructor_lexical_seh(raw: usize, invoke: *const fn (usize) callconv(.c) usize, _: *const fn (usize) callconv(.c) void) usize {
    return invoke(raw);
}
