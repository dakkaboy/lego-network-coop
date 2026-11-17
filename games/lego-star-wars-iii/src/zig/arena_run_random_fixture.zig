pub extern fn arena_random_probe() void;
pub extern fn arena_random_probe_original() void;
pub extern fn arena_random_probe_native() void;
pub export var arena_random_probe_entry: usize = 0;
pub export var arena_random_probe_controller: usize = 0;
pub export var arena_random_probe_calls: u32 = 0;
pub export var arena_random_probe_regs: [9]u32 = @splat(0);
pub export var arena_random_probe_fx: [512]u8 align(16) = @splat(0);
pub export var arena_random_probe_cw: u32 = 0x37f;
pub export var arena_random_probe_mxcsr: u32 = 0x1f80;
pub export var arena_random_probe_xmm: [128]u8 align(16) = @splat(0);
export var arena_random_probe_saved_fx: [512]u8 align(16) = @splat(0);
comptime {
    asm (
        \\.text
        \\_arena_random_probe_native:
        \\incl _arena_random_probe_calls
        \\movl 0xe637b4,%eax
        \\imull $0x24cd,%eax,%eax
        \\incl %eax
        \\andl $65535,%eax
        \\movl %eax,0xe637b4
        \\movl $321,%fs:0x34
        \\ret
        \\_arena_random_probe_original:
        \\call _arena_random_probe_native
        \\ret
        \\_arena_random_probe:
        \\pushfl
        \\pushal
        \\fxsave _arena_random_probe_saved_fx
        \\fninit
        \\fldcw _arena_random_probe_cw
        \\ldmxcsr _arena_random_probe_mxcsr
        \\fldpi
        \\fld1
        \\movdqa _arena_random_probe_xmm,%xmm0
        \\movdqa _arena_random_probe_xmm+16,%xmm1
        \\movdqa _arena_random_probe_xmm+32,%xmm2
        \\movdqa _arena_random_probe_xmm+48,%xmm3
        \\movdqa _arena_random_probe_xmm+64,%xmm4
        \\movdqa _arena_random_probe_xmm+80,%xmm5
        \\movdqa _arena_random_probe_xmm+96,%xmm6
        \\movdqa _arena_random_probe_xmm+112,%xmm7
        \\movl $0x87654321,%ecx
        \\movl $0x13579bdf,%edx
        \\movl $0x2468ace0,%ebx
        \\movl _arena_random_probe_controller,%esi
        \\movl $0x55667788,%edi
        \\movl $0x19283746,%ebp
        \\pushl $0x646
        \\popfl
        \\call *_arena_random_probe_entry
        \\fxsave _arena_random_probe_fx
        \\pushfl
        \\pushal
        \\movl %esp,%esi
        \\movl $_arena_random_probe_regs,%edi
        \\movl $9,%ecx
        \\cld
        \\rep movsl
        \\popal
        \\popfl
        \\fxrstor _arena_random_probe_saved_fx
        \\popal
        \\popfl
        \\ret
    );
}
