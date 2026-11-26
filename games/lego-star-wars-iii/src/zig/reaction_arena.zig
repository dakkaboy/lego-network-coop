const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const Machine = @import("machine_environment.zig").Environment;
const read = s.read;
const native: *const fn (usize, usize, u32, u32, u32, u32) callconv(.c) u32 = @ptrFromInt(0x96a4c0);
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
const arena_hit_flags = 0x400000;
const lift_hit_flags = 0x100010a;
const Hit = struct { attacker: usize, victim: usize, flags: u32, previous_attacker: usize, previous_victim: usize };
pub export var clonewars_arena_hit_debug: [6]u32 = @splat(0);
pub export var clonewars_arena_hit_failure: [12]u32 = @splat(0);
fn beforeHit(actor: usize) p.SyncReactionHitOutcome {
    return .{ .completed = 1, .health_before = read(i8, actor + 0xdde), .health_after = 0, .life_before = (read(u32, actor + 0x50) & 3) | (@as(u32, read(u8, actor + 0x54)) << 8), .life_after = 0, .action_before = read(i16, actor + 0x2f4), .action_after = 0, .timer_before = read(f32, actor + 0xd3c), .timer_after = 0 };
}
fn completeHit(outcome: *p.SyncReactionHitOutcome, actor: usize, generation: u32) void {
    if (s.entities_allocation_retained(actor, generation) == 0 or !s.valid(actor, 0x1440)) return;
    outcome.health_after = read(i8, actor + 0xdde);
    outcome.life_after = (read(u32, actor + 0x50) & 3) | (@as(u32, read(u8, actor + 0x54)) << 8);
    outcome.action_after = read(i16, actor + 0x2f4);
    outcome.timer_after = read(f32, actor + 0xd3c);
}
fn sameBefore(a: *const p.SyncReactionHitOutcome, b: *const p.SyncReactionHitOutcome) bool {
    return a.health_before == b.health_before and a.life_before == b.life_before and a.action_before == b.action_before and a.timer_before == b.timer_before;
}
fn failure(reason: u32, op: *const s.Lease, entry: *const p.SyncReactionChoice, actual: ?*const p.SyncReactionHitOutcome) ?u32 {
    if (s.live(op) and clonewars_arena_hit_failure[0] == 0) {
        const h = &entry.payload.clip.hit;
        clonewars_arena_hit_failure = .{ reason, op.cohort.sequence, entry.slot, entry.generation, @bitCast(h.action_before), if (actual) |a| @bitCast(a.action_before) else 0, @bitCast(entry.old_action), @bitCast(h.health_before), if (actual) |a| @bitCast(a.health_before) else 0, @bitCast(h.timer_before), if (actual) |a| @bitCast(a.timer_before) else 0, h.completed };
    }
    return null;
}
fn invoke(context: usize) callconv(.c) usize {
    const invocation: *const Hit = @ptrFromInt(context);
    return native(invocation.attacker, invocation.victim, 1, invocation.flags, 0, 1);
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const invocation: *const Hit = @ptrFromInt(context);
    s.attacker = invocation.previous_attacker;
    s.victim = invocation.previous_victim;
}
fn hit(attacker: usize, victim: usize, flags: u32) u32 {
    const context: Hit = .{ .attacker = attacker, .victim = victim, .flags = flags, .previous_attacker = s.attacker, .previous_victim = s.victim };
    s.attacker = attacker;
    s.victim = victim;
    const result = constructor_lexical_seh(@intFromPtr(&context), invoke, abort);
    s.attacker = context.previous_attacker;
    s.victim = context.previous_victim;
    return @intCast(result);
}
fn liftActors(attacker: usize, victim: usize) bool {
    return s.valid(attacker, 0x1440) and s.valid(victim, 0x1440) and
        read(i16, attacker + 0xdc0) == 184 and read(i16, victim + 0xdc0) == 321 and
        read(f32, attacker + 0x24) > 30 and read(f32, victim + 0x24) > 30;
}
fn replay(op: *const s.Lease, entry: *const p.SyncReactionChoice, flags: u32) ?u32 {
    const attacker = s.entities_actor(entry.payload.clip.arena_attacker_slot, entry.payload.clip.arena_attacker_generation);
    const victim = s.entities_actor(entry.slot, entry.generation);
    if (!s.live(op) or !s.valid(attacker, 0x1440) or !s.valid(victim, 0x1440) or read(i16, victim + 0xdc0) != entry.character or
        (flags == lift_hit_flags and !liftActors(attacker, victim)))
    {
        return failure(1, op, entry, null);
    }
    var actual = beforeHit(victim);
    const recorded = &entry.payload.clip.hit;
    if (recorded.completed != 0) {
        if (flags == lift_hit_flags and actual.timer_before <= 0 and recorded.timer_before <= 0) actual.timer_before = recorded.timer_before;
        if (!validation.hitValid(recorded) or !sameBefore(&actual, recorded)) {
            return failure(2, op, entry, &actual);
        }
    } else if (read(i16, victim + 0x2f4) != entry.old_action) {
        return failure(3, op, entry, &actual);
    }
    const generation = s.entities_observed_generation(victim);
    if (generation == 0 or s.entities_allocation_retained(victim, generation) == 0 or !s.live(op)) {
        return failure(4, op, entry, &actual);
    }
    const cursor = s.journal.cursor;
    const result = hit(attacker, victim, flags);
    const no_clip = entry.payload.clip.selection.clip == -2;
    if (!s.live(op) or s.journal.failed != 0 or s.journal.cursor != cursor + @intFromBool(!no_clip) or s.entities_actor(entry.slot, entry.generation) != victim or !s.live(op)) return null;
    completeHit(&actual, victim, generation);
    if (flags == lift_hit_flags and actual.timer_after <= 0 and recorded.timer_after <= 0) actual.timer_after = recorded.timer_after;
    if (recorded.completed != 0 and !validation.hitSame(&actual, recorded)) {
        return failure(5, op, entry, &actual);
    }
    clonewars_arena_hit_debug[1] +%= 1;
    if (no_clip) s.journal.cursor += 1;
    if (flags == arena_hit_flags) s.win.store(f32, victim + 0xd3c, 2.5);
    return result;
}
pub export fn reaction_drain_contact_hits() c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return 0;
    if (s.journal.host != 0) return 1;
    const flags: u32 = switch (s.journal.frame.?.level) {
        12 => arena_hit_flags,
        74 => lift_hit_flags,
        else => return 1,
    };
    while (s.journal.peek()) |entry| {
        if (entry.kind != p.SYNC_REACTION_CLIP or entry.payload.clip.arena_attacker_generation == 0) break;
        if (replay(&op, entry, flags) == null) {
            if (s.live(&op)) {
                s.journal.failed = 8;
                s.failed(&op, 0, entry, 0, 0, 8, std.math.maxInt(u32));
            }
            return 0;
        }
    }
    return @intFromBool(s.journal.failed == 0);
}
pub export fn reaction_arena_contact_hit(attacker: usize, victim: usize) c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active or s.journal.frame.?.level != 12) {
        _ = native(attacker, victim, 1, arena_hit_flags, 0, 1);
        return 1;
    }
    if (!s.valid(attacker, 0x1440) or !s.valid(victim, 0x1440)) {
        s.journal.failed = 8;
        s.failed(&op, 0, null, 0, 0, 8, std.math.maxInt(u32));
        return 0;
    }
    if (s.journal.host == 0) {
        if (s.journal.peek()) |e| if (e.kind == p.SYNC_REACTION_CLIP and e.payload.clip.arena_attacker_generation != 0 and s.entities_actor(e.slot, e.generation) == victim and s.entities_actor(e.payload.clip.arena_attacker_slot, e.payload.clip.arena_attacker_generation) == attacker and replay(&op, e, arena_hit_flags) == null and s.live(&op)) {
            s.journal.failed = 8;
            s.failed(&op, victim, e, 0, 0, 8, std.math.maxInt(u32));
        };
        return 0;
    }
    return @intFromBool(record(&op, attacker, victim, arena_hit_flags) != null);
}

pub fn liftContact(attacker: usize, victim: usize, amount: u32, flags: u32, reserved: u32, effect: u32) callconv(.c) u32 {
    var op: s.Lease = undefined;
    if (amount != 1 or flags != lift_hit_flags or reserved != 0 or effect != 1 or !s.get(&op) or !s.active or
        s.journal.frame.?.level != 74 or !liftActors(attacker, victim)) return native(attacker, victim, amount, flags, reserved, effect);
    if (s.journal.host != 0) return record(&op, attacker, victim, flags) orelse 0;
    const entry = s.journal.peek() orelse return 0;
    if (entry.kind != p.SYNC_REACTION_CLIP or entry.payload.clip.arena_attacker_generation == 0 or
        s.entities_actor(entry.slot, entry.generation) != victim or
        s.entities_actor(entry.payload.clip.arena_attacker_slot, entry.payload.clip.arena_attacker_generation) != attacker) return 0;
    if (replay(&op, entry, flags)) |result| return result;
    if (s.live(&op)) {
        s.journal.failed = 8;
        s.failed(&op, victim, entry, 0, 0, 8, std.math.maxInt(u32));
    }
    return 0;
}

fn record(op: *const s.Lease, attacker: usize, victim: usize, flags: u32) ?u32 {
    const before = s.journal.frame.?.reaction_count;
    var identity = std.mem.zeroes(p.SyncActor);
    s.entities_update();
    if (!s.live(op)) return null;
    s.entities_describe(&identity, victim);
    if (!s.live(op)) return null;
    var marker = std.mem.zeroes(p.SyncReactionChoice);
    s.describe(&marker, victim, &identity, s.entities_slot(victim), read(i16, victim + 0x2f4));
    marker.payload.clip.selection.clip = -2;
    const generation = s.entities_observed_generation(victim);
    var outcome = beforeHit(victim);
    if (!s.live(op)) return null;
    if (generation == 0 or s.entities_allocation_retained(victim, generation) == 0 or !validation.hitValid(&outcome)) {
        s.journal.failed = 8;
        s.failed(op, victim, &marker, 0, 0, 8, std.math.maxInt(u32));
        return null;
    }
    if (s.entities_observed_identity(attacker, &marker.payload.clip.arena_attacker_slot, &marker.payload.clip.arena_attacker_generation) == 0 or !s.live(op) or !validation.valid(&marker)) {
        if (s.live(op)) {
            s.journal.failed = 8;
            s.failed(op, victim, null, 0, 0, 8, std.math.maxInt(u32));
        }
        return null;
    }
    const result = hit(attacker, victim, flags);
    if (!s.live(op)) return null;
    completeHit(&outcome, victim, generation);
    if (!validation.hitValid(&outcome)) {
        s.journal.failed = 8;
        s.failed(op, victim, null, 0, 0, 8, std.math.maxInt(u32));
        return null;
    }
    clonewars_arena_hit_debug[0] +%= 1;
    if (outcome.action_before != outcome.action_after) clonewars_arena_hit_debug[2] +%= 1;
    marker.payload.clip.hit = outcome;
    if (s.journal.failed == 0 and s.journal.frame.?.reaction_count == before) {
        if (s.reaction_journal_record(&s.journal, &marker) != 0) {
            s.clonewars_reaction_debug[0] +%= 1;
            return result;
        }
    }
    if (s.journal.failed != 0 or s.journal.frame.?.reaction_count != before + 1 or s.journal.frame.?.reactions[before].payload.clip.arena_attacker_generation == 0) {
        s.journal.failed = 8;
        s.failed(op, victim, null, 0, 0, 8, std.math.maxInt(u32));
        return null;
    }
    const entry = &s.journal.frame.?.reactions[before];
    entry.payload.clip.hit = outcome;
    if (!validation.valid(entry)) {
        s.journal.failed = 8;
        s.failed(op, victim, entry, 0, 0, 8, std.math.maxInt(u32));
        return null;
    }
    if (outcome.action_before != entry.old_action) clonewars_arena_hit_debug[3] +%= 1;
    return result;
}
