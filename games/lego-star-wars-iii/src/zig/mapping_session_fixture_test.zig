const std = @import("std");
const win = @import("win32.zig");
const owner = @import("owner.zig");
const fence = @import("frame_fence.zig");
const m = @import("mapping_types.zig");
const observer = @import("mapping_observer.zig");
const session = @import("mapping_session.zig");
const install = @import("mapping_install.zig");
const contract = @import("mapping_contract.zig");
const support = @import("native_test_support.zig");
const check = support.check;
const Boundary = @import("sync_boundary.zig").Boundary;
pub const panic = @import("safety.zig").panic;
pub const mapping_test_api = true;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
const State = struct {
    pub const win = @import("win32.zig");
    pub const api = struct {
        pub const coherent_frame_release = fence.coherent_frame_release;
        pub const native_owner_current = owner.native_owner_current;
        pub const native_owner_scope_valid = owner.native_owner_scope_valid;
    };
    pub var core: struct { opened: u32 = 0 } = .{};
    pub var window_thread: u32 = 0;
    pub var main_boundary: Boundary = undefined;
    pub var main_boundary_active = false;
    pub var main_boundary_serial: u32 = 0;
};
const boundary = @import("sync_boundary.zig").Authority(State);
var old_frame: usize = 0;
var frame_token: fence.Token = undefined;
var lane: u32 = 1;
var mode: u32 = 0;
var root_round: u32 = 0;
var key: m.Key = undefined;
var device_state: usize = 0;
var failed_protect: u32 = 0;
var failed_protect_second: u32 = 0;
var protect_calls: u32 = 0;
var failed_flush: u32 = 0;
var flush_calls: u32 = 0;
var listener_calls: u32 = 0;
var callback_boundary: Boundary = undefined;
var exception_boundary: Boundary = undefined;
var at_gate: usize = 0;
var worker_done: usize = 0;
var worker: usize = 0;
var owned_image: usize = 0;
export var native_store_address: usize = 0;
extern fn user_mapping_test_slab() usize;
extern fn user_mapping_test_entry_count(u32) u32;
extern fn user_mapping_test_marker_empty() i32;
extern fn user_mapping_setter_entry(i32, i32) void;
extern fn user_mapping_session_owned_request(u32, *const m.Request, *m.Key) i32;
extern fn user_mapping_session_drain(usize, u32, u32) i32;
extern fn native_owner_entry(usize) callconv(.{ .x86_thiscall = .{} }) u32;
extern fn invoke_native_user0_store() void;
extern "kernel32" fn CreateThread(usize, usize, *const fn (usize) callconv(.winapi) u32, usize, u32, ?*u32) callconv(.winapi) usize;
extern "kernel32" fn CreateEventA(usize, i32, i32, ?[*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn SetEvent(usize) callconv(.winapi) i32;
extern "kernel32" fn WaitForSingleObject(usize, u32) callconv(.winapi) u32;
fn n(address: usize) usize {
    return owned_image + address - 0x400000;
}
fn bytes(address: usize, size: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..size];
}
fn copy(address: usize, value: []const u8) void {
    @memcpy(bytes(address, value.len), value);
}
fn jump(from: usize, to: usize) void {
    win.store(u8, from, 0xe9);
    win.store(u32, from + 1, to -% from -% 5);
}
fn nativeVoid(address: usize) void {
    const call: *const fn () callconv(.c) void = @ptrFromInt(n(address));
    call();
}
fn drain(b: *const Boundary) i32 {
    return user_mapping_session_drain(@intFromPtr(b), @sizeOf(Boundary), 2);
}
fn sourceValid(raw: usize, size: u32) callconv(.c) i32 {
    return if (size == @sizeOf(Boundary)) boundary.valid(raw, size, 0) else @intFromBool(size == @sizeOf(fence.Token) and fence.coherent_frame_valid(@ptrFromInt(raw), 0x3e) != 0);
}
fn installAllowed(user: usize) callconv(.c) i32 {
    return boundary.valid(@intFromPtr(&State.main_boundary), @sizeOf(Boundary), user);
}
fn sessionSerial(_: usize) callconv(.c) u32 {
    return @atomicLoad(u32, &lane, .seq_cst);
}
pub export fn user_mapping_test_image_base() usize {
    return owned_image;
}
pub export fn user_mapping_test_protect(p: usize, size: usize, protection: u32, out: *u32) i32 {
    protect_calls += 1;
    if ((failed_protect != 0 and protect_calls == failed_protect) or (failed_protect_second != 0 and protect_calls == failed_protect_second)) return 0;
    return win.VirtualProtect(p, size, protection, out);
}
pub export fn user_mapping_test_flush(process: usize, p: usize, size: usize) i32 {
    flush_calls += 1;
    return if (failed_flush != 0 and flush_calls == failed_flush) 0 else win.FlushInstructionCache(process, p, size);
}
fn pollerBody() callconv(.c) void {
    if (mode == 11) check(@src(), drain(&callback_boundary) == 2);
    win.store(i32, n(0xead92c) + 12 * 0x90, 0);
    invoke_native_user0_store();
    check(@src(), win.load(i32, n(0xeb1a70)) == 12);
}
fn activationListener(_: usize, _: usize, event: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), event != 0);
    listener_calls += 1;
    check(@src(), session.user_mapping_session_retire(1, 4) != 0);
    @atomicStore(u32, &lane, 2, .seq_cst);
    check(@src(), session.user_mapping_session_begin(2) != 0 and boundary.get(&callback_boundary) != 0 and drain(&callback_boundary) == 2);
}
var listener_vtable: [2]usize = @splat(0);
var listener_object: [1]usize = @splat(0);
var listener_node: [3]usize = @splat(0);
fn memset(raw: usize, value: i32, count: usize) callconv(.c) usize {
    @memset(bytes(raw, count), @truncate(@as(u32, @bitCast(value))));
    return raw;
}
fn validateContract() void {
    var hash: u32 = 2166136261;
    for (contract.bodies) |body| {
        const address: u32 = @intCast(body.address);
        for (std.mem.asBytes(&address)) |byte| hash = (hash ^ byte) *% 16777619;
        for (body.bytes) |byte| hash = (hash ^ byte) *% 16777619;
    }
    for (contract.relocations) |raw| {
        const address: u32 = @intCast(raw);
        for (std.mem.asBytes(&address)) |byte| hash = (hash ^ byte) *% 16777619;
    }
    check(@src(), hash == 2097885874);
}
fn relocate(first: usize, limit: usize) void {
    for (contract.relocations) |address| if (address >= first and address + 4 <= limit) win.store(u32, n(address), win.load(u32, n(address)) +% @as(u32, @truncate(owned_image -% 0x400000)));
}
fn setupNative() void {
    validateContract();
    owned_image = win.VirtualAlloc(0, 0xc00000, 0x3000, 0x40);
    check(@src(), owned_image != 0);
    for (contract.bodies) |body| copy(n(body.address), body.bytes);
    relocate(0x400000, 0x1000000);
    jump(n(0xa60fc0), @intFromPtr(&memset));
    var store = [_]u8{ 0x89, 0x15, 0x70, 0x1a, 0xeb, 0, 0xc3 };
    std.mem.writeInt(u32, store[2..6], n(0xeb1a70), .little);
    copy(n(0x58988f), &store);
    copy(n(0x5898e1), &store);
    var poller = [_]u8{ 0x6a, 0xff, 0x68, 0x68, 0x12, 0xaa, 0, 0x83, 0xc4, 8 };
    std.mem.writeInt(u32, poller[3..7], n(0xaa1268), .little);
    copy(n(0x589660), &poller);
    jump(n(0x58966a), @intFromPtr(&pollerBody));
    native_store_address = n(0x58988f);
    device_state = win.VirtualAlloc(0, 0x7000, 0x3000, 4);
    check(@src(), device_state != 0);
    win.store(usize, n(0xf909ac), device_state);
    win.store(i32, device_state + 0x6610, 1);
    nativeVoid(0x57b2a0);
    if (mode == 12) {
        listener_vtable[1] = @intFromPtr(&activationListener);
        listener_object[0] = @intFromPtr(&listener_vtable);
        listener_node = .{ 0, @intFromPtr(&listener_object), 0 };
        win.store(usize, n(0xeb0e98), @intFromPtr(&listener_node));
    }
    for ([_]usize{ 0x57b000, 0x582000, 0x589000, 0xab6000 }) |address| {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(n(address), 4096, 0x20, &old) != 0);
    }
}
fn begin(s: *owner.Scope, _: *const owner.Input, _: ?*anyopaque) callconv(.c) void {
    State.window_thread = win.GetCurrentThreadId();
    State.core.opened = 0;
    State.main_boundary_active = true;
    State.main_boundary_serial += 1;
    State.main_boundary = .{ .owner = s, .owner_nonce = owner.native_owner_scope_nonce(s), .thread = State.window_thread, .release = fence.coherent_frame_release(), .boundary_serial = State.main_boundary_serial };
}
fn end(_: *owner.Scope, _: i32, _: ?*anyopaque) callconv(.c) void {
    State.main_boundary_active = false;
}
fn reject(_: ?*owner.Scope, _: ?*owner.Scope, _: i32, _: ?*anyopaque) callconv(.c) void {
    fence.coherent_frame_cancel_atomic(0x20);
}
fn makeRequest(proof: anytype, serial: u32) m.Request {
    var r = std.mem.zeroes(m.Request);
    r.user = 1;
    r.requested = 13;
    r.saved_negative = -1;
    r.source.assignment = 19;
    r.source.epoch = 1;
    r.source.level = 6;
    r.source.release = proof.release;
    r.source.owner_nonce = proof.owner_nonce;
    r.source.root_serial = serial;
    r.source.proof_bytes = @sizeOf(@TypeOf(proof.*));
    @memcpy(r.source.proof[0..r.source.proof_bytes], std.mem.asBytes(proof));
    return r;
}
fn createMapping() void {
    if (mode == 7 or mode == 12) {
        var b: Boundary = undefined;
        check(@src(), boundary.get(&b) != 0);
        const r = makeRequest(&b, b.boundary_serial);
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(old_frame, 4096, 1, &old) != 0);
        check(@src(), user_mapping_session_owned_request(1, &r, &key) != 0);
        return;
    }
    win.store(u32, old_frame, 1);
    win.store(u32, old_frame + 4, 7);
    const s = owner.native_owner_current().?;
    check(@src(), fence.coherent_frame_open(&frame_token, @intFromPtr(s), owner.native_owner_scope_nonce(s), old_frame, 1, 7, fence.coherent_frame_release()) != 0);
    State.core.opened = 1;
    const r = makeRequest(&frame_token, State.main_boundary_serial);
    check(@src(), user_mapping_session_owned_request(1, &r, &key) != 0);
    check(@src(), fence.coherent_frame_close(&frame_token) != 0);
    State.core.opened = 0;
    check(@src(), win.load(i32, n(0xeb1a78)) == 12 and win.load(i32, n(0xead92c) + 12 * 0x90) == 1 and win.load(u8, n(0xeb1a7c)) == 1 and win.load(u16, n(0xcef69a)) == 13);
}
fn throwing(_: usize) callconv(.c) i32 {
    return drain(&exception_boundary);
}
fn negativeRaise(user: i32, _: i32) callconv(.c) void {
    check(@src(), user < 0);
    win.SetLastError(0x81818181);
    win.RaiseException(0xe0011234, 0, 0, null);
}
fn foreignSetter(_: usize) callconv(.winapi) u32 {
    user_mapping_setter_entry(1, 13);
    _ = SetEvent(worker_done);
    return 0;
}
pub export fn user_mapping_test_admission_wait(site: u32) void {
    if (mode == 6 and site == 1 and win.GetCurrentThreadId() != State.window_thread) _ = SetEvent(at_gate);
}
pub export fn user_mapping_test_before_negative() void {
    if (mode == 8) jump(n(0x63a940), @intFromPtr(&negativeRaise));
    if (mode == 6) {
        at_gate = CreateEventA(0, 1, 0, null);
        worker_done = CreateEventA(0, 1, 0, null);
        worker = CreateThread(0, 0, foreignSetter, 0, 0, null);
        check(@src(), worker != 0 and WaitForSingleObject(at_gate, 3000) == 0 and WaitForSingleObject(worker_done, 0) == 258);
    }
}
fn faultInstall(config: *const m.InstallConfig) void {
    if (mode == 28) {
        failed_protect = 3;
        failed_protect_second = 4;
    } else if (mode >= 30) failed_flush = mode - 29 else failed_protect = mode - 19;
    const sites = [_]usize{ 0x57b1a0, 0x582da0, 0x57b2a0, 0x57b530, 0xab67f0, 0x58988f, 0x5898e1, 0x589660 };
    const lengths = [_]usize{ 5, 5, 5, 5, 5, 6, 6, 7 };
    var before: [8][7]u8 = undefined;
    for (sites, lengths, 0..) |address, len, i| @memcpy(before[i][0..len], bytes(n(address), len));
    check(@src(), install.user_mapping_install_safe(config) == 0 and install.user_mapping_install_ready() == 0);
    if (mode == 28) {
        check(@src(), install.clonewars_user_mapping_installed == -1 and user_mapping_test_slab() == 0);
        for (sites, lengths, 0..) |address, len, i| check(@src(), std.mem.eql(u8, before[i][0..len], bytes(n(address), len)));
    } else if (failed_flush != 0 or failed_protect > 4) {
        check(@src(), install.clonewars_user_mapping_installed == -1 and observer.user_mapping_enable() == 0);
        var info: win.MemoryInfo = undefined;
        check(@src(), user_mapping_test_slab() != 0 and win.VirtualQuery(user_mapping_test_slab(), &info, @sizeOf(win.MemoryInfo)) != 0 and info.state == 0x1000);
        for (sites) |address| check(@src(), win.load(u8, n(address)) == 0xe9);
        const before_calls = protect_calls;
        check(@src(), install.user_mapping_install_safe(config) == 0 and protect_calls == before_calls);
    } else for (sites, lengths, 0..) |address, len, i| {
        check(@src(), std.mem.eql(u8, before[i][0..len], bytes(n(address), len)));
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(n(address), &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
}
fn rootBody(_: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    if (root_round == 0) {
        const config: m.InstallConfig = .{ .main_thread = State.window_thread, .original_source_valid = sourceValid, .install_allowed = installAllowed, .user = 0 };
        if (mode >= 20) {
            faultInstall(&config);
            return 1;
        }
        check(@src(), install.user_mapping_install_safe(&config) != 0 and install.user_mapping_install_ready() != 0);
        const c: m.SessionConfig = .{ .version = 1, .main_thread = State.window_thread, .safe_main_valid = boundary.valid, .current_session = sessionSerial, .user = 0 };
        check(@src(), session.user_mapping_session_configure(&c) != 0 and session.user_mapping_session_begin(1) != 0);
        createMapping();
    }
    if (mode == 12 and root_round == 0) return 1;
    var obs: m.Observation = undefined;
    if (root_round == 0) check(@src(), session.user_mapping_session_device_get(1, &obs) != 0 and session.user_mapping_session_pending() == 0);
    if (mode == 3) {
        win.store(u32, old_frame, 77);
        check(@src(), session.user_mapping_session_begin(1) != 0 and session.user_mapping_session_device_get(1, &obs) != 0);
        return 1;
    }
    if (mode == 11) {
        check(@src(), session.user_mapping_session_retire(1, 8) != 0);
        @atomicStore(u32, &lane, 2, .seq_cst);
        check(@src(), session.user_mapping_session_begin(2) != 0 and boundary.get(&callback_boundary) != 0);
        nativeVoid(0x589660);
        check(@src(), drain(&callback_boundary) == 3 and user_mapping_test_entry_count(1) == 1);
        return 1;
    }
    if (mode == 1) user_mapping_setter_entry(1, 13);
    if (mode == 2) nativeVoid(0x589660);
    if (mode == 5) {
        worker_done = CreateEventA(0, 1, 0, null);
        worker = CreateThread(0, 0, foreignSetter, 0, 0, null);
        check(@src(), worker != 0 and WaitForSingleObject(worker, 3000) == 0);
        check(@src(), win.CloseHandle(worker) != 0);
    }
    check(@src(), session.user_mapping_session_retire(1, 2) != 0);
    @atomicStore(u32, &lane, 2, .seq_cst);
    check(@src(), session.user_mapping_session_begin(2) != 0 and session.user_mapping_session_pending() != 0);
    var b: Boundary = undefined;
    check(@src(), boundary.get(&b) != 0);
    if (mode == 4 and root_round == 0) {
        fence.coherent_frame_cancel_atomic(0x40);
        check(@src(), drain(&b) == 2);
        return 1;
    }
    if (mode == 8) {
        exception_boundary = b;
        const caught = support.exceptionResult(0, throwing);
        check(@src(), caught.code == 0xe0011234 and caught.last_error == 0x81818181);
        check(@src(), user_mapping_test_entry_count(1) == 2 and drain(&b) == 4 and user_mapping_test_entry_count(1) == 2);
        for (contract.bodies) |body| if (body.address == 0x63a940) copy(n(body.address), body.bytes);
        relocate(0x63a940, 0x63a972);
        worker_done = CreateEventA(0, 1, 0, null);
        worker = CreateThread(0, 0, foreignSetter, 0, 0, null);
        check(@src(), worker != 0 and WaitForSingleObject(worker, 3000) == 0);
        check(@src(), win.CloseHandle(worker) != 0);
        return 1;
    }
    if (mode == 9) {
        const p = n(0x57b1a0);
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(p, 5, 0x40, &old) != 0);
        const saved = win.load(u8, p + 1);
        win.store(u8, p + 1, saved ^ 1);
        check(@src(), install.user_mapping_install_ready() == 0 and drain(&b) == 2 and user_mapping_test_entry_count(1) == 1);
        win.store(u8, p + 1, saved);
        var ignored: u32 = 0;
        check(@src(), win.VirtualProtect(p, 5, old, &ignored) != 0);
    }
    if (mode == 10) {
        const p = n(0x63a940);
        const saved = win.load(u8, p);
        win.store(u8, p, saved ^ 1);
        check(@src(), install.user_mapping_install_ready() == 0 and drain(&b) == 2 and user_mapping_test_entry_count(1) == 1);
        win.store(u8, p, saved);
    }
    const result = drain(&b);
    switch (mode) {
        1, 2 => {
            check(@src(), result == 3 and win.load(i32, n(0xeb1a78)) == 12);
            return 1;
        },
        5 => {
            check(@src(), result == 4 and win.load(i32, n(0xeb1a78)) == 12);
            return 1;
        },
        6 => {
            check(@src(), result == 6 and WaitForSingleObject(worker, 3000) == 0);
            check(@src(), win.CloseHandle(worker) != 0 and win.load(i32, n(0xeb1a78)) == 12);
            return 1;
        },
        else => {},
    }
    check(@src(), result == 1 and win.load(i32, n(0xeb1a78)) == -1 and win.load(i32, n(0xead92c) + 12 * 0x90) == -1);
    check(@src(), win.load(u8, n(0xeb1a7c)) == 0 and win.load(u8, n(0xeb1a7d)) == 0 and win.load(u16, n(0xcef69a)) == 0xffff and win.load(u8, device_state + 0x634d + 12) == 5);
    check(@src(), user_mapping_test_entry_count(1) == 2 and session.user_mapping_session_pending() == 0 and drain(&b) == 0 and user_mapping_test_entry_count(1) == 2);
    return 1;
}
pub export fn run_session_fixture(choice: u32) i32 {
    mode = choice;
    setupNative();
    old_frame = win.VirtualAlloc(0, 4096, 0x3000, 4);
    check(@src(), old_frame != 0 and fence.coherent_frame_register_main() != 0);
    const cb: owner.Callbacks = .{ .version = 1, .begin = begin, .end = end, .reject = reject };
    check(@src(), owner.native_owner_configure(@intFromPtr(&rootBody), &cb) != 0 and native_owner_entry(0) == 1);
    if (mode == 12) {
        root_round = 1;
        check(@src(), native_owner_entry(0) == 1 and listener_calls == 1);
    }
    if (mode == 4) {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(old_frame, 4096, 1, &old) != 0);
        root_round = 1;
        check(@src(), native_owner_entry(0) == 1);
    }
    check(@src(), user_mapping_test_marker_empty() != 0);
    return 0;
}
comptime {
    _ = @import("mapping_fixture_runtime.zig");
    asm (
        \\.text
        \\_invoke_native_user0_store:
        \\pushfl
        \\pushal
        \\movl $12,%edx
        \\movl _native_store_address,%eax
        \\call *%eax
        \\popal
        \\popfl
        \\ret
    );
}
