const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const read = s.read;
fn blockedByCooldown(hit: *const p.SyncReactionHitOutcome) bool {
    return hit.timer_before > 0 and hit.timer_before == hit.timer_after and
        hit.health_before > 0 and hit.health_before == hit.health_after and
        hit.life_before == hit.life_after and hit.action_before == hit.action_after;
}
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
            if (s.journal.host == 0 and s.journal.frame.?.level == 79 and std.math.isFinite(receipt.hit.timer_before)) {
                if (s.journal.peek()) |entry| {
                    if (entry.kind != p.SYNC_REACTION_CLIP or entry.slot != receipt.slot or entry.generation != receipt.generation) return;
                    const clip = &entry.payload.clip;
                    const hit = &clip.hit;
                    const expired = receipt.hit.timer_before > 0 and hit.timer_before <= 0 and hit.health_after < hit.health_before;
                    const blocked = s.combat_damage_native_caller() == 0x81f27f and blockedByCooldown(hit);
                    if (clip.selection.clip == -1 and clip.source_id == source and clip.arena_attacker_generation == 0 and
                        (expired or blocked) and validation.valid(entry) and
                        hit.health_before == receipt.hit.health_before and hit.life_before == receipt.hit.life_before and
                        hit.action_before == receipt.hit.action_before and s.live(&receipt.lease))
                    {
                        receipt.hit.timer_before = hit.timer_before;
                        s.win.store(f32, actor + 0xd3c, hit.timer_before);
                    }
                }
            }
        }
    }
}
pub export var clonewars_projectile_damage_corrections: u32 = 0;
pub export fn reaction_projectile_damage_amount(actor: usize, amount: c_int) c_int {
    if (amount < 0 or s.combat_damage_native_caller() != 0x81f27f) return amount;
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active or s.journal.host != 0 or s.journal.failed != 0 or s.journal.frame.?.level != 79 or !s.valid(actor, 0x1440)) return amount;
    const entry = s.journal.peek() orelse return amount;
    if (entry.kind != p.SYNC_REACTION_CLIP or !validation.valid(entry)) return amount;
    const clip = &entry.payload.clip;
    const hit = &clip.hit;
    if (clip.selection.clip != -1 or clip.arena_attacker_generation != 0 or clip.source_id == 0 or clip.source_id != s.combat_damage_source_id() or
        !validation.hitValid(hit) or hit.health_after <= 0 or
        hit.life_before != hit.life_after or hit.action_before != hit.action_after) return amount;
    const damage = hit.health_before - hit.health_after;
    const corrected: c_int = if (amount == 0 and damage >= 1 and damage <= 2 and hit.timer_before <= 0 and hit.timer_after > 0)
        damage
    else if (amount > 0 and hit.health_before == 1 and hit.health_after == 1 and hit.timer_before == hit.timer_after)
        0
    else
        return amount;
    const identity = s.identity(entry);
    if (s.entities_resolve_reference(&identity) != actor or !s.live(&op)) return amount;
    if (read(i8, actor + 0xdde) != hit.health_before or
        (read(u32, actor + 0x50) & 3) | (@as(u32, read(u8, actor + 0x54)) << 8) != hit.life_before or
        read(i16, actor + 0x2f4) != hit.action_before) return amount;
    const timer = read(f32, actor + 0xd3c);
    if (!(timer == hit.timer_before or (timer <= 0 and hit.timer_before <= 0))) return amount;
    clonewars_projectile_damage_corrections +%= 1;
    return corrected;
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
            const last_health_point = actual.health_before == 1 and actual.health_after == 1 and
                actual.life_before == actual.life_after and actual.action_before == actual.action_after and actual.timer_before == actual.timer_after;
            // The native hit can finish without selecting a clip when damage is blocked.
            if (i == receipt.cursor and s.journal.frame.?.level == 79 and s.combat_damage_native_caller() == 0x81f27f and
                (last_health_point or blockedByCooldown(&actual)))
            {
                var identity = std.mem.zeroes(p.SyncActor);
                s.entities_describe(&identity, actor);
                if (!s.live(&receipt.lease)) return;
                var entry = std.mem.zeroes(p.SyncReactionChoice);
                if (identity.generation != receipt.generation) {
                    s.failed(&receipt.lease, actor, null, actual.action_before, receipt.source_id, 6, std.math.maxInt(u32));
                    return;
                }
                s.describe(&entry, actor, &identity, @intCast(receipt.slot), actual.action_before);
                entry.payload.clip.selection.clip = -1;
                entry.payload.clip.source_id = receipt.source_id;
                entry.payload.clip.hit = actual;
                if (s.reaction_journal_record(&s.journal, &entry) == 0) {
                    s.failed(&receipt.lease, actor, &entry, actual.action_before, receipt.source_id, 6, std.math.maxInt(u32));
                }
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
