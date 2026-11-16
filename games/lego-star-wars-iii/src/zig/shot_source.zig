const p = @import("protocol.zig");
pub fn matches(shot: *const p.SyncShot, owner: i32, generation: u32, weapon: i32, source: u8, depth: u8) bool {
    return shot.phase == 0 and shot.owner == owner and shot.owner_generation == generation and shot.weapon == weapon and shot.source == source and shot.depth == depth;
}
