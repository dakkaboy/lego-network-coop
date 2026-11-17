const std = @import("std");
const p = @import("protocol.zig");
const v = @import("validation.zig");
pub fn valid(frame: *const p.SyncFrame, tag: *const p.SyncTag, previous: []const p.SyncTag) bool {
    if (!v.finite(tag.delta) or tag.delta < 0) return false;
    if (tag.delta <= 0.1) return true;
    if (tag.phase != 0) return false;
    if (tag.parent != 0) {
        for (previous) |parent| if (parent.id == tag.parent and parent.phase == 0 and parent.clock == tag.clock and @as(u32, @bitCast(parent.delta)) == @as(u32, @bitCast(tag.delta))) return true;
        return false;
    }
    var matches: u32 = 0;
    for (frame.cadence[0..frame.cadence_count]) |entry| {
        if (entry.slot != tag.from or entry.generation != tag.from_generation) continue;
        if (entry.character != tag.from_identity.character or entry.spawn_tag != tag.from_identity.spawn_tag or !v.equal(&entry.spawn_source, &tag.from_identity.spawn_source) or
            entry.period == 0 or entry.period > 255 or entry.phase > 255 or (tag.clock +% entry.phase) % entry.period != 0 or
            @as(u32, @bitCast(entry.elapsed)) != @as(u32, @bitCast(tag.delta))) return false;
        const bound: f32 = 255 * @as(f32, 0.1);
        // Visibility may change the period on the update that consumes accumulated time.
        if (entry.elapsed > bound + bound * std.math.floatEps(f32) * 255 * 2) return false;
        matches += 1;
    }
    return matches == 1;
}
