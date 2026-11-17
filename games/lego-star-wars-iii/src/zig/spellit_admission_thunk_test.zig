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
export var stage: u32 = 0;
export var manager_result: u32 = 0;
export var manager_calls: u32 = 0;
export var manager_table: [0x6c]u8 = @splat(0);
export var spellit_manager_force_resume: usize = 0;
export var spellit_manager_special_resume: usize = 0;
export var rider_fire_visible_resume: usize = 0;
export var rider_fire_hidden_resume: usize = 0;
export var rider_frame: [4]u32 = .{ 0, 0x46332b, 0x12345678, 0x23456789 };
var calls: u32 = 0;
pub const probe_registers =
    \\movl _admission_local,%eax
    \\movl _admission_kind,%ebp
    \\movl $_admission_manager,%esi
    \\movl $0x44444444,%edi
    \\cmpl $4,_stage
    \\jb 1f
    \\movl $_admission_manager,%ecx
    \\movl $_manager_table,%edx
    \\movl $_manager_native,%eax
    \\cmpl $6,_stage
    \\jne 1f
    \\movl $_rider_frame,%ebp
    \\movl $0x44444444,%esi
    \\movl $_admission_manager,%eax
    \\1:
;
export fn cadence_spellit_admission(actor: usize, kind: u32, part: u32, local: u32) u32 {
    check(@src(), actor == 0x44444444 and kind == admission_kind and part == stage and local == admission_local);
    calls += 1;
    win.SetLastError(999);
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7; stc" ::: .{ .memory = true, .cc = true, .xmm0 = true, .xmm7 = true });
    return admission_expected;
}
export fn cadence_rider_fire_input(actor: usize, mount: usize, timer: usize, caller: usize) u32 {
    check(@src(), actor == 0x44444444 and mount == 0x12345678 and timer == 0x23456789 and caller == 0x46332b);
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
extern fn spellit_manager_force_thunk() void;
extern fn spellit_manager_special_thunk() void;
extern fn manager_native() void;
extern fn manager_return() void;
extern fn original_force() void;
extern fn original_special() void;
extern fn rider_fire_visibility_thunk() void;
extern fn original_rider() void;
comptime {
    asm (@import("spellit_admission_bridge.zig").code(0));
    asm (@import("spellit_admission_bridge.zig").code(1));
    asm (@import("spellit_admission_bridge.zig").managerCode(false));
    asm (@import("spellit_admission_bridge.zig").managerCode(true));
    asm (@import("rider_fire_bridge.zig").code);
    asm (
        \\.text
        \\_original_rider:
        \\cmpl $0,_admission_expected
        \\jz 1f
        \\jmp *_rider_fire_visible_resume
        \\1: jmp *_rider_fire_hidden_resume
        \\_manager_native:
        \\pushfl
        \\incl _manager_calls
        \\popfl
        \\movl _manager_result,%eax
        \\ret $4
        \\_manager_return: ret
        \\_original_force:
        \\movl 0x64(%edx),%eax
        \\pushl %edi
        \\call *%eax
        \\movb _admission_expected,%al
        \\jmp *_spellit_manager_force_resume
        \\_original_special:
        \\pushl %edi
        \\setnz %bl
        \\call *%eax
        \\movb _admission_expected,%al
        \\jmp *_spellit_manager_special_resume
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
    spellit_manager_force_resume = @intFromPtr(&manager_return);
    spellit_manager_special_resume = @intFromPtr(&manager_return);
    win.store(usize, @intFromPtr(&manager_table) + 0x64, @intFromPtr(&manager_native));
    admission_kind = 0;
    for (0..2000) |i| for (0..2) |part| {
        stage = @intCast(4 + part);
        manager_result = if (i & 1 == 0) 0xdeadbe00 else 0xcafebeff;
        admission_local = @intFromBool(manager_result & 255 != 0);
        admission_expected = @intFromBool(i % 3 == 0);
        f.entry = if (part == 0) @intFromPtr(&original_force) else @intFromPtr(&original_special);
        win.SetLastError(123);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const before = manager_calls;
        f.entry = if (part == 0) @intFromPtr(&spellit_manager_force_thunk) else @intFromPtr(&spellit_manager_special_thunk);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and manager_calls == before + 1);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), calls == 16000 and manager_calls == 8000);
    stage = 6;
    rider_fire_visible_resume = @intFromPtr(&state_continue);
    rider_fire_hidden_resume = @intFromPtr(&skip);
    for (0..2000) |i| {
        admission_expected = @intFromBool(i & 1 != 0);
        f.entry = @intFromPtr(&original_rider);
        win.SetLastError(123);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const expected = f.branch;
        f.entry = @intFromPtr(&rider_fire_visibility_thunk);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.branch == expected);
        f.expectSame(@src(), &fx, &regs);
    }
    check(@src(), calls == 18000);
}
