const std = @import("std");
pub const names = [_][]const u8{ "native_rts_dispatch_observer", "native_world_exit", "native_world_continue", "native_pickup_render_primary_bridge", "native_actor_turn_input_bridge", "native_rts_turn_input_bridge", "native_pack_attack_input", "native_rts_turret_heading_input", "native_pack_hit_int_input", "native_pack_hit_float_input", "native_rts_registry_input", "native_rts_producer_input", "native_rts_wait_seed_input", "native_pack_attack_seed_input", "native_pack_rearm_seed_input", "native_pack_move_timer_seed_input", "native_pack_move_heading_seed_input", "native_pack_move_choice_seed_input", "native_pack_pose_query_input", "native_pack_pose_commit_input", "native_pack_cell_admission_input", "native_pack_goal_move_bridge", "native_pack_goal_active_bridge", "native_pack_formation_input", "native_pack_animation_input", "native_rts_turret_aim_input", "native_gizmo_turret_bridge", "native_weapon_commands_input", "native_fire_visibility_input", "native_pack_mode_input", "native_rts_pack_gate", "native_flow_request_input", "native_track_clock_input", "native_perception_sweep_input", "native_perception_sweep_early", "native_tick_first" };
pub fn code(comptime name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "native_rts_dispatch_observer")) return
    \\.text
    \\.globl _native_rts_dispatch_observer
    \\_native_rts_dispatch_observer:
    \\    pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $4,%esp
    \\    pushl 52(%eax)
    \\    pushl 0(%eax)
    \\    pushl 4(%eax)
    \\    call _native_rts_dispatch_observe
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    cmpl $0,0xc(%edi)
    \\    je 1f
    \\    jmp *_rts_dispatch_blocked
    \\1:  jmp *_rts_dispatch_continue
    ;
    if (std.mem.eql(u8, name, "native_world_exit")) return
    \\.text
    \\.globl _native_world_exit
    \\_native_world_exit:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl $1
    \\    pushl $0x888889
    \\    call _native_tick_decision
    \\    addl $16,%esp
    \\    movl %eax,528(%esp)
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%edx
    \\    cmpl $0,528(%esp)
    \\    je 1f
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    pushl $0xf
    \\    movl %edi,%ecx
    \\    call *_world_transition
    \\    jmp *_world_exit_resume
    \\    1: movl %edx,%esp
    \\    popal
    \\    popfl
    \\    call *_world_continue
    \\    jmp *_world_continue_resume
    \\    
    ;
    if (std.mem.eql(u8, name, "native_world_continue")) return
    \\.text
    \\.globl _native_world_continue
    \\_native_world_continue:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl $0
    \\    pushl $0x888889
    \\    call _native_tick_decision
    \\    addl $16,%esp
    \\    movl %eax,528(%esp)
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%edx
    \\    cmpl $0,528(%esp)
    \\    je 1f
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    pushl $0xf
    \\    movl %edi,%ecx
    \\    call *_world_transition
    \\    jmp *_world_exit_resume
    \\    1: movl %edx,%esp
    \\    popal
    \\    popfl
    \\    call *_world_continue
    \\    jmp *_world_continue_resume
    \\    
    ;
    if (std.mem.eql(u8, name, "native_pickup_render_primary_bridge")) return
    \\.text
    \\.globl _native_pickup_render_primary_bridge
    \\_native_pickup_render_primary_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    movzbl 0xfb0b1d,%ecx
    \\    subl $8,%esp
    \\    pushl %ecx
    \\    pushl (%eax)
    \\    call _native_pickup_render_primary
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movb %al,16(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    jmp *_pickup_render_resume
    ;
    if (std.mem.eql(u8, name, "native_actor_turn_input_bridge")) return
    \\.text
    \\.globl _native_actor_turn_input_bridge
    \\_native_actor_turn_input_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $4,%esp
    \\    pushl 16(%eax)
    \\    pushl 28(%eax)
    \\    pushl 4(%eax)
    \\    call _native_actor_turn_input
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    movzwl %ax,%edi
    \\    movw %di,%cx
    \\    subw (%ebx),%cx
    \\    jmp *_actor_turn_resume
    ;
    if (std.mem.eql(u8, name, "native_rts_turn_input_bridge")) return
    \\.text
    \\.globl _native_rts_turn_input_bridge
    \\_native_rts_turn_input_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    leal 64(%eax),%edx
    \\    subl $4,%esp
    \\    pushl %edx
    \\    pushl 28(%eax)
    \\    pushl 16(%eax)
    \\    call _native_rts_turn_input
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    movl %eax,%edi
    \\    movl (%ebx),%eax
    \\    movl 0x160(%eax),%edx
    \\    jmp *_rts_turn_resume
    ;
    if (std.mem.eql(u8, name, "native_pack_attack_input")) return
    \\.text
    \\.globl _native_pack_attack_input
    \\_native_pack_attack_input:
    \\testb $2,%dl
    \\    jz 1f
    \\    fcomps 0xadae44
    \\    fnstsw %ax
    \\    testb $5,%ah
    \\    jp 2f
    \\    leal 0x16c(%edi),%eax
    \\    movl $0x2d8,%ecx
    \\    cmpw %cx,%ax
    \\    ja 2f
    \\    pushfl
    \\    pushal
    \\    xorl %ecx,%ecx
    \\    testb $8,%dl
    \\    setne %cl
    \\    incl %ecx
    \\    jmp 3f
    \\    1: fstp %st(0)
    \\    2: pushfl
    \\    pushal
    \\    xorl %ecx,%ecx
    \\    3: movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl %ecx
    \\    pushl 4(%eax)
    \\    call _native_pack_attack
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 4f
    \\    cmpl $2,%eax
    \\    je 5f
    \\    andl $-9,20(%esp)
    \\    jmp 6f
    \\    5: orl $8,20(%esp)
    \\    6: movl (%esp),%eax
    \\    addl $0x16c,%eax
    \\    movl %eax,28(%esp)
    \\    movl $0x2d8,24(%esp)
    \\    popal
    \\    popfl
    \\    jmp *_pack_attack_arrived
    \\    4: popal
    \\    popfl
    \\    jmp *_pack_attack_continue
    ;
    if (std.mem.eql(u8, name, "native_rts_turret_heading_input")) return
    \\.text
    \\.globl _native_rts_turret_heading_input
    \\_native_rts_turret_heading_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl 28(%eax)
    \\    pushl 4(%eax)
    \\    call _native_rts_turret_heading
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    movw %ax,0x880(%esi)
    \\    jmp *_rts_turret_heading_resume
    ;
    if (std.mem.eql(u8, name, "native_pack_hit_int_input")) return
    \\.text
    \\.globl _native_pack_hit_int_input
    \\_native_pack_hit_int_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    movl 36(%eax),%edx
    \\    subl $5,%edx
    \\    leal 36(%eax),%ecx
    \\    subl $4,%esp
    \\    pushl %ecx
    \\    pushl %edx
    \\    pushl 4(%eax)
    \\    call _native_pack_hit_seed_bridge
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_move_random_integer
    ;
    if (std.mem.eql(u8, name, "native_pack_hit_float_input")) return
    \\.text
    \\.globl _native_pack_hit_float_input
    \\_native_pack_hit_float_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    movl 36(%eax),%edx
    \\    subl $5,%edx
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl 4(%eax)
    \\    call _native_pack_hit_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_attack_random
    ;
    if (std.mem.eql(u8, name, "native_rts_registry_input")) return
    \\.text
    \\.globl _native_rts_registry_input
    \\_native_rts_registry_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 24(%eax)
    \\    call _native_rts_registry_rng
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_rts_registry_update
    ;
    if (std.mem.eql(u8, name, "native_rts_producer_input")) return
    \\.text
    \\.globl _native_rts_producer_input
    \\_native_rts_producer_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_rts_producer_rng
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0xb8(%esi),%edi
    \\    jmp *_rts_producer_resume
    ;
    if (std.mem.eql(u8, name, "native_rts_wait_seed_input")) return
    \\.text
    \\.globl _native_rts_wait_seed_input
    \\_native_rts_wait_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_rts_wait_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_rts_wait_random
    ;
    if (std.mem.eql(u8, name, "native_pack_attack_seed_input")) return
    \\.text
    \\.globl _native_pack_attack_seed_input
    \\_native_pack_attack_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_pack_attack_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_attack_random
    ;
    if (std.mem.eql(u8, name, "native_pack_rearm_seed_input")) return
    \\.text
    \\.globl _native_pack_rearm_seed_input
    \\_native_pack_rearm_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_pack_rearm_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_attack_random
    ;
    if (std.mem.eql(u8, name, "native_pack_move_timer_seed_input")) return
    \\.text
    \\.globl _native_pack_move_timer_seed_input
    \\_native_pack_move_timer_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_pack_move_timer_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_attack_random
    ;
    if (std.mem.eql(u8, name, "native_pack_move_heading_seed_input")) return
    \\.text
    \\.globl _native_pack_move_heading_seed_input
    \\_native_pack_move_heading_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_pack_move_heading_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_move_random_integer
    ;
    if (std.mem.eql(u8, name, "native_pack_move_choice_seed_input")) return
    \\.text
    \\.globl _native_pack_move_choice_seed_input
    \\_native_pack_move_choice_seed_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_pack_move_choice_seed
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_move_random_integer
    ;
    if (std.mem.eql(u8, name, "native_pack_pose_query_input")) return
    \\.text
    \\.globl _native_pack_pose_query_input
    \\_native_pack_pose_query_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    movl 12(%eax),%edx
    \\    cmpl $0x433971,4(%edx)
    \\    jne 1f
    \\    call _native_pack_pose_commit
    \\    jmp 2f
    \\1:
    \\    call _native_pack_pose_query
    \\2:
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_cell_query
    ;
    if (std.mem.eql(u8, name, "native_pack_pose_commit_input")) return
    \\.text
    \\.globl _native_pack_pose_commit_input
    \\_native_pack_pose_commit_input:
    \\pushfl
    \\    cmpl $0x433987,4(%esp)
    \\    je 1f
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 24(%eax)
    \\    call _native_pack_pose_commit
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\1:
    \\    popfl
    \\    movl 0x38(%ecx),%eax
    \\    movl 4(%esp),%edx
    \\    jmp *_pack_cell_commit_resume
    ;
    if (std.mem.eql(u8, name, "native_pack_cell_admission_input")) return
    \\.text
    \\.globl _native_pack_cell_admission_input
    \\_native_pack_cell_admission_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl 16(%eax)
    \\    pushl 4(%eax)
    \\    call _native_pack_cell_admission
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    andl $-97,16(%edx)
    \\    orl %eax,16(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    testb $0x60,%bl
    \\    jnz 1f
    \\    jmp *_pack_cell_callbacks
    \\    1: jmp *_pack_cell_skip
    ;
    if (std.mem.eql(u8, name, "native_pack_goal_move_bridge")) return
    \\.text
    \\.globl _native_pack_goal_move_bridge
    \\_native_pack_goal_move_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    leal 100(%eax),%edx
    \\    subl $4,%esp
    \\    pushl $0x43167f
    \\    pushl %edx
    \\    pushl 4(%eax)
    \\    call _native_pack_goal_input
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    flds 0x40(%esp)
    \\    fsubs (%edi)
    \\    jmp *_pack_goal_move_resume
    ;
    if (std.mem.eql(u8, name, "native_pack_goal_active_bridge")) return
    \\.text
    \\.globl _native_pack_goal_active_bridge
    \\_native_pack_goal_active_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    leal 132(%eax),%edx
    \\    subl $4,%esp
    \\    pushl $0x45fded
    \\    pushl %edx
    \\    pushl 4(%eax)
    \\    call _native_pack_goal_input
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    flds 0x60(%esp)
    \\    fsubs (%ebx)
    \\    jmp *_pack_goal_active_resume
    ;
    if (std.mem.eql(u8, name, "native_pack_formation_input")) return
    \\.text
    \\.globl _native_pack_formation_input
    \\_native_pack_formation_input:
    \\jz 1f
    \\    flds 0x20(%esp)
    \\    flds 0x28(%esp)
    \\    fld %st(1)
    \\    fmulp %st,%st(2)
    \\    fldz
    \\    .byte 0xdc,0xc8
    \\    faddp %st,%st(2)
    \\    .byte 0xdc,0xc8
    \\    faddp %st,%st(1)
    \\    fstps 0x14(%esp)
    \\    flds 0x14(%esp)
    \\    fcomps 0xadae44
    \\    fnstsw %ax
    \\    testb $1,%ah
    \\    jz 1f
    \\    movl $0x2d8,%edx
    \\    cmpw %dx,%cx
    \\    jg 1f
    \\    movl $-0x2d8,%eax
    \\    cmpw %ax,%cx
    \\    jl 1f
    \\    pushfl
    \\    pushal
    \\    xorl %ecx,%ecx
    \\    jmp 2f
    \\    1: pushfl
    \\    pushal
    \\    movl $1,%ecx
    \\    2: movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl %ecx
    \\    pushl 4(%eax)
    \\    call _native_pack_formation
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 3f
    \\    popal
    \\    popfl
    \\    jmp *_pack_formation_leave
    \\    3: popal
    \\    popfl
    \\    jmp *_pack_formation_keep
    ;
    if (std.mem.eql(u8, name, "native_pack_animation_input")) return
    \\.text
    \\.globl _native_pack_animation_input
    \\_native_pack_animation_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    leal 44(%eax),%edx
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl 24(%eax)
    \\    call _native_pack_animation
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    pushl %ecx
    \\    movl 12(%esp),%eax
    \\    pushl %esi
    \\    jmp *_pack_animation_resume
    ;
    if (std.mem.eql(u8, name, "native_rts_turret_aim_input")) return
    \\.text
    \\.globl _native_rts_turret_aim_input
    \\_native_rts_turret_aim_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_rts_turret_aim
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    leal 0x8a0(%esi),%eax
    \\    jmp *_rts_turret_aim_resume
    ;
    if (std.mem.eql(u8, name, "native_gizmo_turret_bridge")) return
    \\.text
    \\.globl _native_gizmo_turret_bridge
    \\_native_gizmo_turret_bridge:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 16(%eax)
    \\    call _native_gizmo_turret_input
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movzwl 0x1ba(%ebx),%eax
    \\    jmp *_gizmo_turret_resume
    ;
    if (std.mem.eql(u8, name, "native_weapon_commands_input")) return
    \\.text
    \\.globl _native_weapon_commands_input
    \\_native_weapon_commands_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 16(%eax)
    \\    call _native_weapon_commands
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    cmpb $0xff,0x8fb(%ebx)
    \\    jmp *_weapon_commands_resume
    ;
    if (std.mem.eql(u8, name, "native_fire_visibility_input")) return
    \\.text
    \\.globl _native_fire_visibility_input
    \\_native_fire_visibility_input:
    \\movl 8(%ecx),%eax
    \\    testl %eax,%eax
    \\    jz 1f
    \\    movb 0x42(%eax),%al
    \\    1: pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $8,%esp
    \\    pushl 28(%eax)
    \\    pushl 24(%eax)
    \\    call _native_fire_visibility
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    ret
    ;
    if (std.mem.eql(u8, name, "native_pack_mode_input")) return
    \\.text
    \\.globl _native_pack_mode_input
    \\_native_pack_mode_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    leal 52(%eax),%edx
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl 4(%eax)
    \\    call _native_pack_mode_checked
    \\    addl $16,%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movzbl 0x60(%esi),%eax
    \\    cmpl $0x1d,%eax
    \\    jmp *_pack_mode_resume
    \\1: fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    jmp *_pack_mode_abort
    ;
    if (std.mem.eql(u8, name, "native_rts_pack_gate")) return
    \\.text
    \\.globl _native_rts_pack_gate
    \\_native_rts_pack_gate:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    pushl 28(%eax)
    \\    pushl 0(%eax)
    \\    pushl 16(%eax)
    \\    pushl 4(%eax)
    \\    call _native_rts_pack_admission
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    jmp *_rts_pack_admitted
    \\    1: popal
    \\    popfl
    \\    jmp *_rts_pack_waiting
    \\    
    ;
    if (std.mem.eql(u8, name, "native_flow_request_input")) return
    \\.text
    \\.globl _native_flow_request_input
    \\_native_flow_request_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 4(%eax)
    \\    call _native_flow_request
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x60(%esi),%eax
    \\    cmpl %edi,%eax
    \\    jmp *_flow_request_resume
    \\    
    ;
    if (std.mem.eql(u8, name, "native_track_clock_input")) return
    \\.text
    \\.globl _native_track_clock_input
    \\_native_track_clock_input:
    \\movl %eax,%ecx
    \\    call _native_track_clock
    \\    jmp *_track_clock_resume
    \\    
    ;
    if (std.mem.eql(u8, name, "native_perception_sweep_input")) return
    \\.text
    \\.globl _native_perception_sweep_input
    \\_native_perception_sweep_input:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl 60(%eax)
    \\    call _native_perception_sweep
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    cmpl $0,0x18(%esp)
    \\    jmp *_perception_publish
    \\    1: popal
    \\    popfl
    \\    cmpl $0,0x18(%esp)
    \\    jmp *_perception_exit
    \\    
    ;
    if (std.mem.eql(u8, name, "native_perception_sweep_early")) return
    \\.text
    \\.globl _native_perception_sweep_early
    \\_native_perception_sweep_early:
    \\cmpl $0,0x18(%esp)
    \\    jne _native_perception_sweep_input
    \\    jmp *_perception_continue
    \\    
    ;
    if (std.mem.eql(u8, name, "native_tick_first")) return
    \\.text
    \\.globl _native_tick_first
    \\_native_tick_first:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    cld
    \\    subl $12,%esp
    \\    pushl $0x8888cd
    \\    call _native_tick_gate
    \\    addl $16,%esp
    \\    movl %eax,528(%esp)
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%edx
    \\    pushl 32(%edx)
    \\    popfl
    \\    cmpb $0,528(%esp)
    \\    pushfl
    \\    popl 32(%edx)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    jmp *_first_resume
    \\    
    ;
    @compileError("unknown tick bridge");
}
