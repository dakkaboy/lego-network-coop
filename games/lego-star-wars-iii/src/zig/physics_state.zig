const std = @import("std");
const p = @import("protocol.zig");
const types = @import("cohort_types.zig");
const Token = types.Token;
const Lease = types.Lease;
const validation = @import("physics_validation.zig");
const equal = @import("validation.zig").equal;
pub var frame: ?*p.SyncFrame = null;
pub var lease = std.mem.zeroes(Lease);
pub var cursor: u32 = 0;
var consumed: [1024]bool = @splat(false);
var last_epoch: u32 = 0;
pub var active = false;
pub var host = false;
pub var failed = false;
pub export var clonewars_physics_input_debug: [8]u32 = @splat(0);
pub export var clonewars_physics_input_failure: [12]u32 = @splat(0);
pub export var clonewars_physics_failure_local = std.mem.zeroes(p.SyncPhysicsChoice);
pub export var clonewars_physics_failure_expected = std.mem.zeroes(p.SyncPhysicsChoice);
pub export var clonewars_physics_failure_stack: [25]usize = @splat(0);
pub export var clonewars_breakup_launch_correction: [8]u32 = @splat(0);
extern fn geometry_frame_lease_get(*Lease) c_int;
extern fn geometry_frame_cancelled(*const Lease) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn game_sync_native_fault(c_int) void;
extern "kernel32" fn RtlCaptureStackBackTrace(u32, u32, [*]usize, ?*u32) callconv(.winapi) u16;
extern fn entities_bind_native_reference(*const p.SyncActor, usize) c_int;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
pub fn live() bool {
    if (!active or frame == null) return false;
    var current: Lease = undefined;
    return geometry_frame_lease_get(&current) != 0 and lease.serial == current.serial and equal(&lease.cohort, &current.cohort) and geometry_frame_cancelled(&lease) == 0 and coherent_frame_valid(&lease.cohort, 14) != 0 and lease.cohort.frame == @intFromPtr(frame.?);
}
fn sourceWord(value: ?*const p.SyncPhysicsChoice) u32 {
    const choice = value orelse return 0;
    return switch (choice.kind) {
        p.SYNC_PHYSICS_BLUE_SHADOW_BLAST => choice.payload.blast.slot,
        p.SYNC_PHYSICS_BREAKUP_BASIS => choice.payload.breakup_basis.name_hash[0],
        p.SYNC_PHYSICS_BREAKUP_SCALE, p.SYNC_PHYSICS_EFFECT_BIRTH, p.SYNC_PHYSICS_EFFECT_STEP, p.SYNC_PHYSICS_EFFECT_REST => choice.payload.basic.name_hash[0],
        p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION => choice.payload.spellit_body.key[0],
        else => if (choice.kind >= p.SYNC_PHYSICS_SPELLIT_SEED) choice.payload.world.source_name[0] else choice.payload.basic.name_hash[0],
    };
}
fn clock(value: ?*const p.SyncPhysicsChoice) u32 {
    const choice = value orelse return 0;
    if (choice.kind == p.SYNC_PHYSICS_BLUE_SHADOW_BLAST) return choice.payload.blast.clock;
    return if (choice.kind < p.SYNC_PHYSICS_SPELLIT_SEED or choice.kind == p.SYNC_PHYSICS_BREAKUP_SCALE or choice.kind == p.SYNC_PHYSICS_EFFECT_BIRTH or choice.kind == p.SYNC_PHYSICS_EFFECT_STEP or choice.kind == p.SYNC_PHYSICS_EFFECT_REST) choice.payload.basic.clock else choice.payload.world.clock;
}
pub fn fail(reason: u32, local: ?*const p.SyncPhysicsChoice, expected: ?*const p.SyncPhysicsChoice) c_int {
    if (!live()) return 0;
    failed = true;
    if (clonewars_physics_input_failure[0] == 0) {
        clonewars_physics_failure_local = if (local) |v| v.* else std.mem.zeroes(p.SyncPhysicsChoice);
        clonewars_physics_failure_expected = if (expected) |v| v.* else std.mem.zeroes(p.SyncPhysicsChoice);
        const values = [_]u32{ frame.?.epoch, frame.?.sequence, cursor, reason, if (local) |v| v.kind else 0, if (expected) |v| v.kind else 0, sourceWord(local), sourceWord(expected), clock(local), clock(expected), if (local) |v| v.site else 0, if (expected) |v| v.site else 0 };
        @memcpy(&clonewars_physics_input_failure, &values);
        clonewars_physics_failure_stack[0] = RtlCaptureStackBackTrace(0, 24, @ptrCast(&clonewars_physics_failure_stack[1]), null);
    }
    clonewars_physics_input_debug[2] +%= 1;
    game_sync_native_fault(15);
    return 0;
}
pub fn expectedEntry() ?*const p.SyncPhysicsChoice {
    const f = frame orelse return null;
    return if (cursor < f.physics_choice_count) &f.physics_choices[cursor] else null;
}
pub fn record(choice: p.SyncPhysicsChoice) bool {
    const f = frame.?;
    if (f.physics_choice_count >= p.SYNC_MAX_PHYSICS_CHOICES) return false;
    f.physics_choices[f.physics_choice_count] = choice;
    f.physics_choice_count += 1;
    clonewars_physics_input_debug[0] +%= 1;
    return true;
}
pub fn consume(count: u32) void {
    cursor += count;
    while (cursor < frame.?.physics_choice_count and consumed[cursor]) cursor += 1;
    clonewars_physics_input_debug[1] +%= count;
}
pub fn rest(local: *const p.SyncPhysicsChoice) ?u32 {
    if (!live() or failed or host or local.kind != p.SYNC_PHYSICS_EFFECT_REST or !validation.valid(local)) return null;
    var selected: ?u32 = null;
    var i = cursor;
    while (i < frame.?.physics_choice_count) : (i += 1) {
        const e = &frame.?.physics_choices[i];
        if (e.kind != p.SYNC_PHYSICS_EFFECT_REST or e.site != local.site or e.payload.basic.clock != local.payload.basic.clock) break;
        if (consumed[i] or !validation.sameSource(e, local)) continue;
        if (selected != null) return null;
        selected = i;
    }
    if (selected) |index| {
        consumed[index] = true;
        clonewars_physics_input_debug[1] +%= 1;
        while (cursor < frame.?.physics_choice_count and consumed[cursor]) cursor += 1;
        return frame.?.physics_choices[index].payload.basic.recipe[0];
    }
    return null;
}
pub export fn physics_input_begin(next: ?*p.SyncFrame, authority: c_int) c_int {
    const f = next orelse return 0;
    var current: Lease = undefined;
    if (geometry_frame_lease_get(&current) == 0 or current.cohort.frame != @intFromPtr(f) or coherent_frame_valid(&current.cohort, 2) == 0) return 0;
    frame = f;
    lease = current;
    cursor = 0;
    consumed = @splat(false);
    host = authority != 0;
    failed = false;
    active = true;
    clonewars_physics_input_debug[5] = @truncate(@intFromPtr(f));
    if (host) f.physics_choice_count = 0;
    if (last_epoch != f.epoch) {
        @memset(&clonewars_physics_input_failure, 0);
        @memset(&clonewars_physics_failure_stack, 0);
        @memset(&clonewars_breakup_launch_correction, 0);
        last_epoch = f.epoch;
    }
    return @intFromBool(live());
}
pub export fn physics_input_finish() c_int {
    if (!live()) return 0;
    if (!failed and !host and cursor != frame.?.physics_choice_count) _ = fail(4, null, null);
    const ok = !failed;
    active = false;
    return @intFromBool(ok);
}
pub export fn physics_input_cancel() void {
    active = false;
    frame = null;
}
fn sourceInput(choice_value: ?*p.SyncPhysicsChoice, token: ?*const Token) c_int {
    if (!active) return 0;
    if (token == null or !live() or failed or !equal(token.?, &lease.cohort) or coherent_frame_valid(token.?, 4) == 0) return -1;
    const choice = choice_value orelse {
        _ = fail(5, null, null);
        return -1;
    };
    if (!validation.valid(choice)) {
        _ = fail(5, choice, null);
        return -1;
    }
    if (host) {
        if (!record(choice.*)) {
            _ = fail(2, choice, null);
            return -1;
        }
    } else {
        const expected = expectedEntry() orelse {
            _ = fail(6, choice, null);
            return -1;
        };
        if (!validation.sameSource(expected, choice)) {
            _ = fail(6, choice, expected);
            return -1;
        }
        const value = &choice.payload;
        const canonical = &expected.payload;
        switch (choice.kind) {
            p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION, p.SYNC_PHYSICS_RTS_BODY_BASIS, p.SYNC_PHYSICS_RTS_BODY_MOTION => value.spellit_body.values = canonical.spellit_body.values,
            p.SYNC_PHYSICS_SPELLIT_STEP => {
                value.spellit_step.engine_seed = canonical.spellit_step.engine_seed;
                value.spellit_step.game_seed = canonical.spellit_step.game_seed;
                value.spellit_step.delta = canonical.spellit_step.delta;
                value.spellit_step.timer = canonical.spellit_step.timer;
            },
            p.SYNC_PHYSICS_SPELLIT_POSE => {
                value.spellit_pose.position = canonical.spellit_pose.position;
                value.spellit_pose.last_time = canonical.spellit_pose.last_time;
            },
            p.SYNC_PHYSICS_RTS_GENERATOR => @memcpy(std.mem.asBytes(value)[24..60], std.mem.asBytes(canonical)[24..60]),
            p.SYNC_PHYSICS_RTS_ORDER => @memcpy(std.mem.asBytes(value)[16..36], std.mem.asBytes(canonical)[16..36]),
            p.SYNC_PHYSICS_MODULE_SEED => value.module.value = canonical.module.value,
            p.SYNC_PHYSICS_GUN_JAM_SEED => value.gun_jam.value = canonical.gun_jam.value,
            p.SYNC_PHYSICS_VEHICLE_RNG => value.vehicle_rng.value = canonical.vehicle_rng.value,
            else => value.world.value = canonical.world.value,
        }
        consume(1);
    }
    return if (live()) 1 else -1;
}
pub export fn physics_world_input(choice: ?*p.SyncPhysicsChoice, token: ?*const Token) c_int {
    if (!active) return 0;
    const allowed = if (choice) |c| switch (c.kind) {
        p.SYNC_PHYSICS_SPELLIT_SEED...p.SYNC_PHYSICS_SPELLIT_ENABLED, p.SYNC_PHYSICS_SPELLIT_POSE, p.SYNC_PHYSICS_SPELLIT_STEP, p.SYNC_PHYSICS_SPELLIT_SELECTION, p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION, p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS, p.SYNC_PHYSICS_RTS_VISIBILITY, p.SYNC_PHYSICS_RTS_BODY_BASIS, p.SYNC_PHYSICS_RTS_BODY_MOTION, p.SYNC_PHYSICS_RTS_ORDER, p.SYNC_PHYSICS_RTS_GENERATOR => true,
        else => false,
    } else false;
    if (!allowed) {
        if (live()) _ = fail(5, choice, null);
        return -1;
    }
    return sourceInput(choice, token);
}

pub fn skipResoluteHologramStep(choice: *const p.SyncPhysicsChoice, token: *const Token) bool {
    if (host or failed or !live() or frame.?.level != 3 or !equal(token, &lease.cohort) or
        choice.kind != p.SYNC_PHYSICS_SPELLIT_STEP or !validation.valid(choice)) return false;
    for (frame.?.physics_choices[0..frame.?.physics_choice_count]) |entry| {
        if (entry.kind == choice.kind and entry.payload.spellit_step.clock == choice.payload.spellit_step.clock) return false;
    }
    return true;
}
pub export fn physics_module_input(choice: ?*p.SyncPhysicsChoice, token: ?*const Token) c_int {
    if (!active) return 0;
    if (choice == null or (choice.?.kind != p.SYNC_PHYSICS_MODULE_SEED and choice.?.kind != p.SYNC_PHYSICS_GUN_JAM_SEED)) {
        if (live()) _ = fail(5, choice, null);
        return -1;
    }
    return sourceInput(choice, token);
}
pub export fn physics_vehicle_rng_input(choice_value: ?*p.SyncPhysicsChoice, actor: usize, token: ?*const Token) c_int {
    if (!active) return 0;
    const choice = choice_value orelse return -1;
    if (choice.kind != p.SYNC_PHYSICS_VEHICLE_RNG or token == null or !live() or failed or !equal(token.?, &lease.cohort) or coherent_frame_valid(token.?, 4) == 0) return -1;
    if (!host) {
        const expected = expectedEntry() orelse {
            _ = fail(6, choice, null);
            return -1;
        };
        if (expected.kind != choice.kind or expected.site != choice.site or !validation.valid(expected)) {
            _ = fail(6, choice, expected);
            return -1;
        }
        const value = &expected.payload.vehicle_rng;
        var reference = std.mem.zeroes(p.SyncActor);
        reference.slot = value.slot;
        reference.generation = value.generation;
        reference.character = value.character;
        reference.spawn_tag = value.spawn_tag;
        reference.spawn_source = value.spawn_source;
        if (entities_bind_native_reference(&reference, actor) == 0 or !live() or entities_observed_identity(actor, &choice.payload.vehicle_rng.slot, &choice.payload.vehicle_rng.generation) == 0) {
            _ = fail(6, choice, expected);
            return -1;
        }
    }
    return sourceInput(choice, token);
}
