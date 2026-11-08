#pragma once
#define AIM_BASE_INPUT_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\t" \
    "movl 0x34(%eax),%edx\n\tleal 0x38(%eax),%ebx\n\tmovl 24(%eax),%ecx\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $4,%esp\n\tpushl %ebx\n\tpushl %edx\n\tpushl %ecx\n\tcld\n\t" \
    "call _cadence_prepare_aim_base\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "flds 0x14(%esp)\n\tmovl 0xc(%esp),%eax\n\tjmp *_aim_base_input_resume\n\t"
