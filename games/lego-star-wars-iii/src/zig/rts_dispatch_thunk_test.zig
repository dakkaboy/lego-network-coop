const std = @import("std");
const win = @import("win32.zig");
const f = @import("native_probe_fixture.zig");
const check = @import("native_test_support.zig").check;
export var rts_descriptor: [16]u8 = @splat(0);
export var rts_event: u32 = 27;
export var rts_dispatch_blocked: usize = 0;
export var rts_dispatch_continue: usize = 0;
var calls: u32 = 0;
pub const probe_registers =
    \\movl $_rts_descriptor,%edi
    \\movl $0x66666666,%esi
    \\movl $_rts_event,12(%esp)
;
export fn native_rts_dispatch_observe(battlefield: usize, descriptor: usize, event: usize) void {
    check(@src(), battlefield == 0x66666666 and descriptor == @intFromPtr(&rts_descriptor) and event == @intFromPtr(&rts_event));
    calls += 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
}
extern fn blocked() void;
extern fn proceed() void;
extern fn original() void;
extern fn native_rts_dispatch_observer() void;
comptime {
    asm (@import("tick_bridge_code.zig").code("native_rts_dispatch_observer"));
    asm (
        \\.text
        \\_blocked:
        \\movl $1,_branch
        \\ret
        \\_proceed:
        \\movl $0,_branch
        \\ret
        \\_original:
        \\cmpl $0,0xc(%edi)
        \\je 1f
        \\jmp *_rts_dispatch_blocked
        \\1: jmp *_rts_dispatch_continue
    );
}
pub fn main() void {
    rts_dispatch_blocked = @intFromPtr(&blocked);
    rts_dispatch_continue = @intFromPtr(&proceed);
    for (0..6000) |i| {
        const value: u32 = @truncate(i *% 0x9e3779b9);
        win.store(u32, @intFromPtr(&rts_descriptor) + 12, if (i % 3 == 0) 0 else value);
        rts_event = if (i % 2 == 0) 20 else 27;
        f.fp_control = if (i % 2 == 0) 0x37f else 0x7f;
        f.entry = @intFromPtr(&original);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const branch = f.branch;
        win.SetLastError(123);
        f.entry = @intFromPtr(&native_rts_dispatch_observer);
        f.invoke_thunk();
        check(@src(), f.branch == branch and win.GetLastError() == 123);
        f.expectSame(@src(), &fx, &regs);
    }
    check(@src(), calls == 6000);
}
