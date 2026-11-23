const s = @import("tick_state.zig");
const equal = @import("validation.zig").equal;
pub export fn native_tick_begin(next: ?*s.p.SyncFrame, authority: c_int, original: ?*const s.Token) c_int {
    const frame = next orelse return 0;
    const token = original orelse return 0;
    if (token.frame != @intFromPtr(frame) or s.world_vars_cohort_valid(token, 2) == 0) return 0;
    if (s.token.epoch != token.epoch) {
        @import("tick_pack_spawn.zig").reset();
        @import("pack_hit_query_observer.zig").reset();
        s.clonewars_native_tick_failure = @splat(0);
        s.clonewars_native_tick_failure_stack = @splat(0);
        s.clonewars_native_pack_seed_context = @splat(0);
        s.clonewars_native_pack_hit_caller = @splat(0);
        s.clonewars_native_tick_correction = @splat(0);
        s.clonewars_native_pack_pose_correction = @splat(0);
        s.clonewars_native_pack_cell_correction = @splat(0);
        s.clonewars_native_pack_hit_correction = @splat(0);
        s.clonewars_native_weapon_command_correction = @splat(0);
    }
    s.frame = frame;
    s.token = token.*;
    s.cursor = 0;
    s.early_rts_wait = null;
    s.host = authority != 0;
    s.failed = false;
    s.active = true;
    if (s.host) {
        frame.tick_gate_count = 0;
        frame.tick_gate_reserved = 0;
    }
    return @intFromBool(s.live(2));
}
pub export fn native_tick_finish() c_int {
    if (!s.live(4)) return 0;
    if (!s.host and s.cursor != s.frame.?.tick_gate_count and !s.failed) s.fail(3, 0, 0, null);
    const result = !s.failed;
    s.active = false;
    return @intFromBool(result);
}
pub export fn native_tick_cancel(original: ?*const s.Token) void {
    if (original) |token| if (equal(&s.token, token)) {
        s.active = false;
        s.frame = null;
    };
}
comptime {
    _ = @import("tick_pack_spawn.zig");
    _ = @import("pack_spawn_bridge.zig");
    _ = @import("tick_clock.zig");
    _ = @import("tick_actor.zig");
    _ = @import("tick_pack_pose.zig");
    _ = @import("tick_pack_control.zig");
    _ = @import("tick_world.zig");
    _ = @import("tick_install.zig");
}
