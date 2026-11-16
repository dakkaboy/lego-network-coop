const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
pub const Source = @import("gizmo_types.zig").Source;
fn managerSnapshot(manager: usize, out: *Source, read: *Reader) bool {
    out.* = std.mem.zeroes(Source);
    out.world = win.load(usize, 0xfb4a20);
    out.registry = win.load(usize, 0xe90184);
    out.manager = manager;
    if (!read.readable(out.world, 0x22e8) or !read.readable(out.registry, 0x2c) or !read.readable(manager, 0x28) or !read.imageClass(manager, &out.manager_class)) return false;
    out.container = win.load(usize, out.world + 0x22e4);
    out.handle = win.load(usize, out.world + 0x400);
    if (!read.readable(out.container, 0x10) or win.load(usize, out.container + 0xc) != out.world or !read.readable(out.handle, 4)) return false;
    out.table = win.load(usize, out.handle);
    const count = win.load(u32, out.registry + 0x28);
    if (count == 0 or count > 4096 or !read.readable(out.table, count * 4)) return false;
    var managers: u32 = 0;
    for (0..count) |i| if (win.load(usize, out.table + i * 4) == manager) {
        out.manager_index = @intCast(i);
        managers += 1;
    };
    if (managers != 1) return false;
    out.head = win.load(usize, manager + 0x24);
    var hash: Hash = .{};
    if (!hash.text(read, out.world + 0x81, 512, true, true)) return false;
    hash.number(out.manager_class);
    hash.number(out.manager_index);
    out.key = hash.words;
    return true;
}
fn snapshot(manager: usize, gizmo: usize, out: *Source) bool {
    var read = Reader.init();
    if (!managerSnapshot(manager, out, &read) or !read.readable(gizmo, 0x80) or !read.imageClass(gizmo, &out.gizmo_class)) return false;
    out.gizmo = gizmo;
    var node = out.head;
    var matches: u32 = 0;
    while (node != 0 and out.count < 65536) {
        if (!read.readable(node, 0x28)) return false;
        if (node == gizmo) {
            out.ordinal = out.count;
            matches += 1;
        }
        node = win.load(usize, node + 0x24);
        out.count += 1;
    }
    if (node != 0 or matches != 1) return false;
    var hash: Hash = .{};
    if (!hash.text(&read, out.world + 0x81, 512, true, true) or !hash.text(&read, gizmo + 0x30, 32, false, true)) return false;
    hash.number(out.manager_class);
    hash.number(out.gizmo_class);
    hash.number(out.manager_index);
    hash.number(out.ordinal);
    out.key = hash.words;
    return true;
}
pub export fn native_gizmo_source_resolve(manager: usize, gizmo: usize, out: *Source) bool {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    return snapshot(manager, gizmo, out);
}
pub export fn native_gizmo_source_revalidate(source: *const Source) bool {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var now: Source = undefined;
    return snapshot(source.manager, source.gizmo, &now) and @import("validation.zig").equal(source, &now);
}
pub export fn native_gizmo_manager_source_resolve(manager: usize, out: *Source) bool {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var read = Reader.init();
    return managerSnapshot(manager, out, &read);
}
pub export fn native_gizmo_source_find(gizmo: usize, native_update: usize, out: *Source) bool {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var read = Reader.init();
    out.* = std.mem.zeroes(Source);
    const world = win.load(usize, 0xfb4a20);
    const registry = win.load(usize, 0xe90184);
    if (!read.readable(world, 0x404) or !read.readable(registry, 0x2c)) return false;
    const handle = win.load(usize, world + 0x400);
    const count = win.load(u32, registry + 0x28);
    if (!read.readable(handle, 4) or count == 0 or count > 4096) return false;
    const table = win.load(usize, handle);
    if (!read.readable(table, count * 4)) return false;
    var found = false;
    for (0..count) |i| {
        const manager = win.load(usize, table + i * 4);
        var kind: u32 = undefined;
        if (!read.imageClass(manager, &kind)) continue;
        const vtable = win.load(usize, manager);
        if (!read.readable(vtable, 0x44) or win.load(usize, vtable + 0x40) != native_update) continue;
        var candidate: Source = undefined;
        if (!snapshot(manager, gizmo, &candidate)) continue;
        if (found) {
            out.* = std.mem.zeroes(Source);
            return false;
        }
        out.* = candidate;
        found = true;
    }
    return found;
}
