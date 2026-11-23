const std = @import("std");
pub const names = [_][]const u8{ "cadence_period_thunk", "fire_task_gate_thunk", "attack_support_thunk", "breakup_visibility_thunk", "death_breakup_thunk", "fall_visibility_thunk", "aim_task_input_thunk", "aim_task_visibility_thunk", "script_shoot_visibility_thunk", "rts_competitor_input_thunk", "aim_base_input_thunk", "force_target_visibility_thunk", "force_geometry_input_thunk", "spellit_node_thunk", "spellit_prepare_thunk", "spellit_first_heading_thunk", "spellit_second_heading_thunk", "spellit_height_thunk", "spellit_position_thunk", "character_motion_thunk", "primary_perception_thunk", "script_attack_target_thunk", "script_assigned_target_thunk" };
pub fn code(comptime name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, "cadence_period_thunk")) return
    \\.text
    \\.globl _cadence_period_thunk
    \\_cadence_period_thunk:
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
    \\    leal 56(%eax),%edx
    \\    movl (%eax),%ecx
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_apply_period
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x14(%esp),%ecx
    \\    movb %cl,0x138e(%edi)
    \\    jmp *_cadence_resume
    ;
    if (std.mem.eql(u8, name, "fire_task_gate_thunk")) return
    \\.text
    \\.globl _fire_task_gate_thunk
    \\_fire_task_gate_thunk:
    \\pushfl
    \\    pushal
    \\    xorl %edx,%edx
    \\    movl 8(%ebx),%eax
    \\    testl %eax,%eax
    \\    jz 1f
    \\    cmpb $0,0x42(%eax)
    \\    jne 2f
    \\    1: testb $8,4(%esi)
    \\    jz 3f
    \\    2: movl $1,%edx
    \\    3: movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    leal 0x14(%ebp),%ecx
    \\    pushl %ecx
    \\    pushl %edx
    \\    pushl %esi
    \\    pushl %ebx
    \\    cld
    \\    call _cadence_apply_fire_task_gate
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 4f
    \\    popal
    \\    popfl
    \\    jmp *_fire_task_gate_allow
    \\    4: popal
    \\    popfl
    \\    jmp *_fire_task_gate_skip
    ;
    if (std.mem.eql(u8, name, "attack_support_thunk")) return
    \\.text
    \\.globl _attack_support_thunk
    \\_attack_support_thunk:
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
    \\    subl $8,%esp
    \\    leal 120(%eax),%edx
    \\    pushl %edx
    \\    pushl 16(%eax)
    \\    cld
    \\    call _cadence_apply_attack_support
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x54(%esp),%esi
    \\    movl 0x24(%ebp),%ecx
    \\    jmp *_attack_support_resume
    ;
    if (std.mem.eql(u8, name, "breakup_visibility_thunk")) return
    \\.text
    \\.globl _breakup_visibility_thunk
    \\_breakup_visibility_thunk:
    \\testb %bl,%bl
    \\    pushfl
    \\    pushal
    \\    movzbl %bl,%edx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl %esi
    \\    cld
    \\    call _cadence_apply_breakup_visibility
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jnz 1f
    \\    popal
    \\    popfl
    \\    jmp *_breakup_visible_resume
    \\    1: popal
    \\    popfl
    \\    jmp *_breakup_hidden_resume
    ;
    if (std.mem.eql(u8, name, "death_breakup_thunk")) return
    \\.text
    \\.globl _death_breakup_thunk
    \\_death_breakup_thunk:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    leal 0xc4(%eax),%edx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl %ebp
    \\    cld
    \\    call _cadence_apply_death_breakup
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    cmpl $0,0xa0(%esp)
    \\    jmp *_death_breakup_resume
    ;
    if (std.mem.eql(u8, name, "fall_visibility_thunk")) return
    \\.text
    \\.globl _fall_visibility_thunk
    \\_fall_visibility_thunk:
    \\cmpb $0,0x42(%edx)
    \\    pushfl
    \\    pushal
    \\    xorl %ecx,%ecx
    \\    cmpb $0,0x42(%edx)
    \\    setne %cl
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl %ecx
    \\    pushl %ebx
    \\    cld
    \\    call _cadence_apply_fall_visibility
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    jmp *_fall_visible_resume
    \\    1: popal
    \\    popfl
    \\    jmp *_fall_hidden_resume
    ;
    if (std.mem.eql(u8, name, "aim_task_input_thunk")) return
    \\.text
    \\.globl _aim_task_input_thunk
    \\_aim_task_input_thunk:
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
    \\    subl $8,%esp
    \\    pushl %edi
    \\    pushl %esi
    \\    cld
    \\    call _cadence_prepare_aim_task
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x10(%edi),%ecx
    \\    testl %ecx,%ecx
    \\    jmp *_aim_task_input_resume
    ;
    if (std.mem.eql(u8, name, "aim_task_visibility_thunk")) return
    \\.text
    \\.globl _aim_task_visibility_thunk
    \\_aim_task_visibility_thunk:
    \\cmpb $0,0x42(%eax)
    \\    pushfl
    \\    pushal
    \\    movzbl 0x42(%eax),%edx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %edx
    \\    pushl %edi
    \\    pushl %esi
    \\    cld
    \\    call _cadence_aim_task_visibility
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    jmp *_aim_task_visible_resume
    \\    1: popal
    \\    popfl
    \\    jmp *_aim_task_hidden_resume
    ;
    if (std.mem.eql(u8, name, "script_shoot_visibility_thunk")) return
    \\.text
    \\.globl _script_shoot_visibility_thunk
    \\_script_shoot_visibility_thunk:
    \\pushfl
    \\    pushal
    \\    movzbl 0x42(%eax),%ecx
    \\    movl %esp,%edx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %edx,512(%esp)
    \\    fxsave (%esp)
    \\    movl %fs:0x34,%edx
    \\    movl %edx,520(%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $12,%esp
    \\    pushl %ecx
    \\    pushl %ebp
    \\    pushl %eax
    \\    pushl %esi
    \\    pushl %edi
    \\    cld
    \\    call _cadence_script_shoot_visibility
    \\    addl $32,%esp
    \\    fxrstor (%esp)
    \\    movl 520(%esp),%edx
    \\    movl %edx,%fs:0x34
    \\    movl 512(%esp),%esp
    \\    pushl 32(%esp)
    \\    popfl
    \\    cmpb $0,%al
    \\    pushfl
    \\    popl 32(%esp)
    \\    popal
    \\    popfl
    \\    jnz 1f
    \\    jmp *_script_shoot_hidden_resume
    \\    1: jmp *_script_shoot_visible_resume
    ;
    if (std.mem.eql(u8, name, "rts_competitor_input_thunk")) return
    \\.text
    \\.globl _rts_competitor_input_thunk
    \\_rts_competitor_input_thunk:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    leal 40(%eax),%edx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_prepare_rts_competitor
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    pushl %ebp
    \\    movl %esp,%ebp
    \\    andl $-16,%esp
    \\    jmp *_rts_competitor_input_resume
    ;
    if (std.mem.eql(u8, name, "aim_base_input_thunk")) return
    \\.text
    \\.globl _aim_base_input_thunk
    \\_aim_base_input_thunk:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    movl 0x34(%eax),%edx
    \\    leal 0x38(%eax),%ebx
    \\    movl 24(%eax),%ecx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %ebx
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_prepare_aim_base
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    testl %eax,%eax
    \\    movl 512(%esp),%esp
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    flds 0x14(%esp)
    \\    movl 0xc(%esp),%eax
    \\    jmp *_aim_base_input_resume
    \\1:
    \\    popal
    \\    popfl
    \\    ret $0x14
    ;
    if (std.mem.eql(u8, name, "force_target_visibility_thunk")) return
    \\.text
    \\.globl _force_target_visibility_thunk
    \\_force_target_visibility_thunk:
    \\cmpb $0,0x42(%eax)
    \\    pushfl
    \\    pushal
    \\    movzbl 0x42(%eax),%ecx
    \\    movl 0x68(%esp),%ebx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    pushl %ecx
    \\    pushl %ebx
    \\    pushl %edx
    \\    pushl %edi
    \\    cld
    \\    call _cadence_force_target_visibility
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    testl %eax,%eax
    \\    jz 1f
    \\    popal
    \\    popfl
    \\    jmp *_force_target_visible_resume
    \\    1: popal
    \\    popfl
    \\    jmp *_force_target_hidden_resume
    ;
    if (std.mem.eql(u8, name, "force_geometry_input_thunk")) return
    \\.text
    \\.globl _force_geometry_input_thunk
    \\_force_geometry_input_thunk:
    \\leal -32(%esp),%esp
    \\    pushfl
    \\    pushal
    \\    movl 72(%esp),%eax
    \\    leal 44(%esp),%ebx
    \\    movl (%eax),%ecx
    \\    movl %ecx,(%ebx)
    \\    movl 4(%eax),%ecx
    \\    movl %ecx,4(%ebx)
    \\    movl 8(%eax),%ecx
    \\    movl %ecx,8(%ebx)
    \\    movl 76(%esp),%eax
    \\    movl (%eax),%ecx
    \\    movl %ecx,12(%ebx)
    \\    movl 4(%eax),%ecx
    \\    movl %ecx,16(%ebx)
    \\    movl 8(%eax),%ecx
    \\    movl %ecx,20(%ebx)
    \\    movl 8(%esp),%edx
    \\    movl (%esp),%ecx
    \\    movl 152(%esp),%edi
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    pushl %ebx
    \\    pushl %edi
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_force_geometry_input
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    pushl 44(%esp)
    \\    leal 24(%esp),%edx
    \\    pushl %edx
    \\    leal 16(%esp),%eax
    \\    pushl %eax
    \\    call *_force_distance_native
    \\    leal 44(%esp),%esp
    \\    ret
    ;
    if (std.mem.eql(u8, name, "spellit_node_thunk")) return
    \\.text
    \\.globl _spellit_node_thunk
    \\_spellit_node_thunk:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    movl 8(%eax),%ecx
    \\    movl 4(%eax),%edx
    \\    movl (%eax),%ebx
    \\    leal 148(%eax),%esi
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    pushl %esi
    \\    pushl %ebx
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_node
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x70(%esp),%eax
    \\    movl 0x74(%esp),%ecx
    \\    jmp *_spellit_node_resume
    ;
    if (std.mem.eql(u8, name, "spellit_prepare_thunk")) return
    \\.text
    \\.globl _spellit_prepare_thunk
    \\_spellit_prepare_thunk:
    \\pushfl
    \\    pushal
    \\    movl %esp,%eax
    \\    movl 4(%eax),%ecx
    \\    movl (%eax),%edx
    \\    movl 8(%eax),%ebx
    \\    leal 52(%eax),%esi
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    pushl %esi
    \\    pushl %ebx
    \\    pushl %edx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_prepare
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 8(%esi),%eax
    \\    testl %eax,%eax
    \\    jmp *_spellit_prepare_resume
    ;
    if (std.mem.eql(u8, name, "spellit_first_heading_thunk")) return
    \\.text
    \\.globl _spellit_first_heading_thunk
    \\_spellit_first_heading_thunk:
    \\pushfl
    \\    pushal
    \\    movzwl 0x40(%eax),%ebx
    \\    movl 8(%esp),%ecx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %ebx
    \\    pushl $0
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_operand
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    movl %eax,28(%esp)
    \\    popal
    \\    popfl
    \\    jmp *_spellit_first_heading_resume
    ;
    if (std.mem.eql(u8, name, "spellit_second_heading_thunk")) return
    \\.text
    \\.globl _spellit_second_heading_thunk
    \\_spellit_second_heading_thunk:
    \\pushfl
    \\    pushal
    \\    movzwl 0x40(%esi),%ebx
    \\    movl 8(%esp),%ecx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %ebx
    \\    pushl $0
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_operand
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    movl %eax,28(%esp)
    \\    popal
    \\    popfl
    \\    jmp *_spellit_second_heading_resume
    ;
    if (std.mem.eql(u8, name, "spellit_height_thunk")) return
    \\.text
    \\.globl _spellit_height_thunk
    \\_spellit_height_thunk:
    \\pushfl
    \\    pushal
    \\    movl 0x28(%eax),%ebx
    \\    movl 8(%esp),%ecx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %ebx
    \\    pushl $1
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_operand
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    movl %eax,12(%esp)
    \\    flds 12(%esp)
    \\    popal
    \\    popfl
    \\    movl %ecx,0x2c(%esp)
    \\    jmp *_spellit_height_resume
    ;
    if (std.mem.eql(u8, name, "spellit_position_thunk")) return
    \\.text
    \\.globl _spellit_position_thunk
    \\_spellit_position_thunk:
    \\leal -16(%esp),%esp
    \\    pushfl
    \\    pushal
    \\    movl 60(%esp),%eax
    \\    leal 40(%esp),%ebx
    \\    movl (%eax),%ecx
    \\    movl %ecx,(%ebx)
    \\    movl 4(%eax),%ecx
    \\    movl %ecx,4(%ebx)
    \\    movl 8(%eax),%ecx
    \\    movl %ecx,8(%ebx)
    \\    movl 8(%esp),%ecx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl %ebx
    \\    pushl %ecx
    \\    cld
    \\    call _cadence_spellit_position
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    pushl 28(%esp)
    \\    leal 8(%esp),%edx
    \\    pushl %edx
    \\    pushl 28(%esp)
    \\    call *_spellit_distance_native
    \\    leal 28(%esp),%esp
    \\    ret
    ;
    if (std.mem.eql(u8, name, "character_motion_thunk")) return
    \\.text
    \\.globl _character_motion_thunk
    \\_character_motion_thunk:
    \\leal -16(%esp),%esp
    \\    pushfl
    \\    pushal
    \\    movl 56(%esp),%eax
    \\    leal 36(%esp),%edi
    \\    movl (%eax),%edx
    \\    movl %edx,(%edi)
    \\    movl 4(%eax),%edx
    \\    movl %edx,4(%edi)
    \\    movl 8(%eax),%edx
    \\    movl %edx,8(%edi)
    \\    movl 12(%eax),%edx
    \\    movl %edx,12(%edi)
    \\    movl 16(%esp),%ebx
    \\    movl 24(%esp),%ecx
    \\    movl %esp,%eax
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %eax,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $4,%esp
    \\    pushl %edi
    \\    pushl %ecx
    \\    pushl %ebx
    \\    cld
    \\    call _cadence_character_motion_input
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    pushl %esp
    \\    call *_character_velocity_native
    \\    movl 20(%esp),%eax
    \\    leal 16(%esp),%esp
    \\    ret $4
    ;
    if (std.mem.eql(u8, name, "primary_perception_thunk")) return
    \\.text
    \\.globl _primary_perception_thunk
    \\_primary_perception_thunk:
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
    \\    call _cadence_primary_perception
    \\    addl $16,%esp
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\    movl 0x164(%esi),%eax
    \\    jmp *_primary_perception_resume
    ;
    if (std.mem.eql(u8, name, "script_attack_target_thunk")) return
    \\.text
    \\.globl _script_attack_target_thunk
    \\_script_attack_target_thunk:
    \\    pushfl
    \\    pushal
    \\    movl %esp,%edx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %edx,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl 28(%edx)
    \\    pushl 44(%edx)
    \\    cld
    \\    call _cadence_script_attack_target
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    movl %eax,0xb8(%esi)
    \\    testl %eax,%eax
    \\    jmp *_script_attack_target_resume
    ;
    if (std.mem.eql(u8, name, "script_assigned_target_thunk")) return
    \\.text
    \\.globl _script_assigned_target_thunk
    \\_script_assigned_target_thunk:
    \\    movl 0xe14(%esi),%eax
    \\    pushfl
    \\    pushal
    \\    movl %esp,%edx
    \\    subl $544,%esp
    \\    andl $-16,%esp
    \\    movl %edx,512(%esp)
    \\    fxsave (%esp)
    \\    fninit
    \\    movl $0x1f80,516(%esp)
    \\    ldmxcsr 516(%esp)
    \\    subl $8,%esp
    \\    pushl 28(%edx)
    \\    pushl 4(%edx)
    \\    cld
    \\    call _cadence_script_assigned_target
    \\    addl $16,%esp
    \\    movl 512(%esp),%edx
    \\    movl %eax,28(%edx)
    \\    fxrstor (%esp)
    \\    movl %edx,%esp
    \\    popal
    \\    popfl
    \\    cmpl %eax,0xe14(%esi)
    \\    je 1f
    \\    movl %eax,0xe14(%esi)
    \\1:
    \\    jmp *_script_assigned_target_resume
    ;
    @compileError("Unknown cadence bridge");
}
