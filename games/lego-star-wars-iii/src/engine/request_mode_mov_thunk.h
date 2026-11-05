#pragma once
#define REQUEST_MODE_MOV_THUNK_ASM \
    "movl 0xb0(%eax),%eax\n\t" \
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
    "leal 520(%esp),%ecx\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "subl $8,%esp\n\t" \
    "pushl %ecx\n\t" \
    "pushl %eax\n\t" \
    "call _request_mode_mov_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\t" \
    "cld\n\t" \
    "pushl 524(%esp)\n\t" \
    "call _SetLastError@4\n\t" \
    "cmpl $0,528(%esp)\n\t" \
    "je 1f\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "movl 520(%esp),%edx\n\t" \
    "movl %edx,28(%eax)\n\t" \
    "1:\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_request_mode_mov_resume\n\t"
