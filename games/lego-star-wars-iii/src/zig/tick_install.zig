const s = @import("tick_state.zig");
const hook = @import("hook_transaction.zig");
const membership = @import("tick_pack_mutation.zig");
extern fn native_pack_remove_observer() void;
extern fn native_pack_construct_observer() void;
extern fn native_pack_destroy_observer() void;
extern fn target_retirement_thunk() void;
extern fn native_global_pack_registry_count() c_uint;
extern fn native_pack_behavior_bridge() void;
extern fn native_gizmo_turret_bridge() void;
extern fn native_weapon_commands_input() void;
extern fn native_tick_first() void;
extern fn native_world_exit() void;
extern fn native_world_continue() void;
extern fn native_flow_request_input() void;
extern fn native_track_clock_input() void;
extern fn native_perception_sweep_input() void;
extern fn native_perception_sweep_early() void;
extern fn reset_native_visibility_cache() void;
extern fn native_rts_registry_input() void;
extern fn native_rts_producer_input() void;
extern fn native_rts_dispatch_observer() void;
extern fn native_rts_pack_gate() void;
extern fn native_rts_turret_heading_input() void;
extern fn native_pack_attack_input() void;
extern fn native_pack_attack_seed_input() void;
extern fn native_pack_mode_input() void;
extern fn native_pack_rearm_seed_input() void;
extern fn native_pack_formation_input() void;
extern fn native_fire_visibility_input() void;
extern fn native_rts_turret_aim_input() void;
extern fn native_pack_animation_input() void;
extern fn native_pack_move_timer_seed_input() void;
extern fn native_pack_move_heading_seed_input() void;
extern fn native_pack_move_choice_seed_input() void;
extern fn native_pack_pose_query_input() void;
extern fn native_pack_pose_commit_input() void;
extern fn native_pack_cell_admission_input() void;
extern fn native_rts_turn_input_bridge() void;
extern fn native_actor_turn_input_bridge() void;
extern fn native_pickup_render_primary_bridge() void;
extern fn native_pack_goal_move_bridge() void;
extern fn native_pack_goal_active_bridge() void;
extern fn native_pack_hit_int_input() void;
extern fn native_pack_hit_float_input() void;
extern fn native_rts_wait_seed_input() void;
extern fn native_pack_spawn_rng_input() void;
extern fn native_pack_spawn_birth_input() void;
pub fn patches() [41]hook.Patch {
    return .{
        .{ .address = s.site.PACK_SPAWN_X, .expected = "\xe8\x5d\xe8\xfe\xff", .target = @intFromPtr(&native_pack_spawn_rng_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_SPAWN_Z, .expected = "\xe8\x41\xe8\xfe\xff", .target = @intFromPtr(&native_pack_spawn_rng_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_SPAWN_BIRTH, .expected = "\xe8\x2e\xfd\xfe\xff", .target = @intFromPtr(&native_pack_spawn_birth_input), .opcode = 0xe8 },
        .{ .address = 0x40ab90, .expected = "\x53\x8b\x5c\x24\x08", .target = @intFromPtr(&native_pack_remove_observer), .opcode = 0xe9 },
        .{ .address = 0x461e50, .expected = "\x6a\xff\x68\x96\xce\xa9\x00", .target = @intFromPtr(&native_pack_construct_observer), .opcode = 0xe9 },
        .{ .address = 0x4620e0, .expected = "\x6a\xff\x68\xd6\xce\xa9\x00", .target = @intFromPtr(&native_pack_destroy_observer), .opcode = 0xe9 },
        .{ .address = 0x562ba7, .expected = "\x83\x7f\x0c\x00\x74\x16", .target = @intFromPtr(&native_rts_dispatch_observer), .opcode = 0xe9 },
        .{ .address = s.site.GIZMO_TURRET_SOURCE, .expected = "\x0f\xb7\x83\xba\x01\x00\x00", .target = @intFromPtr(&native_gizmo_turret_bridge), .opcode = 0xe9 },
        .{ .address = s.site.WEAPON_COMMAND_ACTOR, .expected = "\x80\xbb\xfb\x08\x00\x00\xff", .target = @intFromPtr(&native_weapon_commands_input), .opcode = 0xe9 },
        .{ .address = 0x8888cd, .expected = "\x80\x3d\x61\xc1\xfb\x00\x00", .target = @intFromPtr(&native_tick_first), .opcode = 0xe9 },
        .{ .address = 0x888889, .expected = "\x6a\x0f\x8b\xcf\xe8\x6e\xbf\xf5\xff", .target = @intFromPtr(&native_world_exit), .opcode = 0xe9 },
        .{ .address = 0x888897, .expected = "\xe8\x84\x4b\xcf\xff", .target = @intFromPtr(&native_world_continue), .opcode = 0xe9 },
        .{ .address = 0x889edc, .expected = "\x8b\x46\x60\x3b\xc7", .target = @intFromPtr(&native_flow_request_input), .opcode = 0xe9 },
        .{ .address = 0x7b8b02, .expected = "\x85\xc0\x74\x1e\x8b\xc8\xe8\xc3\x86\xf0\xff", .target = @intFromPtr(&native_track_clock_input), .opcode = 0xe9 },
        .{ .address = 0x9dda14, .expected = "\x83\x7c\x24\x18\x00\x0f\x84\xd3\x04\x00\x00", .target = @intFromPtr(&native_perception_sweep_input), .opcode = 0xe9 },
        .{ .address = 0x9dd0f4, .expected = "\x83\x7c\x24\x18\x00\x0f\x85\x20\x09\x00\x00", .target = @intFromPtr(&native_perception_sweep_early), .opcode = 0xe9 },
        .{ .address = 0x791777, .expected = "\xe8\xe4\x4d\x11\x00", .target = @intFromPtr(&reset_native_visibility_cache), .opcode = 0xe8 },
        .{ .address = s.site.RTS_GAME_RNG, .expected = "\xe8\xd2\x6a\xfb\xff", .target = @intFromPtr(&native_rts_registry_input), .opcode = 0xe8 },
        .{ .address = s.site.RTS_PRODUCER_GAME_RNG, .expected = "\x8b\xbe\xb8\x00\x00\x00", .target = @intFromPtr(&native_rts_producer_input), .opcode = 0xe9 },
        .{ .address = s.site.RTS_PACK_ADMISSION, .expected = "\x3b\xdf\x7d\x26\x84\xc0\x75\x22", .target = @intFromPtr(&native_rts_pack_gate), .opcode = 0xe9 },
        .{ .address = s.site.RTS_TURRET_HEADING, .expected = "\x66\x89\x86\x80\x08\x00\x00", .target = @intFromPtr(&native_rts_turret_heading_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_ATTACK, .expected = "\xf6\xc2\x02\x74\x34\xd8\x1d\x44\xae\xad\x00", .target = @intFromPtr(&native_pack_attack_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_TIMER_MEMBER, .expected = "\xe8\xa7\x5c\x27\x00", .target = @intFromPtr(&native_pack_attack_seed_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_MODE_MEMBER, .expected = "\x0f\xb6\x46\x60\x83\xf8\x1d", .target = @intFromPtr(&native_pack_mode_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_REARM_MEMBER, .expected = "\xe8\xc6\x59\x27\x00", .target = @intFromPtr(&native_pack_rearm_seed_input), .opcode = 0xe8 },
        .{ .address = 0x4604b3, .expected = "\x74\x3f\xd9\x44\x24\x20", .target = @intFromPtr(&native_pack_formation_input), .opcode = 0xe9 },
        .{ .address = s.site.FIRE_VISIBILITY, .expected = "\xe8\x78\x8a\xb8\xff", .target = @intFromPtr(&native_fire_visibility_input), .opcode = 0xe8 },
        .{ .address = s.site.RTS_TURRET_AIM, .expected = "\x8d\x86\xa0\x08\x00\x00", .target = @intFromPtr(&native_rts_turret_aim_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_ANIMATION_MEMBER, .expected = "\x51\x8b\x44\x24\x0c\x56", .target = @intFromPtr(&native_pack_animation_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_MOVE_TIMER, .expected = "\xe8\xbe\x63\x27\x00", .target = @intFromPtr(&native_pack_move_timer_seed_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_MOVE_HEADING, .expected = "\xe8\xb1\x63\x27\x00", .target = @intFromPtr(&native_pack_move_heading_seed_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_MOVE_CHOICE, .expected = "\xe8\x23\x5f\x27\x00", .target = @intFromPtr(&native_pack_move_choice_seed_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_POSE_QUERY, .expected = "\xe8\x5c\x4f\xfb\xff", .target = @intFromPtr(&native_pack_pose_query_input), .opcode = 0xe8 },
        .{ .address = s.site.PACK_POSE_COMMIT, .expected = "\x8b\x41\x38\x8b\x54\x24\x04", .target = @intFromPtr(&native_pack_pose_commit_input), .opcode = 0xe9 },
        .{ .address = s.site.PACK_CELL_MEMBER, .expected = "\xf6\xc3\x60\x75\x20", .target = @intFromPtr(&native_pack_cell_admission_input), .opcode = 0xe9 },
        .{ .address = s.site.RTS_TURN_INPUT, .expected = "\x8b\xf8\x8b\x03\x8b\x90\x60\x01\x00\x00", .target = @intFromPtr(&native_rts_turn_input_bridge), .opcode = 0xe9 },
        .{ .address = s.site.ACTOR_TURN_INPUT, .expected = "\x0f\xb7\xf8\x66\x8b\xcf\x66\x2b\x0b", .target = @intFromPtr(&native_actor_turn_input_bridge), .opcode = 0xe9 },
        .{ .address = 0x806373, .expected = "\x8a\x1d\x1d\x0b\xfb\x00", .target = @intFromPtr(&native_pickup_render_primary_bridge), .opcode = 0xe9 },
        .{ .address = s.site.PACK_GOAL_MOVE, .expected = "\xd9\x44\x24\x40\xd8\x27", .target = @intFromPtr(&native_pack_goal_move_bridge), .opcode = 0xe9 },
        .{ .address = s.site.PACK_GOAL_ACTIVE, .expected = "\xd9\x44\x24\x60\xd8\x23", .target = @intFromPtr(&native_pack_goal_active_bridge), .opcode = 0xe9 },
        .{ .address = s.site.PACK_BEHAVIOR, .expected = "\x8b\x8e\x50\x01\x00\x00", .target = @intFromPtr(&native_pack_behavior_bridge), .opcode = 0xe9 },
    };
}
pub const hit_rng = [_][2]u32{ .{ s.site.PACK_HIT_REACTION, 0x6d6140 }, .{ s.site.PACK_HIT_AVOIDANCE, 0x6d6140 }, .{ s.site.PACK_HIT_DEBRIS, 0x6d6140 }, .{ s.site.PACK_HIT_SHOCK, 0x6d6140 }, .{ s.site.PACK_HIT_HEADING, 0x6d6140 }, .{ s.site.PACK_IMPULSE_TIMER, 0x6d60d0 }, .{ s.site.PACK_IMPULSE_SPEED, 0x6d60d0 }, .{ s.site.PACK_IMPULSE_HEADING, 0x6d6140 }, .{ s.site.PACK_DEATH_CLIP, 0x6d60d0 }, .{ s.site.PACK_MODE10_DURATION, 0x6d60d0 }, .{ s.site.PACK_MODE10_CLIP_PHASE, 0x6d60d0 }, .{ s.site.RTS_WAIT_RNG, 0x573100 } };
pub export fn native_tick_install() c_int {
    const exit = [_]u8{ 0x5f, 0x5e, 0x5d, 0x5b, 0x83, 0xc4, 8, 0xc2, 8, 0 };
    if (!s.readable(0x475acb, exit.len) or !@import("std").mem.eql(u8, &s.load([10]u8, 0x475acb), &exit)) return 0;
    if (native_global_pack_registry_count() == 0) return 0;
    var expected: [hit_rng.len][5]u8 = undefined;
    var all: [42 + hit_rng.len]hook.Patch = undefined;
    all[0..41].* = patches();
    for (hit_rng, &expected, all[41..][0..hit_rng.len]) |source, *bytes, *patch| {
        bytes[0] = 0xe8;
        @import("std").mem.writeInt(u32, bytes[1..5], source[1] -% source[0] -% 5, .little);
        patch.* = .{ .address = source[0], .expected = bytes, .target = if (source[1] == 0x573100) @intFromPtr(&native_rts_wait_seed_input) else if (source[1] == 0x6d6140) @intFromPtr(&native_pack_hit_int_input) else @intFromPtr(&native_pack_hit_float_input), .opcode = 0xe8 };
    }
    all[all.len - 1] = .{ .address = 0x8766a5, .expected = "\x83\xc4\x08\xe8\x83\xb2\xf1\xff", .target = @intFromPtr(&target_retirement_thunk), .opcode = 0xe9 };
    if (!hook.apply(&all)) return 0;
    @atomicStore(u32, &membership.clonewars_pack_membership_observer_active, 1, .release);
    return 1;
}
comptime {
    _ = @import("pack_spawn_bridge.zig");
    _ = @import("tick_pack_spawn.zig");
    _ = @import("tick_pack_behavior.zig");
    _ = @import("tick_resume.zig");
    _ = @import("tick_bridges.zig");
}
