const std = @import("std");
const p = @import("protocol.zig");
const v = @import("validation.zig");
const abi = @import("abi.zig");

fn nonzero(words: anytype) bool {
    for (words) |word| if (word != 0) return true;
    return false;
}
fn address(value: u32) bool {
    return value >= 0x400000 and value < 0xb00000;
}
fn emptyTail(value: anytype, offset: usize) bool {
    for (std.mem.asBytes(value)[offset..]) |byte| if (byte != 0) return false;
    return true;
}
pub fn sameSource(a: *const p.SyncPhysicsChoice, b: *const p.SyncPhysicsChoice) bool {
    if (!valid(a) or !valid(b) or a.kind != b.kind or a.site != b.site) return false;
    const first = std.mem.asBytes(&a.payload);
    const second = std.mem.asBytes(&b.payload);
    switch (a.kind) {
        p.SYNC_PHYSICS_EFFECT_STEP, p.SYNC_PHYSICS_EFFECT_REST => return std.mem.eql(u8, first[0..20], second[0..20]) and std.mem.eql(u32, a.payload.basic.recipe[1..], b.payload.basic.recipe[1..]),
        p.SYNC_PHYSICS_RTS_GENERATOR => return std.mem.eql(u8, first[0..24], second[0..24]),
        p.SYNC_PHYSICS_RTS_ORDER => return std.mem.eql(u8, first[0..16], second[0..16]) and std.mem.eql(u32, &a.payload.rts_order.source_key, &b.payload.rts_order.source_key),
        p.SYNC_PHYSICS_BREAKUP_BASIS => return std.mem.eql(u8, first[0..16], second[0..16]),
        p.SYNC_PHYSICS_BREAKUP_SCALE, p.SYNC_PHYSICS_EFFECT_BIRTH => return std.mem.eql(u8, first[0..20], second[0..20]),
        p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION, p.SYNC_PHYSICS_RTS_BODY_BASIS, p.SYNC_PHYSICS_RTS_BODY_MOTION => return std.mem.eql(u8, first[0..32], second[0..32]),
        p.SYNC_PHYSICS_SPELLIT_STEP => return a.payload.spellit_step.clock == b.payload.spellit_step.clock and std.mem.eql(u8, first[20..], second[20..]),
        p.SYNC_PHYSICS_SPELLIT_POSE => return a.payload.spellit_pose.clock == b.payload.spellit_pose.clock and std.mem.eql(u8, first[16..76], second[16..76]),
        else => {},
    }
    if (a.kind >= p.SYNC_PHYSICS_SPELLIT_SEED) {
        if (a.payload.world.clock != b.payload.world.clock) return false;
        for (8..@sizeOf(p.SyncPhysicsWorldInput)) |i| {
            if ((a.kind == p.SYNC_PHYSICS_MODULE_SEED or a.kind == p.SYNC_PHYSICS_GUN_JAM_SEED) and i >= 16 and i < 20) continue;
            if (first[i] != second[i]) return false;
        }
        return true;
    }
    if (!std.mem.eql(u8, first[0..20], second[0..20])) return false;
    const words: usize = if (a.kind == p.SYNC_PHYSICS_BREAKUP_LAUNCH) 2 else 6;
    return std.mem.eql(u32, a.payload.basic.recipe[0..words], b.payload.basic.recipe[0..words]);
}
pub fn vehicleSite(site: u32) bool {
    return switch (site) {
        0x997f03, 0x997f14, 0x997f25, 0x99803e, 0x998085, 0x9980b4, 0x99813e, 0x9981cf, 0x998288, 0x9982b7, 0x9982ee => true,
        else => false,
    };
}
pub fn valid(choice: *const p.SyncPhysicsChoice) bool {
    const u = &choice.payload;
    switch (choice.kind) {
        p.SYNC_PHYSICS_EFFECT_STEP => {
            const s = &u.basic;
            const delta: f32 = @bitCast(s.recipe[0]);
            return choice.site == 0x743bb0 and s.flags == 0 and s.model == 0 and !nonzero(s.name_hash) and
                v.finite(delta) and delta >= 0 and delta <= 0.1 and !nonzero(s.recipe[1..]) and s.rng == 0 and emptyTail(choice, 56);
        },
        p.SYNC_PHYSICS_EFFECT_REST => {
            const s = &u.basic;
            return choice.site == 0x743ca8 and s.flags & 0x40000000 != 0 and s.model <= 65535 and
                s.name_hash[0] != 0 and s.name_hash[1] != 0 and s.name_hash[1] <= p.SYNC_MAX_PHYSICS_CHOICES and
                s.recipe[0] & ~@as(u32, 0x41) == 0 and (s.recipe[1] == 0 or address(s.recipe[1])) and
                !nonzero(s.recipe[2..]) and s.rng == 0 and emptyTail(choice, 56);
        },
        p.SYNC_PHYSICS_RTS_VISIBILITY => {
            const s = &u.world;
            return (choice.site == 0x5525e0 or choice.site == 0x546674 or choice.site == 0x561ba9) and s.value <= 1 and address(s.gizmo_class) and
                s.gizmo_ordinal < 65536 and nonzero(s.source_name) and emptyTail(s, 32);
        },
        p.SYNC_PHYSICS_RTS_GENERATOR => {
            const s = &u.rts_generator;
            return choice.site == 0x547d30 and s.team_slot < p.SYNC_MAX_RTS_TEAMS and s.index < 8 and s.side < 2 and
                address(s.object_class) and v.finite(s.*) and s.delta >= 0 and s.timer_delta >= 0 and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_RTS_ORDER => {
            const s = &u.rts_order;
            if ((choice.site != 0x55e2c0 and choice.site != 0x55e65c) or s.team_slot >= p.SYNC_MAX_RTS_TEAMS or
                s.building_ordinal >= 65536 or !nonzero(s.source_key) or !address(s.order_class) or !v.finite(s.*) or nonzero(s.reserved)) return false;
            return if (choice.site == 0x55e2c0) s.ready == 0 else s.ready & ~@as(u32, 2) == 0 and s.state == 0 and s.previous_state == 0 and s.elapsed == 0 and s.progress == 0;
        },
        p.SYNC_PHYSICS_EFFECT_BIRTH, p.SYNC_PHYSICS_BREAKUP_SCALE => {
            const s = &u.basic;
            const site: u32 = if (choice.kind == p.SYNC_PHYSICS_EFFECT_BIRTH) 0x7427d8 else 0x905f38;
            if (choice.site != site or s.flags & 0x40000000 == 0 or s.model > 65535 or !nonzero(s.name_hash) or s.rng != 0 or !emptyTail(choice, 56)) return false;
            const first: usize = 3;
            for (s.recipe[0..first]) |bits| if (!v.finite(@as(f32, @bitCast(bits)))) return false;
            return !nonzero(s.recipe[first..]);
        },
        p.SYNC_PHYSICS_BREAKUP_BASIS => {
            const s = &u.breakup_basis;
            return choice.site == 0x905f38 and s.model <= 65535 and nonzero(s.name_hash) and v.finite(s.matrix);
        },
        p.SYNC_PHYSICS_VEHICLE_RNG => {
            const s = &u.vehicle_rng;
            return vehicleSite(choice.site) and s.slot < p.SYNC_MAX_ACTORS and s.generation != 0 and abi.validLevel(s.character) and s.vehicle_type == 4 and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION, p.SYNC_PHYSICS_RTS_BODY_BASIS, p.SYNC_PHYSICS_RTS_BODY_MOTION => {
            const s = &u.spellit_body;
            const rts = choice.kind == p.SYNC_PHYSICS_RTS_BODY_BASIS or choice.kind == p.SYNC_PHYSICS_RTS_BODY_MOTION;
            if (choice.site != @as(u32, if (rts) 0x544b10 else 0x840660) or s.body_class == 0 or s.body_class >= 0x1000000 or
                s.piece_ordinal >= 65536 or s.reserved != 0 or !nonzero(s.key) or !v.finite(s.values)) return false;
            return choice.kind != p.SYNC_PHYSICS_RTS_BODY_MOTION or
                (@as(u32, @bitCast(s.values[7])) == 0 and @as(u32, @bitCast(s.values[11])) == 0);
        },
        p.SYNC_PHYSICS_SPELLIT_SELECTION => {
            const s = &u.spellit_selection;
            return (choice.site == 0x8406a7 or choice.site == 0x840790 or choice.site == 0x840b93) and s.gizmo_class != 0 and
                s.gizmo_ordinal < 65536 and s.piece_count <= 65536 and s.candidate_count <= s.piece_count and
                nonzero(s.source_name) and nonzero(s.eligibility) and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_SPELLIT_STEP => {
            const s = &u.spellit_step;
            return choice.site == 0x86101e and s.game_seed <= 65535 and v.finite(s.*) and s.delta >= 0 and s.delta <= 0.1 and
                s.gizmo_class != 0 and s.gizmo_ordinal < 65536 and nonzero(s.source_name) and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_SPELLIT_POSE => {
            const s = &u.spellit_pose;
            return choice.site == 0x8406b2 and s.gizmo_class != 0 and s.gizmo_ordinal < 65536 and v.finite(s.*) and
                nonzero(s.source_name) and nonzero(s.resource_name) and nonzero(s.poi_name);
        },
        p.SYNC_PHYSICS_MODULE_SEED => {
            const s = &u.module;
            return choice.site == 0x4da6d0 and s.module_id != 0 and s.module_type != 0 and s.module_class == 0x6e6b3c and
                s.burst_min <= 255 and s.burst_max <= 255 and s.burst_min < s.burst_max and s.channel_count <= 3 and
                s.weapon >= -128 and s.weapon <= 127 and v.finite(s.intervals) and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_GUN_JAM_SEED => {
            const s = &u.gun_jam;
            return choice.site == 0x4acb53 and s.module_id != 0 and s.module_type != 0 and s.member_count <= 12 and
                s.candidate_count <= std.math.maxInt(i32) and s.clip >= -32768 and s.clip <= 32767 and v.finite(s.*) and !nonzero(s.reserved);
        },
        p.SYNC_PHYSICS_SPELLIT_SEED, p.SYNC_PHYSICS_SPELLIT_ENTITY, p.SYNC_PHYSICS_SPELLIT_ENABLED, p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS => {
            const s = &u.world;
            if (s.gizmo_class == 0 or s.gizmo_ordinal >= 65536 or !nonzero(s.source_name)) return false;
            if (choice.kind == p.SYNC_PHYSICS_SPELLIT_SEED) return choice.site == 0x86101e and
                s.poi_ordinal == 0 and s.poi_count == 0 and s.receiver_class == 0 and s.piece_ordinal == 0 and !nonzero(s.resource_name) and !nonzero(s.poi_name);
            const site_valid = switch (choice.kind) {
                p.SYNC_PHYSICS_SPELLIT_ENTITY => choice.site == 0x8407d4,
                p.SYNC_PHYSICS_SPELLIT_ENABLED => choice.site == 0x84085b or choice.site == 0x812d8c or choice.site == 0x812e02,
                else => choice.site == 0x812d7a or choice.site == 0x812df0,
            };
            const value_valid = if (choice.kind == p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS) s.value & ~@as(u32, 4) == 0 else s.value <= 1;
            return site_valid and value_valid and s.receiver_class != 0 and s.piece_ordinal < 65536 and s.poi_count != 0 and
                s.poi_count <= 65536 and s.poi_ordinal < s.poi_count and nonzero(s.resource_name) and nonzero(s.poi_name);
        },
        else => {
            const s = &u.basic;
            if (!emptyTail(choice, 56) or s.flags & 0x40000000 == 0 or s.model > 65535 or !nonzero(s.name_hash) or !address(choice.site)) return false;
            if (choice.kind == p.SYNC_PHYSICS_BREAKUP_LAUNCH) for (s.recipe[2..]) |bits| {
                if (!v.finite(@as(f32, @bitCast(bits)))) return false;
            };
            return switch (choice.kind) {
                p.SYNC_PHYSICS_AXIS_SPIN => s.flags & 0x80 != 0,
                p.SYNC_PHYSICS_ROTATION_SPIN => s.flags & 0x100000 != 0,
                p.SYNC_PHYSICS_BREAKUP_LAUNCH => choice.site == 0x905f38,
                else => false,
            };
        },
    }
}
