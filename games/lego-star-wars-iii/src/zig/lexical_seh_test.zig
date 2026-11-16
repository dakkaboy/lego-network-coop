const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
comptime {
    _ = @import("lexical_seh.zig");
}
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn tag_lexical_seh(usize, *const fn (usize) callconv(.c) c_int, *const fn (usize, c_int) callconv(.c) void) c_int;
var invokes: u32 = 0;
var aborts: u32 = 0;
var leaves: u32 = 0;
var completed: c_int = 0;
var fail_invoke = false;
var fail_leave = false;
fn invoke(context: usize) callconv(.c) c_int {
    check(@src(), context == @intFromPtr(&invokes));
    invokes += 1;
    if (fail_invoke) win.RaiseException(0xe1654321, 0, 0, null);
    return 37;
}
fn construct(context: usize) callconv(.c) usize {
    _ = invoke(context);
    return context;
}
fn leave(context: usize, done: c_int) callconv(.c) void {
    check(@src(), context == @intFromPtr(&invokes));
    leaves += 1;
    completed = done;
    if (fail_leave) win.RaiseException(0xe1654322, 0, 0, null);
}
fn abortConstruct(context: usize) callconv(.c) void {
    check(@src(), context == @intFromPtr(&invokes));
    aborts += 1;
    if (fail_leave) win.RaiseException(0xe1654322, 0, 0, null);
}
fn body(constructor: usize) callconv(.c) c_int {
    if (constructor != 0) check(@src(), constructor_lexical_seh(@intFromPtr(&invokes), construct, abortConstruct) == @intFromPtr(&invokes)) else check(@src(), tag_lexical_seh(@intFromPtr(&invokes), invoke, leave) == 37);
    return 1;
}
fn run(constructor: bool) u32 {
    return @import("native_test_support.zig").exceptionCode(@intFromBool(constructor), body);
}
pub fn main() void {
    check(@src(), run(true) == 0 and invokes == 1 and aborts == 0);
    check(@src(), run(false) == 0 and invokes == 2 and leaves == 1 and completed == 1);
    fail_invoke = true;
    check(@src(), run(true) == 0xe1654321 and aborts == 1);
    check(@src(), run(false) == 0xe1654321 and leaves == 2 and completed == 0);
    fail_invoke = false;
    fail_leave = true;
    check(@src(), run(false) == 0xe1654322 and leaves == 3 and completed == 1);
    fail_invoke = true;
    check(@src(), run(true) == 0xe1654322 and aborts == 2);
    fail_invoke = false;
    fail_leave = false;
    check(@src(), run(false) == 0 and leaves == 4 and completed == 1);
}
