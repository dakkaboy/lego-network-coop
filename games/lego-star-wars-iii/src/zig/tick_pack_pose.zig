const std = @import("std");
const s = @import("tick_state.zig");
const identity = @import("tick_pack_identity.zig");
const load = s.load;
const store = s.store;
const v = s.site;
fn poseSite(at: u32) bool {
    return at == v.PACK_POSE_QUERY or at == v.PACK_POSE_COMMIT;
}
fn goalSite(at: u32) bool {
    return at == v.PACK_GOAL_MOVE or at == v.PACK_GOAL_ACTIVE;
}
fn validate(values: []const u32, sites: []const u32) bool {
    for (values[1..], sites[1..]) |value, at| if (!s.valid.gateValid(.{ .site = at, .clock = s.clock(), .value = value })) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return false;
    };
    return true;
}
fn canonical(local: []const u32, sites: []const u32, source: []u32) bool {
    @memcpy(source, local);
    if (s.host) return s.capacity(@intCast(local.len), sites[0]);
    const expected = s.expected(local.len) orelse {
        s.fail(2, sites[0], s.clock(), s.firstExpected());
        return false;
    };
    if (expected[0].value != local[0]) {
        s.fail(2, sites[0], s.clock(), s.firstExpected());
        return false;
    }
    if (!s.match(local, sites, 1, true)) return false;
    for (source, expected) |*value, gate| value.* = gate.value;
    return true;
}
pub export fn native_pack_pose(member: usize, at: u32) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (!s.readable(member, 0x80)) return;
    const id = identity.resolve(member, false) orelse return;
    const local = [_]u32{ id.key(), load(u32, member + 0x20), load(u32, member + 0x24), load(u32, member + 0x28), load(u16, member + 0x48) };
    const sites = s.consecutive(5, at, 5);
    var source: [5]u32 = undefined;
    if (!poseSite(at) or (s.host and s.frame.?.tick_gate_count > s.p.SYNC_MAX_TICK_GATES - 5)) {
        s.fail(1, at, s.clock(), s.firstExpected());
        return;
    }
    if (!s.host and s.firstExpected() != null and s.firstExpected().?.site == at and s.firstExpected().?.value != local[0] and s.clonewars_native_tick_failure[0] == 0) {
        const pack = load(usize, member + 0x68);
        s.clonewars_native_tick_failure[8..16].* = .{
            id.index, id.witness, local[0], s.firstExpected().?.value, member, pack,
            if (s.readable(pack, 0xb0)) load(u32, pack + 0xac) else 0,
            if (s.readable(pack, 0x144)) load(u32, pack + 0x13c) else 0,
        };
    }
    if (!canonical(&local, &sites, &source) or !validate(&source, &sites)) return;
    var ignored: [5]u32 = undefined;
    s.run(&local, &sites, &ignored);
    if (!s.host and s.ready()) {
        if (!std.mem.eql(u32, local[1..5], source[1..5]) and s.clonewars_native_pack_pose_correction[0] == 0) s.clonewars_native_pack_pose_correction[0..14].* = .{ s.frame.?.epoch, s.frame.?.sequence, at, s.clock(), id.index, local[1], local[2], local[3], local[4], source[1], source[2], source[3], source[4], id.witness };
        store([3]u32, member + 0x20, source[1..4].*);
        store(u16, member + 0x48, @truncate(source[4]));
    }
}
pub export fn native_pack_pose_query(member: usize) void {
    native_pack_pose(member, v.PACK_POSE_QUERY);
}
pub export fn native_pack_pose_commit(member: usize) void {
    native_pack_pose(member, v.PACK_POSE_COMMIT);
}
pub export fn native_pack_goal_input(member: usize, goal: usize, at: u32) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (!s.readable(member, 0x80)) return;
    const id = identity.resolve(member, false) orelse return;
    if (!goalSite(at) or !s.readable(goal, 0x20)) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return;
    }
    var local = [_]u32{ id.key(), load(u32, member + 0x20), load(u32, member + 0x24), load(u32, member + 0x28), load(u16, member + 0x48), load(u32, goal), load(u32, goal + 4), load(u32, goal + 8), 0, load(u8, goal + 0x1c) & 15 };
    if (local[9] & 1 != 0) local[8] = load(u16, goal + 0x10);
    const sites = s.consecutive(10, at, 1);
    var source: [10]u32 = undefined;
    if (!canonical(&local, &sites, &source) or !validate(&source, &sites)) return;
    if (source[9] & 1 == 0 and source[8] != 0) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return;
    }
    var ignored: [10]u32 = undefined;
    s.run(&local, &sites, &ignored);
    if (!s.ready()) return;
    s.clonewars_native_pack_goal_debug[@intFromBool(!s.host)] +%= 1;
    if (!s.host) {
        const pose_changed = !std.mem.eql(u32, local[1..5], source[1..5]);
        const goal_changed = !std.mem.eql(u32, local[5..10], source[5..10]);
        if ((pose_changed or goal_changed) and s.clonewars_native_pack_goal_first[0] == 0) {
            s.clonewars_native_pack_goal_first[0..6].* = .{ s.frame.?.epoch, s.frame.?.sequence, at, s.clock(), id.index, id.witness };
            s.clonewars_native_pack_goal_first[6..15].* = local[1..10].*;
            s.clonewars_native_pack_goal_first[15..24].* = source[1..10].*;
        }
        s.clonewars_native_pack_goal_debug[2] +%= @intFromBool(pose_changed);
        s.clonewars_native_pack_goal_debug[3] +%= @intFromBool(goal_changed);
        store([3]u32, member + 0x20, source[1..4].*);
        store(u16, member + 0x48, @truncate(source[4]));
        store([3]u32, goal, source[5..8].*);
        if (source[9] & 1 != 0) store(u16, goal + 0x10, @truncate(source[8]));
        store(u8, goal + 0x1c, load(u8, goal + 0x1c) & 0xf0 | @as(u8, @truncate(source[9])));
    }
}
pub export fn native_pack_animation(member: usize, arguments: [*]u32) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (!s.readable(member, 0x88)) return;
    const id = identity.resolve(member, false) orelse return;
    const sites = [_]u32{ v.PACK_ANIMATION_MEMBER, v.PACK_ANIMATION_REQUEST, v.PACK_ANIMATION_STATE, v.PACK_ANIMATION_CLOCK, v.PACK_ANIMATION_DELTA };
    const local = [_]u32{ id.key(), arguments[0], @as(u32, load(u8, member + 0x61)) | @as(u32, load(u8, member + 0x62)) << 8 | @as(u32, @intFromBool(load(u8, member + 0x63) & 0x10 != 0)) << 16, load(u32, member + 0x84), arguments[1] };
    var source: [5]u32 = undefined;
    if (!canonical(&local, &sites, &source)) return;
    const table = load(usize, member + 0x80);
    const requested = source[1];
    const playing = source[2] & 255;
    if (requested > std.math.maxInt(usize) / 20 or table > std.math.maxInt(usize) - requested * 20 or !s.readable(table + requested * 20, 20)) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    if (s.host and requested != playing and load(u8, table + requested * 20 + 0x12) == 0) source[3] = 0;
    if (!@import("tick_clock.zig").finite(source[3]) or !@import("tick_clock.zig").finite(source[4])) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    var ignored: [5]u32 = undefined;
    s.run(if (s.host) &source else &local, &sites, &ignored);
    if (!s.host and s.ready()) {
        arguments[0] = requested;
        arguments[1] = source[4];
        store(u8, member + 0x61, @truncate(playing));
        store(u8, member + 0x62, @truncate(source[2] >> 8));
        store(u8, member + 0x63, load(u8, member + 0x63) & 0xef | @as(u8, @truncate((source[2] >> 12) & 0x10)));
        store(u32, member + 0x84, source[3]);
        if (requested == playing) store(usize, member + 0x10, table + requested * 20);
    }
}
