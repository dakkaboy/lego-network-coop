#pragma once
#define SPELLIT_NODE_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tmovl 8(%eax),%ecx\n\tmovl 4(%eax),%edx\n\t" \
    "movl (%eax),%ebx\n\tleal 148(%eax),%esi\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "pushl %esi\n\tpushl %ebx\n\tpushl %edx\n\tpushl %ecx\n\tcld\n\tcall _cadence_spellit_node\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 0x70(%esp),%eax\n\tmovl 0x74(%esp),%ecx\n\tjmp *_spellit_node_resume\n\t"

#define SPELLIT_PREPARE_THUNK_ASM \
    "pushfl\n\tpushal\n\tmovl %esp,%eax\n\tmovl 4(%eax),%ecx\n\tmovl (%eax),%edx\n\t" \
    "movl 8(%eax),%ebx\n\tleal 52(%eax),%esi\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "pushl %esi\n\tpushl %ebx\n\tpushl %edx\n\tpushl %ecx\n\tcld\n\tcall _cadence_spellit_prepare\n\taddl $16,%esp\n\t" \
    "fxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "movl 8(%esi),%eax\n\ttestl %eax,%eax\n\tjmp *_spellit_prepare_resume\n\t"

#define SPELLIT_OPERAND_SAVE_ASM(local_expression,kind) \
    "pushfl\n\tpushal\n\t" local_expression \
    "movl 8(%esp),%ecx\n\tmovl %esp,%eax\n\tsubl $544,%esp\n\tandl $-16,%esp\n\t" \
    "movl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\tmovl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\t" \
    "subl $4,%esp\n\tpushl %ebx\n\tpushl $" #kind "\n\tpushl %ecx\n\tcld\n\t" \
    "call _cadence_spellit_operand\n\taddl $16,%esp\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\t"

#define SPELLIT_HEADING_THUNK_ASM(model_register,resume) \
    SPELLIT_OPERAND_SAVE_ASM("movzwl 0x40(" model_register "),%ebx\n\t",0) \
    "movl %eax,28(%esp)\n\tpopal\n\tpopfl\n\tjmp *_" #resume "\n\t"

#define SPELLIT_HEIGHT_THUNK_ASM \
    SPELLIT_OPERAND_SAVE_ASM("movl 0x28(%eax),%ebx\n\t",1) \
    "movl %eax,12(%esp)\n\tflds 12(%esp)\n\tpopal\n\tpopfl\n\t" \
    "movl %ecx,0x2c(%esp)\n\tjmp *_spellit_height_resume\n\t"

#define SPELLIT_POSITION_THUNK_ASM \
    "leal -16(%esp),%esp\n\tpushfl\n\tpushal\n\tmovl 60(%esp),%eax\n\tleal 40(%esp),%ebx\n\t" \
    "movl (%eax),%ecx\n\tmovl %ecx,(%ebx)\n\tmovl 4(%eax),%ecx\n\tmovl %ecx,4(%ebx)\n\t" \
    "movl 8(%eax),%ecx\n\tmovl %ecx,8(%ebx)\n\tmovl 8(%esp),%ecx\n\tmovl %esp,%eax\n\t" \
    "subl $544,%esp\n\tandl $-16,%esp\n\tmovl %eax,512(%esp)\n\tfxsave (%esp)\n\tfninit\n\t" \
    "movl $0x1f80,516(%esp)\n\tldmxcsr 516(%esp)\n\tsubl $8,%esp\n\tpushl %ebx\n\tpushl %ecx\n\tcld\n\t" \
    "call _cadence_spellit_position\n\taddl $16,%esp\n\tfxrstor (%esp)\n\tmovl 512(%esp),%esp\n\tpopal\n\tpopfl\n\t" \
    "pushl 28(%esp)\n\tleal 8(%esp),%edx\n\tpushl %edx\n\tpushl 28(%esp)\n\t" \
    "call *_spellit_distance_native\n\tleal 28(%esp),%esp\n\tret\n\t"
