const std = @import("std");
const s = @import("projectile_state.zig");
const hooks = @import("hook_transaction.zig");
pub export var shot_center_resume: usize = 0x85ae73;
pub export var shot_motion_original: usize = 0x574af0;
extern fn projectile_create_hook() void;
extern fn projectile_create_secondary_hook() void;
extern fn projectile_remove_hook() void;
extern fn projectile_pool_release_hook() void;
extern fn projectile_fire_hook() void;
extern fn projectile_shot_center_hook() void;
extern fn projectile_shot_motion_hook() void;
extern fn combat_observer_removal_ready() void;
fn expected(site: usize, target: usize) [5]u8 {
    const relative: u32 = @truncate(target -% site -% 5);
    return .{ 0xe8, @truncate(relative), @truncate(relative >> 8), @truncate(relative >> 16), @truncate(relative >> 24) };
}
pub export fn projectiles_install() c_int {
    @atomicStore(i32, &s.hooks_installed, 0, .seq_cst);
    const sites = [_]usize{ 0x44e4c0, 0x81f5bb, 0x8633e0, 0x85b33f, 0x85ba1f, 0x85be70, 0x8643a1, 0x8464cf, 0x864424, 0x45a98f, 0x45aa31, 0x45aab5, 0x884b4c, 0x85aa90 };
    const native = [_]usize{ 0x869060, 0x8630f0, 0x8630f0, 0x846460, 0x846460, 0x846460, 0x846460, 0x69c9b0, 0x69c9b0, 0x879710, 0x879710, 0x879710, 0x879710, shot_motion_original };
    const targets = [_]usize{ @intFromPtr(&projectile_create_hook), @intFromPtr(&projectile_create_secondary_hook), @intFromPtr(&projectile_create_secondary_hook), @intFromPtr(&projectile_remove_hook), @intFromPtr(&projectile_remove_hook), @intFromPtr(&projectile_remove_hook), @intFromPtr(&projectile_remove_hook), @intFromPtr(&projectile_pool_release_hook), @intFromPtr(&projectile_pool_release_hook), @intFromPtr(&projectile_fire_hook), @intFromPtr(&projectile_fire_hook), @intFromPtr(&projectile_fire_hook), @intFromPtr(&projectile_fire_hook), @intFromPtr(&projectile_shot_motion_hook) };
    var prefixes: [14][5]u8 = undefined;
    var patches: [15]hooks.Patch = undefined;
    for (sites, native, targets, 0..) |site, target, replacement, i| {
        prefixes[i] = expected(site, target);
        patches[i] = .{ .address = site, .expected = &prefixes[i], .target = replacement, .opcode = 0xe8 };
    }
    patches[14] = .{ .address = 0x85ae6a, .expected = "\x8b\x7d\x0c\x81\xc7\x28\x0f\x00\x00", .target = @intFromPtr(&projectile_shot_center_hook) };
    if (!hooks.apply(&patches)) return 0;
    combat_observer_removal_ready();
    @atomicStore(i32, &s.hooks_installed, 1, .seq_cst);
    if (@import("projectile_constructor.zig").enabled) {
        if (@import("constructor_observer.zig").constructor_observer_install() == 0 or @import("constructor_query.zig").constructor_query_install() == 0) return 0;
    }
    return 1;
}
comptime {
    _ = @import("projectile_control.zig");
    if (@import("projectile_constructor.zig").enabled) _ = @import("constructor_query.zig");
    _ = @import("projectile_tracking.zig");
    _ = @import("projectile_fire.zig");
    _ = @import("projectile_launch.zig");
    _ = @import("projectile_creation.zig");
    _ = @import("projectile_removal.zig");
    _ = @import("projectile_frame.zig");
    _ = @import("projectile_launch_bridges.zig");
}
