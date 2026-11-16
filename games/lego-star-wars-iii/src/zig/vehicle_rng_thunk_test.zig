const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var vehicle_rng_float_native: usize = 0;
export var vehicle_rng_integer_native: usize = 0;
export var rng_return: f64 = 0.375;
var projections: u32 = 0;
pub export fn physics_apply_vehicle_rng(descriptor: usize, site: u32) void {
    const err = win.GetLastError();
    check(@src(), descriptor == 0x66666666 and site == f.argument - 5);
    projections += 1;
    f.projected = 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn native_float_rng() void;
extern fn native_integer_rng() void;
extern fn vehicle_rng_float_thunk() void;
extern fn vehicle_rng_integer_thunk() void;
comptime {
    _ = @import("vehicle_rng_bridge.zig");
    asm (
        \\.text
        \\_native_float_rng:
        \\pushfl
        \\incl _native_calls
        \\popfl
        \\pushl %eax
        \\movl 4(%esp),%eax
        \\movl %eax,_argument
        \\popl %eax
        \\fldl _rng_return
        \\ret
        \\_native_integer_rng:
        \\pushfl
        \\incl _native_calls
        \\popfl
        \\movl (%esp),%eax
        \\movl %eax,_argument
        \\movl $0x8badf00d,%eax
        \\ret
    );
}
pub fn main() void {
    vehicle_rng_float_native = @intFromPtr(&native_float_rng);
    vehicle_rng_integer_native = @intFromPtr(&native_integer_rng);
    const originals = [_]usize{ vehicle_rng_float_native, vehicle_rng_integer_native };
    const hooks = [_]usize{ @intFromPtr(&vehicle_rng_float_thunk), @intFromPtr(&vehicle_rng_integer_thunk) };
    for (0..1000) |_| for ([_]u16{ 0x7f, 0x27f, 0x37f }) |control| for (0..2) |kind| {
        f.fp_control = control;
        f.iterator = 0;
        f.entry = originals[kind];
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.projected = 0;
        f.entry = hooks[kind];
        win.SetLastError(123);
        const before = f.native_calls;
        f.invoke_thunk();
        check(@src(), f.projected == 1 and f.native_calls == before + 1 and win.GetLastError() == 123);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), projections == 6000);
}
