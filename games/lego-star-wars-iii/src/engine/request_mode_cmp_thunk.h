#pragma once
#define REQUEST_MODE_CMP_THUNK_ASM \
    "cmpl $1,0xb0(%eax)\n\t" \
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
    "call _request_mode_cmp_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\t" \
    "cld\n\t" \
    "pushl 524(%esp)\n\t" \
    "call _SetLastError@4\n\t" \
    "cmpl $0,528(%esp)\n\t" \
    "je 1f\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "cmpl $1,520(%esp)\n\t" \
    "pushfl\n\t" \
    "popl %edx\n\t" \
    "andl $0x8d5,%edx\n\t" \
    "andl $0xfffff72a,32(%eax)\n\t" \
    "orl %edx,32(%eax)\n\t" \
    "1:\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_request_mode_cmp_resume\n\t"

#define REQUEST_PRIORITY_THUNK_ASM \
    "cmpw $0,0x76(%ebx)\n\t" \
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
    "call _request_priority_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\t" \
    "cld\n\t" \
    "pushl 524(%esp)\n\t" \
    "call _SetLastError@4\n\t" \
    "cmpl $0,528(%esp)\n\t" \
    "je 1f\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "cmpw $0,520(%esp)\n\t" \
    "pushfl\n\t" \
    "popl %edx\n\t" \
    "andl $0x8d5,%edx\n\t" \
    "andl $0xfffff72a,32(%eax)\n\t" \
    "orl %edx,32(%eax)\n\t" \
    "1:\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_request_priority_resume\n\t"

#define REQUEST_VISIBILITY_THUNK_ASM \
    "cmpb $0,0x42(%eax)\n\t" \
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
    "call _request_visibility_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "movl %eax,528(%esp)\n\t" \
    "cld\n\t" \
    "pushl 524(%esp)\n\t" \
    "call _SetLastError@4\n\t" \
    "cmpl $0,528(%esp)\n\t" \
    "je 1f\n\t" \
    "movl 512(%esp),%eax\n\t" \
    "cmpb $0,520(%esp)\n\t" \
    "pushfl\n\t" \
    "popl %edx\n\t" \
    "andl $0x8d5,%edx\n\t" \
    "andl $0xfffff72a,32(%eax)\n\t" \
    "orl %edx,32(%eax)\n\t" \
    "1:\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jne 2f\n\t" \
    "jmp *_request_visibility_continue\n\t" \
    "2: jmp *_request_visibility_skip\n\t"
