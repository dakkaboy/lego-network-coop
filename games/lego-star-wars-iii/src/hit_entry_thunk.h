#pragma once
#define HIT_ENTRY_THUNK_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
 "call _GetLastError@0\n\tmovl %eax,524(%esp)\n\tmovl %esp,%edx\n\tmovl 512(%esp),%eax\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl %eax\n\tcall _hit_entry_checkpoint\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\tjmp *_hit_entry_original\n\t"
