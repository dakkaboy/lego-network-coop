const std = @import("std");
const p = @import("protocol.zig");
const s = @import("tick_sites.zig");
const tick = @import("tick_validation.zig");
const physics = @import("physics_validation.zig");
const frame = @import("frame_validation.zig");
const Cursor = @import("validation_reference.zig").Cursor;
extern fn sync_frame_encode(*const p.SyncFrame, [*]u8, u32) u32;
extern fn sync_frame_decode(*p.SyncFrame, [*]const u8, u32) c_int;
comptime {
    _ = @import("wire.zig");
}

const values = [_]u32{ 0, 1, 2, 3, 4, 7, 8, 9, 15, 16, 17, 20, 21, 31, 32, 63, 64, 65, 127, 128, 255, 256, 4095, 4096, 65535, 65536, 0x3dcccccd, 0x3f800000, 0x3f800001, 0x40000000, 0x80000000, 0x7f800000, 0xff800000, 0x7fc00001, 0xffffffff };

fn sameGate(oracle: *Cursor, gate: p.SyncTickGate) !void {
    const expected = oracle.tickValid(&gate) != 0;
    const actual = tick.gateValid(gate);
    if (expected != actual) std.debug.print("tick mismatch site={x} value={x}\n", .{ gate.site, gate.value });
    try std.testing.expectEqual(expected, actual);
}
fn sameStream(oracle: *Cursor, gates: []const p.SyncTickGate) !void {
    try std.testing.expectEqual(oracle.tickStream(gates.ptr, @intCast(gates.len)) != 0, tick.streamValid(gates));
}
test "wire validation: all tick sites and boundary values match the original" {
    @setEvalBranchQuota(2000);
    var oracle = Cursor.init(0);
    defer oracle.finish();
    inline for (@typeInfo(s).@"struct".decl_names) |name| {
        if (comptime std.mem.eql(u8, name, "RTS_WAIT_SAMPLE") or std.mem.startsWith(u8, name, "PACK_BEHAVIOR") or std.mem.startsWith(u8, name, "pack_behavior_") or std.mem.eql(u8, name, "PACK_FIRE_TARGET") or std.mem.eql(u8, name, "PACK_FIRE_FIELDS") or std.mem.eql(u8, name, "PACK_MODE28_RECOVERY_DURATION") or std.mem.startsWith(u8, name, "PACK_SPAWN_") or std.mem.startsWith(u8, name, "ZILLO_") or std.mem.startsWith(u8, name, "ARENA_ROPE_")) continue;
        const site = @field(s, name);
        for (values) |value| {
            try sameGate(&oracle, .{ .site = site, .clock = 17, .value = value });
            try sameGate(&oracle, .{ .site = site +% 1, .clock = 17, .value = value });
            try sameGate(&oracle, .{ .site = site -% 1, .clock = 17, .value = value });
            try sameGate(&oracle, .{ .site = site +% 5, .clock = 17, .value = value });
        }
    }
    for ([_]u32{ 0x8888cd, 0x888889, 0x889edc, 0x9dda14, 0x7b8ae1, 0x7b8afd, 0x7b8b08, 0xfb0fc4, 0, 0xffffffff }) |site|
        for (values) |value| try sameGate(&oracle, .{ .site = site, .clock = 17, .value = value });
    for (values) |value| {
        const branch = p.SyncTickGate{ .site = s.RTS_WAIT_SAMPLE, .clock = 17, .value = value };
        try std.testing.expectEqual(value <= 1, tick.gateValid(branch));
    }
    try spawnWireCases();
    const recovery = s.PACK_MODE28_RECOVERY_DURATION;
    var gates = [_]p.SyncTickGate{
        .{ .site = recovery, .clock = 17, .value = 0xe7ede210 },
        .{ .site = recovery + 5, .clock = 17, .value = 0x9f29a3b1 },
    };
    try std.testing.expect(tick.streamValid(&gates));
    try std.testing.expect(!tick.streamValid(gates[0..1]));
    try std.testing.expect(!tick.streamValid(gates[1..2]));
    gates[1].clock += 1;
    try std.testing.expect(!tick.streamValid(&gates));
    gates[1].clock -= 1;
    gates[1].site = s.PACK_MODE10_DURATION + 5;
    try std.testing.expect(!tick.streamValid(&gates));
}
fn spawnWireCases() !void {
    const source = [_]u32{ 65535, 0xffffffff, 0, 39, 0, 0x12345678, 0x87654321, 5430013 };
    var gates: [16]p.SyncTickGate = undefined;
    for (&gates, 0..) |*gate, i| gate.* = .{ .site = (if (i < 8) s.PACK_SPAWN_X else s.PACK_SPAWN_Z) + @as(u32, @intCast(i % 8)), .clock = 100, .value = source[i % 8] };
    try std.testing.expect(tick.streamValid(&gates));
    for (1..16) |count| {
        try std.testing.expect(!tick.streamValid(gates[0..count]));
        try std.testing.expect(!tick.streamValid(gates[count..]));
    }
    for (&gates) |*gate| {
        gate.clock += 1;
        try std.testing.expect(!tick.streamValid(&gates));
        gate.clock -= 1;
        gate.site += 1;
        try std.testing.expect(!tick.streamValid(&gates));
        gate.site -= 1;
    }
    for (0..7) |i| {
        gates[i + 8].value ^= 1;
        try std.testing.expect(!tick.streamValid(&gates));
        gates[i + 8].value ^= 1;
    }
    for ([_]usize{ 0, 2, 3, 4 }) |i| {
        const old = gates[i].value;
        gates[i].value = 65536;
        gates[i + 8].value = 65536;
        try std.testing.expect(!tick.streamValid(&gates));
        gates[i].value = old;
        gates[i + 8].value = old;
    }
    gates[15].value = 0xffffffff;
    try std.testing.expect(tick.streamValid(&gates));
    try std.testing.expect(!tick.gateValid(.{ .site = s.PACK_SPAWN_BIRTH, .clock = 100, .value = 0 }));
}

test "wire validation: pack behavior requires a complete identity and native class" {
    var gates = [_]p.SyncTickGate{
        .{ .site = s.PACK_BEHAVIOR, .clock = 10, .value = 0 },
        .{ .site = s.PACK_BEHAVIOR + 1, .clock = 10, .value = 0xffffffff },
        .{ .site = s.PACK_BEHAVIOR + 2, .clock = 10, .value = 0xadcc94 },
    };
    try std.testing.expect(tick.streamValid(&gates));
    try std.testing.expect(!tick.streamValid(gates[0..2]));
    try std.testing.expect(!tick.streamValid(gates[1..]));
    for (0..3) |i| {
        gates[i].clock += 1;
        try std.testing.expect(!tick.streamValid(&gates));
        gates[i].clock -= 1;
    }
    gates[0].value = 65535;
    try std.testing.expect(!tick.streamValid(&gates));
    gates[0].value = 65534;
    for ([_]u32{ 0, 0x400000, 0xadcc94, 0x11ffffc }) |kind| {
        gates[2].value = kind;
        try std.testing.expect(tick.streamValid(&gates));
    }
    for ([_]u32{ 1, 0x3ffffc, 0xadcc95, 0x1200000, 0xffffffff }) |kind| {
        gates[2].value = kind;
        try std.testing.expect(!tick.streamValid(&gates));
    }
}

test "wire validation: tick groups reject omissions, reordering and clock changes" {
    var oracle = Cursor.init(1);
    defer oracle.finish();
    const groups = [_][]const u32{
        &.{ s.ACTOR_TURN_INPUT, s.ACTOR_TURN_INPUT + 1, s.ACTOR_TURN_INPUT + 2, s.ACTOR_TURN_INPUT + 3, s.ACTOR_TURN_INPUT + 4 },
        &.{ s.RTS_TURN_INPUT, s.RTS_TURN_INPUT + 1, s.RTS_TURN_INPUT + 2, s.RTS_TURN_INPUT + 3 },
        &.{ s.RTS_WAIT_RNG, s.RTS_WAIT_RNG + 1, s.RTS_WAIT_RNG + 2, s.RTS_WAIT_RNG + 3, s.RTS_WAIT_RNG + 4 },
        &.{ s.PACK_MODE_MEMBER, s.PACK_MODE_WITNESS, s.PACK_MODE_VALUE, s.PACK_DEATH_VERTICAL, s.PACK_DEATH_SPEED, s.PACK_DEATH_FLAGS },
        &.{ s.PACK_GOAL_MOVE, s.PACK_GOAL_MOVE + 1, s.PACK_GOAL_MOVE + 2, s.PACK_GOAL_MOVE + 3, s.PACK_GOAL_MOVE + 4, s.PACK_GOAL_MOVE + 5, s.PACK_GOAL_MOVE + 6, s.PACK_GOAL_MOVE + 7, s.PACK_GOAL_MOVE + 8, s.PACK_GOAL_MOVE + 9 },
        &.{ s.PACK_POSE_QUERY, s.PACK_POSE_QUERY + 5, s.PACK_POSE_QUERY + 10, s.PACK_POSE_QUERY + 15, s.PACK_POSE_QUERY + 20 },
        &.{ s.GAME_TIME, 0xfb0fc4, 0xfb0fa8, 0xfb0fb4, 0xfb102c, 0xfb0fb0, 0xfb0fac, 0xfb1028, 0xfb0fa0, 0xfb1014, 0xfb0fc0, 0xfb1070, 0xfb1018, 0xfb101c, 0xfb0fb8, 0xfb0fa4, 0xfb0fbc, 0xfb0fc8 },
        &.{ s.PACK_ANIMATION_MEMBER, s.PACK_ANIMATION_REQUEST, s.PACK_ANIMATION_STATE, s.PACK_ANIMATION_CLOCK, s.PACK_ANIMATION_DELTA },
        &.{ s.PACK_ATTACK, s.PACK_ATTACK_WITNESS },
        &.{ s.FIRE_VISIBILITY, s.FIRE_VISIBILITY_ACTOR },
    };
    for (groups) |sites| {
        var storage: [20]p.SyncTickGate = undefined;
        const gates = storage[0..sites.len];
        for (gates, sites) |*gate, site| gate.* = .{ .site = site, .clock = 17, .value = 1 };
        for (0..gates.len + 1) |len| try sameStream(&oracle, gates[0..len]);
        for (gates, 0..) |*gate, i| {
            const before = gate.*;
            for (values) |value| {
                gate.value = value;
                try sameStream(&oracle, gates);
            }
            gate.* = before;
            gate.clock += 1;
            try sameStream(&oracle, gates);
            gate.* = before;
            gate.site = sites[(i + 1) % sites.len];
            try sameStream(&oracle, gates);
            gate.* = before;
        }
    }
}

fn choice(kind: u32) p.SyncPhysicsChoice {
    var result = std.mem.zeroes(p.SyncPhysicsChoice);
    result.kind = kind;
    return result;
}
fn physicsSeeds() [23]p.SyncPhysicsChoice {
    var result: [23]p.SyncPhysicsChoice = undefined;
    for (&result, 1..) |*entry, kind| {
        entry.* = choice(@intCast(kind));
        const u = &entry.payload;
        switch (kind) {
            1, 2, 3, 16, 17 => {
                entry.site = if (kind == 17) 0x7427d8 else 0x905f38;
                u.basic.flags = 0x40100080;
                u.basic.name_hash[0] = 1;
            },
            4, 5, 6, 18, 23 => {
                entry.site = switch (kind) {
                    4 => 0x86101e,
                    5 => 0x8407d4,
                    6 => 0x84085b,
                    18 => 0x812d7a,
                    else => 0x5525e0,
                };
                u.world.source_name[0] = 1;
                u.world.gizmo_class = 0x8480ac;
                if (kind != 4 and kind != 23) {
                    u.world.receiver_class = 0x820f64;
                    u.world.poi_count = 1;
                    u.world.resource_name[0] = 1;
                    u.world.poi_name[0] = 1;
                }
            },
            7 => {
                entry.site = 0x4da6d0;
                u.module.module_id = 1;
                u.module.module_type = 1;
                u.module.module_class = 0x6e6b3c;
                u.module.burst_max = 1;
            },
            8 => {
                entry.site = 0x4acb53;
                u.gun_jam.module_id = 1;
                u.gun_jam.module_type = 1;
            },
            9 => {
                entry.site = 0x8406b2;
                u.spellit_pose.gizmo_class = 1;
                u.spellit_pose.source_name[0] = 1;
                u.spellit_pose.resource_name[0] = 1;
                u.spellit_pose.poi_name[0] = 1;
            },
            10 => {
                entry.site = 0x86101e;
                u.spellit_step.gizmo_class = 1;
                u.spellit_step.source_name[0] = 1;
            },
            11 => {
                entry.site = 0x8406a7;
                u.spellit_selection.gizmo_class = 1;
                u.spellit_selection.source_name[0] = 1;
                u.spellit_selection.eligibility[0] = 1;
            },
            12, 13, 21, 22 => {
                entry.site = if (kind >= 21) 0x544b10 else 0x840660;
                u.spellit_body.body_class = 1;
                u.spellit_body.key[0] = 1;
            },
            14 => {
                entry.site = 0x997f03;
                u.vehicle_rng.generation = 1;
                u.vehicle_rng.vehicle_type = 4;
            },
            15 => {
                entry.site = 0x905f38;
                u.breakup_basis.name_hash[0] = 1;
            },
            19 => {
                entry.site = 0x55e2c0;
                u.rts_order.order_class = 0x500000;
                u.rts_order.source_key[0] = 1;
            },
            20 => {
                entry.site = 0x547d30;
                u.rts_generator.object_class = 0x500000;
            },
            else => unreachable,
        }
    }
    return result;
}

test "wire validation: physics kinds match the original across every word boundary" {
    var oracle = Cursor.init(2);
    defer oracle.finish();
    for (physicsSeeds()) |seed| {
        try std.testing.expect(oracle.physicsValid(&seed) != 0);
        try std.testing.expect(physics.valid(&seed));
        var actual = seed;
        const bytes = std.mem.asBytes(&actual);
        var offset: usize = 0;
        while (offset < bytes.len) : (offset += 4) {
            for (values) |bits| {
                std.mem.writeInt(u32, bytes[offset..][0..4], bits, .little);
                const expected = oracle.physicsValid(&actual) != 0;
                const valid = physics.valid(&actual);
                const birth_timer = seed.kind == p.SYNC_PHYSICS_EFFECT_BIRTH and offset >= 28 and offset < 40 and std.math.isFinite(@as(f32, @bitCast(bits)));
                try std.testing.expectEqual(expected or birth_timer, valid);
                try std.testing.expectEqual((oracle.physicsSource(&seed, &actual) != 0) or birth_timer, physics.sameSource(&seed, &actual));
                actual = seed;
            }
        }
    }
}

test "wire validation: complete frame headers and event payloads match the original" {
    var oracle = Cursor.init(3);
    defer oracle.finish();
    const f = try std.testing.allocator.create(p.SyncFrame);
    defer std.testing.allocator.destroy(f);
    @memset(std.mem.asBytes(f), 0);
    f.epoch = 1;
    f.sequence = 1;
    f.level = 6;
    for (physicsSeeds()) |seed| {
        f.physics_choice_count = 1;
        f.physics_choices[0] = seed;
        const size = oracle.frameSize(f);
        try std.testing.expect(oracle.frameValid(f, size) != 0);
        try std.testing.expect(frame.valid(f, size));
        const payload = std.mem.asBytes(&f.physics_choices[0]);
        var offset: usize = 0;
        while (offset < payload.len) : (offset += 4) for (values) |bits| {
            std.mem.writeInt(u32, payload[offset..][0..4], bits, .little);
            const birth_timer = seed.kind == p.SYNC_PHYSICS_EFFECT_BIRTH and offset >= 28 and offset < 40 and std.math.isFinite(@as(f32, @bitCast(bits)));
            try std.testing.expectEqual((oracle.frameValid(f, size) != 0) or birth_timer, frame.valid(f, size));
            f.physics_choices[0] = seed;
        };
    }
    f.physics_choice_count = 0;
    const bytes = std.mem.asBytes(f);
    var offset: usize = 0;
    while (offset < @offsetOf(p.SyncFrame, "actors")) : (offset += 4) {
        const original = std.mem.readInt(u32, bytes[offset..][0..4], .little);
        for (values) |bits| {
            std.mem.writeInt(u32, bytes[offset..][0..4], bits, .little);
            const size = oracle.frameSize(f);
            try std.testing.expectEqual(oracle.frameValid(f, size) != 0, frame.valid(f, size));
        }
        std.mem.writeInt(u32, bytes[offset..][0..4], original, .little);
    }
    var encoded: [1024]u8 = undefined;
    var reference: [1024]u8 = undefined;
    const length = sync_frame_encode(f, &encoded, encoded.len);
    const expected_length = oracle.frameEncode(f, &reference, reference.len);
    try std.testing.expectEqual(expected_length, length);
    try std.testing.expectEqualSlices(u8, reference[0..length], encoded[0..length]);
}

test "wire preserves the native Storm over Ryloth wave values only for their exact variables" {
    const f = try std.testing.allocator.create(p.SyncFrame);
    defer std.testing.allocator.destroy(f);
    @memset(std.mem.asBytes(f), 0);
    f.epoch = 1;
    f.sequence = 406;
    f.level = 83;
    f.variable_count = 1;
    const variable = &f.variables[0];
    var bytes: [1024]u8 = undefined;
    var size: u32 = 0;
    for ([_][]const u8{ "WaveADestroyed", "WaveBDestroyed" }) |name| {
        @memcpy(variable.name[0..name.len], name);
        variable.value = @bitCast(@as(u32, 0x7f800000));
        size = sync_frame_encode(f, &bytes, bytes.len);
        try std.testing.expect(size != 0);
        variable.value = 0;
        try std.testing.expectEqual(@as(c_int, 1), sync_frame_decode(f, &bytes, size));
        try std.testing.expectEqual(@as(u32, 0x7f800000), @as(u32, @bitCast(variable.value)));
    }

    f.level = 84;
    try std.testing.expect(!frame.valid(f, size));
    f.level = 83;
    variable.scope = p.SYNC_VARIABLE_AREA;
    try std.testing.expect(!frame.valid(f, size));
    variable.scope = p.SYNC_VARIABLE_GLOBAL;
    variable.name[4] = 'C';
    try std.testing.expect(!frame.valid(f, size));
    variable.name[4] = 'B';
    variable.name[31] = 1;
    try std.testing.expect(!frame.valid(f, size));
    variable.name[31] = 0;
    for ([_]u32{ 0xff800000, 0x7fc00000 }) |bits| {
        variable.value = @bitCast(bits);
        try std.testing.expect(!frame.valid(f, size));
    }
}

test "wire validation: SpellIt admission stages and malformed gate words" {
    var oracle = Cursor.init(4);
    defer oracle.finish();
    const f = try std.testing.allocator.create(p.SyncFrame);
    defer std.testing.allocator.destroy(f);
    @memset(std.mem.asBytes(f), 0);
    f.epoch = 22;
    f.sequence = 50;
    f.level = 64;
    f.fire_task_gate_count = 1;
    for ([_]u16{ 0, 1 }) |stage| for ([_]u16{ 0x24, 0x25 }) |kind| for ([_]i32{ 0, 1 }) |result| {
        var seed = std.mem.zeroes(p.SyncFireTaskGate);
        seed.slot = 7;
        seed.generation = 335;
        seed.character = 184;
        seed.kind = p.SYNC_ACTOR_SPELLIT_ADMISSION;
        seed.flags = stage;
        seed.action = kind;
        seed.value = result;
        seed.payload.state.repeat = 51;
        f.fire_task_gates[0] = seed;
        const size = oracle.frameSize(f);
        try std.testing.expect(oracle.frameValid(f, size) != 0 and frame.valid(f, size));
        const bytes = std.mem.asBytes(&f.fire_task_gates[0]);
        var offset: usize = 0;
        while (offset < bytes.len) : (offset += 4) for (values) |value| {
            std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
            const mutated = f.fire_task_gates[0];
            const outer_stage = mutated.kind == p.SYNC_ACTOR_SPELLIT_ADMISSION and mutated.flags >= 2 and mutated.flags <= 5 and mutated.action == 0;
            // The historical corpus keeps its original bytes; these two flag/action words extend it.
            const reference_valid = oracle.frameValid(f, size) != 0;
            try std.testing.expectEqual(reference_valid or outer_stage, frame.valid(f, size));
            f.fire_task_gates[0] = seed;
        };
        var encoded: [512]u8 = undefined;
        var reference: [512]u8 = undefined;
        const length = sync_frame_encode(f, &encoded, encoded.len);
        try std.testing.expectEqual(oracle.frameEncode(f, &reference, reference.len), length);
        try std.testing.expect(length > 0);
        try std.testing.expectEqualSlices(u8, reference[0..length], encoded[0..length]);
    };
}
