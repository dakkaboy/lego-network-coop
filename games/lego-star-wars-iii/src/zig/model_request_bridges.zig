comptime {
    asm (
        \\.text
        \\.globl _model_source_thunk
        \\_model_source_thunk:
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl %esp,%edx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %edx
        \\    pushl %eax
        \\    call _request_mode_source_checkpoint
        \\    addl $16,%esp
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    fld %st(0)
        \\    flds 0x20(%esp)
        \\    jmp *_model_input_resume
        \\.globl _model_cmp_thunk
        \\_model_cmp_thunk:
        \\cmpl $1,0xb0(%eax)
        \\    pushfl
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    leal 520(%esp),%ecx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %eax
        \\    call _request_mode_cmp_checkpoint
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    cmpl $0,528(%esp)
        \\    je 1f
        \\    movl 512(%esp),%eax
        \\    cmpl $1,520(%esp)
        \\    pushfl
        \\    popl %edx
        \\    andl $0x8d5,%edx
        \\    andl $0xfffff72a,32(%eax)
        \\    orl %edx,32(%eax)
        \\    1:
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_request_mode_cmp_resume
        \\.globl _model_priority_thunk
        \\_model_priority_thunk:
        \\cmpw $0,0x76(%ebx)
        \\    pushfl
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    leal 520(%esp),%ecx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %eax
        \\    call _request_priority_checkpoint
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    cmpl $0,528(%esp)
        \\    je 1f
        \\    movl 512(%esp),%eax
        \\    cmpw $0,520(%esp)
        \\    pushfl
        \\    popl %edx
        \\    andl $0x8d5,%edx
        \\    andl $0xfffff72a,32(%eax)
        \\    orl %edx,32(%eax)
        \\    1:
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_request_priority_resume
        \\.globl _model_hidden_model_thunk
        \\_model_hidden_model_thunk:
        \\testl %edx,0x4c(%ebx)
        \\    pushfl
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    leal 520(%esp),%ecx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %eax
        \\    call _request_hidden_model_checkpoint
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    cmpl $0,528(%esp)
        \\    je 1f
        \\    movl 512(%esp),%eax
        \\    cmpb $0,520(%esp)
        \\    pushfl
        \\    popl %edx
        \\    andl $0x8d5,%edx
        \\    andl $0xfffff72a,32(%eax)
        \\    orl %edx,32(%eax)
        \\    1:
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jne 2f
        \\    jmp *_request_hidden_model_continue
        \\    2: jmp *_request_visibility_skip
        \\.globl _model_visibility_thunk
        \\_model_visibility_thunk:
        \\cmpb $0,0x42(%eax)
        \\    pushfl
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    leal 520(%esp),%ecx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %eax
        \\    call _request_visibility_checkpoint
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    cmpl $0,528(%esp)
        \\    je 1f
        \\    movl 512(%esp),%eax
        \\    cmpb $0,520(%esp)
        \\    pushfl
        \\    popl %edx
        \\    andl $0x8d5,%edx
        \\    andl $0xfffff72a,32(%eax)
        \\    orl %edx,32(%eax)
        \\    1:
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jne 2f
        \\    jmp *_request_visibility_continue
        \\    2: jmp *_request_visibility_skip
        \\.globl _model_mov_thunk
        \\_model_mov_thunk:
        \\movl 0xb0(%eax),%eax
        \\    pushfl
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    leal 520(%esp),%ecx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %ecx
        \\    pushl %eax
        \\    call _request_mode_mov_checkpoint
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    cmpl $0,528(%esp)
        \\    je 1f
        \\    movl 512(%esp),%eax
        \\    movl 520(%esp),%edx
        \\    movl %edx,28(%eax)
        \\    1:
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_request_mode_mov_resume
        \\.globl _model_join_thunk
        \\_model_join_thunk:
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
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl %esp,%edx
        \\    movl 512(%esp),%eax
        \\    subl $8,%esp
        \\    pushl %edx
        \\    pushl %eax
        \\    call _request_mode_join_checkpoint
        \\    addl $16,%esp
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    movl 8(%ebx),%eax
        \\    testl %eax,%eax
        \\    jmp *_request_mode_join_resume
    );
}
