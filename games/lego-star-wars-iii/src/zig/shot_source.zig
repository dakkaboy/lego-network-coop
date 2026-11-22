const p = @import("protocol.zig");
pub fn isGeonosisBarrage(level: i32, owner: i32, weapon: i32, flags: u32, source: u8) bool {
    // The same ownerless barrage emitter selects several weapon variants.
    return level == 79 and owner == -1 and weapon >= 0 and flags == 0x802 and source == p.SYNC_SHOT_WEAPON;
}
pub fn matches(shot: *const p.SyncShot, owner: i32, generation: u32, weapon: i32, source: u8, depth: u8) bool {
    return shot.phase == 0 and shot.owner == owner and shot.owner_generation == generation and shot.weapon == weapon and shot.source == source and shot.depth == depth;
}
