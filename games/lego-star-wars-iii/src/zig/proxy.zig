const std = @import("std");
const win = @import("win32.zig");
const com = @import("com.zig");
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
extern "kernel32" fn GetSystemDirectoryW([*]u16, u32) callconv(.winapi) u32;
extern "kernel32" fn GetModuleFileNameW(usize, [*]u16, u32) callconv(.winapi) u32;
extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn InitOnceExecuteOnce(*usize, *const fn (*usize, usize, usize) callconv(.winapi) i32, usize, usize) callconv(.winapi) i32;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern "kernel32" fn GetPrivateProfileIntW([*:0]const u16, [*:0]const u16, i32, [*:0]const u16) callconv(.winapi) u32;
extern "kernel32" fn DisableThreadLibraryCalls(usize) callconv(.winapi) i32;
var real_d3d9: usize = 0;
var proxy_module: usize = 0;
var once: usize = 0;
var prepared: i32 = 0;
var profile: [260]u8 = @splat(0);
const FolderPath = *const fn (usize, i32, usize, u32, [*:0]u8) callconv(.winapi) i32;
var original_folder: FolderPath = undefined;
fn wide(comptime value: []const u8) *const [std.unicode.calcUtf16LeLen(value) catch unreachable:0]u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(value);
}
fn folderPath(owner: usize, folder: i32, token: usize, flags: u32, path: [*:0]u8) callconv(.winapi) i32 {
    if (folder & 0xff == 0x1a and profile[0] != 0) {
        const length = std.mem.indexOfScalar(u8, &profile, 0).?;
        @memcpy(path[0 .. length + 1], profile[0 .. length + 1]);
        return 0;
    }
    return original_folder(owner, folder, token, flags, path);
}
fn loadReal(_: *usize, _: usize, _: usize) callconv(.winapi) i32 {
    var path: [260]u16 = undefined;
    const length = GetSystemDirectoryW(&path, path.len);
    if (length == 0 or length + 10 >= path.len) return 0;
    const filename = wide("\\d3d9.dll");
    @memcpy(path[length .. length + filename.len + 1], filename[0 .. filename.len + 1]);
    real_d3d9 = win.LoadLibraryW(@ptrCast(&path));
    return @intFromBool(real_d3d9 != 0);
}
fn resolve(comptime Function: type, name: [*:0]const u8) ?Function {
    if (InitOnceExecuteOnce(&once, loadReal, 0, 0) == 0) return null;
    const address = GetProcAddress(real_d3d9, name);
    return if (address != 0) @ptrFromInt(address) else null;
}
fn adjacent(path: *[260]u16, comptime filename: []const u8) bool {
    path.* = @splat(0);
    _ = GetModuleFileNameW(proxy_module, path, path.len);
    const end = std.mem.indexOfScalar(u16, path, 0) orelse return false;
    const separator = std.mem.lastIndexOfScalar(u16, path[0..end], '\\') orelse return false;
    if (separator + 23 >= path.len) return false;
    const text = wide(filename);
    @memcpy(path[separator + 1 .. separator + 2 + text.len], text[0 .. text.len + 1]);
    return true;
}
fn prepareGame() void {
    if (@atomicRmw(i32, &prepared, .Xchg, 1, .seq_cst) != 0) return;
    const base = win.GetModuleHandleA(null);
    if (base != 0x400000) return;
    const headers = base + win.load(u32, base + 0x3c);
    if (win.load(u32, headers + 8) != 0x4d5abe1c or win.load(u16, headers + 4) != 0x14c) return;
    win.store(i32, 0xf92280, 1);
    const address: usize = 0x63d633;
    const expected = "\x3b\x05\x04\xf0\xfd\x00";
    const primary = "\x83\xf8\x01\x90\x90\x90";
    var protection: u32 = 0;
    if (std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..6], expected) and win.VirtualProtect(address, 6, 0x40, &protection) != 0) {
        // Each network instance binds player one's devices instead of using the native instance counter.
        @memcpy(@as([*]u8, @ptrFromInt(address))[0..6], primary);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), address, 6);
        _ = win.VirtualProtect(address, 6, protection, &protection);
    }
    const length = GetEnvironmentVariableA("CLONEWARS_PROFILE", &profile, profile.len);
    if (length >= profile.len) profile[0] = 0;
    if (profile[0] != 0) {
        const entry: *usize = @ptrFromInt(0xabf25c);
        original_folder = @ptrFromInt(entry.*);
        var old: u32 = 0;
        if (win.VirtualProtect(@intFromPtr(entry), 4, 4, &old) != 0) {
            _ = @atomicRmw(usize, entry, .Xchg, @intFromPtr(&folderPath), .seq_cst);
            _ = win.VirtualProtect(@intFromPtr(entry), 4, old, &old);
        }
    }
    var path: [260]u16 = undefined;
    if (adjacent(&path, "clonewars-camera.dll")) _ = win.LoadLibraryW(@ptrCast(&path));
}
const Parameters = extern struct {
    back_width: u32,
    back_height: u32,
    back_format: u32,
    back_count: u32,
    multisample: u32,
    quality: u32,
    swap_effect: u32,
    window: usize,
    windowed: i32,
    auto_depth: i32,
    depth_format: u32,
    flags: u32,
    fullscreen_refresh: u32,
    interval: u32,
};
const CreateDevice = *const fn (usize, u32, u32, usize, u32, *Parameters, *usize) callconv(.winapi) i32;
var original_create: CreateDevice = undefined;
fn createDevice(api: usize, adapter: u32, kind: u32, window: usize, flags: u32, parameters: *Parameters, device: *usize) callconv(.winapi) i32 {
    parameters.windowed = 1;
    parameters.fullscreen_refresh = 0;
    win.store(i32, 0xf92730, 1);
    return original_create(api, adapter, kind, window, flags, parameters, device);
}
fn backgroundDevice(api: usize) void {
    if (api == 0) return;
    var value: [8]u8 = @splat(0);
    var windowed = GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE", &value, value.len) == 1 and value[0] == '1';
    var config: [260]u16 = undefined;
    if (adjacent(&config, "clonewars-display.ini")) windowed = windowed or GetPrivateProfileIntW(wide("Display"), wide("Windowed"), -1, @ptrCast(&config)) == 1;
    if (!windowed) return;
    const slot: *usize = @ptrFromInt(win.load(usize, api) + 16 * 4);
    if (slot.* == @intFromPtr(&createDevice)) return;
    var old: u32 = 0;
    if (win.VirtualProtect(@intFromPtr(slot), 4, 4, &old) == 0) return;
    original_create = @ptrFromInt(slot.*);
    slot.* = @intFromPtr(&createDevice);
    _ = win.VirtualProtect(@intFromPtr(slot), 4, old, &old);
}
pub export fn Direct3DCreate9(version: u32) callconv(.winapi) usize {
    const function = resolve(*const fn (u32) callconv(.winapi) usize, "Direct3DCreate9");
    prepareGame();
    const api = if (function) |f| f(version) else 0;
    backgroundDevice(api);
    return api;
}
pub export fn Direct3DCreate9Ex(version: u32, device: *usize) callconv(.winapi) i32 {
    const f = resolve(*const fn (u32, *usize) callconv(.winapi) i32, "Direct3DCreate9Ex") orelse return @bitCast(@as(u32, 0x80004001));
    return f(version, device);
}
pub export fn D3DPERF_BeginEvent(color: u32, name: [*:0]const u16) callconv(.winapi) i32 {
    const f = resolve(*const fn (u32, [*:0]const u16) callconv(.winapi) i32, "D3DPERF_BeginEvent") orelse return -1;
    return f(color, name);
}
pub export fn D3DPERF_EndEvent() callconv(.winapi) i32 {
    const f = resolve(*const fn () callconv(.winapi) i32, "D3DPERF_EndEvent") orelse return -1;
    return f();
}
fn marker(name: [*:0]const u8, color: u32, value: [*:0]const u16) void {
    const f = resolve(*const fn (u32, [*:0]const u16) callconv(.winapi) void, name) orelse return;
    f(color, value);
}
pub export fn D3DPERF_SetMarker(color: u32, name: [*:0]const u16) callconv(.winapi) void {
    marker("D3DPERF_SetMarker", color, name);
}
pub export fn D3DPERF_SetRegion(color: u32, name: [*:0]const u16) callconv(.winapi) void {
    marker("D3DPERF_SetRegion", color, name);
}
pub export fn D3DPERF_SetOptions(options: u32) callconv(.winapi) void {
    const f = resolve(*const fn (u32) callconv(.winapi) void, "D3DPERF_SetOptions") orelse return;
    f(options);
}
pub export fn D3DPERF_GetStatus() callconv(.winapi) u32 {
    const f = resolve(*const fn () callconv(.winapi) u32, "D3DPERF_GetStatus") orelse return 0;
    return f();
}
pub export fn D3DPERF_QueryRepeatFrame() callconv(.winapi) i32 {
    const f = resolve(*const fn () callconv(.winapi) i32, "D3DPERF_QueryRepeatFrame") orelse return 0;
    return f();
}
pub export fn DebugSetMute() callconv(.winapi) void {
    const f = resolve(*const fn () callconv(.winapi) void, "DebugSetMute") orelse return;
    f();
}
pub export fn DllMain(module: usize, reason: u32, _: usize) callconv(.winapi) i32 {
    if (reason == 1) {
        proxy_module = module;
        _ = DisableThreadLibraryCalls(module);
    }
    return 1;
}
