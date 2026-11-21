const std = @import("std");
const state = @import("cadence_state.zig");
const hooks = @import("hook_transaction.zig");
const origins = @import("zillo_support_origin.zig");
const protocol = @import("protocol.zig");

extern fn zillo_island_order_entry() void;
extern fn zillo_island_contact_order_entry() void;
extern fn native_scene_support_source(usize, *[2]u32) c_int;
extern fn physics_effect_ordering_source(usize, *[2]u32) c_int;
export var zillo_island_order_resume: usize = 0xa365d5;
export var zillo_island_contact_order_resume: usize = 0xa123b5;
pub export var clonewars_zillo_island_order_debug: [10]u32 = @splat(0);

pub fn patches() [2]hooks.Patch {
    return .{
        .{ .address = 0xa365d0, .expected = "\x51\xd9\x44\x24\x0c", .target = @intFromPtr(&zillo_island_order_entry) },
        .{ .address = 0xa123b0, .expected = "\x53\x8b\x5c\x24\x08", .target = @intFromPtr(&zillo_island_contact_order_entry) },
    };
}

const Member = struct {
    body: usize,
    key: [6]u32,
    name: [32]u8 = @splat(0),
};

const IslandSource = enum {
    none,
    thrown,
    detached_effect,

    fn matches(self: IslandSource, member: Member) bool {
        return switch (self) {
            .none => false,
            .thrown => member.key[0] == 1,
            .detached_effect => member.key[0] == 6,
        };
    }
};

fn order(a: Member, b: Member) std.math.Order {
    const source_order = std.mem.order(u32, &a.key, &b.key);
    return if (source_order == .eq) std.mem.order(u8, &a.name, &b.name) else source_order;
}

fn lessThan(_: void, a: Member, b: Member) bool {
    return order(a, b) == .lt;
}

fn actorMember(access: *state.win.AccessCache, body: usize) ?Member {
    const actor = @import("vehicle_body_source.zig").identify(access, body) orelse return null;
    return .{ .body = body, .key = .{ 2, 0, actor.slot, actor.generation, 0, actor.character } };
}

fn petalMember(access: *state.win.AccessCache, body: usize, owner: usize) ?Member {
    if (state.read(u8, body + 0x19) != 0x40 or !access.accessible(owner, 0x1a4, false) or
        state.read(u32, owner) != 0xc20f64 or state.read(usize, owner + 0x1a0) != body) return null;
    const shape = state.read(usize, body + 0x24);
    const name = state.read(usize, body + 0x1c);
    if (!access.accessible(shape, 4, false) or state.read(u32, shape) != 0xc69b0c or
        !access.accessible(name, 9, false)) return null;
    const label = state.read([9]u8, name);
    if (!std.mem.eql(u8, label[0..7], "Petals_") or label[7] < '0' or label[7] > '7' or label[8] != 0) return null;
    var source: [2]u32 = undefined;
    if (native_scene_support_source(body, &source) == 0) return null;
    return .{ .body = body, .key = .{ 4, 0, source[0], source[1], 0, 0 } };
}

fn polygonMember(access: *state.win.AccessCache, world: usize, body: usize, owner: usize) ?Member {
    const origin = origins.polygon(world, owner, body) orelse return null;
    if (!access.accessible(owner, 0x1a4, false) or state.read(u32, owner) != 0xc20f64 or
        state.read(usize, owner + 0x1a0) != body) return null;
    const shape = state.read(usize, body + 0x24);
    if (!access.accessible(shape, 4, false) or state.read(u32, shape) != 0xc695d4) return null;
    return .{ .body = body, .key = .{ 5, origin.root_clock, origin.clock, origin.mode, 0, 0 } };
}

fn effectMember(access: *state.win.AccessCache, body: usize, owner: usize) ?Member {
    if (!access.accessible(owner, 0x1a4, false) or state.read(u32, owner) != 0xc20f64 or
        state.read(usize, owner + 0x1a0) != body) return null;
    const shape = state.read(usize, body + 0x24);
    if (!access.accessible(shape, 4, false) or state.read(u32, shape) != 0xc695d4) return null;
    var source: [2]u32 = undefined;
    if (physics_effect_ordering_source(body, &source) == 0) return null;
    return .{ .body = body, .key = .{ 6, 0, source[0], source[1], 0, 0 } };
}

fn nativeName(access: *state.win.AccessCache, address: usize, expected: []const u8) bool {
    if (!access.accessible(address, expected.len + 1, false) or state.read(u8, address + expected.len) != 0) return false;
    return std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..expected.len], expected);
}

fn zilloAssemblyResource(access: *state.win.AccessCache, world: usize) bool {
    if (!access.accessible(world, 0x22e8, false)) return false;
    const container = state.read(usize, world + 0x22e4);
    const registry = state.read(usize, 0xf9dd10);
    if (!access.accessible(container, 0x10, false) or state.read(u32, container) != 0xada098 or
        state.read(usize, container + 0xc) != world or !access.accessible(registry, 8 + 85 * 4, false)) return false;
    const resource = state.read(usize, registry + 8 + 84 * 4);
    return access.accessible(resource, 0x58, false) and state.read(usize, resource + 0x54) == container and
        state.read(usize, resource + 0x4c) == 0 and
        nativeName(access, state.read(usize, resource + 0x34), "ZilloBeast_B_temp.led") and
        nativeName(access, state.read(usize, resource + 0x40), "ZilloBeast_B_temp");
}

const DishPart = struct { name: []const u8, shape_class: u32 };
const dish_parts = [_]DishPart{
    .{ .name = "joint1", .shape_class = 0xc695d4 },
    .{ .name = "joint2", .shape_class = 0xc69b0c },
    .{ .name = "joint3", .shape_class = 0xc695d4 },
    .{ .name = "joint4", .shape_class = 0xc69b0c },
    .{ .name = "joint5", .shape_class = 0xc69b0c },
    .{ .name = "signal_base", .shape_class = 0xc69b7c },
    .{ .name = "joint11", .shape_class = 0xc69b7c },
    .{ .name = "signal_dish", .shape_class = 0xc695d4 },
    .{ .name = "joint12", .shape_class = 0xc69b0c },
};

fn assemblyOwner(access: *state.win.AccessCache, owner: usize, body: usize) bool {
    return access.accessible(owner, 0x1a4, false) and state.read(u32, owner) == 0xc20f64 and
        state.read(usize, owner + 0x1a0) == body and state.read(usize, owner + 0x18) == 0 and
        state.read(u8, owner + 6) == 84;
}

fn dishPartMatches(access: *state.win.AccessCache, owner: usize, physics: usize, part: DishPart) bool {
    if (!access.accessible(owner, 0x1a4, false)) return false;
    const body = state.read(usize, owner + 0x1a0);
    if (!assemblyOwner(access, owner, body) or !access.accessible(body, 0xa4, false) or
        state.read(u32, body) != 0xc69eac or state.read(u16, body + 0x18) != 0x4f01 or
        state.read(usize, body + 0x28) != owner or state.read(usize, body + 0x2c) != physics or
        state.read(usize, body + 0x34) == 0 or state.read(u8, body + 0x90) & 1 == 0) return false;
    const counted = state.read(usize, owner + 0xc);
    const shape = state.read(usize, body + 0x24);
    return access.accessible(counted, part.name.len + 2, false) and state.read(u8, counted) == part.name.len + 2 and
        nativeName(access, counted + 1, part.name) and nativeName(access, state.read(usize, body + 0x1c), part.name) and
        access.accessible(shape, 4, false) and state.read(u32, shape) == part.shape_class;
}

fn registeredWorldPhysics(access: *state.win.AccessCache, world: usize, physics: usize) bool {
    const scheduler = state.read(usize, 0xfb0b10);
    if (!access.accessible(scheduler, 0x30, false)) return false;
    const container = state.read(usize, world + 0x22e4);
    var node = state.read(usize, scheduler + 0x2c);
    var previous: usize = 0;
    var found = false;
    for (0..512) |_| {
        if (node == 0) return found;
        if (!access.accessible(node, 0xc, false) or state.read(usize, node + 4) != previous) return false;
        const entry = state.read(usize, node + 8);
        if (!access.accessible(entry, 0xc, false)) return false;
        const listener = state.read(usize, entry);
        if (!access.accessible(listener, 4, false)) return false;
        if (state.read(u32, listener) == 0xc213dc) {
            if (!access.accessible(listener, 0x28, false)) return false;
            if (state.read(usize, listener + 0xc) == container) {
                if (found or state.read(usize, listener + 0x24) != physics) return false;
                found = true;
            }
        }
        previous = node;
        node = state.read(usize, node);
    }
    return node == 0 and found;
}

fn dishMember(access: *state.win.AccessCache, world: usize, body: usize, owner: usize) ?Member {
    if (state.read(u16, body + 0x18) != 0x4f01 or !assemblyOwner(access, owner, body)) return null;
    const name = state.read(usize, body + 0x1c);
    const index = for (dish_parts, 0..) |part, i| {
        if (nativeName(access, name, part.name)) break i;
    } else return null;
    if (!zilloAssemblyResource(access, world)) return null;
    const physics = state.read(usize, body + 0x2c);
    if (!access.accessible(physics, 0x14, false)) return null;

    // Unplaced copies have the same part names and resource as the placed assembly.
    var current = owner;
    for (0..index) |_| {
        const previous = state.read(usize, current + 0x1c);
        if (!access.accessible(previous, 0x24, false) or state.read(usize, previous + 0x20) != current) return null;
        current = previous;
    }
    const first = current;
    const plate = state.read(usize, first + 0x1c);
    if (!access.accessible(plate, 0x1a4, false) or state.read(u32, plate) != 0xc20f64 or
        state.read(usize, plate + 0x20) != first) return null;
    const plate_body = state.read(usize, plate + 0x1a0);
    if (!access.accessible(plate_body, 0xa4, false) or state.read(u32, plate_body) != 0xc69eac or
        state.read(u16, plate_body + 0x18) != 0x2001 or state.read(usize, plate_body + 0x28) != plate or
        !nativeName(access, state.read(usize, plate_body + 0x1c), "plate_grey_solid")) return null;
    var previous = plate;
    for (dish_parts, 0..) |part, i| {
        if (!dishPartMatches(access, current, physics, part) or state.read(usize, current + 0x1c) != previous or
            (i == index and current != owner)) return null;
        previous = current;
        current = state.read(usize, current + 0x20);
    }
    // Stock can remove the plate collider while the nine attached scene parts remain in the solver.
    const plate_physics = state.read(usize, plate_body + 0x2c);
    if (plate_physics != physics and
        (plate_physics != 0 or state.read(usize, plate_body + 0x34) != 0 or state.read(u8, plate_body + 0x90) & 1 != 0 or
            !registeredWorldPhysics(access, world, physics))) return null;
    var source: [2]u32 = undefined;
    if (native_scene_support_source(plate_body, &source) == 0) return null;
    return .{ .body = body, .key = .{ 8, 0, source[0], source[1], @intCast(index), dish_parts[index].shape_class } };
}

fn assembledActorMember(access: *state.win.AccessCache, world: usize, body: usize, owner: usize) ?Member {
    if (state.read(u8, body + 0x19) != 0x4f or !assemblyOwner(access, owner, body) or !zilloAssemblyResource(access, world)) return null;

    const shape = state.read(usize, body + 0x24);
    if (!access.accessible(shape, 4, false)) return null;
    const shape_class = state.read(u32, shape);
    const pool = state.read(usize, 0xfb2f60);
    const count = state.read(u32, 0xfb2e3c);
    if (count == 0 or count > protocol.SYNC_MAX_ACTORS or !access.accessible(pool, count * 0x1440, false)) return null;
    var result: ?Member = null;
    for (0..count) |index| {
        const actor = pool + index * 0x1440;
        if (state.read(u32, actor + 0x50) & 3 != 3) continue;
        const character = state.read(u16, actor + 0xdc0);
        const name = state.read(usize, actor + 0x14);
        switch (character) {
            127 => if ((shape_class != 0xc699f4 and shape_class != 0xc695d4) or
                !nativeName(access, name, "zillobeast")) continue,
            472 => if ((shape_class != 0xc697ec and shape_class != 0xc69b0c) or
                !nativeName(access, name, "clone_tr57_cannon")) continue,
            429 => if (shape_class != 0xc69b0c or !nativeName(access, name, "stun_tank_chassis")) continue,
            430 => if (shape_class != 0xc69b0c or !nativeName(access, name, "stun_tank_turret")) continue,
            else => continue,
        }
        const link = state.read(usize, actor + 8);
        if (!access.accessible(link, 0x40, false)) continue;
        const skin = state.read(usize, link + 0x3c);
        if (!access.accessible(skin, 0xc, false) or state.read(u32, skin) != 1) continue;
        const model = state.read(usize, skin + 8);
        if (!access.accessible(model, 0xd8, false) or state.read(u32, model) != 0xc1ed6c or
            state.read(usize, model + 0x10) != skin) continue;
        const parts = state.read(usize, model + 0xd0);
        const part_count = state.read(u16, model + 0xd6);
        if (part_count == 0 or part_count > 128 or !access.accessible(parts, @as(usize, part_count) * 4, false)) continue;
        for (0..part_count) |part_index| {
            const part = state.read(usize, parts + 4 * part_index);
            if (!access.accessible(part, 0x14, false) or state.read(u32, part) != 0xc1cc18 or
                state.read(usize, part + 0x10) != body) continue;
            var slot: u32 = undefined;
            var generation: u32 = undefined;
            if (result != null or state.entities_observed_identity(actor, &slot, &generation) == 0 or
                slot >= protocol.SYNC_MAX_ACTORS or generation == 0 or state.entities_actor(slot, generation) != actor) return null;
            result = .{ .body = body, .key = .{ 7, character, slot, generation, @intCast(part_index), shape_class } };
        }
    }
    return result;
}

fn identify(access: *state.win.AccessCache, world: usize, body: usize) ?Member {
    if (state.read(usize, body) != 0xc69eac or state.read(u8, body + 0x19) & 0x60 != 0x40) return null;
    const owner = state.read(usize, body + 0x28);
    const origin = switch (origins.lookup(world, owner, body)) {
        .bound => |origin| origin,
        .absent => return if (owner == 0) actorMember(access, body) else polygonMember(access, world, body, owner) orelse petalMember(access, body, owner) orelse
            effectMember(access, body, owner) orelse assembledActorMember(access, world, body, owner) orelse dishMember(access, world, body, owner),
        .invalid => return null,
    };
    if (!access.accessible(owner, 0x1a4, false) or state.read(usize, owner) != 0xc20f64 or
        state.read(usize, owner + 0x1a0) != body) return null;
    const name = state.read(usize, body + 0x1c);
    if (!access.accessible(name, 32, false)) return null;
    const raw = state.read([32]u8, name);
    const length = std.mem.indexOfScalar(u8, &raw, 0) orelse return null;
    if (length == 0) return null;
    var result = Member{ .body = body, .key = .{ 1, origin.clock, origin.actor_slot, origin.generation, origin.throw_slot, origin.model } };
    @memcpy(result.name[0..length], raw[0..length]);
    return result;
}

export fn zillo_island_order_before_solve(island: usize, caller: usize) void {
    const last_error = state.win.GetLastError();
    defer state.win.SetLastError(last_error);
    if (caller != 0xa3a835 and caller != 0xa3a84e) return;
    var lease: state.Lease = undefined;
    if (!state.ready(&lease) or lease.cohort.thread != state.win.GetCurrentThreadId() or
        state.journal.frame.?.level != 112) return;
    var access: state.win.AccessCache = .{};
    if (!access.accessible(island, 0x18, true)) return;
    const world = state.read(usize, 0xfb4a20);
    var body = state.read(usize, island + 8);
    const source = islandSource(&access, world, island);
    if (source == .none) return;
    var previous: usize = 0;
    var members: [128]Member = undefined;
    var count: usize = 0;
    var has_source = false;
    var has_vehicle = false;
    clonewars_zillo_island_order_debug[0] +%= 1;
    while (body != 0) {
        if (count == members.len or !access.accessible(body, 0xa4, true) or
            state.read(usize, body + 0x14) != previous or state.read(usize, body + 0x34) != island)
        {
            clonewars_zillo_island_order_debug[4] +%= 1;
            return;
        }
        members[count] = identify(&access, world, body) orelse {
            clonewars_zillo_island_order_debug[3] +%= 1;
            return;
        };
        has_source = has_source or source.matches(members[count]);
        has_vehicle = has_vehicle or members[count].key[0] == 2;
        count += 1;
        previous = body;
        body = state.read(usize, body + 0x10);
    }
    if (count < 2 or !has_source) return;

    const chain = members[0..count];
    const ordered = std.sort.isSorted(Member, chain, {}, lessThan);
    if (!ordered) std.sort.pdq(Member, chain, {}, lessThan);
    for (chain[1..], chain[0 .. count - 1]) |current, before| {
        if (order(before, current) != .lt) {
            clonewars_zillo_island_order_debug[5] +%= 1;
            return;
        }
    }
    if (!state.live(&lease) or world != state.read(usize, 0xfb4a20)) return;
    clonewars_zillo_island_order_debug[1] +%= 1;
    clonewars_zillo_island_order_debug[6] +%= @intFromBool(has_vehicle);
    if (!ordered) {
        for (chain, 0..) |member, index| {
            state.win.store(usize, member.body + 0x10, if (index + 1 < count) chain[index + 1].body else 0);
            state.win.store(usize, member.body + 0x14, if (index != 0) chain[index - 1].body else 0);
        }
        state.win.store(usize, island + 8, chain[0].body);
        clonewars_zillo_island_order_debug[2] +%= 1;
    }
}

const Contact = struct { address: usize, first: usize, second: usize };
const max_contact_links = 1024;

fn contactOrder(members: []const Member, a: Contact, b: Contact) std.math.Order {
    const first = order(members[a.first], members[b.first]);
    return if (first == .eq) order(members[a.second], members[b.second]) else first;
}

fn contactLessThan(members: []const Member, a: Contact, b: Contact) bool {
    return contactOrder(members, a, b) == .lt;
}

fn endpoint(access: *state.win.AccessCache, world: usize, body: usize, members: *[128]Member, count: *usize) ?usize {
    for (members[0..count.*], 0..) |member, index| if (member.body == body) return index;
    if (count.* == members.len or !access.accessible(body, 0xa4, false)) return null;
    const key = identify(access, world, body) orelse blk: {
        var source: [2]u32 = undefined;
        if (state.read(u8, body + 0x19) & 0x60 != 0x20 or native_scene_support_source(body, &source) == 0) return null;
        break :blk Member{ .body = body, .key = .{ 3, 0, source[0], source[1], 0, 0 } };
    };
    for (members[0..count.*]) |other| if (order(other, key) == .eq) return null;
    const index = count.*;
    members[index] = key;
    count.* += 1;
    return index;
}

fn islandSource(access: *state.win.AccessCache, world: usize, island: usize) IslandSource {
    var body = state.read(usize, island + 8);
    var previous: usize = 0;
    var keys: [128][6]u32 = undefined;
    var has_effect = false;
    var only_detached_members = true;
    for (0..keys.len) |index| {
        if (body == 0) break;
        if (!access.accessible(body, 0xa4, false)) return .none;
        const owner = state.read(usize, body + 0x28);
        switch (origins.lookup(world, owner, body)) {
            .bound => return .thrown,
            .invalid => only_detached_members = false,
            .absent => if (only_detached_members) {
                const member = if (owner != 0 and state.read(usize, body) == 0xc69eac and
                    state.read(u8, body + 0x19) & 0x60 == 0x40 and
                    state.read(usize, body + 0x14) == previous and
                    state.read(usize, body + 0x34) == island)
                    polygonMember(access, world, body, owner) orelse effectMember(access, body, owner) orelse
                        petalMember(access, body, owner)
                else
                    null;
                only_detached_members = member != null;
                if (member) |item| {
                    for (keys[0..index]) |key| {
                        if (std.mem.eql(u32, &key, &item.key)) only_detached_members = false;
                    }
                    keys[index] = item.key;
                    has_effect = has_effect or IslandSource.detached_effect.matches(item);
                }
            },
        }
        previous = body;
        body = state.read(usize, body + 0x10);
    }
    // A detached effect can share a solver island with the registered petals without a boss throw.
    return if (body == 0 and only_detached_members and has_effect) .detached_effect else .none;
}

export fn zillo_island_order_before_contacts(island: usize, caller: usize) void {
    const last_error = state.win.GetLastError();
    defer state.win.SetLastError(last_error);
    if (caller != 0xa3665d) return;
    var lease: state.Lease = undefined;
    if (!state.ready(&lease) or lease.cohort.thread != state.win.GetCurrentThreadId() or
        state.journal.frame.?.level != 112) return;
    var access: state.win.AccessCache = .{};
    if (!access.accessible(island, 0x18, true)) return;
    const world = state.read(usize, 0xfb4a20);
    const source = islandSource(&access, world, island);
    if (source == .none) return;
    var members: [128]Member = undefined;
    var member_count: usize = 0;
    var links: [max_contact_links]Contact = undefined;
    var count: usize = 0;
    var link = state.read(usize, island + 0xc);
    var previous: usize = 0;
    var has_source = false;
    while (link != 0) {
        if (count == links.len or !access.accessible(link, 0x20, true) or state.read(usize, link) != 0xc696d4 or
            state.read(usize, link + 8) != previous) return;
        const first = endpoint(&access, world, state.read(usize, link + 0xc), &members, &member_count) orelse {
            clonewars_zillo_island_order_debug[9] +%= 1;
            return;
        };
        const second = endpoint(&access, world, state.read(usize, link + 0x10), &members, &member_count) orelse {
            clonewars_zillo_island_order_debug[9] +%= 1;
            return;
        };
        if (first == second) return;
        has_source = has_source or source.matches(members[first]) or source.matches(members[second]);
        links[count] = .{ .address = link, .first = first, .second = second };
        count += 1;
        previous = link;
        link = state.read(usize, link + 4);
    }
    if (count < 2 or !has_source) return;

    const chain = links[0..count];
    const keys = members[0..member_count];
    const ordered = std.sort.isSorted(Contact, chain, keys, contactLessThan);
    if (!ordered) std.sort.pdq(Contact, chain, keys, contactLessThan);
    for (chain[1..], chain[0 .. count - 1]) |current, before| {
        if (contactOrder(keys, before, current) != .lt) {
            clonewars_zillo_island_order_debug[9] +%= 1;
            return;
        }
    }
    if (!state.live(&lease) or world != state.read(usize, 0xfb4a20)) return;
    clonewars_zillo_island_order_debug[7] +%= 1;
    if (!ordered) {
        // The native solver consumes these links in order after collision geometry is available.
        for (chain, 0..) |contact, index| {
            state.win.store(usize, contact.address + 4, if (index + 1 < count) chain[index + 1].address else 0);
            state.win.store(usize, contact.address + 8, if (index != 0) chain[index - 1].address else 0);
        }
        state.win.store(usize, island + 0xc, chain[0].address);
        clonewars_zillo_island_order_debug[8] +%= 1;
    }
}

comptime {
    asm (
        \\.text
        \\.macro island_sort_call callback
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\subl $8,%esp
        \\movl 12(%edx),%eax
        \\pushl 4(%eax)
        \\pushl 24(%edx)
        \\call \callback
        \\addl $16,%esp
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\.endm
        \\.globl _zillo_island_order_entry
        \\_zillo_island_order_entry:
        \\island_sort_call _zillo_island_order_before_solve
        \\pushl %ecx
        \\flds 12(%esp)
        \\jmp *_zillo_island_order_resume
        \\.globl _zillo_island_contact_order_entry
        \\_zillo_island_contact_order_entry:
        \\island_sort_call _zillo_island_order_before_contacts
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\jmp *_zillo_island_contact_order_resume
    );
}
