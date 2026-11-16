comptime {
    asm (
        \\.text
        \\.globl _gun_jam_rng_thunk
        \\_gun_jam_rng_thunk:
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
        \\    pushl 8(%eax)
        \\    call _gun_jam_rng_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    pushl $0x4acb58
        \\    jmp *_gun_jam_native_rng
        \\    
    );
}
