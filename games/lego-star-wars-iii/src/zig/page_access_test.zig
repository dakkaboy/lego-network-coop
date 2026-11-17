const std = @import("std");
const access = @import("page_access.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
extern "kernel32" fn CreateFileMappingW(usize, ?*anyopaque, u32, u32, u32, ?[*:0]const u16) callconv(.winapi) usize;
extern "kernel32" fn MapViewOfFile(usize, u32, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn UnmapViewOfFile(usize) callconv(.winapi) c_int;
extern "kernel32" fn K32QueryWorkingSetEx(usize, *anyopaque, u32) callconv(.winapi) c_int;
var working_set_calls: u32 = 0;
var working_set_failure = false;
fn countedWorkingSet(process: usize, buffer: *anyopaque, bytes: u32) callconv(.winapi) c_int {
    working_set_calls += 1;
    return if (working_set_failure) 0 else K32QueryWorkingSetEx(process, buffer, bytes);
}
const Batch = access.ResidentPagesWithQuery(countedWorkingSet);
fn allocationBoundary() void {
    const reserved = win.VirtualAlloc(0, 0x20000, 0x2000, 4);
    check(@src(), reserved != 0);
    check(@src(), win.VirtualFree(reserved, 0, 0x8000) != 0);
    const first = win.VirtualAlloc(reserved, 0x10000, 0x3000, 4);
    check(@src(), first == reserved);
    defer _ = win.VirtualFree(first, 0, 0x8000);
    const second = win.VirtualAlloc(reserved + 0x10000, 0x10000, 0x3000, 4);
    check(@src(), second == reserved + 0x10000);
    defer _ = win.VirtualFree(second, 0, 0x8000);
    @memset(@as([*]u8, @ptrFromInt(first))[0..0x10000], 1);
    @memset(@as([*]u8, @ptrFromInt(second))[0..0x10000], 1);
    check(@src(), access.residentReadable(second - 16, 32) == false);
    check(@src(), !access.readable(second - 16, 32) and !access.regionReadable(second - 16, 32));
    var known: ?@import("allocation_region.zig").Info = null;
    check(@src(), access.residentReadableInAllocation(first + 0xff0, 32, &known) == true);
    check(@src(), known.?.base == first);
    check(@src(), access.residentReadableInAllocation(second - 16, 32, &known) == false);
    check(@src(), access.residentReadableInAllocation(second + 0xff0, 32, &known) == true and known.?.base == second);
    var cache: Batch = .{};
    check(@src(), cache.readable(first + 0xff0, 32) == true and cache.readable(second - 16, 32) == false and cache.readable(second + 0xff0, 32) == true);
}
fn mappedPages() void {
    const mapping = CreateFileMappingW(std.math.maxInt(usize), null, 4, 0, 0x3000, null);
    check(@src(), mapping != 0);
    defer _ = win.CloseHandle(mapping);
    const view = MapViewOfFile(mapping, 2, 0, 0, 0x3000);
    check(@src(), view != 0);
    defer _ = UnmapViewOfFile(view);
    @memset(@as([*]u8, @ptrFromInt(view))[0..0x3000], 1);
    check(@src(), @import("allocation_region.zig").private(view) == null);
    check(@src(), access.residentReadable(view + 0xff0, 32) == null and access.readable(view + 0xff0, 32));
    var cache: Batch = .{};
    check(@src(), cache.readable(view + 16, 32) == true and cache.readable(view + 0xff0, 32) == null);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(view + 0x1000, 0x1000, 2, &old) != 0);
    check(@src(), !access.readable(view + 0xff0, 32) and !access.regionReadable(view + 0xff0, 32));
}
fn batchedPages() void {
    const allocation = win.VirtualAlloc(0, 0x100000, 0x3000, 4);
    check(@src(), allocation != 0);
    defer _ = win.VirtualFree(allocation, 0, 0x8000);
    @memset(@as([*]u8, @ptrFromInt(allocation))[0..0x100000], 1);
    var cache: Batch = .{};
    working_set_calls = 0;
    for (0..100) |i| check(@src(), cache.readable(allocation + 0xff000 - i * 0x1000, 0x80) == true);
    check(@src(), working_set_calls == 7);
    for (0..5000) |i| check(@src(), cache.readable(allocation + 0xf0010 + (i % 16) * 0x1000, 0x80) == true);
    check(@src(), working_set_calls == 7);
    check(@src(), cache.readable(allocation + 0xafff0, 32) == true and cache.readable(allocation + 0xbfff0, 32) == true);
    check(@src(), working_set_calls == 7);
    var old: u32 = 0;
    for ([_]u32{ 1, 2, 4, 0x10, 0x20, 0x40, 0x104 }) |protection| {
        check(@src(), win.VirtualProtect(allocation + 0x1000, 0x1000, protection, &old) != 0);
        cache = .{};
        if (cache.readable(allocation + 0x1010, 0x80)) |actual| check(@src(), actual == access.regionReadable(allocation + 0x1010, 0x80));
        if (cache.readable(allocation + 0xff0, 32)) |actual| check(@src(), actual == access.regionReadable(allocation + 0xff0, 32));
    }
    check(@src(), win.VirtualFree(allocation + 0x1000, 0x1000, 0x4000) != 0);
    cache = .{};
    check(@src(), cache.readable(allocation + 0xff0, 32) != true and !access.regionReadable(allocation + 0xff0, 32));
    working_set_failure = true;
    cache = .{};
    working_set_calls = 0;
    check(@src(), cache.readable(allocation + 0x2010, 32) == null and working_set_calls == 1);
    working_set_failure = false;
    check(@src(), cache.readable(allocation + 0x2010, 32) == true and working_set_calls == 2);
    check(@src(), cache.readable(0, 1) == null and cache.readable(std.math.maxInt(usize) - 3, 8) == null and cache.readable(allocation, 0) == null and working_set_calls == 2);
}
pub fn main() void {
    allocationBoundary();
    mappedPages();
    batchedPages();
    prefetchedPages();
    const allocation = win.VirtualAlloc(0, 0x4000, 0x3000, 4);
    check(@src(), allocation != 0);
    defer _ = win.VirtualFree(allocation, 0, 0x8000);
    @memset(@as([*]u8, @ptrFromInt(allocation))[0..0x4000], 1);
    check(@src(), access.residentReadable(allocation + 16, 32) == true);
    check(@src(), access.readable(0, 4) == false and !access.readable(std.math.maxInt(usize) - 3, 8));
    check(@src(), access.readable(allocation, 0) == access.regionReadable(allocation, 0));
    var old: u32 = 0;
    for ([_]u32{ 1, 2, 4, 0x10, 0x20, 0x40, 0x104 }) |protection| {
        check(@src(), win.VirtualProtect(allocation + 0x1000, 0x1000, protection, &old) != 0);
        const actual = access.readable(allocation + 0x1010, 0x80);
        check(@src(), actual == access.regionReadable(allocation + 0x1010, 0x80));
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(allocation + 0x1000, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == protection);
    }
    check(@src(), win.VirtualProtect(allocation + 0x1000, 0x1000, 2, &old) != 0);
    check(@src(), access.residentReadable(allocation + 0x1ff0, 32) != true and !access.readable(allocation + 0x1ff0, 32));
    check(@src(), win.VirtualProtect(allocation + 0x1000, 0x1000, 4, &old) != 0);
    check(@src(), access.readable(allocation + 0x1ff0, 32));
    check(@src(), win.VirtualFree(allocation + 0x1000, 0x1000, 0x4000) != 0);
    check(@src(), !access.readable(allocation + 0x1010, 0x80) and !access.readable(allocation + 0xff0, 0x1020));
    check(@src(), win.VirtualAlloc(allocation + 0x1000, 0x1000, 0x1000, 4) == allocation + 0x1000);
    check(@src(), access.readable(allocation + 0x1010, 0x80));
    @memset(@as([*]u8, @ptrFromInt(allocation))[0..0x4000], 1);
    const region = @import("allocation_region.zig").private(allocation + 0x1010).?;
    check(@src(), region.base == allocation and region.size == 0x4000 and region.committed == 0x4000);
    check(@src(), access.residentReadable(allocation + 0x1ff0, 32) == true and access.residentReadable(allocation + 16, 0x4000) == null);
}
fn prefetchedPages() void {
    const allocation = win.VirtualAlloc(0, 0x400000, 0x3000, 4);
    check(@src(), allocation != 0);
    defer _ = win.VirtualFree(allocation, 0, 0x8000);
    @memset(@as([*]u8, @ptrFromInt(allocation))[0..0x400000], 1);
    var cache: Batch = .{};
    var addresses: [6]usize = undefined;
    for (&addresses, 0..) |*address, i| address.* = allocation + i * 0x80000;
    working_set_calls = 0;
    cache.prefetch(&addresses);
    for (addresses) |address| check(@src(), cache.readable(address + 16, 32) == true);
    check(@src(), working_set_calls == 1);
    var remembered: [128]usize = undefined;
    const count = cache.hints(&remembered);
    check(@src(), count == addresses.len);
    check(@src(), cache.readable(addresses[0] + 0x1010, 32) == true);
    for (addresses) |address| check(@src(), cache.readable(address + 16, 32) == true);
    check(@src(), working_set_calls <= 3);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(addresses[2], 0x1000, 1, &old) != 0);
    cache = .{};
    cache.prefetch(remembered[0..count]);
    check(@src(), cache.readable(addresses[2] + 16, 32) != true);
    check(@src(), win.VirtualProtect(addresses[2], 0x1000, 4, &old) != 0);
    @as(*volatile u8, @ptrFromInt(addresses[2])).* = 1;
    cache = .{};
    working_set_failure = true;
    working_set_calls = 0;
    cache.prefetch(&addresses);
    check(@src(), working_set_calls == 1);
    working_set_failure = false;
    check(@src(), cache.readable(addresses[2] + 16, 32) == true and working_set_calls == 2);
    cache = .{};
    cache.prefetch(&.{ 0, allocation + 1 });
    check(@src(), working_set_calls == 2);
}
