#pragma once
#define POSE_OBSERVER_THUNK_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tsubl $12,%esp\n\tpushl 524(%esp)\n\tcall _pose_observer_record\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\tret\n\t"
