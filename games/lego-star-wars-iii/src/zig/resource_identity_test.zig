const std = @import("std");
const r = @import("resource_identity.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var image_classes: [8]u32 = @splat(0);
var world: [0x2300]u8 = @splat(0);
var source_world: [0x2300]u8 = @splat(0);
var container: [0x20]u8 = @splat(0);
var other_container: [0x20]u8 = @splat(0);
var registry: [8 + 199 * 4]u8 = @splat(0);
var entry: [0x58]u8 = @splat(0);
var other_entry: [0x58]u8 = @splat(0);
var resource: [0x738]u8 = @splat(0);
var other_resource: [0x738]u8 = @splat(0);
var runtime: [0x70]u8 = @splat(0);
var file_table: [3]usize = @splat(0);
var array: [8]u32 = @splat(0);
var filename: [128]u8 = @splat(0);
var logical_name: [64]u8 = @splat(0);
fn pointer(base: anytype, offset: usize, value: anytype) void {
    win.store(usize, @intFromPtr(base) + offset, @intFromPtr(value));
}
fn native(address: usize) usize {
    return win.GetModuleHandleA(null) + address - 0x400000;
}
fn setup(bound: bool) void {
    inline for (.{ &world, &source_world, &container, &other_container, &registry, &entry, &other_entry, &resource, &other_resource, &runtime }) |buffer| @memset(buffer, 0);
    @memcpy(world[0x81..][0..12], "CurrentArea\x00");
    @memcpy(source_world[0x81..][0..11], "SourceArea\x00");
    const name = "levels\\library\\prefab.gsc\x00";
    @memcpy(filename[0..name.len], name);
    @memcpy(logical_name[0..13], "prefab_scene\x00");
    win.store(usize, native(0xfb4a20), @intFromPtr(&world));
    win.store(usize, native(0xf9dd10), @intFromPtr(&registry));
    pointer(&container, 0, &image_classes);
    if (bound) pointer(&container, 0xc, &source_world);
    pointer(&source_world, 0x22e4, &container);
    pointer(&world, 0x22e4, &container);
    pointer(&registry, 8, &entry);
    pointer(&entry, 0, &file_table);
    pointer(&entry, 0x34, &filename);
    pointer(&entry, 0x40, &logical_name);
    pointer(&entry, 0x4c, &resource);
    pointer(&entry, 0x54, &container);
    pointer(&resource, 0x6f8, &runtime);
    pointer(&runtime, 0x6c, &array);
    file_table[1] = win.GetModuleHandleA(null) + 0x5cf20;
}
fn duplicate(bound: bool, different_class: bool) void {
    other_entry = entry;
    other_container = container;
    pointer(&registry, 12, &other_entry);
    pointer(&other_entry, 0x4c, &other_resource);
    pointer(&other_entry, 0x54, &other_container);
    pointer(&other_container, 0, &image_classes[@intFromBool(different_class)]);
    win.store(usize, @intFromPtr(&other_container) + 0xc, if (bound) @intFromPtr(&source_world) else 0);
    if (bound) pointer(&source_world, 0x22e4, &other_container);
}
fn resolve(out: *r.Source) bool {
    return r.native_resource_identity_resolve(@intFromPtr(&world), @intFromPtr(&resource), out) != 0;
}
fn revalidate(out: *const r.Source) bool {
    return r.native_resource_identity_revalidate(out) != 0;
}
pub fn main() void {
    var library: r.Source = undefined;
    var bound: r.Source = undefined;
    var changed: r.Source = undefined;
    setup(false);
    win.SetLastError(761);
    check(@src(), resolve(&library) and win.GetLastError() == 761);
    check(@src(), library.source_world_present == 0 and library.source_world == 0 and revalidate(&library));
    setup(true);
    check(@src(), resolve(&bound) and bound.source_world_present != 0 and bound.source_world == @intFromPtr(&source_world) and !std.mem.eql(u32, &bound.key, &library.key));
    win.store(usize, @intFromPtr(&container) + 0xc, 0);
    check(@src(), !revalidate(&bound));
    setup(false);
    check(@src(), resolve(&library));
    filename[0] = 'L';
    check(@src(), !revalidate(&library));
    check(@src(), resolve(&changed) and !std.mem.eql(u32, &library.key, &changed.key));
    setup(false);
    check(@src(), resolve(&library));
    duplicate(false, false);
    check(@src(), !revalidate(&library) and !resolve(&changed));
    setup(false);
    duplicate(false, true);
    check(@src(), resolve(&changed));
    setup(false);
    duplicate(true, false);
    check(@src(), resolve(&changed));
    setup(false);
    check(@src(), resolve(&library));
    pointer(&container, 0xc, &source_world);
    check(@src(), !revalidate(&library));
    setup(false);
    check(@src(), resolve(&library));
    pointer(&container, 0, &image_classes[1]);
    check(@src(), !revalidate(&library));
    setup(true);
    win.store(usize, @intFromPtr(&source_world) + 0x22e4, 0);
    check(@src(), !resolve(&changed));
    setup(false);
    check(@src(), r.native_resource_identity_resolve(@intFromPtr(&source_world), @intFromPtr(&resource), &changed) == 0);
    setup(false);
    check(@src(), resolve(&library));
    win.store(usize, native(0xfb4a20), @intFromPtr(&source_world));
    check(@src(), !revalidate(&library));
    setup(false);
    pointer(&resource, 0x734, &other_resource);
    check(@src(), !resolve(&changed));
    pointer(&other_resource, 0x6f8, &runtime);
    pointer(&entry, 0x4c, &other_resource);
    check(@src(), resolve(&changed) and changed.actual_resource == @intFromPtr(&resource) and changed.root_resource == @intFromPtr(&other_resource));
    setup(false);
    win.SetLastError(762);
    @memset(std.mem.asBytes(&changed), 0xa5);
    const before = changed;
    check(@src(), r.native_resource_identity_resolve(@intFromPtr(&world), 1, &changed) == 0 and win.GetLastError() == 762);
    check(@src(), std.mem.eql(u8, std.mem.asBytes(&before), std.mem.asBytes(&changed)));
}
