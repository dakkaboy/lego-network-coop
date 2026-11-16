const std = @import("std");
const g = @import("gizmo_source.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var manager_class: [0x44]u8 = @splat(0);
var gizmo_class: [16]u8 = @splat(0);
const World = struct {
    world: [0x22e8]u8 = @splat(0),
    container: [16]u8 = @splat(0),
    registry: [0x2c]u8 = @splat(0),
    manager: [0x28]u8 = @splat(0),
    gizmos: [2][0x80]u8 = @splat(@splat(0)),
    table: [3]usize = @splat(0),
    handle: usize = 0,
    fn init(self: *World) void {
        self.* = .{};
        self.handle = @intFromPtr(&self.table);
        put(&self.world, 0x22e4, @intFromPtr(&self.container));
        put(&self.container, 12, @intFromPtr(&self.world));
        put(&self.world, 0x400, @intFromPtr(&self.handle));
        put(&self.registry, 0x28, 3);
        @memcpy(self.world[0x81..][0..14], "NativeMission\x00");
        put(&self.manager, 0, @intFromPtr(&manager_class));
        self.table[1] = @intFromPtr(&self.manager);
        put(&self.manager, 0x24, @intFromPtr(&self.gizmos[0]));
        for (&self.gizmos) |*object| {
            put(object, 0, @intFromPtr(&gizmo_class));
            @memcpy(object[0x30..][0..17], "SameAuthoredName\x00");
        }
        put(&self.gizmos[0], 0x24, @intFromPtr(&self.gizmos[1]));
    }
    fn bind(self: *World) void {
        win.store(usize, 0xfb4a20, @intFromPtr(&self.world));
        win.store(usize, 0xe90184, @intFromPtr(&self.registry));
    }
    fn resolve(self: *World, index: usize, out: *g.Source) bool {
        return g.native_gizmo_source_resolve(@intFromPtr(&self.manager), @intFromPtr(&self.gizmos[index]), out);
    }
    fn managerSource(self: *World, out: *g.Source) bool {
        return g.native_gizmo_manager_source_resolve(@intFromPtr(&self.manager), out);
    }
};
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
pub fn main() void {
    check(@src(), @intFromPtr(&native_image) < 0xfb0000 and @intFromPtr(&native_image) + native_image.len > 0xfc0000);
    var a: World = undefined;
    var b: World = undefined;
    a.init();
    b.init();
    var first: g.Source = undefined;
    var second: g.Source = undefined;
    var relocated: g.Source = undefined;
    a.bind();
    win.SetLastError(123);
    put(&manager_class, 0x40, 0x838260);
    check(@src(), g.native_gizmo_source_find(@intFromPtr(&a.gizmos[0]), 0x838260, &relocated) and win.GetLastError() == 123);
    check(@src(), !g.native_gizmo_source_find(@intFromPtr(&a.gizmos[0]), 0x838261, &relocated));
    check(@src(), a.resolve(0, &first) and win.GetLastError() == 123 and first.ordinal == 0 and first.count == 2);
    check(@src(), a.resolve(1, &second) and second.ordinal == 1 and !std.mem.eql(u32, &first.key, &second.key));
    check(@src(), g.native_gizmo_source_revalidate(&first));
    a.gizmos[0][0x62] = 3;
    check(@src(), g.native_gizmo_source_revalidate(&first));
    b.bind();
    check(@src(), !g.native_gizmo_source_revalidate(&first));
    check(@src(), b.resolve(0, &relocated) and std.mem.eql(u32, &first.key, &relocated.key));
    b.world[0x81] = 'X';
    check(@src(), b.resolve(0, &relocated) and !std.mem.eql(u32, &first.key, &relocated.key));
    b.world[0x81] = 'N';
    b.table[0] = @intFromPtr(&b.manager);
    check(@src(), !b.resolve(0, &relocated));
    b.table[0] = 0;
    put(&b.container, 12, 0);
    check(@src(), !b.resolve(0, &relocated));
    put(&b.container, 12, @intFromPtr(&b.world));
    check(@src(), !g.native_gizmo_source_resolve(@intFromPtr(&b.manager), @intFromPtr(&a.gizmos[0]), &relocated));
    put(&b.gizmos[1], 0x24, @intFromPtr(&b.gizmos[0]));
    check(@src(), !b.resolve(0, &relocated));
    put(&b.gizmos[1], 0x24, 0);
    put(&b.gizmos[0], 0, 1);
    check(@src(), !b.resolve(0, &relocated));
    a.bind();
    var source: g.Source = undefined;
    check(@src(), a.managerSource(&source) and source.manager_index == 1 and source.gizmo == 0);
    var cohort: @import("render_cohort.zig").RenderCohort = .{};
    const passes = [_][3]u32{ .{ 5610, 1, 0 }, .{ 5610, 0, 1 }, .{ 5610, 1, 0 }, .{ 5610, 0, 0 }, .{ 5610, 1, 0 }, .{ 5610, 0, 0 }, .{ 5611, 1, 0 }, .{ 5611, 0, 1 }, .{ 5611, 1, 0 }, .{ 5611, 0, 0 }, .{ 5611, 1, 0 }, .{ 5611, 0, 0 } };
    var original_flags: u16 = 9;
    var coherent_flags: u16 = 9;
    var resets: u32 = 0;
    for (passes) |pass| {
        if (pass[1] != 0) original_flags &= ~@as(u16, 4);
        if (cohort.primary(&source, 2, pass[0], pass[1]) != 0) {
            coherent_flags &= ~@as(u16, 4);
            resets += 1;
        }
        original_flags |= @intCast(pass[2] * 4);
        coherent_flags |= @intCast(pass[2] * 4);
    }
    check(@src(), original_flags == 9 and coherent_flags == 13 and resets == 2);
    check(@src(), cohort.primary(&source, 2, 5612, 1) == 1);
    coherent_flags &= ~@as(u16, 4);
    check(@src(), coherent_flags == 9 and cohort.primary(&source, 2, 5612, 1) == 0 and cohort.primary(&source, 3, 5612, 1) == 1);
    var changed = source;
    changed.world = @intFromPtr(&b.world);
    check(@src(), cohort.primary(&changed, 3, 5612, 1) == 1);
    changed = source;
    changed.manager = @intFromPtr(&b.manager);
    check(@src(), cohort.primary(&changed, 3, 5612, 1) == 1);
    changed = source;
    changed.key[0] ^= 1;
    check(@src(), cohort.primary(&changed, 3, 5612, 1) == 1);
    check(@src(), cohort.primary(&source, 4, 0xffffffff, 0) == 0 and cohort.primary(&source, 4, 0xffffffff, 1) == 1 and cohort.primary(&source, 4, 0, 1) == 1);
    put(&a.manager, 0x24, 0);
    check(@src(), a.managerSource(&source));
    a.table[0] = @intFromPtr(&a.manager);
    check(@src(), !a.managerSource(&source));
    a.table[0] = 0;
    put(&a.container, 12, 0);
    check(@src(), !a.managerSource(&source));
}
