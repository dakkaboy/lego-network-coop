const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn melee_contact_thunk() void;
pub extern fn melee_bounds_thunk() void;
export var melee_contact_continue: usize = 0x92ad65;
export var melee_contact_skip: usize = 0x92b333;
export var melee_bounds_continue: usize = 0x92ad17;
export var melee_bounds_original: usize = 0x92ac87;
pub export var clonewars_melee_contact_debug: [4]u32 = @splat(0);

fn attackerIdentity(victim: usize, attack: usize) ?p.SyncMeleeContact {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or !s.valid(victim, 0x1440) or
        s.read(u32, victim + 0x50) & 0x200 == 0 or !s.valid(attack, 0x1d3) or
        s.read(u8, attack + 0x1d2) & 0x20 == 0) return null;
    const attacker = s.read(usize, attack + 0xd4);
    if (!s.valid(attacker, 0x1440) or s.read(i16, attacker + 0xdc0) != 196) return null;
    var identity: p.SyncMeleeContact = undefined;
    if (s.entities_observed_identity(attacker, &identity.attacker_slot, &identity.attacker_generation) == 0 or !s.live(&lease)) return null;
    return identity;
}

pub export fn melee_contact(victim: usize, attack: usize, native_contact: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local = native_contact != 0;
    var identity = attackerIdentity(victim, attack) orelse return @intFromBool(local);
    if (s.journal.host != 0 and !local) return 0;
    return @import("cadence_gate.zig").apply(victim, p.SYNC_ACTOR_MELEE_CONTACT, 0, 0, @intFromBool(local), @ptrCast(&identity), &clonewars_melee_contact_debug);
}

pub export fn melee_bounds(victim: usize, attack: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const identity = attackerIdentity(victim, attack) orelse return 2;
    if (s.journal.host != 0) return 2;
    var lease: s.Lease = undefined;
    if (!s.ready(&lease)) return 2;
    const frame = s.journal.frame.?;
    if (s.fire_task_cursor >= frame.fire_task_gate_count) return 0;
    const entry = &frame.fire_task_gates[s.fire_task_cursor];
    if (entry.kind != p.SYNC_ACTOR_MELEE_CONTACT or
        identity.attacker_slot != entry.payload.melee_contact.attacker_slot or
        identity.attacker_generation != entry.payload.melee_contact.attacker_generation) return 0;
    var reference = s.reference(entry);
    return @intFromBool(s.entities_resolve_reference(&reference) == victim and s.live(&lease));
}

comptime {
    asm (
        \\.text
        \\.globl _melee_contact_thunk
        \\_melee_contact_thunk:
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
        \\    pushl 28(%edx)
        \\    pushl 0(%edx)
        \\    pushl 4(%edx)
        \\    call _melee_contact
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    jmp *_melee_contact_continue
        \\1:  popal
        \\    popfl
        \\    jmp *_melee_contact_skip
    );
    asm (
        \\.text
        \\.globl _melee_bounds_thunk
        \\_melee_bounds_thunk:
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
        \\    pushl 0(%edx)
        \\    pushl 4(%edx)
        \\    call _melee_bounds
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    cmpl $2,%eax
        \\    je 2f
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    jmp *_melee_bounds_continue
        \\1:  popal
        \\    popfl
        \\    jmp *_melee_contact_skip
        \\2:  popal
        \\    popfl
        \\    flds 0x28(%esp)
        \\    flds 0x3c(%esi)
        \\    jmp *_melee_bounds_original
    );
}
