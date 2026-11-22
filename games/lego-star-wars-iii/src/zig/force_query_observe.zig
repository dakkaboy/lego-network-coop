const s = @import("cadence_state.zig");

pub extern fn force_query_observe_thunk() void;
export var force_query_original: usize = 0x7f80e0;
pub export var clonewars_force_query_history: [257]u32 = @splat(0);

export fn force_query_observe(caster: usize, mode: u32, caller: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or !s.valid(caster, 0x1440)) return;
    const frame = s.journal.frame.?;
    const count = clonewars_force_query_history[0];
    const record = clonewars_force_query_history[1 + count % 32 * 8 ..][0..8];
    record.* = .{ frame.epoch, frame.sequence, s.read(u32, 0xfb4b6c), @truncate(caster), s.read(u16, caster + 0xdc0), mode, @truncate(caller), s.fire_task_cursor };
    clonewars_force_query_history[0] = count +% 1;
}

comptime {
    asm (
        \\.text
        \\.globl _force_query_observe_thunk
        \\_force_query_observe_thunk:
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
        \\    subl $4,%esp
        \\    pushl 4(%ebp)
        \\    pushl 44(%edx)
        \\    pushl 40(%edx)
        \\    call _force_query_observe
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_force_query_original
    );
}
