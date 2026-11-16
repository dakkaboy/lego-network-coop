pub const code =
    \\.text
    \\.globl _hazard_death_thunk
    \\_hazard_death_thunk:
    \\pushfl
    \\pushal
    \\movl %esp,%edx
    \\subl $544,%esp
    \\andl $-16,%esp
    \\movl %edx,512(%esp)
    \\fxsave (%esp)
    \\movl %fs:0x34,%eax
    \\movl %eax,520(%esp)
    \\fninit
    \\movl $0x1f80,516(%esp)
    \\ldmxcsr 516(%esp)
    \\pushl 8(%edx)
    \\pushl 16(%edx)
    \\pushl 28(%edx)
    \\pushl 4(%edx)
    \\cld
    \\call _cadence_hazard_death
    \\addl $16,%esp
    \\fxrstor (%esp)
    \\movl 520(%esp),%edx
    \\movl %edx,%fs:0x34
    \\movl 512(%esp),%esp
    \\pushl 32(%esp)
    \\popfl
    \\testb $0x41,%al
    \\pushfl
    \\popl 32(%esp)
    \\popal
    \\popfl
    \\jnz 1f
    \\jmp *_hazard_death_continue
    \\1: jmp *_hazard_death_skip
;
