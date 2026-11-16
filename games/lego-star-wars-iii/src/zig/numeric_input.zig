const std = @import("std");
pub const Input = extern struct { cw: u32, mxcsr: u32 };
pub const Scope = extern struct { local: Input, active: u32 };
pub fn valid(value: Input) bool {
    return value.cw & ~@as(u32, 0x1f3f) == 0 and value.cw & 0x300 != 0x100 and value.mxcsr & ~@as(u32, 0xffc0) == 0;
}
pub fn read(fx: *const [512]u8) Input {
    return .{ .cw = std.mem.readInt(u16, fx[0..2], .little) & 0x1f3f, .mxcsr = std.mem.readInt(u32, fx[24..28], .little) & 0xffc0 };
}
pub fn apply(raw: ?*[512]u8, value: Input) bool {
    const fx = raw orelse return false;
    if (!valid(value)) return false;
    const cw = std.mem.readInt(u16, fx[0..2], .little);
    const mxcsr = std.mem.readInt(u32, fx[24..28], .little);
    std.mem.writeInt(u16, fx[0..2], (cw & ~@as(u16, 0x1f3f)) | @as(u16, @intCast(value.cw)), .little);
    std.mem.writeInt(u32, fx[24..28], (mxcsr & ~@as(u32, 0xffc0)) | value.mxcsr, .little);
    return true;
}
pub fn borrow(scope: *Scope, local: Input, fx: *const [512]u8) void {
    const effective = read(fx);
    scope.* = .{ .local = local, .active = @intFromBool(effective.cw != local.cw or effective.mxcsr != local.mxcsr) };
}
pub fn restore(scope: *Scope, fx: *[512]u8) void {
    if (scope.active != 0) {
        _ = apply(fx, scope.local);
        scope.active = 0;
    }
}
