const std = @import("std");
pub fn code(comptime name: []const u8, comptime observer: []const u8, comptime target: []const u8) []const u8 {
    return std.fmt.comptimePrint(
        \\.text
        \\.globl _{0s}
        \\_{0s}:
        \\pushfl
        \\pushal
        \\movl %esp,%eax
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %eax,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\movl %fs:52,%eax
        \\movl %eax,524(%esp)
        \\movl 512(%esp),%edx
        \\movl %esp,%eax
        \\subl $8,%esp
        \\pushl %eax
        \\pushl %edx
        \\call _{1s}
        \\addl $16,%esp
        \\cld
        \\movl 524(%esp),%eax
        \\movl %eax,%fs:52
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\jmp *_{2s}
    , .{ name, observer, target });
}
