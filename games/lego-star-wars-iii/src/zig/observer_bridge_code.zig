pub fn code(comptime name: []const u8, comptime helper: []const u8) []const u8 {
    return ".text\n.globl _" ++ name ++ "\n_" ++ name ++ ":\n" ++
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
        \\call _GetLastError@0
        \\movl %eax,524(%esp)
        \\movl 512(%esp),%edx
        \\movl 40(%edx),%eax
        \\movl 44(%edx),%ecx
        \\subl $8,%esp
        \\pushl %ecx
        \\pushl %eax
        \\call _
    ++ helper ++ "\n" ++
        \\addl $16,%esp
        \\cld
        \\pushl 524(%esp)
        \\call _SetLastError@4
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\ret
    ++ "\n";
}
