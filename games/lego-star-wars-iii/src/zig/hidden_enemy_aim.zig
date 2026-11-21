const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn hidden_enemy_aim_thunk() void;
export var hidden_enemy_aim_continue: usize = 0x899f37;
export var hidden_enemy_aim_skip: usize = 0x89a179;
pub export var clonewars_hidden_enemy_aim_debug: [4]u32 = @splat(0);

pub export fn hidden_enemy_aim_input(actor: usize, admitted: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local: c_int = @intFromBool(admitted != 0);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or s.read(i16, actor + 0xdc0) != 184) return local;
    // This branch runs after the base aim callbacks and guards the extended aim task.
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_HIDDEN_ENEMY_AIM, 0, 0, local, null, &clonewars_hidden_enemy_aim_debug);
}

comptime {
    asm (
        \\.text
        \\.globl _hidden_enemy_aim_thunk
        \\_hidden_enemy_aim_thunk:
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
        \\    pushl 16(%edx)
        \\    pushl 4(%edx)
        \\    call _hidden_enemy_aim_input
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    movl %eax,%ebx
        \\    jmp *_hidden_enemy_aim_continue
        \\1:  popal
        \\    popfl
        \\    jmp *_hidden_enemy_aim_skip
    );
}
