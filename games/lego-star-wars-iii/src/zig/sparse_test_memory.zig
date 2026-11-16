const std = @import("std");
const check = @import("native_test_support.zig").check;
const allocator = std.heap.page_allocator;
const Region = struct { base: u32, bytes: []u8, writable: bool };
pub const Memory = struct {
    regions: [32]Region = undefined,
    count: usize = 0,
    mutate_on: u32 = 0,
    mutate_address: u32 = 0,
    mutate_value: u32 = 0,
    pub fn add(self: *Memory, base: u32, size: usize, writable: bool) void {
        check(@src(), self.count < self.regions.len);
        const data = allocator.alloc(u8, size) catch @panic("test allocation failed");
        @memset(data, 0);
        self.regions[self.count] = .{ .base = base, .bytes = data, .writable = writable };
        self.count += 1;
    }
    pub fn deinit(self: *Memory) void {
        for (self.regions[0..self.count]) |region| allocator.free(region.bytes);
        self.count = 0;
    }
    pub fn clone(self: *const Memory) Memory {
        var result = Memory{};
        result.mutate_on = self.mutate_on;
        result.mutate_address = self.mutate_address;
        result.mutate_value = self.mutate_value;
        for (self.regions[0..self.count]) |region| {
            result.add(region.base, region.bytes.len, region.writable);
            @memcpy(result.regions[result.count - 1].bytes, region.bytes);
        }
        return result;
    }
    fn locate(self: *Memory, address: u32, size: usize) ?*Region {
        for (self.regions[0..self.count]) |*entry| if (address >= entry.base and size <= entry.bytes.len and address - entry.base <= entry.bytes.len - size) return entry;
        return null;
    }
    pub fn find(self: *Memory, address: u32, size: usize) *Region {
        return self.locate(address, size) orelse @panic("fixture address missing");
    }
    pub fn put(self: *Memory, comptime T: type, address: u32, value: T) void {
        const entry = self.find(address, @sizeOf(T));
        @memcpy(entry.bytes[address - entry.base ..][0..@sizeOf(T)], std.mem.asBytes(&value));
    }
    pub fn range(raw: usize, address: u32, size: usize, writable: i32) callconv(.c) i32 {
        const self: *Memory = @ptrFromInt(raw);
        const entry = self.locate(address, size) orelse return 0;
        return @intFromBool(writable == 0 or entry.writable);
    }
    pub fn read(raw: usize, address: u32, out: *anyopaque, size: usize) callconv(.c) i32 {
        const self: *Memory = @ptrFromInt(raw);
        const entry = self.locate(address, size) orelse return 0;
        @memcpy(@as([*]u8, @ptrCast(out))[0..size], entry.bytes[address - entry.base ..][0..size]);
        if (self.mutate_on == address) {
            self.mutate_on = 0;
            self.put(u32, self.mutate_address, self.mutate_value);
        }
        return 1;
    }
};
