const win = @import("win32.zig");
pub extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.winapi) i32;
pub extern "kernel32" fn GetProcessHeap() callconv(.winapi) usize;
const heap_api = if (@hasDecl(@import("root"), "heap_test_api")) @import("root").heap_test_api else struct {
    pub extern "kernel32" fn HeapAlloc(usize, u32, usize) callconv(.winapi) usize;
    pub extern "kernel32" fn HeapFree(usize, u32, usize) callconv(.winapi) i32;
};
pub const HeapAlloc = heap_api.HeapAlloc;
pub const HeapFree = heap_api.HeapFree;
pub fn read(address: usize, output: []u8) bool {
    if (!win.accessible(address, output.len, false)) return false;
    @memcpy(output, @as([*]const u8, @ptrFromInt(address))[0..output.len]);
    return true;
}
pub fn word(address: usize) u32 {
    var value: u32 = 0;
    _ = read(address, @import("std").mem.asBytes(&value));
    return value;
}
pub fn timestamp(low: *u32, high: *u32) void {
    var q: i64 = 0;
    _ = QueryPerformanceCounter(&q);
    const bits: [2]u32 = @bitCast(q);
    low.* = bits[0];
    high.* = bits[1];
}
pub fn publish(target: anytype, record: anytype) void {
    @atomicStore(u32, &target.committed, 0, .seq_cst);
    target.* = record.*;
    @atomicStore(u32, &target.committed, record.id, .seq_cst);
}
pub fn increment(counter: *u32) u32 {
    return @atomicRmw(u32, counter, .Add, 1, .seq_cst) +% 1;
}
pub fn install(address: usize, prefix: []const u8, hook: usize) ?usize {
    const std = @import("std");
    if (!win.accessible(address, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..prefix.len], prefix)) return null;
    const bridge = win.VirtualAlloc(0, prefix.len + 5, 0x3000, 0x40);
    if (bridge == 0) return null;
    var old: u32 = 0;
    if (win.VirtualProtect(address, prefix.len, 0x40, &old) == 0) {
        _ = win.VirtualFree(bridge, 0, 0x8000);
        return null;
    }
    @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..prefix.len], prefix);
    win.store(u8, bridge + prefix.len, 0xe9);
    win.store(u32, bridge + prefix.len + 1, @truncate(address -% bridge -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, prefix.len + 5);
    win.store(u8, address, 0xe9);
    win.store(u32, address + 1, @truncate(hook -% address -% 5));
    for (5..prefix.len) |i| win.store(u8, address + i, 0x90);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), address, prefix.len);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(address, prefix.len, old, &ignored);
    return bridge;
}
