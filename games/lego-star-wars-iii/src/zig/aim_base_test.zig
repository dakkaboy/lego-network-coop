const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var input_delta: f32 = 0;
export var observed_delta: f32 = 0;
export var observed_argument: u32 = 0;
export var wrapper: [8]u8 = @splat(0);
export var aim_base_input_resume: usize = 0;
var selected_delta: f32 = 0;
var input_calls: u32 = 0;
pub const probe_registers =
    \\subl $0x20,%esp
    \\movl $0xaabbccdd,8(%esp)
    \\movl $_wrapper,12(%esp)
    \\movl _input_delta,%eax
    \\movl %eax,16(%esp)
    \\movl $_model,%eax
    \\movl $_task,%ecx
;
pub const probe_after_call = "leal 0x20(%esp),%esp";
export fn cadence_prepare_aim_base(task: usize, native_wrapper: usize, delta: *f32) void {
    const err = win.GetLastError();
    check(@src(), task == @intFromPtr(&f.task) and native_wrapper == @intFromPtr(&wrapper) and delta.* == input_delta);
    input_calls += 1;
    delta.* = selected_delta;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn input_cont() void;
extern fn original_input() void;
extern fn aim_base_input_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("aim_base_input_thunk"));
    asm (
        \\.text
        \\_input_cont:
        \\fstps _observed_delta
        \\movl %eax,_observed_argument
        \\ret
        \\_original_input:
        \\flds 0x14(%esp)
        \\movl 0xc(%esp),%eax
        \\jmp *_aim_base_input_resume
    );
}
pub fn main() void {
    aim_base_input_resume = @intFromPtr(&input_cont);
    for (0..500) |_| for ([_]f32{ 0, 0.017, 1.25 }) |local| for ([_]f32{ 0, 0.025, 2.5 }) |selected| {
        selected_delta = selected;
        input_delta = selected;
        f.entry = @intFromPtr(&original_input);
        f.invoke_thunk();
        check(@src(), observed_delta == selected and observed_argument == 0xaabbccdd);
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        input_delta = local;
        f.entry = @intFromPtr(&aim_base_input_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and observed_delta == selected and observed_argument == 0xaabbccdd);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), input_calls == 4500);
}
