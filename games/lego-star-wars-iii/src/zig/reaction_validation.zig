const p = @import("protocol.zig");
const abi = @import("abi.zig");
const v = @import("validation.zig");
pub fn hitValid(hit: *const p.SyncReactionHitOutcome) bool {
    return hit.completed == 1 and hit.health_before >= -128 and hit.health_before <= 127 and hit.health_after >= -128 and hit.health_after <= 127 and
        hit.life_before & ~@as(u32, 0xff03) == 0 and hit.life_after & ~@as(u32, 0xff03) == 0 and
        (hit.life_before & 3 == 1 or hit.life_before & 3 == 3) and
        (hit.life_after == 0 or hit.life_after & 3 == 1 or hit.life_after & 3 == 3) and
        hit.action_before >= -32768 and hit.action_before <= 32767 and hit.action_after >= -32768 and hit.action_after <= 32767 and
        v.finite(hit.*) and (hit.life_after != 0 or (hit.health_after == 0 and hit.action_after == 0 and hit.timer_after == 0));
}
pub fn hitSame(a: *const p.SyncReactionHitOutcome, b: ?*const p.SyncReactionHitOutcome) bool {
    const other = b orelse return false;
    if (!hitValid(a) or !hitValid(other)) return false;
    inline for (@typeInfo(p.SyncReactionHitOutcome).@"struct".field_names) |name| if (@field(a, name) != @field(other, name)) return false;
    return true;
}
pub fn valid(entry: ?*const p.SyncReactionChoice) bool {
    const e = entry orelse return false;
    if (e.slot >= p.SYNC_MAX_ACTORS or e.generation == 0 or !abi.validLevel(e.character) or e.old_action < -32768 or e.old_action > 32767 or !v.finite(e.origin)) return false;
    if (e.kind == p.SYNC_REACTION_ITEM_RANGE) {
        const r = &e.payload.range;
        return r.target_slot < p.SYNC_MAX_ACTORS and r.target_slot != e.slot and r.target_generation != 0 and r.reverse <= 1 and r.reserved == 0 and v.finite(r.*);
    }
    const clip = &e.payload.clip;
    if (e.kind == p.SYNC_REACTION_DAMAGE_DRAW) return clip.source_id != 0 and clip.arena_attacker_slot == 0 and clip.arena_attacker_generation == 0 and clip.selection.damage_draw <= 65535 and v.zero(&clip.hit);
    if (e.kind != p.SYNC_REACTION_CLIP) return false;
    if (clip.hit.completed != 0) {
        if (!hitValid(&clip.hit)) return false;
        if (clip.arena_attacker_generation == 0 and (clip.selection.clip != -1 or clip.source_id == 0)) return false;
    } else if (!v.zero(&clip.hit)) return false;
    const attacker = if (clip.arena_attacker_generation != 0) clip.arena_attacker_slot < p.SYNC_MAX_ACTORS and clip.arena_attacker_slot != e.slot and clip.source_id == 0 else clip.arena_attacker_slot == 0;
    return attacker and clip.selection.clip >= @as(i32, if (clip.arena_attacker_generation != 0) -2 else -1) and clip.selection.clip < 4096;
}
