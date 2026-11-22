const std = @import("std");
const p = @import("protocol.zig");
const v = @import("validation.zig");
const abi = @import("abi.zig");

pub fn sourceValid(source: p.SyncSpawnSource) bool {
    return source.producer != 0 or source.serial == 0;
}
fn any(words: anytype) bool {
    for (words) |word| if (word != 0) return true;
    return false;
}
fn zeros(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}
pub fn supportValid(s: *const p.SyncCharacterMotionState) bool {
    const source = s.support_material_flags & (p.SYNC_SUPPORT_SCENE | p.SYNC_SUPPORT_VEHICLE);
    if ((s.support_frame == 0) != (s.support_event == 0) or s.support_material_flags & ~@as(u32, 0xfffff) != 0 or
        source == (p.SYNC_SUPPORT_SCENE | p.SYNC_SUPPORT_VEHICLE) or !v.finite(s.support_anchor) or !v.finite(s.support_normal)) return false;
    if (s.support_frame != 0) return s.support_material_flags & p.SYNC_SUPPORT_ABSENT == 0;
    return zeros(std.mem.asBytes(&s.support_anchor)) and zeros(std.mem.asBytes(&s.support_normal)) and (s.support_material_flags == 0 or s.support_material_flags == p.SYNC_SUPPORT_ABSENT);
}
pub fn valid(g: *const p.SyncFireTaskGate) bool {
    if (!sourceValid(g.spawn_source) or g.slot >= p.SYNC_MAX_ACTORS or g.generation == 0 or !abi.validLevel(g.character) or !v.finite(g.origin)) return false;
    const data = &g.payload;
    if (g.kind != p.SYNC_ACTOR_RTS_COMPETITOR) {
        const used: usize = switch (g.kind) {
            p.SYNC_ACTOR_FORCE_GEOMETRY => @sizeOf(p.SyncForceGeometryState),
            p.SYNC_ACTOR_CHARACTER_MOTION => @sizeOf(p.SyncCharacterMotionState),
            p.SYNC_ACTOR_SPELLIT_NODE => @sizeOf(p.SyncSpellItNodeState),
            p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY => @sizeOf(p.SyncScriptShootState),
            p.SYNC_ACTOR_PRIMARY_PERCEPTION => @sizeOf(p.SyncPrimaryPerceptionState),
            p.SYNC_ACTOR_RIDER_FIRE => @sizeOf(p.SyncRiderFireState),
            p.SYNC_ACTOR_ARENA_RUN_RANDOM => @sizeOf(p.SyncArenaRunRandomState),
            p.SYNC_ACTOR_BARC_SUSPENSION => @sizeOf(p.SyncBarcSuspensionState),
            p.SYNC_ACTOR_BARC_ALIGNMENT => @sizeOf(p.SyncBarcAlignmentState),
            p.SYNC_ACTOR_TUBE_CONTACT => @sizeOf([3]f32),
            p.SYNC_ACTOR_MELEE_CONTACT => @sizeOf(p.SyncMeleeContact),
            else => @sizeOf(p.SyncFireTaskState),
        };
        if (!zeros(data.storage[used..])) return false;
    }
    const clean = g.flags == 0 and g.action == 0;
    const boolean = g.value >= 0 and g.value <= 1;
    switch (g.kind) {
        p.SYNC_ACTOR_BARC_SUSPENSION => return clean and boolean and (g.character == 417 or g.character == 429) and
            (data.barc_suspension.body_flags == 0x42 or data.barc_suspension.body_flags == 0x43) and data.barc_suspension.cache_index <= 1,
        p.SYNC_ACTOR_BARC_ALIGNMENT => return clean and g.value == 0 and g.character == 417 and
            (data.barc_alignment.body_flags == 0x42 or data.barc_alignment.body_flags == 0x43) and barcBasis(&data.barc_alignment.basis),
        p.SYNC_ACTOR_ARENA_RUN_RANDOM => return g.flags <= 1 and g.action == 0 and g.value >= 0 and g.value <= 65535 and g.character == 119 and data.arena_run_random.behavior_class == 0x6dee68 and data.arena_run_random.run_state == 10,
        p.SYNC_ACTOR_RIDER_FIRE => return g.flags <= 1 and g.action == 0 and boolean and data.rider_fire.behavior_class == 0x6d83dc and data.rider_fire.mount_slot < p.SYNC_MAX_ACTORS and data.rider_fire.mount_generation != 0 and v.finite(data.rider_fire.cooldown),
        p.SYNC_ACTOR_RYLOTH_FIGHTER_DEATH => return clean and boolean and g.character == 381 and zeros(&data.storage),
        p.SYNC_ACTOR_FORCE_ELIGIBILITY => return g.flags <= 2 and g.action == 0 and boolean and zeros(&data.storage),
        p.SYNC_ACTOR_TUBE_CONTACT => return g.flags <= 3 and g.action == 0 and boolean and
            (if (g.flags == 2) zeros(&data.storage) else v.finite(data.tube_position)),
        p.SYNC_ACTOR_MELEE_CONTACT => return g.flags <= 1 and g.action == 0 and boolean and data.melee_contact.attacker_slot < p.SYNC_MAX_ACTORS and data.melee_contact.attacker_generation != 0,
        p.SYNC_ACTOR_HAZARD_DEATH => return clean and boolean and zeros(data.storage[4..]),
        p.SYNC_ACTOR_SPELLIT_ADMISSION => return ((g.flags <= 1 and (g.action == 0x24 or g.action == 0x25)) or (g.flags >= 2 and g.flags <= 5 and g.action == 0)) and boolean and zeros(data.storage[4..]),
        p.SYNC_FIRE_TASK_VISIBILITY => return g.flags & p.SYNC_FIRE_TASK_QUEUES_SHOT != 0 and boolean and data.state.repeat <= 255 and v.finite(data.state) and data.state.delta >= 0,
        p.SYNC_FIRE_ATTACK_SUPPORT => return clean and g.value >= -128 and g.value <= 127 and v.zero(&data.state),
        p.SYNC_ACTOR_BREAKUP_VISIBILITY, p.SYNC_ACTOR_DEATH_BREAKUP, p.SYNC_ACTOR_FALL_VISIBILITY => return clean and boolean and v.zero(&data.state),
        p.SYNC_ACTOR_AIM_BASE => {
            const s = &data.aim_base;
            return clean and g.value == 0 and s.task_class != 0 and s.reserved == 0 and v.finite(s.*) and s.delta >= 0;
        },
        p.SYNC_ACTOR_FORCE_VISIBILITY => {
            const s = &data.force;
            return clean and boolean and s.caster_slot < p.SYNC_MAX_ACTORS and s.caster_generation != 0 and !any(s.reserved);
        },
        p.SYNC_ACTOR_FORCE_GEOMETRY => {
            const s = &data.force_geometry;
            return clean and g.value == 0 and s.caster_slot < p.SYNC_MAX_ACTORS and s.caster_generation != 0 and s.reserved == 0 and v.finite(s.*);
        },
        p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY => {
            const s = &data.script_shoot;
            return clean and boolean and s.model_class != 0 and s.brain_class != 0 and s.state_class != 0 and s.brain_admission == 1 and
                s.state_flags <= 65535 and s.argument_count <= p.SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS and s.initialize <= 1 and
                (s.initialize == 0 or s.state_flags == 0) and s.caller_rva != 0 and s.reserved == 0 and any(s.argument_hash);
        },
        p.SYNC_ACTOR_PRIMARY_PERCEPTION => {
            const s = &data.perception;
            if (!clean or g.value != 0 or s.target_visible > 1 or !v.finite(s.*) or s.distance < 0 or !sourceValid(s.target_source)) return false;
            if (s.target_slot != 0xffffffff) return s.target_slot < p.SYNC_MAX_ACTORS and s.target_generation != 0 and abi.validLevel(s.target_character);
            var empty = std.mem.zeroes(p.SyncPrimaryPerceptionState);
            empty.clock = s.clock;
            empty.target_slot = 0xffffffff;
            return v.equal(s, &empty);
        },
        p.SYNC_ACTOR_CHARACTER_MOTION => {
            const s = &data.character_motion;
            return clean and g.value == 0 and s.body_class != 0 and s.rest_counter <= 65535 and supportValid(s) and v.finite(s.velocity);
        },
        p.SYNC_ACTOR_SPELLIT_NODE => {
            const s = &data.spellit_node;
            return clean and g.value == 0 and s.reserved == 0 and s.gizmo_class != 0 and s.receiver_class != 0 and any(s.resource_name) and
                s.poi_count != 0 and s.poi_count <= 65536 and s.poi_ordinal < s.poi_count and s.poi_name != 0 and s.component_class != 0 and
                s.node_ordinal < 65536 and s.gizmo_ordinal < 65536 and v.finite(s.position);
        },
        p.SYNC_ACTOR_SPELLIT_QUERY => {
            const s = &data.spellit;
            return clean and g.value == 0 and s.manager_class != 0 and s.caller_site != 0 and s.heading <= 65535 and s.reserved == 0 and v.finite(s.*);
        },
        p.SYNC_ACTOR_RTS_COMPETITOR => {
            const s = &data.competitor;
            return clean and g.value == 0 and s.competitor_class != 0 and v.finite(s.*) and s.delta >= 0;
        },
        p.SYNC_ACTOR_AIM_TASK => {
            const s = &data.aim;
            return clean and boolean and s.reserved == 0 and s.task_class != 0 and
                (if (s.target_generation != 0) s.target_slot < p.SYNC_MAX_ACTORS else s.target_slot == 0) and v.finite(s.*);
        },
        else => return false,
    }
}

pub fn barcBasis(basis: *const [9]f32) bool {
    if (!v.finite(basis.*)) return false;
    for (0..3) |axis| {
        const x, const y, const z = basis[axis * 3 ..][0..3].*;
        const length = x * x + y * y + z * z;
        if (length < 0.5 or length > 2.0) return false;
    }
    return true;
}
