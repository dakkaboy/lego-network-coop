const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
var queries: u32 = 0;
var protection: u32 = 4;
var state: u32 = 0x1000;
var overflow = false;
var failure = false;
var suffix = false;
fn query(address: usize, info: *win.MemoryInfo, size: usize) callconv(.winapi) usize {
    check(@src(), size == @sizeOf(win.MemoryInfo));
    queries += 1;
    info.* = std.mem.zeroes(win.MemoryInfo);
    info.base = address & ~@as(usize, 0xfff);
    info.region_size = if (overflow) std.math.maxInt(usize) else 0x1000;
    info.state = state;
    info.protection = protection;
    if (suffix) {
        info.allocation_base = 0x10000;
        info.region_size = 0x16000 - info.base;
        if (address == 0x10000) {
            info.region_size = 0x1000;
            info.state = 0x2000;
            info.protection = 0;
        }
    }
    return if (failure) 0 else size;
}
fn nativeQuery(address: usize, info: *win.MemoryInfo, size: usize) callconv(.winapi) usize {
    queries += 1;
    return win.VirtualQuery(address, info, size);
}
pub fn main() void {
    const Cache = @import("list_memory.zig").Cache(query);
    var cache: Cache = .{};
    for (0..5000) |i| check(@src(), cache.contains(0x10000 + (i & 1) * 0x10000, 0x80));
    check(@src(), queries == 2);
    check(@src(), cache.contains(0x10f80, 0x80) and !cache.contains(0x10f81, 0x80) and !cache.contains(0, 4));
    for (0..40) |i| check(@src(), cache.contains(0x30000 + i * 0x1000, 4));
    check(@src(), cache.count == 32 and cache.contains(0x10000, 4));
    for ([_]u32{ 1, 0x100, 0x104 }) |value| {
        cache = .{};
        protection = value;
        check(@src(), !cache.contains(0x10000, 4) and cache.count == 0);
    }
    protection = 4;
    state = 0x2000;
    cache = .{};
    check(@src(), !cache.contains(0x10000, 4));
    state = 0x1000;
    overflow = true;
    check(@src(), !cache.contains(0x10000, 4));
    overflow = false;
    failure = true;
    check(@src(), !cache.contains(0x10000, 4));
    failure = false;
    check(@src(), cache.contains(0x10000, 4));
    var fresh: Cache = .{};
    protection = 1;
    check(@src(), !fresh.contains(0x10000, 4));
    protection = 4;
    suffix = true;
    queries = 0;
    cache = .{};
    check(@src(), cache.contains(0x14000, 0x80) and cache.contains(0x13000, 0x80) and cache.contains(0x12000, 0x80) and cache.contains(0x11000, 0x80));
    check(@src(), queries == 3 and !cache.contains(0x10000, 4));
    const allocation = win.VirtualAlloc(0, 0x100000, 0x2000, 1);
    check(@src(), allocation != 0);
    defer _ = win.VirtualFree(allocation, 0, 0x8000);
    check(@src(), win.VirtualAlloc(allocation + 0x5000, 0xfb000, 0x1000, 4) == allocation + 0x5000);
    var native_cache: @import("list_memory.zig").Cache(nativeQuery) = .{};
    queries = 0;
    for (0..100) |i| check(@src(), native_cache.contains(allocation + 0xff000 - i * 0x1000, 0x80));
    check(@src(), queries == 3);
    @memset(@as([*]u8, @ptrFromInt(allocation + 0x5000))[0..0xfb000], 1);
    var resident_cache: @import("list_memory.zig").ResidentCache(nativeQuery) = .{};
    queries = 0;
    for (0..100) |i| check(@src(), resident_cache.contains(allocation + 0xff000 - i * 0x1000, 0x80));
    check(@src(), queries == 0);
    check(@src(), resident_cache.contains(allocation + 0x9fff0, 32));
    check(@src(), queries == 0);
}
