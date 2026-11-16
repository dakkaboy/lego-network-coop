comptime {
    asm (
        \\.text
        \\.globl _rts_attack_visibility_input_bridge
        \\_rts_attack_visibility_input_bridge:
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
        \\    call _rts_attack_visibility_input
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    fxrstor (%esp)
        \\    movl %edx,%esp
        \\    popal
        \\    popfl
        \\    movl 0x24(%ebx),%eax
        \\    cmpb $0,0x27d(%eax)
        \\    jmp *_attack_visibility_resume
    );
}
