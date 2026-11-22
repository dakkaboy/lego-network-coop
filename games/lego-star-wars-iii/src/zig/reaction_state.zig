const std = @import("std");
const p = @import("protocol.zig");
pub const win = @import("win32.zig");
pub const Lease = @import("cohort_types.zig").Lease;
pub const Journal = @import("journal.zig").Journal("reactions", "reaction_count");
pub const Receipt = @import("combat_types.zig").Receipt;
pub var journal = std.mem.zeroes(Journal);
pub var binding: @import("cohort_binding.zig").Binding = .{};
pub var active = false;
pub var cancelled = false;
pub var last_epoch: u32 = 0;
pub threadlocal var attacker: usize = 0;
pub threadlocal var victim: usize = 0;
pub export var clonewars_reaction_installed: i32 = 0;
pub export var clonewars_reaction_debug: [20]u32 = @splat(0);
pub export var clonewars_damage_draw_debug: [8]u32 = @splat(0);
pub export var clonewars_item_range_debug: [8]u32 = @splat(0);
pub export var clonewars_item_range_failure_mask: u32 = 0;
pub export var clonewars_item_range_failure: [2]p.SyncReactionChoice = std.mem.zeroes([2]p.SyncReactionChoice);
pub export var clonewars_item_range_failure_stride: u32 = @sizeOf(p.SyncReactionChoice);
pub export var clonewars_reaction_failure: [14]u32 = @splat(0);
pub export var clonewars_reaction_first_correction: [12]u32 = @splat(0);
pub export var clonewars_reaction_receipt_debug: [10]u32 = @splat(0);
pub export var clonewars_reaction_hit_actual = std.mem.zeroes(p.SyncReactionHitOutcome);
pub export var clonewars_reaction_hit_expected = std.mem.zeroes(p.SyncReactionHitOutcome);
pub const read = win.load;
pub extern fn entities_observed_identity(usize, *u32, *u32) c_int;
pub extern fn entities_observed_generation(usize) u32;
pub extern fn entities_allocation_retained(usize, u32) c_int;
pub extern fn entities_update() void;
pub extern fn entities_describe(*p.SyncActor, usize) void;
pub extern fn entities_slot(usize) c_int;
pub extern fn entities_resolve_reference(*const p.SyncActor) usize;
pub extern fn entities_actor(u32, u32) usize;
pub extern fn combat_damage_source_id() u32;
pub extern fn combat_damage_native_caller() u32;
extern fn game_sync_native_fault(c_int) void;
pub fn live(op: *const Lease) bool {
    return binding.live(op) and journal.frame != null and @intFromPtr(journal.frame.?) == op.cohort.frame;
}
pub fn get(op: *Lease) bool {
    return binding.get(op) and live(op);
}
pub fn valid(address: usize, size: usize) bool {
    return win.accessible(address, size, false);
}
pub fn identity(entry: *const p.SyncReactionChoice) p.SyncActor {
    var result = std.mem.zeroes(p.SyncActor);
    result.slot = entry.slot;
    result.generation = entry.generation;
    result.spawn_tag = entry.spawn_tag;
    result.spawn_source = entry.spawn_source;
    result.character = entry.character;
    result.spawn_position = entry.origin;
    return result;
}
pub fn describe(entry: *p.SyncReactionChoice, actor: usize, source: *const p.SyncActor, slot: c_int, action: i32) void {
    entry.slot = @bitCast(slot);
    entry.generation = source.generation;
    entry.spawn_tag = source.spawn_tag;
    entry.spawn_source = source.spawn_source;
    entry.character = read(i16, actor + 0xdc0);
    entry.old_action = action;
    entry.origin = source.spawn_position;
}
pub fn failed(op: *const Lease, actor: usize, entry: ?*const p.SyncReactionChoice, action: i32, source: u32, reason: u32, local_clip: u32) void {
    if (!live(op)) return;
    if (clonewars_reaction_failure[0] == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = entities_observed_identity(actor, &slot, &generation);
        if (!live(op)) return;
        const hit = entry != null and entry.?.kind != p.SYNC_REACTION_ITEM_RANGE;
        clonewars_reaction_failure = .{ journal.frame.?.epoch, journal.frame.?.sequence, if (journal.host != 0) journal.frame.?.reaction_count else journal.cursor, if (entry) |e| e.slot else std.math.maxInt(u32), if (entry) |e| e.generation else 0, slot, generation, reason, if (entry) |e| @bitCast(e.old_action) else 0, @bitCast(action), if (hit) entry.?.payload.clip.source_id else 0, source, if (hit) @bitCast(entry.?.payload.clip.selection.clip) else std.math.maxInt(u32), local_clip };
    }
    if (!live(op)) return;
    clonewars_reaction_debug[3] +%= 1;
    game_sync_native_fault(17);
}
pub extern fn reaction_journal_record(*Journal, *const p.SyncReactionChoice) c_int;
pub extern fn reaction_journal_apply(*Journal, ?*const p.SyncReactionChoice, c_int, c_int, u32, c_int, *u32) c_int;
pub extern fn reaction_journal_begin(*Journal, *p.SyncFrame, c_int) void;
pub extern fn reaction_journal_complete_no_clip(*Journal, u32, u32, u32, u32, *const p.SyncReactionHitOutcome) c_int;
