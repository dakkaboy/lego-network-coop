#pragma once
#define AIM_TASK_INPUT_THUNK_ASM \
    "pushfl\n\tpushal\n\t" \
    "movl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $8,%esp\n\tpushl %edi\n\tpushl %esi\n\tcld\n\t" \
    "call _cadence_prepare_aim_task\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 0x10(%edi),%ecx\n\ttestl %ecx,%ecx\n\t" \
    "jmp *_aim_task_input_resume\n\t"

#define AIM_TASK_VISIBILITY_THUNK_ASM \
    "cmpb $0,0x42(%eax)\n\tpushfl\n\tpushal\n\t" \
    "movzbl 0x42(%eax),%edx\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $4,%esp\n\tpushl %edx\n\tpushl %edi\n\tpushl %esi\n\tcld\n\t" \
    "call _cadence_aim_task_visibility\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\ttestl %eax,%eax\n\tjz 1f\n\t" \
    "popal\n\tpopfl\n\tjmp *_aim_task_visible_resume\n\t" \
    "1: popal\n\tpopfl\n\tjmp *_aim_task_hidden_resume\n\t"
