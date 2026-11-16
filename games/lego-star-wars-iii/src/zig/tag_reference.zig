const std = @import("std");
const p = @import("protocol.zig");
pub fn reference(slot: i32, generation: u32, identity: *const p.SyncTagIdentity) ?p.SyncActor {
    if (slot < 0 or slot >= p.SYNC_MAX_ACTORS or generation == 0 or identity.character < 0 or identity.character >= 4096) return null;
    var result = std.mem.zeroes(p.SyncActor);
    result.slot = @intCast(slot);
    result.generation = generation;
    result.character = identity.character;
    result.spawn_tag = identity.spawn_tag;
    result.spawn_source = identity.spawn_source;
    return result;
}
