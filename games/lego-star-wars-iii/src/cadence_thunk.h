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
