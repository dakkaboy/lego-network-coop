const std = @import("std");
const p = @import("protocol.zig");
const cadence = @import("cadence.zig");
const geometry = @import("geometry.zig");
const model = @import("model.zig");
const reaction = @import("reaction.zig");

fn frame() !*p.SyncFrame {
    const result = try std.testing.allocator.create(p.SyncFrame);
    @memset(std.mem.asBytes(result), 0);
    return result;
}

test "cadence: phase mismatch leaves output and cursor unchanged" {
    const f = try frame();
    defer std.testing.allocator.destroy(f);
    var host: cadence.Journal = undefined;
    var peer: cadence.Journal = undefined;
    var entry = std.mem.zeroes(p.SyncCadence);
    entry.generation = 1;
    entry.period = 7;
    entry.phase = 2;
    cadence.cadence_journal_begin(&host, f, 1);
    try std.testing.expectEqual(@as(c_int, 1), cadence.cadence_journal_record(&host, &entry));
    cadence.cadence_journal_begin(&peer, f, 0);
    var period: u32 = 99;
    var elapsed: f32 = 77;
    try std.testing.expectEqual(@as(c_int, 0), cadence.cadence_journal_apply(&peer, peer.peek(), 1, 3, &period, &elapsed));
    try std.testing.expectEqual(@as(c_int, 2), peer.failed);
    try std.testing.expectEqual(@as(u32, 0), peer.cursor);
    try std.testing.expectEqual(@as(u32, 99), period);
    try std.testing.expectEqual(@as(f32, 77), elapsed);
    cadence.cadence_journal_begin(&peer, f, 0);
    try std.testing.expectEqual(@as(c_int, 1), cadence.cadence_journal_apply(&peer, peer.peek(), 1, 2, &period, &elapsed));
    try std.testing.expectEqual(@as(u32, 7), period);
    try std.testing.expectEqual(@as(c_int, 1), peer.finish());
}

test "model: reject changed native clock and context before consuming" {
    const f = try frame();
    defer std.testing.allocator.destroy(f);
    var host: model.Journal = undefined;
    var peer: model.Journal = undefined;
    var entry = std.mem.zeroes(p.SyncModelInput);
    entry.generation = 1;
    entry.character = 466;
    entry.period = 7;
    entry.phase = 2;
    entry.context.axis_1dd = 255;
    model.model_input_journal_begin(&host, f, 1);
    try std.testing.expectEqual(@as(c_int, 1), model.model_input_journal_record(&host, &entry));
    model.model_input_journal_begin(&peer, f, 0);
    var local = entry;
    local.native_clock += 1;
    try std.testing.expectEqual(@as(c_int, 0), model.model_input_journal_validate(&peer, peer.peek(), 1, &local));
    try std.testing.expectEqual(@as(c_int, 6), peer.failed);
    try std.testing.expectEqual(@as(u32, 0), peer.cursor);
    model.model_input_journal_begin(&peer, f, 0);
    local = entry;
    local.context.actor_76 += 1;
    try std.testing.expectEqual(@as(c_int, 0), model.model_input_journal_validate(&peer, peer.peek(), 1, &local));
    try std.testing.expectEqual(@as(c_int, 9), peer.failed);
    try std.testing.expectEqual(@as(u32, 0), peer.cursor);
    model.model_input_journal_begin(&peer, f, 0);
    try std.testing.expectEqual(@as(c_int, 1), model.model_input_journal_validate(&peer, peer.peek(), 1, &entry));
    try std.testing.expectEqual(@as(c_int, 1), peer.finish());
}

test "geometry: validate entire batch before advancing its cursor" {
    const f = try frame();
    defer std.testing.allocator.destroy(f);
    var host: geometry.Journal = undefined;
    var peer: geometry.Journal = undefined;
    var batch: geometry.Batch = undefined;
    geometry.geometry_journal_begin(&host, f, 1);
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_phase(&host, 0, &batch));
    var entry = std.mem.zeroes(p.SyncCollider);
    entry.generation = 1;
    entry.manager_ordinal = 1;
    entry.slot = 1;
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_record(&host, &entry));
    entry.slot = 2;
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_record(&host, &entry));
    geometry.geometry_journal_begin(&peer, f, 0);
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_phase(&peer, 0, &batch));
    try std.testing.expectEqual(@as(u32, 2), batch.count);
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_validate(&peer, &f.geometry[0], 1));
    try std.testing.expectEqual(@as(c_int, 0), geometry.geometry_journal_commit(&peer, &batch));
    try std.testing.expectEqual(@as(u32, 0), peer.cursor);
    geometry.geometry_journal_begin(&peer, f, 0);
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_phase(&peer, 0, &batch));
    for (0..2) |i| try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_validate(&peer, &f.geometry[i], 1));
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_commit(&peer, &batch));
    try std.testing.expectEqual(@as(c_int, 1), geometry.geometry_journal_finish(&peer));
}

test "reaction: mismatched hit receipt fails without consuming it" {
    const f = try frame();
    defer std.testing.allocator.destroy(f);
    var host: reaction.Journal = undefined;
    var peer: reaction.Journal = undefined;
    var entry = std.mem.zeroes(p.SyncReactionChoice);
    entry.slot = 3;
    entry.generation = 8;
    entry.character = 321;
    entry.old_action = 20;
    entry.kind = p.SYNC_REACTION_CLIP;
    const clip = &entry.payload.clip;
    clip.selection.clip = -1;
    clip.source_id = 77;
    clip.hit = .{ .completed = 1, .health_before = 4, .health_after = 3, .life_before = 3, .life_after = 3, .action_before = 0, .action_after = 0, .timer_before = 0, .timer_after = 0 };
    reaction.reaction_journal_begin(&host, f, 1);
    try std.testing.expectEqual(@as(c_int, 1), reaction.reaction_journal_record(&host, &entry));
    reaction.reaction_journal_begin(&peer, f, 0);
    var wrong = clip.hit;
    wrong.health_after = 2;
    try std.testing.expectEqual(@as(c_int, -1), reaction.reaction_journal_complete_no_clip(&peer, 0, 3, 8, 77, &wrong));
    try std.testing.expectEqual(@as(c_int, 11), peer.failed);
    try std.testing.expectEqual(@as(u32, 0), peer.cursor);
    reaction.reaction_journal_begin(&peer, f, 0);
    try std.testing.expectEqual(@as(c_int, 1), reaction.reaction_journal_complete_no_clip(&peer, 0, 3, 8, 77, &clip.hit));
    try std.testing.expectEqual(@as(c_int, 1), peer.finish());
}
