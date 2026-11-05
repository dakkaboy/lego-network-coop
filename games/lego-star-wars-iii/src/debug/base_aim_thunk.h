#pragma once
#define BASE_AIM_THUNK_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
 "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\t" \
 "movl %esp,%edx\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl 524(%esp)\n\tcall _base_aim_checkpoint\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\t" \
 "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\tcmpw $-1,0x2f4(%ebx)\n\tjmp *_base_aim_resume\n\t"
