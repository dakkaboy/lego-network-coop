const std = @import("std");
const check = @import("native_test_support.zig").check;
pub export var caller_fx: [512]u8 align(16) = @splat(0);
pub export var observed_fx: [512]u8 align(16) = @splat(0);
pub export var observed_regs: [9]u32 = @splat(0);
pub export var iterator: u32 = 0;
pub export var argument: u32 = 0;
pub export var projected: u32 = 0;
pub export var native_calls: u32 = 0;
pub export var entry: usize = 0;
pub export var fpu_values: [2]f64 = .{ 1.25, 2.5 };
pub export var mxcsr_value: u32 = 0x3f80;
pub export var fp_control: u16 = 0x37f;
pub export var model: [0x50]u8 = @splat(0);
pub export var task: [0x30]u8 = @splat(0);
pub export var test_mode: u32 = 0;
pub export var branch: u32 = 0;
pub extern fn invoke_thunk() void;
pub fn expectSame(comptime location: std.builtin.SourceLocation, fx: *const [512]u8, regs: *const [9]u32) void {
    for (regs, observed_regs, 0..) |a, b, i| if (a != b) {
        std.debug.print("register {d}: {x} vs {x}\n", .{ i, a, b });
        check(location, false);
    };
    for (fx, observed_fx, 0..) |a, b, i| if (a != b) {
        std.debug.print("fx byte {d}: {x} vs {x}\n", .{ i, a, b });
        check(location, false);
    };
}
comptime {
    asm (
        \\.text
        \\_invoke_thunk:
        \\pushfl
        \\pushal
        \\subl $1280,%esp
        \\fxsave _caller_fx
        \\fninit
        \\fldcw _fp_control
        \\fldl _fpu_values
        \\fldl _fpu_values+8
        \\ldmxcsr _mxcsr_value
        \\pcmpeqd %xmm0,%xmm0
        \\pcmpeqd %xmm1,%xmm1
        \\pxor %xmm2,%xmm2
        \\pcmpeqd %xmm3,%xmm3
        \\pxor %xmm4,%xmm4
        \\pcmpeqd %xmm5,%xmm5
        \\pxor %xmm6,%xmm6
        \\pcmpeqd %xmm7,%xmm7
        \\pslld $7,%xmm7
        \\movl _iterator,%ecx
        \\movl %ecx,0x3c(%esp)
        \\movl $0x11223344,0x398(%esp,%ecx,4)
        \\movl $0x8899aabb,0x2c(%esp)
        \\movl $0x99aabbcc,0x34(%esp)
        \\movl $0x12345678,(%esp)
    ++ "\n" ++ (if (@hasDecl(@import("root"), "probe_flags")) @import("root").probe_flags else "pushl $0x646") ++ "\n" ++
        \\popfl
        \\movl $0x11111111,%eax
        \\movl $0x22222222,%ecx
        \\movl $0x33333333,%edx
        \\movl $0x44444444,%ebx
        \\movl $0x55555555,%ebp
        \\movl $0x66666666,%esi
        \\movl $0x77777777,%edi
    ++ "\n" ++ (if (@hasDecl(@import("root"), "probe_registers")) @import("root").probe_registers else "") ++ "\n" ++
        \\call *_entry
    ++ "\n" ++ (if (@hasDecl(@import("root"), "probe_after_call")) @import("root").probe_after_call else "") ++ "\n" ++
        \\pushfl
        \\pushal
        \\movl %esp,%esi
        \\movl $_observed_regs,%edi
        \\movl $9,%ecx
        \\cld
        \\rep movsl
        \\fxsave _observed_fx
        \\addl $36,%esp
        \\fxrstor _caller_fx
        \\addl $1280,%esp
        \\popal
        \\popfl
        \\ret
    );
}
