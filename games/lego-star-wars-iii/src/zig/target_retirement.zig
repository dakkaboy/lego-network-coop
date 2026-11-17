const s = @import("tick_state.zig");
const Entry = struct { pool: usize = 0, generation: u32 = 0, epoch: u32 = 0 };
var entries: [s.p.SYNC_MAX_ACTORS]Entry = @splat(.{});
pub export var clonewars_target_retirement_debug: [4]u32 = @splat(0);
pub export var target_retirement_native: usize = 0x791930;
pub export var target_retirement_resume: usize = 0x8766ad;
extern fn entities_observed_generation(usize) u32;
pub fn invalidate(actor: usize) void {
    const pool = s.load(usize, 0xfb2f60);
    if (actor < pool or (actor - pool) % 0x1440 != 0) return;
    const index = (actor - pool) / 0x1440;
    if (index < entries.len) entries[index] = .{};
}
pub export fn note_retired_target(actor: usize) void {
    if (!s.ready()) return;
    const pool = s.load(usize, 0xfb2f60);
    if (pool == 0 or actor < pool or (actor - pool) % 0x1440 != 0) return;
    const index = (actor - pool) / 0x1440;
    if (index >= entries.len or index >= s.load(u32, 0xfb2e3c) or !s.readable(actor, 0x1440)) return;
    const generation = entities_observed_generation(actor);
    if (generation == 0 or s.load(u32, actor + 0x50) != 0 or s.load(usize, actor + 8) != 0) return;
    entries[index] = .{ .pool = pool, .generation = generation, .epoch = s.frame.?.epoch };
    clonewars_target_retirement_debug[0] +%= 1;
}
pub fn witnessed(actor: usize) bool {
    if (!s.ready()) return false;
    const pool = s.load(usize, 0xfb2f60);
    if (pool == 0 or actor < pool or (actor - pool) % 0x1440 != 0) return false;
    const index = (actor - pool) / 0x1440;
    if (index >= entries.len or index >= s.load(u32, 0xfb2e3c) or !s.readable(actor, 0x1440)) return false;
    const e = entries[index];
    if (e.pool != pool or e.generation == 0 or e.epoch != s.frame.?.epoch or s.load(u32, actor + 0x50) != 0 or s.load(usize, actor + 8) != 0) return false;
    const current = entities_observed_generation(actor);
    return current == 0 or current == e.generation;
}
comptime {
    asm (
        \\.text
        \\.globl _target_retirement_thunk
        \\_target_retirement_thunk:
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
        \\pushl %edi
        \\cld
        \\call _note_retired_target
        \\addl $4,%esp
        \\fxrstor (%esp)
        \\movl 520(%esp),%eax
        \\movl %eax,%fs:0x34
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\addl $8,%esp
        \\call *_target_retirement_native
        \\jmp *_target_retirement_resume
    );
}
