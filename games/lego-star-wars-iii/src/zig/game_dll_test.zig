const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn GetFullPathNameA([*:0]const u8, u32, [*]u8, usize) callconv(.winapi) u32;
extern "kernel32" fn DeleteFileA([*:0]const u8) callconv(.winapi) i32;
extern "kernel32" fn CreateFileA([*:0]const u8, u32, u32, usize, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn ReadFile(usize, [*]u8, u32, *u32, usize) callconv(.winapi) i32;
extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
fn unsupported(path: [*:0]const u8) bool {
    const file = CreateFileA(path, 0x80000000, 3, 0, 3, 0x80, 0);
    if (file == std.math.maxInt(usize)) return false;
    defer _ = win.CloseHandle(file);
    var data: [4096]u8 = undefined;
    var count: u32 = 0;
    if (ReadFile(file, &data, data.len, &count, 0) == 0) return false;
    return std.mem.indexOf(u8, data[0..count], "unsupported executable; hooks not installed") != null;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    check(@src(), args.len == 2);
    var path: [260]u8 = @splat(0);
    const length = GetFullPathNameA(args[1], path.len, &path, 0);
    check(@src(), length != 0 and length < path.len);
    var log_path = path;
    const separator = std.mem.lastIndexOfScalar(u8, path[0..length], '\\') orelse unreachable;
    var writer = std.Io.Writer.fixed(log_path[separator + 1 ..]);
    writer.print("camera-{d}.log", .{win.GetCurrentProcessId()}) catch unreachable;
    writer.writeByte(0) catch unreachable;
    const log_name: [*:0]const u8 = @ptrCast(&log_path);
    _ = DeleteFileA(log_name);
    const module = LoadLibraryA(@ptrCast(&path));
    check(@src(), module != 0);
    for ([_][*:0]const u8{ "clonewars_zig_trace", "clonewars_capture_info", "clonewars_coherent_debug", "clonewars_camera_native_order_installed", "clonewars_input_prep_installed" }) |name| check(@src(), GetProcAddress(module, name) != 0);
    const deadline = GetTickCount64() + 3000;
    while (!unsupported(log_name) and GetTickCount64() < deadline) @import("threading.zig").Sleep(5);
    check(@src(), unsupported(log_name));
    check(@src(), win.load(u32, GetProcAddress(module, "clonewars_camera_native_order_installed")) == 0 and win.load(u32, GetProcAddress(module, "clonewars_input_prep_installed")) == 0);
}
