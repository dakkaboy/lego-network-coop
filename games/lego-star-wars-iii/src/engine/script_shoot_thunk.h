#pragma once
#define SCRIPT_SHOOT_VISIBILITY_THUNK_ASM \
    "pushfl\n\tpushal\n\t" \
    "movzbl 0x42(%eax),%ecx\n\tmovl %esp,%edx\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %edx,512(%esp)\n\t" \
    "fxsave (%esp)\n\tmovl %fs:0x34,%edx\n\tmovl %edx,520(%esp)\n\t" \
    "fninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $12,%esp\n\tpushl %ecx\n\tpushl %ebp\n\tpushl %eax\n\tpushl %esi\n\tpushl %edi\n\tcld\n\t" \
    "call _cadence_script_shoot_visibility\n\taddl $32,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 520(%esp),%edx\n\tmovl %edx,%fs:0x34\n\t" \
    "movl 512(%esp),%esp\n\tpushl 32(%esp)\n\tpopfl\n\tcmpb $0,%al\n\tpushfl\n\tpopl 32(%esp)\n\t" \
    "popal\n\tpopfl\n\tjnz 1f\n\tjmp *_script_shoot_hidden_resume\n\t" \
    "1: jmp *_script_shoot_visible_resume\n\t"
