const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const read = s.read;
extern fn entities_allocation_live(usize, u32) c_int;
fn targetLive(target: usize) bool {
    return s.valid(target, 0x1440) and read(u32, target + 0x50) & 3 == 3 and read(u8, target + 0x54) == 0;
}
pub export fn cadence_primary_perception(actor: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    input: {
        if (!s.valid(actor, 0x1440)) break :input;
        const clock = read(u32, 0xfb4b6c);
        const local_target = read(usize, actor + 0x164);
        const local_distance = read(f32, actor + 0x168);
        var state = std.mem.zeroes(p.SyncPrimaryPerceptionState);
        state.clock = clock;
        state.target_slot = std.math.maxInt(u32);
        s.entities_update();
        if (!s.live(&op)) return;
        const generation = s.entities_observed_generation(actor);
        if (generation == 0) break :input;
        if (s.journal.host != 0 and targetLive(local_target)) {
            var identity = std.mem.zeroes(p.SyncActor);
            s.entities_describe(&identity, local_target);
            if (!s.live(&op)) return;
            const slot = s.entities_slot(local_target);
            if (slot < 0 or slot >= p.SYNC_MAX_ACTORS or identity.generation == 0 or !@import("validation.zig").finite(local_distance) or local_distance < 0) break :input;
            state.target_slot = @intCast(slot);
            state.target_generation = identity.generation;
            state.target_tag = identity.spawn_tag;
            state.target_character = read(i16, local_target + 0xdc0);
            state.target_source = identity.spawn_source;
            state.target_origin = identity.spawn_position;
            state.distance = local_distance;
            state.target_visible = (read(u32, actor + 0x1c8) >> 5) & 1;
        }
        _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PRIMARY_PERCEPTION, 0, 0, 0, @ptrCast(&state), &s.clonewars_primary_perception_debug);
        if (!s.live(&op) or !s.active or s.journal.failed != 0 or s.journal.host != 0) return;
        var target: usize = 0;
        if (state.target_slot != std.math.maxInt(u32)) {
            var identity = std.mem.zeroes(p.SyncActor);
            identity.slot = state.target_slot;
            identity.generation = state.target_generation;
            identity.spawn_tag = state.target_tag;
            identity.character = state.target_character;
            identity.spawn_source = state.target_source;
            identity.spawn_position = state.target_origin;
            target = s.entities_resolve_reference(&identity);
            if (!s.live(&op)) return;
            if (!targetLive(target)) break :input;
        }
        if (state.clock != clock or entities_allocation_live(actor, generation) == 0) break :input;
        if (!s.live(&op)) return;
        const flags = read(u32, actor + 0x1c8);
        if (target != local_target or (target != 0 and (s.bits(state.distance) != s.bits(local_distance) or state.target_visible != ((flags >> 5) & 1)))) s.clonewars_primary_perception_debug[2] +%= 1;
        s.win.store(usize, actor + 0x164, target);
        if (target != 0) {
            s.win.store(f32, actor + 0x168, state.distance);
            s.win.store(u32, actor + 0x1c8, (flags & ~@as(u32, 0x20)) | (state.target_visible << 5));
        }
        return;
    }
    if (s.live(&op)) {
        s.journal.failed = 19;
        s.clonewars_primary_perception_debug[3] +%= 1;
        s.failed(&op, actor, null, 19);
    }
}
