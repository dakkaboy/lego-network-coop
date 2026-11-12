#pragma once
// At 905F33 the native part iterator and handle table still live in the caller's stack frame.
#define BREAKUP_LAUNCH_THUNK_ASM \
    "pushfl\n\t" \
    "pushal\n\t" \
    "movl %esp,%eax\n\t" \
    "movl 0x64(%eax),%ecx\n\t" \
    "xorl %edx,%edx\n\t" \
    "cmpl $40,%ecx\n\t" \
    "jae 1f\n\t" \
    "movl 0x3c0(%eax,%ecx,4),%edx\n\t" \
    "1: subl $544,%esp\n\t" \
    "andl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\t" \
    "fninit\n\t" \
    "movl $0x1f80,516(%esp)\n\t" \
    "ldmxcsr 516(%esp)\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "pushl 0x5c(%eax)\n\t" \
    "pushl 0x54(%eax)\n\t" \
    "pushl %edx\n\t" \
    "pushl %esi\n\t" \
    "cld\n\t" \
    "call _physics_apply_breakup_launch\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_breakup_launch_native\n\t"
