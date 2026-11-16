const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
pub const Source = @import("identity_types.zig").ResourceIdentity;
const Input = struct { world: usize, resource: usize };
fn snapshot(read: *Reader, input: Input, output: *Source) bool {
    var s = std.mem.zeroes(Source);
    s.world = input.world;
    s.actual_resource = input.resource;
    if (!read.readable(read.native(0xfb4a20), 4) or win.load(usize, read.native(0xfb4a20)) != s.world or !read.readable(read.native(0xf9dd10), 4)) return false;
    s.registry = win.load(usize, read.native(0xf9dd10));
    if (!read.readable(input.resource, 0x738) or !read.readable(s.registry, 8 + 199 * 4) or !read.readable(s.world, 0x82)) return false;
    s.runtime = win.load(usize, input.resource + 0x6f8);
    s.root_resource = win.load(usize, input.resource + 0x734);
    if (s.root_resource != 0) {
        if (!read.readable(s.root_resource, 0x6fc) or win.load(usize, s.root_resource + 0x6f8) != s.runtime) return false;
    } else s.root_resource = input.resource;
    for (0..199) |i| {
        const entry = win.load(usize, s.registry + 8 + i * 4);
        if (entry == 0) continue;
        if (!read.readable(entry, 0x58)) return false;
        if (win.load(usize, entry + 0x4c) != s.root_resource) continue;
        if (s.entry != 0) return false;
        s.entry = entry;
    }
    if (s.entry == 0) return false;
    const table = win.load(usize, s.entry);
    var getter: u32 = undefined;
    if (!read.readable(table, 8) or !read.imageOffset(win.load(usize, table + 4), &getter) or getter != 0x5cf20 or !read.readable(s.runtime, 0x70)) return false;
    s.name = win.load(usize, s.entry + 0x40);
    s.filename = win.load(usize, s.entry + 0x34);
    s.container = win.load(usize, s.entry + 0x54);
    if (!read.readable(s.container, 0x10) or !read.imageClass(s.container, &s.container_class)) return false;
    s.source_world = win.load(usize, s.container + 0xc);
    s.source_world_present = @intFromBool(s.source_world != 0);
    if (s.source_world != 0 and (!read.readable(s.source_world, 0x22e8) or win.load(usize, s.source_world + 0x22e4) != s.container)) return false;
    s.array = win.load(usize, s.runtime + 0x6c);
    for (0..199) |i| {
        const other = win.load(usize, s.registry + 8 + i * 4);
        if (other == 0 or other == s.entry) continue;
        if (!read.readable(other, 0x58)) return false;
        if (win.load(usize, other + 0x4c) == 0) continue;
        if (!read.sameName(s.filename, win.load(usize, other + 0x34)) or !read.sameName(s.name, win.load(usize, other + 0x40))) continue;
        const owner = win.load(usize, other + 0x54);
        var owner_class: u32 = undefined;
        if (!read.readable(owner, 0x10) or !read.imageClass(owner, &owner_class)) return false;
        const area = win.load(usize, owner + 0xc);
        if (area != 0 and (!read.readable(area, 0x22e8) or win.load(usize, area + 0x22e4) != owner)) return false;
        if (owner_class == s.container_class and (area != 0) == (s.source_world != 0) and (area == 0 or read.sameName(s.source_world + 0x81, area + 0x81))) return false;
    }
    var hash: Hash = .{};
    hash.number(s.container_class);
    hash.number(s.source_world_present);
    s.world_name_length = read.nameLength(s.world + 0x81);
    if (s.world_name_length == 0) return false;
    hash.bytes(@as([*]const u8, @ptrFromInt(s.world + 0x81))[0..s.world_name_length]);
    if (s.source_world != 0) {
        s.source_world_name_length = read.nameLength(s.source_world + 0x81);
        if (s.source_world_name_length == 0) return false;
        hash.bytes(@as([*]const u8, @ptrFromInt(s.source_world + 0x81))[0..s.source_world_name_length]);
    }
    s.filename_length = read.nameLength(s.filename);
    s.name_length = read.nameLength(s.name);
    if (s.filename_length == 0 or s.name_length == 0) return false;
    hash.bytes(@as([*]const u8, @ptrFromInt(s.filename))[0..s.filename_length]);
    hash.bytes(@as([*]const u8, @ptrFromInt(s.name))[0..s.name_length]);
    s.key = hash.words;
    output.* = s;
    return true;
}
fn inputOf(s: *const Source) Input {
    return .{ .world = s.world, .resource = s.actual_resource };
}
const Capture = @import("snapshot.zig").Snapshot(Source, Input, snapshot, inputOf);
pub export fn native_resource_identity_resolve(world: usize, resource: usize, output: ?*Source) c_int {
    return Capture.resolve(.{ .world = world, .resource = resource }, output);
}
pub export fn native_resource_identity_revalidate(witness: ?*const Source) c_int {
    return Capture.revalidate(witness);
}
