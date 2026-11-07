#pragma once
#define NATIVE_TICK_GATE_ASM(site,resume) \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "subl $12,%esp\n\tpushl $" #site "\n\tcall _native_tick_gate\n\taddl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\tfxrstor (%esp)\n\tmovl 512(%esp),%edx\n\t" \
    "pushl 32(%edx)\n\tpopfl\n\tcmpb $0,528(%esp)\n\tpushfl\n\tpopl 32(%edx)\n\t" \
    "movl %edx,%esp\n\tpopal\n\tpopfl\n\tjmp *_" #resume "\n\t"
