const win = @import("win32.zig");
pub const Input = extern struct { cw: u32, mxcsr: u32 };
pub const Scope = extern struct { local: Input, active: u32 };
pub fn valid(value: Input) bool {
    return value.cw & ~@as(u32, 0x1f3f) == 0 and value.cw & 0x300 != 0x100 and value.mxcsr & ~@as(u32, 0xffc0) == 0;
}
pub fn read(fx: usize) Input {
    return .{ .cw = win.load(u16, fx) & 0x1f3f, .mxcsr = win.load(u32, fx + 24) & 0xffc0 };
}
pub fn apply(fx: usize, value: Input) bool {
    if (fx == 0 or !valid(value)) return false;
    win.store(u16, fx, (win.load(u16, fx) & ~@as(u16, 0x1f3f)) | @as(u16, @intCast(value.cw)));
    win.store(u32, fx + 24, (win.load(u32, fx + 24) & ~@as(u32, 0xffc0)) | value.mxcsr);
    return true;
}
pub fn borrow(scope: *Scope, local: Input, fx: usize) void {
    const effective = read(fx);
    scope.local = local;
    scope.active = @intFromBool(effective.cw != local.cw or effective.mxcsr != local.mxcsr);
}
pub fn restore(scope: *Scope, fx: usize) void {
    if (scope.active != 0) {
        _ = apply(fx, scope.local);
        scope.active = 0;
    }
}
