const std = @import("std");
const win = @import("win32.zig");
const threads = @import("threading.zig");
const m = @import("mapping_types.zig");
const Environment = @import("machine_environment.zig").Environment;
const root = @import("root");
const testing = if (@hasDecl(root, "mapping_test_api")) root.mapping_test_api else false;
const Record = extern struct { committed: u32, flags: u32, data: m.Ticket };
const Event = extern struct { entered: u32, site: u32, mask: u32, generation: u32, acquired: u32, locked: u32, user: i32, marker: ?*m.Marker, claim: m.Key };
var configuration = std.mem.zeroes(m.Config);
var configured: i32 = 0;
var enabled: u32 = 0;
var disabled: u32 = 0;
var coverage: u32 = 0;
var next_id: u32 = 0;
var ticket_count: u32 = 0;
var generation: [4]u32 = @splat(0);
var committed_generation: [4]u32 = @splat(0);
var writer_depth: [4]u32 = @splat(0);
var setter_depth: [4]u32 = @splat(0);
var reset_generation: u32 = 0;
var poller_depth: u32 = 0;
var mutation_lock: threads.CriticalSection = .{};
var tickets: [64]Record = @splat(std.mem.zeroes(Record));
threadlocal var marker_head: ?*m.Marker = null;
threadlocal var physical_marker: ?*m.Marker = null;
var entry_count: [8]u32 = @splat(0);
export const user_mapping_default_mxcsr: u32 = 0x1f80;
pub export var clonewars_user_mapping_observer_version: u32 = 2;
pub export var clonewars_user_mapping_observer_faults: u32 = 0;
extern fn user_mapping_test_admission_wait(u32) void;
fn load(value: *const u32) u32 {
    return @atomicLoad(u32, value, .seq_cst);
}
fn store(value: *u32, next: u32) void {
    @atomicStore(u32, value, next, .seq_cst);
}
fn mainNow() bool {
    return win.GetCurrentThreadId() == configuration.main_thread;
}
fn domain(user: i32) bool {
    return user >= 0 and user < 4;
}
fn disable() void {
    store(&disabled, 1);
    _ = @atomicRmw(u32, &clonewars_user_mapping_observer_faults, .Add, 1, .seq_cst);
}
pub export fn user_mapping_invalidate_runtime() void {
    disable();
}
fn advance(value: *u32) u32 {
    while (true) {
        const prior = load(value);
        if (prior == 0xffffffff) {
            disable();
            return 0;
        }
        if (@cmpxchgStrong(u32, value, prior, prior + 1, .seq_cst, .seq_cst) == null) return prior + 1;
    }
}
fn decrement(value: *u32) void {
    while (true) {
        const prior = load(value);
        if (prior == 0) {
            disable();
            return;
        }
        if (@cmpxchgStrong(u32, value, prior, prior - 1, .seq_cst, .seq_cst) == null) return;
    }
}
fn ready() bool {
    return @atomicLoad(i32, &configured, .seq_cst) == 1 and load(&enabled) != 0 and load(&disabled) == 0 and load(&coverage) & 127 == 127;
}
pub export fn user_mapping_runtime_ready() c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    return @intFromBool(mainNow() and ready());
}
fn record(key: m.Key) ?*Record {
    if (key.slot >= tickets.len or key.id == 0) return null;
    const r = &tickets[key.slot];
    return if (r.data.key.id == key.id) r else null;
}
fn flags(key: m.Key, value: u32) void {
    if (record(key)) |r| {
        _ = @atomicRmw(u32, &r.flags, .Or, value, .seq_cst);
    }
}
fn invalidate(mask: u32, reset: bool) u32 {
    if (reset and advance(&reset_generation) == 0) return 0;
    var last: u32 = 0;
    for (&generation, &committed_generation, 0..) |*g, *c, i| if (mask & (@as(u32, 1) << @intCast(i)) != 0) {
        last = advance(g);
        store(c, 0);
    };
    return last;
}
pub export fn user_mapping_configure(config: ?*const m.Config) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const c = config orelse return 0;
    if (c.version != 2 or c.main_thread == 0 or c.native_table == 0 or c.native_owners == 0 or c.original_source_valid == null) return 0;
    for (c.targets) |target| if (target == 0) return 0;
    if (!win.accessible(c.native_table, 32, false) or @cmpxchgStrong(i32, &configured, 0, -1, .seq_cst, .seq_cst) != null) return 0;
    configuration = c.*;
    threads.InitializeCriticalSection(&mutation_lock);
    @atomicStore(i32, &configured, 1, .seq_cst);
    return 1;
}
pub export fn user_mapping_binding_ready(declared: u32) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or load(&enabled) != 0 or declared & ~@as(u32, 127) != 0) return 0;
    store(&coverage, declared);
    return 1;
}
pub export fn user_mapping_enable() c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (@atomicLoad(i32, &configured, .seq_cst) != 1 or !mainNow() or load(&disabled) != 0 or load(&coverage) & 127 != 127) return 0;
    store(&enabled, 1);
    return 1;
}
fn event(bridge: *m.Bridge) *Event {
    return @ptrCast(@alignCast(&bridge.storage));
}
pub export fn user_mapping_bridge_begin(bridge: *m.Bridge) void {
    const e = event(bridge);
    if (comptime testing) {
        _ = @atomicRmw(u32, &entry_count[bridge.site], .Add, 1, .seq_cst);
    }
    e.* = std.mem.zeroes(Event);
    e.site = bridge.site;
    e.user = -1;
    bridge.target = configuration.targets[bridge.site];
    bridge.args = @splat(0);
    const args = bridge.entry_esp + 4;
    if (bridge.site == 0 or bridge.site == 1) {
        bridge.args = win.load([2]i32, args);
        e.user = bridge.args[0];
    } else if (bridge.site == 3) bridge.args[0] = win.load(i32, args);
    if (load(&enabled) == 0) return;
    if (!mainNow()) disable();
    if (comptime testing) user_mapping_test_admission_wait(bridge.site);
    threads.EnterCriticalSection(&mutation_lock);
    e.locked = 1;
    if (bridge.site == 1) {
        if (domain(e.user)) {
            const user: usize = @intCast(e.user);
            e.mask = @as(u32, 1) << @intCast(user);
            e.entered = 1;
            if (advance(&setter_depth[user]) != 0) e.acquired = e.mask;
        } else disable();
        if (!mainNow()) disable();
        threads.LeaveCriticalSection(&mutation_lock);
        e.locked = 0;
        return;
    }
    if (bridge.site == 7) {
        e.entered = 1;
        if (advance(&poller_depth) != 0) e.acquired = 1;
        if (!mainNow()) disable();
        threads.LeaveCriticalSection(&mutation_lock);
        e.locked = 0;
        return;
    }
    if (bridge.site == 0) {
        if (!domain(e.user)) {
            disable();
            return;
        }
        e.mask = @as(u32, 1) << @intCast(e.user);
    } else e.mask = if (bridge.site == 3) 3 else if (bridge.site == 5 or bridge.site == 6) 1 else 15;
    e.entered = 1;
    for (&writer_depth, 0..) |*depth, i| if (e.mask & (@as(u32, 1) << @intCast(i)) != 0 and advance(depth) != 0) {
        e.acquired |= @as(u32, 1) << @intCast(i);
    };
    if (!mainNow()) disable();
    if (!ready()) return;
    _ = invalidate(e.mask, bridge.site == 2 or bridge.site == 3 or bridge.site == 4);
    if (!ready()) return;
    if (bridge.site != 0) return;
    e.generation = load(&generation[@intCast(e.user)]);
    const marker = physical_marker;
    if (marker_head != marker) {
        disable();
        return;
    }
    const request = marker orelse return;
    if (request.linked == 0 or request.admitted == 0 or request.claimed != 0 or request.request.user != e.user or request.request.requested != bridge.args[1]) return;
    request.claimed = 1;
    e.marker = request;
    e.claim = request.key;
    flags(request.key, 64);
}
pub export fn user_mapping_bridge_end(bridge: *m.Bridge, unwind: c_int) void {
    var environment: Environment = undefined;
    environment.save(&user_mapping_default_mxcsr);
    defer environment.restore();
    const e = event(bridge);
    if (e.entered == 0) return;
    if (e.site == 1 or e.site == 7) {
        threads.EnterCriticalSection(&mutation_lock);
        e.locked = 1;
        if (e.acquired != 0) decrement(if (e.site == 1) &setter_depth[@intCast(e.user)] else &poller_depth);
        return;
    }
    for (&writer_depth, 0..) |*depth, i| if (e.acquired & (@as(u32, 1) << @intCast(i)) != 0) decrement(depth);
    if (unwind != 0) {
        _ = invalidate(e.mask, true);
        return;
    }
    if (!ready() or e.site != 0) return;
    const user: usize = @intCast(e.user);
    if (load(&generation[user]) != e.generation or load(&writer_depth[user]) != 0) {
        _ = invalidate(e.mask, false);
        return;
    }
    const actual = win.load(i32, configuration.native_table + user * 8);
    if (load(&generation[user]) != e.generation or load(&writer_depth[user]) != 0 or !ready()) return;
    store(&committed_generation[user], e.generation);
    if (e.marker) |marker| {
        if (marker_head != physical_marker or physical_marker != marker or marker.linked == 0 or marker.key.id != e.claim.id or marker.key.slot != e.claim.slot) {
            disable();
            return;
        }
        const r = record(e.claim) orelse return;
        if (actual >= 12 and actual <= 13) {
            r.data.actual = actual;
            r.data.generation = e.generation;
            r.data.reset_generation = load(&reset_generation);
            _ = @atomicRmw(u32, &r.flags, .Or, 1, .seq_cst);
            store(&r.committed, e.claim.id);
        }
    }
}
pub export fn user_mapping_bridge_unlock(bridge: *m.Bridge) void {
    var environment: Environment = undefined;
    environment.save(&user_mapping_default_mxcsr);
    defer environment.restore();
    const e = event(bridge);
    if (e.locked != 0) {
        e.locked = 0;
        threads.LeaveCriticalSection(&mutation_lock);
    }
}
pub export fn user_mapping_mutation_try() c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    return @intFromBool(mainNow() and ready() and threads.TryEnterCriticalSection(&mutation_lock) != 0);
}
pub export fn user_mapping_mutation_unlock() void {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    threads.LeaveCriticalSection(&mutation_lock);
}
fn allIdle() bool {
    if (load(&poller_depth) != 0) return false;
    for (&setter_depth, &writer_depth) |*setter, *writer| if (load(setter) != 0 or load(writer) != 0) return false;
    return true;
}
pub export fn user_mapping_cleanup_owned(key: m.Key, negative: *i32) c_int {
    if (!mainNow() or !ready() or !allIdle()) return 0;
    const r = record(key) orelse return -1;
    if (load(&r.committed) != key.id or load(&r.flags) & 1 == 0 or load(&r.flags) & 32 != 0) return -1;
    const ticket = &r.data;
    if (ticket.user != 1 or ticket.saved_negative >= 0 or ticket.actual < 12 or ticket.actual > 13 or load(&generation[1]) != ticket.generation or load(&committed_generation[1]) != ticket.generation or load(&reset_generation) != ticket.reset_generation or
        win.load(i32, configuration.native_table + 8) != ticket.actual or win.load(i32, configuration.native_owners + @as(usize, @intCast(ticket.actual)) * 0x90) != 1) return -1;
    if (!ready() or !allIdle()) return 0;
    negative.* = ticket.saved_negative;
    return 1;
}
pub export fn user_mapping_cleanup_consume(key: m.Key) c_int {
    if (!mainNow()) return 0;
    const r = record(key) orelse return 0;
    if (load(&r.flags) & 32 != 0) return 0;
    flags(key, 32);
    return 1;
}
pub export fn user_mapping_native_saved_matches(negative: i32) c_int {
    return @intFromBool(mainNow() and negative < 0 and win.load(i32, configuration.native_table + 8) == negative);
}
pub export fn user_mapping_request_begin(marker: *m.Marker, request: ?*const m.Request, output: ?*m.Key) void {
    var environment: Environment = undefined;
    environment.save(&user_mapping_default_mxcsr);
    defer environment.restore();
    marker.* = std.mem.zeroes(m.Marker);
    if (output) |out| out.* = .{ .slot = 0, .id = 0 };
    const r = request orelse return;
    const out = output orelse return;
    if (!ready() or !mainNow() or r.user != 1 or r.requested != 13 or r.saved_negative >= 0 or r.source.assignment == 0 or r.source.epoch == 0 or r.source.proof_bytes == 0 or r.source.proof_bytes > 64) return;
    if (marker_head != physical_marker) {
        disable();
        return;
    }
    marker.request = r.*;
    marker.previous = marker_head;
    marker.previous_physical = physical_marker;
    marker.linked = 1;
    marker_head = marker;
    physical_marker = marker;
    marker.entered = 1;
    const slot = advance(&ticket_count);
    if (slot == 0 or slot > tickets.len) {
        disable();
        return;
    }
    const id = advance(&next_id);
    if (id == 0) return;
    marker.key = .{ .slot = slot - 1, .id = id };
    out.* = marker.key;
    const ticket = &tickets[slot - 1].data;
    ticket.key = marker.key;
    @memcpy(std.mem.asBytes(&ticket.source), std.mem.asBytes(&r.source)[0..@sizeOf(m.Stamp)]);
    ticket.user = r.user;
    ticket.requested = r.requested;
    ticket.saved_negative = r.saved_negative;
    ticket.actual = -1;
    if (configuration.original_source_valid.?(@intFromPtr(&r.source.proof), r.source.proof_bytes) == 0) {
        flags(marker.key, 8);
        return;
    }
    if (!ready()) return;
    if (win.load(i32, configuration.native_table + 8) != r.saved_negative) {
        flags(marker.key, 256);
        return;
    }
    marker.admitted = 1;
}
pub export fn user_mapping_request_end(marker: *m.Marker, unwind: c_int) void {
    var environment: Environment = undefined;
    environment.save(&user_mapping_default_mxcsr);
    defer environment.restore();
    if (marker.entered != 0) {
        flags(marker.key, @as(u32, if (unwind != 0) 4 else 2) | @as(u32, if (marker.admitted != 0) 0 else 128));
        if (marker_head == marker and physical_marker == marker) {
            physical_marker = marker.previous_physical;
            marker_head = marker.previous;
            marker.linked = 0;
        } else disable();
    }
}
pub export fn user_mapping_ticket_get(key: m.Key, output: ?*m.Ticket) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const out = output orelse return 0;
    if (!mainNow()) return 0;
    const r = record(key) orelse return 0;
    out.* = r.data;
    out.flags = load(&r.flags);
    return 1;
}
pub export fn user_mapping_inspect(key: m.Key, output: ?*m.Observation) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const out = output orelse return 0;
    if (!mainNow()) return 0;
    const r = record(key) orelse return 0;
    out.* = std.mem.zeroes(m.Observation);
    out.ticket = r.data;
    out.ticket.flags = load(&r.flags);
    out.quality = 1;
    out.disabled = load(&disabled);
    const user: usize = @intCast(r.data.user);
    out.generation = load(&generation[user]);
    out.committed_generation = load(&committed_generation[user]);
    out.reset_generation = load(&reset_generation);
    out.setter_depth = load(&setter_depth[user]);
    out.writer_depth = load(&writer_depth[user]);
    out.poller_depth = load(&poller_depth);
    out.current_actual = -1;
    if (out.ticket.flags & 32 != 0 or !ready() or load(&r.committed) != key.id or out.generation != r.data.generation or out.committed_generation != r.data.generation or out.reset_generation != r.data.reset_generation) return 1;
    out.quality |= 2;
    if (allIdle()) out.quality |= 8;
    out.current_actual = win.load(i32, configuration.native_table + user * 8);
    if (out.current_actual == r.data.actual and ready() and load(&generation[user]) == out.generation and load(&reset_generation) == out.reset_generation) out.quality |= 4;
    return 1;
}
fn changeFlags(key: m.Key, value: u32) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (!mainNow() or record(key) == null) return 0;
    flags(key, value);
    return 1;
}
pub export fn user_mapping_cancel(key: m.Key) c_int {
    return changeFlags(key, 16);
}
pub export fn user_mapping_retire(key: m.Key) c_int {
    return changeFlags(key, 32);
}
pub export fn user_mapping_user0_store_event() void {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (load(&enabled) != 0) {
        if (!mainNow()) disable() else if (ready()) {
            _ = invalidate(1, false);
        }
    }
}
fn testId(id: u32) callconv(.c) void {
    store(&next_id, id);
}
fn testGeneration(user: u32, value: u32) callconv(.c) void {
    if (user < 4) store(&generation[user], value);
}
fn testMarkerEmpty() callconv(.c) c_int {
    return @intFromBool(marker_head == null and physical_marker == null);
}
fn testCorruptMarker() callconv(.c) void {
    marker_head = @ptrFromInt(0x11110000);
}
fn testEntryCount(site: u32) callconv(.c) u32 {
    return if (site < entry_count.len) load(&entry_count[site]) else 0;
}
comptime {
    std.debug.assert(@sizeOf(Event) <= 1024 and @offsetOf(m.Bridge, "site") == 1752 and @offsetOf(m.Bridge, "storage") == 1764);
    if (testing) {
        @export(&testId, .{ .name = "user_mapping_test_id" });
        @export(&testGeneration, .{ .name = "user_mapping_test_generation" });
        @export(&testMarkerEmpty, .{ .name = "user_mapping_test_marker_empty" });
        @export(&testCorruptMarker, .{ .name = "user_mapping_test_corrupt_marker" });
        @export(&testEntryCount, .{ .name = "user_mapping_test_entry_count" });
    }
}
