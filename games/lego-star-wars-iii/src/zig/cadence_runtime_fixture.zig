const std = @import("std");
const s = @import("cadence_state.zig");
pub const Diagnostics = extern struct {
    clonewars_character_motion_debug: [4]u32,
    clonewars_character_motion_correction: [16]u32,
    clonewars_character_support_debug: [8]u32,
    clonewars_character_motion_failure: [40]u32,
    clonewars_character_support_local: [10]u32,
    clonewars_character_support_host: [10]u32,
    clonewars_aim_base_debug: [4]u32,
    clonewars_aim_base_correction: [12]u32,
    clonewars_actor_gate_failure: [16]u32,
    clonewars_force_target_debug: [4]u32,
    clonewars_force_target_correction: [10]u32,
    clonewars_force_geometry_debug: [4]u32,
    clonewars_force_geometry_correction: [20]u32,
    clonewars_spellit_query_debug: [4]u32,
    clonewars_spellit_query_correction: [20]u32,
    clonewars_spellit_node_debug: [4]u32,
    clonewars_spellit_node_correction: [24]u32,
    clonewars_spellit_node_failure: [16]u32,
    clonewars_script_shoot_debug: [4]u32,
    clonewars_script_shoot_correction: [12]u32,
    clonewars_script_shoot_failure: [16]u32,
    clonewars_rts_competitor_debug: [8]u32,
    clonewars_rts_competitor_correction: [10]u32,
    clonewars_cadence_installed: [1]u32,
    clonewars_cadence_debug: [20]u32,
    clonewars_cadence_failure: [14]u32,
    clonewars_fire_task_gate_debug: [4]u32,
    clonewars_attack_support_debug: [4]u32,
    clonewars_breakup_visibility_debug: [4]u32,
    clonewars_breakup_visibility_correction: [8]u32,
    clonewars_death_breakup_debug: [4]u32,
    clonewars_death_breakup_correction: [8]u32,
    clonewars_fall_visibility_debug: [4]u32,
    clonewars_fall_visibility_correction: [8]u32,
    clonewars_aim_task_debug: [4]u32,
    clonewars_aim_task_correction: [12]u32,
    clonewars_primary_perception_debug: [4]u32,
};
pub fn clear() void {
    s.clonewars_character_motion_debug = @splat(0);
    s.clonewars_character_motion_correction = @splat(0);
    s.clonewars_character_support_debug = @splat(0);
    s.clonewars_character_motion_failure = @splat(0);
    s.clonewars_character_support_local = @splat(0);
    s.clonewars_character_support_host = @splat(0);
    s.clonewars_aim_base_debug = @splat(0);
    s.clonewars_aim_base_correction = @splat(0);
    s.clonewars_actor_gate_failure = @splat(0);
    s.clonewars_force_target_debug = @splat(0);
    s.clonewars_force_target_correction = @splat(0);
    s.clonewars_force_geometry_debug = @splat(0);
    s.clonewars_force_geometry_correction = @splat(0);
    s.clonewars_spellit_query_debug = @splat(0);
    s.clonewars_spellit_query_correction = @splat(0);
    s.clonewars_spellit_node_debug = @splat(0);
    s.clonewars_spellit_node_correction = @splat(0);
    s.clonewars_spellit_node_failure = @splat(0);
    s.clonewars_script_shoot_debug = @splat(0);
    s.clonewars_script_shoot_correction = @splat(0);
    s.clonewars_script_shoot_failure = @splat(0);
    s.clonewars_rts_competitor_debug = @splat(0);
    s.clonewars_rts_competitor_correction = @splat(0);
    s.clonewars_cadence_installed = 0;
    s.clonewars_cadence_debug = @splat(0);
    s.clonewars_cadence_failure = @splat(0);
    s.clonewars_fire_task_gate_debug = @splat(0);
    s.clonewars_attack_support_debug = @splat(0);
    s.clonewars_breakup_visibility_debug = @splat(0);
    s.clonewars_breakup_visibility_correction = @splat(0);
    s.clonewars_death_breakup_debug = @splat(0);
    s.clonewars_death_breakup_correction = @splat(0);
    s.clonewars_fall_visibility_debug = @splat(0);
    s.clonewars_fall_visibility_correction = @splat(0);
    s.clonewars_aim_task_debug = @splat(0);
    s.clonewars_aim_task_correction = @splat(0);
    s.clonewars_primary_perception_debug = @splat(0);
}
pub fn capture() Diagnostics {
    var out: Diagnostics = undefined;
    out.clonewars_character_motion_debug = s.clonewars_character_motion_debug;
    out.clonewars_character_motion_correction = s.clonewars_character_motion_correction;
    out.clonewars_character_support_debug = s.clonewars_character_support_debug;
    out.clonewars_character_motion_failure = s.clonewars_character_motion_failure;
    out.clonewars_character_support_local = s.clonewars_character_support_local;
    out.clonewars_character_support_host = s.clonewars_character_support_host;
    out.clonewars_aim_base_debug = s.clonewars_aim_base_debug;
    out.clonewars_aim_base_correction = s.clonewars_aim_base_correction;
    out.clonewars_actor_gate_failure = s.clonewars_actor_gate_failure;
    out.clonewars_force_target_debug = s.clonewars_force_target_debug;
    out.clonewars_force_target_correction = s.clonewars_force_target_correction;
    out.clonewars_force_geometry_debug = s.clonewars_force_geometry_debug;
    out.clonewars_force_geometry_correction = s.clonewars_force_geometry_correction;
    out.clonewars_spellit_query_debug = s.clonewars_spellit_query_debug;
    out.clonewars_spellit_query_correction = s.clonewars_spellit_query_correction;
    out.clonewars_spellit_node_debug = s.clonewars_spellit_node_debug;
    out.clonewars_spellit_node_correction = s.clonewars_spellit_node_correction;
    out.clonewars_spellit_node_failure = s.clonewars_spellit_node_failure;
    out.clonewars_script_shoot_debug = s.clonewars_script_shoot_debug;
    out.clonewars_script_shoot_correction = s.clonewars_script_shoot_correction;
    out.clonewars_script_shoot_failure = s.clonewars_script_shoot_failure;
    out.clonewars_rts_competitor_debug = s.clonewars_rts_competitor_debug;
    out.clonewars_rts_competitor_correction = s.clonewars_rts_competitor_correction;
    out.clonewars_cadence_installed = .{@bitCast(s.clonewars_cadence_installed)};
    out.clonewars_cadence_debug = s.clonewars_cadence_debug;
    out.clonewars_cadence_failure = s.clonewars_cadence_failure;
    out.clonewars_fire_task_gate_debug = s.clonewars_fire_task_gate_debug;
    out.clonewars_attack_support_debug = s.clonewars_attack_support_debug;
    out.clonewars_breakup_visibility_debug = s.clonewars_breakup_visibility_debug;
    out.clonewars_breakup_visibility_correction = s.clonewars_breakup_visibility_correction;
    out.clonewars_death_breakup_debug = s.clonewars_death_breakup_debug;
    out.clonewars_death_breakup_correction = s.clonewars_death_breakup_correction;
    out.clonewars_fall_visibility_debug = s.clonewars_fall_visibility_debug;
    out.clonewars_fall_visibility_correction = s.clonewars_fall_visibility_correction;
    out.clonewars_aim_task_debug = s.clonewars_aim_task_debug;
    out.clonewars_aim_task_correction = s.clonewars_aim_task_correction;
    out.clonewars_primary_perception_debug = s.clonewars_primary_perception_debug;
    return out;
}
comptime {
    asm (
        \\.text
        \\_invoke_period:
        \\pushl %edi
        \\subl $32,%esp
        \\movl _cadence_fixture_actor,%edi
        \\movl _cadence_fixture_value,%eax
        \\movl %eax,16(%esp)
        \\call *_cadence_fixture_entry
        \\movl 16(%esp),%eax
        \\movl %eax,_cadence_fixture_value
        \\addl $32,%esp
        \\popl %edi
        \\ret
        \\_invoke_fire:
        \\pushl %ebp
        \\pushl %ebx
        \\pushl %esi
        \\movl _cadence_fixture_frame,%ebp
        \\movl _cadence_fixture_actor,%ebx
        \\movl _cadence_fixture_task,%esi
        \\call *_cadence_fixture_entry
        \\popl %esi
        \\popl %ebx
        \\popl %ebp
        \\ret
        \\_invoke_support:
        \\pushl %ebp
        \\pushl %ebx
        \\pushl %esi
        \\subl $112,%esp
        \\movl _cadence_fixture_frame,%ebp
        \\movl _cadence_fixture_actor,%ebx
        \\movl _cadence_fixture_value,%eax
        \\movl %eax,80(%esp)
        \\call *_cadence_fixture_entry
        \\movl %esi,_cadence_fixture_value
        \\addl $112,%esp
        \\popl %esi
        \\popl %ebx
        \\popl %ebp
        \\ret
        \\_invoke_perception:
        \\pushl %esi
        \\movl _cadence_fixture_actor,%esi
        \\call *_cadence_fixture_entry
        \\popl %esi
        \\ret
        \\_allow_cont:
        \\movl $1,_cadence_fixture_branch
        \\ret
        \\_skip_cont:
        \\movl $0,_cadence_fixture_branch
        \\ret
    );
}
