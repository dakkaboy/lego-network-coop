const abi = @import("abi.zig");
const Cursor = abi.c.SyncEpochCursor;
const trace = @import("trace.zig");
pub const Result = enum(c_int) { invalid = -3, gap = -2, wait_level = -1, stale = 0, next = 1, first = 2 };

pub fn classify(cursor: *const Cursor, loaded: i32, epoch: u32, level: i32, sequence: u32) Result {
    if (epoch == 0 or sequence == 0 or !abi.validLevel(level)) return .invalid;
    if (epoch < cursor.epoch or (epoch == cursor.epoch and cursor.active == 0)) return .stale;
    if (level != loaded) return if (epoch > cursor.epoch) .wait_level else .stale;
    if (epoch > cursor.epoch) return if (sequence == 1) .first else .gap;
    if (level != cursor.level) return .invalid;
    if (sequence <= cursor.sequence) return .stale;
    return if (sequence == cursor.sequence + 1) .next else .gap;
}

export fn sync_epoch_begin(cursor: *Cursor, level: c_int) u32 {
    if (cursor.active != 0 and cursor.level == level) return cursor.epoch;
    const next = cursor.epoch +% 1;
    cursor.* = .{ .epoch = if (next == 0) 1 else next, .sequence = 0, .level = level, .active = 1 };
    return cursor.epoch;
}

export fn sync_epoch_loading(cursor: *Cursor) void {
    cursor.active = 0;
    cursor.sequence = 0;
}

export fn sync_epoch_classify(cursor: *const Cursor, loaded: c_int, epoch: u32, level: c_int, sequence: u32) c_int {
    return @backingInt(classify(cursor, loaded, epoch, level, sequence));
}

export fn sync_epoch_apply(cursor: *Cursor, loaded: c_int, epoch: u32, level: c_int, sequence: u32) c_int {
    const result = classify(cursor, loaded, epoch, level, sequence);
    if (result != .next) trace.record(.epoch, epoch, sequence, @bitCast(@backingInt(result)), cursor.epoch, cursor.sequence, @bitCast(level));
    if (@backingInt(result) > 0) cursor.* = .{ .epoch = epoch, .sequence = sequence, .level = level, .active = 1 };
    return @backingInt(result);
}

export fn sync_epoch_unacknowledged(cursor: *const Cursor, epoch: u32, sequence: u32) u32 {
    return if (epoch != cursor.epoch or sequence > cursor.sequence) cursor.sequence else cursor.sequence - sequence;
}

export fn sync_epoch_profile_ready(cursor: *const Cursor, epoch: u32, sequence: u32) c_int {
    return @intFromBool(cursor.active != 0 and epoch == cursor.epoch and sequence <= cursor.sequence);
}
