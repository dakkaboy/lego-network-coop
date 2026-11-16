const std = @import("std");
const win = @import("win32.zig");
const m = @import("mapping_types.zig");
const mapping = @import("mapping_session.zig");
const check = @import("native_test_support.zig").check;
var serial: u32 = 1;
var safe = true;
var locked = false;
var allow_lock = true;
var disabled = false;
var owned: i32 = 1;
var unlocked: u32 = 0;
var consumed: u32 = 0;
var retired: u32 = 0;
var boundary: [4]u32 = .{ 11, 22, 33, 44 };
var native_value: i32 = 13;
var ticket = std.mem.zeroes(m.Ticket);
pub export fn user_mapping_inspect(key: m.Key, out: ?*m.Observation) i32 {
    check(@src(), key.id == 1);
    win.SetLastError(777);
    const value = out orelse return 0;
    value.* = std.mem.zeroes(m.Observation);
    value.ticket = ticket;
    value.disabled = @intFromBool(disabled);
    value.quality = 4;
    return 1;
}
pub export fn user_mapping_retire(_: m.Key) i32 {
    retired += 1;
    return 1;
}
pub export fn user_mapping_ticket_get(key: m.Key, out: *m.Ticket) i32 {
    check(@src(), key.id == 1);
    out.* = ticket;
    return 1;
}
pub export fn user_mapping_mutation_try() i32 {
    if (!allow_lock) return 0;
    check(@src(), !locked);
    locked = true;
    return 1;
}
pub export fn user_mapping_mutation_unlock() void {
    check(@src(), locked);
    locked = false;
    unlocked += 1;
}
pub export fn user_mapping_cleanup_owned(key: m.Key, negative: *i32) i32 {
    check(@src(), locked and key.id == 1);
    negative.* = -9;
    return owned;
}
pub export fn user_mapping_cleanup_consume(key: m.Key) i32 {
    check(@src(), key.id == 1);
    consumed += 1;
    return 1;
}
pub export fn user_mapping_install_ready() i32 {
    return 1;
}
pub export fn user_mapping_runtime_ready() i32 {
    return 1;
}
pub export fn user_mapping_native_saved_matches(negative: i32) i32 {
    return @intFromBool(native_value == negative);
}
fn safeMain(proof: usize, size: u32, _: usize) callconv(.c) i32 {
    win.SetLastError(888);
    return @intFromBool(safe and size == @sizeOf(@TypeOf(boundary)) and std.mem.eql(u8, @as([*]const u8, @ptrFromInt(proof))[0..size], std.mem.asBytes(&boundary)));
}
fn currentSession(_: usize) callconv(.c) u32 {
    win.SetLastError(999);
    return serial;
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const mode = if (args.len > 1) try std.fmt.parseInt(u32, args[1], 10) else 0;
    const config: m.SessionConfig = .{ .version = 1, .main_thread = win.GetCurrentThreadId(), .safe_main_valid = safeMain, .current_session = currentSession, .user = 0 };
    win.SetLastError(123);
    check(@src(), mapping.user_mapping_session_configure(&config) != 0 and win.GetLastError() == 123);
    check(@src(), mapping.user_mapping_session_configure(&config) == 0);
    check(@src(), mapping.user_mapping_session_begin(1) != 0 and mapping.user_mapping_session_begin(1) != 0);
    const request = std.mem.zeroes(m.Request);
    var acquire = std.mem.zeroes(m.Acquire);
    check(@src(), mapping.user_mapping_session_acquire_begin(&acquire, 1, &request) != 0);
    acquire.key = .{ .slot = 0, .id = 1 };
    ticket.key = acquire.key;
    ticket.flags = 1;
    mapping.user_mapping_session_acquire_end(&acquire, 0);
    var observation: m.Observation = undefined;
    win.SetLastError(456);
    check(@src(), mapping.user_mapping_session_device_get(1, &observation) != 0 and win.GetLastError() == 456 and !locked);
    serial = 2;
    check(@src(), mapping.user_mapping_session_begin(2) != 0 and mapping.user_mapping_session_pending() != 0 and mapping.user_mapping_session_device_get(1, &observation) == 0);
    switch (mode) {
        1 => owned = -1,
        2 => allow_lock = false,
        3 => safe = false,
        4 => disabled = true,
        else => {},
    }
    var drain = std.mem.zeroes(m.Drain);
    win.SetLastError(654);
    const result = mapping.user_mapping_session_drain_begin(&drain, @intFromPtr(&boundary), @sizeOf(@TypeOf(boundary)), 2);
    check(@src(), win.GetLastError() == 654);
    switch (mode) {
        1 => check(@src(), result == 3 and retired == 1 and mapping.user_mapping_session_pending() == 0),
        2, 3 => check(@src(), result == 2 and drain.consumed == 0),
        4 => check(@src(), result == 4 and drain.consumed == 0),
        else => {
            check(@src(), result == 1 and drain.consumed != 0 and locked and consumed == 1 and drain.negative == -9);
            native_value = -9;
            if (mode == 5) safe = false;
            if (mode == 6) native_value = -8;
            const expected: i32 = if (mode == 5) 6 else if (mode == 6) 4 else 1;
            check(@src(), mapping.user_mapping_session_drain_complete(&drain) == expected);
        },
    }
    win.SetLastError(789);
    const ended = mapping.user_mapping_session_drain_end(&drain, @intFromBool(mode == 7));
    check(@src(), win.GetLastError() == 789 and !locked and ended == (if (mode == 7) @as(i32, 5) else 0));
    if (mode == 0) {
        check(@src(), mapping.user_mapping_session_pending() == 0);
        serial = 3;
        check(@src(), mapping.user_mapping_session_begin(3) != 0);
    }
    if (mode == 4 or mode == 6 or mode == 7) {
        serial = 3;
        check(@src(), mapping.user_mapping_session_begin(3) == 0);
    }
}
