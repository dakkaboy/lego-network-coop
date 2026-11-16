const std = @import("std");
const win = @import("win32.zig");
const o = @import("owner.zig");
const fence = @import("frame_fence.zig");
const mapping = @import("mapping_observer.zig");
const m = @import("mapping_types.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub var table: [*]i32 = undefined;
var frame: [2]u32 = .{ 1, 7 };
pub var token: fence.Token = undefined;
pub var owners: [32 * 36]i32 = @splat(0);
var field3c: [32]i32 = @splat(0);
var field44: [32]i32 = @splat(0);
var device_state: [32]i32 = @splat(0);
var active: [4]u8 = @splat(0);
var secondary: [4]u8 = @splat(0);
var requested_word: [4]u16 = @splat(0);
var mode: u32 = 0;
var set_calls: u32 = 0;
var map_calls: u32 = 0;
var reset_calls: u32 = 0;
var depth: u32 = 0;
var proof_raise = false;
var proof_fail = false;
var outer_key: m.Key = undefined;
var child_key: m.Key = undefined;
var request: m.Request = undefined;
extern fn user_mapping_test_corrupt_marker() void;
extern fn user_mapping_test_id(u32) void;
extern fn user_mapping_test_generation(u32, u32) void;
extern fn user_mapping_test_marker_empty() i32;
pub extern fn user_mapping_mapper_entry(i32, i32) void;
pub extern fn user_mapping_setter_entry(i32, i32) void;
pub extern fn user_mapping_reset_all_entry() void;
pub extern fn user_mapping_reset_01_entry(i32) void;
pub extern fn user_mapping_initializer_entry() void;
pub extern fn user_mapping_user0_a_entry() void;
pub extern fn user_mapping_user0_b_entry() void;
pub extern fn user_mapping_poller_entry() void;
extern fn user_mapping_owned_request(*const m.Request, *m.Key) i32;
pub extern fn native_owner_entry(usize) callconv(.{ .x86_thiscall = .{} }) u32;
extern "kernel32" fn CreateThread(usize, usize, *const fn (usize) callconv(.winapi) u32, usize, u32, ?*u32) callconv(.winapi) usize;
extern "kernel32" fn WaitForSingleObject(usize, u32) callconv(.winapi) u32;
pub fn allocate(n: usize) usize {
    const p = win.VirtualAlloc(0, n, 0x3000, 4);
    check(@src(), p != 0);
    return p;
}
pub fn sourceValid(raw: usize, n: u32) callconv(.c) i32 {
    check(@src(), n == @sizeOf(fence.Token));
    if (proof_raise) {
        win.SetLastError(0x63636363);
        win.RaiseException(0xe0011234, 0, 0, null);
    }
    return if (proof_fail) 0 else fence.coherent_frame_valid(@ptrFromInt(raw), 0x3e);
}
fn resolve(device: i32, user: i32) i32 {
    return if (device >= 10 and device <= 13) (if (user == 1) @as(i32, 10) else 11) + (if (user >= 0) user * 2 else 0) else device;
}
fn nativeMapper(user: i32, requested: i32) callconv(.c) void {
    map_calls += 1;
    if (user < 0 or user >= 4) return;
    const u: usize = @intCast(user);
    const old = table[u * 2];
    if (old >= 0 and old < 32) owners[@as(usize, @intCast(old)) * 36] = -1;
    const actual = resolve(requested, user);
    table[u * 2] = actual;
    if (mode == 12 and depth == 1) {
        win.SetLastError(0x12121212);
        win.RaiseException(0xe0011234, 0, 0, null);
    }
    if (actual >= 0 and actual < 32) {
        const a: usize = @intCast(actual);
        owners[a * 36] = user;
        field3c[a] = 0;
    }
}
fn activation(user: usize) void {
    active[user] = 1;
    secondary[user] = 1;
    if (depth != 1 or mode == 10 or mode == 14 or mode == 15) return;
    var obs: m.Observation = undefined;
    check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0);
    check(@src(), obs.ticket.flags & 1 != 0 and obs.setter_depth == 1 and obs.quality & 8 == 0);
    switch (mode) {
        19 => {
            user_mapping_test_corrupt_marker();
            user_mapping_mapper_entry(1, 13);
        },
        1 => user_mapping_setter_entry(1, 13),
        2 => {
            user_mapping_reset_all_entry();
            user_mapping_setter_entry(1, 13);
        },
        3 => {
            user_mapping_reset_01_entry(1);
            user_mapping_setter_entry(1, 13);
        },
        4 => {
            user_mapping_initializer_entry();
            user_mapping_setter_entry(1, 13);
        },
        5 => {
            user_mapping_reset_01_entry(1);
            const r = request;
            check(@src(), user_mapping_owned_request(&r, &child_key) != 0);
        },
        6 => {
            fence.coherent_frame_cancel_atomic(0x10);
            check(@src(), mapping.user_mapping_cancel(outer_key) != 0);
        },
        7 => {
            win.SetLastError(0x77777777);
            win.RaiseException(0xe0011234, 0, 0, null);
        },
        17 => {
            const r = request;
            check(@src(), user_mapping_owned_request(&r, &child_key) == 0);
        },
        else => {},
    }
}
fn nativeSetter(user: i32, requested: i32) callconv(.c) void {
    set_calls += 1;
    if (user < 0 or user >= 4) return;
    const u: usize = @intCast(user);
    depth += 1;
    if (active[u] != 0) {
        const old = table[u * 2];
        if (old >= 0 and old < 32) device_state[@intCast(old)] = 5 else @memset(device_state[0..14], 5);
    }
    active[u] = 0;
    secondary[u] = 0;
    user_mapping_mapper_entry(user, requested);
    if (requested >= 0) {
        activation(u);
        if (requested < 32) field44[@intCast(requested)] = 0;
    }
    requested_word[u] = @truncate(@as(u32, @bitCast(requested)));
    depth -= 1;
}
fn nativeResetAll() callconv(.c) void {
    reset_calls += 1;
    for (0..4) |i| {
        table[i * 2] = -1;
        active[i] = 0;
    }
    for (0..16) |i| owners[i * 36] = -1;
}
fn nativeReset01(flag: i32) callconv(.c) void {
    reset_calls += 1;
    table[0] = -1;
    table[2] = -1;
    if (flag == 0) {
        @memset(field3c[0..16], 0);
        @memset(field44[0..16], 0);
    }
}
fn nativeInitializer() callconv(.c) void {
    reset_calls += 1;
    for (0..4) |i| {
        table[i * 2] = -1;
        active[i] = 0;
        secondary[i] = 0;
    }
}
fn nativeUser0() callconv(.c) void {}
fn nativePoller() callconv(.c) void {}
pub fn begin(s: *o.Scope, _: *const o.Input, storage: ?*anyopaque) callconv(.c) void {
    check(@src(), fence.coherent_frame_open(&token, @intFromPtr(s), o.native_owner_scope_nonce(s), @intFromPtr(&frame), 1, 7, fence.coherent_frame_release()) != 0);
    @as(*align(1) fence.Token, @ptrCast(storage.?)).* = token;
}
pub fn end(_: *o.Scope, _: i32, storage: ?*anyopaque) callconv(.c) void {
    _ = fence.coherent_frame_close(@ptrCast(@alignCast(storage.?)));
}
pub fn reject(_: ?*o.Scope, _: ?*o.Scope, _: i32, _: ?*anyopaque) callconv(.c) void {
    fence.coherent_frame_cancel_atomic(0x20);
}
fn throwing(_: usize) callconv(.c) i32 {
    return user_mapping_owned_request(&request, &outer_key);
}
fn caught() support.ExceptionResult {
    return support.exceptionResult(0, throwing);
}
fn foreign(_: usize) callconv(.winapi) u32 {
    user_mapping_setter_entry(1, 13);
    return 0;
}
fn rootBody(_: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    request = std.mem.zeroes(m.Request);
    request.user = 1;
    request.requested = 13;
    request.saved_negative = -1;
    request.source = .{ .assignment = 19, .epoch = 1, .level = 6, .release = token.release, .owner_nonce = token.owner_nonce, .root_serial = 7, .proof_bytes = @sizeOf(fence.Token), .proof = @splat(0) };
    @memcpy(request.source.proof[0..@sizeOf(fence.Token)], std.mem.asBytes(&token));
    var obs: m.Observation = undefined;
    switch (mode) {
        18 => {
            for (0..64) |i| {
                proof_fail = true;
                check(@src(), user_mapping_owned_request(&request, &outer_key) == 0 and outer_key.id == i + 1);
            }
            const last = outer_key;
            check(@src(), user_mapping_owned_request(&request, &outer_key) == 0 and outer_key.id == 0 and set_calls == 0);
            check(@src(), mapping.user_mapping_inspect(last, &obs) != 0 and obs.disabled != 0);
            return 1;
        },
        8 => {
            proof_raise = true;
            const result = caught();
            check(@src(), result.code == 0xe0011234 and result.last_error == 0x63636363);
            check(@src(), set_calls == 0 and map_calls == 0 and user_mapping_test_marker_empty() != 0);
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.ticket.flags & 128 != 0);
            return 1;
        },
        9 => {
            proof_fail = true;
            check(@src(), user_mapping_owned_request(&request, &outer_key) == 0 and set_calls == 0 and map_calls == 0);
            return 1;
        },
        10 => {
            check(@src(), user_mapping_owned_request(&request, &outer_key) == 0 and set_calls == 0);
            user_mapping_setter_entry(1, 13);
            check(@src(), set_calls == 1 and map_calls == 1);
            return 1;
        },
        11 => {
            request.user = 0;
            check(@src(), user_mapping_owned_request(&request, &outer_key) == 0 and set_calls == 0);
            user_mapping_mapper_entry(-1, 13);
            check(@src(), map_calls == 1);
            return 1;
        },
        13 => user_mapping_test_id(0xfffffffe),
        14 => {
            user_mapping_test_generation(1, 0xffffffff);
            check(@src(), user_mapping_owned_request(&request, &outer_key) != 0 and set_calls == 1 and map_calls == 1);
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.disabled != 0 and obs.quality & 4 == 0);
            return 1;
        },
        7, 12 => {
            const result = caught();
            check(@src(), result.code == 0xe0011234 and result.last_error == (if (mode == 7) @as(u32, 0x77777777) else 0x12121212));
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.ticket.flags & 4 != 0);
            check(@src(), obs.setter_depth == 0 and obs.writer_depth == 0 and table[2] == 12);
            check(@src(), (obs.ticket.flags & 1 != 0) == (mode == 7) and user_mapping_test_marker_empty() != 0);
            return 1;
        },
        else => {},
    }
    check(@src(), user_mapping_owned_request(&request, &outer_key) != 0);
    if (mode == 19) {
        check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.disabled != 0 and obs.quality == 1);
        return 1;
    }
    check(@src(), user_mapping_test_marker_empty() != 0 and mapping.user_mapping_inspect(outer_key, &obs) != 0);
    check(@src(), obs.ticket.key.id == outer_key.id and obs.ticket.actual == 12 and obs.ticket.requested == 13 and obs.ticket.generation == 1 and obs.ticket.flags & 2 != 0);
    check(@src(), obs.setter_depth == 0 and obs.writer_depth == 0 and table[2] == 12);
    if (mode >= 1 and mode <= 5) {
        check(@src(), obs.quality & 2 == 0 and obs.ticket.generation == 1);
        if (mode == 5) check(@src(), mapping.user_mapping_inspect(child_key, &obs) != 0 and obs.quality & 4 != 0);
        return 1;
    }
    check(@src(), obs.quality & 14 == 14);
    switch (mode) {
        0 => {
            user_mapping_mapper_entry(1, -2);
            check(@src(), table[2] == -2 and mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.quality & 2 == 0);
        },
        6 => check(@src(), obs.ticket.flags & 16 != 0 and fence.coherent_frame_valid(&token, 0x3e) == 0),
        13 => {
            user_mapping_reset_01_entry(1);
            var key: m.Key = undefined;
            check(@src(), user_mapping_owned_request(&request, &key) == 0);
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.disabled != 0);
        },
        15 => {
            const thread = CreateThread(0, 0, foreign, 0, 0, null);
            check(@src(), thread != 0 and WaitForSingleObject(thread, 3000) == 0);
            check(@src(), win.CloseHandle(thread) != 0);
            var old: u32 = 0;
            check(@src(), win.VirtualProtect(@intFromPtr(table), 4096, 1, &old) != 0);
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.disabled != 0 and obs.quality == 1);
        },
        16 => {
            mapping.user_mapping_user0_store_event();
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.quality & 4 != 0);
            check(@src(), mapping.user_mapping_retire(outer_key) != 0);
            check(@src(), mapping.user_mapping_inspect(outer_key, &obs) != 0 and obs.quality == 1);
        },
        else => {},
    }
    return 1;
}
pub fn run(choice: u32) i32 {
    mode = choice;
    table = @ptrFromInt(allocate(4096));
    for (0..4) |i| table[i * 2] = -1;
    for (0..32) |i| owners[i * 36] = -1;
    const c: m.Config = .{ .version = 2, .main_thread = win.GetCurrentThreadId(), .native_table = @intFromPtr(table), .native_owners = @intFromPtr(&owners), .original_source_valid = sourceValid, .targets = .{ @intFromPtr(&nativeMapper), @intFromPtr(&nativeSetter), @intFromPtr(&nativeResetAll), @intFromPtr(&nativeReset01), @intFromPtr(&nativeInitializer), @intFromPtr(&nativeUser0), @intFromPtr(&nativeUser0), @intFromPtr(&nativePoller) } };
    check(@src(), mapping.user_mapping_configure(&c) != 0 and mapping.user_mapping_configure(&c) == 0 and mapping.user_mapping_enable() == 0);
    check(@src(), mapping.user_mapping_binding_ready(127) != 0);
    if (mode != 10) check(@src(), mapping.user_mapping_enable() != 0);
    check(@src(), fence.coherent_frame_register_main() != 0);
    const cb: o.Callbacks = .{ .version = 1, .begin = begin, .end = end, .reject = reject };
    check(@src(), o.native_owner_configure(@intFromPtr(&rootBody), &cb) != 0 and native_owner_entry(0) == 1);
    asm volatile ("cld" ::: .{ .cc = true });
    check(@src(), (mode == 19 or user_mapping_test_marker_empty() != 0) and o.native_owner_current() == null);
    return 0;
}
