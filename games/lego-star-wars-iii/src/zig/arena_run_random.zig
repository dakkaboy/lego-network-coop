const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
pub export var arena_run_random_original: usize = 0x78e450;
pub export var clonewars_arena_run_random_debug: [4]u32 = @splat(0);
pub export var clonewars_arena_run_random_failure: [10]u32 = @splat(0);
pub export var clonewars_arena_run_random_correction: [10]u32 = @splat(0);
const Source = struct { parent: usize, actor: usize, generation: u32, state: p.SyncArenaRunRandomState };
fn source(controller: usize) ?Source {
    if (!s.valid(controller, 0x84) or s.imageClass(s.read(usize, controller), true) != 0x6dee68) return null;
    const parent = s.read(usize, controller + 0x14);
    const actor = s.read(usize, controller + 0x10);
    if (!s.valid(parent, 0x348) or s.imageClass(s.read(usize, parent), true) != 0x6d83dc or s.read(usize, parent + 0x340) != controller or
        !s.valid(actor, 0x1440) or s.read(u32, actor + 0x50) & 3 != 3 or s.read(i16, actor + 0xdc0) != 119 or s.read(u32, controller + 0x40) != 10) return null;
    const generation = s.entities_observed_generation(actor);
    if (generation == 0 or s.entities_allocation_retained(actor, generation) == 0) return null;
    return .{ .parent = parent, .actor = actor, .generation = generation, .state = .{ .clock = s.read(u32, 0xfb4b6c), .behavior_class = 0x6dee68, .run_state = 10 } };
}
fn failed(op: *const s.Lease, controller: usize, caller: usize, value: u32, reason: u32) void {
    if (!s.live(op)) return;
    clonewars_arena_run_random_debug[3] +%= 1;
    if (clonewars_arena_run_random_failure[0] == 0) clonewars_arena_run_random_failure = .{ reason, op.cohort.epoch, op.cohort.sequence, s.read(u32, 0xfb4b6c), @truncate(controller), @truncate(caller), value, s.read(u32, 0xe637b4), 0, 0 };
    s.journal.failed = 22;
    s.failed(op, 0, null, 22);
}
pub export fn cadence_arena_run_random(controller: usize, caller: usize, value: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op) or s.journal.frame.?.level != 12) return value;
    const side: u16 = if (caller == 0x464b44) 0 else if (caller == 0x464b71) 1 else {
        failed(&op, controller, caller, value, 1);
        return value;
    };
    s.entities_update();
    if (!s.live(&op)) return value;
    const before = source(controller) orelse {
        failed(&op, controller, caller, value, 2);
        return value;
    };
    if (value > 65535 or s.read(u32, 0xe637b4) != value) {
        failed(&op, controller, caller, value, 3);
        return value;
    }
    if (s.journal.host == 0 and s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count and !@import("fire_validation.zig").valid(&s.journal.frame.?.fire_task_gates[s.fire_task_cursor])) {
        failed(&op, controller, caller, value, 6);
        return value;
    }
    var state = before.state;
    if (s.journal.host == 0 and s.fire_task_cursor < s.journal.frame.?.fire_task_gate_count and !@import("fire_validation.zig").valid(&s.journal.frame.?.fire_task_gates[s.fire_task_cursor])) {
        failed(&op, controller, caller, value, 6);
        return value;
    }
    const result = @import("cadence_gate.zig").apply(before.actor, p.SYNC_ACTOR_ARENA_RUN_RANDOM, side, 0, @intCast(value), @ptrCast(&state), &clonewars_arena_run_random_debug);
    if (!s.live(&op) or s.journal.failed != 0) return value;
    const now = source(controller) orelse {
        failed(&op, controller, caller, value, 4);
        return value;
    };
    if (!@import("validation.zig").equal(&before, &now) or !@import("validation.zig").equal(&before.state, &state) or s.read(u32, 0xe637b4) != value or result < 0 or result > 65535 or !s.win.accessible(0xe637b4, 4, true)) {
        failed(&op, controller, caller, value, 5);
        return value;
    }
    if (s.journal.host == 0) {
        if (side == 1 and value != @as(u32, @intCast(result)) and clonewars_arena_run_random_correction[0] == 0) clonewars_arena_run_random_correction = .{ op.cohort.epoch, op.cohort.sequence, state.clock, side, @truncate(controller), @truncate(before.actor), before.generation, value, @intCast(result), state.behavior_class };
        s.win.store(u32, 0xe637b4, @intCast(result));
    }
    return @intCast(result);
}
comptime {
    asm (
        \\.text
        \\.globl _arena_run_random_thunk
        \\_arena_run_random_thunk:
        \\call *_arena_run_random_original
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\movl %fs:0x34,%eax
        \\movl %eax,520(%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\pushl 28(%edx)
        \\pushl 36(%edx)
        \\pushl 4(%edx)
        \\cld
        \\call _cadence_arena_run_random
        \\addl $12,%esp
        \\movl 512(%esp),%edx
        \\movl %eax,28(%edx)
        \\fxrstor (%esp)
        \\movl 520(%esp),%eax
        \\movl %eax,%fs:0x34
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\ret
    );
}
