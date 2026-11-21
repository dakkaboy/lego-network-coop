const std = @import("std");
const s = @import("cadence_state.zig");
const hooks = @import("hook_transaction.zig");
extern fn native_script_shoot_dispatch_install() c_int;
pub export var character_velocity_native: usize = 0xa08380;
pub export var cadence_resume: usize = 0x96d954;
pub export var fire_task_gate_allow: usize = 0x42fe42;
pub export var fire_task_gate_skip: usize = 0x42fff6;
pub export var attack_support_resume: usize = 0x8789f7;
pub export var breakup_visible_resume: usize = 0x968a9c;
pub export var breakup_hidden_resume: usize = 0x968d4b;
pub export var death_breakup_resume: usize = 0x968f1c;
pub export var fall_visible_resume: usize = 0x9c49b9;
pub export var fall_hidden_resume: usize = 0x9c4a09;
pub export var aim_task_input_resume: usize = 0x899f3c;
pub export var aim_task_visible_resume: usize = 0x89a09d;
pub export var aim_task_hidden_resume: usize = 0x89a179;
pub export var rts_competitor_input_resume: usize = 0x541186;
pub export var aim_base_input_resume: usize = 0x899ed8;
pub export var force_target_visible_resume: usize = 0x7f8181;
pub export var force_target_hidden_resume: usize = 0x7f83b1;
pub export var force_distance_native: usize = 0x574ec0;
pub export var spellit_prepare_resume: usize = 0x7da946;
pub export var spellit_first_heading_resume: usize = 0x7da950;
pub export var spellit_second_heading_resume: usize = 0x7da96f;
pub export var spellit_height_resume: usize = 0x7daa83;
pub export var spellit_distance_native: usize = 0x574f60;
pub export var spellit_node_resume: usize = 0x7daa71;
pub export var script_shoot_visible_resume: usize = 0x963cb4;
pub export var script_shoot_hidden_resume: usize = 0x963cab;
pub export var primary_perception_resume: usize = 0x9ddc1f;
pub export var spellit_admission_state_continue: usize = 0x857eca;
pub export var spellit_admission_state_skip: usize = 0x857f84;
pub export var spellit_admission_hint_continue: usize = 0x857ede;
pub export var spellit_admission_hint_skip: usize = 0x857f52;
extern fn spellit_admission_state_thunk() void;
extern fn spellit_admission_hint_thunk() void;
extern fn cadence_period_thunk() void;
extern fn fire_task_gate_thunk() void;
extern fn attack_support_thunk() void;
extern fn breakup_visibility_thunk() void;
extern fn death_breakup_thunk() void;
extern fn fall_visibility_thunk() void;
extern fn aim_task_input_thunk() void;
extern fn aim_task_visibility_thunk() void;
extern fn rts_competitor_input_thunk() void;
extern fn force_target_visibility_thunk() void;
extern fn primary_perception_thunk() void;
extern fn aim_base_input_thunk() void;
extern fn script_shoot_visibility_thunk() void;
extern fn spellit_prepare_thunk() void;
extern fn spellit_first_heading_thunk() void;
extern fn spellit_second_heading_thunk() void;
extern fn spellit_height_thunk() void;
extern fn spellit_node_thunk() void;
extern fn force_geometry_input_thunk() void;
extern fn spellit_position_thunk() void;
extern fn character_motion_thunk() void;
extern fn spellit_actor_eligible(usize) u32;
extern fn spellit_action_matches(usize, i32) u32;
pub export var spellit_manager_force_resume: usize = 0x857e16;
pub export var spellit_manager_special_resume: usize = 0x857e29;
extern fn spellit_manager_force_thunk() void;
extern fn spellit_manager_special_thunk() void;
pub export var hazard_death_continue: usize = 0x437e4a;
pub export var hazard_death_skip: usize = 0x437e73;
extern fn hazard_death_thunk() void;
pub export var rider_fire_visible_resume: usize = 0x4395fb;
pub export var rider_fire_hidden_resume: usize = 0x4397ef;
extern fn rider_fire_visibility_thunk() void;
extern fn arena_run_random_thunk() void;
extern fn zillo_support_throw_thunk() void;
pub fn patches() [39]hooks.Patch {
    return [_]hooks.Patch{
        .{ .address = 0x99a39b, .expected = "\x33\x8a\x68\x02\x00\x00", .target = @intFromPtr(&@import("barc_suspension.zig").barc_suspension_thunk) },
        .{ .address = 0x9977c9, .expected = "\xe8\xc2\x4a\xff\xff", .target = @intFromPtr(&@import("barc_alignment.zig").barc_alignment_thunk), .opcode = 0xe8 },
        .{ .address = 0x464b3f, .expected = "\xe8\x0c\x99\x32\x00", .target = @intFromPtr(&arena_run_random_thunk), .opcode = 0xe8 },
        .{ .address = 0x464b6c, .expected = "\xe8\xdf\x98\x32\x00", .target = @intFromPtr(&arena_run_random_thunk), .opcode = 0xe8 },
        .{ .address = 0x449313, .expected = "\xe8\x58\x2d\x10\x00", .target = @intFromPtr(&zillo_support_throw_thunk), .opcode = 0xe8 },
        .{ .address = 0x670def, .expected = "\xe8\x5c\xf2\xff\xff", .target = @intFromPtr(&@import("zillo_support_hooks.zig").zillo_support_register_thunk), .opcode = 0xe8 },
        .{ .address = 0x4395f1, .expected = "\x80\x78\x42\x00\x0f\x84\xf4\x01\x00\x00", .target = @intFromPtr(&rider_fire_visibility_thunk) },
        .{ .address = 0x857e10, .expected = "\x8b\x42\x64\x57\xff\xd0", .target = @intFromPtr(&spellit_manager_force_thunk) },
        .{ .address = 0x857e23, .expected = "\x57\x0f\x95\xc3\xff\xd0", .target = @intFromPtr(&spellit_manager_special_thunk) },
        .{ .address = 0x857e5a, .expected = "\xe8\xb1\xa7\x06\x00", .target = @intFromPtr(&spellit_actor_eligible), .opcode = 0xe8 },
        .{ .address = 0x857e6e, .expected = "\xe8\xdd\xf7\x19\x00", .target = @intFromPtr(&spellit_action_matches), .opcode = 0xe8 },
        .{ .address = 0x437e45, .expected = "\xf6\xc4\x41\x75\x29", .target = @intFromPtr(&hazard_death_thunk) },
        .{ .address = 0x96d94a, .expected = "\x8b\x4c\x24\x14\x88\x8f\x8e\x13\x00\x00", .target = @intFromPtr(&cadence_period_thunk) },
        .{ .address = 0x42fe2b, .expected = "\x8b\x43\x08\x85\xc0\x74\x06\x80\x78\x42\x00\x75\x0a\xf6\x46\x04\x08\x0f\x84\xb4\x01\x00\x00", .target = @intFromPtr(&fire_task_gate_thunk) },
        .{ .address = 0x8789f0, .expected = "\x8b\x74\x24\x54\x8b\x4d\x24", .target = @intFromPtr(&attack_support_thunk) },
        .{ .address = 0x968a94, .expected = "\x84\xdb\x0f\x85\xaf\x02\x00\x00", .target = @intFromPtr(&breakup_visibility_thunk) },
        .{ .address = 0x991d01, .expected = "\x80\xb8\xde\x0d\x00\x00\x00\x0f\x8f\xab\x02\x00\x00", .target = @intFromPtr(&@import("ryloth_fighter_death.zig").ryloth_fighter_death_thunk) },
        .{ .address = 0x968f14, .expected = "\x83\xbc\x24\xa0\x00\x00\x00\x00", .target = @intFromPtr(&death_breakup_thunk) },
        .{ .address = 0x9c49b3, .expected = "\x80\x7a\x42\x00\x74\x50", .target = @intFromPtr(&fall_visibility_thunk) },
        .{ .address = 0x899f37, .expected = "\x8b\x4f\x10\x85\xc9", .target = @intFromPtr(&aim_task_input_thunk) },
        .{ .address = 0x899f31, .expected = "\x0f\x84\x42\x02\x00\x00", .target = @intFromPtr(&@import("hidden_enemy_aim.zig").hidden_enemy_aim_thunk) },
        .{ .address = 0x89a093, .expected = "\x80\x78\x42\x00\x0f\x84\xdc\x00\x00\x00", .target = @intFromPtr(&aim_task_visibility_thunk) },
        .{ .address = 0x541180, .expected = "\x55\x8b\xec\x83\xe4\xf0", .target = @intFromPtr(&rts_competitor_input_thunk) },
        .{ .address = 0x7f8177, .expected = "\x80\x78\x42\x00\x0f\x84\x30\x02\x00\x00", .target = @intFromPtr(&force_target_visibility_thunk) },
        .{ .address = 0x9ddc19, .expected = "\x8b\x86\x64\x01\x00\x00", .target = @intFromPtr(&primary_perception_thunk) },
        .{ .address = 0x899ed0, .expected = "\xd9\x44\x24\x14\x8b\x44\x24\x0c", .target = @intFromPtr(&aim_base_input_thunk) },
        .{ .address = 0x963ca5, .expected = "\x80\x78\x42\x00\x75\x09", .target = @intFromPtr(&script_shoot_visibility_thunk) },
        .{ .address = 0x7da941, .expected = "\x8b\x46\x08\x85\xc0", .target = @intFromPtr(&spellit_prepare_thunk) },
        .{ .address = 0x7da948, .expected = "\x0f\xb7\x40\x40\xeb\x02", .target = @intFromPtr(&spellit_first_heading_thunk) },
        .{ .address = 0x7da967, .expected = "\x0f\xb7\x46\x40\xeb\x02", .target = @intFromPtr(&spellit_second_heading_thunk) },
        .{ .address = 0x7daa7c, .expected = "\xd9\x40\x28\x89\x4c\x24\x2c", .target = @intFromPtr(&spellit_height_thunk) },
        .{ .address = 0x7daa69, .expected = "\x8b\x44\x24\x70\x8b\x4c\x24\x74", .target = @intFromPtr(&spellit_node_thunk) },
        .{ .address = 0x7f8310, .expected = "\xe8\xab\xcb\xd7\xff", .target = @intFromPtr(&force_geometry_input_thunk), .opcode = 0xe8 },
        .{ .address = 0x7daaeb, .expected = "\xe8\x70\xa4\xd9\xff", .target = @intFromPtr(&spellit_position_thunk), .opcode = 0xe8 },
        .{ .address = 0x9c43d1, .expected = "\xe8\xaa\x3f\x04\x00", .target = @intFromPtr(&character_motion_thunk), .opcode = 0xe8 },
        .{ .address = 0x857ec2, .expected = "\x85\xc0\x0f\x85\xba\x00\x00\x00", .target = @intFromPtr(&spellit_admission_state_thunk) },
        .{ .address = 0x857ed4, .expected = "\x85\xc0\x74\x7a\x8b\x86\x00\x04\x00\x00", .target = @intFromPtr(&spellit_admission_hint_thunk) },
    } ++ @import("zillo_island_order.zig").patches();
}
pub fn install() c_int {
    if (s.clonewars_cadence_installed == 1) return 1;
    s.clonewars_cadence_installed = -1;
    const patch_set = patches();
    for (patch_set) |patch| if (!s.valid(patch.address, patch.expected.len) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected)) return 0;
    if (native_script_shoot_dispatch_install() == 0 or !hooks.apply(&patch_set)) return 0;
    s.clonewars_cadence_installed = 1;
    return 1;
}
comptime {
    _ = @import("arena_run_random.zig");
    _ = @import("spellit_eligibility.zig");
    _ = @import("rider_fire_input.zig");
    asm (@import("rider_fire_bridge.zig").code);
    asm (@import("hazard_death_bridge.zig").code);
    _ = @import("cadence_bridges.zig");
    asm (@import("spellit_admission_bridge.zig").code(0));
    asm (@import("spellit_admission_bridge.zig").code(1));
    asm (@import("spellit_admission_bridge.zig").managerCode(false));
    asm (@import("spellit_admission_bridge.zig").managerCode(true));
}
