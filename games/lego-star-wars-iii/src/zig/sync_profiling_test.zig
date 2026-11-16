const std = @import("std");
const win = @import("win32.zig");
const profiling = @import("sync_profiling.zig");
const trace = @import("trace.zig");
const check = @import("native_test_support.zig").check;
pub const tracy_enabled = true;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
extern var clonewars_zig_trace: trace.Ring(512);
const Context = extern struct { id: u32, active: i32, connection_id: u64 };
const Source = extern struct { name: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: u32, color: u32 };
var begins: u32 = 0;
var ends: u32 = 0;
var frames: u32 = 0;
var open: u32 = 0;
pub fn counts() [3]u32 {
    return .{ begins, ends, frames };
}
fn disturb() void {
    const mxcsr: u32 = 0x1f80;
    asm volatile ("fninit; ldmxcsr (%[control])"
        :
        : [control] "r" (&mxcsr),
        : .{ .memory = true });
    win.SetLastError(991);
}
pub export fn ___tracy_emit_zone_begin(source: *const Source, active: i32) Context {
    check(@src(), active == 1 and open == 0 and std.mem.eql(u8, std.mem.span(source.name), "coherent.frame") and std.mem.indexOf(u8, std.mem.span(source.file), "sync_profiling.zig") != null);
    begins += 1;
    open = begins;
    disturb();
    return .{ .id = begins, .active = 1, .connection_id = 7 };
}
pub export fn ___tracy_emit_zone_end(context: Context) void {
    check(@src(), context.active == 1 and context.id == open and context.connection_id == 7);
    open = 0;
    ends += 1;
    disturb();
}
pub export fn ___tracy_emit_frame_mark(name: ?[*:0]const u8) void {
    check(@src(), open == 0 and name != null and std.mem.eql(u8, std.mem.span(name.?), "network"));
    frames += 1;
    disturb();
}
fn controls(last_error: u32) void {
    var cw: u16 = 0;
    var mxcsr: u32 = 0;
    asm volatile ("fnstcw (%[cw]); stmxcsr (%[mxcsr])"
        :
        : [cw] "r" (&cw),
          [mxcsr] "r" (&mxcsr),
        : .{ .memory = true });
    check(@src(), cw == 0x27f and mxcsr == 0x3f80 and win.GetLastError() == last_error);
}
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
comptime {
    _ = @import("lexical_seh.zig");
}
fn raise(_: usize) callconv(.c) usize {
    win.SetLastError(717);
    win.RaiseException(0xe1654321, 0, 0, null);
    return 0;
}
fn unwind(_: usize) callconv(.c) void {
    profiling.end(false);
}
fn body(_: usize) callconv(.c) c_int {
    profiling.begin();
    _ = constructor_lexical_seh(0, raise, unwind);
    return 1;
}
pub fn main() void {
    var original: [512]u8 align(16) = @splat(0);
    asm volatile ("fxsave (%[value])"
        :
        : [value] "r" (&original),
        : .{ .memory = true });
    defer @import("machine_environment.zig").restoreFx(&original);
    const cw: u16 = 0x27f;
    const mxcsr: u32 = 0x3f80;
    asm volatile ("fldcw (%[cw]); ldmxcsr (%[mxcsr])"
        :
        : [cw] "r" (&cw),
          [mxcsr] "r" (&mxcsr),
        : .{ .memory = true });
    for (0..3) |i| {
        win.SetLastError(711);
        profiling.begin();
        controls(711);
        profiling.end(i % 2 == 0);
        controls(711);
        profiling.end(true);
        controls(711);
    }
    check(@src(), begins == 3 and ends == 3 and frames == 2 and open == 0);
    win.SetLastError(711);
    profiling.begin();
    profiling.begin();
    profiling.end(false);
    controls(711);
    check(@src(), begins == 5 and ends == 5 and frames == 2);
    check(@src(), @import("native_test_support.zig").exceptionCode(0, body) == 0xe1654321);
    controls(717);
    check(@src(), begins == 6 and ends == 6 and frames == 2 and open == 0);
    win.SetLastError(711);
    @import("sync_trace.zig").point(.publish, 7, 19, 1, 3, 1);
    controls(711);
    const event = clonewars_zig_trace.read(1) catch unreachable;
    check(@src(), event.domain == .coherent and event.epoch == 7 and event.sequence == 19 and event.kind == 4 and event.local == 1 and event.remote == 3 and event.detail == 1);
}
