#pragma once
#define NATIVE_ROSTER_SOURCE_THUNK_ASM \
    "pushfl\n\tpushal\n\tpushl %esp\n\tcld\n\t" \
    "call _entity_roster_constructor\n\taddl $4,%esp\n\t" \
    "movl %eax,28(%esp)\n\tpopal\n\tpopfl\n\tret\n\t"
#define NATIVE_HUB_SOURCE_THUNK_ASM \
    "pushfl\n\tpushal\n\tpushl %esp\n\tcld\n\t" \
    "call _entity_hub_constructor\n\taddl $4,%esp\n\t" \
    "movl %eax,28(%esp)\n\tpopal\n\tpopfl\n\tret\n\t"
