pub const code =
    \\.text
    \\.globl _rider_fire_visibility_thunk
    \\_rider_fire_visibility_thunk:
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
    \\movl 8(%edx),%eax
    \\pushl 4(%eax)
    \\pushl 12(%eax)
    \\pushl 8(%eax)
    \\pushl 4(%edx)
    \\cld
    \\call _cadence_rider_fire_input
    \\addl $16,%esp
    \\fxrstor (%esp)
    \\movl 520(%esp),%edx
    \\movl %edx,%fs:0x34
    \\movl 512(%esp),%esp
    \\pushl 32(%esp)
    \\popfl
    \\testl %eax,%eax
    \\pushfl
    \\popl 32(%esp)
    \\popal
    \\popfl
    \\jnz 1f
    \\jmp *_rider_fire_hidden_resume
    \\1: jmp *_rider_fire_visible_resume
;
