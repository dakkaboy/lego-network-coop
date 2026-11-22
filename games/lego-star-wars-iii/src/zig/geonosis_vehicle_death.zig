const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn geonosis_vehicle_death_thunk() void;
export const geonosis_vehicle_death_resume: usize = 0x427a35;
pub export var clonewars_geonosis_vehicle_death_debug: [4]u32 = @splat(0);

pub export fn geonosis_vehicle_death_input(actor: usize, handle: usize, flags: u32) u32 {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 79 or !s.valid(actor, 0x1440) or s.read(i16, actor + 0xdc0) != 417) return flags;
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const queued = 0x40000000;
    const local: c_int = @intFromBool(flags & queued != 0);
    const die = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_GEONOSIS_VEHICLE_DEATH, 0, 0, local, null, &clonewars_geonosis_vehicle_death_debug);
    if (die != 0) return flags | queued;
    const remaining = flags & ~@as(u32, queued);
    if (local != 0 and s.journal.failed == 0 and s.live(&lease) and s.read(usize, actor + 0x142c) == handle and s.win.accessible(handle + 0x84, 4, true) and s.read(u32, handle + 0x84) == flags) {
        s.win.store(u32, handle + 0x84, remaining);
    }
    return remaining;
}

comptime {
    asm (
        \\.text
        \\.globl _geonosis_vehicle_death_thunk
        \\_geonosis_vehicle_death_thunk:
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
        \\    subl $4,%esp
        \\    pushl 4(%edx)
        \\    pushl 28(%edx)
        \\    pushl 0(%edx)
        \\    cld
        \\    call _geonosis_vehicle_death_input
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movl %eax,4(%edx)
        \\    fxrstor (%esp)
        \\    movl %edx,%esp
        \\    popal
        \\    popfl
        \\    testl $0x40000000,%esi
        \\    jmp *_geonosis_vehicle_death_resume
    );
}
