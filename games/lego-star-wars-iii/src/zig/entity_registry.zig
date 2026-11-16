const std = @import("std");
const s = @import("entity_state.zig");
const p = s.p;
const read = s.read;
pub export fn entities_reset_bindings() void {
    s.resetBindings();
}
pub export fn entities_set_spawn_context(identity: s.SpawnIdentity) s.SpawnIdentity {
    const previous = s.spawn_context;
    s.spawn_context = identity;
    return previous;
}
pub export fn entities_update() void {
    s.currentPool();
    const count = s.count();
    if (!s.valid(s.pool, count * 0x1440)) return;
    for (0..count) |slot| {
        const actor = s.address(slot);
        const entry = &s.local[slot];
        const flags = read(u32, actor + 0x50);
        if (flags & 1 == 0) {
            entry.* = std.mem.zeroes(s.Local);
            continue;
        }
        const model = read(usize, actor + 8);
        if (flags & 3 != 3) {
            if (entry.origin_ready == 0 and entry.model == 0 and model != 0) {
                if (entry.key.generation == 0) entry.key.generation = s.generation();
                entry.model = model;
                entry.key.character = read(i16, actor + 0xdc0);
            }
            continue;
        }
        if (entry.key.generation == 0 or (entry.model != 0 and entry.model != model) or ((entry.model != 0 or entry.origin_ready != 0) and entry.key.character != read(i16, actor + 0xdc0))) {
            entry.key.generation = s.generation();
            entry.origin_ready = 0;
        }
        if (entry.origin_ready == 0) {
            entry.model = model;
            entry.key.character = read(i16, actor + 0xdc0);
            entry.origin = read([3]f32, actor + 0x24);
            entry.origin_ready = 1;
        }
    }
    finalizeRoster();
}
fn finalizeRoster() void {
    for (&s.pending, 0..) |*pending, i| {
        if (!pending.active) continue;
        const raw = s.rawSlot(pending.actor);
        if (raw < 0 or raw >= s.game_actor_count() or s.local[@intCast(raw)].key.generation != pending.generation or entities_allocation_live(pending.actor, pending.generation) == 0) {
            pending.active = false;
            s.clonewars_roster_source_debug[5] +%= 1;
            continue;
        }
        if (s.native_roster_source_revalidate(&pending.source, pending.actor) != 0) {
            const entry = &s.local[@intCast(raw)];
            entry.key.spawn_tag = 0x5c5ce6;
            entry.key.spawn_source = .{ .producer = 2, .serial = (@as(u32, @bitCast(pending.source.level)) << 3) | @as(u32, @intCast(i)) };
            pending.active = false;
            s.clonewars_roster_source_debug[2] +%= 1;
        } else if (s.native_roster_source_revalidate(&pending.source, 0) == 0) {
            pending.active = false;
            s.clonewars_roster_source_debug[5] +%= 1;
        }
    }
}
pub export fn entities_describe(state: *p.SyncActor, actor: usize) void {
    const raw = s.rawSlot(actor);
    if (raw < 0) return;
    const entry = &s.local[@intCast(raw)];
    state.generation = entry.key.generation;
    state.spawn_tag = entry.key.spawn_tag;
    state.spawn_source = entry.key.spawn_source;
    state.spawn_position = entry.origin;
    state.player = -1;
    state.party_slot = -1;
    for (0..8) |party| if (s.player(party) == actor) {
        state.party_slot = @intCast(party);
        if (party < 2) state.player = @intCast(party);
    };
}
pub export fn entities_note_spawn_source(actor: usize, site: u32, source: p.SyncSpawnSource) void {
    if (source.producer == 0) return;
    s.currentPool();
    const raw = s.rawSlot(actor);
    if (raw >= 0) {
        const entry = &s.local[@intCast(raw)];
        if (entry.key.generation != 0) {
            entry.key.spawn_tag = site;
            entry.key.spawn_source = source;
        }
    }
}
pub export fn entities_spawn_source(actor: usize, site: *u32) p.SyncSpawnSource {
    s.currentPool();
    const raw = s.rawSlot(actor);
    if (raw < 0 or raw >= s.game_actor_count() or s.local[@intCast(raw)].key.generation == 0) return std.mem.zeroes(p.SyncSpawnSource);
    site.* = s.local[@intCast(raw)].key.spawn_tag;
    return s.local[@intCast(raw)].key.spawn_source;
}
pub export fn entities_resolve_reference(state: ?*const p.SyncActor) usize {
    const wanted = state orelse return 0;
    if (wanted.slot >= p.SYNC_MAX_ACTORS or wanted.generation == 0) return 0;
    entities_update();
    const count = s.count();
    const history = &s.known[wanted.slot];
    var slot: c_int = -1;
    if (history.remote_generation == wanted.generation) {
        slot = history.local_slot;
        if (slot < 0 or slot >= s.game_actor_count()) return 0;
        const index: usize = @intCast(slot);
        if (s.local[index].key.generation != history.local_generation or !s.matches(&s.local[index].key, wanted) or read(u32, s.address(index) + 0x50) & 3 != 3) return 0;
    } else {
        var unavailable: [p.SYNC_MAX_ACTORS]u8 = @splat(0);
        for (0..count) |i| {
            s.keys[i] = s.local[i].key;
            if (read(u32, s.address(i) + 0x50) & 3 != 3) s.keys[i].generation = 0;
            if (s.claimedElsewhere(i, s.keys[i].generation, wanted.slot, wanted.generation)) unavailable[i] = 1;
        }
        const key = s.key(wanted);
        slot = s.entity_match_unique(&key, &s.keys, &unavailable, @intCast(count));
        if (slot < 0) return 0;
    }
    return s.address(@intCast(slot));
}
pub export fn entities_resolve_identity(frame: *const p.SyncFrame, slot: u32, generation: u32) usize {
    if (slot >= p.SYNC_MAX_ACTORS or generation == 0) return 0;
    for (frame.actors[0..frame.actor_count]) |*state| if (state.slot == slot and state.generation == generation) return entities_resolve_reference(state);
    return 0;
}
pub export fn entities_actor(remote: u32, generation: u32) usize {
    if (remote >= p.SYNC_MAX_ACTORS) return 0;
    const slot: c_int = if (s.lan_is_host() != 0) @intCast(remote) else s.bindings[remote].local_slot;
    if (slot < 0 or slot >= s.game_actor_count()) return 0;
    const index: usize = @intCast(slot);
    const actor = s.address(index);
    if (!s.valid(actor, 0x1440)) return 0;
    const b = &s.bindings[remote];
    if (s.lan_is_host() == 0 and (b.remote_generation == 0 or b.remote_generation != generation or s.local[index].key.generation != b.local_generation)) return 0;
    if (s.lan_is_host() != 0 and s.local[index].key.generation != generation) return 0;
    return actor;
}
pub export fn entities_allocation_retained(actor: usize, generation: u32) c_int {
    if (generation == 0 or s.nativePool() != s.pool) return 0;
    const raw = s.rawSlot(actor);
    if (raw < 0 or raw >= s.game_actor_count() or !s.valid(actor, 0x1440)) return 0;
    const entry = &s.local[@intCast(raw)];
    return @intFromBool((entry.origin_ready != 0 or entry.model != 0) and entry.key.generation == generation and read(u32, actor + 0x50) & 1 != 0 and entry.model == read(usize, actor + 8) and entry.key.character == read(i16, actor + 0xdc0));
}
pub export fn entities_allocation_live(actor: usize, generation: u32) c_int {
    return @intFromBool(entities_allocation_retained(actor, generation) != 0 and read(u32, actor + 0x50) & 3 == 3);
}
pub export fn entities_local_generation(actor: usize) u32 {
    entities_update();
    return entities_observed_generation(actor);
}
pub export fn entities_observed_generation(actor: usize) u32 {
    const raw = s.rawSlot(actor);
    return if (raw >= 0) s.local[@intCast(raw)].key.generation else 0;
}
pub export fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    slot.* = std.math.maxInt(u32);
    generation.* = 0;
    const raw = s.rawSlot(actor);
    if (raw < 0 or s.local[@intCast(raw)].key.generation == 0) return 0;
    const index: usize = @intCast(raw);
    if (s.lan_is_host() != 0) {
        slot.* = @intCast(index);
        generation.* = s.local[index].key.generation;
        return 1;
    }
    const remote = s.inverse[index];
    if (remote < 0 or remote >= p.SYNC_MAX_ACTORS) return 0;
    const b = &s.bindings[@intCast(remote)];
    if (b.local_generation != s.local[index].key.generation or b.remote_generation == 0) return 0;
    slot.* = @intCast(remote);
    generation.* = b.remote_generation;
    return 1;
}
pub export fn entities_generation(actor: usize) u32 {
    const raw = s.rawSlot(actor);
    if (raw < 0) return 0;
    const index: usize = @intCast(raw);
    if (s.lan_is_host() != 0) return s.local[index].key.generation;
    const remote = s.inverse[index];
    return if (remote >= 0 and s.bindings[@intCast(remote)].local_generation == s.local[index].key.generation) s.bindings[@intCast(remote)].remote_generation else 0;
}
pub export fn entities_slot(actor: usize) c_int {
    s.currentPool();
    const raw = s.rawSlot(actor);
    if (raw < 0) return -1;
    return if (s.lan_is_host() != 0) raw else s.inverse[@intCast(raw)];
}
