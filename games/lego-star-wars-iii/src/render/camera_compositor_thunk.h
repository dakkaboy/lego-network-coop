#pragma once
#define CAMERA_COMPOSITOR_THUNK_ASM(nativeSymbol,helperSymbol) \
 "pushl $0\n\tpushl %ecx\n\t" \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tmovl 512(%esp),%edx\n\tleal 40(%edx),%ecx\n\tsubl $12,%esp\n\tpushl %ecx\n\tpushl $0\n\tpushl 28(%edx)\n\tpushl 48(%edx)\n\tpushl 36(%edx)\n\tcall " helperSymbol "\n\taddl $32,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
 "pushl 12(%esp)\n\tcall *" nativeSymbol "\n\t" \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tmovl 512(%esp),%edx\n\tleal 40(%edx),%ecx\n\tsubl $12,%esp\n\tpushl %ecx\n\tpushl $1\n\tpushl 28(%edx)\n\tpushl 48(%edx)\n\tpushl 36(%edx)\n\tcall " helperSymbol "\n\taddl $32,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
 "leal 8(%esp),%esp\n\tret $4\n\t"
