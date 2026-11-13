#pragma once

// Preserve the native TEST's branch flags without changing receiver state or live FP registers.
#define SPELLIT_RECEIVER_FLAGS_ASM(site,resume) \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
 "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
 "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\t" \
 "subl $8,%esp\n\tpushl $" #site "\n\tpushl 24(%eax)\n\tcall _native_spellit_receiver_flags\n\taddl $16,%esp\n\t" \
 "testb $4,%al\n\tpushfl\n\tpopl %eax\n\tmovl 512(%esp),%edx\n\t" \
 "andl $0xfffff73a,32(%edx)\n\tandl $0x8c5,%eax\n\torl %eax,32(%edx)\n\t" \
 "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\tjmp *_" #resume
