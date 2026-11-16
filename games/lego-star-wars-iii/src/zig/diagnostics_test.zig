const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
extern "kernel32" fn GetModuleFileNameA(usize, [*]u8, u32) callconv(.winapi) u32;
extern "kernel32" fn CreateFileA([*:0]const u8, u32, u32, usize, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn ReadFile(usize, [*]u8, u32, *u32, usize) callconv(.winapi) i32;
extern "kernel32" fn WriteFile(usize, [*]const u8, u32, *u32, usize) callconv(.winapi) i32;
extern "kernel32" fn DeleteFileA([*:0]const u8) callconv(.winapi) i32;
fn fault(_: usize) callconv(.c) c_int {
    const parameters = [_]usize{ 1, 0x12345678 };
    win.RaiseException(0xc0000005, 0, 2, &parameters);
    return 1;
}
fn read(path: [*:0]const u8, buffer: []u8) []const u8 {
    const file = CreateFileA(path, 0x80000000, 1, 0, 3, 0x80, 0);
    check(@src(), file != std.math.maxInt(usize));
    defer _ = win.CloseHandle(file);
    var length: u32 = 0;
    check(@src(), ReadFile(file, buffer.ptr, @intCast(buffer.len), &length, 0) != 0 and length != 0);
    return buffer[0..length];
}
pub fn main() void {
    var path: [260]u8 = @splat(0);
    const length = GetModuleFileNameA(0, &path, path.len);
    check(@src(), length != 0);
    const separator = std.mem.lastIndexOfScalar(u8, path[0..length], '\\') orelse unreachable;
    var writer = std.Io.Writer.fixed(path[separator + 1 ..]);
    writer.print("crash-{d}.txt", .{win.GetCurrentProcessId()}) catch unreachable;
    writer.writeByte(0) catch unreachable;
    const filename: [*:0]const u8 = @ptrCast(&path);
    @import("diagnostics.zig").diagnostics_install(win.GetModuleHandleA(null));
    check(@src(), @import("seh_guard.zig").all(0, fault) == 0);
    var buffer: [32800]u8 = undefined;
    const first = read(filename, &buffer);
    check(@src(), std.mem.indexOf(u8, first, "module=") != null and std.mem.indexOf(u8, first, "fault_rva=") != null and std.mem.indexOf(u8, first, "fault code @") != null);
    check(@src(), std.mem.indexOf(u8, first, "read_write=1 address=12345678") != null and std.mem.indexOf(u8, first, "root flow @") != null and std.mem.indexOf(u8, first, "stack @") != null);
    const file = CreateFileA(filename, 4, 1, 0, 3, 0x80, 0);
    check(@src(), file != std.math.maxInt(usize));
    var written: u32 = 0;
    check(@src(), WriteFile(file, "sentinel", 8, &written, 0) != 0 and written == 8);
    _ = win.CloseHandle(file);
    check(@src(), @import("seh_guard.zig").all(0, fault) == 0);
    check(@src(), std.mem.endsWith(u8, read(filename, &buffer), "sentinel"));
    check(@src(), DeleteFileA(filename) != 0);
}
