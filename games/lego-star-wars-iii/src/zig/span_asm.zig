comptime {
    asm (
        \\.text
        \\.globl _span_entry_thunk
        \\_span_entry_thunk:
        \\testb $2,0x4d(%eax)
        \\    movl %ebp,0x48(%esp)
        \\    pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl 512(%esp),%edx
        \\    movl %esp,%eax
        \\    subl $8,%esp
        \\    pushl %eax
        \\    pushl %edx
        \\    call _native_span_enter
        \\    addl $16,%esp
        \\    movl %eax,528(%esp)
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    cmpl $1,528(%esp)
        \\    ja 8f
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_native_span_run_resume
        \\    8: movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_native_span_skip_target
        \\    
        \\.text
        \\.globl _span_exit_thunk
        \\_span_exit_thunk:
        \\pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    call _GetLastError@0
        \\    movl %eax,524(%esp)
        \\    movl 512(%esp),%edx
        \\    movl %esp,%eax
        \\    subl $8,%esp
        \\    pushl %eax
        \\    pushl %edx
        \\    call _native_span_exit
        \\    addl $16,%esp
        \\    cld
        \\    pushl 524(%esp)
        \\    call _SetLastError@4
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    movl (%esi),%edx
        \\    movl 0x30(%edx),%eax
        \\    jmp *_native_span_exit_resume
        \\    
    );
    asm (@import("span_marker_asm.zig").code("span_optional_thunk", "optional_enter", "optional_target"));
    asm (@import("span_marker_asm.zig").code("span_main_thunk", "main_enter", "main_target"));
}
