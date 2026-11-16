comptime {
    asm (
        \\.text
        \\.globl _native_spellit_pose_bridge
        \\_native_spellit_pose_bridge:
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
        \\    call _native_spellit_pose_input
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    movl 0x21c(%ebx),%ecx
        \\    jmp *_spellit_target_resume
        \\.text
        \\.globl _native_spellit_timeout_flags_bridge
        \\_native_spellit_timeout_flags_bridge:
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
        \\    pushl $0x812d7a
        \\    pushl 24(%eax)
        \\    call _native_spellit_receiver_flags
        \\    addl $16,%esp
        \\    testb $4,%al
        \\    pushfl
        \\    popl %eax
        \\    movl 512(%esp),%edx
        \\    andl $0xfffff73a,32(%edx)
        \\    andl $0x8c5,%eax
        \\    orl %eax,32(%edx)
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_spellit_timeout_flags_resume
        \\.text
        \\.globl _native_spellit_finish_flags_bridge
        \\_native_spellit_finish_flags_bridge:
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
        \\    pushl $0x812df0
        \\    pushl 24(%eax)
        \\    call _native_spellit_receiver_flags
        \\    addl $16,%esp
        \\    testb $4,%al
        \\    pushfl
        \\    popl %eax
        \\    movl 512(%esp),%edx
        \\    andl $0xfffff73a,32(%edx)
        \\    andl $0x8c5,%eax
        \\    orl %eax,32(%edx)
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_spellit_finish_flags_resume
    );
}
