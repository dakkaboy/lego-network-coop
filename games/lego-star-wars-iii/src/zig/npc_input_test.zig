const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const n = @import("npc_input.zig");
const Token = @import("cohort_types.zig").Token;
const check = @import("native_test_support.zig").check;
var active: Token = undefined;
var phase: u5 = 1;
var cancellation: u32 = 0;
var valid = true;
pub export fn coherent_frame_valid(token: *const Token, phases: u32) c_int {
    return @intFromBool(valid and phases & (@as(u32, 1) << phase) != 0 and std.mem.eql(u8, std.mem.asBytes(token), std.mem.asBytes(&active)));
}
pub export fn coherent_frame_cancel_atomic(reason: u32) void {
    cancellation |= reason;
    valid = false;
}
fn state(journal: *const n.Journal, nonce: u32, bound: u32, started: u32, cancelled: u32, cursor: u32, host: c_int) void {
    check(@src(), journal.nonce == nonce and journal.bound == bound and journal.started == started and journal.cancelled == cancelled and journal.cursor == cursor and journal.host == host and journal.failed == 0);
    check(@src(), @import("validation.zig").equal(&journal.cohort, &active));
}
pub fn main() void {
    const frame: *p.SyncFrame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(frame) != 0);
    defer _ = win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    frame.epoch = 1;
    frame.sequence = 1;
    active = .{ .owner = 0x1000, .owner_nonce = 1, .cohort_nonce = 1, .thread = win.GetCurrentThreadId(), .release = 1, .epoch = 1, .sequence = 1, .frame = @intFromPtr(frame) };
    var journal = std.mem.zeroes(n.Journal);
    check(@src(), n.npc_input_bind_cohort(&journal, &active) == 1);
    state(&journal, 1, 1, 0, 0, 0, 0);
    check(@src(), journal.frame == null and journal.retired_valid == 0 and journal.disabled == 0);
    check(@src(), n.npc_input_begin(&journal, frame, 1) == 1);
    state(&journal, 2, 1, 1, 0, 0, 1);
    check(@src(), journal.frame == frame);
    phase = 2;
    var entry = std.mem.zeroes(p.SyncActorInput);
    entry.slot = 7;
    entry.generation = 9;
    entry.held = 3;
    entry.pressed = 1;
    check(@src(), n.npc_input_record(&journal, &entry) == 1 and frame.actor_input_count == 1 and std.mem.eql(u8, std.mem.asBytes(&frame.actor_inputs[0]), std.mem.asBytes(&entry)));
    state(&journal, 2, 1, 1, 0, 0, 1);
    phase = 3;
    check(@src(), n.npc_input_finish(&journal) == 1);
    check(@src(), n.npc_input_abort_cohort(&journal, &active) == 1);
    state(&journal, 3, 0, 1, 1, 0, 1);
    check(@src(), journal.frame == null and journal.retired_valid == 1 and @import("validation.zig").equal(&journal.retired, &active));
    phase = 1;
    check(@src(), n.npc_input_bind_cohort(&journal, &active) == 0);
    active.cohort_nonce += 1;
    check(@src(), n.npc_input_bind_cohort(&journal, &active) == 1);
    state(&journal, 4, 1, 0, 0, 0, 1);
    check(@src(), n.npc_input_begin(&journal, frame, 0) == 1);
    state(&journal, 5, 1, 1, 0, 0, 0);
    phase = 2;
    check(@src(), n.npc_input_peek(&journal) == &frame.actor_inputs[0]);
    var scope = std.mem.zeroes(n.Scope);
    var held: u32 = 10;
    var pressed: u32 = 11;
    check(@src(), n.npc_input_apply(&journal, n.npc_input_peek(&journal), 1, &held, &pressed, &scope) == 1 and held == 3 and pressed == 1);
    state(&journal, 5, 1, 1, 0, 1, 0);
    check(@src(), scope.applied == 1 and scope.held == 10 and scope.pressed == 11 and scope.journal == &journal and scope.nonce == 5 and scope.held_local == @intFromPtr(&held) and scope.pressed_local == @intFromPtr(&pressed) and @import("validation.zig").equal(&scope.cohort, &active));
    check(@src(), n.npc_input_restore(&scope, &held, &pressed) == 1 and held == 10 and pressed == 11);
    var other: u32 = 77;
    check(@src(), n.npc_input_restore(&scope, &other, &pressed) == 0 and other == 77);
    phase = 3;
    check(@src(), n.npc_input_finish(&journal) == 1 and n.npc_input_abort_cohort(&journal, &active) == 1);
    state(&journal, 6, 0, 1, 1, 1, 0);
    phase = 2;
    check(@src(), n.npc_input_restore(&scope, &held, &pressed) == 0);
    phase = 1;
    active.cohort_nonce += 1;
    journal.nonce = 0xfffffffe;
    check(@src(), n.npc_input_bind_cohort(&journal, &active) == 1 and journal.nonce == 0xffffffff);
    cancellation = 0;
    valid = true;
    check(@src(), n.npc_input_begin(&journal, frame, 0) == 0 and cancellation == 0x80000 and journal.disabled == 1 and journal.started == 0 and !valid);
}
