const std = @import("std");
const win = @import("win32.zig");
const Region = struct { first: usize, last: usize, allocation: usize, state: u32, protection: u32 };
pub const Reader = struct {
    regions: [32]Region = undefined,
    count: usize = 0,
    image: usize,
    pub fn init() Reader {
        return .{ .image = win.GetModuleHandleA(null) };
    }
    fn region(self: *Reader, address: usize) ?Region {
        for (self.regions[0..self.count]) |r| if (address >= r.first and address < r.last) return r;
        var info: win.MemoryInfo = undefined;
        if (win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) == 0 or info.region_size > std.math.maxInt(usize) - info.base or info.region_size == 0) return null;
        const r: Region = .{ .first = info.base, .last = info.base + info.region_size, .allocation = info.allocation_base, .state = info.state, .protection = info.protection };
        if (self.count < self.regions.len) {
            self.regions[self.count] = r;
            self.count += 1;
        }
        return r;
    }
    pub fn readable(self: *Reader, address: usize, bytes: usize) bool {
        if (address == 0 or bytes == 0 or bytes > std.math.maxInt(usize) - address) return false;
        var cursor = address;
        const end = address + bytes;
        while (cursor < end) {
            const r = self.region(cursor) orelse return false;
            if (r.state != 0x1000 or r.protection & 0x101 != 0) return false;
            cursor = @min(r.last, end);
        }
        return true;
    }
    pub fn imageClass(self: *Reader, object: usize, rva: *u32) bool {
        if (!self.readable(object, 4)) return false;
        return self.imageOffset(win.load(usize, object), rva);
    }
    pub fn imageOffset(self: *Reader, address: usize, rva: *u32) bool {
        return self.imageAddress(address, rva, false);
    }
    pub fn imageAddress(self: *Reader, address: usize, rva: *u32, executable: bool) bool {
        if (address <= self.image) return false;
        const r = self.region(address) orelse return false;
        if (r.allocation != self.image or r.state != 0x1000 or r.protection & 0x101 != 0) return false;
        if (executable and r.protection & 0xf0 == 0) return false;
        rva.* = @intCast(address - self.image);
        return true;
    }
    pub fn native(self: *const Reader, address: usize) usize {
        return self.image + address - 0x400000;
    }
    pub fn nameLength(self: *Reader, address: usize) u32 {
        if (address == 0) return 0;
        for (0..1024) |i| {
            if (!self.readable(address + i, 1)) return 0;
            if (win.load(u8, address + i) == 0) return if (i > 0) @intCast(i + 1) else 0;
        }
        return 0;
    }
    pub fn sameName(self: *Reader, first: usize, second: usize) bool {
        const length = self.nameLength(first);
        if (length == 0 or self.nameLength(second) != length) return false;
        return std.mem.eql(u8, @as([*]const u8, @ptrFromInt(first))[0..length], @as([*]const u8, @ptrFromInt(second))[0..length]);
    }
};
