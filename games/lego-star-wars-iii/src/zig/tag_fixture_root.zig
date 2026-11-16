const std = @import("std");
const s = @import("tag_state.zig");
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
pub const tag_test_api = struct {
    extern var tag_test_clock: s.Clock;
    pub fn readClock() s.Clock {
        return tag_test_clock;
    }
    pub fn writeClock(value: s.Clock) void {
        tag_test_clock = value;
    }
};
extern fn tag_test_original(usize, usize, i32, i32, i32, i32, i32, i32) c_int;
extern fn tag_transfer_hook() void;
export fn tag_fixture_setup() void {
    s.adapter = null;
    s.session_provider = null;
    @import("tag_frame.zig").reset();
    s.initial_control_available = true;
    s.last_authorized_session = 0;
    s.last_authorized_epoch = 0;
    s.active_session = 0;
    s.scope_was_cancelled = false;
    s.cohort_cancelled = false;
    s.bound_session = 0;
    s.controller = null;
    s.actor_update = null;
    s.assignment_version = null;
    s.assignment_remap = null;
    s.original = tag_test_original;
    s.dispatch_revision = 0;
    s.clonewars_tag_debug = @splat(0);
    s.clonewars_tag_identity_debug = @splat(0);
    s.pending = std.mem.zeroes(@TypeOf(s.pending));
    s.provenance = std.mem.zeroes(@TypeOf(s.provenance));
}
export fn tag_fixture_entry() usize {
    return @intFromPtr(&tag_transfer_hook);
}
export fn tag_fixture_pending() [*]s.p.SyncTag {
    return &s.pending;
}
const Metadata = extern struct {
    scope_serial: u64,
    pending_generation: u64,
    binding_serial: u64,
    dispatch_revision: u64,
    epoch: u32,
    next_id: u32,
    last_applied: u32,
    replay_cursor: u32,
    active_event: u32,
    pending_count: u32,
    active_session: u32,
    failed: u32,
    current: u32,
    active: u32,
    frame_complete: u32,
    cohort_bound: u32,
    cohort_cancelled: u32,
    scope_cancelled: u32,
    controller: u32,
    actor_update: u32,
    initial_control_available: u32,
    reserved: u32,
};
export fn tag_fixture_metadata(out: *Metadata) void {
    out.* = .{ .scope_serial = s.scope_serial, .pending_generation = s.pending_generation, .binding_serial = s.binding_serial, .dispatch_revision = s.dispatch_revision, .epoch = s.epoch, .next_id = s.next_id, .last_applied = s.last_applied, .replay_cursor = s.replay_cursor, .active_event = s.active_event, .pending_count = @intCast(s.pending_count), .active_session = s.active_session, .failed = s.failed, .current = @intFromBool(s.current != null), .active = @intFromBool(s.active), .frame_complete = @intFromBool(s.frame_complete), .cohort_bound = @intFromBool(s.cohort_bound), .cohort_cancelled = @intFromBool(s.cohort_cancelled), .scope_cancelled = @intFromBool(s.scope_was_cancelled), .controller = @intFromBool(s.controller != null), .actor_update = @intFromBool(s.actor_update != null), .initial_control_available = @intFromBool(s.initial_control_available), .reserved = 0 };
}
comptime {
    _ = @import("tag_input.zig");
    _ = @import("lexical_seh.zig");
}
