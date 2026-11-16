const std = @import("std");
const win = @import("win32.zig");
const f = @import("native_probe_fixture.zig");
const check = @import("native_test_support.zig").check;
export var admission_manager: [0x410]u8 = @splat(0);
export var admission_local: u32 = 0;
export var admission_expected: u32 = 0;
export var admission_kind: u32 = 0x24;
export var spellit_admission_state_continue: usize = 0;
export var spellit_admission_state_skip: usize = 0;
export var spellit_admission_hint_continue: usize = 0;
export var spellit_admission_hint_skip: usize = 0;
var stage: u32 = 0;
var calls: u32 = 0;
pub const probe_registers =
    \\movl _admission_local,%eax
    \\movl _admission_kind,%ebp
    \\movl $_admission_manager,%esi
    \\movl $0x44444444,%edi
;
export fn cadence_spellit_admission(actor: usize, kind: u32, part: u32, local: u32) u32 {
    check(@src(), actor == 0x44444444 and kind == admission_kind and part == stage and local == admission_local);
    calls += 1;
    win.SetLastError(999);
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7; stc" ::: .{ .memory = true, .cc = true, .xmm0 = true, .xmm7 = true });
    return admission_expected;
}
extern fn state_continue() void;
extern fn skip() void;
extern fn hint_continue() void;
extern fn original_state() void;
extern fn original_hint() void;
extern fn spellit_admission_state_thunk() void;
extern fn spellit_admission_hint_thunk() void;
comptime {
    asm (@import("spellit_admission_bridge.zig").code(0));
    asm (@import("spellit_admission_bridge.zig").code(1));
    asm (
        \\.text
        \\_state_continue:
        \\movl $0,_branch
        \\ret
        \\_hint_continue:
        \\movl $1,_branch
        \\ret
        \\_skip:
        \\movl $2,_branch
        \\ret
        \\_original_state:
        \\movl _admission_expected,%eax
        \\testl %eax,%eax
        \\movl _admission_local,%eax
        \\jnz 1f
        \\jmp *_spellit_admission_state_continue
        \\1: jmp *_spellit_admission_state_skip
        \\_original_hint:
        \\movl _admission_expected,%eax
        \\testl %eax,%eax
        \\movl _admission_local,%eax
        \\jz 1f
        \\movl 0x400(%esi),%eax
        \\jmp *_spellit_admission_hint_continue
        \\1: jmp *_spellit_admission_hint_skip
    );
}
pub fn main() void {
    spellit_admission_state_continue = @intFromPtr(&state_continue);
    spellit_admission_state_skip = @intFromPtr(&skip);
    spellit_admission_hint_continue = @intFromPtr(&hint_continue);
    spellit_admission_hint_skip = @intFromPtr(&skip);
    win.store(u32, @intFromPtr(&admission_manager) + 0x400, 0xcafebabe);
    f.fp_control = 0x7f;
    for (0..6000) |i| for (0..2) |part| {
        stage = @intCast(part);
        admission_kind = 0x24 + @as(u32, @intCast(i & 1));
        admission_local = if (i & 1 == 0) 0 else if (part == 0) 0x44445328 else 1;
        const canonical: u32 = @intFromBool(i % 3 == 0);
        admission_expected = if ((admission_local != 0) == (canonical != 0)) admission_local else canonical;
        f.entry = if (part == 0) @intFromPtr(&original_state) else @intFromPtr(&original_hint);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const expected = f.branch;
        f.entry = if (part == 0) @intFromPtr(&spellit_admission_state_thunk) else @intFromPtr(&spellit_admission_hint_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.branch == expected);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), calls == 12000);
}
