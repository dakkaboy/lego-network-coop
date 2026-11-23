const std = @import("std");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const t = @import("model_types.zig");
const Token = @import("cohort_types.zig").Token;
pub var journal = std.mem.zeroes(t.Journal);
pub var early_entries: std.StaticBitSet(@typeInfo(@FieldType(p.SyncFrame, "model_inputs")).array.len) = .empty;
pub var binding: @import("cohort_binding.zig").Binding = .{};
pub var active = false;
pub var initialized_serial: u32 = 0;
pub var active_thread: u32 = 0;
pub var last_epoch: u32 = 0;
pub var first_actor: usize = 0;
pub var first_controller: usize = 0;
pub var first_generation: u32 = 0;
pub var cancelled: i32 = 0;
pub var disabled: i32 = 0;
pub threadlocal var lexical: ?*t.Local = null;
pub threadlocal var scope: ?*t.Scope = null;
pub threadlocal var depth: u32 = 0;
pub threadlocal var serial: u32 = 0;
pub export var clonewars_model_input_installed: i32 = 0;
pub export var clonewars_model_input_entry_stride: u32 = @sizeOf(p.SyncModelInput);
pub export var clonewars_model_input_context_stride: u32 = @sizeOf(p.SyncModelInputContext);
pub export var clonewars_model_input_outcome_stride: u32 = @sizeOf(t.Outcome);
pub export var clonewars_model_input_frame_capacity: u32 = @sizeOf(p.SyncFrame);
pub export var clonewars_model_input_frame_offset: u32 = @offsetOf(p.SyncFrame, "model_inputs");
pub export var clonewars_model_input_protocol: u32 = p.SYNC_PROTOCOL_VERSION;
pub export var clonewars_model_input_layout: u32 = p.SYNC_LAYOUT_VERSION;
pub export var clonewars_model_input_authority: u32 = 1;
pub export var clonewars_model_input_debug: [16]u32 = @splat(0);
pub export var clonewars_model_input_failure: [16]u32 = @splat(0);
pub export var clonewars_model_input_first_correction: [8]u32 = @splat(0);
pub export var clonewars_model_visibility_debug: [4]u32 = @splat(0);
pub export var clonewars_model_input_failed_host = std.mem.zeroes(p.SyncModelInput);
pub export var clonewars_model_input_failed_local = std.mem.zeroes(p.SyncModelInput);
pub export var clonewars_model_input_corrected_host = std.mem.zeroes(p.SyncModelInput);
pub export var clonewars_model_input_corrected_local = std.mem.zeroes(p.SyncModelInput);
pub export var clonewars_model_input_effective = std.mem.zeroes(p.SyncModelInput);
pub export var clonewars_model_input_first_outcome = std.mem.zeroes(t.Outcome);
pub export var clonewars_model_input_context_encoding: u32 = 1;
pub export var clonewars_model_projection_enabled: i32 = 0;
pub export var clonewars_model_projection_count: u32 = 0;
pub export var clonewars_model_projection_version: u32 = 3;
pub export var clonewars_model_projection_stride: u32 = @sizeOf(t.Projection);
pub export var clonewars_model_projection_capacity: u32 = 2048;
pub export var clonewars_model_projection_records: [2048]t.Projection = std.mem.zeroes([2048]t.Projection);
extern fn coherent_frame_cancel_atomic(u32) void;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn game_sync_native_fault(c_int) void;
pub fn live(op: *const t.Lease) bool {
    return binding.live(op) and journal.frame != null and @intFromPtr(journal.frame.?) == op.cohort.frame;
}
pub fn disable() void {
    @atomicStore(i32, &disabled, 1, .seq_cst);
    coherent_frame_cancel_atomic(0x4000);
}
pub fn failed(op: *const t.Lease, actor: usize, host: ?*const p.SyncModelInput, local: ?*const p.SyncModelInput, reason: u32) void {
    if (!live(op)) return;
    if (@cmpxchgStrong(u32, &clonewars_model_input_failure[0], 0, std.math.maxInt(u32), .seq_cst, .seq_cst) == null) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = entities_observed_identity(actor, &slot, &generation);
        if (!live(op)) return;
        const values = [_]u32{ journal.frame.?.epoch, journal.frame.?.sequence, if (journal.host != 0) journal.frame.?.model_input_count else journal.cursor, if (host) |v| v.slot else std.math.maxInt(u32), if (host) |v| v.generation else 0, slot, generation, reason, if (host) |v| v.native_clock else 0, if (local) |v| v.native_clock else 0, if (host) |v| v.context.action else 0, if (local) |v| v.context.action else 0, if (host) |v| v.input_mode else 0, if (local) |v| v.input_mode else 0, @truncate(actor), win.load(u32, 0xfb4b6c) };
        if (host) |v| clonewars_model_input_failed_host = v.*;
        if (local) |v| clonewars_model_input_failed_local = v.*;
        @memcpy(clonewars_model_input_failure[1..16], values[1..16]);
        @atomicStore(u32, &clonewars_model_input_failure[0], values[0], .seq_cst);
    }
    if (!live(op)) return;
    clonewars_model_input_debug[3] +%= 1;
    journal.failed = @bitCast(reason);
    game_sync_native_fault(20);
}
pub fn qualified(op: *t.Lease) ?*t.Scope {
    if (@atomicLoad(i32, &disabled, .seq_cst) != 0 or !active or win.GetCurrentThreadId() != active_thread) return null;
    const local = lexical orelse return null;
    const s = &local.scope;
    if (scope != s) {
        disable();
        return null;
    }
    if (s.linked == 0 or s.usable == 0) return null;
    op.* = s.lease;
    return if (live(op)) s else null;
}
