comptime {
    asm (
        \\.text
        \\.globl _world_contact_query_thunk
        \\_world_contact_query_thunk:
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
        \\    leal 36(%eax),%edx
        \\    movl 28(%eax),%ecx
        \\    pushl %eax
        \\    pushl $0x81f7bf
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _world_contact_query_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $24,%esp
        \\    testl %eax,%eax
        \\    jmp *_world_contact_query_resume
        \\    
    );
}
