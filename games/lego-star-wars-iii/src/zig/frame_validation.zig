const std = @import("std");
const p = @import("protocol.zig");
const v = @import("validation.zig");
const abi = @import("abi.zig");
const fire = @import("fire_validation.zig");
const physics = @import("physics_validation.zig");
const tick = @import("tick_validation.zig");
extern fn sync_frame_size(*const p.SyncFrame) u32;
fn delta(value: f32) bool {
    return v.finite(value) and value >= 0 and value <= 0.1;
}
fn zeroFloats(values: anytype) bool {
    for (values) |value| if (value != 0) return false;
    return true;
}
fn ordered(entries: anytype, comptime name: []const u8) bool {
    for (entries, 0..) |entry, i| if (i > 0 and @field(entries[i - 1], name) >= @field(entry, name)) return false;
    return true;
}
fn owner(entry: anytype) bool {
    return fire.sourceValid(entry.spawn_source) and entry.slot < p.SYNC_MAX_ACTORS and entry.generation != 0 and abi.validLevel(entry.character);
}
pub export fn sync_frame_valid(frame: *const p.SyncFrame, bytes: u32) c_int {
    return @intFromBool(valid(frame, bytes));
}
pub fn valid(f: *const p.SyncFrame, bytes: u32) bool {
    if (bytes < @offsetOf(p.SyncFrame, "actors") or bytes != sync_frame_size(f) or f.native_span_plan & ~@as(u32, p.SYNC_NATIVE_SPAN_PLAN_MASK) != 0 or
        f.native_span_calls & ~@as(u32, p.SYNC_NATIVE_SPAN_CALLS_MASK) != 0 or f.epoch == 0 or f.sequence == 0 or !abi.validLevel(f.level) or
        !delta(f.delta) or !delta(f.engine_delta) or f.engine_mode > 16 or f.world_calls > 64 or f.tick_calls > 64 or f.combat_ready > 1 or
        f.numeric_cw & ~@as(u32, 0x1f3f) != 0 or f.numeric_cw & 0x300 == 0x100 or f.numeric_mxcsr & ~@as(u32, 0xffc0) != 0 or
        f.reaction_reserved != 0 or f.model_input_reserved != 0 or f.tick_gate_reserved != 0 or f.spawn_timer_reserved != 0 or f.fire_task_gate_reserved != 0 or
        (f.sequence != 1 and (f.spawn_timer_count != 0 or f.rts_team_timer_count != 0))) return false;
    var retire_ids: [p.SYNC_MAX_PROJECTILES * 2]u32 = @splat(0);
    for (f.projectile_retires[0..f.projectile_retire_count]) |request| {
        if (request.id == 0 or request.flags != 0 or request.effects != 0 or request.caller != 0x85ba24) return false;
        var index: usize = request.id % retire_ids.len;
        while (retire_ids[index] != 0) {
            if (retire_ids[index] == request.id) return false;
            index = (index + 1) % retire_ids.len;
        }
        retire_ids[index] = request.id;
    }
    if (!tick.streamValid(f.tick_gates[0..f.tick_gate_count])) return false;
    for (f.physics_choices[0..f.physics_choice_count]) |*choice| if (!physics.valid(choice)) return false;
    var team_slots: u32 = 0;
    for (f.rts_team_timers[0..f.rts_team_timer_count]) |team| {
        if (team.slot >= p.SYNC_MAX_RTS_TEAMS or !v.finite(team.remaining)) return false;
        const bit = @as(u32, 1) << @as(u5, @intCast(team.slot));
        if (team_slots & bit != 0) return false;
        team_slots |= bit;
    }
    for (f.spawn_timer_choices[0..f.spawn_timer_choice_count]) |choice| {
        if (!v.finite(choice.remaining)) return false;
        switch (choice.kind) {
            p.SYNC_SPAWN_TIMER_RTS => if (choice.owner >= p.SYNC_MAX_RTS_TEAMS or choice.selector >= 3 or choice.serial != 0 or choice.remaining < 2 or choice.remaining > 4) return false,
            p.SYNC_SPAWN_TIMER_MODULE => if (choice.owner == 0 or choice.selector == 0) return false,
            else => return false,
        }
    }
    const timers = f.spawn_timers[0..f.spawn_timer_count];
    if (!ordered(timers, "id")) return false;
    for (timers) |timer| if (timer.id == 0 or timer.type == 0 or !v.finite(timer.remaining)) return false;
    for (f.fire_task_gates[0..f.fire_task_gate_count]) |*gate| if (!fire.valid(gate)) return false;
    var party: u32 = 0;
    for (f.dormant_party, 0..) |member, i| {
        if (member > 4096) return false;
        if (member != 0) party |= @as(u32, 1) << @as(u5, @intCast(i));
    }
    const actors = f.actors[0..f.actor_count];
    if (!ordered(actors, "slot")) return false;
    for (actors) |*actor| {
        if (actor.slot >= p.SYNC_MAX_ACTORS or actor.character < -1 or actor.character >= 4096 or actor.generation == 0 or actor.player < -1 or actor.player > 1 or
            actor.has_wallet > 1 or !fire.sourceValid(actor.spawn_source) or actor.body.active > 1 or actor.rigid_body.active > 1 or actor.rigid_body.reserved != 0 or !v.finite(actor.*)) return false;
        if (actor.rigid_body.active == 0 and !zeroFloats(actor.rigid_body.transform)) return false;
        if (actor.body.active == 0 and (actor.body.floor_height != 0 or !zeroFloats(actor.body.position) or !zeroFloats(actor.body.velocity))) return false;
        if (actor.party_slot < -1 or actor.party_slot >= 8 or (actor.player >= 0 and actor.party_slot != actor.player) or
            (actor.party_slot >= 0 and actor.party_slot < 2 and actor.player != actor.party_slot)) return false;
        if (actor.party_slot >= 0) {
            const bit = @as(u32, 1) << @as(u5, @intCast(actor.party_slot));
            if (party & bit != 0) return false;
            party |= bit;
        }
        if (actor.animation.current < -1 or actor.animation.current >= 4096) return false;
        for (actor.animation.clips) |clip| if (clip < -1 or clip >= 4096) return false;
    }
    for (f.variables[0..f.variable_count]) |variable| if (variable.name[0] == 0 or variable.scope > p.SYNC_VARIABLE_AREA_DECLARATION or !v.finite(variable.value)) return false;
    const shots = f.shots[0..f.shot_count];
    if (!ordered(shots, "id")) return false;
    for (shots) |*shot| {
        if (shot.phase > 1 or !delta(shot.delta) or shot.id == 0 or shot.owner < -1 or shot.owner >= 4096 or shot.weapon < 0 or shot.weapon >= 128 or
            (shot.owner >= 0 and shot.owner_generation == 0) or shot.reserved != 0 or shot.source > p.SYNC_SHOT_PROJECTILE_CHILD or
            (shot.phase != 0 and shot.source != p.SYNC_SHOT_WEAPON) or !v.finite(shot.*)) return false;
        if (shot.source == p.SYNC_SHOT_PROJECTILE_CHILD) {
            if (shot.owner != -1 or shot.depth < 1 or shot.depth > 3) return false;
        } else if (shot.depth != 0 or (shot.source == p.SYNC_SHOT_ACTOR_FOLLOWUP and shot.owner < 0)) return false;
        if (shot.has_launch_center > 1 or shot.has_launch_motion > 1 or shot.has_projectile_seed > 1 or
            ((shot.has_launch_center != 0 or shot.has_launch_motion != 0) and shot.owner < 0)) return false;
        if (shot.has_launch_center == 0 and !zeroFloats(shot.launch_center)) return false;
        if (shot.has_launch_motion == 0 and !zeroFloats(shot.launch_motion)) return false;
        const seed = &shot.projectile_seed;
        if (shot.has_projectile_seed == 0 and (seed.age != 0 or seed.expires_at != 0 or seed.cast_countdown != 0 or !zeroFloats(seed.cast_origin))) return false;
    }
    const projectiles = f.projectiles[0..f.projectile_count];
    if (!ordered(projectiles, "id")) return false;
    for (projectiles) |projectile| if (projectile.id == 0 or !v.finite(projectile)) return false;
    const tags = f.tags[0..f.tag_count];
    if (!ordered(tags, "id")) return false;
    for (tags, 0..) |tag, i| {
        if (tag.id == 0 or !abi.validLevel(tag.from) or !abi.validLevel(tag.to) or tag.from == tag.to or tag.from_generation == 0 or tag.to_generation == 0 or tag.phase > 1 or
            tag.source > p.SYNC_TAG_ACTOR_UPDATE or (tag.source != 0 and (tag.phase != 0 or tag.parent != 0)) or
            !abi.validLevel(tag.from_identity.character) or !abi.validLevel(tag.to_identity.character) or
            !fire.sourceValid(tag.from_identity.spawn_source) or !fire.sourceValid(tag.to_identity.spawn_source) or !@import("frame_tag_time.zig").valid(f, &tag, tags[0..i])) return false;
        if (tag.parent != 0) {
            var found = false;
            for (tags[0..i]) |parent| if (parent.id == tag.parent and parent.phase == tag.phase) {
                found = true;
                break;
            };
            if (!found) return false;
        }
    }
    for (f.actor_inputs[0..f.actor_input_count]) |entry| if (!owner(entry) or !v.finite(entry.origin)) return false;
    for (f.cadence[0..f.cadence_count]) |entry| if (!owner(entry) or entry.period == 0 or entry.period > 255 or entry.phase > 255 or !v.finite(entry.elapsed) or entry.elapsed < 0 or !v.finite(entry.origin)) return false;
    const geometry = f.geometry[0..f.geometry_count];
    for (geometry, 0..) |*entry, i| {
        if (!fire.sourceValid(entry.spawn_source) or !@import("geometry.zig").valid(entry) or entry.manager_ordinal > f.geometry_calls) return false;
        if (i > 0 and (entry.manager_ordinal < geometry[i - 1].manager_ordinal or (entry.manager_ordinal == geometry[i - 1].manager_ordinal and entry.slot <= geometry[i - 1].slot))) return false;
    }
    for (f.reactions[0..f.reaction_count]) |*entry| if (!@import("reaction.zig").valid(entry) or !fire.sourceValid(entry.spawn_source) or
        (entry.kind == p.SYNC_REACTION_CLIP and entry.payload.clip.arena_attacker_generation != 0 and f.level != 12)) return false;
    for (f.model_inputs[0..f.model_input_count]) |*entry| if (!@import("model.zig").valid(entry) or !fire.sourceValid(entry.spawn_source)) return false;
    return true;
}
