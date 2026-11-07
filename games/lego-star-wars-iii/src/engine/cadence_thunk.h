#pragma once
#define CADENCE_THUNK_ASM \
    "pushfl\n\t" \
    "pushal\n\t" \
    "movl %esp,%eax\n\t" \
    "subl $544,%esp\n\t" \
    "andl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\t" \
    "fninit\n\t" \
    "movl $0x1f80,516(%esp)\n\t" \
    "ldmxcsr 516(%esp)\n\t" \
    "leal 56(%eax),%edx\n\t" \
    "movl (%eax),%ecx\n\t" \
    "subl $8,%esp\n\t" \
    "pushl %edx\n\t" \
    "pushl %ecx\n\t" \
    "cld\n\t" \
    "call _cadence_apply_period\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "movl 0x14(%esp),%ecx\n\t" \
    "movb %cl,0x138e(%edi)\n\t" \
    "jmp *_cadence_resume\n\t"

#define FIRE_TASK_GATE_THUNK_ASM \
    "pushfl\n\t" \
    "pushal\n\t" \
    "xorl %edx,%edx\n\t" \
    "movl 8(%ebx),%eax\n\t" \
    "testl %eax,%eax\n\t" \
    "jz 1f\n\t" \
    "cmpb $0,0x42(%eax)\n\t" \
    "jne 2f\n\t" \
    "1: testb $8,4(%esi)\n\t" \
    "jz 3f\n\t" \
    "2: movl $1,%edx\n\t" \
    "3: movl %esp,%eax\n\t" \
    "subl $544,%esp\n\t" \
    "andl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\t" \
    "fninit\n\t" \
    "movl $0x1f80,516(%esp)\n\t" \
    "ldmxcsr 516(%esp)\n\t" \
    "leal 0x14(%ebp),%ecx\n\t" \
    "pushl %ecx\n\t" \
    "pushl %edx\n\t" \
    "pushl %esi\n\t" \
    "pushl %ebx\n\t" \
    "cld\n\t" \
    "call _cadence_apply_fire_task_gate\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "testl %eax,%eax\n\t" \
    "jz 4f\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_fire_task_gate_allow\n\t" \
    "4: popal\n\t" \
    "popfl\n\t" \
    "jmp *_fire_task_gate_skip\n\t"

#define ATTACK_SUPPORT_THUNK_ASM \
    "pushfl\n\t" \
    "pushal\n\t" \
    "movl %esp,%eax\n\t" \
    "subl $544,%esp\n\t" \
    "andl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\t" \
    "fninit\n\t" \
    "movl $0x1f80,516(%esp)\n\t" \
    "ldmxcsr 516(%esp)\n\t" \
    "subl $8,%esp\n\t" \
    "leal 120(%eax),%edx\n\t" \
    "pushl %edx\n\t" \
    "pushl 16(%eax)\n\t" \
    "cld\n\t" \
    "call _cadence_apply_attack_support\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "movl 0x54(%esp),%esi\n\t" \
    "movl 0x24(%ebp),%ecx\n\t" \
    "jmp *_attack_support_resume\n\t"
