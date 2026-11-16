pub const code =
    \\.text
    \\_cadence_script_shoot_visibility:
    \\pushl 20(%esp)
    \\    pushl 20(%esp)
    \\    pushl 20(%esp)
    \\    pushl 20(%esp)
    \\    pushl 20(%esp)
    \\    call _helper_body
    \\    addl $20,%esp
    \\    fninit
    \\    pcmpeqd %xmm0,%xmm0
    \\    pxor %xmm1,%xmm1
    \\    pxor %xmm2,%xmm2
    \\    pxor %xmm3,%xmm3
    \\    pxor %xmm4,%xmm4
    \\    pxor %xmm5,%xmm5
    \\    pxor %xmm6,%xmm6
    \\    pxor %xmm7,%xmm7
    \\    movl $1,%ebx
    \\    movl $2,%ebp
    \\    movl $3,%esi
    \\    movl $4,%edi
    \\    movl $5,%ecx
    \\    movl $6,%edx
    \\    std
    \\    ret
    \\_visible_cont:
    \\movl $1,_branch
    \\    pushfl
    \\    incl _continuation_calls
    \\    popfl
    \\    ret
    \\_hidden_cont:
    \\testb $8,_abi_state+0xa6
    \\    jnz 1f
    \\    movl $0,_branch
    \\    pushfl
    \\    incl _continuation_calls
    \\    popfl
    \\    ret
    \\    1: jmp *_script_shoot_visible_resume
    \\_original:
    \\cmpb $0,_native_operand
    \\    jne 1f
    \\    jmp *_script_shoot_hidden_resume
    \\    1: jmp *_script_shoot_visible_resume
    \\_invoke:
    \\pushfl
    \\    pushal
    \\    fxsave _caller_fx
    \\    fninit
    \\    fldcw _cw
    \\    fldl _fpu_values
    \\    fldl _fpu_values+8
    \\    ldmxcsr _mxcsr_value
    \\    movdqa _xmm_patterns,%xmm0
    \\    movdqa _xmm_patterns+16,%xmm1
    \\    movdqa _xmm_patterns+32,%xmm2
    \\    movdqa _xmm_patterns+48,%xmm3
    \\    movdqa _xmm_patterns+64,%xmm4
    \\    movdqa _xmm_patterns+80,%xmm5
    \\    movdqa _xmm_patterns+96,%xmm6
    \\    movdqa _xmm_patterns+112,%xmm7
    \\    pushl $0x646
    \\    popfl
    \\    movl $_abi_model,%eax
    \\    movl $0x22222222,%ecx
    \\    movl $0x33333333,%edx
    \\    movl $0x44444444,%ebx
    \\    movl $0x33334444,%ebp
    \\    movl $_abi_state,%esi
    \\    movl $0x11112222,%edi
    \\    call *_entry
    \\    pushfl
    \\    pushal
    \\    movl %esp,%esi
    \\    movl $_observed_regs,%edi
    \\    movl $9,%ecx
    \\    cld
    \\    rep movsl
    \\    fxsave _observed_fx
    \\    addl $36,%esp
    \\    fxrstor _caller_fx
    \\    popal
    \\    popfl
    \\    ret
;
