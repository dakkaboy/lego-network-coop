const std = @import("std");
const s = @import("projectile_state.zig");
const t = s.t;
const Token = @import("cohort_types.zig").Token;
const equal = @import("validation.zig").equal;
pub fn sessionRead(output: *t.Session) bool {
    const provider = s.session_provider orelse return false;
    if (provider(output, s.control_user) == 0 or output.host > 1 or output.classification > t.fault) return false;
    return output.classification != t.established or (output.session != 0 and output.epoch != 0 and output.level >= 0 and output.level < 4096);
}
pub fn sessionPermission(session: *const t.Session) bool {
    if (session.session == 0 or session.epoch == 0 or (session.session == s.revoked_session and session.epoch == s.revoked_session_epoch)) return false;
    return s.last_session == 0 or (session.session == s.last_session and session.epoch == s.last_session_epoch) or ((session.session > s.last_session or (session.session == s.last_session and session.epoch > s.last_session_epoch)) and s.level == -1 and s.pending_count == 0 and s.next_id == 0);
}
pub fn accept(session: *const t.Session) void {
    s.last_session = session.session;
    s.last_session_epoch = session.epoch;
}
pub fn frameContextLive() bool {
    const thread = @atomicLoad(u32, &s.main_thread, .seq_cst);
    if (thread == 0 or thread != s.win.GetCurrentThreadId()) return false;
    if (s.adapter == null) return true;
    var now: t.Session = undefined;
    return s.frame_associated and s.frame_context.session != 0 and sessionRead(&now) and now.session == s.frame_context.session and now.epoch == s.frame_context.epoch and now.level == s.frame_context.level and now.host == s.frame_context.host;
}
pub fn threadOwned() bool {
    const own = @atomicLoad(u32, &s.main_thread, .seq_cst);
    const thread = s.win.GetCurrentThreadId();
    if (own != 0) return own == thread;
    var token: Token = undefined;
    var lease: t.ControlLease = undefined;
    var proven: u32 = 0;
    if (s.coherent_frame_get(&token, 0x3e) != 0) proven = token.thread else if (s.adapter) |adapter| {
        if (s.span_engine_control_get(adapter, &lease) != 0) proven = lease.thread;
    }
    if (proven == 0) return false;
    const prior = @cmpxchgStrong(u32, &s.main_thread, 0, proven, .seq_cst, .seq_cst) orelse 0;
    return prior == 0 or prior == thread;
}
pub export fn projectiles_configure_coherent(adapter: ?*t.Adapter, provider: ?t.SessionProvider, reject_provider: ?t.RejectProvider, user: usize) c_int {
    const a = adapter orelse return 0;
    if (provider == null or reject_provider == null or a.window_thread != s.win.GetCurrentThreadId() or a.callbacks.main_confirmed == null or a.callbacks.main_confirmed.?(s.win.GetCurrentThreadId(), a.callbacks.user) == 0) return 0;
    if (s.adapter != null) return @intFromBool(s.adapter == a and s.session_provider == provider and s.reject_provider == reject_provider and s.control_user == user);
    var token: Token = undefined;
    if (s.frame_associated or s.active_fire != null or s.pending_count != 0 or s.coherent_frame_get(&token, 0x3e) != 0) return 0;
    s.adapter = a;
    s.session_provider = provider;
    s.reject_provider = reject_provider;
    s.control_user = user;
    _ = @cmpxchgStrong(u32, &s.main_thread, 0, s.win.GetCurrentThreadId(), .seq_cst, .seq_cst);
    return 1;
}
pub export fn projectiles_cohort_capabilities() c_uint {
    return 3;
}
pub export fn projectiles_control_pending_missing() c_int {
    return @intFromBool(s.adapter == null or s.session_provider == null or s.reject_provider == null);
}
pub export fn projectiles_cohort_ready() c_int {
    return @intFromBool(projectiles_control_pending_missing() == 0 and @atomicLoad(i32, &s.hooks_installed, .seq_cst) != 0);
}
pub fn frameLive() bool {
    return threadOwned() and s.frame_bound and frameContextLive() and s.coherent_frame_valid(&s.frame_lease.cohort, 14) != 0 and !s.binding_cancelled and s.frame_lifecycle == s.lifecycle_serial and s.current != null and @intFromPtr(s.current.?) == s.frame_lease.cohort.frame;
}
pub export fn projectiles_bind_cohort(original: ?*const Token) c_int {
    const token = original orelse return 0;
    if (!threadOwned()) return 0;
    var session = std.mem.zeroes(t.Session);
    if (s.adapter != null and (!sessionRead(&session) or session.session == 0 or session.epoch != token.epoch or (s.frame_associated and !frameContextLive()))) return 0;
    if (s.coherent_frame_valid(token, 2) == 0 or (s.retired_frame_valid and equal(token, &s.retired_frame_token))) return 0;
    if (s.frame_associated) return @intFromBool(equal(token, &s.frame_lease.cohort) and !s.binding_cancelled and s.coherent_frame_valid(token, 2) != 0);
    if (s.next_binding == std.math.maxInt(u32)) {
        s.coherent_frame_cancel_atomic(0x100000);
        return 0;
    }
    s.next_binding += 1;
    s.frame_lease = .{ .serial = s.next_binding, .cohort = token.* };
    s.frame_context = session;
    s.frame_associated = true;
    s.frame_started = false;
    s.frame_complete = false;
    s.binding_cancelled = false;
    s.dispatch_completed = false;
    s.dispatch_revision = 0;
    s.dispatch_completed_revision = 0;
    s.current = null;
    return 1;
}
pub export fn projectiles_cohort_valid(original: ?*const Token) c_int {
    const token = original orelse return 0;
    return @intFromBool(threadOwned() and s.frame_associated and !s.binding_cancelled and equal(token, &s.frame_lease.cohort) and frameContextLive() and s.coherent_frame_valid(token, 0x3e) != 0);
}
pub export fn projectiles_frame_cancelled(captured: ?*const t.Lease) c_int {
    const lease = captured orelse return 1;
    return @intFromBool(!threadOwned() or !s.frame_associated or lease.serial != s.frame_lease.serial or s.binding_cancelled or !equal(&lease.cohort, &s.frame_lease.cohort) or !frameContextLive() or s.coherent_frame_valid(&lease.cohort, 0x3e) == 0);
}
pub export fn projectiles_frame_lease_get(output: ?*t.Lease) c_int {
    const out = output orelse return 0;
    if (!threadOwned() or !s.frame_associated or s.frame_lease.cohort.thread != s.win.GetCurrentThreadId()) return 0;
    out.* = s.frame_lease;
    return 1;
}
pub fn controlValid(lease: *const t.ControlLease, session: *const t.Session, generation: u64) bool {
    const adapter = s.adapter orelse return false;
    var now: t.Session = undefined;
    if (generation != s.reset_generation or s.frame_bound or s.span_engine_control_valid(adapter, lease) == 0 or !sessionRead(&now) or !equal(session, &now) or !sessionPermission(&now) or now.classification != t.established or now.epoch == 0 or now.epoch != lease.epoch or now.level != lease.level) return false;
    return s.span_engine_control_valid(adapter, lease) != 0;
}
pub fn reject(operation: ?*const t.Operation, reason: u32) void {
    var context = std.mem.zeroes(t.Reject);
    if (operation) |op| {
        if (op.session.session != 0 and op.session.epoch != 0) {
            s.revoked_session = op.session.session;
            s.revoked_session_epoch = op.session.epoch;
        }
        context.capability = op.kind;
        if (op.kind == t.control) {
            context.epoch = op.control.epoch;
            context.level = op.control.level;
            context.release = op.control.release;
        } else if (op.kind == t.keyed) {
            context.epoch = op.frame.cohort.epoch;
            context.level = op.session.level;
            context.release = op.frame.cohort.release;
            context.sequence = op.frame.cohort.sequence;
        } else {
            context.epoch = op.session.epoch;
            context.level = op.session.level;
            context.release = s.coherent_frame_release();
        }
    }
    s.coherent_frame_cancel_atomic(0x200000);
    if (s.reject_provider) |provider| provider(reason, &context, s.control_user);
}
pub fn live(operation: ?*const t.Operation) bool {
    const op = operation orelse return false;
    if (!threadOwned() or op.serial != s.lifecycle_serial) return false;
    if (op.kind == t.control) return controlValid(&op.control, &op.session, op.reset_generation);
    if (op.kind == t.unkeyed or op.kind == t.barrier) return !s.frame_bound and s.current == null;
    return op.kind == t.keyed and op.session.session == s.frame_context.session and frameContextLive() and s.coherent_frame_valid(&op.frame.cohort, 14) != 0 and s.frame_bound and equal(&op.frame.cohort, &s.frame_lease.cohort) and op.frame.serial == s.frame_lease.serial and !s.binding_cancelled and s.current != null and @intFromPtr(s.current.?) == op.frame.cohort.frame;
}
pub fn capture() t.Operation {
    var op = std.mem.zeroes(t.Operation);
    op.kind = t.rejected;
    if (!threadOwned()) return op;
    op.serial = s.lifecycle_serial;
    op.reset_generation = s.reset_generation;
    if (s.frame_bound) {
        op.frame = s.frame_lease;
        op.session.epoch = s.frame_lease.cohort.epoch;
        op.session.level = s.level;
        op.session.host = @intFromBool(s.host);
        op.session.session = s.frame_context.session;
        op.kind = t.keyed;
        if (!live(&op)) op.kind = t.rejected;
        return op;
    }
    const adapter = s.adapter orelse {
        if (!s.frame_associated) op.kind = t.unkeyed;
        return op;
    };
    if (!sessionRead(&op.session)) {
        op.kind = t.control_fault;
        return op;
    }
    if (op.session.classification == t.offline or op.session.classification == t.bootstrap or op.session.classification == t.transition) {
        op.kind = t.barrier;
        return op;
    }
    if (op.session.classification == t.established and s.span_engine_control_get(adapter, &op.control) != 0 and controlValid(&op.control, &op.session, op.reset_generation)) {
        accept(&op.session);
        op.kind = t.control;
        return op;
    }
    op.kind = if (op.session.classification == t.established and op.session.host == 0) t.client_decline else t.control_fault;
    return op;
}
pub fn admit(operation: *const t.Operation) void {
    if (operation.kind == t.control_fault) reject(operation, t.unavailable);
}
pub fn exception(operation: *const t.Operation) void {
    if (operation.kind == t.keyed or operation.kind == t.control) reject(operation, t.exception);
}
pub fn dispatchChanged(op: *const t.Operation) void {
    if (op.kind != t.keyed or !live(op)) return;
    if (s.dispatch_revision == std.math.maxInt(u64)) reject(op, t.exhausted) else s.dispatch_revision += 1;
}
pub export fn projectiles_lifecycle_serial() u32 {
    return s.lifecycle_serial;
}
pub fn legacySet(op: *const t.Operation, index: usize, object: usize) bool {
    if (!live(op)) return false;
    if (s.next_legacy_version == std.math.maxInt(u64)) {
        exception(op);
        return false;
    }
    s.next_legacy_version += 1;
    s.legacy_version[index] = s.next_legacy_version;
    s.legacy[index] = object;
    dispatchChanged(op);
    return live(op);
}
pub export fn projectiles_abort_frame(captured: ?*const t.Lease) c_int {
    const lease = captured orelse return 0;
    if (lease.cohort.thread != s.win.GetCurrentThreadId() or !threadOwned() or !s.frame_associated or s.frame_lease.serial != lease.serial or !equal(&lease.cohort, &s.frame_lease.cohort)) return 0;
    @import("projectile_constructor.zig").abort(&lease.cohort);
    @import("projectile_constructor.zig").close();
    s.retired_frame_token = lease.cohort;
    s.retired_frame_valid = true;
    s.lifecycle_serial +%= 1;
    if (s.lifecycle_serial == 0) s.lifecycle_serial +%= 1;
    s.detachFire();
    s.current = null;
    s.network_active = false;
    s.authority = false;
    s.frame_bound = false;
    s.frame_associated = false;
    s.frame_started = false;
    s.frame_complete = false;
    s.binding_cancelled = true;
    return 1;
}
