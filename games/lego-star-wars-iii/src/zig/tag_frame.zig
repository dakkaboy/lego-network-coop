const std = @import("std");
const s = @import("tag_state.zig");
const p = s.p;
const guard = @import("tag_guard.zig");
const events = @import("tag_events.zig");
pub fn reset() void {
    s.initial_control_available = false;
    s.scope_was_cancelled = s.scope_was_cancelled or s.current != null;
    s.scope_serial +%= 1;
    s.pending_generation +%= 1;
    s.current = null;
    s.pending_count = 0;
    s.epoch = 0;
    s.next_id = 0;
    s.last_applied = 0;
    s.replay_cursor = 0;
    s.active = false;
    s.failed = 0;
    s.frame_complete = false;
    s.active_event = 0;
    s.replay_completed = 0;
    s.replay_corrected = 0;
    s.cohort_bound = false;
}
pub export fn tags_reset() void {
    if (s.adapter) |adapter| if (s.win.GetCurrentThreadId() != adapter.window_thread) {
        s.reject(19);
        return;
    };
    if (s.active or s.pending_count != 0 or s.epoch != 0) s.reject(19);
    reset();
}
pub export fn tags_begin(frame: *p.SyncFrame, host: c_int) c_int {
    const captured = s.cohort;
    const original_binding = s.binding_serial;
    if (!s.cohort_bound or captured.frame != @intFromPtr(frame) or guard.tags_cohort_valid(&captured, 2) == 0) return -1;
    var session: s.Session = undefined;
    if (s.session_provider == null or s.session_provider.?(&session) == 0 or session.session == 0 or session.session == std.math.maxInt(u32)) return -1;
    if (s.epoch != frame.epoch or (s.active_session != 0 and s.active_session != session.session)) {
        if (s.pending_count != 0 or (s.last_authorized_session != 0 and (session.session < s.last_authorized_session or (session.session == s.last_authorized_session and captured.epoch <= s.last_authorized_epoch)))) {
            s.reject(23);
            return -1;
        }
        reset();
        s.epoch = frame.epoch;
        s.cohort = captured;
        s.binding_serial = original_binding;
        s.cohort_bound = true;
        s.cohort_cancelled = false;
    }
    s.active_session = session.session;
    s.last_authorized_session = session.session;
    s.last_authorized_epoch = captured.epoch;
    s.frame_complete = false;
    if (frame.tag_count > p.SYNC_MAX_TAGS) return 0;
    s.scope_serial +%= 1;
    const serial = s.scope_serial;
    s.current = frame;
    s.host = host != 0;
    s.active = true;
    s.frame_complete = false;
    s.scope_was_cancelled = false;
    s.active_event = 0;
    s.replay_completed = 0;
    s.replay_corrected = 0;
    s.consumed = @splat(0);
    if (host != 0) {
        for (s.provenance[0..s.pending_count]) |provenance| if (provenance.committed == 0 or provenance.epoch != captured.epoch or provenance.level != frame.level or provenance.session != session.session or provenance.release != captured.release or provenance.generation != s.pending_generation) {
            s.scope_was_cancelled = true;
            s.current = null;
            return -1;
        };
        frame.tag_count = @intCast(s.pending_count);
        @memcpy(frame.tags[0..s.pending_count], s.pending[0..s.pending_count]);
        s.pending_count = 0;
    } else {
        var i: usize = 0;
        while (guard.scope(serial, frame) and i < frame.tag_count) : (i += 1) {
            if (frame.tags[i].id <= s.replay_cursor) s.consumed[i] = 1 else if (frame.tags[i].phase != 0 and events.replay(i, true, null) == 0) break;
        }
    }
    if (!guard.scope(serial, frame)) return -1;
    s.clonewars_tag_debug[3] = s.failed;
    s.clonewars_tag_debug[4] = @intCast(s.pending_count);
    s.clonewars_tag_debug[10] = frame.sequence;
    if (s.failed != 0) s.current = null;
    return @intFromBool(s.failed == 0);
}
pub export fn tags_cancel() void {
    if (s.adapter) |adapter| if (s.win.GetCurrentThreadId() != adapter.window_thread) {
        s.reject(19);
        return;
    };
    if (s.active or s.cohort_bound or s.pending_count != 0) s.reject(19);
    s.cohort_cancelled = true;
    s.scope_was_cancelled = s.scope_was_cancelled or s.current != null;
    s.scope_serial +%= 1;
    s.pending_generation +%= 1;
    s.current = null;
    s.active = false;
    s.active_event = 0;
    s.replay_completed = 0;
    s.replay_corrected = 0;
}
pub export fn tags_dispatch_revision(original: ?*const s.Token, output: ?*u64) c_int {
    const token = original orelse return 0;
    const out = output orelse return 0;
    if (guard.tags_cohort_valid(token, 4) == 0) return 0;
    out.* = s.dispatch_revision;
    return guard.tags_cohort_valid(token, 4);
}
pub export fn tags_dispatch_pending() c_int {
    var authority: s.Guard = undefined;
    if (!guard.frame(&authority) or s.coherent_frame_valid(&authority.frame, 4) == 0 or s.failed != 0) return -1;
    if (s.host) return 0;
    const frame = s.current.?;
    if (frame.tag_count > p.SYNC_MAX_TAGS) return -1;
    for (s.consumed[0..frame.tag_count]) |consumed| if (consumed == 0) return 1;
    return 0;
}
pub export fn tags_dispatch_complete() c_int {
    var authority: s.Guard = undefined;
    if (!guard.frame(&authority) or s.coherent_frame_valid(&authority.frame, 4) == 0 or s.failed != 0) return -1;
    if (!s.host) {
        const frame = s.current.?;
        var i: usize = 0;
        while (guard.valid(&authority) and i < frame.tag_count) : (i += 1) {
            if (s.consumed[i] != 0) continue;
            if (frame.tags[i].source == p.SYNC_TAG_ACTOR_UPDATE) {
                s.failed = 6;
                break;
            }
            if (events.replay(i, true, null) == 0) break;
        }
    }
    if (!guard.valid(&authority)) return -1;
    return @intFromBool(s.failed == 0);
}
pub export fn tags_finish() c_int {
    const frame = s.current orelse return if (s.scope_was_cancelled) -1 else 0;
    const serial = s.scope_serial;
    if (!guard.scope(serial, frame)) return -1;
    if (!s.host) for (s.consumed[0..frame.tag_count]) |consumed| if (consumed == 0) {
        s.failed = 6;
        break;
    };
    if (!guard.scope(serial, frame)) return -1;
    if (!s.host and s.failed == 0 and s.entities_party_matches(frame) == 0) s.failed = 5;
    if (!guard.scope(serial, frame)) return -1;
    s.clonewars_tag_debug[11] = @intFromBool(s.failed == 5);
    s.clonewars_tag_debug[3] = s.failed;
    s.frame_complete = s.failed == 0;
    s.current = null;
    return @intFromBool(s.failed == 0);
}
