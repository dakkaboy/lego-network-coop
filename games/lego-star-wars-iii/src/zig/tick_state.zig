const std = @import("std");
pub const p = @import("protocol.zig");
pub const site = @import("tick_sites.zig");
pub const win = @import("win32.zig");
pub const valid = @import("tick_validation.zig");
pub const Token = @import("cohort_types.zig").Token;
pub var frame: ?*p.SyncFrame = null;
pub var token = std.mem.zeroes(Token);
pub var cursor: u32 = 0;
pub var early_rts_wait: ?u32 = null;
pub var active = false;
pub var host = false;
pub var failed = false;
pub export var clonewars_native_tick_debug: [4]u32 = @splat(0);
pub export var clonewars_native_tick_failure: [16]u32 = @splat(0);
pub export var clonewars_native_tick_failure_stack: [33]usize = @splat(0);
pub export var clonewars_native_pack_seed_context: [16]u32 = @splat(0);
pub export var clonewars_native_pack_hit_caller: [8]u32 = @splat(0);
extern "kernel32" fn RtlCaptureStackBackTrace(u32, u32, [*]usize, ?*u32) callconv(.winapi) u16;
pub export var clonewars_native_tick_correction: [6]u32 = @splat(0);
pub export var clonewars_native_pack_pose_correction: [16]u32 = @splat(0);
pub export var clonewars_native_pack_goal_debug: [4]u32 = @splat(0);
pub export var clonewars_native_pack_goal_first: [32]u32 = @splat(0);
pub export var clonewars_native_pack_cell_correction: [8]u32 = @splat(0);
pub export var clonewars_native_pack_hit_correction: [8]u32 = @splat(0);
pub export var clonewars_native_pack_death_input_debug: [4]u32 = @splat(0);
pub export var clonewars_native_pack_avoidance_debug: [4]u32 = @splat(0);
pub export var clonewars_native_pack_mode10_rng_debug: [4]u32 = @splat(0);
pub export var clonewars_native_rts_heading_debug: [4]u32 = @splat(0);
pub export var clonewars_native_rts_turn_debug: [4]u32 = @splat(0);
pub export var clonewars_native_actor_turn_debug: [4]u32 = @splat(0);
pub export var clonewars_native_elapsed_debug: [4]u32 = @splat(0);
pub export var clonewars_native_pickup_render_debug: [4]u32 = @splat(0);
pub export var clonewars_native_global_pack_debug: [4]u32 = @splat(0);
pub export var clonewars_native_weapon_command_correction: [8]u32 = @splat(0);
pub export var clonewars_native_clock_debug: [4]u32 = @splat(0);
pub export var clonewars_native_clock_correction: [10]u32 = @splat(0);
pub export var clonewars_native_rts_wait_rng_debug: [4]u32 = @splat(0);
pub export var clonewars_native_rts_wait_reorders: u32 = 0;
pub extern fn world_vars_cohort_valid(*const Token, u32) c_int;
pub extern fn game_sync_native_fault(c_int) void;
pub extern fn entities_slot(usize) c_int;
pub extern fn entities_generation(usize) u32;
pub extern fn entities_bind_native_actor(*const p.SyncFrame, usize) c_int;
pub extern fn lan_status() c_long;
pub extern fn game_sync_status() c_int;
pub extern fn game_sync_epoch() u32;
pub extern fn game_sync_preload_level() c_int;
pub extern fn game_sync_preload_track_input(?*const [2]u32, u32) u32;
pub extern fn game_sync_preload_flow_input(usize, u32) u32;
pub const load = win.load;
pub const store = win.store;
pub fn live(phases: u32) bool {
    return active and frame != null and token.frame == @intFromPtr(frame.?) and world_vars_cohort_valid(&token, phases) != 0;
}
pub fn ready() bool {
    return live(4) and !failed;
}
pub fn readable(address: usize, bytes: usize) bool {
    return @import("page_access.zig").readable(address, bytes);
}
pub fn clock() u32 {
    return load(u32, 0xfb4b6c);
}
pub fn expected(count: usize) ?[]const p.SyncTickGate {
    const f = frame orelse return null;
    return if (cursor <= f.tick_gate_count and count <= f.tick_gate_count - cursor) f.tick_gates[cursor..][0..count] else null;
}
pub fn fail(reason: u32, at: u32, time: u32, source: ?*const p.SyncTickGate) void {
    if (!live(0x3e)) return;
    failed = true;
    if (clonewars_native_tick_failure[0] == 0) {
        clonewars_native_tick_failure[0..8].* = .{ frame.?.epoch, frame.?.sequence, cursor, reason, at, if (source) |v| v.site else 0, time, if (source) |v| v.clock else 0 };
        clonewars_native_tick_failure_stack[0] = RtlCaptureStackBackTrace(0, 32, @ptrCast(&clonewars_native_tick_failure_stack[1]), null);
    }
    clonewars_native_tick_debug[3] +%= 1;
    game_sync_native_fault(22);
}
pub fn firstExpected() ?*const p.SyncTickGate {
    const e = expected(1) orelse return null;
    return &e[0];
}
pub export fn native_tick_decision(at: u32, local: u32) u32 {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (!ready()) return local;
    const time = clock();
    const f = frame.?;
    if (host) {
        if (f.tick_gate_count >= p.SYNC_MAX_TICK_GATES) fail(1, at, time, null) else {
            f.tick_gates[f.tick_gate_count] = .{ .site = at, .clock = time, .value = local };
            f.tick_gate_count += 1;
            clonewars_native_tick_debug[0] +%= 1;
        }
        return local;
    }
    const e = firstExpected();
    if (e == null or !valid.gateValid(e.?.*) or e.?.site != at or e.?.clock != time) {
        fail(2, at, time, e);
        return local;
    }
    cursor += 1;
    clonewars_native_tick_debug[1] +%= 1;
    const result = e.?.value;
    if (result != local) {
        clonewars_native_tick_debug[2] +%= 1;
        if (clonewars_native_tick_correction[0] == 0) clonewars_native_tick_correction = .{ f.epoch, f.sequence, at, time, local, result };
    }
    return result;
}
pub const decision = native_tick_decision;
pub fn capacity(count: u32, at: u32) bool {
    if (frame.?.tick_gate_count > @as(u32, p.SYNC_MAX_TICK_GATES) - count) {
        fail(1, at, clock(), null);
        return false;
    }
    return true;
}
pub fn match(values: []const u32, sites: []const u32, identities: usize, validate: bool) bool {
    const e = expected(values.len) orelse {
        fail(2, sites[0], clock(), firstExpected());
        return false;
    };
    for (e, sites, values, 0..) |g, at, value, i| if (g.site != at or g.clock != clock() or (validate and !valid.gateValid(g)) or (i < identities and g.value != value)) {
        fail(2, sites[0], clock(), firstExpected());
        return false;
    };
    return true;
}
pub fn run(values: []const u32, sites: []const u32, out: []u32) void {
    for (values, sites, out) |v, at, *result| result.* = decision(at, v);
}
pub fn consecutive(comptime count: usize, first: u32, stride: u32) [count]u32 {
    var out: [count]u32 = undefined;
    for (&out, 0..) |*v, i| v.* = first + @as(u32, @intCast(i)) * stride;
    return out;
}
