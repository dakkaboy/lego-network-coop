#pragma once
#define RTS_ORDER_READY_ASM \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
 "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
 "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
 "movl 28(%eax),%edx\n\tmovzbl 0x62(%edx),%edx\n\tsubl $8,%esp\n\tpushl %edx\n\tpushl 4(%eax)\n\t" \
 "call _native_rts_order_ready\n\taddl $16,%esp\n\tmovl 512(%esp),%edx\n\tmovb %al,24(%edx)\n\t" \
 "fxrstor (%esp)\n\tmovl %edx,%esp\n\tpopal\n\tpopfl\n\tshrb %cl\n\tjmp *_rts_order_ready_resume"
