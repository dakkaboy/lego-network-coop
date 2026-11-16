const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const Token = @import("cohort_types.zig").Token;
extern fn combat_damage_source_ready() c_int;
pub export fn reaction_bind_cohort(original: ?*const Token) c_int {
    return @intFromBool(s.binding.bind(original));
}
pub export fn reaction_frame_lease_get(out: ?*s.Lease) c_int {
    return @intFromBool(s.binding.get(out));
}
pub export fn reaction_frame_cancelled(op: ?*const s.Lease) c_int {
    return @intFromBool(s.binding.cancelled(op));
}
pub export fn reaction_abort_frame(op: ?*const s.Lease) c_int {
    if (!s.binding.detach(op)) return 0;
    s.active = false;
    s.cancelled = true;
    s.journal = std.mem.zeroes(s.Journal);
    return 1;
}
pub export fn reaction_ready() c_int {
    return @intFromBool(s.clonewars_reaction_installed == 1 and combat_damage_source_ready() != 0);
}
pub export fn reaction_cancel() void {
    if (s.binding.bound or s.binding.lease.cohort.thread == 0 or s.binding.lease.cohort.thread != s.win.GetCurrentThreadId()) return;
    s.active = false;
    s.cancelled = true;
    s.journal = std.mem.zeroes(s.Journal);
}
pub export fn reaction_begin(frame: *p.SyncFrame, host: c_int) c_int {
    if (!s.binding.begin(@intFromPtr(frame))) return 0;
    const op = s.binding.lease;
    if (!s.binding.live(&op)) return 0;
    s.cancelled = false;
    if (s.last_epoch != op.cohort.epoch) {
        s.clonewars_item_range_failure_mask = 0;
        s.clonewars_item_range_failure = std.mem.zeroes(@TypeOf(s.clonewars_item_range_failure));
        s.clonewars_reaction_failure = @splat(0);
        s.clonewars_reaction_first_correction = @splat(0);
        s.last_epoch = op.cohort.epoch;
    }
    s.reaction_journal_begin(&s.journal, frame, host);
    s.active = true;
    return @intFromBool(s.live(&op));
}
pub export fn reaction_finish() c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active or s.cancelled) return 0;
    s.active = false;
    s.clonewars_reaction_debug[5] +%= 1;
    if (s.journal.finish() == 0) {
        s.clonewars_reaction_debug[6] +%= 1;
        if (s.journal.failed == 0) {
            const entry = s.journal.peek();
            s.journal.failed = 7;
            s.failed(&op, 0, entry, 0, 0, 7, std.math.maxInt(u32));
        }
        return 0;
    }
    return 1;
}
pub export fn reaction_install() c_int {
    return @import("reaction_install.zig").install();
}
comptime {
    _ = @import("reaction_choice.zig");
    _ = @import("reaction_receipt.zig");
    _ = @import("reaction_item_range.zig");
    _ = @import("reaction_arena.zig");
}
