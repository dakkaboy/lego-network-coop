const std = @import("std");
const s = @import("entity_state.zig");
const p = s.p;
const read = s.read;
extern fn entities_resolve_identity(*const p.SyncFrame, u32, u32) usize;
fn dormant(actor: usize, party: usize, count: usize) c_int {
    if (actor == 0) return 0;
    const slot = s.rawSlot(actor);
    if (slot < 0 or slot >= count or !s.valid(actor, 0x1440) or read(i8, actor + 0x55) != party) return -1;
    const flags = read(u32, actor + 0x50) & 3;
    if (flags == 3) return 0;
    const character: i32 = read(i16, actor + 0xdc0);
    return if (flags == 1 and character >= 0 and character < 4096) character + 1 else -1;
}
pub export fn entities_collect_dormant_party(frame: *p.SyncFrame) c_int {
    s.currentPool();
    const count = s.count();
    for (0..8) |party| {
        const character = dormant(s.player(party), party, count);
        if (character < 0) return 0;
        frame.dormant_party[party] = @intCast(character);
    }
    return 1;
}
pub export fn entities_party_matches(frame: *const p.SyncFrame) c_int {
    var desired: [8]usize = @splat(0);
    for (frame.actors[0..frame.actor_count]) |*state| {
        if (state.party_slot < 0) continue;
        if (state.party_slot >= 8) return 0;
        const party: usize = @intCast(state.party_slot);
        if (desired[party] != 0) return 0;
        desired[party] = entities_resolve_identity(frame, state.slot, state.generation);
        if (desired[party] == 0) return 0;
    }
    s.currentPool();
    const count = s.count();
    for (0..8) |party| {
        const actor = s.player(party);
        if (dormant(actor, party, count) != frame.dormant_party[party]) return 0;
        if (frame.dormant_party[party] == 0 and actor != desired[party]) return 0;
    }
    return 1;
}
pub const tagReference = @import("tag_reference.zig").reference;
pub export fn entities_is_retired(slot: u32, generation: u32) c_int {
    if (generation == 0) return 0;
    for (s.retired) |r| if (r.slot == slot and r.generation == generation) return 1;
    return 0;
}
pub fn retire(state: *const p.SyncActor) void {
    if (state.player >= 0 or state.health != 0 or entities_is_retired(state.slot, state.generation) != 0) return;
    const previous = &s.known[state.slot];
    if (previous.remote_generation != state.generation or previous.local_slot < 0 or previous.local_slot >= s.game_actor_count()) return;
    const slot: usize = @intCast(previous.local_slot);
    if (s.local[slot].key.generation == previous.local_generation and read(u32, s.address(slot) + 0x50) & 3 == 3) return;
    s.retired[s.retired_head] = .{ .slot = state.slot, .generation = state.generation };
    s.retired_head = (s.retired_head + 1) % p.SYNC_MAX_PROJECTILES;
    s.clonewars_entity_debug[8] +%= 1;
}
