const std = @import("std");
const s = @import("tag_state.zig");
const equal = @import("validation.zig").equal;
pub export fn tags_configure_coherent(adapter: ?*s.Adapter, provider: ?s.SessionProvider) c_int {
    if (s.adapter != null or adapter == null or provider == null) return 0;
    s.adapter = adapter;
    s.session_provider = provider;
    return 1;
}
pub export fn tags_cohort_valid(original: ?*const s.Token, phases: u32) c_int {
    const token = original orelse return 0;
    if (!s.cohort_bound or s.cohort_cancelled or !equal(token, &s.cohort) or token.thread != s.win.GetCurrentThreadId()) return 0;
    var context: s.Session = undefined;
    const provider = s.session_provider orelse return 0;
    if (provider(&context) == 0 or s.bound_session == 0 or context.session != s.bound_session) return 0;
    return s.coherent_frame_valid(token, phases);
}
pub export fn tags_bind_cohort(original: ?*const s.Token) c_int {
    if (s.adapter == null or s.session_provider == null) return 0;
    const token = original orelse return 0;
    var context: s.Session = undefined;
    if (token.thread != s.win.GetCurrentThreadId() or s.session_provider.?(&context) == 0 or context.session == 0 or context.session == std.math.maxInt(u32)) return 0;
    if (s.cohort_bound and equal(token, &s.cohort)) return tags_cohort_valid(token, 2);
    if (s.coherent_frame_valid(token, 2) == 0) return 0;
    if (s.cohort_bound and equal(token, &s.cohort)) return tags_cohort_valid(token, 2);
    if (s.cohort_bound and tags_cohort_valid(&s.cohort, 0x3e) != 0) return 0;
    if (s.binding_serial == std.math.maxInt(u64)) return 0;
    s.binding_serial += 1;
    s.cohort = token.*;
    s.bound_session = context.session;
    s.cohort_bound = true;
    s.cohort_cancelled = false;
    return tags_cohort_valid(token, 2);
}
pub export fn tags_frame_binding_get(out: ?*s.FrameBinding) c_int {
    const output = out orelse return 0;
    if (!s.cohort_bound or s.cohort.thread != s.win.GetCurrentThreadId()) return 0;
    output.* = .{ .token = s.cohort, .binding_serial = s.binding_serial };
    return 1;
}
pub export fn tags_abort_frame(captured: ?*const s.FrameBinding) c_int {
    const binding = captured orelse return 0;
    if (!s.cohort_bound or binding.token.thread != s.win.GetCurrentThreadId() or binding.binding_serial != s.binding_serial or !equal(&binding.token, &s.cohort)) return 0;
    s.cohort_bound = false;
    if (!s.frame_complete or s.failed != 0 or s.coherent_frame_release() != binding.token.release) {
        s.current = null;
        s.active = false;
        s.active_event = 0;
        s.scope_was_cancelled = true;
        s.scope_serial +%= 1;
        s.pending_generation +%= 1;
        s.replay_completed = 0;
        s.replay_corrected = 0;
    }
    return 1;
}
pub fn valid(guard: *const s.Guard) bool {
    if (guard.serial != s.scope_serial or guard.epoch != s.epoch) return false;
    const provider = s.session_provider orelse return false;
    var now: s.Session = undefined;
    if (provider(&now) == 0 or now.session != guard.session) return false;
    if (guard.kind == 1) return guard.binding == s.binding_serial and s.current != null and @intFromPtr(s.current.?) == guard.frame.frame and tags_cohort_valid(&guard.frame, 14) != 0;
    if (guard.kind == 2) {
        var control: s.Session = undefined;
        return s.current == null and provider(&control) != 0 and control.session == guard.session and guard.pending_generation == s.pending_generation and s.adapter != null and s.span_engine_control_valid(s.adapter.?, &guard.control) != 0;
    }
    return false;
}
pub fn frame(out: *s.Guard) bool {
    if (!s.active or s.current == null or !s.cohort_bound or s.cohort.frame != @intFromPtr(s.current.?) or tags_cohort_valid(&s.cohort, 14) == 0) return false;
    out.* = std.mem.zeroes(s.Guard);
    out.kind = 1;
    out.frame = s.cohort;
    out.serial = s.scope_serial;
    out.binding = s.binding_serial;
    out.pending_generation = s.pending_generation;
    out.epoch = s.epoch;
    out.session = s.active_session;
    return valid(out);
}
pub fn scope(serial: u64, current: *const s.p.SyncFrame) bool {
    var guard: s.Guard = undefined;
    return s.scope_serial == serial and s.current == current and frame(&guard);
}
