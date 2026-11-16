const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var caller_fx: [512]u8 align(16) = @splat(0);
export var observed_fx: [512]u8 align(16) = @splat(0);
export var flow: [0x80]u8 align(16) = @splat(0);
export var observed_regs: [9]u32 = @splat(0);
export var native_calls: u32 = 0;
export var entry: usize = 0;
export var fpu_values: [2]f64 = .{ 1.25, 2.5 };
export var mxcsr_value: u32 = 0x3f80;
export var flow_request_resume: usize = 0;
var input_calls: u32 = 0;
var expected_local: u32 = 0;
var selected: u32 = 0;
pub export fn native_flow_request(p: usize) void {
    const err = win.GetLastError();
    check(@src(), p == @intFromPtr(&flow) and win.load(u32, p + 0x60) == expected_local);
    input_calls += 1;
    win.store(u32, p + 0x60, selected);
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn native_cont() void;
extern fn original_input() void;
extern fn native_flow_request_input() void;
extern fn invoke() void;
comptime {
    asm (@import("tick_bridge_code.zig").code("native_flow_request_input"));
}
pub fn main() void {
    flow_request_resume = @intFromPtr(&native_cont);
    for (0..200) |_| for ([_]u32{ 0xffffffff, 11, 14 }) |local| for ([_]u32{ 0xffffffff, 0, 11, 13, 14, 20 }) |request| {
        selected = request;
        expected_local = local;
        win.store(u32, @intFromPtr(&flow) + 0x60, selected);
        win.store(u32, @intFromPtr(&flow) + 0x34, 14);
        native_calls = 0;
        entry = @intFromPtr(&original_input);
        invoke();
        check(@src(), native_calls == @intFromBool(selected != 0xffffffff));
        const saved_state = win.load(u32, @intFromPtr(&flow) + 0x34);
        const fx = observed_fx;
        const regs = observed_regs;
        win.store(u32, @intFromPtr(&flow) + 0x60, expected_local);
        win.store(u32, @intFromPtr(&flow) + 0x34, 14);
        native_calls = 0;
        entry = @intFromPtr(&native_flow_request_input);
        win.SetLastError(123);
        invoke();
        check(@src(), native_calls == @intFromBool(selected != 0xffffffff) and win.load(u32, @intFromPtr(&flow) + 0x34) == saved_state and win.load(u32, @intFromPtr(&flow) + 0x60) == 0xffffffff);
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
    check(@src(), input_calls == 3600);
}

comptime {
    asm (
        \\.text
        \\_transition_stub:
        \\movl 4(%esp),%eax
        \\    movl %eax,0x34(%ecx)
        \\    pushfl
        \\    incl _native_calls
        \\    popfl
        \\    ret $4
        \\_native_cont:
        \\je 1f
        \\    pushl %eax
        \\    movl %esi,%ecx
        \\    call _transition_stub
        \\    movl $-1,0x60(%esi)
        \\    1: ret
        \\_original_input:
        \\movl 0x60(%esi),%eax
        \\    cmpl %edi,%eax
        \\    jmp *_flow_request_resume
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
        \\    pcmpeqd %xmm1,%xmm1
        \\    movdqa %xmm7,%xmm2
        \\    pxor %xmm3,%xmm3
        \\    movdqa %xmm7,%xmm4
        \\    pcmpeqd %xmm5,%xmm5
        \\    pxor %xmm6,%xmm6
        \\    pushl $0x646
        \\    popfl
        \\    movl $0x11111111,%eax
        \\    movl $0x22222222,%ecx
        \\    movl $0x33333333,%edx
        \\    movl $0x44444444,%ebx
        \\    movl $0x55555555,%ebp
        \\    movl $_flow,%esi
        \\    movl $-1,%edi
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
