const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
fn numbers(read: *Reader, hash: *Hash, address: usize, comptime count: usize, nonnegative: bool) bool {
    if (!read.readable(address, count * 4)) return false;
    const values = win.load([count]f32, address);
    for (values) |value| {
        if (!std.math.isFinite(value) or (nonnegative and value < 0)) return false;
        hash.number(if (value == 0) 0 else @as(u32, @bitCast(value)));
    }
    return true;
}
pub fn geometry(read: *Reader, hash: *Hash, shape: usize, class: u32) bool {
    // Native copies a190b0/a1a4a0 retain these local dimensions, not the unused header bytes.
    return switch (class) {
        0x8697ec => numbers(read, hash, shape + 0x20, 4, true),
        0x8699f4 => numbers(read, hash, shape + 0x14, 1, true) and numbers(read, hash, shape + 0x20, 3, false) and numbers(read, hash, shape + 0x30, 3, false),
        else => true,
    };
}
