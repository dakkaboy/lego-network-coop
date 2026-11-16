const std = @import("std");
const win = @import("win32.zig");
const m = @import("mapping_types.zig");
const Row = extern struct { published: u32, pending: u32, done: u32, in_request: u32, has_key: u32, serial: u32, reason: u32, key: m.Key };
var policy = std.mem.zeroes(m.SessionConfig);
var configured: i32 = 0;
var rows: u32 = 0;
var current: u32 = 0;
var fatal: u32 = 0;
var records: [32]Row = @splat(std.mem.zeroes(Row));
extern fn user_mapping_inspect(m.Key, *m.Observation) c_int;
extern fn user_mapping_retire(m.Key) c_int;
extern fn user_mapping_ticket_get(m.Key, *m.Ticket) c_int;
extern fn user_mapping_mutation_try() c_int;
extern fn user_mapping_mutation_unlock() void;
extern fn user_mapping_cleanup_owned(m.Key, *i32) c_int;
extern fn user_mapping_cleanup_consume(m.Key) c_int;
extern fn user_mapping_install_ready() c_int;
extern fn user_mapping_runtime_ready() c_int;
extern fn user_mapping_native_saved_matches(i32) c_int;
fn load(value: *const u32) u32 {
    return @atomicLoad(u32, value, .seq_cst);
}
fn store(value: *u32, next: u32) void {
    @atomicStore(u32, value, next, .seq_cst);
}
fn mainNow() bool {
    return win.GetCurrentThreadId() == policy.main_thread;
}
fn find(serial: u32) ?*Row {
    for (&records) |*r| if (load(&r.published) != 0 and r.serial == serial) return r;
    return null;
}
fn session() u32 {
    return policy.current_session.?(policy.user);
}
fn safe(boundary: usize, length: u32) bool {
    return policy.safe_main_valid.?(boundary, length, policy.user) != 0;
}
pub export fn user_mapping_session_configure(config: ?*const m.SessionConfig) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const c = config orelse return 0;
    if (c.version != 1 or c.main_thread == 0 or c.safe_main_valid == null or c.current_session == null or @cmpxchgStrong(i32, &configured, 0, -1, .seq_cst, .seq_cst) != null) return 0;
    policy = c.*;
    @atomicStore(i32, &configured, 1, .seq_cst);
    return 1;
}
pub export fn user_mapping_session_retire(serial: u32, reason: u32) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const r = find(serial) orelse return 0;
    _ = @atomicRmw(u32, &r.reason, .Or, reason, .seq_cst);
    store(&r.pending, 1);
    return 1;
}
pub export fn user_mapping_session_begin(serial: u32) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or serial == 0 or load(&fatal) != 0 or session() != serial) return 0;
    if (find(serial)) |r| return @intFromBool(load(&r.pending) == 0 and load(&r.done) == 0);
    if (serial < load(&current) or load(&rows) >= records.len) {
        store(&fatal, 1);
        return 0;
    }
    for (&records) |*r| if (load(&r.published) != 0 and load(&r.done) == 0) {
        _ = user_mapping_session_retire(r.serial, 1);
    };
    const r = &records[load(&rows)];
    r.* = std.mem.zeroes(Row);
    r.serial = serial;
    store(&r.published, 1);
    _ = @atomicRmw(u32, &rows, .Add, 1, .seq_cst);
    store(&current, serial);
    return 1;
}
pub export fn user_mapping_session_pending() c_int {
    for (&records) |*r| if (load(&r.published) != 0 and load(&r.pending) != 0 and load(&r.done) == 0 and (load(&r.in_request) != 0 or load(&r.has_key) != 0)) return 1;
    return 0;
}
pub export fn user_mapping_session_acquire_begin(scope: *m.Acquire, serial: u32, request: ?*const m.Request) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    scope.* = std.mem.zeroes(m.Acquire);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or load(&fatal) != 0 or session() != serial or user_mapping_session_pending() != 0) return 0;
    const r = find(serial) orelse return 0;
    if (load(&r.pending) != 0 or load(&r.done) != 0 or load(&r.in_request) != 0 or request == null) return 0;
    if (load(&r.has_key) != 0) {
        var observation: m.Observation = undefined;
        if (user_mapping_inspect(r.key, &observation) == 0 or observation.quality & 4 != 0) return 0;
        _ = user_mapping_retire(r.key);
        store(&r.has_key, 0);
    }
    scope.row = @intFromPtr(r);
    scope.session_serial = serial;
    scope.entered = 1;
    _ = @atomicRmw(u32, &r.in_request, .Add, 1, .seq_cst);
    return 1;
}
pub export fn user_mapping_session_acquire_end(scope: *m.Acquire, unwind: c_int) void {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (scope.entered == 0 or scope.row == 0) return;
    const r: *Row = @ptrFromInt(scope.row);
    if (load(&r.published) == 0 or r.serial != scope.session_serial) return;
    var ticket: m.Ticket = undefined;
    if (scope.key.id != 0 and user_mapping_ticket_get(scope.key, &ticket) != 0 and ticket.flags & 128 == 0) {
        r.key = scope.key;
        store(&r.has_key, 1);
    }
    if (unwind != 0) store(&r.pending, 1);
    _ = @atomicRmw(u32, &r.in_request, .Sub, 1, .seq_cst);
}
pub export fn user_mapping_session_device_get(serial: u32, output: *m.Observation) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or load(&fatal) != 0 or session() != serial) return 0;
    const r = find(serial) orelse return 0;
    if (load(&r.pending) != 0 or load(&r.done) != 0 or load(&r.has_key) == 0 or user_mapping_inspect(r.key, output) == 0 or output.quality & 4 == 0 or session() != serial or load(&r.pending) != 0) return 0;
    if (user_mapping_mutation_try() == 0) return 0;
    defer user_mapping_mutation_unlock();
    var saved: i32 = undefined;
    return @intFromBool(user_mapping_cleanup_owned(r.key, &saved) == 1);
}
pub export fn user_mapping_session_drain_begin(scope: *m.Drain, boundary: usize, length: u32, observed: u32) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    scope.* = std.mem.zeroes(m.Drain);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or load(&fatal) != 0) return 4;
    if (length == 0 or length > scope.boundary.len or user_mapping_install_ready() == 0 or !safe(boundary, length) or session() != observed) return 2;
    @memcpy(scope.boundary[0..length], @as([*]const u8, @ptrFromInt(boundary))[0..length]);
    scope.boundary_bytes = length;
    scope.observed = observed;
    var row: ?*Row = null;
    for (&records) |*r| if (load(&r.published) != 0 and load(&r.pending) != 0 and load(&r.done) == 0) {
        row = r;
        break;
    };
    const r = row orelse return 0;
    scope.row = @intFromPtr(r);
    if (load(&r.in_request) != 0) return 2;
    if (load(&r.has_key) == 0) {
        store(&r.done, 1);
        return 0;
    }
    var observation: m.Observation = undefined;
    if (user_mapping_inspect(r.key, &observation) == 0 or observation.disabled != 0 or observation.ticket.flags & 1 == 0) {
        store(&fatal, 1);
        return 4;
    }
    if (user_mapping_mutation_try() == 0) return 2;
    scope.locked = 1;
    if (!safe(boundary, length) or session() != observed or user_mapping_install_ready() == 0) return 2;
    const owned = user_mapping_cleanup_owned(r.key, &scope.negative);
    if (owned < 0) {
        _ = user_mapping_retire(r.key);
        store(&r.done, 1);
        return 3;
    }
    if (owned == 0 or !safe(boundary, length) or session() != observed) return 2;
    if (user_mapping_cleanup_consume(r.key) == 0) {
        store(&fatal, 1);
        return 4;
    }
    scope.consumed = 1;
    return 1;
}
pub export fn user_mapping_session_drain_complete(scope: *m.Drain) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (scope.consumed == 0) return 0;
    const r: ?*Row = if (scope.row == 0) null else @ptrFromInt(scope.row);
    if (user_mapping_runtime_ready() == 0 or !safe(@intFromPtr(&scope.boundary), scope.boundary_bytes) or session() != scope.observed) {
        if (r) |row| store(&row.done, 1);
        return 6;
    }
    if (user_mapping_native_saved_matches(scope.negative) != 0) {
        if (r) |row| store(&row.done, 1);
        return 1;
    }
    store(&fatal, 1);
    return 4;
}
pub export fn user_mapping_session_drain_end(scope: *m.Drain, unwind: c_int) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    var result: c_int = 0;
    if (scope.consumed != 0 and unwind != 0) {
        store(&fatal, 1);
        result = 5;
    }
    if (scope.locked != 0) {
        scope.locked = 0;
        user_mapping_mutation_unlock();
    }
    return result;
}
