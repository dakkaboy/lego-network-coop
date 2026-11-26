const p = @import("protocol.zig");
const s = @import("tick_sites.zig");
const fire_sites = blk: {
    var values: [s.PACK_FIRE_FIELDS]u32 = undefined;
    for (&values, 0..) |*value, i| value.* = s.PACK_FIRE_TARGET + i;
    break :blk values;
};

const coefficients = [_]u32{ 0xfb0fc4, 0xfb0fa8, 0xfb0fb4, 0xfb102c, 0xfb0fb0, 0xfb0fac, 0xfb1028, 0xfb0fa0, 0xfb1014, 0xfb0fc0, 0xfb1070, 0xfb1018, 0xfb101c, 0xfb0fb8, 0xfb0fa4, 0xfb0fbc, 0xfb0fc8 };
const hit_sites = [_]u32{ s.PACK_HIT_REACTION, s.PACK_HIT_AVOIDANCE, s.PACK_HIT_DEBRIS, s.PACK_HIT_SHOCK, s.PACK_HIT_HEADING, s.PACK_IMPULSE_TIMER, s.PACK_IMPULSE_SPEED, s.PACK_IMPULSE_HEADING, s.PACK_DEATH_CLIP, s.PACK_MODE10_DURATION, s.PACK_MODE10_CLIP_PHASE, s.PACK_MODE28_RECOVERY_DURATION };
const groups = [_][]const u32{
    &.{ s.ZILLO_THROW, s.ZILLO_THROW + 1, s.ZILLO_THROW + 2, s.ZILLO_THROW + 3 },
    &.{ s.ZILLO_RELEASE, s.ZILLO_RELEASE + 1, s.ZILLO_RELEASE + 2, s.ZILLO_RELEASE + 3, s.ZILLO_RELEASE + 4, s.ZILLO_RELEASE + 5 },
    &.{ s.ZILLO_SPREAD, s.ZILLO_SPREAD + 1, s.ZILLO_SPREAD + 2, s.ZILLO_SPREAD + 3, s.ZILLO_SPREAD + 4, s.ZILLO_SPREAD + 5 },
    &.{ s.ZILLO_ORIENTATION, s.ZILLO_ORIENTATION + 1, s.ZILLO_ORIENTATION + 2, s.ZILLO_ORIENTATION + 3, s.ZILLO_ORIENTATION + 4, s.ZILLO_ORIENTATION + 5 },
    &.{ s.ZILLO_THROW_COUNTDOWN, s.ZILLO_THROW_COUNTDOWN + 1, s.ZILLO_THROW_COUNTDOWN + 2, s.ZILLO_THROW_COUNTDOWN + 3 },
    &.{ s.ZILLO_GROUND_RENDER, s.ZILLO_GROUND_RENDER + 1, s.ZILLO_GROUND_RENDER + 2, s.ZILLO_GROUND_RENDER + 3, s.ZILLO_GROUND_RENDER + 4, s.ZILLO_GROUND_RENDER + 5 },
    &.{ s.PACK_BEHAVIOR, s.PACK_BEHAVIOR + 1, s.PACK_BEHAVIOR + 2 },
    &.{ s.PACK_ANIMATION_MEMBER, s.PACK_ANIMATION_REQUEST, s.PACK_ANIMATION_STATE, s.PACK_ANIMATION_CLOCK, s.PACK_ANIMATION_DELTA },
    &.{ s.WEAPON_COMMAND_ACTOR, s.WEAPON_COMMAND_GENERATION, s.WEAPON_COMMAND_VALUE },
    &.{ s.PACK_MODE_MEMBER, s.PACK_MODE_WITNESS, s.PACK_MODE_VALUE },
    &.{ 0x7b8ae1, 0x7b8afd, 0x7b8b08 },
    &.{ s.RTS_GAME_RNG, s.RTS_ENGINE_RNG },
    &.{ s.RTS_PRODUCER_GAME_RNG, s.RTS_PRODUCER_ENGINE_RNG },
    &.{ s.RTS_TURRET_HEADING, s.RTS_TURRET_PILOT },
    &.{ s.RTS_TURRET_AIM, s.RTS_TURRET_PILOT },
    &.{ s.PACK_ATTACK, s.PACK_ATTACK_WITNESS },
    &.{ s.PACK_TIMER_MEMBER, s.PACK_TIMER_SEED },
    &.{ s.PACK_REARM_MEMBER, s.PACK_REARM_SEED },
    &.{ s.PACK_FORMATION_MEMBER, s.PACK_FORMATION_LEAVE },
    &.{ s.FIRE_VISIBILITY, s.FIRE_VISIBILITY_ACTOR },
    &.{ s.PACK_MOVE_TIMER, s.PACK_MOVE_TIMER_SEED },
    &.{ s.PACK_MOVE_HEADING, s.PACK_MOVE_HEADING_SEED },
    &.{ s.PACK_MOVE_CHOICE, s.PACK_MOVE_CHOICE_SEED },
    &.{ s.PACK_CELL_MEMBER, s.PACK_CELL_FLAGS },
};
const Run = struct { first: u32, count: u32, stride: u32 = 1 };
const runs = [_]Run{
    .{ .first = s.ACTOR_TURN_INPUT, .count = 5 },
    .{ .first = s.RTS_TURN_INPUT, .count = 4 },
    .{ .first = s.RTS_WAIT_RNG, .count = 5 },
    .{ .first = s.GIZMO_TURRET_SOURCE, .count = 7 },
    .{ .first = s.PACK_GOAL_MOVE, .count = s.PACK_GOAL_FIELDS },
    .{ .first = s.PACK_GOAL_ACTIVE, .count = s.PACK_GOAL_FIELDS },
    .{ .first = s.PACK_POSE_QUERY, .count = 5, .stride = 5 },
    .{ .first = s.PACK_POSE_COMMIT, .count = 5, .stride = 5 },
};
const rope_runs = [_]Run{
    .{ .first = s.ARENA_ROPE_BASIS, .count = 21 },
    .{ .first = s.ARENA_ROPE_BIRTH, .count = 9 },
    .{ .first = s.ARENA_ROPE_STEP, .count = 9 },
};
const death_sites = [_]u32{ s.PACK_DEATH_VERTICAL, s.PACK_DEATH_SPEED, s.PACK_DEATH_FLAGS };

fn contains(list: []const u32, site: u32) bool {
    for (list) |item| if (item == site) return true;
    return false;
}
fn field(run: Run, site: u32) ?u32 {
    if (site < run.first) return null;
    const offset = site - run.first;
    return if (offset % run.stride == 0 and offset / run.stride < run.count) offset / run.stride else null;
}
fn finite(bits: u32) bool {
    return bits & 0x7fffffff < 0x7f800000;
}
fn angle(bits: u32) bool {
    const value: i32 = @bitCast(bits);
    return value >= -32768 and value <= 32768;
}
pub fn gateValid(gate: p.SyncTickGate) bool {
    if (gate.site >= s.SWAMP_PERISCOPE_QUERY and gate.site < s.SWAMP_PERISCOPE_QUERY + 5) return gate.value <= 1;
    for ([_]u32{ s.PACK_SPAWN_X, s.PACK_SPAWN_Z }) |first| if (gate.site >= first and gate.site < first + 8) return switch (gate.site - first) {
        0, 2, 3, 4 => gate.value <= 65535,
        else => true,
    };
    if (gate.site >= s.PACK_FIRE_TARGET and gate.site < s.PACK_FIRE_TARGET + s.PACK_FIRE_FIELDS) return switch (gate.site - s.PACK_FIRE_TARGET) {
        0 => gate.value <= p.SYNC_MAX_ACTORS,
        1 => true,
        2 => gate.value <= 32767,
        7 => gate.value <= 1,
        8, 9, 10 => true,
        else => finite(gate.value),
    };
    const site = gate.site;
    const value = gate.value;
    if (field(runs[0], site)) |i| return switch (i) {
        0 => value < p.SYNC_MAX_ACTORS,
        1 => value != 0,
        2 => value > 0 and value < 0x900000,
        else => value <= 65535,
    };
    if (field(runs[1], site)) |i| return switch (i) {
        0 => value < p.SYNC_MAX_ACTORS,
        1 => value != 0,
        else => angle(value),
    };
    if (field(runs[2], site) != null) return true;
    if (field(runs[3], site)) |i| return switch (i) {
        4 => value <= 65535,
        6 => finite(value),
        else => true,
    };
    for (runs[4..6]) |run| if (field(run, site)) |i| return switch (i) {
        0 => true,
        4, 8 => value <= 65535,
        9 => value <= 15,
        else => finite(value),
    };
    for (runs[6..]) |run| if (field(run, site)) |i| return switch (i) {
        0 => true,
        4 => value <= 65535,
        else => finite(value),
    };
    for (rope_runs) |run| if (field(run, site)) |index| return switch (index) {
        0 => value < p.SYNC_MAX_ACTORS,
        1 => value != 0,
        2 => value & 0xffff != 0,
        else => finite(value),
    };
    if (contains(&coefficients, site)) return value <= 0x3f800000 or value == 0x80000000;
    if (contains(&hit_sites, site) or contains(&hit_sites, site -% 5)) return true;
    return switch (site) {
        s.ZILLO_THROW, s.ZILLO_RELEASE, s.ZILLO_SPREAD, s.ZILLO_ORIENTATION, s.ZILLO_THROW_COUNTDOWN => value < p.SYNC_MAX_ACTORS,
        s.ZILLO_THROW + 1, s.ZILLO_RELEASE + 1, s.ZILLO_SPREAD + 1, s.ZILLO_ORIENTATION + 1, s.ZILLO_THROW_COUNTDOWN + 1 => value != 0,
        s.ZILLO_THROW + 2, s.ZILLO_RELEASE + 2, s.ZILLO_SPREAD + 2, s.ZILLO_ORIENTATION + 2, s.ZILLO_THROW_COUNTDOWN + 2 => value > 0 and value < 0x900000,
        s.ZILLO_RELEASE + 3, s.ZILLO_ORIENTATION + 3 => value < 3,
        s.ZILLO_SPREAD + 3 => value == 1 or value == 2,
        s.ZILLO_RELEASE + 4, s.ZILLO_SPREAD + 4, s.ZILLO_ORIENTATION + 4 => value == 6 or value == 31 or value == 33,
        s.ZILLO_ORIENTATION + 5 => value <= 0xffff,
        s.ZILLO_THROW + 3, s.ZILLO_RELEASE + 5, s.ZILLO_SPREAD + 5, s.ZILLO_THROW_COUNTDOWN + 3 => true,
        s.ZILLO_GROUND_RENDER, s.ZILLO_GROUND_RENDER + 1, s.ZILLO_GROUND_RENDER + 2, s.ZILLO_GROUND_RENDER + 3 => true,
        s.ZILLO_GROUND_RENDER + 4 => value >= 1 and value <= 3,
        s.ZILLO_GROUND_RENDER + 5 => value <= 1,
        s.PACK_BEHAVIOR_TARGET...s.PACK_BEHAVIOR_TARGET + 3 => finite(value),
        s.PACK_BEHAVIOR_FORMATION, s.PACK_BEHAVIOR_TURN => value <= 0xffff,
        s.PACK_BEHAVIOR_TURN + 1 => value <= 1,
        s.PACK_BEHAVIOR_MARCH...s.PACK_BEHAVIOR_MARCH + 4 => finite(value),
        s.PACK_BEHAVIOR_MARCH + 5 => value <= 1,
        s.PACK_BEHAVIOR => value < 65535,
        s.PACK_BEHAVIOR + 1 => true,
        s.PACK_BEHAVIOR + 2 => value == 0 or (value >= 0x400000 and value < 0x1200000 and value & 3 == 0),
        0x8888cd => value <= 255,
        s.GAME_TIME, s.PACK_ANIMATION_CLOCK, s.PACK_ANIMATION_DELTA, s.PACK_DEATH_VERTICAL, s.PACK_DEATH_SPEED, 0x7b8b08 => finite(value),
        0x888889, s.PACK_FORMATION_LEAVE, s.RTS_WAIT_SAMPLE => value <= 1,
        s.RTS_PACK_ADMISSION => value < 32,
        s.RTS_TURRET_HEADING, s.RTS_TURRET_AIM => value >> 16 < p.SYNC_MAX_ACTORS,
        s.RTS_TURRET_PILOT, s.FIRE_VISIBILITY_ACTOR, s.WEAPON_COMMAND_GENERATION => value != 0,
        s.FIRE_VISIBILITY => value >> 8 < p.SYNC_MAX_ACTORS,
        s.WEAPON_COMMAND_ACTOR => value < p.SYNC_MAX_ACTORS,
        s.PACK_CELL_FLAGS => value & ~@as(u32, 0x60) == 0,
        s.PACK_ANIMATION_STATE => value & ~@as(u32, 0x1ffff) == 0,
        s.PACK_MODE_VALUE => value & ~@as(u32, 0x3ff) == 0,
        s.PACK_DEATH_FLAGS => value & ~@as(u32, 0xffff) == 0,
        0x889edc => value == 0xffffffff or value <= 0x14,
        0x9dda14 => value == 1 or (value & 1 == 0 and value / 2 <= p.SYNC_MAX_ACTORS),
        s.RTS_GAME_RNG, s.RTS_PRODUCER_GAME_RNG => value <= 65535,
        s.WEAPON_COMMAND_VALUE, s.PACK_CELL_MEMBER, s.PACK_MOVE_TIMER, s.PACK_MOVE_TIMER_SEED, s.PACK_MOVE_HEADING, s.PACK_MOVE_HEADING_SEED, s.PACK_MOVE_CHOICE, s.PACK_MOVE_CHOICE_SEED, s.PACK_ANIMATION_MEMBER, s.PACK_ANIMATION_REQUEST, s.PACK_ATTACK, s.PACK_ATTACK_WITNESS, s.PACK_MODE_MEMBER, s.PACK_MODE_WITNESS, s.PACK_TIMER_MEMBER, s.PACK_TIMER_SEED, s.PACK_REARM_MEMBER, s.PACK_REARM_SEED, s.PACK_FORMATION_MEMBER, s.RTS_ENGINE_RNG, s.RTS_PRODUCER_ENGINE_RNG, 0x7b8ae1, 0x7b8afd => true,
        else => false,
    };
}
fn matches(gates: []const p.SyncTickGate, sites: []const u32) bool {
    if (gates.len < sites.len) return false;
    for (gates[0..sites.len], sites) |gate, site| if (gate.site != site or gate.clock != gates[0].clock or !gateValid(gate)) return false;
    return true;
}
pub fn streamValid(gates: []const p.SyncTickGate) bool {
    if (gates.len > p.SYNC_MAX_TICK_GATES) return false;
    var i: usize = 0;
    next: while (i < gates.len) {
        const gate = gates[i];
        if (!gateValid(gate)) return false;
        if (gate.site == s.PACK_SPAWN_X) {
            if (gates.len - i < 16) return false;
            for (0..16) |j| {
                const part = gates[i + j];
                const first = if (j < 8) s.PACK_SPAWN_X else s.PACK_SPAWN_Z;
                if (part.site != first + j % 8 or part.clock != gate.clock or !gateValid(part)) return false;
                if (j >= 8 and j % 8 < 7 and part.value != gates[i + j - 8].value) return false;
            }
            i += 16;
            continue;
        }
        for ([_]u32{ s.PACK_SPAWN_X, s.PACK_SPAWN_Z }) |first| if (gate.site >= first and gate.site < first + 8) return false;
        if (gate.site == s.GAME_TIME) {
            if (gates.len - i < 1 + coefficients.len or !matches(gates[i + 1 ..], &coefficients)) return false;
            if (gates[i + 1].clock != gate.clock) return false;
            i += 1 + coefficients.len;
            continue;
        }
        for (runs ++ rope_runs) |run| if (field(run, gate.site)) |index| {
            if (index != 0 or gates.len - i < run.count) return false;
            for (0..run.count) |j| {
                const part = gates[i + j];
                if (part.site != run.first + j * run.stride or part.clock != gate.clock or !gateValid(part)) return false;
            }
            if ((gate.site == s.PACK_GOAL_MOVE or gate.site == s.PACK_GOAL_ACTIVE) and gates[i + 9].value & 1 == 0 and gates[i + 8].value != 0) return false;
            i += run.count;
            continue :next;
        };
        if (contains(&hit_sites, gate.site)) {
            const sites = [_]u32{ gate.site, gate.site + 5 };
            if (!matches(gates[i..], &sites)) return false;
            i += 2;
            continue;
        }
        for (groups) |group| if (gate.site == group[0]) {
            if (!matches(gates[i..], group)) return false;
            var count = group.len;
            if (gate.site == s.PACK_BEHAVIOR and gates[i + 2].value == s.pack_behavior_target_class) {
                if (!matches(gates[i + count ..], &s.pack_behavior_target_sites) or gates[i + count].clock != gate.clock) return false;
                count += s.pack_behavior_target_sites.len;
            }
            if (gate.site == s.PACK_BEHAVIOR and gates[i + 2].value == s.pack_behavior_formation_class) {
                if (!matches(gates[i + count ..], &.{s.PACK_BEHAVIOR_FORMATION}) or gates[i + count].clock != gate.clock) return false;
                count += 1;
            }
            if (gate.site == s.PACK_BEHAVIOR and gates[i + 2].value == s.pack_behavior_turn_class) {
                if (!matches(gates[i + count ..], &s.pack_behavior_turn_sites) or gates[i + count].clock != gate.clock) return false;
                count += s.pack_behavior_turn_sites.len;
            }
            if (gate.site == s.PACK_BEHAVIOR and gates[i + 2].value == s.pack_behavior_march_class) {
                if (!matches(gates[i + count ..], &s.pack_behavior_march_sites) or gates[i + count].clock != gate.clock) return false;
                count += s.pack_behavior_march_sites.len;
            }
            if (gate.site == s.PACK_MODE_MEMBER and gates[i + 2].value & 0xff == 9) {
                if (!matches(gates[i + count ..], &death_sites) or gates[i + count].clock != gate.clock) return false;
                count += death_sites.len;
            }
            if (gate.site == s.PACK_MODE_MEMBER and gates[i + 2].value & 0xff == 18) {
                if (!matches(gates[i + count ..], &fire_sites) or gates[i + count].clock != gate.clock) return false;
                const target = gates[i + count ..][0..s.PACK_FIRE_FIELDS];
                if ((target[0].value == 0 and (target[1].value != 0 or target[2].value != 0 or target[8].value != 0 or target[9].value != 0 or target[10].value != 0)) or (target[0].value != 0 and target[1].value == 0)) return false;
                count += fire_sites.len;
            }
            i += count;
            continue :next;
        };
        if ((gate.site >= s.PACK_FIRE_TARGET and gate.site < s.PACK_FIRE_TARGET + s.PACK_FIRE_FIELDS) or contains(&coefficients, gate.site) or contains(&death_sites, gate.site) or contains(&hit_sites, gate.site -% 5)) return false;
        if (contains(&s.pack_behavior_target_sites, gate.site) or contains(&s.pack_behavior_turn_sites, gate.site) or contains(&s.pack_behavior_march_sites, gate.site) or gate.site == s.PACK_BEHAVIOR_FORMATION) return false;
        for (groups) |group| if (contains(group[1..], gate.site)) return false;
        i += 1;
    }
    return true;
}
