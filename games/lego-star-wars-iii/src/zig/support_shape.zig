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

pub fn staticConvexHull(read: *Reader, hash: *Hash, shape: usize) bool {
    if (!read.readable(shape, 0x66)) return false;
    const face_count: usize = win.load(u16, shape + 0x60);
    const vertex_count: usize = win.load(u16, shape + 0x62);
    const index_count: usize = win.load(u16, shape + 0x64);
    const vertices = win.load(usize, shape + 0x44);
    const faces = win.load(usize, shape + 0x48);
    const indices = win.load(usize, shape + 0x4c);
    if (vertex_count < 4 or vertex_count > 128 or face_count < 4 or face_count > 128 or
        index_count < 12 or index_count > 512 or !read.readable(vertices, vertex_count * 16) or
        !read.readable(faces, face_count * 4) or !read.readable(indices, index_count * 2) or
        !numbers(read, hash, shape + 0x20, 4, true) or !numbers(read, hash, shape + 0x30, 4, false)) return false;

    var covered: usize = 0;
    for (0..face_count) |i| {
        const count: usize = win.load(u16, faces + i * 4);
        const first: usize = win.load(u16, faces + i * 4 + 2);
        if (count < 3 or first != covered or first + count > index_count) return false;
        covered += count;
    }
    if (covered != index_count) return false;
    for (0..index_count) |i| {
        if (win.load(u16, indices + i * 2) >= vertex_count) return false;
    }
    for (0..vertex_count) |i| {
        const vertex = vertices + i * 16;
        if (!numbers(read, hash, vertex, 3, false)) return false;
        hash.number(win.load(u32, vertex + 12));
    }
    hash.number(@intCast(vertex_count));
    hash.number(@intCast(face_count));
    hash.number(@intCast(index_count));
    hash.bytes(@as([*]const u8, @ptrFromInt(faces))[0 .. face_count * 4]);
    hash.bytes(@as([*]const u8, @ptrFromInt(indices))[0 .. index_count * 2]);
    return true;
}
