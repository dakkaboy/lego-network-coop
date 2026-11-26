comptime {
    asm (
        \\.text
        \\.globl _reaction_choice_thunk
        \\_reaction_choice_thunk:
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
        \\    leal 116(%eax),%edx
        \\    movl 4(%eax),%ecx
        \\    subl $8,%esp
        \\    pushl %edx
        \\    pushl %ecx
        \\    cld
        \\    call _reaction_apply_choice
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    movl 0x50(%esp),%edi
        \\    cmpl $-1,%edi
        \\    jmp *_reaction_resume
        \\.globl _reaction_damage_draw_thunk
        \\_reaction_damage_draw_thunk:
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
        \\    subl $8,%esp
        \\    pushl 28(%eax)
        \\    pushl 4(%eax)
        \\    cld
        \\    call _reaction_damage_draw
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movl %eax,104(%edx)
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    fildl 0x44(%esp)
        \\    jmp *_reaction_damage_draw_resume
        \\.globl _reaction_projectile_damage_thunk
        \\_reaction_projectile_damage_thunk:
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
        \\    subl $8,%esp
        \\    pushl 16(%eax)
        \\    pushl 4(%eax)
        \\    cld
        \\    call _reaction_projectile_damage_amount
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    cmpl 16(%edx),%eax
        \\    je 1f
        \\    movl 8(%edx),%ecx
        \\    movl %eax,0x10(%ecx)
        \\    movl %eax,16(%edx)
        \\1:
        \\    fxrstor (%esp)
        \\    movl %edx,%esp
        \\    popal
        \\    popfl
        \\    movsbl 0xdde(%esi),%edi
        \\    jmp *_reaction_projectile_damage_resume
        \\.globl _reaction_lep_projectile_contact_thunk
        \\_reaction_lep_projectile_contact_thunk:
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
        \\    subl $12,%esp
        \\    pushl 4(%eax)
        \\    cld
        \\    call _reaction_lep_projectile_contact
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jnz 1f
        \\    popal
        \\    popfl
        \\    testl $0x1000,0xc80(%esi)
        \\    jmp *_reaction_lep_contact_resume
        \\1:
        \\    popal
        \\    popfl
        \\    jmp *_reaction_lep_contact_allowed
        \\.globl _reaction_arena_contact_thunk
        \\_reaction_arena_contact_thunk:
        \\pushl 8(%esp)
        \\pushl 8(%esp)
        \\call _reaction_arena_contact_hit
        \\addl $8,%esp
        \\testl %eax,%eax
        \\jz 1f
        \\ret
        \\1: addl $28,%esp
        \\jmp *_reaction_arena_skip_timer
    );
}
