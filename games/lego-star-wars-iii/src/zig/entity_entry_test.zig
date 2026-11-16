const std = @import("std");
const p = @import("protocol.zig");
const s = @import("entity_state.zig");
const r = @import("entity_registry.zig");
const b = @import("entity_binding.zig");
const party = @import("entity_party.zig");
const reference = @import("tag_reference.zig").reference;
const win = s.win;
const check = @import("native_test_support.zig").check;
const stride = 0x1440;
var pool_address: usize = 0;
var players: [8]usize = @splat(0);
pub const entity_test_api = struct {
    pub fn pool() usize {
        return pool_address;
    }
    pub fn player(index: usize) usize {
        return players[index];
    }
};
export fn lan_is_host() c_int {
    return 0;
}
export fn game_actor_count() c_int {
    return 4;
}
export fn native_roster_source_revalidate(_: *const s.Roster, _: usize) c_int {
    return 0;
}
export fn native_hub_source_revalidate(_: *const s.Hub) c_int {
    return 0;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn character(actor: usize, value: i16) void {
    win.store(i16, actor + 0xdc0, value);
}
fn playerSlot(actor: usize, value: i8) void {
    win.store(i8, actor + 0x55, value);
}
fn source(actor: usize, site: u32, producer: u32, serial: u32) void {
    r.entities_note_spawn_source(actor, site, .{ .producer = producer, .serial = serial });
}
const Fixture = struct {
    saved_pool: usize,
    saved_players: [8]usize,
    allocation: []u8,
    frame: *p.SyncFrame,
    fn init() Fixture {
        const allocation = std.heap.c_allocator.alloc(u8, 4 * stride) catch @panic("allocation failed");
        @memset(allocation, 0);
        const frame = std.heap.c_allocator.create(p.SyncFrame) catch @panic("allocation failed");
        @memset(std.mem.asBytes(frame), 0);
        const result: Fixture = .{ .saved_pool = pool_address, .saved_players = players, .allocation = allocation, .frame = frame };
        pool_address = @intFromPtr(allocation.ptr);
        players = @splat(0);
        return result;
    }
    fn deinit(self: Fixture) void {
        std.heap.c_allocator.destroy(self.frame);
        std.heap.c_allocator.free(self.allocation);
        pool_address = self.saved_pool;
        players = self.saved_players;
        r.entities_update();
    }
};
fn operand(actor: usize) p.SyncTagIdentity {
    var described = std.mem.zeroes(p.SyncActor);
    r.entities_describe(&described, actor);
    return .{ .character = win.load(i16, actor + 0xdc0), .spawn_tag = described.spawn_tag, .spawn_source = described.spawn_source };
}
fn prepareParty(frame: *p.SyncFrame) void {
    const characters = [_]i16{ 199, 176, 138, 138 };
    for (characters, 0..) |value, i| {
        const actor = pool_address + i * stride;
        players[i] = actor;
        playerSlot(actor, @intCast(i));
        win.store(f32, actor + 0x24, @as(f32, @floatFromInt(i)) + 1);
        put(actor + 0x50, 3);
        character(actor, value);
    }
    r.entities_update();
    frame.sequence = 1;
    frame.actor_count = 4;
    for (characters, 0..) |value, i| {
        const state = &frame.actors[i];
        r.entities_describe(state, players[i]);
        state.slot = @intCast(i);
        state.generation = @intCast(100 + i);
        state.character = value;
        state.health = 4;
    }
    frame.actors[2].spawn_position[0] -= 0.49;
    frame.actors[3].spawn_position[0] += 0.75;
}
fn partyBinding() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const frame = fixture.frame;
    prepareParty(frame);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    check(@src(), r.entities_actor(2, 102) == players[2] and r.entities_actor(3, 103) == players[3]);
    frame.sequence = 2;
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    const from = players[0];
    const to = players[2];
    frame.actors[0].player = -1;
    frame.actors[0].party_slot = 2;
    frame.actors[2].player = 0;
    frame.actors[2].party_slot = 0;
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) == 0);
    check(@src(), r.entities_actor(0, 100) == from and r.entities_actor(2, 102) == to);
    check(@src(), r.entities_slot(from) == 0 and r.entities_generation(from) == 100 and r.entities_slot(to) == 2 and r.entities_generation(to) == 102);
    players[0] = to;
    players[2] = from;
    playerSlot(from, 2);
    playerSlot(to, 0);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    check(@src(), r.entities_actor(0, 100) == from and r.entities_actor(2, 102) == to);
    frame.actors[0].player = 0;
    frame.actors[0].party_slot = 0;
    frame.actors[2].player = -1;
    frame.actors[2].party_slot = 2;
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) == 0);
    players[0] = from;
    players[2] = to;
    playerSlot(from, 0);
    playerSlot(to, 2);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    r.entities_reset_bindings();
    check(@src(), b.entities_bind(frame) == 0);
    r.entities_reset_bindings();
    frame.sequence = 1;
    playerSlot(players[2], -1);
    check(@src(), b.entities_bind(frame) == 0 and r.entities_actor(2, 102) == 0);
    r.entities_reset_bindings();
    playerSlot(players[2], 2);
    frame.actors[2].spawn_tag += 1;
    check(@src(), b.entities_bind(frame) == 0 and r.entities_actor(2, 102) == 0);
    r.entities_reset_bindings();
    prepareParty(frame);
    check(@src(), b.entities_bind(frame) != 0);
    const reserve = players[3];
    put(reserve + 0x50, 1);
    frame.actor_count -= 1;
    check(@src(), party.entities_collect_dormant_party(frame) != 0 and frame.dormant_party[3] == 139);
    put(reserve + 0x50, 3);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) == 0);
    var slot: u32 = 0;
    var generation: u32 = 0;
    check(@src(), r.entities_observed_identity(reserve, &slot, &generation) != 0 and slot == 3 and generation == 103);
    check(@src(), r.entities_resolve_reference(&frame.actors[3]) == reserve);
    put(reserve + 0x50, 1);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    check(@src(), r.entities_observed_identity(reserve, &slot, &generation) == 0);
    players[3] = 0;
    check(@src(), party.entities_party_matches(frame) == 0);
    players[3] = reserve;
    frame.dormant_party[3] += 1;
    check(@src(), party.entities_party_matches(frame) == 0);
    frame.dormant_party[3] -= 1;
    playerSlot(reserve, 2);
    check(@src(), party.entities_party_matches(frame) == 0 and party.entities_collect_dormant_party(frame) == 0);
    playerSlot(reserve, 3);
    put(reserve + 0x50, 3);
    check(@src(), party.entities_party_matches(frame) == 0);
    frame.actor_count += 1;
    check(@src(), party.entities_collect_dormant_party(frame) != 0 and frame.dormant_party[3] == 0);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    character(players[0], 200);
    check(@src(), b.entities_bind(frame) == 0 and r.entities_actor(0, 100) == 0);
}
fn retiringOperands() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const frame = fixture.frame;
    const from = pool_address;
    const duplicate = from + stride;
    const to = from + 2 * stride;
    const last = from + 3 * stride;
    for ([_]i16{ 329, 329, 189, 183 }, 0..) |value, i| {
        const actor = pool_address + i * stride;
        character(actor, value);
        put(actor + 0x50, if (i == 1) 0 else 3);
        playerSlot(actor, -1);
    }
    r.entities_update();
    source(from, 0x5c5ef6, 1, 0);
    source(to, 0x5c5ce6, 0xe101, 2);
    source(last, 0x5c5ce6, 0xe101, 3);
    const from_key = operand(from);
    const to_key = operand(to);
    const last_key = operand(last);
    var from_ref = reference(70, 900, &from_key).?;
    var to_ref = reference(71, 901, &to_key).?;
    var last_ref = reference(72, 902, &last_key).?;
    for ([_]*p.SyncActor{ &from_ref, &to_ref, &last_ref }) |entry| {
        entry.player = -1;
        entry.party_slot = -1;
        entry.health = 4;
    }
    frame.sequence = 2;
    frame.actor_count = 2;
    frame.actors[0] = from_ref;
    frame.actors[1] = to_ref;
    check(@src(), b.entities_bind(frame) != 0);
    frame.actor_count = 1;
    frame.actors[0] = to_ref;
    check(@src(), b.entities_bind(frame) != 0);
    check(@src(), r.entities_resolve_identity(frame, 70, 900) == 0 and r.entities_resolve_reference(&from_ref) == from and r.entities_resolve_reference(&to_ref) == to);
    for (0..5) |field| {
        var wrong = from_ref;
        switch (field) {
            0 => wrong.generation += 1,
            1 => wrong.character += 1,
            2 => wrong.spawn_source.serial += 1,
            3 => wrong.spawn_source.producer += 1,
            else => wrong.spawn_tag += 1,
        }
        check(@src(), r.entities_resolve_reference(&wrong) == 0);
    }
    character(from, 330);
    r.entities_update();
    check(@src(), r.entities_resolve_reference(&from_ref) == 0);
    character(from, 329);
    r.entities_update();
    check(@src(), r.entities_resolve_reference(&from_ref) == 0);
    r.entities_reset_bindings();
    check(@src(), r.entities_resolve_reference(&from_ref) == from);
    put(duplicate + 0x50, 3);
    r.entities_update();
    source(duplicate, from_key.spawn_tag, from_key.spawn_source.producer, from_key.spawn_source.serial);
    check(@src(), r.entities_resolve_reference(&from_ref) == 0);
    put(duplicate + 0x50, 0);
    r.entities_update();
    check(@src(), r.entities_resolve_reference(&from_ref) == from);
    var missing_source = to_key;
    missing_source.spawn_source = .{ .producer = 0, .serial = 0 };
    const unsupported = reference(71, 901, &missing_source).?;
    check(@src(), r.entities_resolve_reference(&unsupported) == 0);
    check(@src(), reference(-1, 901, &to_key) == null and reference(p.SYNC_MAX_ACTORS, 901, &to_key) == null and reference(71, 0, &to_key) == null);
    var invalid = to_key;
    invalid.character = -1;
    check(@src(), reference(71, 901, &invalid) == null);
    invalid.character = 4096;
    check(@src(), reference(71, 901, &invalid) == null);
    frame.actors[0] = last_ref;
    put(from + 0x50, 0);
    r.entities_update();
    check(@src(), r.entities_resolve_reference(&from_ref) == 0);
    check(@src(), r.entities_resolve_identity(frame, 71, 901) == 0 and r.entities_resolve_reference(&to_ref) == to and r.entities_resolve_reference(&last_ref) == last);
    put(to + 0x50, 0);
    r.entities_update();
    check(@src(), r.entities_resolve_reference(&to_ref) == 0 and r.entities_resolve_reference(&last_ref) == last);
}
fn coldTagBinding() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const frame = fixture.frame;
    for ([_]i16{ 329, 330, 189, 183 }, 0..) |value, i| {
        const actor = pool_address + i * stride;
        put(actor + 0x50, 3);
        character(actor, value);
        playerSlot(actor, if (i < 2) @intCast(i) else -1);
    }
    players[0] = pool_address;
    players[1] = pool_address + stride;
    r.entities_update();
    for (0..4) |i| source(pool_address + i * stride, if (i < 2) 0x5c5ef6 else 0x5c5ce6, if (i < 2) 1 else 2, @intCast(i % 2));
    frame.sequence = 1;
    frame.actor_count = 2;
    frame.tag_count = 2;
    for (0..2) |i| {
        const from = 1 - i;
        const to = 2 + i;
        const tag = &frame.tags[i];
        tag.id = @intCast(i + 1);
        tag.from = @intCast(from);
        tag.to = @intCast(to);
        tag.from_generation = @intCast(100 + from);
        tag.to_generation = @intCast(100 + to);
        tag.from_identity = operand(pool_address + from * stride);
        tag.to_identity = operand(pool_address + to * stride);
        frame.actors[i] = reference(@intCast(to), @intCast(100 + to), &tag.to_identity).?;
        frame.actors[i].player = @intCast(from);
        frame.actors[i].party_slot = @intCast(from);
        frame.actors[i].health = 4;
    }
    check(@src(), b.entities_bind(frame) != 0);
    for (0..4) |i| check(@src(), r.entities_actor(@intCast(i), @intCast(100 + i)) == pool_address + i * stride);
    check(@src(), party.entities_party_matches(frame) == 0);
    for (0..2) |i| put(pool_address + i * stride + 0x50, 0);
    players[0] = pool_address + 3 * stride;
    players[1] = pool_address + 2 * stride;
    playerSlot(players[0], 0);
    playerSlot(players[1], 1);
    check(@src(), b.entities_bind(frame) != 0 and party.entities_party_matches(frame) != 0);
    check(@src(), r.entities_actor(0, 100) == 0 and r.entities_actor(1, 101) == 0 and r.entities_actor(2, 102) == players[1] and r.entities_actor(3, 103) == players[0]);
    frame.tags[0].from = 2;
    frame.tags[0].from_generation = 999;
    frame.tags[0].from_identity = frame.tags[0].to_identity;
    check(@src(), b.entities_bind(frame) != 0 and r.entities_actor(2, 102) == players[1] and r.entities_actor(2, 999) == 0);
}
fn lastWeaponCommand() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const frame = fixture.frame;
    const actor = pool_address;
    put(actor + 0x50, 3);
    character(actor, 381);
    playerSlot(actor, -1);
    r.entities_update();
    source(actor, 123, 1, 2);
    frame.sequence = 2;
    frame.actor_count = 1;
    r.entities_describe(&frame.actors[0], actor);
    const state = &frame.actors[0];
    state.slot = 70;
    state.generation = 900;
    state.player = -1;
    state.party_slot = -1;
    state.health = 2;
    state.character = 381;
    const original = state.*;
    check(@src(), b.entities_bind(frame) != 0);
    frame.actor_count = 0;
    frame.tick_gate_count = 3;
    const sites = @import("tick_sites.zig");
    frame.tick_gates[0] = .{ .site = sites.WEAPON_COMMAND_ACTOR, .clock = 100, .value = 70 };
    frame.tick_gates[1] = .{ .site = sites.WEAPON_COMMAND_GENERATION, .clock = 100, .value = 900 };
    frame.tick_gates[2] = .{ .site = sites.WEAPON_COMMAND_VALUE, .clock = 100, .value = 0xfffefe03 };
    check(@src(), b.entities_bind_tick(frame) != 0 and r.entities_actor(70, 900) == actor and r.entities_generation(actor) == 900);
    frame.tick_gate_count = 2;
    check(@src(), b.entities_bind_tick(frame) == 0 and r.entities_actor(70, 900) == actor);
    frame.tick_gate_count = 3;
    check(@src(), b.entities_bind(frame) != 0 and r.entities_actor(70, 900) == 0 and r.entities_generation(actor) == 0);
    state.* = original;
    frame.actor_count = 1;
    check(@src(), b.entities_bind(frame) != 0);
    state.generation = 901;
    check(@src(), b.entities_bind_tick(frame) != 0 and r.entities_actor(70, 900) == actor and r.entities_actor(70, 901) == 0);
    put(actor + 0x50, 0);
    r.entities_update();
    put(actor + 0x50, 3);
    r.entities_update();
    source(actor, 123, 1, 2);
    check(@src(), b.entities_bind(frame) != 0 and r.entities_actor(70, 901) == actor and r.entities_actor(70, 900) == 0);
    put(actor + 0x50, 0);
    r.entities_update();
    frame.actor_count = 0;
    check(@src(), b.entities_bind_tick(frame) != 0 and r.entities_actor(70, 900) == 0);
    const newborn = pool_address + 2 * stride;
    frame.actor_count = 1;
    state.* = original;
    state.slot = 72;
    state.generation = 904;
    state.character = 357;
    state.spawn_source = .{ .producer = 5, .serial = 3 };
    check(@src(), b.entities_bind(frame) == 0 and b.entities_bind_native_actor(frame, newborn) == 0);
    put(newborn + 0x50, 3);
    character(newborn, 357);
    playerSlot(newborn, -1);
    r.entities_update();
    source(newborn, original.spawn_tag, 5, 3);
    frame.actor_count = 2;
    frame.actors[1] = state.*;
    frame.actors[1].slot = 73;
    check(@src(), b.entities_bind_native_actor(frame, newborn) == 0);
    frame.actor_count = 1;
    check(@src(), b.entities_bind_native_actor(frame, newborn) != 0 and r.entities_actor(72, 904) == newborn and r.entities_generation(newborn) == 904);
    put(newborn + 0x50, 0);
    r.entities_update();
    check(@src(), b.entities_bind_native_actor(frame, newborn) == 0);
}
fn nativeReferenceBinding() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const actor = pool_address;
    const other = actor + stride;
    put(actor + 0x50, 3);
    character(actor, 381);
    r.entities_update();
    source(actor, 0xcb8c1, 1, 7);
    var ref = std.mem.zeroes(p.SyncActor);
    ref.slot = 70;
    ref.generation = 900;
    ref.character = 381;
    ref.spawn_tag = 0xcb8c1;
    ref.spawn_source = .{ .producer = 1, .serial = 7 };
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0);
    var slot: u32 = 0;
    var generation: u32 = 0;
    check(@src(), r.entities_observed_identity(actor, &slot, &generation) != 0 and slot == 70 and generation == 900);
    const local_generation = r.entities_local_generation(actor);
    put(actor + 0x50, 0x81);
    check(@src(), r.entities_allocation_retained(actor, local_generation) != 0 and r.entities_allocation_live(actor, local_generation) == 0);
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0 and r.entities_resolve_reference(&ref) == 0);
    put(actor + 8, 1);
    check(@src(), r.entities_allocation_retained(actor, local_generation) == 0 and b.entities_bind_native_reference(&ref, actor) == 0);
    put(actor + 8, 0);
    put(actor + 0x50, 3);
    check(@src(), r.entities_allocation_live(actor, local_generation) != 0);
    check(@src(), b.entities_bind(fixture.frame) != 0 and r.entities_observed_identity(actor, &slot, &generation) == 0);
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0);
    var wrong = ref;
    wrong.spawn_source.serial += 1;
    check(@src(), b.entities_bind_native_reference(&wrong, actor) == 0);
    put(actor + 0x50, 0);
    r.entities_update();
    check(@src(), r.entities_allocation_retained(actor, local_generation) == 0 and b.entities_bind_native_reference(&ref, actor) == 0);
    put(actor + 0x50, 3);
    r.entities_update();
    source(actor, 0xcb8c1, 1, 7);
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    ref.generation += 1;
    put(other + 0x50, 3);
    character(other, 381);
    r.entities_update();
    source(other, 0xcb8c1, 1, 7);
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    put(other + 0x50, 0);
    r.entities_update();
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0 and r.entities_actor(70, 901) == actor and r.entities_actor(70, 900) == 0);
    check(@src(), b.entities_bind_native_reference(&ref, other) == 0);
}
fn neverActiveReserve() void {
    const fixture = Fixture.init();
    defer fixture.deinit();
    const actor = pool_address;
    const duplicate = actor + stride;
    put(actor + 0x50, 1);
    put(actor + 8, 0x1234);
    character(actor, 191);
    r.entities_update();
    source(actor, 0x5c5ef6, 1, 1);
    const local_generation = r.entities_observed_generation(actor);
    check(@src(), local_generation != 0 and r.entities_allocation_retained(actor, local_generation) != 0 and r.entities_allocation_live(actor, local_generation) == 0);
    var ref = std.mem.zeroes(p.SyncActor);
    ref.slot = 71;
    ref.generation = 901;
    ref.character = 191;
    ref.spawn_tag = 0x5c5ef6;
    ref.spawn_source = .{ .producer = 1, .serial = 1 };
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0 and r.entities_actor(71, 901) == actor and r.entities_resolve_reference(&ref) == 0);
    var described = std.mem.zeroes(p.SyncActor);
    r.entities_describe(&described, actor);
    check(@src(), std.mem.eql(f32, &described.spawn_position, &.{ 0, 0, 0 }));
    var wrong = ref;
    wrong.spawn_source.serial += 1;
    check(@src(), b.entities_bind_native_reference(&wrong, actor) == 0);
    wrong = ref;
    wrong.character += 1;
    check(@src(), b.entities_bind_native_reference(&wrong, actor) == 0);
    put(actor + 8, 0x5678);
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    put(actor + 8, 0x1234);
    character(actor, 223);
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    character(actor, 191);
    put(duplicate + 0x50, 1);
    put(duplicate + 8, 0x5678);
    character(duplicate, 191);
    r.entities_update();
    source(duplicate, ref.spawn_tag, 1, 1);
    r.entities_reset_bindings();
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    put(duplicate + 0x50, 0);
    r.entities_update();
    check(@src(), b.entities_bind_native_reference(&ref, actor) != 0);
    const position: [3]f32 = .{ 2, 3, 4 };
    win.store([3]f32, actor + 0x24, position);
    put(actor + 0x50, 3);
    r.entities_update();
    check(@src(), r.entities_observed_generation(actor) == local_generation and r.entities_allocation_live(actor, local_generation) != 0);
    r.entities_describe(&described, actor);
    check(@src(), std.mem.eql(f32, &described.spawn_position, &position) and r.entities_resolve_reference(&ref) == actor);
    put(actor + 0x50, 0);
    r.entities_update();
    check(@src(), b.entities_bind_native_reference(&ref, actor) == 0);
    put(actor + 0x50, 1);
    r.entities_update();
    source(actor, ref.spawn_tag, 1, 1);
    check(@src(), r.entities_observed_generation(actor) != local_generation and b.entities_bind_native_reference(&ref, actor) == 0);
}
pub fn main() void {
    var requested: s.Key = .{ .generation = 12, .spawn_tag = 5, .character = 171, .spawn_source = .{ .producer = 0xe033ae01, .serial = 2 } };
    var candidates: [3]s.Key = .{
        .{ .generation = 21, .spawn_tag = 5, .character = 171, .spawn_source = .{ .producer = 0xe033ae01, .serial = 3 } },
        .{ .generation = 22, .spawn_tag = 5, .character = 171, .spawn_source = .{ .producer = 0xa212f067, .serial = 2 } },
        .{ .generation = 23, .spawn_tag = 5, .character = 171, .spawn_source = .{ .producer = 0xe033ae01, .serial = 2 } },
    };
    var unavailable: [3]u8 = @splat(0);
    const match = @import("entity_match.zig").entity_match_unique;
    check(@src(), match(&requested, &candidates, &unavailable, 3) == 2);
    unavailable[2] = 1;
    check(@src(), match(&requested, &candidates, &unavailable, 3) == -1);
    unavailable[2] = 0;
    candidates[1] = candidates[2];
    check(@src(), match(&requested, &candidates, &unavailable, 3) == -2);
    requested.spawn_source = .{ .producer = 0, .serial = 0 };
    check(@src(), match(&requested, &candidates, &unavailable, 3) == -1);
    const base = Fixture.init();
    defer base.deinit();
    prepareParty(base.frame);
    partyBinding();
    retiringOperands();
    coldTagBinding();
    lastWeaponCommand();
    nativeReferenceBinding();
    neverActiveReserve();
}
