const Shot = @import("collision_types.zig").Shot;
pub const Header = extern struct { committed: u32, id: u32, parent: u32, thread: u32, caller: u32, epoch: u32, sequence: u32, ordinal: u32, clock: u32, rng_game: u32, rng_engine: u32, qpc_before_low: u32, qpc_before_high: u32, qpc_after_low: u32, qpc_after_high: u32, clock_after: u32, rng_game_after: u32, rng_engine_after: u32, manager_local: u32, result: u32, arguments: [6]u32 };
pub const Object = extern struct { node_local: u32, pointer_local: u32, raw_valid: u32, raw: [88]u32 };
pub const Entry = extern struct { header: Header, source_before: Shot, source_after: Shot, points_valid: u32, points: [9]u32, bounds_valid: u32, bounds: [6]u32, candidate_head: u32, candidate_count: u32, candidate_status: u32, candidate_reserved: u32, candidates: [64]Object };
pub const Query = extern struct { header: Header, source: Shot, object: Object, arguments_valid: u32, context_valid: u32, sample_index: u32, point_local: u32, center_valid: u32, point_valid: u32, center: [3]u32, point: [3]u32 };
comptime {
    const assert = @import("std").debug.assert;
    assert(@sizeOf(Header) == 104 and @sizeOf(Object) == 364 and @sizeOf(Entry) == 24620 and @sizeOf(Query) == 1084);
}
