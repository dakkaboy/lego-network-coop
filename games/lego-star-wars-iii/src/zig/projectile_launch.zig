const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const control = @import("projectile_control.zig");
pub fn leave(scope: *s.t.Launch) void {
    if (s.launch == scope) s.launch = scope.previous;
}
fn scopeFor(owner: usize, origin: usize, transform: usize) ?*s.t.Launch {
    const scope = s.launch orelse return null;
    return if (scope.owner == owner and scope.origin == origin and scope.transform == transform and control.live(scope.operation)) scope else null;
}
pub export fn projectile_shot_center_source(native: usize, owner: usize, origin: usize, transform: usize) usize {
    const scope = scopeFor(owner, origin, transform) orelse return native;
    const shot = scope.shot;
    scope.center_visited = true;
    if (scope.operation.session.host != 0) {
        if (shot.owner >= 0) {
            const center = s.read([3]f32, native);
            if (@import("validation.zig").finite(center)) {
                shot.launch_center = center;
                shot.has_launch_center = 1;
                s.clonewars_shot_center_debug[0] +%= 1;
            }
        }
        return native;
    }
    if (shot.has_launch_center == 0) return native;
    s.clonewars_shot_center_debug[1] +%= 1;
    const center = s.read([3]f32, native);
    if (!@import("validation.zig").equal(&shot.launch_center, &center)) s.clonewars_shot_center_debug[2] +%= 1;
    return @intFromPtr(&shot.launch_center);
}
pub export fn projectile_shot_motion_source(native: usize, owner: usize, origin: usize, transform: usize) usize {
    const scope = scopeFor(owner, origin, transform) orelse return native;
    const shot = scope.shot;
    if (shot.owner < 0) return native;
    if (scope.operation.session.host == 0) return if (shot.has_launch_motion != 0) @intFromPtr(&shot.launch_motion) else native;
    const motion = s.read([3]f32, native);
    if (@import("validation.zig").finite(motion)) {
        shot.launch_motion = motion;
        shot.has_launch_motion = 1;
    }
    return native;
}
