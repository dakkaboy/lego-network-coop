const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const equal = @import("validation.zig").equal;
pub const Journal = extern struct {
    frame: ?*p.SyncFrame,
    cursor: u32,
    host: c_int,
    failed: c_int,
    cohort: Token,
    nonce: u32,
    bound: u32,
    cancelled: u32,
    disabled: u32,
    started: u32,
    retired: Token,
    retired_valid: u32,
};
pub const Scope = extern struct { held: u32, pressed: u32, applied: c_int, journal: ?*Journal, cohort: Token, nonce: u32, held_local: usize, pressed_local: usize };
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn coherent_frame_cancel_atomic(u32) void;
pub export fn npc_input_cohort_valid(journal: ?*const Journal, token: ?*const Token, phases: u32) c_int {
    const j = journal orelse return 0;
    const t = token orelse return 0;
    return @intFromBool(j.bound != 0 and j.disabled == 0 and j.cancelled == 0 and equal(&j.cohort, t) and coherent_frame_valid(t, phases) != 0);
}
pub export fn npc_input_bind_cohort(journal: ?*Journal, token: ?*const Token) c_int {
    const j = journal orelse return 0;
    const t = token orelse return 0;
    if (j.disabled != 0 or coherent_frame_valid(t, 2) == 0 or (j.retired_valid != 0 and equal(t, &j.retired))) return 0;
    if (j.bound != 0 and equal(&j.cohort, t)) return npc_input_cohort_valid(j, t, 2);
    if (j.bound != 0 and !equal(&j.cohort, t) and coherent_frame_valid(&j.cohort, 0x3e) != 0) return 0;
    if (j.nonce == 0xffffffff) {
        j.disabled = 1;
        return 0;
    }
    j.nonce += 1;
    j.cohort = t.*;
    j.bound = 1;
    j.cancelled = 0;
    j.started = 0;
    j.frame = null;
    return 1;
}
pub export fn npc_input_abort_cohort(journal: ?*Journal, token: ?*const Token) c_int {
    const j = journal orelse return 0;
    const t = token orelse return 0;
    if (j.bound == 0 or t.thread != win.GetCurrentThreadId() or !equal(&j.cohort, t)) return 0;
    if (j.nonce == 0xffffffff) j.disabled = 1 else j.nonce += 1;
    j.retired = t.*;
    j.retired_valid = 1;
    j.bound = 0;
    j.frame = null;
    j.cancelled = 1;
    return 1;
}
fn live(journal: ?*const Journal, phases: u32) bool {
    const j = journal orelse return false;
    return j.started != 0 and j.frame != null and j.cancelled == 0 and npc_input_cohort_valid(j, &j.cohort, phases) != 0 and @intFromPtr(j.frame.?) == j.cohort.frame;
}
pub export fn npc_input_begin(journal: ?*Journal, frame: ?*p.SyncFrame, host: c_int) c_int {
    const j = journal orelse return 0;
    if (npc_input_cohort_valid(j, &j.cohort, 2) == 0) return 0;
    const address = if (frame) |f| @intFromPtr(f) else 0;
    if (address != j.cohort.frame or j.started != 0) {
        j.cancelled = 1;
        coherent_frame_cancel_atomic(0x40000);
        return 0;
    }
    if (j.nonce == 0xffffffff) {
        j.disabled = 1;
        coherent_frame_cancel_atomic(0x80000);
        return 0;
    }
    j.nonce += 1;
    j.frame = frame;
    j.cursor = 0;
    j.host = host;
    j.failed = 0;
    j.cancelled = 0;
    j.started = 1;
    if (host != 0) frame.?.actor_input_count = 0;
    return 1;
}
pub export fn npc_input_record(journal: ?*Journal, entry: ?*const p.SyncActorInput) c_int {
    if (!live(journal, 4)) return 0;
    const j = journal.?;
    const f = j.frame.?;
    if (j.failed != 0 or j.host == 0 or f.actor_input_count >= p.SYNC_MAX_ACTORS or entry == null or entry.?.slot >= p.SYNC_MAX_ACTORS or entry.?.generation == 0) {
        j.failed = 1;
        return 0;
    }
    f.actor_inputs[f.actor_input_count] = entry.?.*;
    f.actor_input_count += 1;
    return 1;
}
pub export fn npc_input_peek(journal: ?*const Journal) ?*const p.SyncActorInput {
    if (!live(journal, 4)) return null;
    const j = journal.?;
    const f = j.frame.?;
    return if (j.failed == 0 and f.actor_input_count <= p.SYNC_MAX_ACTORS and j.cursor < f.actor_input_count) &f.actor_inputs[j.cursor] else null;
}
pub export fn npc_input_scope_valid(scope: ?*const Scope) c_int {
    const s = scope orelse return 0;
    if (s.applied == 0 or coherent_frame_valid(&s.cohort, 4) == 0) return 0;
    const j = s.journal orelse return 0;
    return @intFromBool(live(j, 4) and s.nonce == j.nonce and equal(&s.cohort, &j.cohort));
}
pub export fn npc_input_scope_capture(journal: ?*Journal, held: ?*const u32, pressed: ?*const u32, output: ?*Scope) c_int {
    const out = output orelse return 0;
    out.* = std.mem.zeroes(Scope);
    if (held == null or pressed == null or !live(journal, 4)) return 0;
    const j = journal.?;
    out.* = .{ .cohort = j.cohort, .journal = j, .nonce = j.nonce, .held_local = @intFromPtr(held.?), .pressed_local = @intFromPtr(pressed.?), .held = held.?.*, .pressed = pressed.?.*, .applied = 1 };
    return npc_input_scope_valid(out);
}
pub export fn npc_input_apply(journal: ?*Journal, entry: ?*const p.SyncActorInput, owner_matches: c_int, held: ?*u32, pressed: ?*u32, output: ?*Scope) c_int {
    const out = output orelse return 0;
    out.* = std.mem.zeroes(Scope);
    if (!live(journal, 4)) return 0;
    const j = journal.?;
    if (j.failed != 0 or j.host != 0 or entry == null or entry != npc_input_peek(j) or owner_matches == 0) {
        j.failed = 1;
        return 0;
    }
    if (npc_input_scope_capture(j, held, pressed, out) == 0) return 0;
    held.?.* = entry.?.held;
    pressed.?.* = entry.?.pressed;
    j.cursor += 1;
    return 1;
}
pub export fn npc_input_restore(scope: ?*const Scope, held: ?*u32, pressed: ?*u32) c_int {
    if (npc_input_scope_valid(scope) == 0 or held == null or pressed == null) return 0;
    const s = scope.?;
    if (@intFromPtr(held.?) != s.held_local or @intFromPtr(pressed.?) != s.pressed_local) return 0;
    held.?.* = s.held;
    pressed.?.* = s.pressed;
    return 1;
}
pub export fn npc_input_finish(journal: ?*const Journal) c_int {
    if (!live(journal, 8)) return 0;
    const j = journal.?;
    const frame = j.frame.?;
    return @intFromBool(j.failed == 0 and frame.actor_input_count <= p.SYNC_MAX_ACTORS and (j.host != 0 or j.cursor == frame.actor_input_count));
}
