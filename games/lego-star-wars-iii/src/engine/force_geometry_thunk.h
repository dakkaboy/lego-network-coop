#pragma once
#define FORCE_GEOMETRY_INPUT_THUNK_ASM \
    "leal -32(%esp),%esp\n\tpushfl\n\tpushal\n\t" \
    "movl 72(%esp),%eax\n\tleal 44(%esp),%ebx\n\t" \
    "movl (%eax),%ecx\n\tmovl %ecx,(%ebx)\n\tmovl 4(%eax),%ecx\n\tmovl %ecx,4(%ebx)\n\t" \
    "movl 8(%eax),%ecx\n\tmovl %ecx,8(%ebx)\n\tmovl 76(%esp),%eax\n\t" \
    "movl (%eax),%ecx\n\tmovl %ecx,12(%ebx)\n\tmovl 4(%eax),%ecx\n\tmovl %ecx,16(%ebx)\n\t" \
    "movl 8(%eax),%ecx\n\tmovl %ecx,20(%ebx)\n\t" \
    "movl 8(%esp),%edx\n\tmovl (%esp),%ecx\n\tmovl 152(%esp),%edi\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "pushl %ebx\n\tpushl %edi\n\tpushl %edx\n\tpushl %ecx\n\tcld\n\t" \
    "call _cadence_force_geometry_input\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "pushl 44(%esp)\n\tleal 24(%esp),%edx\n\tpushl %edx\n\t" \
    "leal 16(%esp),%eax\n\tpushl %eax\n\tcall *_force_distance_native\n\t" \
    "leal 44(%esp),%esp\n\tret\n\t"
