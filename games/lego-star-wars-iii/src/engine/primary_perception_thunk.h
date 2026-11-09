#pragma once
#define PRIMARY_PERCEPTION_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "subl $12,%esp\n\tpushl 4(%eax)\n\tcall _cadence_primary_perception\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 0x164(%esi),%eax\n\tjmp *_primary_perception_resume\n\t"
