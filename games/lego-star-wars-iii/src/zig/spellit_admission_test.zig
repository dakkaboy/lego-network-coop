const std = @import("std");
const admission = @import("spellit_admission.zig");
const s = @import("cadence_state.zig");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var actors: [2][0x1440]u8 = std.mem.zeroes([2][0x1440]u8);
var live = true;
var fault: c_int = 0;
var wrong_identity = false;
var release: u32 = 0;
var native_eligible: u32 = 0;
var native_matches: u32 = 0;
var rider_parent: usize = 0;
var detach_rider_on_resolve = false;
var rider_model: [0x50]u8 = @splat(0);
fn eligibleStub(actor: usize) callconv(.c) u32 {
    check(@src(), actor == @intFromPtr(&actors[0]));
    return native_eligible;
}
fn matchesStub(actor: usize, action: i32) callconv(.c) u32 {
    check(@src(), actor == @intFromPtr(&actors[0]) and action == 175);
    return native_matches;
}
export fn coherent_frame_valid(_: *const @import("cohort_types.zig").Token, _: u32) c_int {
    return @intFromBool(live);
}
export fn game_sync_native_fault(code: c_int) void {
    fault = code;
}
export fn entities_update() void {}
export fn entities_observed_generation(_: usize) u32 {
    return 19;
}
export fn entities_describe(out: *p.SyncActor, actor: usize) void {
    out.* = std.mem.zeroes(p.SyncActor);
    out.generation = 19;
    out.spawn_tag = 23;
    out.character = 184;
    out.slot = if (actor == @intFromPtr(&actors[0])) 7 else 8;
}
export fn entities_slot(actor: usize) c_int {
    return if (actor == @intFromPtr(&actors[0])) 7 else 8;
}
export fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    slot.* = @intCast(entities_slot(actor));
    generation.* = 19;
    return 1;
}
export fn entities_resolve_reference(identity: *const p.SyncActor) usize {
    if (detach_rider_on_resolve) {
        detach_rider_on_resolve = false;
        win.store(usize, rider_parent + 0x360, 0);
    }
    return if (wrong_identity or identity.generation != 19) 0 else @intFromPtr(&actors[if (identity.slot == 7) @as(usize, 0) else 1]);
}
export fn entities_bind_native_reference(_: *const p.SyncActor, _: usize) c_int {
    return 0;
}
export fn entities_actor(_: u32, _: u32) usize {
    return 0;
}
export fn physics_effect_body_resolve(_: u32, _: u32) usize {
    unreachable;
}
export fn native_scene_support_source(_: usize, _: *[2]u32) c_int {
    return 0;
}
export fn native_scene_support_resolve(_: u32, _: u32) usize {
    return 0;
}
export fn physics_effect_body_source(_: usize, _: *[2]u32) c_int {
    unreachable;
}
fn begin(frame: *p.SyncFrame, host: bool) void {
    live = true;
    wrong_identity = false;
    fault = 0;
    release += 1;
    s.clonewars_cadence_failure = @splat(0);
    s.clonewars_actor_gate_failure = @splat(0);
    const token: @import("cohort_types.zig").Token = .{ .owner = 1, .owner_nonce = 1, .cohort_nonce = 1, .thread = win.GetCurrentThreadId(), .release = release, .epoch = frame.epoch, .sequence = frame.sequence, .frame = @intFromPtr(frame) };
    check(@src(), s.binding.bind(&token));
    check(@src(), s.binding.begin(@intFromPtr(frame)));
    s.journal.begin(frame, @intFromBool(host));
    if (host) frame.fire_task_gate_count = 0;
    s.fire_task_cursor = 0;
    s.active = true;
}
fn finish() void {
    check(@src(), s.binding.detach(&s.binding.lease));
    s.active = false;
}
fn call(actor: usize, kind: u32, stage: u32, local: u32) u32 {
    win.SetLastError(0x13579);
    const result = admission.cadence_spellit_admission(actor, kind, stage, local);
    check(@src(), win.GetLastError() == 0x13579);
    return result;
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0xfb4b6c and @intFromPtr(&image) + image.len > 0xfb4b70);
    const frame = std.heap.c_allocator.create(p.SyncFrame) catch @panic("allocation failed");
    defer std.heap.c_allocator.destroy(frame);
    @memset(std.mem.asBytes(frame), 0);
    frame.epoch = 22;
    frame.sequence = 50;
    const actor = @intFromPtr(&actors[0]);
    win.store(i16, actor + 0xdc0, 184);
    win.store(i16, @intFromPtr(&actors[1]) + 0xdc0, 181);
    win.store(u32, 0xfb4b6c, 51);
    hazardDeath(frame, actor);
    outerEligibility(frame, actor);
    riderFire(frame, actor);
    for (0..16) |host| for (0..16) |local| {
        begin(frame, true);
        managerFlow(actor, @intCast(host));
        const count = frame.fire_task_gate_count;
        for (frame.fire_task_gates[0..count]) |*entry| check(@src(), @import("fire_validation.zig").valid(entry));
        finish();
        begin(frame, false);
        managerFlow(actor, @intCast(local));
        check(@src(), s.fire_task_cursor == count and s.journal.failed == 0 and fault == 0);
        finish();
    };
    for ([_]u32{ 0x24, 0x25 }) |kind| for (0..2) |stage| for ([_]u32{ 0, 1 }) |authoritative| for ([_]u32{ 0, 1 }) |local| {
        const remote = if (stage == 0 and authoritative != 0) actor + 0xee4 else authoritative;
        const own = if (stage == 0 and local != 0) actor + 0xeec else local;
        begin(frame, true);
        const recorded = call(actor, kind, @intCast(stage), remote);
        check(@src(), recorded == remote and frame.fire_task_gate_count == 1 and @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
        finish();
        begin(frame, false);
        const result = call(actor, kind, @intCast(stage), own);
        check(@src(), (result != 0) == (authoritative != 0) and s.fire_task_cursor == 1 and s.journal.failed == 0 and fault == 0);
        if (authoritative == local) check(@src(), result == own);
        finish();
    };
    begin(frame, true);
    _ = call(actor, 0x24, 1, 1);
    var query = std.mem.zeroes(p.SyncSpellItQueryState);
    query.clock = 51;
    query.manager_class = 0x84c2ac;
    query.caller_site = 0x457f0a;
    query.limit = 1;
    var debug: [4]u32 = @splat(0);
    _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(&query), &debug);
    check(@src(), frame.fire_task_gate_count == 2);
    finish();
    begin(frame, false);
    check(@src(), call(actor, 0x24, 1, 0) == 1);
    _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(&query), &debug);
    check(@src(), s.fire_task_cursor == 2 and s.journal.failed == 0 and fault == 0);
    finish();
    for (0..6) |invalid| {
        begin(frame, true);
        _ = call(actor, 0x24, 1, 1);
        finish();
        begin(frame, false);
        switch (invalid) {
            0 => {
                wrong_identity = true;
            },
            1 => win.store(u32, 0xfb4b6c, 52),
            2 => {},
            3 => {},
            4 => {},
            5 => {
                live = false;
            },
            else => unreachable,
        }
        const count = frame.fire_task_gate_count;
        _ = call(actor, if (invalid == 2) 0x25 else 0x24, if (invalid == 3) 0 else 1, if (invalid == 4) 2 else 0);
        check(@src(), s.fire_task_cursor == 0 and frame.fire_task_gate_count == count);
        if (invalid == 5) check(@src(), fault == 0 and s.journal.failed == 0) else check(@src(), fault == 14 and s.journal.failed != 0);
        live = true;
        finish();
        win.store(u32, 0xfb4b6c, 51);
    }
    var gate = frame.fire_task_gates[0];
    check(@src(), @import("fire_validation.zig").valid(&gate));
    for (0..6) |invalid| {
        var bad = gate;
        switch (invalid) {
            0 => {
                bad.flags = 2;
            },
            1 => {
                bad.action = 0x23;
            },
            2 => {
                bad.value = 2;
            },
            3 => {
                bad.payload.storage[4] = 1;
            },
            4 => {
                bad.payload.storage[67] = 1;
            },
            5 => {
                bad.payload.storage[35] = 1;
            },
            else => unreachable,
        }
        check(@src(), !@import("fire_validation.zig").valid(&bad));
    }
}
fn managerFlow(actor: usize, bits: u32) void {
    const force = call(actor, 0, 4, bits & 1);
    const special = call(actor, 0, 5, (bits >> 1) & 1);
    if (force == 0 and special == 0) return;
    const eligible = call(actor, 0, 2, (bits >> 2) & 1);
    const matches = if (eligible == 0) call(actor, 0, 3, (bits >> 3) & 1) else 0;
    if (eligible != 0 or matches != 0) {
        _ = call(actor, 0x24, 0, 0);
        _ = call(actor, 0x24, 1, 1);
    }
}
fn riderFire(frame: *p.SyncFrame, actor: usize) void {
    const rider = @import("rider_fire_input.zig");
    rider_parent = win.VirtualAlloc(0, 0x1000, 0x3000, 4);
    check(@src(), rider_parent != 0);
    defer _ = win.VirtualFree(rider_parent, 0, 0x8000);
    const timer = rider_parent + 0x368;
    const mount = @intFromPtr(&actors[1]);
    win.store(usize, rider_parent, win.GetModuleHandleA(null) + 0x6d83dc);
    win.store(usize, rider_parent + 0x360, mount);
    win.store(usize, mount + 0x6fc, actor);
    win.store(usize, actor + 8, @intFromPtr(&rider_model));
    for ([_]u8{ 0, 1 }) |host_visible| for ([_]u8{ 0, 1 }) |local_visible| for ([_]f32{ 0.01, 2.0 }) |host_timer| {
        win.store(f32, timer, host_timer);
        rider_model[0x42] = host_visible;
        begin(frame, true);
        check(@src(), rider.cadence_rider_fire_input(actor, mount, timer, 0x46332b) == host_visible);
        check(@src(), frame.fire_task_gate_count == 1 and @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
        for (0..8) |bad| {
            var malformed = frame.fire_task_gates[0];
            switch (bad) {
                0 => malformed.flags = 2,
                1 => malformed.action = 1,
                2 => malformed.value = 2,
                3 => malformed.payload.rider_fire.behavior_class += 4,
                4 => malformed.payload.rider_fire.mount_generation = 0,
                5 => malformed.payload.rider_fire.mount_slot = p.SYNC_MAX_ACTORS,
                6 => malformed.payload.rider_fire.cooldown = std.math.inf(f32),
                7 => malformed.payload.storage[20] = 1,
                else => unreachable,
            }
            check(@src(), !@import("fire_validation.zig").valid(&malformed));
        }
        finish();
        win.store(f32, timer, -0.125);
        rider_model[0x42] = local_visible;
        const actors_before = actors;
        const model_before = rider_model;
        begin(frame, false);
        win.SetLastError(123);
        check(@src(), rider.cadence_rider_fire_input(actor, mount, timer, 0x46332b) == host_visible and win.GetLastError() == 123);
        check(@src(), win.load(f32, timer) == host_timer and s.fire_task_cursor == 1 and fault == 0 and s.journal.failed == 0);
        check(@src(), std.mem.eql(u8, std.mem.asBytes(&actors_before), std.mem.asBytes(&actors)) and std.mem.eql(u8, &model_before, &rider_model));
        finish();
    };
    for (0..8) |bad| {
        win.store(usize, rider_parent, win.GetModuleHandleA(null) + 0x6d83dc);
        win.store(usize, rider_parent + 0x360, mount);
        win.store(usize, mount + 0x6fc, actor);
        win.store(f32, timer, 2.0);
        begin(frame, true);
        _ = rider.cadence_rider_fire_input(actor, mount, timer, 0x46332b);
        finish();
        win.store(f32, timer, -0.125);
        begin(frame, false);
        var old: u32 = 0;
        switch (bad) {
            0 => win.store(usize, rider_parent + 0x360, 0),
            1 => win.store(usize, rider_parent, win.GetModuleHandleA(null) + 0x6d83e0),
            2 => win.store(usize, mount + 0x6fc, 0),
            3 => frame.fire_task_gates[0].payload.rider_fire.mount_generation += 1,
            4 => detach_rider_on_resolve = true,
            5 => check(@src(), win.VirtualProtect(rider_parent, 0x1000, 2, &old) != 0),
            6 => win.store(f32, timer, std.math.nan(f32)),
            7 => live = false,
            else => unreachable,
        }
        const before = win.load(u32, timer);
        _ = rider.cadence_rider_fire_input(actor, mount, timer, 0x46332b);
        check(@src(), win.load(u32, timer) == before);
        if (bad == 5) check(@src(), win.VirtualProtect(rider_parent, 0x1000, old, &old) != 0);
        if (bad == 7) check(@src(), fault == 0 and s.fire_task_cursor == 0) else check(@src(), fault == 14 and s.journal.failed != 0);
        live = true;
        finish();
    }
    win.store(usize, actor + 8, 0);
    win.store(usize, mount + 0x6fc, 0);
}
fn eligibilityFlow(actor: usize) void {
    const eligibility = @import("spellit_eligibility.zig");
    win.SetLastError(0x13579);
    const eligible = eligibility.spellit_actor_eligible(actor);
    check(@src(), win.GetLastError() == 0x13579);
    const matches = if (eligible == 0) eligibility.spellit_action_matches(actor, 175) else 0;
    check(@src(), win.GetLastError() == 0x13579);
    if (eligible != 0 or matches != 0) {
        _ = call(actor, 0x24, 0, 0);
        _ = call(actor, 0x24, 1, 1);
    }
}
fn outerEligibility(frame: *p.SyncFrame, actor: usize) void {
    const eligibility = @import("spellit_eligibility.zig");
    const original_eligible = eligibility.spellit_actor_eligible_native;
    const original_matches = eligibility.spellit_action_matches_native;
    eligibility.spellit_actor_eligible_native = @intFromPtr(&eligibleStub);
    eligibility.spellit_action_matches_native = @intFromPtr(&matchesStub);
    defer {
        eligibility.spellit_actor_eligible_native = original_eligible;
        eligibility.spellit_action_matches_native = original_matches;
    }
    for ([_]u32{ 0, 1 }) |host_eligible| for ([_]u32{ 0, 1 }) |host_matches| for ([_]u32{ 0, 1 }) |local_eligible| for ([_]u32{ 0, 1 }) |local_matches| {
        native_eligible = host_eligible;
        native_matches = host_matches;
        win.store(i16, actor + 0x2f4, -1);
        begin(frame, true);
        eligibilityFlow(actor);
        const count = frame.fire_task_gate_count;
        check(@src(), count == 1 + @as(u32, @intFromBool(host_eligible == 0)) + (if (host_eligible != 0 or host_matches != 0) @as(u32, 2) else 0));
        for (frame.fire_task_gates[0..count]) |*gate| check(@src(), @import("fire_validation.zig").valid(gate));
        finish();
        native_eligible = local_eligible;
        native_matches = local_matches;
        win.store(i16, actor + 0x2f4, 20);
        begin(frame, false);
        eligibilityFlow(actor);
        check(@src(), s.fire_task_cursor == count and s.journal.failed == 0 and fault == 0);
        finish();
    };
    const count = frame.fire_task_gate_count;
    native_eligible = 1;
    check(@src(), eligibility.spellit_actor_eligible(actor) == 1 and frame.fire_task_gate_count == count);
    check(@src(), admission.clonewars_spellit_eligibility_debug[2] != 0 and admission.clonewars_spellit_eligibility_debug[3] != 0);
    for ([_]u16{ 2, 3 }) |stage| {
        var gate = frame.fire_task_gates[0];
        gate.flags = stage;
        gate.action = 0;
        check(@src(), @import("fire_validation.zig").valid(&gate));
        gate.action = 0x24;
        check(@src(), !@import("fire_validation.zig").valid(&gate));
    }
}
fn hazardDeath(frame: *p.SyncFrame, actor: usize) void {
    const hazard = @import("hazard_death.zig");
    var controller: [2]usize = .{ 0xadcc94, 0 };
    var path: [0x160]u8 align(4) = @splat(0);
    var model: [0xe0]u8 align(4) = @splat(0);
    var resource: [0x30]u8 align(4) = @splat(0);
    var definition: [0x134]u8 align(4) = @splat(0);
    var native_frame: [3]u32 = .{ 0x11223344, 0x55667788, 0x99aabbcc };
    controller[1] = @intFromPtr(&path);
    win.store(usize, @intFromPtr(&path) + 4, @intFromPtr(&model));
    win.store(usize, @intFromPtr(&model) + 0xd8, @intFromPtr(&resource));
    win.store(usize, @intFromPtr(&resource) + 0x2c, @intFromPtr(&definition));
    win.store(u8, @intFromPtr(&definition) + 0x130, 1);
    win.store(f32, @intFromPtr(&path) + 0x158, 0.5);
    begin(frame, true);
    hazard.clonewars_hazard_observer_enabled = 1;
    _ = hazard.cadence_hazard_death(actor, 0x4000, @intFromPtr(&controller), @intFromPtr(&native_frame));
    hazard.clonewars_hazard_observer_enabled = 0;
    const observation = hazard.clonewars_hazard_source_debug;
    check(@src(), observation[0] != 0 and observation[6] == 0x55667788 and observation[10] == 1 and observation[11] == @as(u32, @bitCast(@as(f32, 0.5))) and observation[13] == 0xadcc94 and observation[14] == 0x11223344 and observation[15] == 0x99aabbcc);
    finish();
    for ([_]u32{ 0, 0x100, 0x4000, 0x4100, 0xffff }) |host| for ([_]u32{ 0, 0x100, 0x4000, 0x4100, 0xffff }) |local| {
        begin(frame, true);
        check(@src(), hazard.cadence_hazard_death(actor, host, 0, 0) == (host >> 8) & 0x41);
        check(@src(), frame.fire_task_gate_count == 1 and @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
        finish();
        begin(frame, false);
        win.SetLastError(771);
        const result = hazard.cadence_hazard_death(actor, local, 0, 0);
        check(@src(), win.GetLastError() == 771 and s.fire_task_cursor == 1 and s.journal.failed == 0 and fault == 0);
        check(@src(), (result == 0) == ((host >> 8) & 0x41 == 0));
        if (((local >> 8) & 0x41 == 0) == (result == 0)) check(@src(), result == (local >> 8) & 0x41);
        finish();
    };
    for (0..5) |invalid| {
        begin(frame, true);
        _ = hazard.cadence_hazard_death(actor, 0, 0, 0);
        finish();
        begin(frame, false);
        switch (invalid) {
            0 => wrong_identity = true,
            1 => win.store(u32, 0xfb4b6c, 52),
            2 => frame.fire_task_gates[0].kind = p.SYNC_ACTOR_DEATH_BREAKUP,
            3 => frame.fire_task_gate_count = 0,
            4 => live = false,
            else => unreachable,
        }
        check(@src(), hazard.cadence_hazard_death(actor, 0x4000, 0, 0) != 0 and s.fire_task_cursor == 0);
        if (invalid != 4) check(@src(), fault == 14 and s.journal.failed != 0);
        live = true;
        finish();
        win.store(u32, 0xfb4b6c, 51);
    }
    begin(frame, true);
    _ = hazard.cadence_hazard_death(actor, 0, 0, 0);
    finish();
    for (0..4) |invalid| {
        var bad = frame.fire_task_gates[0];
        switch (invalid) {
            0 => bad.flags = 1,
            1 => bad.action = 1,
            2 => bad.value = 2,
            3 => bad.payload.storage[4] = 1,
            else => unreachable,
        }
        check(@src(), !@import("fire_validation.zig").valid(&bad));
    }
}
