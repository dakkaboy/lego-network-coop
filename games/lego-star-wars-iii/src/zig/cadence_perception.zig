const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const read = s.read;
extern fn entities_allocation_live(usize, u32) c_int;
pub export var clonewars_script_attack_target_debug: [4]u32 = @splat(0);
pub export var clonewars_script_assigned_target_debug: [4]u32 = @splat(0);

fn targetLive(target: usize) bool {
    return s.valid(target, 0x1440) and read(u32, target + 0x50) & 3 == 3 and read(u8, target + 0x54) == 0;
}
fn defeatedHero(pointer: usize, character: i16) bool {
    const actor = read(usize, pointer);
    return s.valid(actor, 0x1440) and read(i16, actor + 0xdc0) == character and read(u8, actor + 0xdde) == 0;
}
fn describeTarget(op: *const s.Lease, state: *p.SyncPrimaryPerceptionState, target: usize) bool {
    var identity = std.mem.zeroes(p.SyncActor);
    s.entities_describe(&identity, target);
    if (!s.live(op)) return false;
    const slot = s.entities_slot(target);
    if (!s.live(op) or slot < 0 or slot >= p.SYNC_MAX_ACTORS or identity.generation == 0) return false;
    state.target_slot = @intCast(slot);
    state.target_generation = identity.generation;
    state.target_tag = identity.spawn_tag;
    state.target_character = read(i16, target + 0xdc0);
    state.target_source = identity.spawn_source;
    state.target_origin = identity.spawn_position;
    return true;
}

fn resolveTarget(state: *const p.SyncPrimaryPerceptionState) usize {
    if (state.target_slot == std.math.maxInt(u32)) return 0;
    var identity = std.mem.zeroes(p.SyncActor);
    identity.slot = state.target_slot;
    identity.generation = state.target_generation;
    identity.spawn_tag = state.target_tag;
    identity.character = state.target_character;
    identity.spawn_source = state.target_source;
    identity.spawn_position = state.target_origin;
    return s.entities_resolve_reference(&identity);
}

fn reject(op: *const s.Lease, actor: usize, debug: *[4]u32) void {
    if (!s.live(op)) return;
    s.journal.failed = 19;
    debug[3] +%= 1;
    s.failed(op, actor, null, 19);
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
            if (!describeTarget(&op, &state, local_target) or !@import("validation.zig").finite(local_distance) or local_distance < 0) break :input;
            state.distance = local_distance;
            state.target_visible = (read(u32, actor + 0x1c8) >> 5) & 1;
        }
        _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PRIMARY_PERCEPTION, 0, 0, 0, @ptrCast(&state), &s.clonewars_primary_perception_debug);
        if (!s.live(&op) or !s.active or s.journal.failed != 0 or s.journal.host != 0) return;
        const target = resolveTarget(&state);
        if (!s.live(&op)) return;
        if (state.target_slot != std.math.maxInt(u32) and !targetLive(target)) break :input;
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
    reject(&op, actor, &s.clonewars_primary_perception_debug);
}

pub export fn cadence_script_attack_target(actor: usize, local_target: usize) usize {
    return scriptTarget(actor, local_target, p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET, &clonewars_script_attack_target_debug);
}

pub export fn cadence_script_assigned_target(actor: usize, local_target: usize) usize {
    // The native opponent group reads this assignment before choosing a combat script.
    return scriptTarget(actor, local_target, p.SYNC_PERCEPTION_SCRIPT_ASSIGNED_TARGET, &clonewars_script_assigned_target_debug);
}

fn scriptTarget(actor: usize, local_target: usize, flags: u16, debug: *[4]u32) usize {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op) or s.journal.frame.?.level != 70 or !s.valid(actor, 0x1440)) return local_target;
    const character = read(i16, actor + 0xdc0);
    if (character != 321 and character != 333) return local_target;
    // While both heroes await respawn, a stale fallback is not a combat target.
    if (flags == p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET and defeatedHero(0xfb4940, 191) and defeatedHero(0xfb4944, 156)) return local_target;

    var input = std.mem.zeroes(p.SyncPrimaryPerceptionState);
    const clock = read(u32, 0xfb4b6c);
    input.clock = clock;
    input.target_slot = std.math.maxInt(u32);
    s.entities_update();
    if (!s.live(&op)) return local_target;
    if (s.journal.host != 0 and local_target != 0 and
        (!s.valid(local_target, 0x1440) or !describeTarget(&op, &input, local_target)))
    {
        reject(&op, actor, debug);
        return local_target;
    }
    _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PRIMARY_PERCEPTION, flags, 0, 0, @ptrCast(&input), debug);
    if (!s.live(&op) or s.journal.failed != 0 or s.journal.host != 0) return local_target;

    const target = resolveTarget(&input);
    if (!s.live(&op)) return local_target;
    if (input.clock != clock or (input.target_slot != std.math.maxInt(u32) and !s.valid(target, 0x1440))) {
        reject(&op, actor, debug);
        return local_target;
    }
    debug[2] +%= @intFromBool(target != local_target);
    return target;
}
