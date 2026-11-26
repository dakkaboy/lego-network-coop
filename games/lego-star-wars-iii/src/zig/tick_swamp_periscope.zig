const s = @import("tick_state.zig");

pub extern fn swamp_periscope_query_thunk() void;
export const swamp_periscope_native_query: usize = 0x49c320;

pub fn cameraIndex(module: usize) ?u32 {
    if (!s.readable(module, 0x108) or s.load(u32, module) != 0xae5724) return null;
    const first: u32 = 3472594585;
    const spacing = 79;
    const id = s.load(u32, module + 8);
    if (id < first or id > first + 4 * spacing or (id - first) % spacing != 0) return null;
    return (id - first) / spacing;
}

export fn swamp_periscope_result(module: usize, native: u32) u32 {
    if (!s.ready() or s.frame.?.level != 70) return native;
    const index = cameraIndex(module) orelse return native;
    return s.decision(s.site.SWAMP_PERISCOPE_QUERY + index, @intFromBool(native & 0xff != 0));
}

comptime {
    asm (
        \\.text
        \\.globl _swamp_periscope_query_thunk
        \\_swamp_periscope_query_thunk:
        \\    call *_swamp_periscope_native_query
        \\    pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $8,%esp
        \\    pushl 28(%edx)
        \\    pushl 4(%edx)
        \\    call _swamp_periscope_result
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    movl %eax,28(%esp)
        \\    popal
        \\    popfl
        \\    ret
    );
}
