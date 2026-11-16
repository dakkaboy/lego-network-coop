comptime {
    asm (
        \\    .def    _constructor_lexical_seh;
        \\    .scl    2;
        \\    .type   32;
        \\    .endef
        \\    .text
        \\    .globl  _constructor_lexical_seh
        \\    .p2align    4
        \\_constructor_lexical_seh:
        \\Lconstructor_func_begin0:
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %ebx
        \\    pushl   %edi
        \\    pushl   %esi
        \\    subl    $36, %esp
        \\Lconstructor_lexical_seh$frame_escape_0 = -40
        \\Lconstructor_lexical_seh$frame_escape_1 = -48
        \\Lconstructor_lexical_seh$frame_escape_2 = -44
        \\    movl    8(%ebp), %eax
        \\    movl    16(%ebp), %ecx
        \\    movl    %esp, -36(%ebp)
        \\    movl    $-1, -16(%ebp)
        \\    movl    $L__ehtable$constructor_lexical_seh, -20(%ebp)
        \\    leal    -28(%ebp), %edx
        \\    movl    $__except_handler3, -24(%ebp)
        \\    movl    %fs:0, %esi
        \\    movl    %esi, -28(%ebp)
        \\    movl    %edx, %fs:0
        \\    movl    %ecx, -48(%ebp)
        \\    movl    %eax, -44(%ebp)
        \\    movl    $0, -40(%ebp)
        \\    movl    $0, -16(%ebp)
        \\    pushl   %eax
        \\    calll   *12(%ebp)
        \\    addl    $4, %esp
        \\    movl    $1, -40(%ebp)
        \\    cmpl    $0, Lconstructor_lexical_seh$frame_escape_0(%ebp)
        \\    jne Lconstructor_BB0_3
        \\    movl    Lconstructor_lexical_seh$frame_escape_1(%ebp), %ecx
        \\    movl    Lconstructor_lexical_seh$frame_escape_2(%ebp), %edx
        \\    movl    $-1, -16(%ebp)
        \\    pushl   %edx
        \\    movl    %eax, %esi
        \\    calll   *%ecx
        \\    movl    %esi, %eax
        \\    addl    $4, %esp
        \\Lconstructor_BB0_3:
        \\    movl    $-1, -16(%ebp)
        \\    movl    -28(%ebp), %ecx
        \\    movl    %ecx, %fs:0
        \\    addl    $36, %esp
        \\    popl    %esi
        \\    popl    %edi
        \\    popl    %ebx
        \\    popl    %ebp
        \\    retl
        \\    .def    "?dtor$4@?0?constructor_lexical_seh@4HA";
        \\    .scl    3;
        \\    .type   32;
        \\    .endef
        \\    .p2align    4
        \\"?dtor$4@?0?constructor_lexical_seh@4HA":
        \\Lconstructor_BB0_4:
        \\    pushl   %ebp
        \\    pushl   %eax
        \\    addl    $12, %ebp
        \\    cmpl    $0, Lconstructor_lexical_seh$frame_escape_0(%ebp)
        \\    jne Lconstructor_BB0_6
        \\    pushl   Lconstructor_lexical_seh$frame_escape_2(%ebp)
        \\    calll   *Lconstructor_lexical_seh$frame_escape_1(%ebp)
        \\    addl    $4, %esp
        \\Lconstructor_BB0_6:
        \\    addl    $4, %esp
        \\    popl    %ebp
        \\    retl
        \\Lconstructor_func_end0:
        \\    .section    .xdata,"dr"
        \\Lconstructor_lexical_seh$parent_frame_offset = -36
        \\    .p2align    2, 0x0
        \\L__ehtable$constructor_lexical_seh:
        \\    .long   -1
        \\    .long   0
        \\    .long   "?dtor$4@?0?constructor_lexical_seh@4HA"
        \\    .text
        \\    .def    _tag_lexical_seh;
        \\    .scl    2;
        \\    .type   32;
        \\    .endef
        \\    .text
        \\    .globl  _tag_lexical_seh
        \\    .p2align    4
        \\_tag_lexical_seh:
        \\Ltag_func_begin0:
        \\    pushl   %ebp
        \\    movl    %esp, %ebp
        \\    pushl   %ebx
        \\    pushl   %edi
        \\    pushl   %esi
        \\    subl    $36, %esp
        \\Ltag_lexical_seh$frame_escape_0 = -48
        \\Ltag_lexical_seh$frame_escape_1 = -44
        \\Ltag_lexical_seh$frame_escape_2 = -40
        \\    movl    8(%ebp), %eax
        \\    movl    16(%ebp), %ecx
        \\    movl    %esp, -36(%ebp)
        \\    movl    $-1, -16(%ebp)
        \\    movl    $L__ehtable$tag_lexical_seh, -20(%ebp)
        \\    leal    -28(%ebp), %edx
        \\    movl    $__except_handler3, -24(%ebp)
        \\    movl    %fs:0, %esi
        \\    movl    %esi, -28(%ebp)
        \\    movl    %edx, %fs:0
        \\    movl    %ecx, -48(%ebp)
        \\    movl    %eax, -44(%ebp)
        \\    movl    $0, -40(%ebp)
        \\    movl    $0, -16(%ebp)
        \\    pushl   %eax
        \\    calll   *12(%ebp)
        \\    addl    $4, %esp
        \\    movl    %eax, %esi
        \\    movl    $1, -40(%ebp)
        \\    movl    Ltag_lexical_seh$frame_escape_0(%ebp), %eax
        \\    movl    Ltag_lexical_seh$frame_escape_2(%ebp), %ecx
        \\    movl    Ltag_lexical_seh$frame_escape_1(%ebp), %edx
        \\    movl    $-1, -16(%ebp)
        \\    pushl   %ecx
        \\    pushl   %edx
        \\    calll   *%eax
        \\    addl    $8, %esp
        \\    movl    -28(%ebp), %eax
        \\    movl    %eax, %fs:0
        \\    movl    %esi, %eax
        \\    addl    $36, %esp
        \\    popl    %esi
        \\    popl    %edi
        \\    popl    %ebx
        \\    popl    %ebp
        \\    retl
        \\    .def    "?dtor$2@?0?tag_lexical_seh@4HA";
        \\    .scl    3;
        \\    .type   32;
        \\    .endef
        \\    .p2align    4
        \\"?dtor$2@?0?tag_lexical_seh@4HA":
        \\Ltag_BB0_2:
        \\    pushl   %ebp
        \\    subl    $8, %esp
        \\    addl    $12, %ebp
        \\    pushl   Ltag_lexical_seh$frame_escape_2(%ebp)
        \\    pushl   Ltag_lexical_seh$frame_escape_1(%ebp)
        \\    calll   *Ltag_lexical_seh$frame_escape_0(%ebp)
        \\    addl    $16, %esp
        \\    popl    %ebp
        \\    retl
        \\Ltag_func_end0:
        \\    .section    .xdata,"dr"
        \\Ltag_lexical_seh$parent_frame_offset = -36
        \\    .p2align    2, 0x0
        \\L__ehtable$tag_lexical_seh:
        \\    .long   -1
        \\    .long   0
        \\    .long   "?dtor$2@?0?tag_lexical_seh@4HA"
        \\    .text
        \\.text
        \\.safeseh __except_handler3
    );
}
