const p = @import("protocol.zig");
const v = @import("validation.zig");
pub const Journal = @import("journal.zig").Journal("cadence", "cadence_count");

fn valid(entry: ?*const p.SyncCadence) bool {
    const e = entry orelse return false;
    return e.slot < p.SYNC_MAX_ACTORS and e.generation != 0 and e.period != 0 and e.period <= 255 and e.phase <= 255 and v.finite(e.elapsed) and e.elapsed >= 0;
}
pub export fn cadence_journal_begin(j: *Journal, frame: *p.SyncFrame, host: c_int) void {
    j.begin(frame, host);
}
pub export fn cadence_journal_record(j: *Journal, entry: ?*const p.SyncCadence) c_int {
    return j.record(entry, valid, 4);
}
pub export fn cadence_journal_peek(j: *const Journal) ?*const p.SyncCadence {
    return j.peek();
}
pub export fn cadence_journal_finish(j: *const Journal) c_int {
    return j.finish();
}
pub export fn cadence_journal_apply(j: *Journal, entry: ?*const p.SyncCadence, owner_matches: c_int, phase: u32, period: *u32, elapsed: *f32) c_int {
    if (j.failed != 0) return 0;
    if (entry == null or entry != j.peek()) return j.fail(3);
    if (owner_matches == 0) return j.fail(1);
    if (entry.?.phase != phase) return j.fail(2);
    if (!valid(entry)) return j.fail(4);
    period.* = entry.?.period;
    elapsed.* = entry.?.elapsed;
    j.cursor += 1;
    return 1;
}
