const std = @import("std");
const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
const p = @import("protocol.zig");
export var aim_task_input_resume: usize = 0;
export var aim_task_visible_resume: usize = 0;
export var aim_task_hidden_resume: usize = 0;
var authoritative: i32 = -1;
var input_calls: u32 = 0;
var visibility_calls: u32 = 0;
pub const probe_registers =
    \\movl $_model,%eax
    \\movl $_task,%edi
;
fn clobber() void {
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
}
export fn cadence_prepare_aim_task(actor: usize, task: usize) void {
    const err = win.GetLastError();
    check(@src(), actor == 0x66666666 and task == @intFromPtr(&f.task));
    input_calls += 1;
    clobber();
    win.SetLastError(err);
}
export fn cadence_aim_task_visibility(actor: usize, task: usize, visible: i32) i32 {
    const err = win.GetLastError();
    check(@src(), actor == 0x66666666 and task == @intFromPtr(&f.task) and visible == f.model[0x42]);
    visibility_calls += 1;
    clobber();
    win.SetLastError(err);
    return if (authoritative < 0) visible else authoritative;
}
extern fn input_cont() void;
extern fn visible_cont() void;
extern fn hidden_cont() void;
extern fn original_input() void;
extern fn original_visibility() void;
extern fn aim_task_input_thunk() void;
extern fn aim_task_visibility_thunk() void;
comptime {
    asm (@import("cadence_bridge_code.zig").code("aim_task_input_thunk"));
    asm (@import("cadence_bridge_code.zig").code("aim_task_visibility_thunk"));
    asm (
        \\.text
        \\_input_cont: setnz _branch
        \\ret
        \\_visible_cont: movl $1,_branch
        \\ret
        \\_hidden_cont: movl $0,_branch
        \\ret
        \\_original_input:
        \\movl 0x10(%edi),%ecx
        \\testl %ecx,%ecx
        \\jmp *_aim_task_input_resume
        \\_original_visibility:
        \\cmpb $0,0x42(%eax)
        \\je 1f
        \\jmp *_aim_task_visible_resume
        \\1: jmp *_aim_task_hidden_resume
    );
}
pub fn main() void {
    aim_task_input_resume = @intFromPtr(&input_cont);
    aim_task_visible_resume = @intFromPtr(&visible_cont);
    aim_task_hidden_resume = @intFromPtr(&hidden_cont);
    for (0..1000) |_| for ([_]u32{ 0, 0x12345678 }) |target| {
        std.mem.writeInt(u32, f.task[0x10..0x14], target, .little);
        f.entry = @intFromPtr(&original_input);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.entry = @intFromPtr(&aim_task_input_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and f.branch == @intFromBool(target != 0));
        f.expectSame(@src(), &fx, &regs);
    };
    for (0..1000) |_| for ([_]u8{ 0, 1, 255 }) |visible| for ([_]i32{ -1, 0, 1 }) |forced| {
        f.model[0x42] = visible;
        authoritative = forced;
        f.entry = @intFromPtr(&original_visibility);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.entry = @intFromPtr(&aim_task_visibility_thunk);
        win.SetLastError(123);
        f.invoke_thunk();
        const expected: u32 = if (forced < 0) @intFromBool(visible != 0) else @intCast(forced);
        check(@src(), win.GetLastError() == 123 and f.branch == expected and f.model[0x42] == visible);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), input_calls == 2000 and visibility_calls == 9000);
    const a: p.SyncAimTaskState = .{ .target_slot = 1, .target_generation = 8, .rng_engine = 123, .clock = 200, .remaining = -0.1, .minimum = 0.5, .maximum = 1.5, .task_class = 0x721234, .target_character = 0 };
    var b = a;
    b.rng_engine = 456;
    b.remaining = 0.25;
    const equal = @import("cadence_context.zig").aim;
    check(@src(), equal(&a, &b));
    inline for (.{ "target_slot", "target_generation", "clock", "task_class", "minimum", "maximum" }) |field| {
        b = a;
        @field(b, field) += if (@TypeOf(@field(b, field)) == f32) 0.1 else 1;
        check(@src(), !equal(&a, &b));
    }
}
