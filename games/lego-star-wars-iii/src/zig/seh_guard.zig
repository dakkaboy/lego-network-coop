pub const Invoke = *const fn (usize) callconv(.c) c_int;
extern fn zig_seh_guard_all(usize, Invoke) c_int;
extern fn zig_seh_guard_memory(usize, Invoke, c_int) c_int;
pub fn all(context: usize, invoke: Invoke) c_int {
    return zig_seh_guard_all(context, invoke);
}
pub fn memory(context: usize, invoke: Invoke, fallback: c_int) c_int {
    return zig_seh_guard_memory(context, invoke, fallback);
}
comptime {
    asm (
        \\    .def    _zig_seh_guard_all;
        \\    .scl    2;
        \\    .type   32;
        \\    .endef
        \\    .text
        \\    .globl  _zig_seh_guard_all
        \\    .p2align    4
        \\_zig_seh_guard_all:
        \\Lzig_seh_begin0:
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %ebx
        \\    pushl   %edi
        \\    pushl   %esi
        \\    subl    $28, %esp
        \\Lzig_seh_guard_all$frame_escape_0 = -40
        \\    movl    8(%ebp), %eax
        \\    movl    %esp, -36(%ebp)
        \\    movl    $-1, -16(%ebp)
        \\    movl    $L__ehtable$zig_seh_guard_all, -20(%ebp)
        \\    leal    -28(%ebp), %ecx
        \\    movl    $__except_handler3, -24(%ebp)
        \\    movl    %fs:0, %edx
        \\    movl    %edx, -28(%ebp)
        \\    movl    %ecx, %fs:0
        \\    movl    $0, -16(%ebp)
        \\    pushl   %eax
        \\    calll   *12(%ebp)
        \\    addl    $4, %esp
        \\Lzig_seh_BB0_2:
        \\    movl    -28(%ebp), %ecx
        \\    movl    %ecx, %fs:0
        \\    addl    $28, %esp
        \\    popl    %esi
        \\    popl    %edi
        \\    popl    %ebx
        \\    popl    %ebp
        \\    retl
        \\Lzig_seh_BB0_1:
        \\$zigseh_ehgcr_0_1:
        \\    movl    -24(%ebp), %esp
        \\    addl    $12, %ebp
        \\    xorl    %eax, %eax
        \\    jmp Lzig_seh_BB0_2
        \\Lzig_seh_end0:
        \\    .section    .xdata,"dr"
        \\Lzig_seh_guard_all$parent_frame_offset = -36
        \\    .p2align    2, 0x0
        \\L__ehtable$zig_seh_guard_all:
        \\    .long   -1
        \\    .long   "?filt$0@0@zig_seh_guard_all@@"
        \\    .long   Lzig_seh_BB0_1
        \\    .text
        \\    .def    "?filt$0@0@zig_seh_guard_all@@";
        \\    .scl    3;
        \\    .type   32;
        \\    .endef
        \\    .p2align    4
        \\"?filt$0@0@zig_seh_guard_all@@":
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %esi
        \\    movl    (%ebp), %eax
        \\    movl    $Lzig_seh_guard_all$frame_escape_0, %ecx
        \\    movl    -20(%eax), %edx
        \\    movl    (%edx), %edx
        \\    movl    (%edx), %edx
        \\    movl    $Lzig_seh_guard_all$parent_frame_offset, %esi
        \\    subl    %esi, %eax
        \\    movl    %edx, -24(%ecx,%eax)
        \\    movl    $1, %eax
        \\    popl    %esi
        \\    popl    %ebp
        \\    retl
        \\    .def    _zig_seh_guard_memory;
        \\    .scl    2;
        \\    .type   32;
        \\    .endef
        \\    .globl  _zig_seh_guard_memory
        \\    .p2align    4
        \\_zig_seh_guard_memory:
        \\Lzig_seh_begin1:
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %ebx
        \\    pushl   %edi
        \\    pushl   %esi
        \\    subl    $28, %esp
        \\Lzig_seh_guard_memory$frame_escape_0 = -40
        \\    movl    8(%ebp), %eax
        \\    movl    %esp, -36(%ebp)
        \\    movl    $-1, -16(%ebp)
        \\    movl    $L__ehtable$zig_seh_guard_memory, -20(%ebp)
        \\    leal    -28(%ebp), %ecx
        \\    movl    $__except_handler3, -24(%ebp)
        \\    movl    %fs:0, %edx
        \\    movl    %edx, -28(%ebp)
        \\    movl    %ecx, %fs:0
        \\    movl    $0, -16(%ebp)
        \\    pushl   %eax
        \\    calll   *12(%ebp)
        \\    addl    $4, %esp
        \\Lzig_seh_BB2_2:
        \\    movl    -28(%ebp), %ecx
        \\    movl    %ecx, %fs:0
        \\    addl    $28, %esp
        \\    popl    %esi
        \\    popl    %edi
        \\    popl    %ebx
        \\    popl    %ebp
        \\    retl
        \\Lzig_seh_BB2_1:
        \\$zigseh_ehgcr_2_1:
        \\    movl    -24(%ebp), %esp
        \\    addl    $12, %ebp
        \\    movl    16(%ebp), %eax
        \\    jmp Lzig_seh_BB2_2
        \\Lzig_seh_end1:
        \\    .section    .xdata,"dr"
        \\Lzig_seh_guard_memory$parent_frame_offset = -36
        \\    .p2align    2, 0x0
        \\L__ehtable$zig_seh_guard_memory:
        \\    .long   -1
        \\    .long   "?filt$0@0@zig_seh_guard_memory@@"
        \\    .long   Lzig_seh_BB2_1
        \\    .text
        \\    .def    "?filt$0@0@zig_seh_guard_memory@@";
        \\    .scl    3;
        \\    .type   32;
        \\    .endef
        \\    .p2align    4
        \\"?filt$0@0@zig_seh_guard_memory@@":
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %esi
        \\    movl    (%ebp), %eax
        \\    movl    $Lzig_seh_guard_memory$frame_escape_0, %ecx
        \\    movl    -20(%eax), %edx
        \\    movl    (%edx), %edx
        \\    movl    (%edx), %edx
        \\    movl    $Lzig_seh_guard_memory$parent_frame_offset, %esi
        \\    subl    %esi, %eax
        \\    movl    %edx, -24(%ecx,%eax)
        \\    addl    $1073741819, %edx
        \\    xorl    %eax, %eax
        \\    cmpl    $2, %edx
        \\    setb    %al
        \\    popl    %esi
        \\    popl    %ebp
        \\    retl
        \\    .safeseh    __except_handler3
    );
}
