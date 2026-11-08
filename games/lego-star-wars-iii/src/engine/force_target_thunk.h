#pragma once
#define FORCE_TARGET_VISIBILITY_THUNK_ASM \
    "cmpb $0,0x42(%eax)\n\tpushfl\n\tpushal\n\t" \
    "movzbl 0x42(%eax),%ecx\n\tmovl 0x68(%esp),%ebx\n\t" \
    "movl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "pushl %ecx\n\tpushl %ebx\n\tpushl %edx\n\tpushl %edi\n\tcld\n\t" \
    "call _cadence_force_target_visibility\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\ttestl %eax,%eax\n\tjz 1f\n\t" \
    "popal\n\tpopfl\n\tjmp *_force_target_visible_resume\n\t" \
    "1: popal\n\tpopfl\n\tjmp *_force_target_hidden_resume\n\t"
