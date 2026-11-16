const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const validation = @import("reaction_validation.zig");
const read = s.read;
const equal = @import("validation.zig").equal;
const Actor = extern struct {
    before_position: [0x24]u8,
    position: [3]f32,
    before_heading: [0x6c - 0x30]u8,
    heading: u16,
    before_target: [0x2bc - 0x6e]u8,
    target: usize,
    before_flags: [0x2fc - 0x2c0]u8,
    flags: u32,
    before_radius: [0x1088 - 0x300]u8,
    radius: f32,
};
const native: *const fn (usize, usize, f32) callconv(.c) c_int = @ptrFromInt(0x792db0);
fn replay(range: *const p.SyncItemRange) c_int {
    var actor = std.mem.zeroes(Actor);
    var target = std.mem.zeroes(Actor);
    actor.heading = range.heading;
    actor.flags = @as(u32, range.reverse) << 7;
    actor.radius = range.actor_radius;
    target.radius = range.target_radius;
    actor.position = range.actor_position;
    target.position = range.target_position;
    actor.target = @intFromPtr(&target);
    return native(@intFromPtr(&actor), @intFromPtr(&target), range.reach);
}
fn apply(actor: usize, target: usize, reach: f32) c_int {
    var op: s.Lease = undefined;
    if (target == 0 or !s.get(&op) or !s.active) return native(actor, target, reach);
    if (s.journal.failed != 0) return 0;
    var local = std.mem.zeroes(p.SyncReactionChoice);
    local.kind = p.SYNC_REACTION_ITEM_RANGE;
    if (s.valid(actor, @sizeOf(Actor)) and s.valid(target, @sizeOf(Actor)) and read(usize, actor + 0x2bc) == target) {
        if (s.journal.host != 0) s.entities_update();
        if (!s.live(&op)) return 0;
        var identity = std.mem.zeroes(p.SyncActor);
        s.entities_describe(&identity, actor);
        if (!s.live(&op)) return 0;
        const r = &local.payload.range;
        if (s.entities_observed_identity(actor, &local.slot, &local.generation) != 0 and s.entities_observed_identity(target, &r.target_slot, &r.target_generation) != 0 and s.live(&op)) {
            local.spawn_tag = identity.spawn_tag;
            local.spawn_source = identity.spawn_source;
            local.character = read(i16, actor + 0xdc0);
            local.old_action = read(i16, actor + 0x2f4);
            local.origin = identity.spawn_position;
            r.heading = read(u16, actor + 0x6c);
            r.reverse = @truncate((read(u32, actor + 0x2fc) >> 7) & 1);
            r.animation = read(i16, actor + 0x2e8);
            r.actor_position = read([3]f32, actor + 0x24);
            r.target_position = read([3]f32, target + 0x24);
            r.actor_radius = read(f32, actor + 0x1088);
            r.target_radius = read(f32, target + 0x1088);
            r.reach = reach;
        }
    }
    const entry = s.journal.peek();
    if (validation.valid(&local)) {
        if (s.journal.host != 0) {
            if (s.reaction_journal_record(&s.journal, &local) != 0) {
                s.clonewars_item_range_debug[0] +%= 1;
                return native(actor, target, reach);
            }
        } else if (entry) |e| {
            const a = &local.payload.range;
            const b = &e.payload.range;
            if (e.kind == p.SYNC_REACTION_ITEM_RANGE and validation.valid(e) and e.slot == local.slot and e.generation == local.generation and e.character == local.character and e.old_action == local.old_action and b.animation == a.animation and b.target_slot == a.target_slot and b.target_generation == a.target_generation) {
                s.journal.cursor += 1;
                s.clonewars_item_range_debug[1] +%= 1;
                if (equal(a, b)) return native(actor, target, reach);
                s.clonewars_item_range_debug[2] +%= 1;
                s.clonewars_item_range_debug[4..7].* = .{ s.journal.frame.?.sequence, e.slot, b.target_slot };
                const result = replay(b);
                s.clonewars_item_range_debug[7] = @bitCast(result);
                return result;
            }
        }
    }
    if (s.live(&op)) {
        if (s.clonewars_item_range_failure_mask == 0) {
            var mask: u32 = @intFromBool(!validation.valid(&local));
            if (entry) |e| {
                if (e.kind != p.SYNC_REACTION_ITEM_RANGE) mask |= 4;
                if (e.slot != local.slot or e.generation != local.generation or e.character != local.character) mask |= 8;
                if (e.old_action != local.old_action) mask |= 16;
                if (e.payload.range.animation != local.payload.range.animation) mask |= 32;
                if (e.payload.range.target_slot != local.payload.range.target_slot or e.payload.range.target_generation != local.payload.range.target_generation) mask |= 64;
                s.clonewars_item_range_failure[0] = e.*;
            } else mask |= 2;
            s.clonewars_item_range_failure[1] = local;
            @atomicStore(u32, &s.clonewars_item_range_failure_mask, if (mask != 0) mask else 128, .seq_cst);
        }
        s.journal.failed = 10;
        s.clonewars_item_range_debug[3] +%= 1;
        s.failed(&op, actor, entry, local.old_action, 0, 10, std.math.maxInt(u32));
    }
    return 0;
}
pub export fn reaction_item_range_hook(actor: usize, target: usize, reach: f32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return apply(actor, target, reach);
}
comptime {
    std.debug.assert(@offsetOf(Actor, "position") == 0x24 and @offsetOf(Actor, "heading") == 0x6c and @offsetOf(Actor, "target") == 0x2bc and @offsetOf(Actor, "flags") == 0x2fc and @offsetOf(Actor, "radius") == 0x1088);
}
