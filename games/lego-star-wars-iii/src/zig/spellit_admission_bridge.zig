pub fn action100() []const u8 {
    return
    \\.text
    \\.globl _spellit_action100_thunk
    \\_spellit_action100_thunk:
    \\jnz 2f
    \\pushfl
    \\pushal
    \\movl %esp,%edx
    \\subl $544,%esp
    \\andl $-16,%esp
    \\movl %edx,512(%esp)
    \\fxsave (%esp)
    \\movl %fs:0x34,%eax
    \\movl %eax,520(%esp)
    \\fninit
    \\movl $0x1f80,516(%esp)
    \\ldmxcsr 516(%esp)
    \\pushl (%edx)
    \\cld
    \\call _spellit_gungan_action100_admitted
    \\addl $4,%esp
    \\testl %eax,%eax
    \\jz 1f
    \\movl 512(%esp),%edx
    \\andl $-65,32(%edx)
    \\1:
    \\fxrstor (%esp)
    \\movl 520(%esp),%eax
    \\movl %eax,%fs:0x34
    \\movl 512(%esp),%esp
    \\popal
    \\popfl
    \\jz 3f
    \\2: jmp *_spellit_action100_continue
    \\3: jmp *_spellit_action100_skip
    ;
}

pub fn code(comptime stage: u1) []const u8 {
    return ".text\n.globl _spellit_admission_" ++ (if (stage == 0) "state" else "hint") ++ "_thunk\n_spellit_admission_" ++ (if (stage == 0) "state" else "hint") ++ "_thunk:\n" ++
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\movl %fs:0x34,%eax
        \\movl %eax,520(%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\pushl 28(%edx)
    ++ "\n" ++ (if (stage == 0) "pushl $0" else "pushl $1") ++ "\n" ++
        \\pushl 8(%edx)
        \\pushl (%edx)
        \\cld
        \\call _cadence_spellit_admission
        \\addl $16,%esp
        \\fxrstor (%esp)
        \\movl 520(%esp),%edx
        \\movl %edx,%fs:0x34
        \\movl 512(%esp),%esp
        \\pushl 32(%esp)
        \\popfl
        \\testl %eax,%eax
        \\pushfl
        \\popl 32(%esp)
        \\popal
        \\popfl
    ++ "\n" ++ (if (stage == 0)
        \\jnz 1f
        \\jmp *_spellit_admission_state_continue
        \\1: jmp *_spellit_admission_state_skip
    else
        \\jz 1f
        \\movl 0x400(%esi),%eax
        \\jmp *_spellit_admission_hint_continue
        \\1: jmp *_spellit_admission_hint_skip
    ) ++ "\n";
}

pub fn managerCode(comptime special: bool) []const u8 {
    const name = if (special) "special" else "force";
    return ".text\n.globl _spellit_manager_" ++ name ++ "_thunk\n_spellit_manager_" ++ name ++ "_thunk:\n" ++
        (if (special)
            \\pushl %edi
            \\setnz %bl
            \\call *%eax
        else
            \\movl 0x64(%edx),%eax
            \\pushl %edi
            \\call *%eax
        ) ++ "\n" ++
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\movl %fs:0x34,%eax
        \\movl %eax,520(%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\movzbl 28(%edx),%eax
        \\testl %eax,%eax
        \\setnz %al
        \\pushl %eax
    ++ "\npushl $" ++ (if (special) "5" else "4") ++ "\n" ++
        \\pushl $0
        \\pushl (%edx)
        \\cld
        \\call _cadence_spellit_admission
        \\addl $16,%esp
        \\movl 512(%esp),%edx
        \\movb %al,28(%edx)
        \\fxrstor (%esp)
        \\movl 520(%esp),%edx
        \\movl %edx,%fs:0x34
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
    ++ "\njmp *_spellit_manager_" ++ name ++ "_resume\n";
}
