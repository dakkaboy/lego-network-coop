#pragma once
#define CONSTRUCTOR_OBSERVER_THUNK_ASM(helperSymbol) \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tmovl 512(%esp),%edx\n\tmovl 40(%edx),%eax\n\tmovl 44(%edx),%ecx\n\tsubl $8,%esp\n\tpushl %ecx\n\tpushl %eax\n\tcall " helperSymbol "\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\tret\n\t"
