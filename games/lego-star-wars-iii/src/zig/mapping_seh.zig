const std = @import("std");
const m = @import("mapping_types.zig");
const root = @import("root");
extern fn tag_lexical_seh(usize, *const fn (usize) callconv(.c) c_int, *const fn (usize, c_int) callconv(.c) void) c_int;
extern fn user_mapping_bridge_begin(*m.Bridge) void;
extern fn user_mapping_bridge_inner(*m.Bridge) void;
extern fn user_mapping_bridge_end(*m.Bridge, c_int) void;
extern fn user_mapping_bridge_unlock(*m.Bridge) void;
extern fn user_mapping_request_begin(*m.Marker, ?*const m.Request, ?*m.Key) void;
extern fn user_mapping_request_end(*m.Marker, c_int) void;
extern fn user_mapping_setter_entry(i32, i32) void;
extern fn user_mapping_session_acquire_begin(*m.Acquire, u32, ?*const m.Request) c_int;
extern fn user_mapping_session_acquire_end(*m.Acquire, c_int) void;
extern fn user_mapping_session_drain_begin(*m.Drain, usize, u32, u32) c_int;
extern fn user_mapping_session_drain_complete(*m.Drain) c_int;
extern fn user_mapping_session_drain_end(*m.Drain, c_int) c_int;
extern fn user_mapping_test_before_negative() void;
fn bridgeInvoke(address: usize) callconv(.c) c_int {
    const b: *m.Bridge = @ptrFromInt(address);
    user_mapping_bridge_begin(b);
    user_mapping_bridge_inner(b);
    return 0;
}
const BridgeEnd = struct { bridge: *m.Bridge, unwind: c_int };
fn bridgeEndInvoke(address: usize) callconv(.c) c_int {
    const context: *BridgeEnd = @ptrFromInt(address);
    user_mapping_bridge_end(context.bridge, context.unwind);
    return 0;
}
fn bridgeUnlock(address: usize, _: c_int) callconv(.c) void {
    const context: *BridgeEnd = @ptrFromInt(address);
    user_mapping_bridge_unlock(context.bridge);
}
fn bridgeLeave(address: usize, completed: c_int) callconv(.c) void {
    var context: BridgeEnd = .{ .bridge = @ptrFromInt(address), .unwind = @intFromBool(completed == 0) };
    _ = tag_lexical_seh(@intFromPtr(&context), bridgeEndInvoke, bridgeUnlock);
}
pub export fn user_mapping_bridge_c(bridge: *m.Bridge) void {
    _ = tag_lexical_seh(@intFromPtr(bridge), bridgeInvoke, bridgeLeave);
}
const Owned = struct { marker: m.Marker = std.mem.zeroes(m.Marker), request: ?*const m.Request, output: ?*m.Key };
fn ownedInvoke(address: usize) callconv(.c) c_int {
    const context: *Owned = @ptrFromInt(address);
    user_mapping_request_begin(&context.marker, context.request, context.output);
    if (context.marker.admitted == 0) return 0;
    const request = context.request.?;
    user_mapping_setter_entry(request.user, request.requested);
    return 1;
}
fn ownedLeave(address: usize, completed: c_int) callconv(.c) void {
    const context: *Owned = @ptrFromInt(address);
    user_mapping_request_end(&context.marker, @intFromBool(completed == 0));
}
pub export fn user_mapping_owned_request(request: ?*const m.Request, output: ?*m.Key) c_int {
    var context: Owned = .{ .request = request, .output = output };
    return tag_lexical_seh(@intFromPtr(&context), ownedInvoke, ownedLeave);
}
const SessionOwned = struct { scope: m.Acquire = std.mem.zeroes(m.Acquire), session: u32, request: ?*const m.Request, output: ?*m.Key };
fn sessionInvoke(address: usize) callconv(.c) c_int {
    const context: *SessionOwned = @ptrFromInt(address);
    if (user_mapping_session_acquire_begin(&context.scope, context.session, context.request) == 0) return 0;
    context.scope.sent = 1;
    return user_mapping_owned_request(context.request, &context.scope.key);
}
fn sessionLeave(address: usize, completed: c_int) callconv(.c) void {
    const context: *SessionOwned = @ptrFromInt(address);
    user_mapping_session_acquire_end(&context.scope, @intFromBool(completed == 0));
    if (completed != 0) if (context.output) |out| {
        out.* = context.scope.key;
    };
}
pub export fn user_mapping_session_owned_request(session: u32, request: ?*const m.Request, output: ?*m.Key) c_int {
    var context: SessionOwned = .{ .session = session, .request = request, .output = output };
    return tag_lexical_seh(@intFromPtr(&context), sessionInvoke, sessionLeave);
}
const Drain = struct { scope: m.Drain = std.mem.zeroes(m.Drain), boundary: usize, length: u32, observed: u32 };
fn drainInvoke(address: usize) callconv(.c) c_int {
    const context: *Drain = @ptrFromInt(address);
    var result = user_mapping_session_drain_begin(&context.scope, context.boundary, context.length, context.observed);
    if (context.scope.consumed != 0) {
        if (comptime @hasDecl(root, "mapping_test_api") and root.mapping_test_api) user_mapping_test_before_negative();
        user_mapping_setter_entry(1, context.scope.negative);
        context.scope.returned = 1;
        result = user_mapping_session_drain_complete(&context.scope);
    }
    return result;
}
fn drainLeave(address: usize, completed: c_int) callconv(.c) void {
    const context: *Drain = @ptrFromInt(address);
    _ = user_mapping_session_drain_end(&context.scope, @intFromBool(completed == 0));
}
pub export fn user_mapping_session_drain(boundary: usize, length: u32, observed: u32) c_int {
    var context: Drain = .{ .boundary = boundary, .length = length, .observed = observed };
    return tag_lexical_seh(@intFromPtr(&context), drainInvoke, drainLeave);
}
