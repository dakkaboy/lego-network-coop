const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const shot = @import("projectile_types.zig");
extern fn projectiles_observe_live(usize, *shot.Identity) c_int;
extern fn combat_damage_source_id() u32;
extern fn combat_damage_native_caller() u32;

pub extern fn projectile_actor_reflect_thunk() void;
pub extern fn projectile_actor_damage_thunk() void;
pub extern fn projectile_actor_followup_thunk() void;
pub extern fn projectile_player_hit_thunk() void;
pub extern fn projectile_hit_action_thunk() void;
extern fn projectile_actor_reflect_resume() void;
extern fn projectile_actor_damage_resume() void;
extern fn projectile_actor_followup_resume() void;
export const projectile_actor_reflect_continue: usize = 0x81ecf6;
export const projectile_actor_damage_continue: usize = 0x81f094;
export const projectile_actor_followup_continue: usize = 0x81f388;
export const projectile_player_hit_continue: usize = 0x81f27f;
export const projectile_player_hit_native: usize = 0x96a4c0;
export const projectile_hit_action_continue: usize = 0x96a95a;

pub export var clonewars_projectile_actor_branch_debug: [4]u32 = @splat(0);

export fn projectile_actor_branch(actor: usize, object: usize, local: c_int) usize {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return switch (branch(actor, object, local)) {
        1 => @intFromPtr(&projectile_actor_reflect_resume),
        2 => @intFromPtr(&projectile_actor_followup_resume),
        else => @intFromPtr(&projectile_actor_damage_resume),
    };
}

fn branch(actor: usize, object: usize, local: c_int) c_int {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 73 or !s.valid(actor, 0x1440) or s.read(i16, actor + 0xdc0) != 184) return local;
    var identity: shot.Identity = undefined;
    if (projectiles_observe_live(object, &identity) != 1 or identity.weapon != 7 or !s.live(&lease)) return local;
    // Select the native path before it applies damage or creates a follow-up.
    var context: [2]u32 = .{ s.read(u32, 0xfb4b6c), identity.id };
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PROJECTILE_BRANCH, 0, 0, local, @ptrCast(&context), &clonewars_projectile_actor_branch_debug);
}

pub export fn projectile_player_hit(actor: usize, object: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or !s.valid(actor, 0x1440)) return 1;
    const frame = s.journal.frame.?;
    const character = s.read(i16, actor + 0xdc0);
    if (!((frame.level == 71 and character == 156) or (frame.level == 74 and character == 188))) return 1;
    var identity: shot.Identity = undefined;
    if (projectiles_observe_live(object, &identity) != 1 or identity.weapon != 7 or !s.live(&lease)) return 1;
    var context = [2]u32{ s.read(u32, 0xfb4b6c), identity.id };
    if (s.journal.host == 0) {
        if (s.fire_task_cursor >= frame.fire_task_gate_count) return 0;
        const next = &frame.fire_task_gates[s.fire_task_cursor];
        if (next.kind != p.SYNC_ACTOR_PROJECTILE_BRANCH or next.flags != 1 or
            next.payload.projectile_branch[0] != context[0] or next.payload.projectile_branch[1] != context[1]) return 0;
    }
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PROJECTILE_BRANCH, 1, 0, 1, @ptrCast(&context), &clonewars_projectile_actor_branch_debug);
}

pub export fn projectile_hit_action(actor: usize, action_flags: u32) u32 {
    const native_mask = action_flags & 4;
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 73 or combat_damage_native_caller() != 0x81f27f or
        !s.valid(actor, 0x1440) or s.read(i16, actor + 0xdc0) != 184) return native_mask;
    const source = combat_damage_source_id();
    if (source == 0) return native_mask;
    // A matching impact can arrive during a different animation on the guest.
    var context: [2]u32 = .{ s.read(u32, 0xfb4b6c), source };
    const blocked = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_PROJECTILE_BRANCH, 2, 0, @intFromBool(native_mask != 0), @ptrCast(&context), &clonewars_projectile_actor_branch_debug);
    return if (blocked != 0) 4 else 0;
}

comptime {
    asm (
        \\.text
        \\.globl _projectile_hit_action_thunk
        \\_projectile_hit_action_thunk:
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
        \\    call _projectile_hit_action
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    movl %eax,28(%esp)
        \\    popal
        \\    popfl
        \\    xorl %ecx,%ecx
        \\    orl %eax,%ecx
        \\    jmp *_projectile_hit_action_continue
        \\.globl _projectile_player_hit_thunk
        \\_projectile_player_hit_thunk:
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
        \\    call _projectile_player_hit
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 2f
        \\    popal
        \\    popfl
        \\    pushl _projectile_player_hit_continue
        \\    jmp *_projectile_player_hit_native
        \\2:  popal
        \\    popfl
        \\    jmp *_projectile_player_hit_continue
        \\.globl _projectile_actor_reflect_thunk
        \\_projectile_actor_reflect_thunk:
        \\    pushl $1
        \\    jmp 1f
        \\.globl _projectile_actor_damage_thunk
        \\_projectile_actor_damage_thunk:
        \\    pushl $0
        \\    jmp 1f
        \\.globl _projectile_actor_followup_thunk
        \\_projectile_actor_followup_thunk:
        \\    pushl $2
        \\1:  pushfl
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
        \\    pushl 36(%edx)
        \\    pushl 0(%edx)
        \\    pushl 4(%edx)
        \\    call _projectile_actor_branch
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    movl %eax,36(%esp)
        \\    popal
        \\    popfl
        \\    ret
        \\.globl _projectile_actor_reflect_resume
        \\_projectile_actor_reflect_resume:
        \\    movl 20(%ebp),%ebx
        \\    movl 16(%ebp),%eax
        \\    jmp *_projectile_actor_reflect_continue
        \\.globl _projectile_actor_damage_resume
        \\_projectile_actor_damage_resume:
        \\    movl 0x14(%edi),%eax
        \\    movl 0x74(%eax),%ecx
        \\    jmp *_projectile_actor_damage_continue
        \\.globl _projectile_actor_followup_resume
        \\_projectile_actor_followup_resume:
        \\    movl 0x160(%edi),%eax
        \\    jmp *_projectile_actor_followup_continue
    );
}
