const std = @import("std");
const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var caster: [3]f32 = @splat(0);
export var candidate: [3]f32 = @splat(0);
export var output: [3]f32 = @splat(0);
export var distance_value: f32 = 0;
export var distance_calls: u32 = 0;
export var force_distance_native: usize = 0;
var authoritative: [6]f32 = @splat(0);
var project = false;
var input_calls: u32 = 0;
pub const probe_registers =
    \\subl $0x48,%esp
    \\movl _test_mode,%eax
    \\movl %eax,0x44(%esp)
    \\pushl $_output
    \\pushl $_candidate
    \\pushl $_caster
;
pub const probe_after_call =
    \\fstps _distance_value
    \\leal 0x54(%esp),%esp
;
export fn cadence_force_geometry_input(target: usize, source: usize, mode: u32, points: *[6]f32) void {
    check(@src(), target == 0x77777777 and source == 0x55555555 and mode == f.test_mode);
    check(@src(), std.mem.eql(f32, points[0..3], &caster) and std.mem.eql(f32, points[3..6], &candidate));
    input_calls += 1;
    if (project) points.* = authoritative;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
}
extern fn native_distance() void;
extern fn force_geometry_input_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("force_geometry_input_thunk"));
    asm (
        \\.text
        \\_native_distance:
        \\incl _distance_calls
        \\movl 12(%esp),%eax
        \\subl $12,%esp
        \\movl 16(%esp),%ecx
        \\movl 20(%esp),%edx
        \\flds (%ecx)
        \\fsubs (%edx)
        \\fstps (%eax)
        \\flds 4(%ecx)
        \\fsubs 4(%edx)
        \\fstps 4(%eax)
        \\flds 8(%ecx)
        \\fsubs 8(%edx)
        \\fstps 24(%esp)
        \\flds 24(%esp)
        \\fsts 8(%eax)
        \\flds 4(%eax)
        \\flds (%eax)
        \\fmul %st,%st
        \\fld %st(1)
        \\fmulp %st,%st(2)
        \\faddp %st,%st(1)
        \\fld %st(1)
        \\fmulp %st,%st(2)
        \\faddp %st,%st(1)
        \\fstps 24(%esp)
        \\flds 24(%esp)
        \\addl $12,%esp
        \\ret
    );
}
pub fn main() void {
    force_distance_native = @intFromPtr(&native_distance);
    for (0..5000) |i| {
        f.test_mode = @intCast(i % 3);
        project = i % 2 != 0;
        for (&authoritative, 0..) |*value, j| value.* = @as(f32, @floatFromInt(@as(i32, @intCast((i * 31 + j * 97) % 173)) - 86)) / 37;
        caster = authoritative[0..3].*;
        candidate = authoritative[3..6].*;
        f.entry = force_distance_native;
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const expected = output;
        const distance = distance_value;
        if (project) {
            caster[0] += 0.0001;
            caster[2] -= 0.02;
            candidate[0] -= 0.0001;
            candidate[2] += 0.02;
        }
        const local_caster = caster;
        const local_candidate = candidate;
        f.entry = @intFromPtr(&force_geometry_input_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and distance_value == distance and std.mem.eql(f32, &expected, &output));
        check(@src(), std.mem.eql(u8, &fx, &f.observed_fx));
        check(@src(), std.mem.eql(u32, regs[0..5], f.observed_regs[0..5]));
        check(@src(), std.mem.eql(f32, &local_caster, &caster) and std.mem.eql(f32, &local_candidate, &candidate));
    }
    check(@src(), input_calls == 5000 and distance_calls == 10000);
}
