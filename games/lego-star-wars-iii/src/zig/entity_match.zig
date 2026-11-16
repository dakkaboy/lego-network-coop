pub const Key = @import("entity_types.zig").Key;
pub export fn entity_match_unique(wanted: *const Key, available: [*c]const Key, claimed: [*c]const u8, count: c_uint) c_int {
    if (wanted.spawn_source.producer == 0) return -1;
    var match: c_int = -1;
    for (0..count) |i| {
        const candidate = &available[i];
        if (claimed[i] != 0 or candidate.generation == 0 or candidate.character != wanted.character or candidate.spawn_tag != wanted.spawn_tag or
            candidate.spawn_source.producer != wanted.spawn_source.producer or candidate.spawn_source.serial != wanted.spawn_source.serial) continue;
        if (match >= 0) return -2;
        match = @bitCast(@as(u32, @intCast(i)));
    }
    return match;
}
