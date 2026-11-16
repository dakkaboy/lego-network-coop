comptime {
    asm (
        \\.text
        \\.globl _saber_actor_batch_tap
        \\_saber_actor_batch_tap:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_actor_batch+4
        \\    movzbl 0xfb2f51,%eax
        \\    movl %eax,_clonewars_saber_actor_batch+8
        \\    incl _clonewars_saber_actor_batch
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_actor_batch_native
        \\    
        \\.text
        \\.globl _saber_pass_first
        \\_saber_pass_first:
        \\pushfl
        \\    pushl %eax
        \\    incl _clonewars_saber_pass+0
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_pass+0+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_pass+0+8
        \\    movl 12(%esp),%eax
        \\    movl %eax,_clonewars_saber_pass+0+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_pass+0+16
        \\    movzbl 0xfb2f51,%eax
        \\    movl %eax,_clonewars_saber_actor_batch+12
        \\    movl 0xfbca90,%eax
        \\    movl %eax,_clonewars_saber_list+0
        \\    testl %eax,%eax
        \\    jz 1f
        \\    movl 0x10(%eax),%eax
        \\    movl %eax,_clonewars_saber_list+0+4
        \\    incl _clonewars_saber_list+0+8
        \\    1:
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_draw_native
        \\    
        \\.text
        \\.globl _saber_pass_last
        \\_saber_pass_last:
        \\pushfl
        \\    pushl %eax
        \\    incl _clonewars_saber_pass+20
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_pass+20+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_pass+20+8
        \\    movl 12(%esp),%eax
        \\    movl %eax,_clonewars_saber_pass+20+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_pass+20+16
        \\    movzbl 0xfb2f51,%eax
        \\    movl %eax,_clonewars_saber_actor_batch+12
        \\    movl 0xfbca90,%eax
        \\    movl %eax,_clonewars_saber_list+12
        \\    testl %eax,%eax
        \\    jz 1f
        \\    movl 0x10(%eax),%eax
        \\    movl %eax,_clonewars_saber_list+12+4
        \\    incl _clonewars_saber_list+12+8
        \\    1:
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_draw_native
        \\    
        \\.text
        \\.globl _saber_submit_glow_indexed
        \\_saber_submit_glow_indexed:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+0+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+0+8
        \\    movl 24(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+0+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+0+16
        \\    incl _clonewars_saber_submit+0
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_indexed
        \\    
        \\.text
        \\.globl _saber_submit_glow_plain
        \\_saber_submit_glow_plain:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+20+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+20+8
        \\    movl 20(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+20+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+20+16
        \\    incl _clonewars_saber_submit+20
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_plain
        \\    
        \\.text
        \\.globl _saber_submit_glow_repeat_indexed
        \\_saber_submit_glow_repeat_indexed:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+40+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+40+8
        \\    movl 24(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+40+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+40+16
        \\    incl _clonewars_saber_submit+40
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_indexed
        \\    
        \\.text
        \\.globl _saber_submit_glow_repeat_plain
        \\_saber_submit_glow_repeat_plain:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+60+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+60+8
        \\    movl 20(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+60+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+60+16
        \\    incl _clonewars_saber_submit+60
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_plain
        \\    
        \\.text
        \\.globl _saber_submit_core_indexed
        \\_saber_submit_core_indexed:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+80+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+80+8
        \\    movl 24(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+80+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+80+16
        \\    incl _clonewars_saber_submit+80
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_indexed
        \\    
        \\.text
        \\.globl _saber_submit_core_plain
        \\_saber_submit_core_plain:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+100+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+100+8
        \\    movl 20(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+100+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+100+16
        \\    incl _clonewars_saber_submit+100
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_plain
        \\    
        \\.text
        \\.globl _saber_submit_other
        \\_saber_submit_other:
        \\pushfl
        \\    pushl %eax
        \\    movl 0xeb8374,%eax
        \\    movl %eax,_clonewars_saber_submit+120+4
        \\    movl 0xf73afc,%eax
        \\    movl %eax,_clonewars_saber_submit+120+8
        \\    movl 24(%esp),%eax
        \\    movl %eax,_clonewars_saber_submit+120+12
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_saber_submit+120+16
        \\    incl _clonewars_saber_submit+120
        \\    popl %eax
        \\    popfl
        \\    jmp *_saber_submit_ribbon
        \\    
        \\.text
        \\.globl _saber_weapon_visibility_gate
        \\_saber_weapon_visibility_gate:
        \\cmpb $0,0x42(%eax)
        \\    jne 1f
        \\    cmpl $0x9b6c10,4(%esp)
        \\    jne 2f
        \\    pushal
        \\    pushl %ebx
        \\    call _saber_allow_network_weapon_fx
        \\    addl $4,%esp
        \\    testl %eax,%eax
        \\    popal
        \\    jz 2f
        \\    1: jmp *_saber_weapon_walk
        \\    2: jmp *_saber_weapon_skip
        \\    
        \\.text
        \\.globl _camera_target_end
        \\_camera_target_end:
        \\pushl $0
        \\    pushl %ecx
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl 512(%esp),%edx
        \\    leal 40(%edx),%ecx
        \\    subl $12,%esp
        \\    pushl %ecx
        \\    pushl $0
        \\    pushl 28(%edx)
        \\    pushl 48(%edx)
        \\    pushl 36(%edx)
        \\    call _camera_compositor_sample
        \\    addl $32,%esp
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    pushl 12(%esp)
        \\    call *_camera_original_target_end
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl 512(%esp),%edx
        \\    leal 40(%edx),%ecx
        \\    subl $12,%esp
        \\    pushl %ecx
        \\    pushl $1
        \\    pushl 28(%edx)
        \\    pushl 48(%edx)
        \\    pushl 36(%edx)
        \\    call _camera_compositor_sample
        \\    addl $32,%esp
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    leal 8(%esp),%esp
        \\    ret $4
        \\    
    );
}
