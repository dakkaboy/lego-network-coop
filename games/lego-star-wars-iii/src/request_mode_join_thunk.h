#pragma once
#define REQUEST_MODE_JOIN_THUNK_ASM \
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
    "cld\n\t" \
    "call _GetLastError@0\n\t" \
    "movl %eax,524(%esp)\n\t" \
    "movl %esp,%edx\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "subl $8,%esp\n\t" \
    "pushl %edx\n\t" \
    "pushl %eax\n\t" \
    "call _request_mode_join_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "cld\n\t" \
    "pushl 524(%esp)\n\t" \
    "call _SetLastError@4\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "movl 8(%ebx),%eax\n\t" \
    "testl %eax,%eax\n\t" \
    "jmp *_request_mode_join_resume\n\t"
