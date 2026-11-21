const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const Token = @import("cohort_types.zig").Token;
extern fn cadence_journal_begin(*s.Journal, *p.SyncFrame, c_int) void;
pub export fn cadence_bind_cohort(original: ?*const Token) c_int {
    return @intFromBool(s.binding.bind(original));
}
pub export fn cadence_frame_lease_get(out: ?*s.Lease) c_int {
    return @intFromBool(s.binding.get(out));
}
pub export fn cadence_frame_cancelled(op: ?*const s.Lease) c_int {
    return @intFromBool(s.binding.cancelled(op));
}
pub export fn cadence_abort_frame(op: ?*const s.Lease) c_int {
    if (!s.binding.detach(op)) return 0;
    s.active = false;
    s.cancelled = true;
    s.spellit_scope_count = 0;
    s.journal = std.mem.zeroes(s.Journal);
    return 1;
}
pub export fn cadence_ready() c_int {
    return @intFromBool(s.clonewars_cadence_installed == 1);
}
pub export fn cadence_cancel() void {
    if (s.binding.bound or s.binding.lease.cohort.thread == 0 or s.binding.lease.cohort.thread != s.win.GetCurrentThreadId()) return;
    s.active = false;
    s.cancelled = true;
    s.spellit_scope_count = 0;
    s.journal = std.mem.zeroes(s.Journal);
}
pub export fn cadence_begin(frame: *p.SyncFrame, host: c_int) c_int {
    if (!s.binding.begin(@intFromPtr(frame))) return 0;
    const op = s.binding.lease;
    if (!s.binding.live(&op)) return 0;
    s.cancelled = false;
    if (s.last_epoch != op.cohort.epoch) {
        inline for (.{ &s.clonewars_cadence_failure, &s.clonewars_breakup_visibility_correction, &s.clonewars_death_breakup_correction, &s.clonewars_fall_visibility_correction, &s.clonewars_aim_task_correction, &s.clonewars_rts_competitor_correction, &s.clonewars_force_target_correction, &s.clonewars_force_geometry_correction, &s.clonewars_spellit_query_correction, &s.clonewars_character_motion_correction, &s.clonewars_spellit_node_correction, &s.clonewars_spellit_node_failure, &s.clonewars_aim_base_correction, &s.clonewars_script_shoot_correction, &s.clonewars_script_shoot_failure, &s.clonewars_actor_gate_failure }) |buffer| buffer.* = @splat(0);
        s.last_epoch = op.cohort.epoch;
        @import("zillo_support_origin.zig").reset();
    }
    cadence_journal_begin(&s.journal, frame, host);
    s.fire_task_cursor = 0;
    s.aim_task_scope = std.mem.zeroes(s.AimTaskScope);
    s.spellit_scope_count = 0;
    if (host != 0) frame.fire_task_gate_count = 0;
    s.active = true;
    return @intFromBool(s.live(&op));
}
pub export fn cadence_finish() c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active or s.cancelled) return 0;
    s.active = false;
    s.clonewars_cadence_debug[15] +%= 1;
    if (s.journal.finish() == 0) {
        s.clonewars_cadence_debug[16] +%= 1;
        if (s.journal.failed == 0) {
            const entry = s.journal.peek();
            s.journal.failed = 3;
            s.failed(&op, 0, entry, 3);
        }
        return 0;
    }
    if (s.journal.host == 0 and s.fire_task_cursor != s.journal.frame.?.fire_task_gate_count) {
        s.clonewars_fire_task_gate_debug[3] +%= 1;
        s.journal.failed = 6;
        s.failed(&op, 0, null, 6);
        return 0;
    }
    return 1;
}
pub export fn cadence_install() c_int {
    return @import("cadence_install.zig").install();
}
comptime {
    _ = @import("cadence_basic.zig");
    _ = @import("cadence_tasks.zig");
    _ = @import("cadence_force.zig");
    _ = @import("cadence_script.zig");
    _ = @import("cadence_spellit.zig");
    _ = @import("cadence_spellit_node.zig");
    _ = @import("cadence_motion.zig");
    _ = @import("cadence_perception.zig");
    _ = @import("spellit_admission.zig");
    _ = @import("hazard_death.zig");
}
