const std = @import("std");
const win = @import("win32.zig");
const g = @import("gizmo_source.zig");
const equal = @import("validation.zig").equal;
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
pub const Generator = @import("rts_types.zig").Generator;
pub const Order = @import("rts_types.zig").Order;
pub const Body = @import("rts_types.zig").Body;
pub const Object = @import("rts_types.zig").Object;
fn readable(address: usize, bytes: usize) bool {
    return win.accessible(address, bytes, false);
}
pub fn inactiveGenerator(object: usize) bool {
    // The stock state-zero branch exits on index -1 before looking up a generator slot.
    return readable(object, 0x2a8) and win.load(u32, object) == 0xaed18c and
        win.load(i32, object + 0x250) == -1 and win.load(u32, object + 0x264) == 0 and
        win.load(u32, object + 0x268) == 0 and win.load(usize, object + 0x224) == 0;
}
pub export fn native_rts_generator_source(object: usize, output: ?*Generator) c_int {
    if (output == null or !readable(object, 0x2a8)) return 0;
    var s = std.mem.zeroes(Generator);
    s.object = object;
    s.object_class = win.load(u32, object);
    s.team = win.load(usize, object + 0x28);
    s.index = win.load(u32, object + 0x250);
    s.side = win.load(u32, object + 0x254);
    if (s.object_class < 0x400000 or s.object_class >= 0xb00000 or s.index >= 8 or s.side >= 2 or !readable(s.team, 0x10d4) or win.load(u32, s.team) != 0xaef0fc) return 0;
    s.descriptor = win.load(usize, s.team + 0x1c);
    s.resource = win.load(usize, s.team + 0x10d0);
    s.world = win.load(usize, 0xfb4a20);
    s.engine = win.load(usize, 0xfb0afc);
    if (!readable(s.engine, 0xe10) or s.world == 0 or !readable(s.descriptor, 0x34) or !readable(s.resource, 0x10) or win.load(usize, s.resource + 0xc) != s.world) return 0;
    s.team_slot = win.load(u32, s.descriptor + 0x30);
    if (s.team_slot >= 8) return 0;
    output.?.* = s;
    return 1;
}
pub export fn native_rts_generator_source_live(source: ?*const Generator) c_int {
    const s = source orelse return 0;
    var now: Generator = undefined;
    return @intFromBool(native_rts_generator_source(s.object, &now) != 0 and equal(s, &now));
}
pub export fn native_rts_order_source(order: usize, output: ?*Order) c_int {
    if (output == null or !readable(order, 0x330)) return 0;
    var s = std.mem.zeroes(Order);
    s.order = order;
    s.order_class = win.load(u32, order);
    s.building = win.load(usize, order + 0x24);
    s.team = win.load(usize, order + 0x28);
    if (s.order_class < 0x400000 or s.order_class >= 0xb00000 or !readable(s.building, 0x118) or !readable(s.team, 0x1a34) or
        win.load(u32, s.team) != 0xaef0fc or win.load(usize, s.building + 0x114) != order) return 0;
    s.descriptor = win.load(usize, s.team + 0x1c);
    if (!readable(s.descriptor, 0x34) or !g.native_gizmo_source_resolve(win.load(usize, s.building + 0x28), s.building, &s.gizmo)) return 0;
    const resource = win.load(usize, s.team + 0x10d0);
    if (!readable(resource, 0x10) or win.load(usize, resource + 0xc) != s.gizmo.world) return 0;
    s.team_slot = win.load(u32, s.descriptor + 0x30);
    s.building_ordinal = s.gizmo.ordinal;
    if (s.team_slot >= 8) return 0;
    output.?.* = s;
    return 1;
}
pub export fn native_rts_order_source_live(source: ?*const Order) c_int {
    const s = source orelse return 0;
    var now: Order = undefined;
    return @intFromBool(native_rts_order_source(s.order, &now) != 0 and equal(s, &now));
}
fn pad(pad_value: usize, team: usize, world: usize, source: *g.Source) ?usize {
    if (!readable(team, 0x10d4) or win.load(u32, team) != 0xaef0fc) return null;
    const resource = win.load(usize, team + 0x10d0);
    const descriptor = win.load(usize, team + 0x1c);
    if (!readable(resource, 0x10) or win.load(usize, resource + 0xc) != world or !readable(descriptor, 0x34)) return null;
    return if (g.native_gizmo_source_resolve(win.load(usize, pad_value + 0x28), pad_value, source) and source.world == world) descriptor else null;
}
pub export fn native_rts_body_source(object: usize, request: u32, output: *Body) c_int {
    var s = std.mem.zeroes(Body);
    s.object = object;
    if (!readable(object, 0x290)) return -1;
    s.pad = win.load(usize, object + 0x24);
    s.team = win.load(usize, object + 0x28);
    s.world = win.load(usize, 0xfb4a20);
    if (!readable(s.pad, 0x118) or win.load(usize, s.pad + 0x114) != object or !readable(s.world, 0x221c)) return -1;
    const descriptor = pad(s.pad, s.team, s.world, &s.pad_source) orelse return -1;
    s.ordinal = s.pad_source.ordinal;
    s.model = win.load(usize, object + 0x28c);
    if (s.model == 0) {
        output.* = s;
        return 0;
    }
    if (!readable(s.model, 0x5c)) return -1;
    if (win.load(u16, s.model + 0x5a) & 0x200 == 0) {
        output.* = s;
        return 0;
    }
    s.receiver = win.load(usize, s.model + 0x3c);
    if (!readable(s.receiver, 0x1a4)) return -1;
    s.body = win.load(usize, s.receiver + 0x1a0);
    if (s.body == 0 or s.body == 0xffffffff) {
        output.* = s;
        return 0;
    }
    if (!readable(s.body, 0xa0) or win.load(usize, s.body + 0x28) != s.receiver) return -1;
    s.dynamics = win.load(usize, s.body + 0x98);
    if (s.dynamics == 0) {
        output.* = s;
        return 0;
    }
    if (!readable(s.dynamics, 0x50)) return -1;
    const kind = win.load(usize, s.body);
    if (kind < 0x400000 or kind >= 0xd00000) return -1;
    s.body_class = @intCast(kind - 0x400000);
    var hash: Hash = .{};
    for ([_]u32{ win.load(u32, object), win.load(u32, object + 0x288), win.load(u32, descriptor + 0x30), s.ordinal, request }) |word| hash.number(word);
    for (s.pad_source.key) |word| hash.number(word);
    var read = Reader.init();
    if (!hash.text(&read, s.world + 0x81, 512, true, false) or !hash.text(&read, s.pad + 0x30, 32, true, false) or
        !hash.text(&read, win.load(usize, s.body + 0x1c), 128, true, false)) return -1;
    s.key = hash.words;
    output.* = s;
    return 1;
}
pub export fn native_rts_object_source(object: usize, output: *Object) c_int {
    var s = std.mem.zeroes(Object);
    s.object = object;
    if (!readable(object, 0x2c)) return 0;
    s.pad = win.load(usize, object + 0x24);
    s.team = win.load(usize, object + 0x28);
    s.world = win.load(usize, 0xfb4a20);
    s.object_class = win.load(u32, object);
    if (!readable(s.pad, 0x280) or !readable(s.world, 0x82)) return 0;
    const descriptor = pad(s.pad, s.team, s.world, &s.pad_source) orelse return 0;
    s.ordinal = s.pad_source.ordinal;
    var hash: Hash = .{};
    for ([_]u32{ s.object_class, win.load(u32, descriptor + 0x30), s.ordinal }) |word| hash.number(word);
    for (s.pad_source.key) |word| hash.number(word);
    var read = Reader.init();
    if (!hash.text(&read, s.world + 0x81, 512, true, false) or !hash.text(&read, s.pad + 0x30, 32, true, false)) return 0;
    s.key = hash.words;
    output.* = s;
    return 1;
}
