const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn SetEnvironmentVariableA([*:0]const u8, ?[*:0]const u8) callconv(.winapi) i32;
extern "kernel32" fn GetSystemDirectoryW([*]u16, u32) callconv(.winapi) u32;
fn symbol(comptime T: type, module: usize, name: [*:0]const u8) T {
    const address = GetProcAddress(module, name);
    check(@src(), address != 0);
    return @ptrFromInt(address);
}
fn release(object: usize) void {
    const table = win.load(usize, object);
    const invoke: *const fn (usize) callconv(.winapi) u32 = @ptrFromInt(win.load(usize, table + 8));
    _ = invoke(object);
}
fn adapters(object: usize) u32 {
    const table = win.load(usize, object);
    const invoke: *const fn (usize) callconv(.winapi) u32 = @ptrFromInt(win.load(usize, table + 16));
    return invoke(object);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    check(@src(), args.len == 2);
    _ = SetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE", null);
    const proxy = LoadLibraryA(args[1]);
    check(@src(), proxy != 0);
    defer _ = win.FreeLibrary(proxy);
    for ([_][*:0]const u8{ "Direct3DCreate9", "Direct3DCreate9Ex", "D3DPERF_BeginEvent", "D3DPERF_EndEvent", "D3DPERF_SetMarker", "D3DPERF_SetRegion", "D3DPERF_SetOptions", "D3DPERF_GetStatus", "D3DPERF_QueryRepeatFrame", "DebugSetMute" }) |name| check(@src(), GetProcAddress(proxy, name) != 0);
    var system_path: [260]u16 = @splat(0);
    const length = GetSystemDirectoryW(&system_path, system_path.len);
    check(@src(), length != 0 and length + 10 < system_path.len);
    const suffix = std.unicode.utf8ToUtf16LeStringLiteral("\\d3d9.dll");
    @memcpy(system_path[length..][0 .. suffix.len + 1], suffix[0 .. suffix.len + 1]);
    const system = win.LoadLibraryW(@ptrCast(&system_path));
    check(@src(), system != 0 and system != proxy);
    defer _ = win.FreeLibrary(system);
    const Create = *const fn (u32) callconv(.winapi) usize;
    const create = symbol(Create, proxy, "Direct3DCreate9");
    const direct = symbol(Create, system, "Direct3DCreate9");
    check(@src(), create(0) == 0 and direct(0) == 0);
    const first = create(32);
    const second = direct(32);
    check(@src(), first != 0 and second != 0 and adapters(first) == adapters(second));
    release(first);
    release(second);
    const CreateEx = *const fn (u32, *usize) callconv(.winapi) i32;
    const ex = symbol(CreateEx, proxy, "Direct3DCreate9Ex");
    const direct_ex = symbol(CreateEx, system, "Direct3DCreate9Ex");
    var x: usize = 0;
    var y: usize = 0;
    check(@src(), ex(32, &x) == direct_ex(32, &y));
    if (x != 0) release(x);
    if (y != 0) release(y);
    const Options = *const fn (u32) callconv(.winapi) void;
    symbol(Options, proxy, "D3DPERF_SetOptions")(0);
    const Status = *const fn () callconv(.winapi) u32;
    check(@src(), symbol(Status, proxy, "D3DPERF_GetStatus")() == symbol(Status, system, "D3DPERF_GetStatus")());
}
