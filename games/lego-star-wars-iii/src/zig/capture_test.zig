const std = @import("std");
const win = @import("win32.zig");
const capture = @import("capture.zig");
const check = @import("native_test_support.zig").check;
extern "kernel32" fn SetEnvironmentVariableA([*:0]const u8, ?[*:0]const u8) callconv(.winapi) i32;
extern "kernel32" fn OpenFileMappingA(u32, i32, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn MapViewOfFile(usize, u32, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn UnmapViewOfFile(usize) callconv(.winapi) i32;
const Fake = extern struct { table: [*]usize };
const Description = extern struct { format: u32, kind: u32, usage: u32, pool: u32, multisample: u32, quality: u32, width: u32, height: u32 };
const Locked = extern struct { pitch: i32, bits: usize };
var device_methods: [119]usize = @splat(0);
var surface_methods: [17]usize = @splat(0);
var device = Fake{ .table = &device_methods };
var back = Fake{ .table = &surface_methods };
var gpu = Fake{ .table = &surface_methods };
var cpu = Fake{ .table = &surface_methods };
var releases: u32 = 0;
var locks: u32 = 0;
var unlocks: u32 = 0;
var stretches: u32 = 0;
var downloads: u32 = 0;
var created: u32 = 0;
var format: u32 = 22;
var failure: i32 = 0;
var pixels: [360 * (640 * 4 + 16)]u8 = undefined;
fn release(_: usize) callconv(.winapi) u32 {
    releases += 1;
    return 1;
}
fn getBack(_: usize, chain: u32, index: u32, kind: u32, out: *usize) callconv(.winapi) i32 {
    check(@src(), chain == 0 and index == 0 and kind == 0);
    out.* = @intFromPtr(&back);
    return 0;
}
fn describe(_: usize, out: *Description) callconv(.winapi) i32 {
    out.* = std.mem.zeroes(Description);
    out.format = format;
    out.width = 1280;
    out.height = 720;
    return 0;
}
fn createGpu(_: usize, width: u32, height: u32, value: u32, multi: u32, quality: u32, lockable: i32, out: *usize, shared: usize) callconv(.winapi) i32 {
    check(@src(), width == 640 and height == 360 and value == format and multi == 0 and quality == 0 and lockable == 0 and shared == 0);
    out.* = @intFromPtr(&gpu);
    created += 1;
    return 0;
}
fn createCpu(_: usize, width: u32, height: u32, value: u32, pool: u32, out: *usize, shared: usize) callconv(.winapi) i32 {
    check(@src(), width == 640 and height == 360 and value == format and pool == 2 and shared == 0);
    out.* = @intFromPtr(&cpu);
    created += 1;
    return 0;
}
fn stretch(_: usize, source: usize, source_rect: usize, destination: usize, destination_rect: usize, filter: u32) callconv(.winapi) i32 {
    check(@src(), source == @intFromPtr(&back) and destination == @intFromPtr(&gpu) and source_rect == 0 and destination_rect == 0 and filter == 2);
    stretches += 1;
    return 0;
}
fn download(_: usize, source: usize, destination: usize) callconv(.winapi) i32 {
    check(@src(), source == @intFromPtr(&gpu) and destination == @intFromPtr(&cpu));
    downloads += 1;
    return 0;
}
fn lock(self: usize, out: *Locked, rect: usize, flags: u32) callconv(.winapi) i32 {
    check(@src(), self == @intFromPtr(&cpu) and rect == 0 and flags == 0x10);
    locks += 1;
    out.bits = @intFromPtr(&pixels);
    out.pitch = 640 * 4 + 16;
    return failure;
}
fn unlock(self: usize) callconv(.winapi) i32 {
    check(@src(), self == @intFromPtr(&cpu));
    unlocks += 1;
    return 0;
}
pub fn main() void {
    _ = SetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE", "1");
    _ = SetEnvironmentVariableA("CLONEWARS_CAPTURE_WIDTH", "640");
    _ = SetEnvironmentVariableA("CLONEWARS_CAPTURE_HEIGHT", "360");
    _ = SetEnvironmentVariableA("CLONEWARS_CAPTURE_FPS", "60");
    device_methods[18] = @intFromPtr(&getBack);
    device_methods[28] = @intFromPtr(&createGpu);
    device_methods[36] = @intFromPtr(&createCpu);
    device_methods[34] = @intFromPtr(&stretch);
    device_methods[32] = @intFromPtr(&download);
    surface_methods[2] = @intFromPtr(&release);
    surface_methods[12] = @intFromPtr(&describe);
    surface_methods[13] = @intFromPtr(&lock);
    surface_methods[14] = @intFromPtr(&unlock);
    for (0..360) |y| for (0..640 * 4 + 16) |x| {
        pixels[y * (640 * 4 + 16) + x] = @truncate(y * 3 + x);
    };
    capture.capture_frame(@intFromPtr(&device));
    check(@src(), created == 2 and stretches == 1 and downloads == 1 and locks == 1 and unlocks == 1 and releases == 1);
    var name: [80]u8 = undefined;
    var writer = std.Io.Writer.fixed(&name);
    writer.print("Local\\CloneWarsCapture{d}", .{win.GetCurrentProcessId()}) catch unreachable;
    writer.writeByte(0) catch unreachable;
    const mapping = OpenFileMappingA(4, 0, @ptrCast(&name));
    check(@src(), mapping != 0);
    defer _ = win.CloseHandle(mapping);
    const shared = MapViewOfFile(mapping, 4, 0, 0, 0);
    check(@src(), shared != 0);
    defer _ = UnmapViewOfFile(shared);
    check(@src(), win.load(u32, shared) == 2 and win.load(u32, shared + 4) == 640 and win.load(u32, shared + 8) == 360 and win.load(u32, shared + 12) == 0 and win.load(u32, shared + 20) == 60);
    for (0..360) |y| check(@src(), std.mem.eql(u8, @as([*]const u8, @ptrFromInt(shared + 24 + y * 640 * 4))[0 .. 640 * 4], pixels[y * (640 * 4 + 16) ..][0 .. 640 * 4]));
    check(@src(), capture.clonewars_capture_info[3] == 1280 and capture.clonewars_capture_info[4] == 720 and capture.clonewars_capture_info[5] == 1);
    @import("threading.zig").Sleep(20);
    failure = @bitCast(@as(u32, 0x8876086c));
    capture.capture_frame(@intFromPtr(&device));
    check(@src(), win.load(u32, shared) == 2 and win.load(u32, shared + 12) == @as(u32, @bitCast(failure)) and unlocks == 1);
    @import("threading.zig").Sleep(20);
    format = 23;
    capture.capture_frame(@intFromPtr(&device));
    check(@src(), win.load(u32, shared + 12) == 0x80004001 and locks == 2);
    capture.capture_reset();
    check(@src(), releases == 5);
}
