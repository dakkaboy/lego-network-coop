const std = @import("std");
const obs = @import("observation.zig");
const t = @import("combat_types.zig");
const Identity = @import("collision_types.zig").Identity;
extern fn entities_observed_generation(usize) u32;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn projectiles_observe_live(usize, *Identity) c_int;
fn field(comptime T: type, raw: []const u8, offset: usize) T {
    return std.mem.bytesToValue(T, raw[offset..][0..@sizeOf(T)]);
}
pub fn level() u32 {
    const area = obs.word(0xfb4a20);
    const definition = if (area != 0) obs.word(area +% 0x220) else 0;
    var value: i16 = -1;
    if (definition != 0) _ = obs.read(definition +% 0x94, std.mem.asBytes(&value));
    return @bitCast(@as(i32, value));
}
pub fn phase() u32 {
    const root = obs.word(0xfb2e60);
    return if (root != 0) obs.word(root +% 0x1b78) else std.math.maxInt(u32);
}
pub fn actor(out: *t.Actor, pointer: u32) void {
    out.* = std.mem.zeroes(t.Actor);
    out.pointer_local = pointer;
    out.raw_slot = std.math.maxInt(u32);
    out.network_slot = std.math.maxInt(u32);
    if (pointer == 0) return;
    var raw: [0x1440]u8 = undefined;
    if (!obs.read(pointer, &raw)) return;
    out.valid = 1;
    out.local_generation = entities_observed_generation(pointer);
    _ = entities_observed_identity(pointer, &out.network_slot, &out.network_generation);
    const pool = obs.word(0xfb2f60);
    const count = obs.word(0xfb2e3c);
    const offset = pointer -% pool;
    if (pool != 0 and offset % 0x1440 == 0 and offset / 0x1440 < count) out.raw_slot = offset / 0x1440;
    out.character = field(i16, &raw, 0xdc0);
    out.health = @as(i8, @bitCast(raw[0xdde]));
    out.life_54 = raw[0x54];
    out.death_de6 = raw[0xde6];
    out.state_2f4 = @bitCast(@as(i32, field(i16, &raw, 0x2f4)));
    inline for (.{ .{ "flags", 0x50 }, .{ "invulnerability_d3c", 0xd3c }, .{ "c78", 0xc78 }, .{ "c80", 0xc80 }, .{ "c8c", 0xc8c }, .{ "c94", 0xc94 }, .{ "c98", 0xc98 }, .{ "ca0", 0xca0 }, .{ "handle_142c", 0x142c } }) |entry| @field(out, entry[0]) = field(u32, &raw, entry[1]);
}
pub fn source(out: *t.Source, object: u32, origin: u32) void {
    out.* = std.mem.zeroes(t.Source);
    out.object_local = object;
    out.origin = origin;
    out.owner = -1;
    out.weapon = -1;
    var identity: Identity = undefined;
    _ = projectiles_observe_live(object, &identity);
    out.status = identity.status;
    if (identity.status != 1) return;
    out.id = identity.id;
    out.resource_local = identity.resource_local;
    out.owner = identity.owner;
    out.owner_generation = identity.owner_generation;
    out.weapon = identity.weapon;
    out.instance_serial = identity.instance_serial;
    out.creation_count = identity.creation_count;
    var raw: [0x210]u8 = undefined;
    if (!obs.read(object, &raw)) {
        out.status = 5;
        out.id = 0;
        return;
    }
    if (field(u32, &raw, 0x14) != identity.resource_local) {
        out.status = 3;
        out.id = 0;
        return;
    }
    out.owner_local = field(u32, &raw, 0x18);
    out.flags_160 = field(u32, &raw, 0x160);
    out.flags_164 = field(u32, &raw, 0x164);
    out.position = field([3]f32, &raw, 0xa4);
    out.resource_74 = obs.word(identity.resource_local +% 0x74);
    var damage: u8 = 0;
    _ = obs.read(identity.resource_local +% 0x4a, std.mem.asBytes(&damage));
    out.damage_4a = damage;
}
