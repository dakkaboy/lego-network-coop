const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const Machine = @import("machine_environment.zig").Environment;
const read = s.read;
const native: *const fn (usize, usize, u32, u32, u32, u32) callconv(.c) u32 = @ptrFromInt(0x96a4c0);
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
const Hit = struct { attacker: usize, victim: usize, previous_attacker: usize, previous_victim: usize };
fn invoke(context: usize) callconv(.c) usize {
    const invocation: *const Hit = @ptrFromInt(context);
    return native(invocation.attacker, invocation.victim, 1, 0x400000, 0, 1);
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const invocation: *const Hit = @ptrFromInt(context);
    s.attacker = invocation.previous_attacker;
    s.victim = invocation.previous_victim;
}
fn hit(attacker: usize, victim: usize) void {
    const context: Hit = .{ .attacker = attacker, .victim = victim, .previous_attacker = s.attacker, .previous_victim = s.victim };
    s.attacker = attacker;
    s.victim = victim;
    _ = constructor_lexical_seh(@intFromPtr(&context), invoke, abort);
    s.attacker = context.previous_attacker;
    s.victim = context.previous_victim;
}
fn replay(op: *const s.Lease, entry: *const p.SyncReactionChoice) bool {
    const attacker = s.entities_actor(entry.payload.clip.arena_attacker_slot, entry.payload.clip.arena_attacker_generation);
    const victim = s.entities_actor(entry.slot, entry.generation);
    if (!s.live(op) or !s.valid(attacker, 0x1440) or !s.valid(victim, 0x1440) or read(i16, victim + 0xdc0) != entry.character or read(i16, victim + 0x2f4) != entry.old_action) return false;
    const cursor = s.journal.cursor;
    hit(attacker, victim);
    const no_clip = entry.payload.clip.selection.clip == -2;
    if (!s.live(op) or s.journal.failed != 0 or s.journal.cursor != cursor + @intFromBool(!no_clip) or s.entities_actor(entry.slot, entry.generation) != victim or !s.live(op)) return false;
    if (no_clip) s.journal.cursor += 1;
    s.win.store(f32, victim + 0xd3c, 2.5);
    return true;
}
pub export fn reaction_drain_arena() c_int {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return 0;
    if (s.journal.host != 0 or s.journal.frame.?.level != 12) return 1;
    while (s.journal.peek()) |entry| {
        if (entry.kind != p.SYNC_REACTION_CLIP or entry.payload.clip.arena_attacker_generation == 0) break;
        if (!replay(&op, entry)) {
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
        _ = native(attacker, victim, 1, 0x400000, 0, 1);
        return 1;
    }
    if (s.journal.host == 0) {
        if (s.journal.peek()) |e| if (e.kind == p.SYNC_REACTION_CLIP and e.payload.clip.arena_attacker_generation != 0 and s.entities_actor(e.slot, e.generation) == victim and s.entities_actor(e.payload.clip.arena_attacker_slot, e.payload.clip.arena_attacker_generation) == attacker and !replay(&op, e) and s.live(&op)) {
            s.journal.failed = 8;
            s.failed(&op, victim, e, 0, 0, 8, std.math.maxInt(u32));
        };
        return 0;
    }
    const before = s.journal.frame.?.reaction_count;
    var identity = std.mem.zeroes(p.SyncActor);
    s.entities_update();
    if (!s.live(&op)) return 0;
    s.entities_describe(&identity, victim);
    if (!s.live(&op)) return 0;
    var marker = std.mem.zeroes(p.SyncReactionChoice);
    s.describe(&marker, victim, &identity, s.entities_slot(victim), read(i16, victim + 0x2f4));
    marker.payload.clip.selection.clip = -2;
    if (s.entities_observed_identity(attacker, &marker.payload.clip.arena_attacker_slot, &marker.payload.clip.arena_attacker_generation) == 0 or !s.live(&op) or !validation.valid(&marker)) {
        if (s.live(&op)) {
            s.journal.failed = 8;
            s.failed(&op, victim, null, 0, 0, 8, std.math.maxInt(u32));
        }
        return 0;
    }
    hit(attacker, victim);
    if (!s.live(&op)) return 0;
    if (s.journal.failed == 0 and s.journal.frame.?.reaction_count == before) {
        if (s.reaction_journal_record(&s.journal, &marker) != 0) {
            s.clonewars_reaction_debug[0] +%= 1;
            return 1;
        }
    }
    if (s.journal.failed != 0 or s.journal.frame.?.reaction_count != before + 1 or s.journal.frame.?.reactions[before].payload.clip.arena_attacker_generation == 0) {
        s.journal.failed = 8;
        s.failed(&op, victim, null, 0, 0, 8, std.math.maxInt(u32));
        return 0;
    }
    return 1;
}
