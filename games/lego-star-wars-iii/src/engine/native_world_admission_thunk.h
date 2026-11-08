#pragma once
#define NATIVE_WORLD_ADMISSION_ASM(local) \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "subl $8,%esp\n\tpushl $" #local "\n\tpushl $0x888889\n\tcall _native_tick_decision\n\taddl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\tfxrstor (%esp)\n\tmovl 512(%esp),%edx\n\t" \
    "cmpl $0,528(%esp)\n\tje 1f\n\t" \
    "movl %edx,%esp\n\tpopal\n\tpopfl\n\tpushl $0xf\n\tmovl %edi,%ecx\n\tcall *_world_transition\n\tjmp *_world_exit_resume\n\t" \
    "1: movl %edx,%esp\n\tpopal\n\tpopfl\n\tcall *_world_continue\n\tjmp *_world_continue_resume\n\t"
