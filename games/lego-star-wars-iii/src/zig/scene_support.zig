const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
const types = @import("identity_types.zig");
extern fn native_authored_poi_resolve(usize, *types.AuthoredPoi) c_int;
extern fn native_resource_identity_resolve(usize, usize, *types.ResourceIdentity) c_int;
fn staticWorld(read: *Reader, owner: usize, resource: *types.ResourceIdentity) bool {
    const world = win.load(usize, read.native(0xfb4a20));
    const registry = win.load(usize, read.native(0xf9dd10));
    if (!read.readable(world, 0x22e8) or !read.readable(registry, 8 + 199 * 4) or !read.readable(owner, 0x1a4)) return false;
    const index = win.load(u8, owner + 6);
    if (index >= 199) return false;
    const entry = win.load(usize, registry + 8 + @as(usize, index) * 4);
    const container = win.load(usize, world + 0x22e4);
    if (!read.readable(entry, 0x58) or !read.readable(container, 0x40) or win.load(usize, entry + 0x54) != container or win.load(usize, container + 0xc) != world) return false;
    const table = win.load(usize, container);
    var getter: u32 = 0;
    if (!read.readable(table, 4) or !read.imageOffset(win.load(usize, table), &getter) or getter != 0x34ecb0) return false;
    const scene = win.load(usize, container + 0x3c);
    if (!sceneMember(read, scene, owner)) return false;
    return native_resource_identity_resolve(world, win.load(usize, entry + 0x4c), resource) != 0;
}
fn sceneMember(read: *Reader, scene: usize, owner: usize) bool {
    if (!read.readable(scene, 0x48)) return false;
    const head = scene + 0x10;
    const tail = scene + 8;
    if (win.load(usize, scene + 0x40) != head or win.load(usize, scene + 0x3c) != tail or win.load(usize, head + 0x28) != 0 or win.load(usize, tail + 0x24) != 0) return false;
    const count = win.load(u32, scene + 0x44);
    if (count > 65536) return false;
    var previous = head;
    var current = win.load(usize, head + 0x24);
    var found: u32 = 0;
    for (0..count) |_| {
        if (current == tail or !read.readable(current, 0x2c) or win.load(usize, current + 0x28) != previous) return false;
        found += @intFromBool(current == owner);
        previous = current;
        current = win.load(usize, current + 0x24);
    }
    return current == tail and win.load(usize, tail + 0x28) == previous and found == 1;
}
fn key(body: usize, output: *[2]u32) bool {
    var read = Reader.init();
    var class: u32 = 0;
    if (!read.readable(body, 0xa0) or !read.imageClass(body, &class)) return false;
    const kind = win.load(u8, body + 0x19) & 0x60;
    if (kind != 0x40 and kind != 0x20) return false;
    const receiver = win.load(usize, body + 0x28);
    if (!read.readable(receiver, 0x1a4) or win.load(usize, receiver + 0x1a0) != body) return false;
    var resource: types.ResourceIdentity = undefined;
    var hash: Hash = .{};
    if (kind == 0x20) {
        if (win.load(usize, body + 0x14) != 0 or win.load(usize, body + 0x98) != 0 or !staticWorld(&read, receiver, &resource)) return false;
        const matrix = win.load([16]f32, body + 0x40);
        if (!@import("validation.zig").finite(matrix)) return false;
        var receiver_class: u32 = 0;
        if (!read.imageClass(receiver, &receiver_class)) return false;
        hash.bytes("static-world-character-support");
        hash.number(receiver_class);
        hash.bytes(std.mem.asBytes(&matrix));
    } else {
        const model = win.load(usize, receiver + 0x18);
        if (!read.readable(model, 0x5c) or win.load(usize, model + 0x3c) != receiver or win.load(u16, model + 0x5a) & 0x200 == 0) return false;
        var authored: types.AuthoredPoi = undefined;
        if (native_authored_poi_resolve(model, &authored) == 0 or authored.authored_receiver != receiver or authored.receiver != receiver) return false;
        const world = win.load(usize, read.native(0xfb4a20));
        if (native_resource_identity_resolve(world, authored.resource, &resource) == 0 or resource.runtime != authored.runtime or resource.array != authored.array) return false;
        hash.bytes("authored-character-support");
        hash.number(authored.poi_ordinal);
        hash.number(authored.poi_count);
        hash.number(authored.receiver_class);
    }
    const name = win.load(usize, body + 0x1c);
    const length = read.nameLength(name);
    if (length == 0 or length > 128) return false;
    hash.bytes(std.mem.asBytes(&resource.key));
    hash.number(class);
    hash.bytes(@as([*]const u8, @ptrFromInt(name))[0..length]);
    output.* = hash.words[0..2].*;
    return output[0] != 0 and output[1] != 0;
}
pub export fn native_scene_support_source(body: usize, output: *[2]u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var first: [2]u32 = undefined;
    var second: [2]u32 = undefined;
    if (!key(body, &first) or !key(body, &second) or !std.meta.eql(first, second)) return @intFromBool(@import("level_support.zig").source(body, output));
    output.* = first;
    return 1;
}
pub export fn native_scene_support_resolve(first: u32, second: u32) usize {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (first == 0 or second == 0) return 0;
    const level_body = @import("level_support.zig").resolve(first, second);
    if (level_body != 0) return level_body;
    var read = Reader.init();
    const registry = win.load(usize, read.native(0xf9dd10));
    if (!read.readable(registry, 8 + 199 * 4)) return 0;
    var found: usize = 0;
    const world = win.load(usize, read.native(0xfb4a20));
    if (!read.readable(world, 0x22e8)) return 0;
    const container = win.load(usize, world + 0x22e4);
    if (!read.readable(container, 0x40)) return 0;
    const scene = win.load(usize, container + 0x3c);
    if (read.readable(scene, 0x48)) {
        const count = win.load(u32, scene + 0x44);
        if (count > 65536) return 0;
        var current = win.load(usize, scene + 0x34);
        for (0..count) |_| {
            if (!read.readable(current, 0x2c)) return 0;
            const next = win.load(usize, current + 0x24);
            if (read.readable(current, 0x1a4)) {
                const body = win.load(usize, current + 0x1a0);
                if (read.readable(body, 0xa0) and win.load(u8, body + 0x19) & 0x60 == 0x20) {
                    var candidate: [2]u32 = undefined;
                    if (native_scene_support_source(body, &candidate) != 0 and candidate[0] == first and candidate[1] == second) {
                        if (found != 0 and found != body) return 0;
                        found = body;
                    }
                }
            }
            current = next;
        }
        if (current != scene + 8) return 0;
    }
    for (0..199) |i| {
        const entry = win.load(usize, registry + 8 + i * 4);
        if (entry == 0) continue;
        if (!read.readable(entry, 0x50)) return 0;
        const resource = win.load(usize, entry + 0x4c);
        if (resource == 0) continue;
        if (!read.readable(resource, 0x6fc)) return 0;
        const runtime = win.load(usize, resource + 0x6f8);
        if (!read.readable(runtime, 0x70)) return 0;
        const count = win.load(u32, runtime + 0x68);
        const array = win.load(usize, runtime + 0x6c);
        if (count > 65536 or (count != 0 and !read.readable(array, count * 0xe0))) return 0;
        for (0..count) |j| {
            const receiver = win.load(usize, array + j * 0xe0 + 0xd4);
            if (receiver == 0) continue;
            if (!read.readable(receiver, 0x34)) return 0;
            const model = win.load(usize, receiver + 0x18);
            if (!read.readable(model, 0x5c) or win.load(u16, model + 0x5a) & 0x200 == 0) continue;
            if (!read.readable(receiver, 0x1a4)) return 0;
            const body = win.load(usize, receiver + 0x1a0);
            if (body == 0 or body == std.math.maxInt(usize)) continue;
            var candidate: [2]u32 = undefined;
            if (native_scene_support_source(body, &candidate) == 0 or candidate[0] != first or candidate[1] != second) continue;
            if (found != 0 and found != body) return 0;
            found = body;
        }
    }
    var final: [2]u32 = undefined;
    return if (found != 0 and native_scene_support_source(found, &final) != 0 and final[0] == first and final[1] == second) found else 0;
}
