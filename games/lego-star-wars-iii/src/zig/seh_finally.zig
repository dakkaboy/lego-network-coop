const std = @import("std");

pub fn code(comptime name: []const u8, comptime enter: []const u8, comptime inner: []const u8, comptime leave: []const u8) []const u8 {
    @setEvalBranchQuota(100000);
    return std.fmt.comptimePrint(
        \\  .def    _{0s};
        \\  .scl    2;
        \\  .type   32;
        \\  .endef
        \\  .text
        \\  .globl  _{0s}
        \\  .p2align    4
        \\_{0s}:
        \\L{0s}_begin:
        \\  pushl   %ebp
        \\  movl    %esp, %ebp
        \\  pushl   %ebx
        \\  pushl   %edi
        \\  pushl   %esi
        \\  subl    $32, %esp
        \\L{0s}$frame_escape_0 = -44
        \\L{0s}$frame_escape_1 = -40
        \\  movl    8(%ebp), %eax
        \\  movl    %esp, -36(%ebp)
        \\  movl    $-1, -16(%ebp)
        \\  movl    $L__ehtable${0s}, -20(%ebp)
        \\  leal    -28(%ebp), %ecx
        \\  movl    $__except_handler3, -24(%ebp)
        \\  movl    %fs:0, %edx
        \\  movl    %edx, -28(%ebp)
        \\  movl    %ecx, %fs:0
        \\  movl    %eax, -44(%ebp)
        \\  movl    $0, -40(%ebp)
        \\  movl    $0, -16(%ebp)
        \\  pushl   %eax
        \\  calll   _{1s}
        \\  addl    $4, %esp
        \\  pushl   -44(%ebp)
        \\  calll   _{2s}
        \\  addl    $4, %esp
        \\  movl    $1, -40(%ebp)
        \\  xorl    %eax, %eax
        \\  cmpl    $0, L{0s}$frame_escape_1(%ebp)
        \\  sete    %al
        \\  movl    L{0s}$frame_escape_0(%ebp), %ecx
        \\  movl    $-1, -16(%ebp)
        \\  pushl   %eax
        \\  pushl   %ecx
        \\  calll   _{3s}
        \\  addl    $8, %esp
        \\  movl    -28(%ebp), %eax
        \\  movl    %eax, %fs:0
        \\  addl    $32, %esp
        \\  popl    %esi
        \\  popl    %edi
        \\  popl    %ebx
        \\  popl    %ebp
        \\  retl
        \\  .def    L{0s}_finally;
        \\  .scl    3;
        \\  .type   32;
        \\  .endef
        \\  .p2align    4
        \\L{0s}_finally:
        \\L{0s}_cleanup:
        \\  pushl   %ebp
        \\  subl    $8, %esp
        \\  addl    $12, %ebp
        \\  xorl    %eax, %eax
        \\  cmpl    $0, L{0s}$frame_escape_1(%ebp)
        \\  sete    %al
        \\  pushl   %eax
        \\  pushl   L{0s}$frame_escape_0(%ebp)
        \\  calll   _{3s}
        \\  addl    $16, %esp
        \\  popl    %ebp
        \\  retl
        \\L{0s}_end:
        \\  .section    .xdata,"dr"
        \\L{0s}$parent_frame_offset = -36
        \\  .p2align    2, 0x0
        \\L__ehtable${0s}:
        \\  .long   -1
        \\  .long   0
        \\  .long   L{0s}_finally
        \\  .text
        \\  .safeseh    __except_handler3
    , .{ name, enter, inner, leave });
}
