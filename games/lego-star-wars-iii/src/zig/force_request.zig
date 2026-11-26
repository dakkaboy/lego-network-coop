const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn force_request_eligible_thunk() void;
pub extern fn force_request_begin_thunk() void;
pub extern fn force_request_action_thunk() void;
pub extern fn force_request_available_thunk() void;
pub extern fn force_request_first_target_thunk() void;
pub extern fn force_release_expired_thunk() void;
export var force_release_expired_continue: usize = 0x84adcf;
export var force_release_wait: usize = 0x84b298;
export var force_request_eligible_continue: usize = 0x84bc9d;
export var force_request_action_continue: usize = 0x84bcd9;
export var force_request_available_continue: usize = 0x84bd03;
export var force_request_eligible_skip: usize = 0x84be6e;
export const force_request_begin_continue: usize = 0x84b305;
export const force_request_begin_new: usize = 0x84bc4b;
export var force_request_available_skip: usize = 0x84bd31;
export const force_request_first_target_continue: usize = 0x84bd13;
export const force_request_first_target_skip: usize = 0x84bd21;
pub export var clonewars_force_eligibility_debug: [5][4]u32 = @splat(@splat(0));

const Stage = enum(u16) { area, action, available, release_expired, first_target };
pub export fn force_request_begin(actor: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.host != 0 or !s.valid(actor, 0x1440) or s.read(u16, actor + 0xdc0) != 184 or
        s.read(u32, actor + 0x50) & 0x200 == 0) return 0;
    const gate = @import("cadence_gate.zig");
    const clock = s.read(u32, 0xfb4b6c);
    const owner = gate.labForceRequestAdmission(clock) orelse return 0;
    if (s.entities_resolve_reference(&owner) != actor or !s.live(&lease)) return 0;
    if (gate.labForceRequestOwner(clock) != null) return 1;
    return if (gate.labForceRequestFollowedByCompanion(clock)) -1 else 0;
}

pub fn eligible(actor: usize, stage: Stage, local: bool) bool {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or !s.valid(actor, 0x1440) or s.read(u32, actor + 0x50) & 0x200 == 0) return local;
    const level = s.journal.frame.?.level;
    const character = s.read(u16, actor + 0xdc0);
    const upper_corridor = level == 71 and character == 181 and s.read(f32, actor + 0x28) > 5.5;
    if (level != 64 and !(level == 73 and character == 184) and !upper_corridor) return local;
    if (stage == .first_target and level == 64) return local;
    const index = @backingInt(stage);
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_FORCE_ELIGIBILITY, index, 0, @intFromBool(local), null, &clonewars_force_eligibility_debug[index]) != 0;
}

export fn force_request_eligible(actor: usize, _: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const native: *const fn (usize, usize) callconv(.c) u8 = @ptrFromInt(0x8ce9f0);
    const local = s.read(u8, actor + 0x56) != 0 or native(s.read(usize, 0xfb4a20), actor) != 0;
    return @intFromBool(eligible(actor, .area, local));
}

export fn force_request_action(actor: usize, _: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const action: i32 = s.read(i16, actor + 0x2f4);
    const table = s.read(usize, 0xe75ef8);
    const offset: usize = @bitCast(@as(isize, action) * 16);
    const local = action == -1 or s.read(u32, table +% offset +% 8) & 4 != 0 or
        action == s.read(i32, 0xe6aecc) or action == s.read(i32, 0xe6aed0);
    return @intFromBool(eligible(actor, .action, local));
}

export fn force_request_available(actor: usize, local: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return @intFromBool(eligible(actor, .available, local != 0));
}

pub export fn force_request_first_target(actor: usize, target: usize) usize {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease)) return target;
    if (s.journal.frame.?.level == 73 and s.valid(actor, 0x1440) and
        s.read(u16, actor + 0xdc0) == 184 and s.read(u32, actor + 0x50) & 0x200 != 0)
    {
        const primary = @import("force_primary_target.zig");
        const clock = s.read(u32, 0xfb4b6c);
        var reference: primary.Target = if (s.journal.host != 0) primary.describe(target, clock) else .{ .clock = clock };
        const index = @backingInt(Stage.first_target);
        const accepted = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_FORCE_ELIGIBILITY, index, 0, @intFromBool(target != 0), @ptrCast(&reference), &clonewars_force_eligibility_debug[index]);
        if (accepted == 0 or !s.live(&lease)) return 0;
        if (s.journal.host != 0) return target;
        if (target != 0 and (reference.kind == .none or reference.kind == .unbound)) return target;
        const expected = primary.resolve(reference);
        if (expected != 0 and s.live(&lease)) return expected;
    } else {
        if (!eligible(actor, .first_target, target != 0)) return 0;
        if (target != 0) return target;
    }
    if (s.live(&lease)) {
        s.journal.failed = 11;
        s.failed(&lease, actor, null, 11);
    }
    return 0;
}

pub export fn force_release_expired(actor: usize, status: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const expired: c_int = @intFromBool(status & 0x100 == 0);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or !s.valid(actor, 0x1440)) return expired;
    const level = s.journal.frame.?.level;
    if (level != 7 and level != 71 and level != 73 and level != 74) return expired;
    const character = s.read(u16, actor + 0xdc0);
    if (character != 321 and character != 333) return expired;
    if ((level == 74 or (level == 73 and character == 321) or level == 71) and
        s.journal.host == 0 and s.fire_task_cursor != 0)
    {
        const frame = s.journal.frame.?;
        const cursor = s.fire_task_cursor;
        const last = &frame.fire_task_gates[cursor - 1];
        const previous = if (cursor >= 2 and last.kind == p.SYNC_FIRE_ATTACK_SUPPORT)
            &frame.fire_task_gates[cursor - 2]
        else
            last;
        if (cursor < frame.fire_task_gate_count and previous.kind == p.SYNC_ACTOR_CHARACTER_MOTION and
            previous.slot == last.slot and previous.generation == last.generation and
            previous.payload.character_motion.clock == s.read(u32, 0xfb4b6c))
        {
            const next = &frame.fire_task_gates[cursor];
            const identity = s.reference(previous);
            if (next.kind == p.SYNC_ACTOR_CHARACTER_MOTION and next.slot != previous.slot and
                next.payload.character_motion.clock == previous.payload.character_motion.clock and
                s.entities_resolve_reference(&identity) == actor and s.live(&lease)) return 0;
        }
    }
    const stage = @backingInt(Stage.release_expired);
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_FORCE_ELIGIBILITY, stage, 0, expired, null, &clonewars_force_eligibility_debug[stage]);
}

fn bridge(comptime label: []const u8, comptime skip: []const u8, comptime replay: []const u8) []const u8 {
    return ".text\n.globl _" ++ label ++ "_thunk\n_" ++ label ++ "_thunk:\n" ++
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
    ++ "\n    call _" ++ label ++ "\n" ++
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
    ++ "\n" ++ replay ++ "\n    jmp *_" ++ label ++ "_continue\n" ++
        \\1:  popal
        \\    popfl
    ++ "\n    jmp *_" ++ skip ++ "\n";
}

comptime {
    asm (bridge("force_request_eligible", "force_request_eligible_skip", ""));
    asm (bridge("force_request_action", "force_request_eligible_skip", ""));
    asm (bridge("force_request_available", "force_request_available_skip", "movl (%ebx),%eax"));
    asm (
        \\.text
        \\.globl _force_request_begin_thunk
        \\_force_request_begin_thunk:
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
        \\    pushl 4(%edx)
        \\    call _force_request_begin
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jg 2f
        \\    jl 4f
        \\    popal
        \\    popfl
        \\    cmpl %ecx,%edx
        \\    jne 3f
        \\    jmp *_force_request_begin_continue
        \\2:  popal
        \\    popfl
        \\3:  jmp *_force_request_begin_new
        \\4:  popal
        \\    popfl
        \\    jmp *_force_request_begin_continue
    );
    asm (
        \\.text
        \\.globl _force_request_first_target_thunk
        \\_force_request_first_target_thunk:
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
        \\    subl $8,%esp
        \\    pushl 28(%edx)
        \\    pushl 4(%edx)
        \\    cld
        \\    call _force_request_first_target
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    movl %eax,28(%esp)
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    jmp *_force_request_first_target_skip
        \\1: popal
        \\    popfl
        \\    movl (%ebx),%eax
        \\    jmp *_force_request_first_target_continue
    );
    asm (bridge("force_release_expired", "force_release_wait", ""));
}
