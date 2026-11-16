const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var force_target_visible_resume: usize = 0;
export var force_target_hidden_resume: usize = 0;
var authoritative: i32 = -1;
var visibility_calls: u32 = 0;
pub const probe_registers =
    \\movl $_model,%eax
    \\movl $_task,%edi
    \\subl $0x44,%esp
    \\movl _test_mode,%ecx
    \\movl %ecx,0x40(%esp)
    \\movl $0x22222222,%ecx
;
pub const probe_after_call = "leal 0x44(%esp),%esp";
pub export fn cadence_force_target_visibility(candidate: usize, caster: usize, mode: u32, visible: i32) i32 {
    const err = win.GetLastError();
    check(@src(), candidate == @intFromPtr(&f.task) and caster == 0x33333333 and mode == f.test_mode and visible == f.model[0x42]);
    visibility_calls += 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
    return if (authoritative < 0) visible else authoritative;
}
extern fn visible_cont() void;
extern fn hidden_cont() void;
extern fn original_visibility() void;
extern fn force_target_visibility_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("force_target_visibility_thunk"));
    asm (
        \\.text
        \\_visible_cont:
        \\movl $1,_branch
        \\ret
        \\_hidden_cont:
        \\movl $0,_branch
        \\ret
        \\_original_visibility:
        \\cmpb $0,0x42(%eax)
        \\je 1f
        \\jmp *_force_target_visible_resume
        \\1: jmp *_force_target_hidden_resume
    );
}
pub fn main() void {
    force_target_visible_resume = @intFromPtr(&visible_cont);
    force_target_hidden_resume = @intFromPtr(&hidden_cont);
    for (0..100) |_| for ([_]u32{ 0, 1, 2, 0x12345678, 0xffffffff }) |mode| for ([_]u8{ 0, 1, 255 }) |visible| for ([_]i32{ -1, 0, 1 }) |forced| {
        f.model[0x42] = visible;
        authoritative = forced;
        f.test_mode = mode;
        f.entry = @intFromPtr(&original_visibility);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.entry = @intFromPtr(&force_target_visibility_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        const expected: u32 = if (forced < 0) @intFromBool(visible != 0) else @intCast(forced);
        check(@src(), win.GetLastError() == 123 and f.branch == expected and f.model[0x42] == visible);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), visibility_calls == 4500);
}
