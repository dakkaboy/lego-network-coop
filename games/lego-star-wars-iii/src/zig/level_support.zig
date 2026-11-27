const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
const Context = struct { world: usize, container: usize, scene: usize, count: u32 };
const OriginStatus = @import("zillo_support_origin.zig").Status;
const Identity = struct { words: [2]u32, legacy: [2]u32, origin: OriginStatus };
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
fn named(read: *Reader, address: usize, expected: []const u8) bool {
    if (read.nameLength(address) != expected.len + 1) return false;
    const actual: [*]const u8 = @ptrFromInt(address);
    return std.ascii.eqlIgnoreCase(actual[0..expected.len], expected);
}
fn staticLevelSupport(read: *Reader, hash: *Hash, body: usize, owner: usize, owner_name: usize, name_length: usize, filename: usize, classes: [3]u32) bool {
    if (classes[0] != 0x869eac or classes[2] != 0x820f64 or
        win.load(usize, body + 0x14) != 0 or win.load(usize, body + 0x98) != 0) return false;
    if (name_length < 3 or win.load(u8, owner_name) != '#') return false;
    for (1..name_length - 1) |i| if (!std.ascii.isDigit(win.load(u8, owner_name + i))) return false;
    const label = win.load(usize, body + 0x1c);
    const zillo = named(read, filename, "ZilloBeast_B_temp.led");
    const gungan = named(read, filename, "GunganGeneral_A_temp.led");
    if (classes[1] == 0x869b0c and named(read, label, "plate_grey_solid")) {
        if (!zillo and !gungan) return false;
        hash.bytes(if (zillo) "zillo-static-build-plate" else "gungan-static-build-plate");
    } else if (zillo and classes[1] == 0x869b7c) {
        const rock1 = named(read, label, "Rock1P1") or named(read, label, "Rock1P2");
        const rock = rock1 or named(read, label, "Rock2P1") or named(read, label, "Rock2P2");
        if (!rock and !named(read, label, "TNTSwitch_Base")) return false;
        const model = win.load(usize, owner + 0x18);
        if (model == 0) {
            if (!rock1) return false;
        } else {
            var model_class: u32 = 0;
            if (!read.readable(model, 0x40) or !read.imageClass(model, &model_class) or
                model_class != 0x850344 or win.load(usize, model + 0x3c) != owner) return false;
        }
        hash.bytes(if (rock) "zillo-static-rock" else "zillo-static-tnt-switch");
        if (!@import("support_shape.zig").staticConvexHull(read, hash, win.load(usize, body + 0x24))) return false;
    } else return false;
    // The engine assigns generated owner names on each visit.
    const matrix = win.load([16]f32, body + 0x40);
    if (!@import("validation.zig").finite(matrix)) return false;
    for (matrix) |value| hash.number(if (value == 0) 0 else @as(u32, @bitCast(value)));
    return true;
}
fn key(read: *Reader, ctx: Context, body: usize, output: *Identity) bool {
    var body_class: u32 = 0;
    if (!read.readable(body, 0xa0) or !read.imageClass(body, &body_class)) return false;
    const kind = win.load(u8, body + 0x19) & 0x60;
    if (kind != 0x40 and kind != 0x20) return false;
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
    const label = win.load(usize, body + 0x1c);
    const blue_shadow_object = body_class == 0x869eac and shape_class == 0x8695d4 and owner_class == 0x820f64 and
        named(read, filename, "BlueShadowVirus_C_temp.led") and win.load(u8, name + 1) == '#';
    const corridor_box = blue_shadow_object and kind == 0x40 and named(read, label, "Black_Box");
    const lab_canister = blue_shadow_object and kind == 0x20 and named(read, label, "Canister_Dummy") and
        win.load(usize, body + 0x14) == 0 and win.load(usize, body + 0x98) == 0;
    var hash: Hash = .{};
    if (kind == 0x20 and !lab_canister and !staticLevelSupport(read, &hash, body, owner, name + 1, stored - 1, filename, .{ body_class, shape_class, owner_class })) return false;
    hash.bytes("level-scene-character-support");
    hash.number(body_class);
    hash.number(shape_class);
    if (!@import("support_shape.zig").geometry(read, &hash, win.load(usize, body + 0x24), shape_class)) return false;
    hash.number(owner_class);
    if (!text(read, &hash, ctx.world + 0x81) or !text(read, &hash, filename) or !text(read, &hash, win.load(usize, entry + 0x40))) return false;
    if (corridor_box or lab_canister) {
        for (2..stored - 1) |i| if (!std.ascii.isDigit(win.load(u8, name + i))) return false;
        // Generated owner numbers can differ between peers for the same authored object.
        const placement = win.load([16]f32, owner + 0x40);
        if (!@import("validation.zig").finite(placement)) return false;
        hash.bytes(if (lab_canister) "blue-shadow-lab-canister" else "blue-shadow-corridor-box");
        for (placement) |value| hash.number(if (value == 0) 0 else @as(u32, @bitCast(value)));
    } else if (kind == 0x40 and !text(read, &hash, name + 1)) return false;
    if (!text(read, &hash, label)) return false;
    if (read.nameLength(name + 1) != @as(u32, stored) - 1) return false;
    const legacy = hash.words[0..2].*;
    const origin = @import("zillo_support_origin.zig").append(&hash, ctx.world, owner, body);
    output.* = .{ .words = hash.words[0..2].*, .legacy = legacy, .origin = origin };
    return output.words[0] != 0 and output.words[1] != 0;
}
pub fn source(body: usize, output: *[2]u32) bool {
    var read = Reader.init();
    const ctx = context(&read) orelse return false;
    var first: Identity = undefined;
    if (!key(&read, ctx, body, &first) or first.origin == .invalid) return false;
    const owner = win.load(usize, body + 0x28);
    var previous = ctx.scene + 0x10;
    var current = win.load(usize, ctx.scene + 0x34);
    var seen: u32 = 0;
    for (0..ctx.count) |_| {
        if (current == ctx.scene + 8 or !read.readable(current, 0x2c) or win.load(usize, current + 0x28) != previous) return false;
        seen += @intFromBool(current == owner);
        if (current != owner and read.readable(current, 0x1a4)) {
            const other_body = win.load(usize, current + 0x1a0);
            var other: Identity = undefined;
            if (read.readable(other_body, 0xa0) and win.load(usize, other_body + 0x28) == current and key(&read, ctx, other_body, &other)) {
                if (std.meta.eql(first.words, other.words)) return false;
                if ((first.origin == .absent or other.origin == .invalid) and std.meta.eql(first.legacy, other.legacy)) return false;
            }
        }
        previous = current;
        current = win.load(usize, current + 0x24);
    }
    if (seen != 1 or current != ctx.scene + 8 or win.load(usize, ctx.scene + 0x30) != previous) return false;
    var fresh = Reader.init();
    const now = context(&fresh) orelse return false;
    var second: Identity = undefined;
    if (!std.meta.eql(ctx, now) or !key(&fresh, now, body, &second) or !std.meta.eql(first, second)) return false;
    const origins = @import("zillo_support_origin.zig");
    if (first.origin == .bound) origins.clonewars_zillo_support_origin_debug[2] +%= 1;
    output.* = first.words;
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
            var candidate: Identity = undefined;
            if (key(&read, ctx, body, &candidate) and candidate.origin != .invalid and candidate.words[0] == first and candidate.words[1] == second) {
                var checked: [2]u32 = undefined;
                return if (source(body, &checked) and checked[0] == first and checked[1] == second) body else 0;
            }
        }
        current = win.load(usize, current + 0x24);
    }
    return 0;
}
