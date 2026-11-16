const std = @import("std");
const obs = @import("observation.zig");
const t = @import("collision_types.zig");
extern fn entities_observed_generation(usize) u32;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn projectiles_observe_live(usize, *t.Identity) c_int;
fn rawValue(comptime T: type, bytes: []const u8, offset: usize) T {
    return std.mem.bytesToValue(T, bytes[offset..][0..@sizeOf(T)]);
}
pub fn geometry(out: *t.Geometry, actor: usize) void {
    out.* = std.mem.zeroes(t.Geometry);
    out.pointer_local = @truncate(actor);
    out.raw_slot = std.math.maxInt(u32);
    out.network_slot = std.math.maxInt(u32);
    var raw: [0x1440]u8 = undefined;
    if (!obs.read(actor, &raw)) return;
    out.valid = 1;
    out.local_generation = entities_observed_generation(actor);
    _ = entities_observed_identity(actor, &out.network_slot, &out.network_generation);
    const pool = obs.word(0xfb2f60);
    const count = obs.word(0xfb2e3c);
    const offset = actor -% pool;
    if (pool != 0 and offset % 0x1440 == 0 and offset / 0x1440 < count) out.raw_slot = @intCast(offset / 0x1440);
    out.character = rawValue(i16, &raw, 0xdc0);
    out.state = rawValue(i16, &raw, 0x2f4);
    out.health = @as(i8, @bitCast(raw[0xdde]));
    for ([_]usize{ 0x4c, 0x50, 0xc78, 0xc80, 0xc8c, 0xc94, 0xce4, 0xcea }, &out.flags) |field, *value| value.* = rawValue(u32, &raw, field);
    out.world = rawValue([3]f32, &raw, 0x24);
    out.bounds = rawValue([6]f32, &raw, 0x30);
    out.center = rawValue([3]f32, &raw, 0xf28);
    out.extents = rawValue([2]f32, &raw, 0x1088);
    out.invulnerability = rawValue(f32, &raw, 0xd3c);
    out.elapsed = rawValue(f32, &raw, 0xe28);
    out.facing = rawValue([3]f32, &raw, 0xf10);
    out.life = rawValue(u32, &raw, 0x54);
    out.heading = rawValue(u32, &raw, 0xf0c);
    out.model[0] = rawValue(u32, &raw, 8);
    var flags: [2]u8 = @splat(0);
    const a = obs.read(out.model[0] +% 0x29, flags[0..1]);
    const b = obs.read(out.model[0] +% 0x42, flags[1..2]);
    out.model[1] = @as(u32, @intFromBool(a)) | (@as(u32, @intFromBool(b)) << 1);
    out.model[2] = flags[0];
    out.model[3] = flags[1];
    const resource = rawValue(u32, &raw, 0xf08);
    out.definition[0] = obs.word(resource +% 0x2c);
    var dc: u32 = 0;
    var ec: u32 = 0;
    const c = obs.read(out.definition[0] +% 0xdc, std.mem.asBytes(&dc));
    const d = obs.read(out.definition[0] +% 0xec, std.mem.asBytes(&ec));
    out.definition[1] = @as(u32, @intFromBool(c)) | (@as(u32, @intFromBool(d)) << 1);
    out.definition[2] = dc;
    out.definition[3] = ec;
}
pub fn shot(out: *t.Shot, object: usize, include_untracked: bool) void {
    out.* = std.mem.zeroes(t.Shot);
    out.pointer_local = @truncate(object);
    out.owner = -1;
    out.weapon = -1;
    var identity: t.Identity = undefined;
    _ = projectiles_observe_live(object, &identity);
    out.status = identity.status;
    if (identity.status == 1) {
        out.id = identity.id;
        out.owner = identity.owner;
        out.weapon = identity.weapon;
        out.owner_generation = identity.owner_generation;
        out.resource_local = identity.resource_local;
        out.instance_serial = identity.instance_serial;
        out.creation_count = identity.creation_count;
    }
    if (identity.status == 1 or include_untracked) out.raw_valid = @intFromBool(obs.read(object, std.mem.asBytes(&out.raw)));
}
