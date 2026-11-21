const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var breakup_launch_native: usize = 0;
export var effect_birth_resume: usize = 0;
var projections: u32 = 0;
pub export fn physics_effect_birth(_: usize) void {}
pub export fn physics_apply_breakup_launch(descriptor: usize, handle: usize, matrix: usize, scale: usize, model: usize, native_frame: usize) void {
    const err = win.GetLastError();
    check(@src(), model == 0x77777777 and native_frame == 0x55555555 and descriptor == 0x66666666 and handle == (if (f.iterator < 40) @as(usize, 0x11223344) else 0) and matrix == 0x8899aabb and scale == 0x99aabbcc);
    projections += 1;
    f.projected = 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn native_launch() void;
extern fn physics_breakup_launch_thunk() void;
comptime {
    _ = @import("physics_bridges.zig");
    asm (
        \\.text
        \\_native_launch:
        \\pushfl
        \\incl _native_calls
        \\popfl
        \\pushl %eax
        \\movl 8(%esp),%eax
        \\movl %eax,_argument
        \\popl %eax
        \\ret
    );
}
pub fn main() void {
    breakup_launch_native = @intFromPtr(&native_launch);
    for (0..1000) |_| for ([_]u32{ 0, 39, 40 }) |index| {
        f.iterator = index;
        f.entry = @intFromPtr(&native_launch);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.projected = 0;
        f.entry = @intFromPtr(&physics_breakup_launch_thunk);
        win.SetLastError(123);
        const before = f.native_calls;
        f.invoke_thunk();
        check(@src(), f.projected == 1 and f.native_calls == before + 1 and f.argument == 0x12345678 and win.GetLastError() == 123);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), projections == 3000);
}
