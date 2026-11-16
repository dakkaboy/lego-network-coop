comptime {
    asm (
        \\.text
        \\.globl _entity_roster_thunk
        \\_entity_roster_thunk:
        \\pushfl
        \\    pushal
        \\    pushl %esp
        \\    cld
        \\    call _entity_roster_constructor
        \\    addl $4,%esp
        \\    movl %eax,28(%esp)
        \\    popal
        \\    popfl
        \\    ret
        \\.globl _entity_hub_thunk
        \\_entity_hub_thunk:
        \\pushfl
        \\    pushal
        \\    pushl %esp
        \\    cld
        \\    call _entity_hub_constructor
        \\    addl $4,%esp
        \\    movl %eax,28(%esp)
        \\    popal
        \\    popfl
        \\    ret
        \\.globl _entity_create_placement_thunk
        \\_entity_create_placement_thunk:
        \\pushl 0x1c(%esp)
        \\pushl 0x1c(%esp)
        \\call _entity_create_placement
        \\addl $8,%esp
        \\ret
    );
}
