#pragma once
#define EFFECT_BIRTH_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $12,%esp\n\tpushl 28(%eax)\n\tcld\n\tcall _physics_effect_birth\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 0x208(%esp),%ecx\n\tjmp *_effect_birth_resume\n\t"
