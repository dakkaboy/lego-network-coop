comptime {
    asm (
        \\.text
        \\.globl _vehicle_rng_float_thunk
        \\_vehicle_rng_float_thunk:
        \\pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    movl 0x24(%eax),%ecx
        \\    subl $5,%ecx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %esi
        \\    cld
        \\    call _physics_apply_vehicle_rng
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_vehicle_rng_float_native
        \\    
        \\.text
        \\.globl _vehicle_rng_integer_thunk
        \\_vehicle_rng_integer_thunk:
        \\pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    movl 0x24(%eax),%ecx
        \\    subl $5,%ecx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %esi
        \\    cld
        \\    call _physics_apply_vehicle_rng
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_vehicle_rng_integer_native
        \\    
    );
}
