const p = @import("protocol.zig");
const abi = @import("abi.zig");
const v = @import("validation.zig");
pub const Journal = @import("geometry_types.zig").Journal;
pub const Batch = @import("geometry_types.zig").Batch;
pub fn valid(entry: ?*const p.SyncCollider) bool {
    const e = entry orelse return false;
    if (e.manager_ordinal == 0 or e.manager_ordinal > 64 or e.slot >= p.SYNC_MAX_ACTORS or e.generation == 0 or !abi.validLevel(e.character) or !v.finite(e.*)) return false;
    for (0..3) |i| if (e.bounds[i] > e.bounds[i + 3]) return false;
    return e.extents[0] >= 0 and e.extents[1] >= 0;
}
pub export fn geometry_journal_begin(j: *Journal, frame: *p.SyncFrame, host: c_int) void {
    j.* = .{ .frame = frame, .cursor = 0, .ordinal = 0, .validated = 0, .host = host, .failed = 0 };
    if (host != 0) {
        frame.geometry_count = 0;
        frame.geometry_calls = 0;
    }
}
pub export fn geometry_journal_phase(j: *Journal, mode: u32, batch: *Batch) c_int {
    j.validated = 0;
    j.ordinal +%= 1;
    batch.* = .{ .start = j.cursor, .count = 0, .ordinal = j.ordinal, .mode = mode };
    if (j.failed != 0 or j.ordinal == 0 or j.ordinal > 64 or (j.host == 0 and j.ordinal > j.frame.?.geometry_calls)) return j.fail(3);
    if (j.host != 0) {
        j.frame.?.geometry_calls = j.ordinal;
        return 1;
    }
    if (j.frame.?.geometry_count > p.SYNC_MAX_ACTORS or batch.start > j.frame.?.geometry_count) return j.fail(3);
    while (batch.count < j.frame.?.geometry_count - batch.start) {
        const entry = &j.frame.?.geometry[batch.start + batch.count];
        if (entry.manager_ordinal < j.ordinal) return j.fail(3);
        if (entry.manager_ordinal != j.ordinal) break;
        batch.count += 1;
    }
    return if (mode != 0 and batch.count != 0) j.fail(3) else 1;
}
pub export fn geometry_journal_record(j: *Journal, entry: *const p.SyncCollider) c_int {
    const count = j.frame.?.geometry_count;
    if (j.failed != 0 or j.host == 0 or count >= p.SYNC_MAX_ACTORS or entry.manager_ordinal != j.ordinal or !valid(entry)) return j.fail(2);
    if (count != 0) {
        const previous = &j.frame.?.geometry[count - 1];
        if (previous.manager_ordinal == entry.manager_ordinal and previous.slot >= entry.slot) return j.fail(5);
    }
    j.frame.?.geometry[count] = entry.*;
    j.frame.?.geometry_count += 1;
    return 1;
}
pub export fn geometry_journal_validate(j: *Journal, entry: ?*const p.SyncCollider, owner_matches: c_int) c_int {
    if (j.failed != 0) return 0;
    const count = j.frame.?.geometry_count;
    if (entry == null or count > p.SYNC_MAX_ACTORS or j.cursor > count or j.validated >= count - j.cursor) return j.fail(2);
    const e = entry.?;
    if (e != &j.frame.?.geometry[j.cursor + j.validated] or e.manager_ordinal != j.ordinal or !valid(e)) return j.fail(2);
    if (j.validated != 0 and j.frame.?.geometry[j.cursor + j.validated - 1].slot >= e.slot) return j.fail(5);
    if (owner_matches == 0) return j.fail(4);
    j.validated += 1;
    return 1;
}
pub export fn geometry_journal_commit(j: *Journal, batch: *const Batch) c_int {
    const count = j.frame.?.geometry_count;
    if (j.failed != 0 or j.host != 0 or batch.start != j.cursor or batch.ordinal != j.ordinal or batch.start > count or
        batch.count > count - batch.start or j.validated != batch.count) return j.fail(3);
    j.cursor += batch.count;
    return 1;
}
pub export fn geometry_journal_finish(j: *const Journal) c_int {
    return @intFromBool(j.failed == 0 and (j.host != 0 or (j.cursor == j.frame.?.geometry_count and j.ordinal == j.frame.?.geometry_calls)));
}
