#pragma once
#define NATIVE_FLOW_REQUEST_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
    "subl $12,%esp\n\tpushl 4(%eax)\n\tcall _native_flow_request\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 0x60(%esi),%eax\n\tcmpl %edi,%eax\n\tjmp *_flow_request_resume\n\t"
