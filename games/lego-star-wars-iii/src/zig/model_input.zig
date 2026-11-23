const std = @import("std");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const t = @import("model_types.zig");
const state = @import("model_state.zig");
const Token = @import("cohort_types.zig").Token;
const Machine = @import("machine_environment.zig").Environment;
pub var original_producer: usize = 0;
pub export const model_producer_default_mxcsr: u32 = 0x1f80;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn coherent_frame_cancel_atomic(u32) void;
extern fn entities_observed_generation(usize) u32;
extern fn entities_update() void;
extern fn model_input_journal_begin(*t.Journal, *p.SyncFrame, c_int) void;
pub export fn model_producer_enter(b: *t.Bridge) void {
    b.target = original_producer;
    const l: *t.Local = @ptrCast(@alignCast(&b.storage));
    l.* = std.mem.zeroes(t.Local);
    const s = &l.scope;
    s.actor = b.actor;
    s.previous = state.scope;
    l.previous = state.lexical;
    state.lexical = l;
    s.linked = 1;
    state.scope = s;
    state.depth +%= 1;
    l.entered = 1;
    if (state.serial == std.math.maxInt(u32)) {
        state.disable();
        return;
    }
    state.serial += 1;
    s.lexical_nonce = state.serial;
    var op: t.Lease = undefined;
    if (@atomicLoad(i32, &state.disabled, .seq_cst) == 0 and state.active and win.GetCurrentThreadId() == state.active_thread and state.binding.get(&op) and state.live(&op)) {
        s.lease = op;
        s.usable = @intFromBool(state.depth <= 32);
        if (s.usable != 0 and @import("model_capture.zig").valid(s.actor, 0x1440)) {
            s.entry_generation = entities_observed_generation(s.actor);
            if (s.entry_generation == 0) {
                entities_update();
                if (state.live(&op)) s.entry_generation = entities_observed_generation(s.actor);
            }
        }
        if (!state.live(&op)) s.usable = 0;
        if (state.depth > 32) state.failed(&op, s.actor, null, null, 15);
    }
}
pub export fn model_producer_leave(b: *t.Bridge, unwind: c_int) void {
    var machine: Machine = undefined;
    machine.save(&model_producer_default_mxcsr);
    defer machine.restore();
    const l: *t.Local = @ptrCast(@alignCast(&b.storage));
    const s = &l.scope;
    if (unwind != 0 and s.lease.serial != 0 and state.binding.same(&s.lease)) {
        coherent_frame_cancel_atomic(0x8000);
        _ = model_input_abort_frame(&s.lease);
    } else if (l.entered != 0 and state.scope == s and s.usable != 0 and state.live(&s.lease) and state.active and s.source != 0 and s.projection_complete == 0 and state.journal.failed == 0) {
        state.failed(&s.lease, s.actor, &s.request, null, 14);
    }
    if (l.entered != 0) {
        if (state.scope == s and state.lexical == l) {
            state.lexical = l.previous;
            state.scope = s.previous;
            if (state.depth != 0) state.depth -= 1 else state.disable();
            s.linked = 0;
        } else state.disable();
    }
}
pub export fn model_input_ready() c_int {
    return @intFromBool(state.clonewars_model_input_installed == 31);
}
pub export fn model_input_bind_cohort(original: ?*const Token) c_int {
    if (@atomicLoad(i32, &state.disabled, .seq_cst) != 0 or !state.binding.bind(original)) return 0;
    state.initialized_serial = 0;
    return 1;
}
pub export fn model_input_frame_lease_get(out: ?*t.Lease) c_int {
    return @intFromBool(state.binding.get(out));
}
pub export fn model_input_frame_cancelled(op: ?*const t.Lease) c_int {
    return @intFromBool(state.binding.cancelled(op));
}
pub export fn model_input_abort_frame(op: ?*const t.Lease) c_int {
    if (!state.binding.detach(op)) return 0;
    state.active = false;
    @atomicStore(i32, &state.cancelled, 1, .seq_cst);
    state.journal = std.mem.zeroes(t.Journal);
    return 1;
}
pub export fn model_input_cancel() void {
    if (state.binding.bound) return;
    state.active = false;
    @atomicStore(i32, &state.cancelled, 1, .seq_cst);
    state.clonewars_model_input_debug[14] +%= 1;
}
pub export fn model_input_begin(frame: *p.SyncFrame, host: c_int) c_int {
    if (@atomicLoad(i32, &state.disabled, .seq_cst) != 0) return 0;
    var op: t.Lease = undefined;
    if (!state.binding.get(&op) or !state.binding.live(&op) or coherent_frame_valid(&op.cohort, 2) == 0 or op.cohort.frame != @intFromPtr(frame) or state.initialized_serial == op.serial) return 0;
    state.initialized_serial = op.serial;
    if ((state.scope != null or state.lexical != null) and (state.lexical == null or state.scope != &state.lexical.?.scope)) {
        state.disable();
        return 0;
    }
    @atomicStore(i32, &state.cancelled, 0, .seq_cst);
    if (state.last_epoch != op.cohort.epoch) {
        state.clonewars_model_input_failure = @splat(0);
        state.clonewars_model_input_first_correction = @splat(0);
        state.clonewars_model_input_first_outcome = std.mem.zeroes(t.Outcome);
        state.last_epoch = op.cohort.epoch;
        state.first_actor = 0;
        state.first_controller = 0;
        state.first_generation = 0;
    }
    model_input_journal_begin(&state.journal, frame, host);
    state.early_entries = .empty;
    state.active_thread = win.GetCurrentThreadId();
    state.active = true;
    return @intFromBool(state.live(&op));
}
pub export fn model_input_cancelled() c_int {
    return @intFromBool(@atomicLoad(i32, &state.cancelled, .seq_cst) != 0);
}
pub export fn model_input_finish() c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var op: t.Lease = undefined;
    if (!state.binding.get(&op) or !state.live(&op)) return 0;
    @import("model_projection.zig").outcome(&op);
    if (!state.live(&op)) return 0;
    if ((state.scope != null or state.depth != 0) and state.active and state.journal.failed == 0) state.failed(&op, 0, null, null, 15);
    state.active = false;
    state.clonewars_model_input_debug[4] +%= 1;
    const good = state.journal.finish();
    if (good == 0 and state.journal.failed == 0) state.failed(&op, 0, state.journal.peek(), null, 3);
    return good;
}
pub export fn model_input_install() c_int {
    return @import("model_install.zig").install();
}
comptime {
    _ = @import("model_request.zig");
}
