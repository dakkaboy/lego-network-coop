const s = @import("reaction_state.zig");
pub export var native_action_trace_resume: usize = 0x89e437;
pub export var clonewars_native_action_trace_debug: [2]u32 = .{ 0, 2048 };
pub export var clonewars_native_action_trace_entries: [2048][16]u32 = @splat(@splat(0));
pub export fn native_action_trace_record(state: usize, next: u32, caller: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (!s.active or state < 0x260) return;
    var op: s.Lease = undefined;
    if (!s.get(&op) or op.cohort.thread != s.win.GetCurrentThreadId()) return;
    const actor = state - 0x260;
    if (!s.valid(actor, 0x1440)) return;
    const character = s.read(u16, actor + 0xdc0);
    switch (s.journal.frame.?.level) {
        12 => {
            if (next & 65535 != 65535 and next & 65535 != 116 and next & 65535 != 11) return;
            if (character != 119 and character != 189 and character != 235) return;
        },
        64 => {
            if (s.read(u32, actor + 0x50) & 0x200 == 0) return;
        },
        else => return,
    }
    const count = clonewars_native_action_trace_debug[0];
    clonewars_native_action_trace_entries[count % 2048] = .{ count, op.cohort.epoch, op.cohort.sequence, s.read(u32, 0xfb4b6c), @truncate(caller), @truncate(actor), character, s.read(u16, actor + 0x2f4), next & 65535, s.read(u16, actor + 0x2e8), s.read(u32, actor + 0x2a0), s.read(u8, actor + 0x2fa), s.read(u8, actor + 0xdde), s.read(u32, actor + 0x50), s.read(u32, 0xfb4b74), s.read(u8, actor + 0x309) };
    clonewars_native_action_trace_debug[0] +%= 1;
}
comptime {
    asm (
        \\.text
        \\.globl _native_action_trace_thunk
        \\_native_action_trace_thunk:
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
        \\pushl 36(%edx)
        \\pushl 44(%edx)
        \\pushl 40(%edx)
        \\cld
        \\call _native_action_trace_record
        \\addl $12,%esp
        \\fxrstor (%esp)
        \\movl 520(%esp),%eax
        \\movl %eax,%fs:0x34
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\pushl %esi
        \\movl 8(%esp),%esi
        \\testl %esi,%esi
        \\jmp *_native_action_trace_resume
    );
}
