const std = @import("std");
const s = @import("projectile_state.zig");
const constructor = @import("projectile_constructor.zig");
const control = @import("projectile_control.zig");
const observer = @import("constructor_observer.zig");
const query = @import("constructor_query_state.zig");
const checkpoint = @import("constructor_query.zig");
const fence = @import("frame_fence.zig");
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
pub const constructor_query_enabled = true;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var frame: *@import("protocol.zig").SyncFrame = undefined;
var operation: s.t.Operation = undefined;
var object: [0x210]u8 align(16) = @splat(0);
var origin: [3]f32 = .{ 1, 2, 3 };
var transform: [16]f32 = @splat(0);
var weapon: i8 = 7;
const Mode = enum { normal, nested, barrier, exception, retire };
var mode: Mode = .normal;
var depth: u32 = 0;
var calls: u32 = 0;
pub export fn native_owner_scope_valid(owner: usize, nonce: u32) c_int {
    return @intFromBool(owner == 1234 and nonce == 3);
}
pub export fn span_engine_control_get(_: *s.t.Adapter, _: *s.t.ControlLease) c_int {
    return 0;
}
pub export fn span_engine_control_valid(_: *s.t.Adapter, _: *const s.t.ControlLease) c_int {
    return 0;
}
pub export fn entities_observed_generation(_: usize) u32 {
    return 0;
}
pub export fn entities_allocation_live(_: usize, _: u32) c_int {
    return 0;
}
pub export fn entities_observed_identity(_: usize, _: *u32, _: *u32) c_int {
    return 0;
}
pub export fn projectile_create_hook() void {}
fn capture() void {
    var saved: [64]u32 = @splat(0);
    saved[7] = 1;
    var fx: [512]u8 align(16) = @splat(0);
    checkpoint.constructor_query_checkpoint(&saved, &fx);
}
fn create() usize {
    return constructor.create(&operation, 0, 0, @intFromPtr(&origin), @intFromPtr(&transform), @intFromPtr(&weapon), 5, 0, null, 0, 0x4567);
}
fn native(_: usize, _: usize, _: usize, _: usize, _: usize, _: u32, _: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    calls += 1;
    check(@src(), query.active != null and query.depth == depth + 1);
    capture();
    if (depth == 0 and (mode == .nested or mode == .barrier)) {
        depth += 1;
        if (mode == .barrier) observer.clonewars_constructor_observer_enabled = 0;
        check(@src(), create() == @intFromPtr(&object));
        observer.clonewars_constructor_observer_enabled = 1;
        depth -= 1;
        check(@src(), query.depth == 1 and query.active.?.ready == 1);
        capture();
    }
    if (mode == .exception) {
        s.win.SetLastError(717);
        s.win.RaiseException(0xe1234567, 0, 0, null);
    }
    if (mode == .retire) {
        const lease = s.frame_lease;
        check(@src(), control.projectiles_abort_frame(&lease) == 1);
    }
    s.win.SetLastError(716);
    return @intFromPtr(&object);
}
fn guarded(_: usize) callconv(.c) c_int {
    _ = create();
    return 1;
}
comptime {
    _ = @import("lexical_seh.zig");
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) <= 0x869060 and @intFromPtr(&owned_image) + owned_image.len > 0xfb9820);
    frame = @ptrFromInt(s.win.VirtualAlloc(0, @sizeOf(@import("protocol.zig").SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(frame) != 0);
    defer _ = s.win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    var old: u32 = 0;
    check(@src(), s.win.VirtualProtect(0x869060, 5, 0x40, &old) != 0);
    s.win.store(u8, 0x869060, 0xe9);
    s.win.store(u32, 0x869061, @truncate(@intFromPtr(&native) -% 0x869065));
    check(@src(), s.win.VirtualProtect(0x869060, 5, 0x20, &old) != 0);
    _ = s.win.FlushInstructionCache(s.win.GetCurrentProcess(), 0x869060, 5);
    check(@src(), fence.coherent_frame_register_main() == 1);
    s.main_thread = s.win.GetCurrentThreadId();
    observer.clonewars_constructor_observer_installed = 1;
    query.clonewars_constructor_query_installed = 3;
    query.clonewars_constructor_query_enabled = 1;
    for ([_]Mode{ .normal, .nested, .barrier, .exception, .retire }) |scenario| {
        mode = scenario;
        depth = 0;
        calls = 0;
        observer.clonewars_constructor_observer_count = 0;
        observer.clonewars_constructor_observer_enabled = 1;
        query.clonewars_constructor_query_count = 0;
        s.frame_associated = false;
        s.retired_frame_valid = false;
        s.current = null;
        s.frame_bound = false;
        s.binding_cancelled = false;
        frame.* = std.mem.zeroes(@import("protocol.zig").SyncFrame);
        frame.epoch = 7;
        frame.sequence = 2;
        frame.level = 6;
        var token: @import("cohort_types.zig").Token = undefined;
        check(@src(), fence.coherent_frame_open(&token, 1234, 3, @intFromPtr(frame), 7, 2, fence.coherent_frame_release()) == 1);
        check(@src(), control.projectiles_bind_cohort(&token) == 1);
        s.current = frame;
        s.frame_bound = true;
        s.frame_lifecycle = s.lifecycle_serial;
        constructor.close();
        constructor.begin();
        operation = control.capture();
        check(@src(), operation.kind == s.t.keyed and fence.coherent_frame_set_phase(&token, 2) == 1);
        const completed = @import("seh_guard.zig").all(0, guarded);
        check(@src(), query.active == null and query.depth == 0 and query.clonewars_constructor_query_active_scopes == 0);
        if (mode == .exception) {
            check(@src(), completed == 0 and s.win.GetLastError() == 717 and observer.clonewars_constructor_observer_count == 0);
        } else if (mode == .retire) {
            check(@src(), completed == 1 and observer.clonewars_constructor_observer_count == 0);
        } else {
            check(@src(), completed == 1 and s.win.GetLastError() == 716);
            check(@src(), observer.clonewars_constructor_observer_count == @as(u32, if (mode == .nested) 2 else 1));
            check(@src(), query.clonewars_constructor_query_count == @as(u32, if (mode == .normal) 1 else if (mode == .nested) 3 else 2));
            if (mode == .nested) check(@src(), query.clonewars_constructor_query_records[1].constructor_parent_scope == query.clonewars_constructor_query_records[0].constructor_scope);
        }
        constructor.close();
        _ = fence.coherent_frame_close(&token);
    }
}
