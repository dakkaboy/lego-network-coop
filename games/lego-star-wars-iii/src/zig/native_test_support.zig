const std = @import("std");
extern "kernel32" fn GetStdHandle(u32) callconv(.winapi) usize;
extern "kernel32" fn WriteFile(usize, [*]const u8, u32, *u32, usize) callconv(.winapi) c_int;
pub fn check(comptime location: std.builtin.SourceLocation, value: bool) void {
    if (value) return;
    var buffer: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    writer.print("{s}:{d}: assertion failed\n", .{ location.file, location.line }) catch unreachable;
    var written: u32 = 0;
    _ = WriteFile(GetStdHandle(@bitCast(@as(i32, -12))), buffer[0..writer.end].ptr, @intCast(writer.end), &written, 0);
    @panic("native regression assertion");
}
const ExceptionRecord = extern struct { code: u32 };
const Exception = extern struct { record: *const ExceptionRecord };
extern "kernel32" fn AddVectoredExceptionHandler(u32, *const fn (*const Exception) callconv(.winapi) i32) callconv(.winapi) usize;
extern "kernel32" fn RemoveVectoredExceptionHandler(usize) callconv(.winapi) u32;
threadlocal var exception_code: u32 = 0;
threadlocal var observing: u32 = 0;
fn observe(exception: *const Exception) callconv(.winapi) i32 {
    if (observing != 0) exception_code = exception.record.code;
    return 0;
}
const Guarded = struct { raw: usize, invoke: @import("seh_guard.zig").Invoke };
fn guarded(raw: usize) callconv(.c) c_int {
    const call: *const Guarded = @ptrFromInt(raw);
    _ = call.invoke(call.raw);
    return 1;
}
pub fn exceptionCode(raw: usize, invoke: @import("seh_guard.zig").Invoke) u32 {
    return exceptionResult(raw, invoke).code;
}
pub const ExceptionResult = struct { code: u32, last_error: u32 };
pub fn exceptionResult(raw: usize, invoke: @import("seh_guard.zig").Invoke) ExceptionResult {
    var machine: @import("machine_environment.zig").Environment = undefined;
    machine.capture();
    const handler = AddVectoredExceptionHandler(1, observe);
    check(@src(), handler != 0);
    const previous = exception_code;
    exception_code = 0;
    observing += 1;
    machine.restore();
    const call: Guarded = .{ .raw = raw, .invoke = invoke };
    const normal = @import("seh_guard.zig").all(@intFromPtr(&call), guarded);
    machine.capture();
    const code = if (normal != 0) 0 else exception_code;
    exception_code = previous;
    observing -= 1;
    check(@src(), RemoveVectoredExceptionHandler(handler) != 0);
    machine.restore();
    return .{ .code = code, .last_error = machine.last_error };
}
