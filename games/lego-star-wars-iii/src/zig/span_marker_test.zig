const f = @import("native_probe_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var optional_target: usize = 0;
export var main_target: usize = 0;
export var native_span_run_resume: usize = 0;
export var native_span_skip_target: usize = 0;
export var native_span_exit_resume: usize = 0;
var markers: [2]u32 = @splat(0);
var originals: u32 = 0;
fn mark(saved: [*]const u32, fx: usize, kind: usize) void {
    check(@src(), win.GetLastError() == 123 and @intFromPtr(saved) & 3 == 0 and fx & 15 == 0);
    const expected = [_]u32{ 0x77777777, 0x66666666, 0x55555555, 0, 0x44444444, 0x33333333, 0x22222222, 0x11111111 };
    for (0..8) |i| if (i != 3) check(@src(), saved[i] == expected[i]);
    check(@src(), saved[8] & 0xcd5 == 0x646 & 0xcd5 and win.load(u32, @intFromPtr(saved) + 40) == 0x12345678);
    check(@src(), win.load(u16, fx) == 0x37f and win.load(u32, fx + 24) == 0x3f80);
    const flags = asm volatile ("pushfl; popl %[out]"
        : [out] "=r" (-> u32),
    );
    var mxcsr: u32 = 0;
    asm volatile ("stmxcsr (%[out])"
        :
        : [out] "r" (&mxcsr),
        : .{ .memory = true });
    check(@src(), flags & 0x400 == 0 and mxcsr == 0x1f80);
    markers[kind] += 1;
    win.SetLastError(991);
    asm volatile ("fninit; fld1; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7; stc" ::: .{ .xmm0 = true, .xmm7 = true, .cc = true });
}
pub export fn optional_enter(saved: [*]u32, fx: usize) void {
    mark(saved, fx, 0);
}
pub export fn main_enter(saved: [*]u32, fx: usize) void {
    mark(saved, fx, 1);
}
pub export fn native_span_enter(_: [*]u32, _: usize) u32 {
    @panic("unexpected span entry");
}
pub export fn native_span_exit(_: [*]u32, _: usize) void {
    @panic("unexpected span exit");
}
pub export fn originalCalled() void {
    originals += 1;
}
extern fn original_marker() void;
extern fn original_main() void;
extern fn invoke_main_original() void;
extern fn invoke_main_hook() void;
extern fn span_optional_thunk() void;
extern fn span_main_thunk() void;
comptime {
    _ = @import("span_asm.zig");
    asm (
        \\.text
        \\_original_marker:
        \\pushfl
        \\pushal
        \\cld
        \\call _originalCalled
        \\popal
        \\popfl
        \\ret
        \\_original_main:
        \\pushfl
        \\pushal
        \\cld
        \\call _originalCalled
        \\popal
        \\popfl
        \\ret $4
        \\_invoke_main_original:
        \\pushl $0x12345678
        \\call _original_main
        \\ret
        \\_invoke_main_hook:
        \\pushl $0x12345678
        \\call _span_main_thunk
        \\ret
    );
}
pub fn main() void {
    optional_target = @intFromPtr(&original_marker);
    main_target = @intFromPtr(&original_main);
    for (0..1000) |_| for ([_][2]usize{ .{ @intFromPtr(&original_marker), @intFromPtr(&span_optional_thunk) }, .{ @intFromPtr(&invoke_main_original), @intFromPtr(&invoke_main_hook) } }) |pair| {
        f.entry = pair[0];
        win.SetLastError(123);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        const before = originals;
        f.entry = pair[1];
        win.SetLastError(123);
        f.invoke_thunk();
        check(@src(), win.GetLastError() == 123 and originals == before + 1);
        f.expectSame(@src(), &fx, &regs);
    };
    check(@src(), markers[0] == 1000 and markers[1] == 1000 and originals == 4000);
}
