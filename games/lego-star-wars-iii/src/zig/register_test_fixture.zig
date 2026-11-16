const std = @import("std");
const check = @import("native_test_support.zig").check;
pub export var caller: [512]u8 align(16) = @splat(0);
pub export var before: [512]u8 align(16) = @splat(0);
pub export var after: [512]u8 align(16) = @splat(0);
pub export var receiver: [0x200]u8 align(16) = @splat(0);
pub export var regs: [9]u32 = @splat(0);
pub export var mxcsr: u32 = 0x3f80;
pub export var entry: usize = 0;
pub extern fn invoke() void;
pub extern fn continuation() void;
pub fn clobber() void {
    const flags = asm volatile ("pushfl; popl %[value]"
        : [value] "=r" (-> u32),
    );
    var control: u32 = 0;
    asm volatile ("stmxcsr (%[out])"
        :
        : [out] "r" (&control),
        : .{ .memory = true });
    check(@src(), flags & 0x400 == 0 and control == 0x1f80);
    asm volatile ("fninit; fld1; pcmpeqd %%xmm0,%%xmm0; stc" ::: .{ .memory = true, .cc = true, .xmm0 = true });
}
pub fn preservedFx() void {
    check(@src(), std.mem.eql(u8, before[0..5], after[0..5]) and std.mem.eql(u8, before[24..32], after[24..32]));
    for (0..8) |i| check(@src(), std.mem.eql(u8, before[32 + i * 16 ..][0..10], after[32 + i * 16 ..][0..10]));
    check(@src(), std.mem.eql(u8, before[160..288], after[160..288]));
}
comptime {
    asm (
        \\.text
        \\_continuation: ret
        \\_invoke:
        \\pushfl
        \\pushal
        \\fxsave _caller
        \\fninit
        \\fld1
        \\fldz
        \\ldmxcsr _mxcsr
        \\pxor %xmm0,%xmm0
        \\pcmpeqd %xmm1,%xmm1
        \\pxor %xmm2,%xmm2
        \\pcmpeqd %xmm3,%xmm3
        \\pxor %xmm4,%xmm4
        \\pcmpeqd %xmm5,%xmm5
        \\pxor %xmm6,%xmm6
        \\pcmpeqd %xmm7,%xmm7
        \\fxsave _before
        \\pushl $0xe97
        \\popfl
    ++ "\n" ++ (if (@import("root").fixture_receiver_in_eax)
        \\movl $_receiver,%eax
        \\movl $0x22222222,%ecx
    else
        \\movl $0x11111111,%eax
        \\movl $_receiver,%ecx
    ) ++ "\n" ++
        \\movl $0x33333333,%edx
        \\movl $0x44444444,%ebx
        \\movl $0x55555555,%ebp
        \\movl $0x66666666,%esi
        \\movl $0x77777777,%edi
        \\call *_entry
        \\pushfl
        \\pushal
        \\movl %esp,%esi
        \\movl $_regs,%edi
        \\movl $9,%ecx
        \\cld
        \\rep movsl
        \\fxsave _after
        \\addl $36,%esp
        \\fxrstor _caller
        \\popal
        \\popfl
        \\ret
    );
}
