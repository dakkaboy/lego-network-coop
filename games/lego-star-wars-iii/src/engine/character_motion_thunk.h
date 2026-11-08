#pragma once
#define CHARACTER_MOTION_INPUT_THUNK_ASM \
    "leal -16(%esp),%esp\n\tpushfl\n\tpushal\n\t" \
    "movl 56(%esp),%eax\n\tleal 36(%esp),%edi\n\t" \
    "movl (%eax),%edx\n\tmovl %edx,(%edi)\n\tmovl 4(%eax),%edx\n\tmovl %edx,4(%edi)\n\t" \
    "movl 8(%eax),%edx\n\tmovl %edx,8(%edi)\n\tmovl 12(%eax),%edx\n\tmovl %edx,12(%edi)\n\t" \
    "movl 16(%esp),%ebx\n\tmovl 24(%esp),%ecx\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $4,%esp\n\tpushl %edi\n\tpushl %ecx\n\tpushl %ebx\n\tcld\n\t" \
    "call _cadence_character_motion_input\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "pushl %esp\n\tcall *_character_velocity_native\n\t" \
    "movl 20(%esp),%eax\n\tleal 16(%esp),%esp\n\tret $4\n\t"
