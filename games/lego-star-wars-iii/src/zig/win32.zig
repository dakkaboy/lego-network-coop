const std = @import("std");
pub const MemoryInfo = if (@sizeOf(usize) == 4) extern struct {
    base: usize,
    allocation_base: usize,
    allocation_protection: u32,
    region_size: usize,
    state: u32,
    protection: u32,
    kind: u32,
} else extern struct {
    base: usize,
    allocation_base: usize,
    allocation_protection: u32,
    partition: u16,
    region_size: usize,
    state: u32,
    protection: u32,
    kind: u32,
};
pub extern "kernel32" fn VirtualQuery(usize, *MemoryInfo, usize) callconv(.winapi) usize;
pub extern "kernel32" fn VirtualProtect(usize, usize, u32, *u32) callconv(.winapi) i32;
pub extern "kernel32" fn VirtualAlloc(usize, usize, u32, u32) callconv(.winapi) usize;
pub extern "kernel32" fn VirtualFree(usize, usize, u32) callconv(.winapi) i32;
pub extern "kernel32" fn GetLastError() callconv(.winapi) u32;
pub extern "kernel32" fn SetLastError(u32) callconv(.winapi) void;
pub extern "kernel32" fn GetCurrentThreadId() callconv(.winapi) u32;
pub extern "kernel32" fn GetCurrentProcess() callconv(.winapi) usize;
pub extern "kernel32" fn FlushInstructionCache(usize, usize, usize) callconv(.winapi) i32;
pub extern "kernel32" fn OpenProcess(u32, i32, u32) callconv(.winapi) usize;
pub extern "kernel32" fn ReadProcessMemory(usize, usize, [*]u8, usize, *usize) callconv(.winapi) i32;
pub extern "kernel32" fn CloseHandle(usize) callconv(.winapi) i32;
pub extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) u32;
pub extern "kernel32" fn LoadLibraryW([*:0]const u16) callconv(.winapi) usize;
pub extern "kernel32" fn FreeLibrary(usize) callconv(.winapi) i32;
pub extern "kernel32" fn TlsAlloc() callconv(.winapi) u32;
pub extern "kernel32" fn TlsGetValue(u32) callconv(.winapi) usize;
pub extern "kernel32" fn TlsSetValue(u32, usize) callconv(.winapi) i32;
pub extern "kernel32" fn RaiseException(u32, u32, u32, ?[*]const usize) callconv(.winapi) void;
pub extern "kernel32" fn GetModuleHandleA(?[*:0]const u8) callconv(.winapi) usize;

pub fn accessible(address: usize, length: usize, write: bool) bool {
    if (address == 0 or length > std.math.maxInt(usize) - address) return false;
    const end = address + length;
    var cursor = address;
    while (cursor < end) {
        var info: MemoryInfo = undefined;
        if (VirtualQuery(cursor, &info, @sizeOf(MemoryInfo)) == 0 or info.state != 0x1000 or info.protection & 0x101 != 0 or
            info.protection & @as(u32, if (write) 0xcc else 0xee) == 0 or cursor < info.base or cursor - info.base >= info.region_size) return false;
        cursor += @min(end - cursor, info.region_size - (cursor - info.base));
    }
    return true;
}
pub fn load(comptime T: type, address: usize) T {
    return @as(*align(1) const volatile T, @ptrFromInt(address)).*;
}

pub fn AccessCacheWithQuery(comptime query: anytype) type {
    return struct {
        regions: [16]MemoryInfo = undefined,
        count: usize = 0,
        next: usize = 0,
        pub fn accessible(self: *@This(), address: usize, length: usize, write: bool) bool {
            if (address == 0 or length > std.math.maxInt(usize) - address) return false;
            const end = address + length;
            var cursor = address;
            while (cursor < end) {
                var found: ?MemoryInfo = null;
                for (self.regions[0..self.count]) |region| {
                    if (cursor >= region.base and cursor - region.base < region.region_size) {
                        found = region;
                        break;
                    }
                }
                const region = found orelse blk: {
                    var info: MemoryInfo = undefined;
                    if (query(cursor, &info, @sizeOf(MemoryInfo)) == 0 or cursor < info.base or cursor - info.base >= info.region_size) return false;
                    self.regions[self.next] = info;
                    self.next = (self.next + 1) % self.regions.len;
                    self.count = @min(self.count + 1, self.regions.len);
                    break :blk info;
                };
                if (region.state != 0x1000 or region.protection & 0x101 != 0 or region.protection & @as(u32, if (write) 0xcc else 0xee) == 0) return false;
                cursor += @min(end - cursor, region.region_size - (cursor - region.base));
            }
            return true;
        }
    };
}

// Keep this cache inside one traversal; a later traversal must query permissions again.
pub const AccessCache = AccessCacheWithQuery(VirtualQuery);
pub fn store(comptime T: type, address: usize, value: T) void {
    @as(*align(1) volatile T, @ptrFromInt(address)).* = value;
}

test "memory: span readable regions and reject gaps, execute-only pages and overflow" {
    const allocation = VirtualAlloc(0, 0x3000, 0x3000, 4);
    try std.testing.expect(allocation != 0);
    defer _ = VirtualFree(allocation, 0, 0x8000);
    var old: u32 = 0;
    try std.testing.expect(VirtualProtect(allocation + 0x1000, 0x1000, 2, &old) != 0);
    try std.testing.expect(accessible(allocation + 0x800, 0x2000, false));
    try std.testing.expect(!accessible(allocation + 0x800, 0x2000, true));
    try std.testing.expect(VirtualProtect(allocation + 0x1000, 0x1000, 1, &old) != 0);
    try std.testing.expect(!accessible(allocation + 0x800, 0x2000, false));
    try std.testing.expect(VirtualProtect(allocation + 0x1000, 0x1000, 0x10, &old) != 0);
    try std.testing.expect(!accessible(allocation + 0x800, 0x2000, false));
    try std.testing.expect(!accessible(std.math.maxInt(usize) - 2, 4, false));
}

var access_query_count: usize = 0;
fn countedAccessQuery(address: usize, info: *MemoryInfo, length: usize) callconv(.winapi) usize {
    access_query_count += 1;
    return VirtualQuery(address, info, length);
}
test "memory: traversal cache shares permission queries and resets after protection changes" {
    const allocation = VirtualAlloc(0, 0x3000, 0x3000, 4);
    try std.testing.expect(allocation != 0);
    defer _ = VirtualFree(allocation, 0, 0x8000);
    var old: u32 = 0;
    try std.testing.expect(VirtualProtect(allocation + 0x1000, 0x1000, 2, &old) != 0);
    var cache: AccessCacheWithQuery(countedAccessQuery) = .{};
    access_query_count = 0;
    for (0..1000) |i| try std.testing.expect(cache.accessible(allocation + i, 4, true));
    try std.testing.expectEqual(@as(usize, 1), access_query_count);
    try std.testing.expect(cache.accessible(allocation + 0x800, 0x2000, false));
    try std.testing.expect(!cache.accessible(allocation + 0x800, 0x2000, true));
    try std.testing.expectEqual(@as(usize, 3), access_query_count);
    try std.testing.expect(!cache.accessible(0, 4, false));
    try std.testing.expect(!cache.accessible(std.math.maxInt(usize) - 2, 4, false));
    for ([_]u32{ 1, 0x10, 0x104, 4, 0x20, 0x40, 2 }) |protection| {
        try std.testing.expect(VirtualProtect(allocation + 0x1000, 0x1000, protection, &old) != 0);
        var fresh: AccessCache = .{};
        for ([_]bool{ false, true }) |write| {
            try std.testing.expectEqual(accessible(allocation + 0xfff, 2, write), fresh.accessible(allocation + 0xfff, 2, write));
        }
    }
    try std.testing.expect(VirtualFree(allocation + 0x1000, 0x1000, 0x4000) != 0);
    var fresh: AccessCache = .{};
    try std.testing.expect(!fresh.accessible(allocation + 0xfff, 2, false));
}
