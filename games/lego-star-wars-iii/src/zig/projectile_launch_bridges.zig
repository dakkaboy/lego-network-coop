comptime {
    asm (
        \\.text
        \\.globl _projectile_shot_center_hook
        \\_projectile_shot_center_hook:
        \\movl 0xc(%ebp),%edi
        \\    addl $0xf28,%edi
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
        \\    pushl 0x14(%ebp)
        \\    pushl 0x10(%ebp)
        \\    pushl 0xc(%ebp)
        \\    pushl %edi
        \\    call _projectile_shot_center_source
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movl %eax,(%edx)
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_shot_center_resume
        \\.globl _projectile_shot_motion_hook
        \\_projectile_shot_motion_hook:
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl 512(%esp),%edx
        \\    pushl 0x14(%ebp)
        \\    pushl 0x10(%ebp)
        \\    pushl 0xc(%ebp)
        \\    pushl 48(%edx)
        \\    call _projectile_shot_motion_source
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movl %eax,48(%edx)
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_shot_motion_original
    );
}
