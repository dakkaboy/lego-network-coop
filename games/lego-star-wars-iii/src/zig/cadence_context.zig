const p = @import("protocol.zig");
pub fn competitor(a: *const p.SyncRtsCompetitorState, b: *const p.SyncRtsCompetitorState) bool {
    return a.clock == b.clock and a.competitor_class == b.competitor_class;
}
pub fn aim(a: *const p.SyncAimTaskState, b: *const p.SyncAimTaskState) bool {
    return a.target_slot == b.target_slot and a.target_generation == b.target_generation and a.clock == b.clock and a.task_class == b.task_class and @as(u32, @bitCast(a.minimum)) == @as(u32, @bitCast(b.minimum)) and @as(u32, @bitCast(a.maximum)) == @as(u32, @bitCast(b.maximum));
}
