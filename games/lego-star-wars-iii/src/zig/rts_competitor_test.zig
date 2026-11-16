const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const context = @import("cadence_context.zig");
const check = @import("native_test_support.zig").check;
export var caller_fx: [512]u8 align(16) = @splat(0);
export var observed_fx: [512]u8 align(16) = @splat(0);
export var observed_regs: [9]u32 = @splat(0);
export var model: [0x50]u8 = @splat(0);
export var task: [0x30]u8 = @splat(0);
export var entry: usize = 0;
export var fpu_values: [2]f64 = .{ 1.25, 2.5 };
export var mxcsr_value: u32 = 0x3f80;
export var observed_delta: u32 = 0;
export var rts_competitor_input_resume: usize = 0;
var input_calls: u32 = 0;
pub export fn cadence_prepare_rts_competitor(competitor: usize, delta: *f32) void {
    const err = win.GetLastError();
    check(@src(), competitor == @intFromPtr(&task) and delta.* == 0.05);
    input_calls += 1;
    delta.* = 0.017;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn native_cont() void;
extern fn original_input() void;
extern fn invoke() void;
extern fn rts_competitor_input_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("rts_competitor_input_thunk"));
}
pub fn main() void {
    rts_competitor_input_resume = @intFromPtr(&native_cont);
    for (0..3000) |_| {
        entry = @intFromPtr(&original_input);
        invoke();
        const fx = observed_fx;
        const regs = observed_regs;
        entry = @intFromPtr(&rts_competitor_input_thunk);
        win.SetLastError(123);
        invoke();
        check(@src(), win.GetLastError() == 123 and @as(f32, @bitCast(observed_delta)) == 0.017);
        for (regs, observed_regs, 0..) |a, b, i| if (a != b) {
            std.debug.print("register {d}: {x} vs {x}\n", .{ i, a, b });
            check(@src(), false);
        };
        for (fx, observed_fx, 0..) |a, b, i| if (a != b) {
            std.debug.print("fx byte {d}: {x} vs {x}\n", .{ i, a, b });
            check(@src(), false);
        };
    }
    check(@src(), input_calls == 3000);
    var a = std.mem.zeroes(p.SyncRtsCompetitorState);
    a.rng_game = 123;
    a.rng_engine = 456;
    a.clock = 200;
    a.competitor_class = 0x6ee004;
    a.delta = 0.017;
    var b = a;
    b.rng_game = 789;
    b.rng_engine = 333;
    b.delta = 0.02;
    b.timers[11] = 1;
    check(@src(), context.competitor(&a, &b));
    b = a;
    b.clock += 1;
    check(@src(), !context.competitor(&a, &b));
    b = a;
    b.competitor_class += 1;
    check(@src(), !context.competitor(&a, &b));
}

comptime {
    asm (
        \\.text
        \\_native_cont:
        \\movl %ebp,%esp
        \\    popl %ebp
        \\    ret
        \\_original_input:
        \\pushl %ebp
        \\    movl %esp,%ebp
        \\    andl $-16,%esp
        \\    jmp *_rts_competitor_input_resume
        \\_invoke:
        \\pushfl
        \\    pushal
        \\    fxsave _caller_fx
        \\    fninit
        \\    fldl _fpu_values
        \\    fldl _fpu_values+8
        \\    ldmxcsr _mxcsr_value
        \\    pcmpeqd %xmm0,%xmm0
        \\    pcmpeqd %xmm7,%xmm7
        \\    pslld $7,%xmm7
        \\pcmpeqd %xmm1,%xmm1; movdqa %xmm7,%xmm2; pxor %xmm3,%xmm3; movdqa %xmm7,%xmm4; pcmpeqd %xmm5,%xmm5; pxor %xmm6,%xmm6
        \\    pushl $0x646
        \\    popfl
        \\    movl $_model,%eax
        \\    movl $0x22222222,%ecx
        \\    movl $0x33333333,%edx
        \\    movl $0x44444444,%ebx
        \\    movl $0x55555555,%ebp
        \\    movl $0x66666666,%esi
        \\    movl $_task,%edi
        \\    movl $_task,%ecx
        \\    pushl $0x3d4ccccd
        \\    call *_entry
        \\    pushfl
        \\    pushal
        \\    movl %esp,%esi
        \\    movl $_observed_regs,%edi
        \\    movl $9,%ecx
        \\    cld
        \\    rep movsl
        \\    fxsave _observed_fx
        \\    addl $36,%esp
        \\    popl _observed_delta
        \\    fxrstor _caller_fx
        \\    popal
        \\    popfl
        \\    ret
    );
}
