const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn ryloth_fighter_death_thunk() void;
export var ryloth_fighter_death_continue: usize = 0x991d0e;
export var ryloth_fighter_death_skip: usize = 0x991fb9;
pub export var clonewars_ryloth_fighter_death_debug: [4]u32 = @splat(0);

pub export fn ryloth_fighter_death_input(actor: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local: c_int = @intFromBool(s.read(i8, actor + 0xdde) <= 0);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 83 or s.read(i16, actor + 0xdc0) != 381) return local;

    // Agree before the native vehicle routine mutates or retires the actor.
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_RYLOTH_FIGHTER_DEATH, 0, 0, local, null, &clonewars_ryloth_fighter_death_debug);
}

comptime {
    asm (
        \\.text
        \\.globl _ryloth_fighter_death_thunk
        \\_ryloth_fighter_death_thunk:
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
        \\    subl $12,%esp
        \\    pushl 28(%edx)
        \\    call _ryloth_fighter_death_input
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    jmp *_ryloth_fighter_death_continue
        \\1:  popal
        \\    popfl
        \\    jmp *_ryloth_fighter_death_skip
    );
}
