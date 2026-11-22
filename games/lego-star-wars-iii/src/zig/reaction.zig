const p = @import("protocol.zig");
pub const Journal = @import("journal.zig").Journal("reactions", "reaction_count");

pub const valid = @import("reaction_validation.zig").valid;
const projectileHitSame = @import("reaction_validation.zig").projectileHitSame;
pub export fn reaction_journal_begin(j: *Journal, frame: *p.SyncFrame, host: c_int) void {
    j.begin(frame, host);
    if (host != 0) frame.reaction_reserved = 0;
}
pub export fn reaction_journal_record(j: *Journal, entry: ?*const p.SyncReactionChoice) c_int {
    return j.record(entry, valid, 6);
}
pub export fn reaction_journal_peek(j: *const Journal) ?*const p.SyncReactionChoice {
    return j.peek();
}
pub export fn reaction_journal_finish(j: *const Journal) c_int {
    return j.finish();
}
pub export fn reaction_journal_apply(j: *Journal, entry: ?*const p.SyncReactionChoice, owner_matches: c_int, old_action: c_int, source: u32, available: c_int, clip: *u32) c_int {
    if (j.failed != 0) return 0;
    if (entry == null or entry != j.peek()) return j.fail(1);
    if (owner_matches == 0) return j.fail(2);
    const e = entry.?;
    if (e.old_action != old_action) return j.fail(3);
    if (e.payload.clip.source_id != source) return j.fail(4);
    if (!valid(e) or e.kind != p.SYNC_REACTION_CLIP or e.payload.clip.selection.clip == -2 or available == 0) return j.fail(5);
    clip.* = @bitCast(e.payload.clip.selection.clip);
    j.cursor += 1;
    return 1;
}
pub export fn reaction_journal_complete_no_clip(journal: ?*Journal, begin: u32, slot: u32, generation: u32, source: u32, actual: ?*const p.SyncReactionHitOutcome) c_int {
    const j = journal orelse return 0;
    if (j.host != 0 or j.failed != 0 or source == 0 or generation == 0 or begin > j.cursor or j.cursor > j.frame.?.reaction_count or j.cursor > p.SYNC_MAX_ACTORS) return 0;
    for (j.frame.?.reactions[begin..j.cursor]) |*e| {
        if (e.kind == p.SYNC_REACTION_CLIP and e.slot == slot and e.generation == generation and e.payload.clip.source_id == source) {
            if (e.payload.clip.hit.completed != 0 and !projectileHitSame(&e.payload.clip.hit, actual)) {
                j.failed = 11;
                return -1;
            }
            return 0;
        }
    }
    const e = j.peek() orelse return 0;
    const clip = &e.payload.clip;
    if (!valid(e) or e.kind != p.SYNC_REACTION_CLIP or clip.selection.clip != -1 or clip.arena_attacker_generation != 0 or
        e.slot != slot or e.generation != generation or clip.source_id != source or clip.hit.completed == 0) return 0;
    if (!projectileHitSame(&clip.hit, actual)) {
        j.failed = 11;
        return -1;
    }
    j.cursor += 1;
    return 1;
}
