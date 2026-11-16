const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const read = s.read;
pub export fn reaction_client_duplicate_projectile(actor: usize, source: u32) c_int {
    var op: s.Lease = undefined;
    if (source == 0 or !s.get(&op) or !s.active or s.journal.host != 0 or s.journal.failed != 0 or s.journal.cursor == 0 or s.journal.cursor != s.journal.frame.?.reaction_count) return 0;
    const previous = &s.journal.frame.?.reactions[s.journal.cursor - 1];
    var slot: u32 = undefined;
    var generation: u32 = undefined;
    return @intFromBool(previous.kind == p.SYNC_REACTION_CLIP and previous.payload.clip.source_id == source and s.entities_observed_identity(actor, &slot, &generation) != 0 and s.live(&op) and slot == previous.slot and generation == previous.generation);
}
fn available(actor: usize, clip: i32) bool {
    const resource = read(usize, actor + 0xf04);
    const native: *const fn (usize, i32) callconv(.c) u8 = @ptrFromInt(0x8a8e70);
    return s.valid(resource, 0x10) and native(resource, clip) != 0;
}
pub export fn reaction_apply_choice(actor: usize, output: *u32) void {
    var op: s.Lease = undefined;
    if (!s.get(&op)) return;
    if (!s.active) {
        s.clonewars_reaction_debug[4] +%= 1;
        return;
    }
    if (s.journal.failed != 0) return;
    if (!s.valid(actor, 0x1440) or !s.valid(@intFromPtr(output), 4)) {
        s.journal.failed = 5;
        s.failed(&op, actor, null, 0, 0, 5, std.math.maxInt(u32));
        return;
    }
    const action: i32 = read(i16, actor + 0x2f4);
    const source = s.combat_damage_source_id();
    if (!s.live(&op)) return;
    const local_clip = output.*;
    if (s.attacker == 0 and local_clip == std.math.maxInt(u32)) {
        if (s.journal.host != 0 and source == 0) {
            s.clonewars_reaction_receipt_debug[0] +%= 1;
            return;
        }
        if (s.journal.host == 0) {
            var matches = false;
            if (s.journal.peek()) |next| if (next.kind == p.SYNC_REACTION_CLIP and next.payload.clip.selection.clip >= -1 and next.payload.clip.arena_attacker_generation == 0 and next.old_action == action and next.payload.clip.source_id == source) {
                var reference = s.identity(next);
                matches = s.entities_resolve_reference(&reference) == actor and s.live(&op);
                if (!s.live(&op)) return;
            };
            if (!matches) {
                s.clonewars_reaction_receipt_debug[1] +%= 1;
                return;
            }
        }
    }
    if (s.journal.host != 0) {
        s.entities_update();
        if (!s.live(&op)) return;
        var identity = std.mem.zeroes(p.SyncActor);
        s.entities_describe(&identity, actor);
        if (!s.live(&op)) return;
        const slot = s.entities_slot(actor);
        if (!s.live(&op)) return;
        var entry = std.mem.zeroes(p.SyncReactionChoice);
        s.describe(&entry, actor, &identity, slot, action);
        entry.payload.clip.selection.clip = @bitCast(output.*);
        entry.payload.clip.source_id = source;
        if (s.attacker != 0 and actor == s.victim and s.entities_observed_identity(s.attacker, &entry.payload.clip.arena_attacker_slot, &entry.payload.clip.arena_attacker_generation) == 0) {
            s.journal.failed = 6;
            s.failed(&op, actor, &entry, action, source, 6, local_clip);
            return;
        }
        if (s.reaction_journal_record(&s.journal, &entry) == 0) {
            s.failed(&op, actor, &entry, action, source, 6, local_clip);
            return;
        }
        s.clonewars_reaction_debug[0] +%= 1;
    } else {
        const entry = s.journal.peek();
        var identity = if (entry) |e| s.identity(e) else std.mem.zeroes(p.SyncActor);
        const matches = entry != null and s.entities_resolve_reference(&identity) == actor;
        if (!s.live(&op)) return;
        if (entry != null and entry.?.kind == p.SYNC_REACTION_CLIP and (entry.?.payload.clip.arena_attacker_generation != 0) != (s.attacker != 0 and s.victim == actor)) {
            s.journal.failed = 8;
            s.failed(&op, actor, entry, action, source, 8, local_clip);
            return;
        }
        // Native selection can retain its input ID when no candidate clip is available.
        const allowed = if (entry) |e| e.kind == p.SYNC_REACTION_CLIP and e.payload.clip.selection.clip != -2 and validation.valid(e) and matches and e.old_action == action and e.payload.clip.source_id == source and (e.payload.clip.selection.clip == -1 or @as(u32, @bitCast(e.payload.clip.selection.clip)) == local_clip or available(actor, e.payload.clip.selection.clip)) else false;
        if (!s.live(&op)) return;
        if (s.reaction_journal_apply(&s.journal, entry, @intFromBool(matches), action, source, @intFromBool(allowed), output) == 0) {
            s.failed(&op, actor, entry, action, source, @bitCast(s.journal.failed), local_clip);
            return;
        }
        const e = entry.?;
        s.clonewars_reaction_debug[1] +%= 1;
        s.clonewars_reaction_debug[2] +%= @intFromBool(local_clip != output.*);
        if (local_clip != output.* and s.clonewars_reaction_first_correction[0] == 0) s.clonewars_reaction_first_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, s.journal.cursor - 1, e.slot, e.generation, local_clip, output.*, @bitCast(action), source, read(u32, 0xe637b4), read(u32, 0xea178c), read(u32, actor + 0xf04) };
        s.clonewars_reaction_debug[8..15].* = .{ e.slot, e.generation, local_clip, output.*, source, @bitCast(action), s.journal.cursor };
    }
    s.clonewars_reaction_debug[7] = s.journal.frame.?.sequence;
}
fn draw(victim: usize, native_draw: u32) u32 {
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active or s.journal.failed != 0) return native_draw;
    const source = s.combat_damage_source_id();
    if (source == 0 or !s.live(&op)) return native_draw;
    const action: i32 = read(i16, victim + 0x2f4);
    if (s.journal.host != 0) {
        s.entities_update();
        if (!s.live(&op)) return native_draw;
        var identity = std.mem.zeroes(p.SyncActor);
        s.entities_describe(&identity, victim);
        const slot = s.entities_slot(victim);
        if (!s.live(&op)) return native_draw;
        var entry = std.mem.zeroes(p.SyncReactionChoice);
        s.describe(&entry, victim, &identity, slot, action);
        entry.kind = p.SYNC_REACTION_DAMAGE_DRAW;
        entry.payload.clip.source_id = source;
        entry.payload.clip.selection.damage_draw = native_draw;
        if (s.reaction_journal_record(&s.journal, &entry) != 0) {
            s.clonewars_damage_draw_debug[0] +%= 1;
            return native_draw;
        }
    } else if (s.journal.peek()) |e| {
        if (e.kind == p.SYNC_REACTION_DAMAGE_DRAW and e.payload.clip.source_id == source and e.old_action == action and validation.valid(e)) {
            var identity = s.identity(e);
            const matches = s.entities_resolve_reference(&identity) == victim;
            if (!s.live(&op)) return native_draw;
            if (matches) {
                s.journal.cursor += 1;
                s.clonewars_damage_draw_debug[1] +%= 1;
                if (native_draw != e.payload.clip.selection.damage_draw) {
                    s.clonewars_damage_draw_debug[2] +%= 1;
                    s.clonewars_damage_draw_debug[4..8].* = .{ s.journal.frame.?.sequence, source, native_draw, e.payload.clip.selection.damage_draw };
                }
                return e.payload.clip.selection.damage_draw;
            }
        }
    }
    if (s.live(&op)) {
        const entry = s.journal.peek();
        s.journal.failed = 9;
        s.clonewars_damage_draw_debug[3] +%= 1;
        s.failed(&op, victim, entry, action, source, 9, native_draw);
    }
    return native_draw;
}
pub export fn reaction_damage_draw(victim: usize, native_draw: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return draw(victim, native_draw);
}
