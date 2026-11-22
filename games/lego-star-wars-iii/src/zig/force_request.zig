const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn force_request_eligible_thunk() void;
pub extern fn force_request_action_thunk() void;
pub extern fn force_request_available_thunk() void;
export var force_request_eligible_continue: usize = 0x84bc9d;
export var force_request_action_continue: usize = 0x84bcd9;
export var force_request_available_continue: usize = 0x84bd03;
export var force_request_eligible_skip: usize = 0x84be6e;
export var force_request_available_skip: usize = 0x84bd31;
pub export var clonewars_force_eligibility_debug: [3][4]u32 = @splat(@splat(0));

const Stage = enum(u16) { area, action, available };
pub fn eligible(actor: usize, stage: Stage, local: bool) bool {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or s.read(u32, actor + 0x50) & 0x200 == 0) return local;
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
}
