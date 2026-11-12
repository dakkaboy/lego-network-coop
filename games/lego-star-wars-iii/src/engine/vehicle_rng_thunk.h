#pragma once
#define VEHICLE_RNG_THUNK_ASM(target) \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\t" \
    "movl 0x24(%eax),%ecx\n\tsubl $5,%ecx\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $8,%esp\n\tpushl %ecx\n\tpushl %esi\n\tcld\n\t" \
    "call _physics_apply_vehicle_rng\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "jmp *" target "\n\t"
