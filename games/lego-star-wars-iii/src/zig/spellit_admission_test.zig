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
export fn coherent_frame_valid(_: *const @import("cohort_types.zig").Token, _: u32) c_int {
    return @intFromBool(live);
}
export fn game_sync_native_fault(code: c_int) void {
    fault = code;
}
export fn entities_update() void {}
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
    return if (wrong_identity or identity.generation != 19) 0 else @intFromPtr(&actors[if (identity.slot == 7) @as(usize, 0) else 1]);
}
export fn entities_bind_native_reference(_: *const p.SyncActor, _: usize) c_int {
    return 0;
}
export fn entities_actor(_: u32, _: u32) usize {
    return 0;
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
