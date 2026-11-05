#pragma once
#define INTENT_TRANSFORMED_THUNK_ASM \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $3\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "addl $16,%esp\n\t" \
    "movw %ax,0x26(%esi)\n\t" \
    "jmp *_intent_transformed_resume\n\t"
#define INTENT_MODEL_THUNK_ASM \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $4\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "addl $8,%esp\n\t" \
    "fldz\n\t" \
    "jmp *_intent_model_resume\n\t"
#define INTENT_SPECIAL_THUNK_ASM \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $5\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "addl $8,%esp\n\t" \
    "fldz\n\t" \
    "jmp *_intent_special_resume\n\t"
#define INTENT_DUMMY_THUNK_ASM \
    "movw %ax,0x26(%esi)\n\t" \
    "fsts 0x28(%esi)\n\t" \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $6\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_intent_dummy_resume\n\t"
#define INTENT_PREVIOUS_THUNK_ASM \
    "fstps 0x38(%esi)\n\t" \
    "movw %cx,0x5a(%esi)\n\t" \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $7\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_intent_previous_resume\n\t"
#define INTENT_LAST_THUNK_ASM \
    "fstps 0x34(%esi)\n\t" \
    "movw %ax,0x5e(%esi)\n\t" \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $8\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "jmp *_intent_last_resume\n\t"
#define INTENT_DEFAULT_THUNK_ASM \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $9\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "orl $0x800000,0x8d8(%esi)\n\t" \
    "jmp *_intent_default_resume\n\t"
#define INTENT_CALLBACK_THUNK_ASM \
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
    "leal 36(%eax),%edx\n\t" \
    "subl $4,%esp\n\t" \
    "pushl %eax\n\t" \
    "pushl %edx\n\t" \
    "pushl $10\n\t" \
    "cld\n\t" \
    "call _intent_frame_checkpoint\n\t" \
    "addl $16,%esp\n\t" \
    "fxrstor (%esp)\n\t" \
    "movl 512(%esp),%esp\n\t" \
    "popal\n\t" \
    "popfl\n\t" \
    "fldz\n\t" \
    "fcoms 0x7ac(%esi)\n\t" \
    "jmp *_intent_callback_resume\n\t"
