#pragma once
#define STEERING_THUNK_ASM \
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
    "movl 64(%eax),%edx\n\t" \
    "movl 16(%eax),%ecx\n\t" \
    "subl $8,%esp\n\t" \
    "pushl %edx\n\t" \
    "pushl %ecx\n\t" \
    "cld\n\t" \
    "call _steering_apply_intent\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "testl $0x200,0x50(%ebx)\n\t" \
    "jmp *_steering_resume\n\t"

#define STEERING_MODEL_THUNK_ASM \
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
    "subl $4,%esp\n\t" \
    "pushl 20(%eax)\n\t" \
    "pushl 4(%eax)\n\t" \
    "pushl 16(%eax)\n\t" \
    "cld\n\t" \
    "call _steering_model_witness\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "testl $0x800000,0xc7c(%ebx)\n\t" \
    "jmp *_steering_model_resume\n\t"
