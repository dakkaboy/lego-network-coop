const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var initial_ebx: u32 = 0;
export var initial_edx: usize = 0x33333333;
export var initial_breakup: u32 = 0;
export var observed_breakup: u32 = 0;
export var breakup_visible_resume: usize = 0;
export var breakup_hidden_resume: usize = 0;
export var death_breakup_resume: usize = 0;
export var fall_visible_resume: usize = 0;
export var fall_hidden_resume: usize = 0;
var authoritative: i32 = -1;
var calls: u32 = 0;
var death_calls: u32 = 0;
var fall_calls: u32 = 0;
pub const probe_registers =
    \\movl _initial_breakup,%eax
    \\movl %eax,0x9c(%esp)
    \\movl $0x11111111,%eax
    \\movl _initial_edx,%edx
    \\movl _initial_ebx,%ebx
;
pub const probe_after_call =
    \\pushfl
    \\pushl %eax
    \\movl 0xa4(%esp),%eax
    \\movl %eax,_observed_breakup
    \\popl %eax
    \\popfl
;
fn clobber() void {
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
}
export fn cadence_apply_fall_visibility(actor: usize, visible: i32) i32 {
    const err = win.GetLastError();
    check(@src(), actor == 0x44444444 and visible == @intFromBool(f.model[0x42] != 0));
    fall_calls += 1;
    clobber();
    win.SetLastError(err);
    return if (authoritative < 0) visible else authoritative;
}
export fn cadence_apply_death_breakup(actor: usize, argument: *u32) void {
    const err = win.GetLastError();
    check(@src(), actor == 0x55555555 and argument.* == initial_breakup);
    if (authoritative >= 0) argument.* = @intCast(authoritative);
    death_calls += 1;
    clobber();
    win.SetLastError(err);
}
export fn cadence_apply_breakup_visibility(actor: usize, hidden: i32) i32 {
    const err = win.GetLastError();
    check(@src(), actor == 0x66666666 and hidden == initial_ebx & 255);
    calls += 1;
    clobber();
    win.SetLastError(err);
    return if (authoritative < 0) hidden else authoritative;
}
extern fn visible_cont() void;
extern fn hidden_cont() void;
extern fn death_cont() void;
extern fn original_death() void;
extern fn original_fall() void;
extern fn original_gate() void;
extern fn breakup_visibility_thunk() void;
extern fn death_breakup_thunk() void;
extern fn fall_visibility_thunk() void;
comptime {
    for (.{ "breakup_visibility_thunk", "death_breakup_thunk", "fall_visibility_thunk" }) |name| asm (@import("cadence_bridge_code.zig").code(name));
    asm (
        \\.text
        \\_visible_cont:
        \\movl $0,_branch
        \\ret
        \\_hidden_cont:
        \\movl $1,_branch
        \\ret
        \\_death_cont:
        \\setnz _branch
        \\ret
        \\_original_death:
        \\cmpl $0,0xa0(%esp)
        \\jmp *_death_breakup_resume
        \\_original_fall:
        \\cmpb $0,0x42(%edx)
        \\jz 1f
        \\jmp *_fall_visible_resume
        \\1: jmp *_fall_hidden_resume
        \\_original_gate:
        \\testb %bl,%bl
        \\jnz 1f
        \\jmp *_breakup_visible_resume
        \\1: jmp *_breakup_hidden_resume
    );
}
pub fn main() void {
    breakup_visible_resume = @intFromPtr(&visible_cont);
    breakup_hidden_resume = @intFromPtr(&hidden_cont);
    death_breakup_resume = @intFromPtr(&death_cont);
    fall_visible_resume = @intFromPtr(&hidden_cont);
    fall_hidden_resume = @intFromPtr(&visible_cont);
    for (0..1000) |_| for (0..2) |hidden| {
        initial_ebx = 0x44444400 | @as(u32, @intCast(hidden));
        f.entry = @intFromPtr(&original_gate);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        for ([_]i32{ -1, 0, 1 }) |forced| {
            authoritative = forced;
            f.entry = @intFromPtr(&breakup_visibility_thunk);
            win.SetLastError(123);
            f.invoke_thunk();
            const expected: u32 = if (forced < 0) @intCast(hidden) else @intCast(forced);
            check(@src(), win.GetLastError() == 123 and f.branch == expected);
            f.expectSame(@src(), &fx, &regs);
        }
    };
    check(@src(), calls == 6000);
    for (0..1000) |_| for (0..2) |local| for ([_]i32{ -1, 0, 1 }) |forced| {
        authoritative = forced;
        const expected: u32 = if (forced < 0) @intCast(local) else @intCast(forced);
        initial_breakup = expected;
        f.entry = @intFromPtr(&original_death);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        initial_breakup = @intCast(local);
        f.entry = @intFromPtr(&death_breakup_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.branch == expected and observed_breakup == expected);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), death_calls == 6000);
    initial_edx = @intFromPtr(&f.model);
    initial_ebx = 0x44444444;
    for (0..1000) |_| for ([_]u8{ 0, 1, 255 }) |value| for ([_]i32{ -1, 0, 1 }) |forced| {
        f.model[0x42] = value;
        authoritative = forced;
        f.entry = @intFromPtr(&original_fall);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.entry = @intFromPtr(&fall_visibility_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        const expected: u32 = if (forced < 0) @intFromBool(value != 0) else @intCast(forced);
        check(@src(), win.GetLastError() == 123 and f.branch == expected and f.model[0x42] == value);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), fall_calls == 9000);
}
