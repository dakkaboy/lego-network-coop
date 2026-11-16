comptime {
    asm (
        \\.text
        \\.globl _native_rts_order_ready_bridge
        \\_native_rts_order_ready_bridge:
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
        \\    movl 28(%eax),%edx
        \\    movzbl 0x62(%edx),%edx
        \\    subl $8,%esp
        \\    pushl %edx
        \\    pushl 4(%eax)
        \\    call _native_rts_order_ready
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movb %al,24(%edx)
        \\    fxrstor (%esp)
        \\    movl %edx,%esp
        \\    popal
        \\    popfl
        \\    shrb %cl
        \\    jmp *_rts_order_ready_resume
    );
}
