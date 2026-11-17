const std = @import("std");
const win = @import("win32.zig");
pub fn Cache(comptime query: anytype) type {
    return makeCache(query, null);
}
pub fn ResidentCache(comptime query: anytype) type {
    return ResidentCacheWithPages(query, @import("page_access.zig").ResidentPages);
}
pub fn ResidentCacheWithPages(comptime query: anytype, comptime Pages: type) type {
    return makeCache(query, Pages);
}
fn makeCache(comptime query: anytype, comptime Pages: ?type) type {
    return struct {
        const Self = @This();
        const Region = struct { first: usize, last: usize };
        regions: [32]Region = undefined,
        count: usize = 0,
        next: usize = 0,
        resident_pages: if (Pages) |T| T else void = if (Pages != null) .{} else {},
        fn remember(self: *Self, region: Region) void {
            self.regions[self.next] = region;
            self.next = (self.next + 1) % self.regions.len;
            self.count = @min(self.count + 1, self.regions.len);
        }
        pub fn contains(self: *Self, address: usize, size: usize) bool {
            if (address == 0) return false;
            for (self.regions[0..self.count]) |region| if (address >= region.first and address < region.last and size <= region.last - address) return true;
            if (comptime Pages != null) {
                if (self.resident_pages.readable(address, size)) |result| return result;
            }
            var info: win.MemoryInfo = undefined;
            if (query(address, &info, @sizeOf(win.MemoryInfo)) == 0 or info.state != 0x1000 or info.protection & 0x101 != 0 or info.region_size > std.math.maxInt(usize) - info.base) return false;
            var region = Region{ .first = info.base, .last = info.base + info.region_size };
            // VirtualQuery reports a suffix starting at the requested page; descending lists need the region's lower bound.
            if (info.allocation_base != 0 and info.allocation_base < info.base) {
                var cursor = info.allocation_base;
                for (0..8) |_| {
                    var lower: win.MemoryInfo = undefined;
                    if (query(cursor, &lower, @sizeOf(win.MemoryInfo)) == 0 or lower.allocation_base != info.allocation_base or lower.region_size > std.math.maxInt(usize) - lower.base) break;
                    const end = lower.base + lower.region_size;
                    if (address >= lower.base and address < end) {
                        if (lower.state != 0x1000 or lower.protection & 0x101 != 0) return false;
                        region = .{ .first = lower.base, .last = end };
                        break;
                    }
                    if (end <= cursor or end > address) break;
                    cursor = end;
                }
            }
            self.remember(region);
            return address >= region.first and address < region.last and size <= region.last - address;
        }
    };
}
