const std = @import("std");
const a = @import("abi.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("profile.zig");
}
fn same(left: anytype, right: anytype) bool {
    return std.mem.eql(u8, std.mem.asBytes(left), std.mem.asBytes(right));
}
fn nativeChecksum(bytes: []const u8) u32 {
    var result: u32 = 2166136261;
    for (bytes) |byte| result = (result ^ byte) *% 16777619;
    return result;
}
fn makeData(bytes: []u8, salt: u32) void {
    for (bytes, 0..) |*byte, i| byte.* = @truncate((i * 37 + salt) ^ (i >> 7));
    std.mem.writeInt(u32, bytes[0..4], 0x500, .little);
}
fn context_valid(context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_context_valid(context) != 0;
}
fn profile_valid(profile: ?*const a.SyncProfile, context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_profile_valid(profile, context) != 0;
}
fn host_bind(state: ?*a.ProfileBootstrapHostState, context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_host_bind(state, context) != 0;
}
fn host_capture(state: ?*a.ProfileBootstrapHostState, context: ?*const a.ProfileBootstrapContext, data: ?*const anyopaque, size: usize, sequence: u32) bool {
    return a.profile_bootstrap_host_capture(state, context, data, size, sequence) != 0;
}
fn client_bind(state: ?*a.ProfileBootstrapClientState, context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_client_bind(state, context) != 0;
}
fn client_should_apply(state: ?*const a.ProfileBootstrapClientState, context: ?*const a.ProfileBootstrapContext, sealed: c_int) bool {
    return a.profile_bootstrap_client_should_apply(state, context, sealed) != 0;
}
fn client_is_applied(state: ?*const a.ProfileBootstrapClientState, context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_client_is_applied(state, context) != 0;
}
fn client_accepts_packet(state: ?*const a.ProfileBootstrapClientState, context: ?*const a.ProfileBootstrapContext, profile: ?*const a.SyncProfile, sealed: c_int) bool {
    return a.profile_bootstrap_client_accepts_packet(state, context, profile, sealed) != 0;
}
fn client_mark_applied(state: ?*a.ProfileBootstrapClientState, context: ?*const a.ProfileBootstrapContext) bool {
    return a.profile_bootstrap_client_mark_applied(state, context) != 0;
}
fn host_reset(value: ?*a.ProfileBootstrapHostState) void {
    a.profile_bootstrap_host_reset(value);
}
fn client_reset(value: ?*a.ProfileBootstrapClientState) void {
    a.profile_bootstrap_client_reset(value);
}
pub fn main() void {
    check(@src(), @sizeOf(a.ProfileBootstrapContext) == 12);
    check(@src(), @sizeOf(a.ProfileBootstrapClientState) == 16);
    var context = a.ProfileBootstrapContext{ .session = 17, .epoch = 3, .level = 9 };
    var host = std.mem.zeroes(a.ProfileBootstrapHostState);
    var client = std.mem.zeroes(a.ProfileBootstrapClientState);
    var data: [a.SYNC_PROFILE_BYTES]u8 = undefined;
    makeData(&data, 71);
    check(@src(), context_valid(&context));
    check(@src(), !context_valid(null));
    check(@src(), (a.profile_bootstrap_host_initial(&host, &context) == null));
    check(@src(), !host_capture(&host, &context, &data, data.len, 0));
    check(@src(), !client_should_apply(&client, &context, 0));
    check(@src(), !client_is_applied(&client, &context));
    check(@src(), !client_mark_applied(&client, &context));
    check(@src(), host_bind(&host, &context));
    check(@src(), client_bind(&client, &context));
    const empty_host = host;
    for (0..5) |field| {
        var bad = context;
        if (field == 0) bad.session = 0;
        if (field == 1) bad.session = 0xffffffff;
        if (field == 2) bad.epoch = 0;
        if (field == 3) bad.level = -1;
        if (field == 4) bad.level = 4096;
        check(@src(), !context_valid(&bad));
        check(@src(), !host_bind(&host, &bad));
        check(@src(), same(&host, &empty_host));
        check(@src(), !client_bind(&client, &bad));
        check(@src(), !client_should_apply(&client, &bad, 1));
    }
    check(@src(), !host_capture(&host, &context, null, data.len, 0));
    check(@src(), !host_capture(&host, &context, &data, 0, 0));
    check(@src(), !host_capture(&host, &context, &data, data.len - 1, 0));
    check(@src(), !host_capture(&host, &context, &data, data.len + 1, 0));
    data[0] ^= 1;
    check(@src(), !host_capture(&host, &context, &data, data.len, 0));
    data[0] ^= 1;
    check(@src(), same(&host, &empty_host));
    check(@src(), host_capture(&host, &context, &data, data.len, 0));
    const captured = host;
    const initial = a.profile_bootstrap_host_initial(&host, &context);
    check(@src(), initial != null and initial.?.epoch == context.epoch and initial.?.level == context.level and initial.?.sequence == 0);
    check(@src(), initial.?.checksum == nativeChecksum(&data));
    check(@src(), std.mem.eql(u8, &initial.?.data, &data));
    check(@src(), profile_valid(initial, &context));
    check(@src(), host_capture(&host, &context, &data, data.len, 0));
    check(@src(), host_bind(&host, &context));
    check(@src(), same(&host, &captured));
    data[0xb57c + 21] ^= 2;
    check(@src(), !host_capture(&host, &context, &data, data.len, 1));
    check(@src(), same(&host, &captured));
    check(@src(), a.profile_bootstrap_host_initial(&host, &context).?.data[0xb57c + 21] != data[0xb57c + 21]);
    data[0xb57c + 21] ^= 2;
    check(@src(), !host_capture(&host, &context, &data, data.len, 1));
    check(@src(), same(&host, &captured));
    for (0..4) |field| {
        var malformed = host.initial;
        if (field == 0) malformed.epoch += 1;
        if (field == 1) malformed.level += 1;
        if (field == 2) malformed.data[0] ^= 1;
        if (field == 3) malformed.data[0x40] ^= 1;
        check(@src(), !profile_valid(&malformed, &context));
    }
    check(@src(), !profile_valid(null, &context));
    check(@src(), client_should_apply(&client, &context, 0));
    check(@src(), client_accepts_packet(&client, &context, &host.initial, 0));
    check(@src(), client_accepts_packet(&client, &context, &host.initial, 1));
    var premature_live = host.initial;
    premature_live.sequence = 1;
    check(@src(), !client_accepts_packet(&client, &context, &premature_live, 0));
    check(@src(), !client_accepts_packet(&client, &context, &premature_live, 1));
    const before_decision = client;
    check(@src(), client_should_apply(&client, &context, 0));
    check(@src(), same(&client, &before_decision));
    check(@src(), client_mark_applied(&client, &context));
    check(@src(), client_is_applied(&client, &context));
    check(@src(), !client_accepts_packet(&client, &context, &host.initial, 0));
    check(@src(), !client_accepts_packet(&client, &context, &host.initial, 1));
    check(@src(), !client_accepts_packet(&client, &context, &premature_live, 0));
    check(@src(), client_accepts_packet(&client, &context, &premature_live, 1));
    check(@src(), !client_should_apply(&client, &context, 0));
    check(@src(), client_mark_applied(&client, &context));
    check(@src(), client_bind(&client, &context));
    check(@src(), !client_should_apply(&client, &context, 0));
    for (0..20) |_| check(@src(), client_should_apply(&client, &context, 1));
    for (0..3) |field| {
        var foreign = context;
        if (field == 0) foreign.session += 1;
        if (field == 1) foreign.epoch += 1;
        if (field == 2) foreign.level += 1;
        const before_client = client;
        check(@src(), !host_capture(&host, &foreign, &data, data.len, 0));
        check(@src(), (a.profile_bootstrap_host_initial(&host, &foreign) == null));
        check(@src(), !profile_valid(&host.initial, &foreign) or field == 0);
        check(@src(), !client_should_apply(&client, &foreign, 0));
        check(@src(), !client_should_apply(&client, &foreign, 1));
        check(@src(), !client_is_applied(&client, &foreign));
        check(@src(), !client_accepts_packet(&client, &foreign, &host.initial, 1));
        check(@src(), !client_mark_applied(&client, &foreign));
        check(@src(), same(&client, &before_client));
        check(@src(), same(&host, &captured));
    }
    for (0..3) |field| {
        var next = context;
        if (field == 0) next.session += 1;
        if (field == 1) next.epoch += 1;
        if (field == 2) next.level += 1;
        var rebound_host = captured;
        var rebound_client = client;
        check(@src(), host_bind(&rebound_host, &next));
        check(@src(), (a.profile_bootstrap_host_initial(&rebound_host, &context) == null));
        check(@src(), (a.profile_bootstrap_host_initial(&rebound_host, &next) == null));
        check(@src(), client_bind(&rebound_client, &next));
        check(@src(), !client_is_applied(&rebound_client, &context));
        check(@src(), !client_is_applied(&rebound_client, &next));
        check(@src(), client_should_apply(&rebound_client, &next, 0));
        check(@src(), client_mark_applied(&rebound_client, &next));
        check(@src(), client_is_applied(&rebound_client, &next));
    }
    var corrupt_host = host;
    corrupt_host.initial.data[0x45] ^= 1;
    check(@src(), (a.profile_bootstrap_host_initial(&corrupt_host, &context) == null));
    check(@src(), !host_capture(&corrupt_host, &context, &data, data.len, 0));
    corrupt_host = host;
    corrupt_host.captured = 2;
    check(@src(), (a.profile_bootstrap_host_initial(&corrupt_host, &context) == null));
    check(@src(), !host_capture(&corrupt_host, &context, &data, data.len, 0));
    var corrupt_client = client;
    corrupt_client.applied = 2;
    check(@src(), !client_should_apply(&corrupt_client, &context, 0));
    check(@src(), !client_should_apply(&corrupt_client, &context, 1));
    check(@src(), !client_is_applied(&corrupt_client, &context));
    check(@src(), !client_mark_applied(&corrupt_client, &context));
    var normal_update = host.initial;
    normal_update.sequence = 0xffffffff;
    normal_update.data[0xb57c + 21] ^= 2;
    normal_update.checksum = nativeChecksum(&normal_update.data);
    check(@src(), profile_valid(&normal_update, &context));
    check(@src(), client_accepts_packet(&client, &context, &normal_update, 1));
    check(@src(), !client_should_apply(&client, &context, 0));
    check(@src(), client_should_apply(&client, &context, 1));
    var exchange = std.mem.zeroes(a.ProfileBootstrapClientState);
    check(@src(), client_bind(&exchange, &context));
    for (0..6) |step| {
        const before = exchange;
        const sealed = step >= 2;
        check(@src(), client_accepts_packet(&exchange, &context, &host.initial, @intFromBool(sealed)) == (step == 0));
        check(@src(), client_accepts_packet(&exchange, &context, &normal_update, @intFromBool(sealed)) == (step >= 2));
        check(@src(), same(&before, &exchange));
        if (step == 0) check(@src(), client_mark_applied(&exchange, &context));
    }
    for (0..5) |field| {
        var bad_packet = normal_update;
        if (field == 0) bad_packet.epoch += 1;
        if (field == 1) bad_packet.level += 1;
        if (field == 2) bad_packet.checksum ^= 1;
        if (field == 3) bad_packet.data[0] ^= 1;
        if (field == 4) bad_packet.data[0xb57c] ^= 1;
        check(@src(), !client_accepts_packet(&exchange, &context, &bad_packet, 1));
    }
    check(@src(), !client_accepts_packet(&exchange, &context, null, 1));
    check(@src(), !client_accepts_packet(null, &context, &normal_update, 1));
    var reconnected_context = context;
    reconnected_context.session += 1;
    check(@src(), client_bind(&exchange, &reconnected_context));
    check(@src(), !client_accepts_packet(&exchange, &context, &host.initial, 0));
    check(@src(), !client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    check(@src(), client_accepts_packet(&exchange, &reconnected_context, &host.initial, 1));
    check(@src(), client_mark_applied(&exchange, &reconnected_context));
    check(@src(), !client_accepts_packet(&exchange, &reconnected_context, &host.initial, 1));
    check(@src(), client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    exchange.applied = 2;
    check(@src(), !client_accepts_packet(&exchange, &reconnected_context, &normal_update, 1));
    for (1..1001) |raw_session| {
        const session: u32 = @intCast(raw_session);
        const next = a.ProfileBootstrapContext{ .session = session, .epoch = 3, .level = @intCast(session % 4096) };
        check(@src(), host_bind(&host, &next));
        check(@src(), (a.profile_bootstrap_host_initial(&host, &next) == null));
        check(@src(), client_bind(&client, &next));
        check(@src(), client_should_apply(&client, &next, 0));
        check(@src(), host_capture(&host, &next, &data, data.len, session));
        check(@src(), a.profile_bootstrap_host_initial(&host, &next).?.sequence == session);
        check(@src(), client_mark_applied(&client, &next));
        check(@src(), !client_should_apply(&client, &next, 0));
        context = next;
    }
    host_reset(&host);
    client_reset(&client);
    check(@src(), (a.profile_bootstrap_host_initial(&host, &context) == null));
    check(@src(), !client_should_apply(&client, &context, 1));
    check(@src(), !client_is_applied(&client, &context));
    check(@src(), !client_mark_applied(&client, &context));
    check(@src(), !host_bind(null, &context));
    check(@src(), !client_bind(null, &context));
    check(@src(), !host_capture(null, &context, &data, data.len, 0));
    check(@src(), !client_mark_applied(null, &context));
    host_reset(null);
    client_reset(null);
}
