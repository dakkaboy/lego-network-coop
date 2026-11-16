comptime {
    asm (
        \\.text
        \\.globl _decision_ammo_thunk
        \\_decision_ammo_thunk:
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
        \\    pushl $0x878dc1
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $4,%esp
        \\    testl %eax,%eax
        \\    jmp *_decision_ammo_resume
        \\    
        \\.text
        \\.globl _decision_compat_thunk
        \\_decision_compat_thunk:
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
        \\    pushl $0x878e02
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $8,%esp
        \\    testl %eax,%eax
        \\    jmp *_decision_compat_resume
        \\    
        \\.text
        \\.globl _decision_item_early_thunk
        \\_decision_item_early_thunk:
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
        \\    pushl $0x8770ca
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $4,%esp
        \\    testb %al,%al
        \\    jmp *_decision_item_early_resume
        \\    
        \\.text
        \\.globl _decision_item_late_thunk
        \\_decision_item_late_thunk:
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
        \\    pushl $0x8789b9
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $4,%esp
        \\    testb %al,%al
        \\    jmp *_decision_item_late_resume
        \\    
        \\.text
        \\.globl _decision_cancel_pre_thunk
        \\_decision_cancel_pre_thunk:
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
        \\    pushl $0x87844e
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    testb $8,0x300(%ebx)
        \\    jmp *_decision_cancel_pre_resume
        \\    
        \\.text
        \\.globl _decision_cancel_post_thunk
        \\_decision_cancel_post_thunk:
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
        \\    pushl $0x878472
        \\    pushl %ecx
        \\    pushl %edx
        \\    cld
        \\    call _decision_observer_checkpoint
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    addl $8,%esp
        \\    cmpl $2,%eax
        \\    jmp *_decision_cancel_post_resume
        \\    
    );
}
