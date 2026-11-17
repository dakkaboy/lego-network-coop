pub const code =
    \\.text
    \\.globl _physics_effect_rest_thunk
    \\_physics_effect_rest_thunk:
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
    \\movl 28(%edx),%eax
    \\shrl $8,%eax
    \\subl $8,%esp
    \\pushl %eax
    \\pushl 16(%edx)
    \\cld
    \\call _physics_effect_rest
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
    \\jmp *_effect_rest_resume
    \\1: jmp *_effect_moving_resume
;
