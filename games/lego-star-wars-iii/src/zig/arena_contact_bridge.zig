comptime {
    asm (
        \\.text
        \\.globl _arena_contact_tap
        \\_arena_contact_tap:
        \\pushfl
        \\    pushl %eax
        \\    pushl %edx
        \\    movl _clonewars_arena_contact_count,%edx
        \\    andl $8191,%edx
        \\    shll $4,%edx
        \\    movl 0xfb4b6c,%eax
        \\    movl %eax,_clonewars_arena_contact+4(%edx)
        \\    movl 0xd3c(%ecx),%eax
        \\    movl %eax,_clonewars_arena_contact+8(%edx)
        \\    movl 0x40(%esi),%eax
        \\    movl %eax,_clonewars_arena_contact+12(%edx)
        \\    movl _clonewars_arena_contact_count,%eax
        \\    incl %eax
        \\    movl %eax,_clonewars_arena_contact(%edx)
        \\    movl %eax,_clonewars_arena_contact_count
        \\    popl %edx
        \\    popl %eax
        \\    popfl
        \\    fldz
        \\    fcomps 0xd3c(%ecx)
        \\    jmp *_arena_contact_resume
        \\    
    );
}
