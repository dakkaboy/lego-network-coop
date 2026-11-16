const std = @import("std");
const win = @import("win32.zig");
const com = @import("com.zig");
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern "kernel32" fn QueryPerformanceFrequency(*i64) callconv(.winapi) i32;
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.winapi) i32;
extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
extern "kernel32" fn CreateFileMappingA(usize, usize, u32, u32, u32, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn MapViewOfFile(usize, u32, u32, u32, usize) callconv(.winapi) usize;
var gpu: usize = 0;
var cpu: usize = 0;
var shared: usize = 0;
var mapping: usize = 0;
var enabled: i32 = -1;
var width: u32 = 1280;
var height: u32 = 720;
var fps: u32 = 15;
var frequency: i64 = 0;
var last_capture: i64 = 0;
var capture_device: usize = 0;
pub export var clonewars_capture_info: [8]u32 = @splat(0);
const Description = extern struct { format: u32, kind: u32, usage: u32, pool: u32, multisample: u32, quality: u32, width: u32, height: u32 };
const Locked = extern struct { pitch: i32, bits: usize };
pub export fn capture_reset() void {
    com.release(gpu);
    com.release(cpu);
    gpu = 0;
    cpu = 0;
}
fn setting(name: [*:0]const u8, fallback: u32, low: u32, high: u32) u32 {
    var text: [24]u8 = undefined;
    const length = GetEnvironmentVariableA(name, &text, text.len);
    if (length == 0 or length >= text.len) return fallback;
    const value = std.fmt.parseInt(u32, std.mem.trimStart(u8, text[0..length], " \t\r\n\x0b\x0c"), 10) catch return fallback;
    return if (value >= low and value <= high) value else fallback;
}
fn publish(back: usize, device: usize) i32 {
    var desc: Description = undefined;
    _ = com.method(*const fn (usize, *Description) callconv(.winapi) i32, back, 12)(back, &desc);
    clonewars_capture_info[3] = desc.width;
    clonewars_capture_info[4] = desc.height;
    if (desc.format != 22 and desc.format != 21) return @bitCast(@as(u32, 0x80004001));
    var hr: i32 = 0;
    if (gpu == 0) hr = com.method(*const fn (usize, u32, u32, u32, u32, u32, i32, *usize, usize) callconv(.winapi) i32, device, 28)(device, width, height, desc.format, 0, 0, 0, &gpu, 0);
    if (hr >= 0 and cpu == 0) hr = com.method(*const fn (usize, u32, u32, u32, u32, *usize, usize) callconv(.winapi) i32, device, 36)(device, width, height, desc.format, 2, &cpu, 0);
    if (hr >= 0) hr = com.method(*const fn (usize, usize, usize, usize, usize, u32) callconv(.winapi) i32, device, 34)(device, back, 0, gpu, 0, 2);
    if (hr >= 0) hr = com.method(*const fn (usize, usize, usize) callconv(.winapi) i32, device, 32)(device, gpu, cpu);
    if (hr >= 0) {
        var locked: Locked = undefined;
        hr = com.method(*const fn (usize, *Locked, usize, u32) callconv(.winapi) i32, cpu, 13)(cpu, &locked, 0, 0x10);
        if (hr >= 0) {
            _ = @atomicRmw(u32, @as(*u32, @ptrFromInt(shared)), .Add, 1, .seq_cst);
            win.store(u32, shared + 4, width);
            win.store(u32, shared + 8, height);
            win.store(u32, shared + 20, fps);
            for (0..height) |y| {
                const source = locked.bits +% @as(usize, @bitCast(@as(isize, locked.pitch) * @as(isize, @intCast(y))));
                @memcpy(@as([*]u8, @ptrFromInt(shared + 24 + y * width * 4))[0 .. width * 4], @as([*]const u8, @ptrFromInt(source))[0 .. width * 4]);
            }
            win.store(u32, shared + 16, GetTickCount());
            clonewars_capture_info[5] +%= 1;
            _ = @atomicRmw(u32, @as(*u32, @ptrFromInt(shared)), .Add, 1, .seq_cst);
            _ = com.method(*const fn (usize) callconv(.winapi) i32, cpu, 14)(cpu);
        }
    }
    return hr;
}
pub export fn capture_frame(device: usize) void {
    if (enabled < 0) {
        var text: [8]u8 = @splat(0);
        enabled = @intFromBool(GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE", &text, text.len) > 0 and text[0] == '1');
        width = setting("CLONEWARS_CAPTURE_WIDTH", 1280, 640, 3840);
        height = setting("CLONEWARS_CAPTURE_HEIGHT", 720, 360, 2160);
        fps = setting("CLONEWARS_CAPTURE_FPS", 15, 1, 60);
        _ = QueryPerformanceFrequency(&frequency);
        clonewars_capture_info[0] = width;
        clonewars_capture_info[1] = height;
        clonewars_capture_info[2] = fps;
    }
    if (enabled == 0) return;
    var now: i64 = 0;
    _ = QueryPerformanceCounter(&now);
    const elapsed = now - last_capture;
    if (last_capture != 0 and elapsed * fps < frequency) return;
    if (last_capture == 0 or elapsed * fps > 2 * frequency) last_capture = now else last_capture += @divTrunc(frequency, fps);
    if (capture_device != device) {
        capture_reset();
        capture_device = device;
    }
    if (shared == 0) {
        var name: [80]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&name);
        writer.print("Local\\CloneWarsCapture{d}", .{win.GetCurrentProcessId()}) catch return;
        writer.writeByte(0) catch return;
        const label: [*:0]const u8 = @ptrCast(&name);
        const handle = CreateFileMappingA(std.math.maxInt(usize), 0, 4, 0, 24 + width * height * 4, label);
        if (handle == 0) return;
        shared = MapViewOfFile(handle, 0xf001f, 0, 0, 0);
        if (shared != 0) mapping = handle else {
            _ = win.CloseHandle(handle);
            return;
        }
    }
    var back: usize = 0;
    var hr = com.method(*const fn (usize, u32, u32, u32, *usize) callconv(.winapi) i32, device, 18)(device, 0, 0, 0, &back);
    if (hr >= 0) {
        hr = publish(back, device);
        com.release(back);
    }
    win.store(u32, shared + 12, @bitCast(hr));
    clonewars_capture_info[6] = @bitCast(hr);
}
