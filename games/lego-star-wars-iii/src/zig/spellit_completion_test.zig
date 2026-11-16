const f = @import("register_test_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const fixture_receiver_in_eax = false;
export var spellit_timeout_flags_resume: usize = 0;
export var spellit_finish_flags_resume: usize = 0;
export var spellit_target_resume: usize = 0;
var canonical: u32 = 0;
var site_seen: u32 = 0;
pub export fn native_spellit_receiver_flags(object: usize, site: u32) u32 {
    check(@src(), object == @intFromPtr(&f.receiver));
    site_seen = site;
    f.clobber();
    return canonical;
}
pub export fn native_spellit_pose_input(_: usize) void {}
extern fn native_spellit_timeout_flags_bridge() void;
extern fn native_spellit_finish_flags_bridge() void;
comptime {
    _ = @import("spellit_bridges.zig");
}
pub fn main() void {
    spellit_timeout_flags_resume = @intFromPtr(&f.continuation);
    spellit_finish_flags_resume = @intFromPtr(&f.continuation);
    for (0..2) |branch| for (0..256) |local| for ([_]u32{ 0, 4 }) |value| {
        f.receiver[0x183] = @intCast(local);
        canonical = value;
        f.entry = if (branch != 0) @intFromPtr(&native_spellit_finish_flags_bridge) else @intFromPtr(&native_spellit_timeout_flags_bridge);
        win.SetLastError(123);
        f.invoke();
        check(@src(), win.GetLastError() == 123 and f.receiver[0x183] == local);
        check(@src(), site_seen == (if (branch != 0) @as(u32, 0x812df0) else 0x812d7a));
        check(@src(), f.regs[0] == 0x77777777 and f.regs[1] == 0x66666666 and f.regs[2] == 0x55555555 and f.regs[4] == 0x44444444);
        check(@src(), f.regs[5] == 0x33333333 and f.regs[6] == @intFromPtr(&f.receiver) and f.regs[7] == 0x11111111);
        check(@src(), f.regs[8] & 0x8c5 == (if (value != 0) @as(u32, 0) else 0x44) and f.regs[8] & 0x400 != 0);
        f.preservedFx();
    };
}
