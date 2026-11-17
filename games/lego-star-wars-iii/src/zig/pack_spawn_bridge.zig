const std = @import("std");
comptime {
    for (.{ .{ "native_pack_spawn_rng_input", "pack_spawn_random" }, .{ "native_pack_spawn_birth_input", "pack_spawn_allocate" } }) |names| asm (std.fmt.comptimePrint(
        \\.text
        \\.globl _{s}
        \\_{s}:
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
        \\movl 36(%eax),%edx
        \\subl $5,%edx
        \\leal 36(%eax),%ecx
        \\pushl %edx
        \\pushl %ecx
        \\pushl 0(%eax)
        \\pushl 4(%eax)
        \\cld
        \\call _native_pack_spawn_input
        \\addl $16,%esp
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\jmp *_{s}
    , .{ names[0], names[0], names[1] }));
}
