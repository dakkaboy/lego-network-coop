pub extern fn native_action_probe(usize, usize, u32) void;
pub extern fn native_action_probe_original() void;
pub extern fn native_action_probe_resume() void;
pub export var native_action_probe_regs: [9]u32 = @splat(0);
pub export var native_action_probe_fx: [512]u8 align(16) = @splat(0);
export var native_action_probe_saved_fx: [512]u8 align(16) = @splat(0);
export var native_action_probe_entry: usize = 0;
export var native_action_probe_state: usize = 0;
export var native_action_probe_next: u32 = 0;
comptime {
    asm (
        \\.text
        \\_native_action_probe:
        \\pushfl
        \\pushal
        \\movl 40(%esp),%eax
        \\movl %eax,_native_action_probe_entry
        \\movl 44(%esp),%eax
        \\movl %eax,_native_action_probe_state
        \\movl 48(%esp),%eax
        \\movl %eax,_native_action_probe_next
        \\fxsave _native_action_probe_saved_fx
        \\fninit
        \\fldpi
        \\fld1
        \\pcmpeqd %xmm0,%xmm0
        \\pxor %xmm1,%xmm1
        \\movdqa %xmm0,%xmm2
        \\movdqa %xmm1,%xmm3
        \\movdqa %xmm0,%xmm4
        \\movdqa %xmm1,%xmm5
        \\movdqa %xmm0,%xmm6
        \\movdqa %xmm1,%xmm7
        \\pushl _native_action_probe_next
        \\pushl _native_action_probe_state
        \\movl $0x12345678,%eax
        \\movl $0x87654321,%ecx
        \\movl $0x13579bdf,%edx
        \\movl $0x2468ace0,%ebx
        \\movl $0x11223344,%esi
        \\movl $0x55667788,%edi
        \\movl $0x19283746,%ebp
        \\pushl $0x646
        \\popfl
        \\call *_native_action_probe_entry
        \\leal 8(%esp),%esp
        \\fxrstor _native_action_probe_saved_fx
        \\popal
        \\popfl
        \\ret
        \\_native_action_probe_original:
        \\pushl %esi
        \\movl 8(%esp),%esi
        \\testl %esi,%esi
        \\_native_action_probe_resume:
        \\fxsave _native_action_probe_fx
        \\pushfl
        \\pushal
        \\movl %esp,%esi
        \\movl $_native_action_probe_regs,%edi
        \\movl $9,%ecx
        \\cld
        \\rep movsl
        \\popal
        \\popfl
        \\popl %esi
        \\ret
    );
}
