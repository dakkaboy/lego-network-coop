const win = @import("win32.zig");
pub const Hash = struct {
    words: [4]u32 = .{ 2166136261, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35 },
    pub fn byte(self: *Hash, value: u8) void {
        for (&self.words, 0..) |*word, i| word.* = (word.* ^ value) *% (16777619 + 2 * @as(u32, @intCast(i)));
    }
    pub fn number(self: *Hash, value: u32) void {
        inline for (0..4) |i| self.byte(@truncate(value >> (8 * i)));
    }
    pub fn bytes(self: *Hash, values: []const u8) void {
        for (values) |value| self.byte(value);
    }
    pub fn text(self: *Hash, read: anytype, address: usize, capacity: usize, require_terminator: bool, length_prefix: bool) bool {
        var length: usize = 0;
        while (length < capacity) : (length += 1) {
            if (!read.readable(address + length, 1)) return false;
            if (win.load(u8, address + length) == 0) break;
        }
        if (require_terminator and (length == 0 or length == capacity)) return false;
        if (length_prefix) self.number(@intCast(length));
        for (0..length) |i| self.byte(win.load(u8, address + i));
        return true;
    }
};
