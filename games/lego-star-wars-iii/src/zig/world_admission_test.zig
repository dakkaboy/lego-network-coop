const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var caller_fx: [512]u8 align(16) = @splat(0);
export var observed_fx: [512]u8 align(16) = @splat(0);
export var observed_regs: [9]u32 = @splat(0);
export var branch: u32 = 0;
export var native_calls: u32 = 0;
export var transition_arg: u32 = 0;
export var entry: usize = 0;
export var fpu_values: [2]f64 = .{ 1.25, 2.5 };
export var mxcsr_value: u32 = 0x3f80;
export var world_transition: usize = 0;
export var world_continue: usize = 0;
export var world_exit_resume: usize = 0;
export var world_continue_resume: usize = 0;
var input_calls: u32 = 0;
var expected_local: u32 = 0;
var selected: u32 = 0;
pub export fn native_tick_decision(site: u32, local: u32) u32 {
    const err = win.GetLastError();
    check(@src(), site == 0x888889 and local == expected_local);
    input_calls += 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
    return selected;
}
extern fn transition_stub() void;
extern fn continue_stub() void;
extern fn resume_stub() void;
extern fn original_exit() void;
extern fn original_continue() void;
extern fn native_world_exit() void;
extern fn native_world_continue() void;
extern fn invoke() void;
comptime {
    asm (@import("tick_bridge_code.zig").code("native_world_exit"));
    asm (@import("tick_bridge_code.zig").code("native_world_continue"));
}
pub fn main() void {
    world_transition = @intFromPtr(&transition_stub);
    world_continue = @intFromPtr(&continue_stub);
    world_exit_resume = @intFromPtr(&resume_stub);
    world_continue_resume = @intFromPtr(&resume_stub);
    for (0..1000) |_| for (0..2) |local| for (0..2) |canonical| {
        expected_local = @intCast(local);
        selected = @intCast(canonical);
        entry = if (selected != 0) @intFromPtr(&original_exit) else @intFromPtr(&original_continue);
        branch = 0;
        native_calls = 0;
        transition_arg = 0;
        invoke();
        check(@src(), branch == (if (selected != 0) @as(u32, 1) else 2) and native_calls == 1 and transition_arg == (if (selected != 0) @as(u32, 15) else 0));
        const fx = observed_fx;
        const regs = observed_regs;
        entry = if (expected_local != 0) @intFromPtr(&native_world_exit) else @intFromPtr(&native_world_continue);
        branch = 0;
        native_calls = 0;
        transition_arg = 0;
        win.SetLastError(123);
        invoke();
        check(@src(), branch == (if (selected != 0) @as(u32, 1) else 2) and native_calls == 1 and transition_arg == (if (selected != 0) @as(u32, 15) else 0));
        check(@src(), win.GetLastError() == 123);
        for (regs, observed_regs, 0..) |a, b, i| if (a != b) {
            std.debug.print("register {d}: {x} vs {x}\n", .{ i, a, b });
            check(@src(), false);
        };
        for (fx, observed_fx, 0..) |a, b, i| if (a != b) {
            std.debug.print("fx byte {d}: {x} vs {x}\n", .{ i, a, b });
            check(@src(), false);
        };
    };
    check(@src(), input_calls == 4000);
}

comptime {
    asm (
        \\.text
        \\_transition_stub:
        \\movl $1,_branch
        \\    pushfl
        \\    incl _native_calls
        \\    popfl
        \\    pushl %eax
        \\    movl 8(%esp),%eax
        \\    movl %eax,_transition_arg
        \\    popl %eax
        \\    ret $4
        \\_continue_stub:
        \\movl $2,_branch
        \\    pushfl
        \\    incl _native_calls
        \\    popfl
        \\    ret
        \\_resume_stub:
        \\ret
        \\_original_exit:
        \\pushl $0xf
        \\    movl %edi,%ecx
        \\    call *_world_transition
        \\    jmp *_world_exit_resume
        \\_original_continue:
        \\call *_world_continue
        \\    jmp *_world_continue_resume
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
        \\    movl $0x11111111,%eax
        \\    movl $0x22222222,%ecx
        \\    movl $0x33333333,%edx
        \\    movl $0x44444444,%ebx
        \\    movl $0x55555555,%ebp
        \\    movl $0x66666666,%esi
        \\    movl $0x77777777,%edi
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
        \\    fxrstor _caller_fx
        \\    popal
        \\    popfl
        \\    ret
    );
}
