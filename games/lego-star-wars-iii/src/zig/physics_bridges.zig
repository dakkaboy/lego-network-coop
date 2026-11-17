comptime {
    asm (
        \\.text
        \\.globl _physics_breakup_launch_thunk
        \\_physics_breakup_launch_thunk:
        \\pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    movl 0x64(%eax),%ecx
        \\    xorl %edx,%edx
        \\    cmpl $40,%ecx
        \\    jae 1f
        \\    movl 0x3c0(%eax,%ecx,4),%edx
        \\    1: subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    movl 512(%esp),%eax
        \\    subl $12,%esp
        \\    pushl 0(%eax)
        \\    pushl 0x5c(%eax)
        \\    pushl 0x54(%eax)
        \\    pushl %edx
        \\    pushl %esi
        \\    cld
        \\    call _physics_apply_breakup_launch
        \\    addl $32,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_breakup_launch_native
        \\    
        \\.text
        \\.globl _physics_effect_birth_thunk
        \\_physics_effect_birth_thunk:
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
        \\    subl $12,%esp
        \\    pushl 28(%eax)
        \\    cld
        \\    call _physics_effect_birth
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    movl 0x208(%esp),%ecx
        \\    jmp *_effect_birth_resume
        \\    
    );
}
