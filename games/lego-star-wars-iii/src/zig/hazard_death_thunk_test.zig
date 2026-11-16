const win = @import("win32.zig");
const f = @import("native_probe_fixture.zig");
const check = @import("native_test_support.zig").check;
export var hazard_status: u32 = 0;
export var hazard_mask: u32 = 0;
export var hazard_death_continue: usize = 0;
export var hazard_death_skip: usize = 0;
var calls: u32 = 0;
pub const probe_registers =
    \\movl _hazard_status,%eax
    \\movl $0x44444444,%esi
;
export fn cadence_hazard_death(actor: usize, status: u32, controller: usize, frame: usize) u32 {
    check(@src(), actor == 0x44444444 and status == hazard_status and controller == 0x44444444 and frame == 0x55555555);
    calls += 1;
    win.SetLastError(999);
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7; stc" ::: .{ .memory = true, .cc = true, .xmm0 = true, .xmm7 = true });
    return hazard_mask;
}
extern fn proceed() void;
extern fn skip() void;
extern fn original() void;
extern fn hazard_death_thunk() void;
comptime {
    asm (@import("hazard_death_bridge.zig").code);
    asm (
        \\.text
        \\_proceed:
        \\movl $1,_branch
        \\ret
        \\_skip:
        \\movl $2,_branch
        \\ret
        \\_original:
        \\pushfl
        \\pushl %eax
        \\movl _hazard_mask,%eax
        \\shll $8,%eax
        \\movl %eax,_hazard_comparison
        \\popl %eax
        \\popfl
        \\testb $0x41,_hazard_comparison+1
        \\jnz _skip
        \\jmp _proceed
        \\.data
        \\_hazard_comparison: .long 0
    );
}
pub fn main() void {
    hazard_death_continue = @intFromPtr(&proceed);
    hazard_death_skip = @intFromPtr(&skip);
    f.fp_control = 0x7f;
    for (0..4096) |i| for (0..4) |mask| {
        hazard_status = @as(u32, @intCast(i)) *% 0x13579;
        hazard_mask = switch (mask) { 0 => 0, 1 => 1, 2 => 0x40, else => 0x41 };
        f.entry = @intFromPtr(&original);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const expected = f.branch;
        f.entry = @intFromPtr(&hazard_death_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.branch == expected);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), calls == 16384);
}
