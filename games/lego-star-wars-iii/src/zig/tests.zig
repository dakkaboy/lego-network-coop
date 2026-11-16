const std = @import("std");
const c = @import("abi.zig").c;
const epoch = @import("epoch.zig");
test "native cycle: only an initialized scene with reset clock starts a new interval" {
    const cycle = @import("native_cycle.zig");
    try std.testing.expect(cycle.restarting(10, 0, 84, true));
    for (0..32) |phase| if (phase != 10) try std.testing.expect(!cycle.restarting(@intCast(phase), 0, 84, true));
    for ([_]u32{ 1, 2, 84, 0xffffffff }) |clock| try std.testing.expect(!cycle.restarting(10, clock, 84, true));
    try std.testing.expect(!cycle.restarting(10, 0, 0, true));
    try std.testing.expect(!cycle.restarting(10, 0, 84, false));
}
comptime {
    _ = @import("root.zig");
    _ = @import("trace.zig");
    _ = @import("trace_file.zig");
    _ = @import("journal_tests.zig");
    _ = @import("validation_tests.zig");
    _ = @import("engine_tests.zig");
    _ = @import("frame_validation.zig");
}

test "input: preserve brief presses across sampling and consume once" {
    var buffer: c.InputBuffer = undefined;
    c.input_buffer_reset(&buffer);
    try std.testing.expectEqual(@as(u8, 128), c.input_buffer_take(&buffer).analog_x);
    const press: c.SyncInput = .{ .held = 4, .pressed = 4, .analog_x = 17, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
    c.input_buffer_sample(&buffer, &press);
    var release = press;
    release.held = 0;
    release.pressed = 0;
    c.input_buffer_sample(&buffer, &release);
    try std.testing.expectEqual(@as(u32, 4), c.input_buffer_take(&buffer).pressed);
    try std.testing.expectEqual(@as(u32, 0), c.input_buffer_take(&buffer).pressed);
    var pulse: c.RemoteInputPulse = .{ .next_hold = 0 };
    try std.testing.expectEqual(@as(u32, 4), c.remote_input_execute(&pulse, &press).held);
    try std.testing.expectEqual(@as(u32, 4), c.remote_input_execute(&pulse, &release).held);
    try std.testing.expectEqual(@as(u32, 0), c.remote_input_execute(&pulse, &release).held);
}

test "epoch: future scene waits without mutating cursor" {
    var cursor: c.SyncEpochCursor = .{ .epoch = 2, .sequence = 7, .level = 12, .active = 1 };
    const before = cursor;
    try std.testing.expectEqual(@as(c_int, -1), c.sync_epoch_apply(&cursor, 12, 3, 57, 1));
    try std.testing.expectEqualDeep(before, cursor);
    try std.testing.expectEqual(@as(c_int, 2), c.sync_epoch_apply(&cursor, 57, 3, 57, 1));
    try std.testing.expectEqual(epoch.Result.stale, epoch.classify(&cursor, 57, 2, 12, 100));
    try std.testing.expectEqual(epoch.Result.gap, epoch.classify(&cursor, 57, 3, 57, 3));
}

test "epoch: restart skips reserved zero on integer wrap" {
    var cursor: c.SyncEpochCursor = .{ .epoch = std.math.maxInt(u32), .sequence = 7, .level = 12, .active = 0 };
    try std.testing.expectEqual(@as(u32, 1), c.sync_epoch_begin(&cursor, 12));
    try std.testing.expectEqual(@as(u32, 0), cursor.sequence);
}

test "profile: capture is immutable across retries and context changes" {
    var host = std.mem.zeroes(c.ProfileBootstrapHostState);
    const context: c.ProfileBootstrapContext = .{ .session = 17, .epoch = 3, .level = 9 };
    var bytes: [c.SYNC_PROFILE_BYTES]u8 = @splat(0);
    std.mem.writeInt(u32, bytes[0..4], 0x500, .little);
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_host_bind(&host, &context));
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_host_capture(&host, &context, &bytes, bytes.len, 0));
    const snapshot = host;
    for (0..128) |i| {
        bytes[4 + i] ^= 0xff;
        try std.testing.expectEqual(@as(c_int, 0), c.profile_bootstrap_host_capture(&host, &context, &bytes, bytes.len, 0));
        try std.testing.expectEqualSlices(u8, std.mem.asBytes(&snapshot), std.mem.asBytes(&host));
        bytes[4 + i] ^= 0xff;
    }
    try std.testing.expectEqual(@as(c_int, 0), c.profile_bootstrap_host_capture(&host, &context, &bytes, bytes.len, 1));
    var next = context;
    next.epoch += 1;
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_host_bind(&host, &next));
    try std.testing.expectEqual(@as(u32, 0), host.captured);
    try std.testing.expect(c.profile_bootstrap_host_initial(&host, &context) == null);
}

test "profile: failed application never commits the bootstrap" {
    var client = std.mem.zeroes(c.ProfileBootstrapClientState);
    const context: c.ProfileBootstrapContext = .{ .session = 17, .epoch = 3, .level = 9 };
    try std.testing.expectEqual(@as(c_int, 0), c.profile_bootstrap_client_mark_applied(&client, &context));
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_client_bind(&client, &context));
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_client_should_apply(&client, &context, 0));
    try std.testing.expectEqual(@as(c_int, 0), c.profile_bootstrap_client_is_applied(&client, &context));
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_client_mark_applied(&client, &context));
    try std.testing.expectEqual(@as(c_int, 0), c.profile_bootstrap_client_should_apply(&client, &context, 0));
    try std.testing.expectEqual(@as(c_int, 1), c.profile_bootstrap_client_should_apply(&client, &context, 1));
}

fn preloadInput(serial: u32) c.SyncPreloadInput {
    var input = std.mem.zeroes(c.SyncPreloadInput);
    input.epoch = 5;
    input.level = 7;
    input.serial = serial;
    input.root_phase = 0xd;
    input.delta = 0.08;
    input.engine_delta = 0.1;
    input.engine_mode = 3;
    return input;
}

test "preload: reject malformed floats without changing the transaction" {
    var state = std.mem.zeroes(c.NativePreloadState);
    c.preload_state_bind(&state, 11, 5, 7, 0x12340000);
    const before = state;
    inline for (.{ "delta", "engine_delta", "game_time" }) |field| {
        for ([_]u32{ 0x7f800000, 0xff800000, 0x7fc00001 }) |bits| {
            var input = preloadInput(1);
            @field(input, field) = @bitCast(bits);
            try std.testing.expectEqual(@as(c_int, 0), c.preload_state_accept(&state, &input));
            try std.testing.expectEqualSlices(u8, std.mem.asBytes(&before), std.mem.asBytes(&state));
        }
    }
}

test "preload: seal only after coordinated playable initialization" {
    var state = std.mem.zeroes(c.NativePreloadState);
    c.preload_state_bind(&state, 11, 5, 7, 0x12340000);
    var input = preloadInput(1);
    var receipt = std.mem.zeroes(c.SyncPreloadReceipt);
    receipt.serial = 1;
    receipt.world_calls = 1;
    receipt.end_phase = 0xd;
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_accept(&state, &input));
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_finish(&state, &receipt));
    try std.testing.expectEqual(@as(c_int, 0), c.preload_initial_seal_ready(&state, 0xd));
    input.serial = 2;
    input.root_phase = 0xe;
    receipt.serial = 2;
    receipt.end_phase = 0xe;
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_accept(&state, &input));
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_finish(&state, &receipt));
    try std.testing.expectEqual(@as(c_int, 1), c.preload_initial_seal_ready(&state, 0xe));
    var wrong = receipt;
    wrong.world_calls += 1;
    try std.testing.expectEqual(@as(c_int, -1), c.preload_state_peer_receipt(&state, &wrong));
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_peer_receipt(&state, &receipt));
    try std.testing.expectEqual(@as(c_int, 1), c.preload_state_seal(&state, 2));
    const sealed = state;
    input.serial = 3;
    try std.testing.expectEqual(@as(c_int, 0), c.preload_state_accept(&state, &input));
    try std.testing.expectEqualSlices(u8, std.mem.asBytes(&sealed), std.mem.asBytes(&state));
}
