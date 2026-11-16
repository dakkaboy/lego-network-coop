const std = @import("std");
const win = @import("win32.zig");
pub const Binding = @import("rigid_types.zig").Binding;
pub const Lookup = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) usize;
pub const Transform = *const fn (usize, [*]const f32) callconv(.{ .x86_thiscall = .{} }) void;
pub const Source = struct {
    manager: usize,
    lookup: Lookup,
    transform: Transform,
    pub fn resolve(self: Source, actor: usize, out: *Binding) bool {
        out.* = std.mem.zeroes(Binding);
        if (!win.accessible(actor, 0x1440, false) or !win.accessible(self.manager, 0x160, false)) return false;
        const count = win.load(u32, self.manager + 0x15c);
        if (count > 4096 or !win.accessible(self.manager + 0x160, count * 4, false)) return false;
        const component = self.lookup(self.manager, actor);
        if (!win.accessible(component, 0x2a0, false) or win.load(usize, component + 0x29c) != actor) return false;
        const driver = win.load(usize, component + 0x294);
        if (!win.accessible(driver, 0x264, false)) return false;
        const body = win.load(usize, driver + 0x260);
        if (!win.accessible(body, 0xa0, false)) return false;
        const dynamics = win.load(usize, body + 0x98);
        if (dynamics != 0 and !win.accessible(dynamics, 0x50, false)) return false;
        out.* = .{ .component = component, .driver = driver, .body = body, .dynamics = dynamics };
        return true;
    }
    pub fn matches(self: Source, actor: usize, binding: *const Binding) bool {
        var now: Binding = undefined;
        return self.resolve(actor, &now) and std.meta.eql(now, binding.*);
    }
};
fn current() Source {
    return .{ .manager = win.load(usize, 0xfbdb3c), .lookup = @ptrFromInt(0x9736c0), .transform = @ptrFromInt(0xa29570) };
}
pub export fn native_actor_rigid_body(actor: usize, out: *Binding) c_int {
    return @intFromBool(current().resolve(actor, out));
}
pub export fn native_actor_rigid_body_same(actor: usize, binding: *const Binding) c_int {
    return @intFromBool(current().matches(actor, binding));
}
pub export fn native_rigid_body_transform(body: usize, matrix: [*]const f32) void {
    current().transform(body, matrix);
}
