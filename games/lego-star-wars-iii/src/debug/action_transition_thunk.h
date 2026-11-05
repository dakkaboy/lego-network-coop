#pragma once
#define ACTION_TRANSITION_CONTEXT(helper) \
 "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tcld\n\tcall _GetLastError@0\n\tmovl %eax,524(%esp)\n\tsubl $12,%esp\n\tpushl 524(%esp)\n\tcall " helper "\n\taddl $16,%esp\n\tcld\n\tpushl 524(%esp)\n\tcall _SetLastError@4\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t"

#define ACTION_TRANSITION_ENTRY_ASM \
 "pushfl\n\tcmpl $0,_clonewars_action_transition_enabled\n\tje 1f\n\tpopfl\n\t" \
 ACTION_TRANSITION_CONTEXT("_action_transition_enter") \
 "jmp *_action_transition_original\n\t1: popfl\n\tjmp *_action_transition_original\n\t"

/* PUSHAD's saved ESP is ignored by POPAD, so it can carry the continuation
   without replacing the original native flags saved at post-entry ESP-4. */
#define ACTION_TRANSITION_RETURN_ASM \
 ACTION_TRANSITION_CONTEXT("_action_transition_leave") \
 "jmp *-24(%esp)\n\t"
