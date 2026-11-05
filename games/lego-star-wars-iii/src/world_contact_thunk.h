#pragma once
#define WORLD_CONTACT_QUERY_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "leal 36(%eax),%edx\n\tmovl 28(%eax),%ecx\n\t" \
    "pushl %eax\n\tpushl $0x81f7bf\n\tpushl %ecx\n\tpushl %edx\n\tcld\n\t" \
    "call _world_contact_query_checkpoint\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "addl $24,%esp\n\ttestl %eax,%eax\n\tjmp *_world_contact_query_resume\n\t"
