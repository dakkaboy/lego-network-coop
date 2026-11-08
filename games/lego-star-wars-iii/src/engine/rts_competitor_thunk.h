#pragma once
#define RTS_COMPETITOR_INPUT_THUNK_ASM \
    "pushfl\n\tpushal\n\t" \
    "movl %esp,%eax\n\tleal 40(%eax),%edx\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $8,%esp\n\tpushl %edx\n\tpushl %ecx\n\tcld\n\t" \
    "call _cadence_prepare_rts_competitor\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "pushl %ebp\n\tmovl %esp,%ebp\n\tandl $-16,%esp\n\t" \
    "jmp *_rts_competitor_input_resume\n\t"
