const std = @import("std");
const win = @import("win32.zig");
const allocation = @import("allocation_region.zig");
const Page = extern struct { address: usize, flags: usize };
extern "kernel32" fn K32QueryWorkingSetEx(usize, *Page, u32) callconv(.winapi) c_int;
pub fn residentReadable(address: usize, bytes: usize) ?bool {
    var region: ?allocation.Info = null;
    return residentReadableInAllocation(address, bytes, &region);
}
pub fn residentReadableInAllocation(address: usize, bytes: usize, known: *?allocation.Info) ?bool {
    if (address == 0 or bytes == 0 or bytes - 1 > std.math.maxInt(usize) - address or bytes > 0x4000 - (address & 0xfff)) return null;
    const first = address & ~@as(usize, 0xfff);
    const count = ((address & 0xfff) + bytes - 1) / 0x1000 + 1;
    var pages: [4]Page = undefined;
    for (pages[0..count], 0..) |*page, i| page.* = .{ .address = first + i * 0x1000, .flags = 0 };
    if (K32QueryWorkingSetEx(win.GetCurrentProcess(), &pages[0], @intCast(count * @sizeOf(Page))) == 0) return null;
    return readablePages(address, bytes, pages[0..count], known);
}
fn readablePages(address: usize, bytes: usize, pages: []const Page, known: *?allocation.Info) ?bool {
    var protection: usize = 0;
    for (pages) |page| {
        if (page.flags & 1 == 0) return null;
        const current = (page.flags >> 4) & 0x7ff;
        if (current == 0) return null;
        if (current & 0x101 != 0 or (protection != 0 and current != protection)) return false;
        protection = current;
    }
    if (pages.len > 1) {
        if (known.* == null or address < known.*.?.base or address - known.*.?.base >= known.*.?.size)
            known.* = allocation.private(address);
        const region = known.* orelse return null;
        if (bytes > region.size - (address - region.base)) return false;
    }
    return true;
}
pub const ResidentPages = ResidentPagesWithQuery(K32QueryWorkingSetEx);
pub fn ResidentPagesWithQuery(comptime query: anytype) type {
    return struct {
        const Self = @This();
        pages: [128]Page = @splat(.{ .address = 0, .flags = 0 }),
        allocation_info: ?allocation.Info = null,
        fn get(self: *Self, address: usize) ?Page {
            const index = (address >> 12) & (self.pages.len - 1);
            if (self.pages[index].address != address) {
                var batch: [16]Page = undefined;
                const first = address & ~@as(usize, 0xffff);
                for (&batch, 0..) |*page, i| page.* = .{ .address = first + i * 0x1000, .flags = 0 };
                if (query(win.GetCurrentProcess(), &batch[0], @sizeOf(@TypeOf(batch))) == 0) return null;
                for (batch) |page| self.pages[(page.address >> 12) & (self.pages.len - 1)] = page;
            }
            return self.pages[index];
        }
        pub fn readable(self: *Self, address: usize, bytes: usize) ?bool {
            if (address == 0 or bytes == 0 or bytes - 1 > std.math.maxInt(usize) - address or bytes > 0x4000 - (address & 0xfff)) return null;
            const first = address & ~@as(usize, 0xfff);
            const count = ((address & 0xfff) + bytes - 1) / 0x1000 + 1;
            var requested: [4]Page = undefined;
            for (requested[0..count], 0..) |*page, i| page.* = self.get(first + i * 0x1000) orelse return null;
            return readablePages(address, bytes, requested[0..count], &self.allocation_info);
        }
    };
}
pub fn regionReadable(address: usize, bytes: usize) bool {
    var info: win.MemoryInfo = undefined;
    return address != 0 and win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.state == 0x1000 and info.protection & 0x101 == 0 and bytes <= std.math.maxInt(usize) - address and info.region_size <= std.math.maxInt(usize) - info.base and address + bytes <= info.base + info.region_size;
}
pub fn readable(address: usize, bytes: usize) bool {
    return residentReadable(address, bytes) orelse regionReadable(address, bytes);
}
