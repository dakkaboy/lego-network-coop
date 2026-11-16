const std = @import("std");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const tracking = @import("projectile_tracking.zig");
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
extern fn projectile_create_hook() void;
extern fn projectile_create_secondary_hook() void;
extern fn projectile_remove_hook() void;
extern fn projectile_pool_release_hook() void;
extern fn projectile_fire_hook() void;
extern fn projectile_shot_center_source() void;
extern fn projectile_shot_motion_source() void;
pub export fn projectile_fixture_setup(adapter: *t.Adapter, provider: t.SessionProvider, reject: t.RejectProvider, count: u32, objects: usize, resources: usize) void {
    s.adapter = null;
    s.last_session = 0;
    s.last_session_epoch = 0;
    s.revoked_session = 0;
    s.revoked_session_epoch = 0;
    s.frame_associated = false;
    @import("projectile_frame.zig").reset(true);
    s.retire_draining = false;
    s.clonewars_projectile_retire_debug = @splat(0);
    s.clonewars_projectile_pool_release_debug = @splat(0);
    s.clonewars_projectile_debug = @splat(0);
    s.clonewars_fire_debug = @splat(0);
    s.clonewars_shot_center_debug = @splat(0);
    s.clonewars_projectile_failure = std.mem.zeroes(t.Failure);
    s.adapter = adapter;
    s.session_provider = provider;
    s.reject_provider = reject;
    s.control_user = 0;
    s.main_thread = s.win.GetCurrentThreadId();
    s.level = 6;
    s.next_id = count;
    s.next_instance_serial = 100 + count;
    for (0..count) |i| {
        s.tracked[i].birth.id = @intCast(i + 1);
        s.tracked[i].object = objects + i * 0x210;
        s.tracked[i].resource = resources + i * 0x80;
        s.instance_serial[i] = @intCast(100 + i);
    }
}
pub export fn projectile_fixture_target(kind: u32) usize {
    return switch (kind) {
        0 => @intFromPtr(&projectile_create_hook),
        1 => @intFromPtr(&projectile_create_secondary_hook),
        2 => @intFromPtr(&projectile_remove_hook),
        3 => @intFromPtr(&projectile_pool_release_hook),
        4 => @intFromPtr(&projectile_fire_hook),
        5 => @intFromPtr(&projectile_shot_center_source),
        6 => @intFromPtr(&projectile_shot_motion_source),
        else => 0,
    };
}
pub export fn projectile_fixture_tracked() [*]t.Tracked {
    return &s.tracked;
}
pub export fn projectile_fixture_instance() [*]u32 {
    return &s.instance_serial;
}
pub export fn projectile_fixture_find(id: u32) ?*t.Tracked {
    return tracking.find(id);
}
pub export fn projectile_fixture_remember(id: u32, object: usize) ?*t.Tracked {
    const op = control.capture();
    var birth = std.mem.zeroes(@import("protocol.zig").SyncShot);
    birth.id = id;
    birth.owner = -1;
    return tracking.remember(&op, &birth, object);
}
pub export fn projectile_fixture_pool(pointer: t.PoolRelease) void {
    @import("projectile_removal.zig").native_pool_release = pointer;
}
pub export fn projectile_fixture_reset(normalize: c_int) void {
    @import("projectile_frame.zig").reset(normalize != 0);
}
pub const Metadata = extern struct { reset_generation: u64, lifecycle_serial: u32, next_instance_serial: u32, next_id: u32, pending_count: u32, retire_pending_count: u32, retire_batch_count: u32, level: i32, failed: u32, dispatch_revision: u64, dispatch_completed_revision: u64, frame_bound: u32, frame_associated: u32, binding_cancelled: u32, dispatch_completed: u32, network_active: u32, authority: u32 };
pub export fn projectile_fixture_metadata(out: *Metadata) void {
    out.* = .{ .reset_generation = s.reset_generation, .lifecycle_serial = s.lifecycle_serial, .next_instance_serial = s.next_instance_serial, .next_id = s.next_id, .pending_count = @intCast(s.pending_count), .retire_pending_count = @intCast(s.retire_pending_count), .retire_batch_count = @intCast(s.retire_batch_count), .level = s.level, .failed = @intFromBool(s.failed), .dispatch_revision = s.dispatch_revision, .dispatch_completed_revision = s.dispatch_completed_revision, .frame_bound = @intFromBool(s.frame_bound), .frame_associated = @intFromBool(s.frame_associated), .binding_cancelled = @intFromBool(s.binding_cancelled), .dispatch_completed = @intFromBool(s.dispatch_completed), .network_active = @intFromBool(s.network_active), .authority = @intFromBool(s.authority) };
}
comptime {
    _ = @import("projectile_input.zig");
    _ = @import("lexical_seh.zig");
}
