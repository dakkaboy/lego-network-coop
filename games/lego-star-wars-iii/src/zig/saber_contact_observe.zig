const s = @import("cadence_state.zig");
pub extern fn saber_contact_observe_thunk() void;
export const saber_contact_observe_continue: usize = 0x8cd6b2;
pub export var clonewars_saber_contact_trace_enabled: u32 = 0;
pub export var clonewars_saber_contact_trace_count: u32 = 0;
pub export var clonewars_saber_contact_trace: [128][12]u32 = @splat(@splat(0));
pub export var clonewars_saber_contact_candidates: [128][10][2]u32 = @splat(@splat(@splat(0)));

export fn saber_contact_observe(weapon: usize) void {
    if (@atomicLoad(u32, &clonewars_saber_contact_trace_enabled, .monotonic) == 0) return;
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 73 or !s.valid(weapon, 0x25f)) return;
    const attacker = s.read(usize, weapon + 0x238);
    if (!s.valid(attacker, 0x1440) or s.read(u16, attacker + 0xdc0) != 184) return;

    const index = s.read(u8, weapon + 0x25e);
    const count = s.read(u8, weapon + 0x25c);
    const candidate = weapon + 4 + @as(usize, index) * 40;
    // The native loop copies a 40-byte row to the stack and takes the victim
    // pointer and contact type from its final two words.
    const pending = index < count and index < 10 and s.valid(candidate, 40);
    const contact_flags = if (pending) s.read(u8, candidate + 36) else 0;
    const victim = if (contact_flags & 0xf == 2) s.read(usize, candidate + 32) else 0;
    var slot: u32 = 0xffffffff;
    var generation: u32 = 0;
    if (s.valid(victim, 0x1440)) _ = s.entities_observed_identity(victim, &slot, &generation);
    if (!s.live(&lease)) return;

    const frame = s.journal.frame.?;
    const next = clonewars_saber_contact_trace_count;
    const candidates = &clonewars_saber_contact_candidates[next % clonewars_saber_contact_candidates.len];
    candidates.* = @splat(.{ 0xffffffff, 0 });
    for (0..@min(count, candidates.len)) |i| {
        const row = weapon + 4 + i * 40;
        if (s.read(u8, row + 36) & 0xf != 2) continue;
        const target = s.read(usize, row + 32);
        if (s.valid(target, 0x1440)) {
            _ = s.entities_observed_identity(target, &candidates[i][0], &candidates[i][1]);
        }
        if (!s.live(&lease)) return;
    }
    clonewars_saber_contact_trace[next % clonewars_saber_contact_trace.len] = .{
        frame.epoch, frame.sequence, s.read(u32, 0xfb4b6c), index, count, slot,
        generation, contact_flags,
        s.read(u16, attacker + 0x2f4), s.read(u32, weapon + 0x198),
        s.read(u32, weapon + 0x240), s.fire_task_cursor,
    };
    @atomicStore(u32, &clonewars_saber_contact_trace_count, next +% 1, .release);
}

comptime {
    asm (
        \\.text
        \\.globl _saber_contact_observe_thunk
        \\_saber_contact_observe_thunk:
        \\    cmpl $0,_clonewars_saber_contact_trace_enabled
        \\    je 1f
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
        \\    pushl 16(%edx)
        \\    call _saber_contact_observe
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\1:  movb 0x25e(%ebx),%al
        \\    cmpb 0x25c(%ebx),%al
        \\    jmp *_saber_contact_observe_continue
    );
}
