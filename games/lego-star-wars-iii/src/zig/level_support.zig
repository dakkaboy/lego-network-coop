const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
const Context = struct { world: usize, container: usize, scene: usize, count: u32 };
fn context(read: *Reader) ?Context {
    const world = win.load(usize, read.native(0xfb4a20));
    if (!read.readable(world, 0x22e8)) return null;
    const container = win.load(usize, world + 0x22e4);
    if (!read.readable(container, 0x40) or win.load(usize, container + 0xc) != world) return null;
    const table = win.load(usize, container);
    var getter: u32 = 0;
    if (!read.readable(table, 4) or !read.imageOffset(win.load(usize, table), &getter) or getter != 0x34ecb0) return null;
    const scene = win.load(usize, container + 0x3c);
    if (!read.readable(scene, 0x48) or win.load(usize, scene + 0x40) != scene + 0x10 or win.load(usize, scene + 0x3c) != scene + 8 or win.load(usize, scene + 0x38) != 0 or win.load(usize, scene + 0x2c) != 0) return null;
    const count = win.load(u32, scene + 0x44);
    if (count > 65536) return null;
    return .{ .world = world, .container = container, .scene = scene, .count = count };
}
fn text(read: *Reader, hash: *Hash, address: usize) bool {
    const length = read.nameLength(address);
    if (length == 0 or length > 1024) return false;
    for (0..length - 1) |i| {
        const byte = win.load(u8, address + i);
        if (byte < 32 or byte > 126) return false;
    }
    hash.number(length);
    hash.bytes(@as([*]const u8, @ptrFromInt(address))[0..length]);
    return true;
}
fn key(read: *Reader, ctx: Context, body: usize, output: *[2]u32) bool {
    var body_class: u32 = 0;
    if (!read.readable(body, 0xa0) or win.load(u8, body + 0x19) & 0x60 != 0x40 or !read.imageClass(body, &body_class)) return false;
    const owner = win.load(usize, body + 0x28);
    var shape_class: u32 = 0;
    if (!read.imageClass(win.load(usize, body + 0x24), &shape_class)) return false;
    var owner_class: u32 = 0;
    if (!read.readable(owner, 0x1a4) or win.load(usize, owner + 0x1a0) != body or !read.imageClass(owner, &owner_class)) return false;
    const index = win.load(u8, owner + 6);
    const registry = win.load(usize, read.native(0xf9dd10));
    if (index >= 199 or !read.readable(registry, 8 + 199 * 4)) return false;
    const entry = win.load(usize, registry + 8 + @as(usize, index) * 4);
    if (!read.readable(entry, 0x58) or win.load(usize, entry + 0x54) != ctx.container or win.load(usize, entry + 0x4c) != 0) return false;
    const table = win.load(usize, entry);
    var getter: u32 = 0;
    if (!read.readable(table, 8) or !read.imageOffset(win.load(usize, table + 4), &getter) or getter != 0x5cf20) return false;
    const filename = win.load(usize, entry + 0x34);
    const length = read.nameLength(filename);
    if (length < 5 or length > 1024) return false;
    const suffix = win.load([4]u8, filename + length - 5);
    if (!std.ascii.eqlIgnoreCase(&suffix, ".led")) return false;
    const name = win.load(usize, owner + 0xc);
    if (!read.readable(name, 1)) return false;
    const stored = win.load(u8, name);
    if (stored < 3 or !read.readable(name, stored) or win.load(u8, name + stored - 1) != 0) return false;
    var hash: Hash = .{};
    hash.bytes("level-scene-character-support");
    hash.number(body_class);
    hash.number(shape_class);
    if (!@import("support_shape.zig").geometry(read, &hash, win.load(usize, body + 0x24), shape_class)) return false;
    hash.number(owner_class);
    if (!text(read, &hash, ctx.world + 0x81) or !text(read, &hash, filename) or !text(read, &hash, win.load(usize, entry + 0x40)) or !text(read, &hash, name + 1) or !text(read, &hash, win.load(usize, body + 0x1c))) return false;
    if (read.nameLength(name + 1) != @as(u32, stored) - 1) return false;
    output.* = hash.words[0..2].*;
    return output[0] != 0 and output[1] != 0;
}
pub fn source(body: usize, output: *[2]u32) bool {
    var read = Reader.init();
    const ctx = context(&read) orelse return false;
    var first: [2]u32 = undefined;
    if (!key(&read, ctx, body, &first)) return false;
    const owner = win.load(usize, body + 0x28);
    var previous = ctx.scene + 0x10;
    var current = win.load(usize, ctx.scene + 0x34);
    var seen: u32 = 0;
    for (0..ctx.count) |_| {
        if (current == ctx.scene + 8 or !read.readable(current, 0x2c) or win.load(usize, current + 0x28) != previous) return false;
        seen += @intFromBool(current == owner);
        if (current != owner and read.readable(current, 0x1a4)) {
            const other_body = win.load(usize, current + 0x1a0);
            var other: [2]u32 = undefined;
            if (read.readable(other_body, 0xa0) and win.load(usize, other_body + 0x28) == current and key(&read, ctx, other_body, &other) and std.meta.eql(first, other)) return false;
        }
        previous = current;
        current = win.load(usize, current + 0x24);
    }
    if (seen != 1 or current != ctx.scene + 8 or win.load(usize, ctx.scene + 0x30) != previous) return false;
    var fresh = Reader.init();
    const now = context(&fresh) orelse return false;
    var second: [2]u32 = undefined;
    if (!std.meta.eql(ctx, now) or !key(&fresh, now, body, &second) or !std.meta.eql(first, second)) return false;
    output.* = first;
    return true;
}
pub fn resolve(first: u32, second: u32) usize {
    var read = Reader.init();
    const ctx = context(&read) orelse return 0;
    var current = win.load(usize, ctx.scene + 0x34);
    for (0..ctx.count) |_| {
        if (current == ctx.scene + 8 or !read.readable(current, 0x2c)) return 0;
        if (read.readable(current, 0x1a4)) {
            const body = win.load(usize, current + 0x1a0);
            var candidate: [2]u32 = undefined;
            if (key(&read, ctx, body, &candidate) and candidate[0] == first and candidate[1] == second) {
                return if (source(body, &candidate) and candidate[0] == first and candidate[1] == second) body else 0;
            }
        }
        current = win.load(usize, current + 0x24);
    }
    return 0;
}
