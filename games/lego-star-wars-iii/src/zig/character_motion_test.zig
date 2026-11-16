const std = @import("std");
const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var actor: [0x1440]u8 align(16) = @splat(0);
export var body: [0x140]u8 align(16) = @splat(0);
export var source_velocity: [4]u32 align(16) = @splat(0);
export var canonical_velocity: [4]u32 align(16) = @splat(0);
export var native_argument: usize = 0;
export var native_body: usize = 0;
export var character_velocity_native: usize = 0;
export var initial_flags: u32 = 0;
var helper_calls: u32 = 0;
var projection_calls: u32 = 0;
var fallback_calls: u32 = 0;
var helper_mode: u32 = 0;
pub const probe_flags = "pushl _initial_flags";
pub const probe_registers =
    \\movl $_body,%ecx
    \\movl $_actor,%ebx
    \\pushl $_source_velocity
;
export fn cadence_character_motion_input(source_actor: usize, character: usize, velocity: *[4]u32) void {
    const err = win.GetLastError();
    const flags = asm volatile ("pushfl; popl %[value]"
        : [value] "=r" (-> u32),
    );
    var mxcsr: u32 = 0;
    var cw: u16 = 0;
    var status: u16 = 0;
    asm volatile ("stmxcsr (%[mxcsr]); fnstcw (%[cw]); fnstsw (%[status])"
        :
        : [mxcsr] "r" (&mxcsr),
          [cw] "r" (&cw),
          [status] "r" (&status),
        : .{ .memory = true });
    check(@src(), source_actor == @intFromPtr(&actor) and character == @intFromPtr(&body) and velocity != &source_velocity);
    check(@src(), flags & 0x400 == 0 and mxcsr == 0x1f80 and cw == 0x37f and status & 0x3800 == 0);
    check(@src(), std.mem.eql(u32, velocity, &source_velocity));
    helper_calls += 1;
    if (helper_mode == 2 or helper_mode == 3) {
        velocity.* = canonical_velocity;
        projection_calls += 1;
    } else if (helper_mode == 0) fallback_calls += 1;
    const control: u32 = 0x5f80;
    asm volatile ("fninit; fldz; fld1; ldmxcsr (%[control]); pcmpeqd %%xmm0,%%xmm0; pcmpeqd %%xmm1,%%xmm1; pcmpeqd %%xmm2,%%xmm2; pcmpeqd %%xmm3,%%xmm3; pcmpeqd %%xmm4,%%xmm4; pcmpeqd %%xmm5,%%xmm5; pcmpeqd %%xmm6,%%xmm6; pcmpeqd %%xmm7,%%xmm7; stc"
        :
        : [control] "r" (&control),
        : .{ .memory = true, .cc = true, .xmm0 = true, .xmm1 = true, .xmm2 = true, .xmm3 = true, .xmm4 = true, .xmm5 = true, .xmm6 = true, .xmm7 = true });
    win.SetLastError(err);
}
extern fn native_velocity() void;
extern fn character_motion_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("character_motion_thunk"));
    asm (
        \\.text
        \\_native_velocity:
        \\pushfl
        \\incl _native_calls
        \\popfl
        \\movl 4(%esp),%eax
        \\movl %eax,_native_argument
        \\movl %ecx,_native_body
        \\flds (%eax)
        \\fstps 0xb0(%ecx)
        \\flds 4(%eax)
        \\fstps 0xb4(%ecx)
        \\flds 8(%eax)
        \\fstps 0xb8(%ecx)
        \\flds 12(%eax)
        \\fstps 0xbc(%ecx)
        \\ret $4
    );
}
fn sameFx(expected: *const [512]u8) void {
    check(@src(), std.mem.eql(u8, expected[0..5], f.observed_fx[0..5]) and std.mem.eql(u8, expected[24..32], f.observed_fx[24..32]));
    for (0..8) |i| check(@src(), std.mem.eql(u8, expected[32 + 16 * i ..][0..10], f.observed_fx[32 + 16 * i ..][0..10]));
    check(@src(), std.mem.eql(u8, expected[160..288], f.observed_fx[160..288]));
}
pub fn main() void {
    character_velocity_native = @intFromPtr(&native_velocity);
    f.fpu_values = .{ 1.25, -2.5 };
    const boundary = [_]u32{ 0, 0x80000000, 0x3f800000, 0xbf800000, 0x7f7fffff, 0xff7fffff, 0x00800000, 0x80800000, 1, 0x80000001, 0x3f000001, 0xbf000001 };
    for (0..5000) |i| {
        helper_mode = @intCast(i % 4);
        initial_flags = if (i & 1 != 0) 0x646 else 0x297;
        f.fp_control = @intCast(0x37f | ((i % 4) << 10));
        f.mxcsr_value = @intCast(0x1f80 | ((i % 4) << 13));
        for (&actor, 0..) |*v, j| v.* = @truncate(i * 17 + j * 29);
        for (&body, 0..) |*v, j| v.* = @truncate(i * 43 + j * 13);
        var local_words: [4]u32 = undefined;
        for (&local_words, &canonical_velocity, 0..) |*local, *canonical, j| {
            local.* = boundary[(i + j * 3) % 12];
            canonical.* = boundary[(i + j * 5 + 7) % 12];
        }
        if (helper_mode == 3) canonical_velocity = local_words;
        const body_before = body;
        const actor_before = actor;
        const expected_words = if (helper_mode == 2 or helper_mode == 3) canonical_velocity else local_words;
        source_velocity = expected_words;
        const before = f.native_calls;
        f.entry = character_velocity_native;
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.native_calls == before + 1 and native_body == @intFromPtr(&body));
        check(@src(), native_argument == @intFromPtr(&source_velocity) and f.observed_regs[7] == native_argument);
        const expected_body = body;
        const expected_fx = f.observed_fx;
        const expected_regs = f.observed_regs;
        body = body_before;
        source_velocity = local_words;
        f.entry = @intFromPtr(&character_motion_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and helper_calls == i + 1 and f.native_calls == before + 2);
        check(@src(), native_body == @intFromPtr(&body) and native_argument != @intFromPtr(&source_velocity));
        check(@src(), std.mem.eql(u8, &body, &expected_body) and std.mem.eql(u8, body[0xb0..0xc0], std.mem.asBytes(&expected_words)));
        check(@src(), std.mem.eql(u8, body[0..0xb0], body_before[0..0xb0]) and std.mem.eql(u8, body[0xc0..], body_before[0xc0..]));
        check(@src(), std.mem.eql(u8, &actor, &actor_before) and std.mem.eql(u32, &source_velocity, &local_words));
        check(@src(), std.mem.eql(u32, &f.observed_regs, &expected_regs) and f.observed_regs[7] == @intFromPtr(&source_velocity));
        check(@src(), f.observed_regs[0] == 0x77777777 and f.observed_regs[1] == 0x66666666 and f.observed_regs[2] == 0x55555555);
        check(@src(), f.observed_regs[4] == @intFromPtr(&actor) and f.observed_regs[5] == 0x33333333 and f.observed_regs[6] == @intFromPtr(&body));
        check(@src(), f.observed_regs[8] & 0x400 == initial_flags & 0x400);
        sameFx(&expected_fx);
    }
    check(@src(), helper_calls == 5000 and f.native_calls == 10000 and projection_calls == 2500 and fallback_calls == 1250);
}
