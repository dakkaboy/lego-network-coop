const std = @import("std");
const numeric = @import("numeric_input.zig");
const machine = @import("machine_environment.zig");
const check = @import("native_test_support.zig").check;
fn capture(fx: *[512]u8) void {
    asm volatile ("fxsave (%[value])"
        :
        : [value] "r" (fx),
        : .{ .memory = true });
}
fn unchanged(a: *const [512]u8, b: *const [512]u8) void {
    for (0..512) |i| if (i >= 2 and (i < 24 or i >= 28)) check(@src(), a[i] == b[i]);
}
pub fn main() void {
    check(@src(), @sizeOf(numeric.Scope) == 12);
    var original: [512]u8 align(16) = @splat(0);
    var fx: [512]u8 align(16) = @splat(0);
    var after: [512]u8 align(16) = @splat(0);
    capture(&original);
    defer machine.restoreFx(&original);
    const modes = [_]u16{ 0x7f, 0x27f, 0x37f };
    for (modes) |local| for (modes) |remote| {
        asm volatile ("fninit; fldcw (%[mode]); fld1"
            :
            : [mode] "r" (&local),
            : .{ .memory = true });
        capture(&fx);
        var before = fx;
        const input = numeric.read(&fx);
        var desired = input;
        desired.cw = remote & 0x1f3f;
        desired.mxcsr ^= 0xe040;
        check(@src(), numeric.valid(desired) and numeric.apply(&fx, desired));
        unchanged(&fx, &before);
        var scope: numeric.Scope = undefined;
        numeric.borrow(&scope, input, &fx);
        check(@src(), scope.active != 0);
        machine.restoreFx(&fx);
        var effective: u16 = 0;
        var value: f64 = 0;
        asm volatile ("fnstcw (%[cw]); fstpl (%[value])"
            :
            : [cw] "r" (&effective),
              [value] "r" (&value),
            : .{ .memory = true });
        check(@src(), effective & 0x1f3f == desired.cw and value == 1);
        capture(&after);
        before = after;
        numeric.restore(&scope, &after);
        check(@src(), scope.active == 0 and numeric.read(&after).cw == input.cw and numeric.read(&after).mxcsr == input.mxcsr);
        unchanged(&after, &before);
        before = after;
        numeric.restore(&scope, &after);
        check(@src(), std.mem.eql(u8, &before, &after));
    };
    machine.restoreFx(&original);
    fx = original;
    const before = fx;
    for ([_]numeric.Input{ .{ .cw = 0x100, .mxcsr = 0 }, .{ .cw = 0x4000, .mxcsr = 0 }, .{ .cw = 0, .mxcsr = 0x10000 } }) |invalid| check(@src(), !numeric.apply(&fx, invalid) and std.mem.eql(u8, &fx, &before));
    check(@src(), !numeric.apply(null, .{ .cw = 0x37f, .mxcsr = 0 }));
    var local = numeric.read(&fx);
    var scope: numeric.Scope = undefined;
    numeric.borrow(&scope, local, &fx);
    check(@src(), scope.active == 0 and numeric.apply(&fx, .{ .cw = 831, .mxcsr = local.mxcsr }));
    numeric.restore(&scope, &fx);
    check(@src(), numeric.read(&fx).cw == 831);
    local.cw = 63;
    numeric.borrow(&scope, local, &fx);
    check(@src(), scope.active != 0);
    numeric.restore(&scope, &fx);
    check(@src(), numeric.read(&fx).cw == 63);
}
