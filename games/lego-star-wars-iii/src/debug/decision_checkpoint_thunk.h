#pragma once
#define DECISION_CHECKPOINT_RAW(address,resume,replay) \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\t" \
    "fxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "leal 36(%eax),%edx\n\tmovl 28(%eax),%ecx\n\t" \
    "pushl %eax\n\tpushl $" address "\n\tpushl %ecx\n\tpushl %edx\n\tcld\n\t" \
    "call _decision_observer_checkpoint\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    replay "\n\tjmp *_" resume "\n\t"

#define DECISION_CHECKPOINT_BODY(address,cleanup,resume,test) DECISION_CHECKPOINT_RAW(address,resume,"addl $" cleanup ",%esp\n\t" test)
#define DECISION_CANCEL_PRE_ASM(resume) DECISION_CHECKPOINT_RAW("0x87844e",resume,"testb $8,0x300(%ebx)")
#define DECISION_CANCEL_POST_ASM(resume) DECISION_CHECKPOINT_RAW("0x878472",resume,"addl $8,%esp\n\tcmpl $2,%eax")

#define DECISION_CHECKPOINT_ASM(address,cleanup,resume) DECISION_CHECKPOINT_BODY(address,cleanup,resume,"testl %eax,%eax")
#define DECISION_CHECKPOINT_AL_ASM(address,cleanup,resume) DECISION_CHECKPOINT_BODY(address,cleanup,resume,"testb %al,%al")
