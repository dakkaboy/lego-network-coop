const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const read = s.read;
pub export fn reaction_damage_begin(receipt: *s.Receipt, actor: usize, source: u32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    receipt.* = std.mem.zeroes(s.Receipt);
    if (source != 0 and s.get(&receipt.lease) and s.active and s.journal.failed == 0 and s.valid(actor, 0x1440) and s.entities_observed_identity(actor, &receipt.slot, &receipt.generation) != 0 and s.live(&receipt.lease)) {
        receipt.local_generation = s.entities_observed_generation(actor);
        if (s.entities_allocation_retained(actor, receipt.local_generation) != 0) {
            receipt.cursor = if (s.journal.host != 0) s.journal.frame.?.reaction_count else s.journal.cursor;
            receipt.source_id = source;
            receipt.actor = actor;
            receipt.valid = 1;
            receipt.hit.completed = 1;
            receipt.hit.health_before = read(i8, actor + 0xdde);
            receipt.hit.life_before = (read(u32, actor + 0x50) & 3) | (@as(u32, read(u8, actor + 0x54)) << 8);
            receipt.hit.action_before = read(i16, actor + 0x2f4);
            receipt.hit.timer_before = read(f32, actor + 0xd3c);
        }
    }
}
pub export fn reaction_damage_complete(receipt: *const s.Receipt) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (receipt.valid == 0 or !s.active or !s.live(&receipt.lease)) return;
    var actual = receipt.hit;
    const actor = receipt.actor;
    if (s.entities_allocation_retained(actor, receipt.local_generation) != 0 and s.valid(actor, 0x1440)) {
        actual.health_after = read(i8, actor + 0xdde);
        actual.life_after = (read(u32, actor + 0x50) & 3) | (@as(u32, read(u8, actor + 0x54)) << 8);
        actual.action_after = read(i16, actor + 0x2f4);
        actual.timer_after = read(f32, actor + 0xd3c);
    }
    if (s.journal.host != 0) {
        if (validation.hitValid(&actual)) {
            var i = receipt.cursor;
            while (i < s.journal.frame.?.reaction_count) : (i += 1) {
                const e = &s.journal.frame.?.reactions[i];
                const clip = &e.payload.clip;
                if (e.kind == p.SYNC_REACTION_CLIP and clip.selection.clip == -1 and clip.arena_attacker_generation == 0 and e.slot == receipt.slot and e.generation == receipt.generation and clip.source_id == receipt.source_id) clip.hit = actual;
            }
        }
        return;
    }
    var expected = s.journal.peek();
    var i = receipt.cursor;
    while (i < s.journal.cursor) : (i += 1) {
        const e = &s.journal.frame.?.reactions[i];
        if (e.kind == p.SYNC_REACTION_CLIP and e.payload.clip.hit.completed != 0 and e.slot == receipt.slot and e.generation == receipt.generation and e.payload.clip.source_id == receipt.source_id and !validation.projectileHitSame(&e.payload.clip.hit, &actual)) {
            expected = e;
            break;
        }
    }
    const accepted = s.reaction_journal_complete_no_clip(&s.journal, receipt.cursor, receipt.slot, receipt.generation, receipt.source_id, &actual);
    if (accepted < 0) {
        s.clonewars_reaction_receipt_debug[8] +%= 1;
        s.clonewars_reaction_hit_actual = actual;
        if (expected) |e| s.clonewars_reaction_hit_expected = e.payload.clip.hit;
        s.failed(&receipt.lease, 0, expected, 0, receipt.source_id, 11, std.math.maxInt(u32));
    } else if (accepted > 0) {
        s.clonewars_reaction_receipt_debug[2] +%= 1;
        if (s.clonewars_reaction_receipt_debug[3] == 0) s.clonewars_reaction_receipt_debug[3..8].* = .{ receipt.lease.cohort.epoch, receipt.lease.cohort.sequence, receipt.slot, receipt.generation, receipt.source_id };
    }
}
