pub const code =
    \\.text
    \\_prepare_cont:
    \\ret
    \\_first_heading_cont:
    \\ret
    \\_second_heading_cont:
    \\ret
    \\_height_cont:
    \\ret
    \\_original_prepare:
    \\movl 8(%esi),%eax
    \\    testl %eax,%eax
    \\    jmp *_spellit_prepare_resume
    \\_original_first_heading:
    \\movzwl 0x40(%eax),%eax
    \\    jmp *_spellit_first_heading_resume
    \\_original_second_heading:
    \\movzwl 0x40(%esi),%eax
    \\    jmp *_spellit_second_heading_resume
    \\_original_height:
    \\flds 0x28(%eax)
    \\    movl %ecx,0x2c(%esp)
    \\    jmp *_spellit_height_resume
    \\_original_node:
    \\movl 0x70(%esp),%eax
    \\    movl 0x74(%esp),%ecx
    \\    jmp *_spellit_node_resume
    \\_invoke_node:
    \\pushfl
    \\    pushal
    \\    fxsave _caller_fx
    \\    subl $0x90,%esp
    \\    movl $_node_stack,%esi
    \\    movl %esp,%edi
    \\    movl $36,%ecx
    \\    cld
    \\    rep movsl
    \\    fninit
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fninit
    \\    fldl _live_fpu
    \\    fldl _live_fpu+8
    \\    ldmxcsr _mxcsr_value
    \\    pxor %xmm0,%xmm0
    \\    pxor %xmm1,%xmm1
    \\    pxor %xmm2,%xmm2
    \\    pxor %xmm3,%xmm3
    \\    pxor %xmm4,%xmm4
    \\    pxor %xmm5,%xmm5
    \\    pxor %xmm6,%xmm6
    \\    pxor %xmm7,%xmm7
    \\    pcmpeqd %xmm7,%xmm7
    \\    pslld $7,%xmm7
    \\    pushl $0x646
    \\    popfl
    \\    movl $0x11111111,%eax
    \\    movl $0x22222222,%ecx
    \\    movl $0x33333333,%edx
    \\    movl $0x44444444,%ebx
    \\    movl $0x55555555,%ebp
    \\    movl $_manager,%esi
    \\    movl $0x77777777,%edi
    \\    call *_entry
    \\    pushfl
    \\    pushal
    \\    movl %esp,%esi
    \\    movl $_observed_regs,%edi
    \\    movl $9,%ecx
    \\    cld
    \\    rep movsl
    \\    fxsave _observed_fx
    \\    leal 36(%esp),%esi
    \\    movl $_observed_node_stack,%edi
    \\    movl $36,%ecx
    \\    rep movsl
    \\    leal 180(%esp),%esp
    \\    fxrstor _caller_fx
    \\    popal
    \\    popfl
    \\    ret
    \\_invoke_operand:
    \\pushfl
    \\    pushal
    \\    fxsave _caller_fx
    \\    fninit
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fninit
    \\    fldl _live_fpu
    \\    fldl _live_fpu+8
    \\    ldmxcsr _mxcsr_value
    \\    pxor %xmm0,%xmm0
    \\    pxor %xmm1,%xmm1
    \\    pxor %xmm2,%xmm2
    \\    pxor %xmm3,%xmm3
    \\    pxor %xmm4,%xmm4
    \\    pxor %xmm5,%xmm5
    \\    pxor %xmm6,%xmm6
    \\    pxor %xmm7,%xmm7
    \\    pcmpeqd %xmm7,%xmm7
    \\    pslld $7,%xmm7
    \\    subl $0x60,%esp
    \\    movl _initial_limit,%eax
    \\    movl %eax,0xc(%esp)
    \\    movl $0xcafebabe,0x28(%esp)
    \\    pushl $0x646
    \\    popfl
    \\    movl _test_eax,%eax
    \\    movl $0x22222222,%ecx
    \\    movl $0x33333333,%edx
    \\    movl $0x44444444,%ebx
    \\    movl $0x55555555,%ebp
    \\    movl _test_esi,%esi
    \\    movl $_manager,%edi
    \\    call *_entry
    \\    pushfl
    \\    pushal
    \\    movl %esp,%esi
    \\    movl $_observed_regs,%edi
    \\    movl $9,%ecx
    \\    cld
    \\    rep movsl
    \\    fxsave _observed_fx
    \\    movl 48(%esp),%eax
    \\    movl %eax,_observed_limit
    \\    movl 76(%esp),%eax
    \\    movl %eax,_observed_height_store
    \\    leal 0x84(%esp),%esp
    \\    fxrstor _caller_fx
    \\    popal
    \\    popfl
    \\    ret
    \\_native_distance:
    \\incl _distance_calls
    \\    movl 4(%esp),%eax
    \\    movl %eax,_native_candidate
    \\    movl 8(%esp),%eax
    \\    movl %eax,_native_caster
    \\    movl 12(%esp),%edx
    \\    movl %edx,_native_output
    \\    movl (%eax),%edx
    \\    movl %edx,_native_caster_values
    \\    movl 4(%eax),%edx
    \\    movl %edx,_native_caster_values+4
    \\    movl 8(%eax),%edx
    \\    movl %edx,_native_caster_values+8
    \\    movl 12(%esp),%eax
    \\    subl $12,%esp
    \\    movl 16(%esp),%ecx
    \\    movl 20(%esp),%edx
    \\    flds (%ecx)
    \\    fsubs (%edx)
    \\    fstps (%eax)
    \\    fldz
    \\    fstps 4(%eax)
    \\    flds 8(%ecx)
    \\    fsubs 8(%edx)
    \\    fstps 24(%esp)
    \\    flds 24(%esp)
    \\    fsts 8(%eax)
    \\    flds (%eax)
    \\    fmul %st,%st
    \\    fldz
    \\    fmul %st,%st
    \\    faddp %st,%st(1)
    \\    fld %st(1)
    \\    fmulp %st,%st(2)
    \\    faddp %st,%st(1)
    \\    fstps 24(%esp)
    \\    flds 24(%esp)
    \\    addl $12,%esp
    \\    ret
    \\_invoke_distance:
    \\pushfl
    \\    pushal
    \\    fxsave _caller_fx
    \\    fninit
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fldz
    \\    fninit
    \\    fldl _live_fpu
    \\    fldl _live_fpu+8
    \\    ldmxcsr _mxcsr_value
    \\    pxor %xmm0,%xmm0
    \\    pxor %xmm1,%xmm1
    \\    pxor %xmm2,%xmm2
    \\    pxor %xmm3,%xmm3
    \\    pxor %xmm4,%xmm4
    \\    pxor %xmm5,%xmm5
    \\    pxor %xmm6,%xmm6
    \\    pxor %xmm7,%xmm7
    \\    pcmpeqd %xmm7,%xmm7
    \\    pslld $7,%xmm7
    \\    pushl $0x646
    \\    popfl
    \\    movl $0x44444444,%ebx
    \\    movl $0x55555555,%ebp
    \\    movl $0x66666666,%esi
    \\    movl $0x77777777,%edi
    \\    pushl $_output
    \\    pushl $_actor+0x24
    \\    pushl $_candidate
    \\    call *_entry
    \\    fstps _distance_value
    \\    leal 12(%esp),%esp
    \\    pushfl
    \\    pushal
    \\    movl %esp,%esi
    \\    movl $_observed_regs,%edi
    \\    movl $9,%ecx
    \\    cld
    \\    rep movsl
    \\    fxsave _observed_fx
    \\    leal 36(%esp),%esp
    \\    fxrstor _caller_fx
    \\    popal
    \\    popfl
    \\    ret
;
