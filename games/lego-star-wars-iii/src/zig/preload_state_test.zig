const std = @import("std");
const a = @import("abi.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("preload.zig");
}
const native_jobs_idle = @import("loader_policy.zig").jobsIdle;
fn source(serial: u32) a.SyncPreloadInput {
    var value = std.mem.zeroes(a.SyncPreloadInput);
    value.epoch = 5;
    value.level = 7;
    value.serial = serial;
    value.root_phase = 0xd;
    value.clock = 19;
    value.rng_game = 0xffffffff;
    value.rng_engine = 0x87654321;
    value.rng_effects = 0x92345678;
    value.delta = 0.08;
    value.engine_delta = 0.1;
    value.engine_mode = 3;
    return value;
}
fn receiptValue(serial: u32, worlds: u32, phase: u32) a.SyncPreloadReceipt {
    var value = std.mem.zeroes(a.SyncPreloadReceipt);
    value.serial = serial;
    value.world_calls = worlds;
    value.end_phase = phase;
    return value;
}
fn bound() a.NativePreloadState {
    var value = std.mem.zeroes(a.NativePreloadState);
    api.preload_state_bind(&value, 11, 5, 7, 0x12340000);
    return value;
}
fn reject_input(value: a.NativePreloadState, input: a.SyncPreloadInput) void {
    var state = value;
    check(@src(), api.preload_state_accept(&state, &input) == 0 and std.mem.eql(u8, std.mem.asBytes(&state), std.mem.asBytes(&value)));
}
fn reject_finish(value: a.NativePreloadState, receipt: a.SyncPreloadReceipt) void {
    var state = value;
    check(@src(), api.preload_state_finish(&state, &receipt) == 0 and std.mem.eql(u8, std.mem.asBytes(&state), std.mem.asBytes(&value)));
}
const api = struct {
    extern fn preload_phase_active(u32, c_int) c_int;
    extern fn preload_stage_eligible(u32, c_int, c_int, c_int, c_int) c_int;
    extern fn preload_input_valid(?*const a.SyncPreloadInput) c_int;
    extern fn preload_receipt_valid(?*const a.SyncPreloadReceipt) c_int;
    extern fn preload_flow_request_read(?*const a.SyncPreloadReceipt, u32, u32, ?*u32) c_int;
    extern fn preload_track_read(?*const a.SyncPreloadReceipt, u32, u32, ?*const [2]u32, ?*u32) c_int;
    extern fn preload_world_ready_valid(?*const a.SyncWorldReady) c_int;
    extern fn preload_world_ready_matches(?*const a.SyncWorldReady, ?*const a.SyncWorldReady) c_int;
    extern fn preload_world_roster_matches(?*const a.SyncWorldReady, ?*const a.SyncWorldReady) c_int;
    extern fn preload_state_peer_receipt(?*const a.NativePreloadState, ?*const a.SyncPreloadReceipt) c_int;
    extern fn preload_initial_seal_ready(?*const a.NativePreloadState, u32) c_int;
    extern fn preload_transition_pending(?*const a.NativePreloadState, u32, u32, c_int, ?*const a.SyncPreloadReceipt) c_int;
    extern fn preload_state_bind(?*a.NativePreloadState, u32, u32, c_int, usize) void;
    extern fn preload_state_accept(?*a.NativePreloadState, ?*const a.SyncPreloadInput) c_int;
    extern fn preload_state_finish(?*a.NativePreloadState, ?*const a.SyncPreloadReceipt) c_int;
    extern fn preload_state_seal(?*a.NativePreloadState, u32) c_int;
};
fn preload_phase_active(phase: u32, initialized: c_int) bool {
    return api.preload_phase_active(phase, initialized) != 0;
}
fn preload_stage_eligible(phase: u32, level: c_int, pending: c_int, targeted: c_int, initialized: c_int) bool {
    return api.preload_stage_eligible(phase, level, pending, targeted, initialized) != 0;
}
fn preload_input_valid(input: ?*const a.SyncPreloadInput) bool {
    return api.preload_input_valid(input) != 0;
}
fn preload_receipt_valid(receipt: ?*const a.SyncPreloadReceipt) bool {
    return api.preload_receipt_valid(receipt) != 0;
}
const preload_flow_request_read = api.preload_flow_request_read;
const preload_track_read = api.preload_track_read;
fn preload_world_ready_valid(ready: ?*const a.SyncWorldReady) bool {
    return api.preload_world_ready_valid(ready) != 0;
}
fn preload_world_ready_matches(local: ?*const a.SyncWorldReady, peer: ?*const a.SyncWorldReady) bool {
    return api.preload_world_ready_matches(local, peer) != 0;
}
fn preload_world_roster_matches(local: ?*const a.SyncWorldReady, peer: ?*const a.SyncWorldReady) bool {
    return api.preload_world_roster_matches(local, peer) != 0;
}
const preload_state_peer_receipt = api.preload_state_peer_receipt;
fn preload_initial_seal_ready(state: ?*const a.NativePreloadState, phase: u32) bool {
    return api.preload_initial_seal_ready(state, phase) != 0;
}
const preload_transition_pending = api.preload_transition_pending;
const preload_state_bind = api.preload_state_bind;
fn preload_state_accept(state: ?*a.NativePreloadState, input: ?*const a.SyncPreloadInput) bool {
    return api.preload_state_accept(state, input) != 0;
}
fn preload_state_finish(state: ?*a.NativePreloadState, receipt: ?*const a.SyncPreloadReceipt) bool {
    return api.preload_state_finish(state, receipt) != 0;
}
fn preload_state_seal(state: ?*a.NativePreloadState, serial: u32) bool {
    return api.preload_state_seal(state, serial) != 0;
}
pub fn main() void {
    check(@src(), @sizeOf(a.SyncPreloadInput) == 48);
    check(@src(), @sizeOf(a.SyncPreloadReceipt) == 1044);
    check(@src(), @sizeOf(a.SyncWorldReady) == 24);
    check(@src(), native_jobs_idle(0, 0, 0, 0));
    check(@src(), !native_jobs_idle(1, 0, 0, 0));
    check(@src(), !native_jobs_idle(0, 1, 0, 0));
    check(@src(), !native_jobs_idle(0, 0, 1, 0));
    check(@src(), !native_jobs_idle(0, 0, 0, 1));
    var absent_ready = std.mem.zeroes(a.SyncWorldReady);
    absent_ready.level = -1;
    const zero_world = std.mem.zeroes(a.SyncWorldReady);
    check(@src(), preload_world_ready_valid(&absent_ready) and !preload_world_ready_valid(&zero_world));
    check(@src(), !preload_world_ready_valid(null) and !preload_world_ready_matches(&absent_ready, &absent_ready));
    var prepared = std.mem.zeroes(a.SyncWorldReady);
    prepared.epoch = 5;
    prepared.level = 7;
    prepared.root_phase = 0xd;
    check(@src(), preload_world_ready_valid(&prepared));
    check(@src(), preload_world_ready_matches(&prepared, &prepared));
    var fewer = prepared;
    fewer.collider_count = 1;
    fewer.collider_roster = 42;
    check(@src(), preload_world_ready_matches(&prepared, &fewer));
    check(@src(), !preload_world_roster_matches(&prepared, &fewer));
    check(@src(), preload_world_roster_matches(&fewer, &fewer));
    for (0..4) |field| {
        var stale = prepared;
        if (field == 0) stale.epoch +%= 1;
        if (field == 1) stale.level +%= 1;
        if (field == 2) stale.root_phase = 0xe;
        if (field == 3) stale.completed_serial +%= 1;
        check(@src(), !preload_world_ready_matches(&prepared, &stale));
    }
    var invalid_ready = prepared;
    invalid_ready.root_phase = 0xb;
    check(@src(), !preload_world_ready_valid(&invalid_ready));
    invalid_ready.completed_serial = 1;
    check(@src(), preload_world_ready_valid(&invalid_ready));
    for (0..5000) |raw_serial| {
        const serial: u32 = @intCast(raw_serial);
        const local = a.SyncWorldReady{ .epoch = 5, .level = 7, .root_phase = if (serial != 0) 0xe else 0xd, .completed_serial = serial, .collider_count = 0, .collider_roster = 0 };
        var peer = local;
        check(@src(), preload_world_ready_matches(&local, &peer));
        peer.completed_serial +%= 1;
        check(@src(), !preload_world_ready_matches(&local, &peer));
        peer = local;
        if (serial != 0) {
            peer.completed_serial -= 1;
        } else {
            peer = absent_ready;
        }
        check(@src(), !preload_world_ready_matches(&local, &peer));
    }
    check(@src(), !preload_stage_eligible(0xd, 12, -1, 0, 0));
    check(@src(), !preload_stage_eligible(0xe, 6, 7, 1, 1));
    check(@src(), !preload_stage_eligible(0xd, 6, 7, 1, 1));
    check(@src(), preload_stage_eligible(0xd, 7, -1, 1, 0));
    check(@src(), preload_stage_eligible(0xe, 7, -1, 1, 1));
    check(@src(), !preload_initial_seal_ready(null, 0xd));
    {
        var receipt = receiptValue(3, 1, 14);
        receipt.flow_count = 2;
        receipt.flow_requests[0] = 0xffffffff;
        receipt.flow_requests[1] = 14;
        var request: u32 = 99;
        check(@src(), preload_receipt_valid(&receipt));
        check(@src(), preload_flow_request_read(&receipt, 3, 0, &request) == 1 and request == 0xffffffff);
        check(@src(), preload_flow_request_read(&receipt, 3, 1, &request) == 1 and request == 14);
        check(@src(), preload_flow_request_read(&receipt, 4, 0, &request) == 0 and request == 14);
        check(@src(), preload_flow_request_read(&receipt, 2, 0, &request) == -1 and request == 14);
        check(@src(), preload_flow_request_read(&receipt, 3, 2, &request) == -1);
        check(@src(), preload_flow_request_read(&receipt, 3, a.SYNC_MAX_PRELOAD_FLOW_REQUESTS, &request) == -1);
        var invalid = receipt;
        invalid.flow_requests[1] = 21;
        check(@src(), !preload_receipt_valid(&invalid));
        invalid = receipt;
        invalid.flow_requests[2] = 1;
        check(@src(), !preload_receipt_valid(&invalid));
        invalid = receipt;
        invalid.flow_count = a.SYNC_MAX_PRELOAD_FLOW_REQUESTS + 1;
        check(@src(), !preload_receipt_valid(&invalid));
        var state = bound();
        var input = source(1);
        check(@src(), preload_state_accept(&state, &input));
        receipt.serial = 1;
        check(@src(), preload_state_finish(&state, &receipt));
        check(@src(), preload_state_peer_receipt(&state, &receipt) == 1);
        receipt.flow_requests[1] = 13;
        check(@src(), preload_state_peer_receipt(&state, &receipt) == -1);
    }
    {
        var receipt = receiptValue(3, 1, 13);
        receipt.track_count = 1;
        receipt.tracks[0] = .{ .witness = .{ 0x1234, 0x5678 }, .time = 0x3f800000 };
        var witness: [2]u32 = .{ 0x1234, 0x5678 };
        var time: u32 = 0;
        check(@src(), preload_receipt_valid(&receipt));
        check(@src(), preload_track_read(&receipt, 3, 0, &witness, &time) == 1 and time == 0x3f800000);
        check(@src(), preload_track_read(&receipt, 4, 0, &witness, &time) == 0 and time == 0x3f800000);
        check(@src(), preload_track_read(&receipt, 2, 0, &witness, &time) == -1);
        witness[1] ^= 1;
        check(@src(), preload_track_read(&receipt, 3, 0, &witness, &time) == -1);
        witness[1] ^= 1;
        check(@src(), preload_track_read(&receipt, 3, 1, &witness, &time) == -1);
        var invalid = receipt;
        invalid.tracks[0].time = 0x7fc00000;
        check(@src(), !preload_receipt_valid(&invalid));
        invalid = receipt;
        invalid.tracks[1].witness[0] = 1;
        check(@src(), !preload_receipt_valid(&invalid));
        invalid = receipt;
        invalid.track_count = a.SYNC_MAX_PRELOAD_FLOW_REQUESTS + 1;
        check(@src(), !preload_receipt_valid(&invalid));
        var state = bound();
        var input = source(1);
        check(@src(), preload_state_accept(&state, &input));
        receipt.serial = 1;
        check(@src(), preload_state_finish(&state, &receipt));
        check(@src(), preload_state_peer_receipt(&state, &receipt) == 1);
        receipt.tracks[0].time +%= 1;
        check(@src(), preload_state_peer_receipt(&state, &receipt) == -1);
    }
    {
        var entering = bound();
        var input = source(1);
        input.root_phase = 0xb;
        check(@src(), preload_state_accept(&entering, &input));
        const entered = receiptValue(1, 1, 0xd);
        check(@src(), preload_state_finish(&entering, &entered));
        check(@src(), !preload_initial_seal_ready(&entering, 0xd));
        input = source(2);
        check(@src(), preload_state_accept(&entering, &input));
        const without_world = receiptValue(2, 0, 0xd);
        check(@src(), preload_state_finish(&entering, &without_world));
        check(@src(), !preload_initial_seal_ready(&entering, 0xd));
        input = source(3);
        check(@src(), preload_state_accept(&entering, &input));
        const updated = receiptValue(3, 1, 0xd);
        check(@src(), preload_state_finish(&entering, &updated));
        check(@src(), !preload_initial_seal_ready(&entering, 0xd));
        input = source(4);
        input.root_phase = 0xe;
        check(@src(), preload_state_accept(&entering, &input));
        const playable = receiptValue(4, 1, 0xe);
        check(@src(), preload_state_finish(&entering, &playable));
        check(@src(), preload_initial_seal_ready(&entering, 0xe));
    }
    for ([_]u32{ 0xd, 0xe }) |phase| {
        var early = bound();
        var initial = source(1);
        initial.root_phase = phase;
        check(@src(), !preload_initial_seal_ready(&early, phase));
        check(@src(), preload_state_accept(&early, &initial));
        const zero = receiptValue(1, 0, phase);
        check(@src(), preload_state_finish(&early, &zero));
        check(@src(), !preload_initial_seal_ready(&early, phase));
        early = bound();
        check(@src(), preload_state_accept(&early, &initial));
        const first_world = receiptValue(1, 1, phase);
        check(@src(), preload_state_finish(&early, &first_world));
        check(@src(), preload_initial_seal_ready(&early, phase) == (phase == 0xe));
        var wrong = first_world;
        wrong.end_phase = (if (phase == 0xd) 0xe else 0xd);
        check(@src(), preload_state_peer_receipt(&early, &wrong) == -1);
        check(@src(), !preload_initial_seal_ready(&early, wrong.end_phase));
        check(@src(), !preload_initial_seal_ready(&early, 0xa));
        check(@src(), !preload_initial_seal_ready(&early, 0xb));
        check(@src(), preload_state_peer_receipt(&early, &first_world) == 1);
        check(@src(), preload_state_seal(&early, 1));
        check(@src(), !preload_initial_seal_ready(&early, phase));
        reject_input(early, source(2));
    }
    check(@src(), !preload_stage_eligible(0xb, 7, -1, 1, 0));
    check(@src(), preload_stage_eligible(0xb, 7, -1, 1, 1));
    check(@src(), preload_stage_eligible(0xa, 7, -1, 1, 1));
    check(@src(), !preload_stage_eligible(0xc, 7, -1, 1, 1));
    check(@src(), !preload_stage_eligible(0xd, -1, -1, 1, 0));
    check(@src(), !preload_stage_eligible(0xd, 4096, -1, 1, 0));
    check(@src(), !preload_stage_eligible(0xd, 7, 7, 1, 0));
    check(@src(), !preload_stage_eligible(0xd, 7, 7, 1, 1));
    const host = source(1);
    var empty = std.mem.zeroes(a.SyncPreloadInput);
    empty.level = -1;
    const zero = std.mem.zeroes(a.SyncPreloadInput);
    check(@src(), preload_input_valid(&host) and preload_input_valid(&empty));
    check(@src(), !preload_input_valid(null) and !preload_input_valid(&zero));
    for ([_]u32{ 0xa, 0xb, 0xd, 0xe }) |phase| {
        var input = host;
        input.root_phase = phase;
        check(@src(), preload_input_valid(&input));
    }
    for (0..15) |field| {
        var bad = host;
        switch (field) {
            0 => {
                bad.epoch = 0;
            },
            1 => {
                bad.level = -1;
            },
            2 => {
                bad.level = 4096;
            },
            3 => {
                bad.serial = 0;
            },
            4 => {
                bad.root_phase = 0xc;
            },
            5 => {
                bad.root_phase = 0xf;
            },
            6 => {
                bad.delta = std.math.nan(f32);
            },
            7 => {
                bad.engine_delta = std.math.inf(f32);
            },
            8 => {
                bad.delta = -0.001;
            },
            9 => {
                bad.engine_delta = -0.001;
            },
            10 => {
                bad.delta = 0.1001;
            },
            11 => {
                bad.engine_delta = 0.1001;
            },
            12 => {
                bad.engine_mode = 17;
            },
            13 => {
                bad.engine_mode = 0xffffffff;
            },
            14 => {
                bad.game_time = std.math.nan(f32);
            },
            else => unreachable,
        }
        check(@src(), !preload_input_valid(&bad));
    }
    var boundary = host;
    boundary.root_phase = 0xe;
    boundary.delta = 0;
    boundary.engine_delta = 0;
    boundary.engine_mode = 16;
    check(@src(), preload_input_valid(&boundary));
    var empty_bad = empty;
    empty_bad.serial = 1;
    check(@src(), !preload_input_valid(&empty_bad));
    empty_bad = empty;
    empty_bad.delta = -0.0;
    check(@src(), !preload_input_valid(&empty_bad));
    const no_receipt = std.mem.zeroes(a.SyncPreloadReceipt);
    const no_world = receiptValue(1, 0, 0);
    const many_worlds = receiptValue(1, 64, 20);
    check(@src(), preload_receipt_valid(&no_receipt) and preload_receipt_valid(&no_world) and preload_receipt_valid(&many_worlds));
    check(@src(), !preload_receipt_valid(null));
    for ([_]a.SyncPreloadReceipt{ receiptValue(0, 1, 0), receiptValue(0, 0, 1), receiptValue(1, 65, 0), receiptValue(1, 0, 21) }) |bad| check(@src(), !preload_receipt_valid(&bad));
    var state = bound();
    check(@src(), !preload_state_accept(null, &host));
    check(@src(), !preload_state_finish(null, &no_world));
    check(@src(), !preload_state_seal(null, 1));
    preload_state_bind(null, 1, 1, 1, 1);
    check(@src(), !preload_state_accept(&state, null));
    check(@src(), !preload_state_finish(&state, null));
    reject_input(state, source(2));
    reject_finish(state, no_world);
    var stale = host;
    stale.epoch = 4;
    reject_input(state, stale);
    stale = host;
    stale.level = 6;
    reject_input(state, stale);
    check(@src(), preload_state_accept(&state, &host));
    check(@src(), preload_state_accept(&state, &host));
    for (0..8) |field| {
        var changed = host;
        switch (field) {
            0 => {
                changed.clock +%= 1;
            },
            1 => {
                changed.rng_game +%= 1;
            },
            2 => {
                changed.rng_engine +%= 1;
            },
            3 => {
                changed.delta = 0.07;
            },
            4 => {
                changed.engine_delta = 0.09;
            },
            5 => {
                changed.engine_mode +%= 1;
            },
            6 => {
                changed.root_phase = 0xe;
            },
            7 => {
                changed.rng_effects +%= 1;
            },
            else => unreachable,
        }
        reject_input(state, changed);
    }
    reject_input(state, source(2));
    reject_input(state, source(3));
    reject_finish(state, no_receipt);
    reject_finish(state, receiptValue(2, 1, 14));
    check(@src(), !preload_state_seal(&state, 1));
    check(@src(), preload_state_finish(&state, &no_world));
    check(@src(), state.completed == 0);
    check(@src(), preload_state_peer_receipt(&state, &no_world) == 1);
    check(@src(), preload_state_peer_receipt(&state, &no_receipt) == 0);
    var wrong_phase = no_world;
    wrong_phase.end_phase = 0xd;
    check(@src(), preload_state_peer_receipt(&state, &wrong_phase) == -1);
    var wrong_calls = no_world;
    wrong_calls.world_calls = 1;
    check(@src(), preload_state_peer_receipt(&state, &wrong_calls) == -1);
    const future_receipt = receiptValue(2, 0, 0);
    check(@src(), preload_state_peer_receipt(&state, &future_receipt) == -1);
    check(@src(), preload_state_finish(&state, &no_world));
    reject_finish(state, receiptValue(1, 1, 0));
    check(@src(), !preload_state_seal(&state, 1));
    check(@src(), preload_state_accept(&state, &host));
    var next = source(2);
    next.root_phase = 0xe;
    next.clock +%= 1;
    check(@src(), preload_state_accept(&state, &next));
    reject_input(state, host);
    reject_input(state, source(4));
    reject_finish(state, no_world);
    check(@src(), !preload_state_seal(&state, 1));
    const second = receiptValue(2, 2, 14);
    check(@src(), preload_state_finish(&state, &second));
    check(@src(), state.completed != 0 and state.applied.world_calls == 2);
    check(@src(), preload_state_finish(&state, &second));
    reject_finish(state, receiptValue(2, 1, 14));
    reject_finish(state, receiptValue(2, 2, 13));
    var third = source(3);
    check(@src(), preload_state_accept(&state, &third));
    const third_done = receiptValue(3, 0, 15);
    check(@src(), preload_state_finish(&state, &third_done));
    check(@src(), state.completed != 0);
    check(@src(), !preload_state_seal(&state, 2));
    check(@src(), preload_state_seal(&state, 3));
    check(@src(), preload_state_seal(&state, 3));
    check(@src(), !preload_state_seal(&state, 2));
    reject_input(state, third);
    reject_input(state, source(4));
    check(@src(), preload_state_finish(&state, &third_done));
    preload_state_bind(&state, 11, 5, 7, 0x12340000);
    check(@src(), state.sealed_serial == 3 and state.completed != 0);
    for (0..4) |context| {
        state = bound();
        check(@src(), preload_state_accept(&state, &host));
        const done = receiptValue(1, 1, 14);
        check(@src(), preload_state_finish(&state, &done));
        check(@src(), preload_state_seal(&state, 1));
        preload_state_bind(&state, (if (context == 0) 12 else 11), (if (context == 1) 6 else 5), (if (context == 2) 8 else 7), (if (context == 3) 0x12350000 else 0x12340000));
        check(@src(), state.input.epoch == 0 and state.applied.serial == 0 and state.completed == 0 and state.sealed_serial == 0);
        var fresh = host;
        fresh.epoch = state.epoch;
        fresh.level = state.level;
        check(@src(), preload_state_accept(&state, &fresh));
        check(@src(), preload_state_finish(&state, &done));
        check(@src(), preload_state_seal(&state, 1));
    }
    for (0..4) |invalid| {
        var unbound = std.mem.zeroes(a.NativePreloadState);
        preload_state_bind(&unbound, (if (invalid == 0) 0 else 11), (if (invalid == 1) 0 else 5), (if (invalid == 2) -1 else 7), (if (invalid == 3) 0 else 0x12340000));
        reject_input(unbound, host);
    }
    state = bound();
    var plus = host;
    plus.delta = 0;
    check(@src(), preload_state_accept(&state, &plus));
    var minus = plus;
    minus.delta = -0.0;
    reject_input(state, minus);
    state = bound();
    state.input = source(0xffffffff);
    state.applied = receiptValue(0xffffffff, 1, 14);
    state.completed = 1;
    reject_input(state, source(0));
    reject_input(state, source(1));
    reject_input(state, source(0xffffffff - 1));
    check(@src(), preload_state_accept(&state, &state.input));
    check(@src(), preload_state_seal(&state, 0xffffffff));
    state = bound();
    check(@src(), preload_state_accept(&state, &host));
    check(@src(), preload_state_finish(&state, &many_worlds));
    check(@src(), preload_state_seal(&state, 1));
    state = bound();
    for (1..5001) |raw_serial| {
        const serial: u32 = @intCast(raw_serial);
        const current = source(serial);
        check(@src(), preload_state_accept(&state, &current));
        check(@src(), preload_state_accept(&state, &current));
        const done = receiptValue(serial, serial % 3, serial % 21);
        check(@src(), preload_state_finish(&state, &done));
        check(@src(), preload_state_finish(&state, &done));
    }
    check(@src(), state.completed != 0 and preload_state_seal(&state, 5000));
    state = bound();
    state.input = source(259);
    state.applied = receiptValue(258, 1, 13);
    state.completed = 1;
    const before_final = state.applied;
    var final_tick = receiptValue(259, 1, 13);
    final_tick.flow_count = 1;
    final_tick.flow_requests[0] = 0xffffffff;
    check(@src(), preload_transition_pending(&state, 11, 5, 7, null) == 1);
    check(@src(), preload_transition_pending(&state, 11, 5, 7, &final_tick) == 1);
    check(@src(), preload_state_finish(&state, &final_tick));
    check(@src(), preload_transition_pending(&state, 11, 5, 7, null) == 1);
    check(@src(), preload_transition_pending(&state, 11, 5, 7, &before_final) == 1);
    check(@src(), preload_transition_pending(&state, 11, 5, 7, &final_tick) == 0);
    var different_final = final_tick;
    different_final.flow_requests[0] = 14;
    check(@src(), preload_transition_pending(&state, 11, 5, 7, &different_final) == -1);
    check(@src(), preload_transition_pending(&state, 12, 5, 7, null) == 0);
    check(@src(), preload_transition_pending(&state, 11, 6, 7, null) == 0);
    check(@src(), preload_transition_pending(&state, 11, 5, 8, null) == 0);
    check(@src(), preload_state_seal(&state, 259));
    check(@src(), preload_transition_pending(&state, 11, 5, 7, null) == 0);
}
