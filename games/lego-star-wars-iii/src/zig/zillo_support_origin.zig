const std = @import("std");
const Hash = @import("fingerprint.zig").Hash;

pub const Origin = struct {
    clock: u32,
    actor_slot: u32,
    generation: u32,
    throw_slot: u32,
    model: u32,
};

const Record = struct {
    body: usize = 0,
    owner: usize = 0,
    world: usize = 0,
    origin: Origin = undefined,
};

pub const Polygon = struct { root_clock: u32, clock: u32, mode: u32 };
const PolygonRecord = struct {
    body: usize = 0,
    owner: usize = 0,
    world: usize = 0,
    origin: Polygon = undefined,
    ambiguous: bool = false,
};

threadlocal var records: [512]Record = @splat(.{});
threadlocal var count: usize = 0;
threadlocal var scene: usize = 0;
threadlocal var overflowed = false;
threadlocal var polygons: [64]PolygonRecord = @splat(.{});
threadlocal var polygon_world: usize = 0;
threadlocal var polygon_overflowed = false;
pub export var clonewars_zillo_support_origin_debug: [4]u32 = @splat(0);

fn resetThrows() void {
    records = @splat(.{});
    count = 0;
    scene = 0;
    overflowed = false;
    clonewars_zillo_support_origin_debug = @splat(0);
}

pub fn reset() void {
    resetThrows();
    polygons = @splat(.{});
    polygon_world = 0;
    polygon_overflowed = false;
}

pub fn remember(world: usize, owner: usize, body: usize, origin: Origin) void {
    if (body == 0 or owner == 0 or world == 0) return;
    if (scene != world) {
        resetThrows();
        scene = world;
    }
    var free: ?*Record = null;
    for (records[0..count]) |*entry| {
        if (entry.body == body) {
            if (entry.owner != owner or entry.world != world or !std.meta.eql(entry.origin, origin)) {
                entry.world = 0;
                clonewars_zillo_support_origin_debug[3] +%= 1;
            }
            return;
        }
        if (entry.body == 0 and free == null) free = entry;
    }
    if (free == null and count < records.len) {
        free = &records[count];
        count += 1;
    }
    if (free) |entry| {
        entry.* = .{ .body = body, .owner = owner, .world = world, .origin = origin };
        clonewars_zillo_support_origin_debug[0] +%= 1;
    } else {
        overflowed = true;
        clonewars_zillo_support_origin_debug[3] +%= 1;
    }
}

pub fn forget(body: usize) void {
    if (body == 0) return;
    for (&polygons) |*entry| {
        if (entry.body == body) {
            entry.* = .{};
            break;
        }
    }
    for (records[0..count]) |*entry| {
        if (entry.body != body) continue;
        entry.* = .{};
        return;
    }
}

pub fn rememberPolygon(world: usize, owner: usize, body: usize, origin: Polygon) void {
    if (world == 0 or owner == 0 or body == 0) return;
    if (polygon_world != world) {
        polygons = @splat(.{});
        polygon_world = world;
        polygon_overflowed = false;
    }
    var free: ?*PolygonRecord = null;
    var ambiguous = false;
    for (&polygons) |*entry| {
        if (entry.body == body) {
            if (entry.owner != owner or !std.meta.eql(entry.origin, origin)) entry.ambiguous = true;
            return;
        }
        if (entry.body == 0) {
            if (free == null) free = entry;
        } else if (std.meta.eql(entry.origin, origin)) {
            entry.ambiguous = true;
            ambiguous = true;
        }
    }
    if (free) |entry| {
        entry.* = .{ .body = body, .owner = owner, .world = world, .origin = origin, .ambiguous = ambiguous };
    } else {
        polygon_overflowed = true;
    }
}

pub fn polygon(world: usize, owner: usize, body: usize) ?Polygon {
    if (polygon_world != world or polygon_overflowed or body == 0) return null;
    for (&polygons) |*entry| {
        if (entry.body != body) continue;
        return if (entry.ambiguous or entry.owner != owner or entry.world != world) null else entry.origin;
    }
    return null;
}

pub const Status = enum { absent, bound, invalid };
pub const Lookup = union(Status) { absent, bound: Origin, invalid };

pub fn lookup(world: usize, owner: usize, body: usize) Lookup {
    if (scene != world or body == 0) return .absent;
    for (records[0..count]) |entry| {
        if (entry.body != body) continue;
        if (entry.owner != owner or entry.world != world) return .invalid;
        return .{ .bound = entry.origin };
    }
    return if (overflowed) .invalid else .absent;
}

pub fn append(hash: *Hash, world: usize, owner: usize, body: usize) Status {
    const origin = switch (lookup(world, owner, body)) {
        .bound => |origin| origin,
        .absent => return .absent,
        .invalid => return .invalid,
    };
    hash.bytes("zillo-thrown-object-part");
    hash.number(origin.clock);
    hash.number(origin.actor_slot);
    hash.number(origin.generation);
    hash.number(origin.throw_slot);
    hash.number(origin.model);
    return .bound;
}
