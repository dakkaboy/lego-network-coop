#pragma once
#define CONSTRUCTOR_QUERY_CONTEXT_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tmovl %esp,%ecx\n\tmovl 512(%esp),%edx\n\tsubl $8,%esp\n\tpushl %ecx\n\tpushl %edx\n\tcall _constructor_query_checkpoint\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"
#define CONSTRUCTOR_QUERY_POST_ASM \
 "pushfl\n\tcmpl $0,_clonewars_constructor_query_enabled\n\tje 1f\n\tcmpl $0,_clonewars_constructor_query_active_scopes\n\tje 2f\n\tpopfl\n\t" \
 CONSTRUCTOR_QUERY_CONTEXT_ASM \
 "jmp 3f\n\t2: lock incl _clonewars_constructor_query_debug\n\t1: popfl\n\t3: testb %al,%al\n\tjz 4f\n\tjmp *_constructor_query_success\n\t4: jmp *_constructor_query_miss\n\t"
