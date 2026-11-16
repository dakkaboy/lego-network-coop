const std = @import("std");
const s = @import("entity_state.zig");
const p = s.p;
const read = s.read;
const party = @import("entity_party.zig");
const tick = @import("tick_sites.zig");
fn bind(frame: *const p.SyncFrame, before_tick: bool) c_int {
    if (before_tick and (frame.tick_gate_count > p.SYNC_MAX_TICK_GATES or !@import("tick_validation.zig").streamValid(frame.tick_gates[0..frame.tick_gate_count]))) return 0;
    s.entities_update();
    const count = s.count();
    var claimed: [p.SYNC_MAX_ACTORS]u8 = @splat(0);
    var wanted: [p.SYNC_MAX_ACTORS]u32 = @splat(0);
    for (frame.actors[0..frame.actor_count]) |*state| {
        party.retire(state);
        wanted[state.slot] = state.generation;
    }
    for (0..8) |index| {
        if (frame.dormant_party[index] == 0) continue;
        const actor = s.player(index);
        const raw = s.rawSlot(actor);
        if (raw < 0 or raw >= count) continue;
        const slot: usize = @intCast(raw);
        const remote_raw = s.inverse[slot];
        if (remote_raw < 0 or remote_raw >= p.SYNC_MAX_ACTORS) continue;
        const remote: usize = @intCast(remote_raw);
        if (wanted[remote] != 0) continue;
        const b = &s.bindings[remote];
        if (b.local_slot == raw and s.entities_allocation_live(actor, b.local_generation) != 0 and read(i8, actor + 0x55) == index and @as(i32, read(i16, actor + 0xdc0)) + 1 == frame.dormant_party[index]) wanted[remote] = b.remote_generation;
    }
    if (frame.tag_count > p.SYNC_MAX_TAGS) return 0;
    for (frame.tags[0..frame.tag_count]) |*tag| {
        const slots = [_]i32{ tag.from, tag.to };
        const generations = [_]u32{ tag.from_generation, tag.to_generation };
        for (slots, generations) |raw, generation| if (raw >= 0 and raw < p.SYNC_MAX_ACTORS and generation != 0) {
            const index: usize = @intCast(raw);
            if (wanted[index] == 0 or wanted[index] == generation) wanted[index] = generation;
        };
    }
    if (before_tick) {
        var i: usize = 0;
        while (i < frame.tick_gate_count) : (i += 1) {
            if (frame.tick_gates[i].site != tick.WEAPON_COMMAND_ACTOR) continue;
            const slot = frame.tick_gates[i].value;
            const generation = frame.tick_gates[i + 1].value;
            const b = &s.bindings[slot];
            if (b.remote_generation == generation and b.local_slot >= 0 and b.local_slot < count and s.entities_allocation_live(s.address(@intCast(b.local_slot)), b.local_generation) != 0) wanted[slot] = generation;
            i += 2;
        }
    }
    for (&s.bindings, 0..) |*b, slot| {
        if (b.remote_generation == 0 or wanted[slot] != b.remote_generation or b.local_slot < 0 or b.local_slot >= count or s.local[@intCast(b.local_slot)].key.generation != b.local_generation or read(u32, s.address(@intCast(b.local_slot)) + 0x50) & 3 != 3) {
            b.* = std.mem.zeroes(s.Binding);
            b.local_slot = -1;
        } else claimed[@intCast(b.local_slot)] = 1;
    }
    for (0..count) |slot| {
        s.keys[slot] = s.local[slot].key;
        if (read(u32, s.address(slot) + 0x50) & 3 != 3) s.keys[slot].generation = 0;
    }
    for (frame.tags[0..frame.tag_count]) |*tag| {
        const slots = [_]i32{ tag.from, tag.to };
        const generations = [_]u32{ tag.from_generation, tag.to_generation };
        const identities = [_]*const p.SyncTagIdentity{ &tag.from_identity, &tag.to_identity };
        for (slots, generations, identities) |remote, generation, identity| {
            const reference = party.tagReference(remote, generation, identity) orelse continue;
            if (wanted[reference.slot] != reference.generation) continue;
            const actor = s.entities_resolve_reference(&reference);
            const raw = s.rawSlot(actor);
            if (raw < 0 or raw >= count) continue;
            const slot: usize = @intCast(raw);
            if (s.keys[slot].generation == 0 or !s.matches(&s.keys[slot], &reference)) continue;
            const b = &s.bindings[reference.slot];
            if (claimed[slot] != 0 and (b.local_slot != raw or b.local_generation != s.keys[slot].generation or b.remote_generation != reference.generation)) continue;
            if (s.claimedElsewhere(slot, s.keys[slot].generation, reference.slot, reference.generation)) continue;
            s.claim(reference.slot, slot, reference.generation);
            claimed[slot] = 1;
        }
    }
    const initial = frame.sequence == 1;
    const native_party_count: usize = if (initial) 8 else 2;
    var missing = false;
    for (0..2) |pass| {
        if (pass != 0) for (0..native_party_count) |index| {
            const raw = s.rawSlot(s.player(index));
            if (raw >= 0 and raw < count) claimed[@intCast(raw)] = 1;
        };
        for (frame.actors[0..frame.actor_count]) |*state| {
            if (before_tick and wanted[state.slot] != 0 and wanted[state.slot] != state.generation) continue;
            const native_party: i32 = if (initial and state.party_slot >= 2) state.party_slot else state.player;
            if ((native_party < 0) != (pass == 1)) continue;
            const b = &s.bindings[state.slot];
            if (b.remote_generation != 0 and b.local_slot >= 0 and s.matches(&s.keys[@intCast(b.local_slot)], state)) continue;
            if (b.local_slot >= 0 and b.local_slot < count) claimed[@intCast(b.local_slot)] = 0;
            b.* = std.mem.zeroes(s.Binding);
            b.local_slot = -1;
            var raw: c_int = -1;
            const history = &s.known[state.slot];
            if (native_party >= 0 and native_party < native_party_count) {
                raw = s.rawSlot(s.player(@intCast(native_party)));
                if (raw < 0 or raw >= count or s.keys[@intCast(raw)].generation == 0 or !s.matches(&s.keys[@intCast(raw)], state) or claimed[@intCast(raw)] != 0) raw = -1;
                if (raw >= 0 and native_party >= 2 and (s.keys[@intCast(raw)].spawn_tag != state.spawn_tag or read(i8, s.address(@intCast(raw)) + 0x55) != native_party)) raw = -1;
            } else if (history.remote_generation == state.generation) {
                raw = history.local_slot;
                if (raw < 0 or raw >= count or s.keys[@intCast(raw)].generation != history.local_generation or !s.matches(&s.keys[@intCast(raw)], state) or claimed[@intCast(raw)] != 0) raw = -1;
            } else {
                const key = s.key(state);
                var unavailable = claimed;
                for (0..count) |candidate| if (s.claimedElsewhere(candidate, s.keys[candidate].generation, state.slot, state.generation)) {
                    unavailable[candidate] = 1;
                };
                raw = s.entity_match_unique(&key, &s.keys, &unavailable, @intCast(count));
            }
            if (raw >= 0 and history.remote_generation == state.generation and (history.local_slot != raw or history.local_generation != s.keys[@intCast(raw)].generation)) raw = -1;
            if (raw >= 0 and s.claimedElsewhere(@intCast(raw), s.keys[@intCast(raw)].generation, state.slot, state.generation)) raw = -1;
            if (raw < 0 and state.player < 0 and state.health == 0 and s.entities_is_retired(state.slot, state.generation) != 0) continue;
            if (raw < 0) {
                missing = true;
                s.clonewars_entity_debug[2] = state.slot;
                s.clonewars_entity_debug[3] = @bitCast(raw);
                continue;
            }
            const slot: usize = @intCast(raw);
            s.claim(state.slot, slot, state.generation);
            claimed[slot] = 1;
            if (slot != state.slot) s.clonewars_entity_debug[1] +%= 1;
        }
    }
    s.inverse = @splat(-1);
    for (s.bindings, 0..) |b, slot| if (b.remote_generation != 0 and b.local_slot >= 0) {
        s.inverse[@intCast(b.local_slot)] = @intCast(slot);
    };
    s.clonewars_entity_debug[4] = @intFromBool(missing);
    s.clonewars_entity_debug[5] = @truncate(@intFromPtr(&s.local));
    s.clonewars_entity_debug[6] = @sizeOf(s.Local);
    s.clonewars_entity_debug[7] = @truncate(@intFromPtr(&s.bindings));
    return @intFromBool(!missing);
}
pub export fn entities_bind(frame: *const p.SyncFrame) c_int {
    return bind(frame, false);
}
pub export fn entities_bind_tick(frame: *const p.SyncFrame) c_int {
    return bind(frame, true);
}
pub export fn entities_bind_native_reference(reference: ?*const p.SyncActor, actor: usize) c_int {
    const state = reference orelse return 0;
    if (state.slot >= p.SYNC_MAX_ACTORS or state.generation == 0 or s.lan_is_host() != 0) return 0;
    s.entities_update();
    const raw = s.rawSlot(actor);
    const count = s.count();
    if (raw < 0 or raw >= count) return 0;
    const slot: usize = @intCast(raw);
    const key = &s.local[slot].key;
    if (s.entities_allocation_retained(actor, key.generation) == 0 or !s.matches(key, state) or key.spawn_tag != state.spawn_tag) return 0;
    const history = &s.known[state.slot];
    if (history.remote_generation == state.generation) {
        if (history.local_slot != raw or history.local_generation != key.generation) return 0;
    } else {
        if (state.spawn_source.producer == 0) return 0;
        for (0..count) |other| if (other != slot and s.matches(&s.local[other].key, state) and s.entities_allocation_retained(s.address(other), s.local[other].key.generation) != 0) return 0;
    }
    if (s.claimedElsewhere(slot, key.generation, state.slot, state.generation)) return 0;
    const previous = &s.bindings[state.slot];
    if (previous.remote_generation != 0 and previous.local_slot != raw and previous.local_slot >= 0 and previous.local_slot < count and s.entities_allocation_retained(s.address(@intCast(previous.local_slot)), previous.local_generation) != 0) return 0;
    s.claim(state.slot, slot, state.generation);
    s.inverse[slot] = @intCast(state.slot);
    return 1;
}
fn bindNative(frame: ?*const p.SyncFrame, actor: usize) c_int {
    const f = frame orelse return 0;
    if (f.actor_count > p.SYNC_MAX_ACTORS or s.lan_is_host() != 0) return 0;
    s.entities_update();
    const raw = s.rawSlot(actor);
    if (raw < 0 or raw >= s.game_actor_count()) return 0;
    const slot: usize = @intCast(raw);
    const key = &s.local[slot].key;
    if (s.entities_allocation_live(actor, key.generation) == 0) return 0;
    const remote = s.inverse[slot];
    if (remote >= 0 and remote < p.SYNC_MAX_ACTORS and s.bindings[@intCast(remote)].local_generation == key.generation) return 1;
    if (key.spawn_source.producer == 0) return 0;
    var match: ?*const p.SyncActor = null;
    for (f.actors[0..f.actor_count]) |*state| {
        if (!s.matches(key, state)) continue;
        if (match != null or state.slot >= p.SYNC_MAX_ACTORS or state.generation == 0) return 0;
        match = state;
    }
    const state = match orelse return 0;
    if (s.claimedElsewhere(slot, key.generation, state.slot, state.generation)) return 0;
    for (0..s.count()) |other| if (other != slot and s.matches(&s.local[other].key, state) and s.entities_allocation_live(s.address(other), s.local[other].key.generation) != 0) return 0;
    const previous = &s.bindings[state.slot];
    if (previous.remote_generation != 0 and previous.local_slot != raw and previous.local_slot >= 0 and previous.local_slot < s.game_actor_count() and s.entities_allocation_live(s.address(@intCast(previous.local_slot)), previous.local_generation) != 0) return 0;
    s.claim(state.slot, slot, state.generation);
    s.inverse[slot] = @intCast(state.slot);
    return 1;
}
pub export fn entities_bind_native_actor(frame: ?*const p.SyncFrame, actor: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return bindNative(frame, actor);
}
