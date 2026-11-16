const std = @import("std");
const abi = @import("abi.zig");
const c = abi.c;
const Context = c.ProfileBootstrapContext;
const Host = c.ProfileBootstrapHostState;
const Client = c.ProfileBootstrapClientState;
const Profile = c.SyncProfile;
const trace = @import("trace.zig");
const profiler = @import("profiler.zig");

fn same(a: Context, b: Context) bool {
    return a.session == b.session and a.epoch == b.epoch and a.level == b.level;
}

fn bound(current: Context, context: ?*const Context) bool {
    return profile_bootstrap_context_valid(context) != 0 and
        profile_bootstrap_context_valid(&current) != 0 and same(current, context.?.*);
}

fn nativeData(data: ?*const anyopaque, size: usize) ?[]const u8 {
    if (data == null or size != c.SYNC_PROFILE_BYTES) return null;
    const bytes = @as([*]const u8, @ptrCast(data.?))[0..size];
    return if (std.mem.readInt(u32, bytes[0..4], .little) == 0x500) bytes else null;
}

export fn profile_bootstrap_context_valid(context: ?*const Context) c_int {
    const v = context orelse return 0;
    return @intFromBool(v.session != 0 and v.session != std.math.maxInt(u32) and v.epoch != 0 and abi.validLevel(v.level));
}

export fn profile_bootstrap_profile_valid(profile: ?*const Profile, context: ?*const Context) c_int {
    const p = profile orelse return 0;
    if (profile_bootstrap_context_valid(context) == 0 or p.epoch != context.?.epoch or p.level != context.?.level) return 0;
    const bytes = nativeData(&p.data, p.data.len) orelse return 0;
    return @intFromBool(p.checksum == abi.checksum(bytes));
}

export fn profile_bootstrap_host_reset(state: ?*Host) void {
    if (state) |s| @memset(std.mem.asBytes(s), 0);
}

export fn profile_bootstrap_host_bind(state: ?*Host, context: ?*const Context) c_int {
    const s = state orelse return 0;
    if (profile_bootstrap_context_valid(context) == 0) return 0;
    const next = context.?.*;
    if (!same(s.context, next)) {
        profile_bootstrap_host_reset(s);
        s.context = next;
    }
    return 1;
}

export fn profile_bootstrap_host_capture(state: ?*Host, context: ?*const Context, data: ?*const anyopaque, size: usize, sequence: u32) c_int {
    const zone = profiler.zone(@src(), "profile.capture");
    defer zone.end();
    const s = state orelse return 0;
    if (!bound(s.context, context)) return 0;
    const bytes = nativeData(data, size) orelse return 0;
    if (s.captured != 0) return @intFromBool(s.captured == 1 and profile_bootstrap_profile_valid(&s.initial, context) != 0 and
        s.initial.sequence == sequence and std.mem.eql(u8, &s.initial.data, bytes));
    var candidate = std.mem.zeroes(Profile);
    candidate.epoch = context.?.epoch;
    candidate.sequence = sequence;
    candidate.level = context.?.level;
    @memcpy(&candidate.data, bytes);
    candidate.checksum = abi.checksum(&candidate.data);
    s.initial = candidate;
    s.captured = 1;
    trace.record(.profile, s.context.epoch, sequence, 1, s.context.session, candidate.checksum, @bitCast(s.context.level));
    return 1;
}

export fn profile_bootstrap_host_initial(state: ?*const Host, context: ?*const Context) ?*const Profile {
    const s = state orelse return null;
    return if (s.captured == 1 and bound(s.context, context) and profile_bootstrap_profile_valid(&s.initial, context) != 0) &s.initial else null;
}

export fn profile_bootstrap_client_reset(state: ?*Client) void {
    if (state) |s| @memset(std.mem.asBytes(s), 0);
}

export fn profile_bootstrap_client_bind(state: ?*Client, context: ?*const Context) c_int {
    const s = state orelse return 0;
    if (profile_bootstrap_context_valid(context) == 0) return 0;
    const next = context.?.*;
    if (!same(s.context, next)) {
        profile_bootstrap_client_reset(s);
        s.context = next;
    }
    return 1;
}

export fn profile_bootstrap_client_should_apply(state: ?*const Client, context: ?*const Context, sealed: c_int) c_int {
    const s = state orelse return 0;
    return @intFromBool(bound(s.context, context) and s.applied <= 1 and (sealed != 0 or s.applied == 0));
}

export fn profile_bootstrap_client_is_applied(state: ?*const Client, context: ?*const Context) c_int {
    const s = state orelse return 0;
    return @intFromBool(bound(s.context, context) and s.applied == 1);
}

export fn profile_bootstrap_client_accepts_packet(state: ?*const Client, context: ?*const Context, profile: ?*const Profile, sealed: c_int) c_int {
    const s = state orelse return 0;
    if (!bound(s.context, context) or s.applied > 1 or profile_bootstrap_profile_valid(profile, context) == 0) return 0;
    return @intFromBool(if (s.applied == 0) profile.?.sequence == 0 else sealed != 0 and profile.?.sequence > 0);
}

export fn profile_bootstrap_client_mark_applied(state: ?*Client, context: ?*const Context) c_int {
    const s = state orelse return 0;
    if (!bound(s.context, context) or s.applied > 1) return 0;
    s.applied = 1;
    trace.record(.profile, s.context.epoch, 0, 2, s.context.session, 0, @bitCast(s.context.level));
    return 1;
}
