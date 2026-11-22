const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const tracking = @import("projectile_tracking.zig");
const creation = @import("projectile_creation.zig");
const removal = @import("projectile_removal.zig");
const retire = @import("projectile_retire.zig");
const Token = @import("cohort_types.zig").Token;
const equal = @import("validation.zig").equal;
pub fn reset(normalize: bool) void {
    if (!normalize and s.last_session != 0) {
        s.revoked_session = s.last_session;
        s.revoked_session_epoch = s.last_session_epoch;
    }
    if (s.reset_generation != std.math.maxInt(u64)) s.reset_generation += 1 else {
        const operation = std.mem.zeroes(t.Operation);
        control.reject(&operation, t.exhausted);
        return;
    }
    if (s.frame_associated) @import("projectile_constructor.zig").abort(&s.frame_lease.cohort);
    @import("projectile_constructor.zig").close();
    s.lifecycle_serial +%= 1;
    if (s.lifecycle_serial == 0) s.lifecycle_serial +%= 1;
    s.detachFire();
    @atomicStore(i32, &s.clonewars_projectile_failure_committed, 0, .seq_cst);
    s.clonewars_projectile_stack_debug = @splat(0);
    s.frame_bound = false;
    s.frame_started = false;
    s.frame_complete = false;
    s.dispatch_completed = false;
    if (s.frame_associated) s.binding_cancelled = true;
    s.current = null;
    s.level = -1;
    s.next_id = 0;
    s.failed = false;
    s.pending_count = 0;
    s.network_active = false;
    s.authority = false;
    s.tracked = std.mem.zeroes(@TypeOf(s.tracked));
    s.instance_serial = @splat(0);
    s.creation_count = @splat(0);
    s.next_instance_serial = 0;
    s.legacy = @splat(0);
    s.legacy_version = @splat(0);
    s.next_legacy_version = 0;
    s.retire_pending = std.mem.zeroes(@TypeOf(s.retire_pending));
    s.retire_batch = std.mem.zeroes(@TypeOf(s.retire_batch));
    s.retire_pending_count = 0;
    s.retire_batch_count = 0;
    s.retire_dispatch_done = false;
}
pub export fn projectiles_reset() void {
    reset(false);
}
fn provenanceMatches(provenance: *const t.Provenance, token: *const Token, session: *const t.Session, level: i32) bool {
    return provenance.committed != 0 and provenance.epoch == token.epoch and provenance.level == level and provenance.release == token.release and provenance.session == session.session and provenance.generation == s.reset_generation;
}
pub export fn projectiles_begin(frame: *p.SyncFrame, host: c_int) c_int {
    if (!control.threadOwned() or !s.frame_associated or s.binding_cancelled or s.frame_started or s.frame_lease.cohort.frame != @intFromPtr(frame) or !control.frameContextLive() or s.coherent_frame_valid(&s.frame_lease.cohort, 2) == 0) return 0;
    const captured = s.frame_lease.cohort;
    var session = std.mem.zeroes(t.Session);
    if (s.adapter != null and (!control.sessionRead(&session) or !control.sessionPermission(&session) or session.epoch != captured.epoch or session.level != frame.level or session.host != @intFromBool(host != 0) or session.classification == t.fault or session.classification == 0)) {
        s.binding_cancelled = true;
        s.coherent_frame_cancel_atomic(0x200000);
        return 0;
    }
    if (s.adapter != null) control.accept(&session);
    @import("projectile_constructor.zig").close();
    if (s.level != frame.level) {
        if (s.pending_count != 0) {
            var adopt = s.adapter != null and host != 0 and s.level == -1;
            var i: usize = 0;
            while (adopt and i < s.pending_count) : (i += 1) adopt = provenanceMatches(&s.pending_provenance[i], &captured, &session, frame.level);
            if (!adopt) {
                s.binding_cancelled = true;
                s.coherent_frame_cancel_atomic(0x100000);
                return 0;
            }
            s.level = frame.level;
        } else {
            const original = s.frame_lease;
            reset(true);
            s.frame_lease = original;
            s.frame_associated = true;
            s.binding_cancelled = false;
            s.level = frame.level;
        }
    }
    if (s.coherent_frame_valid(&captured, 14) == 0) return 0;
    if (s.adapter != null) {
        var now: t.Session = undefined;
        if (!control.sessionRead(&now) or !equal(&session, &now)) {
            s.binding_cancelled = true;
            var rejected = std.mem.zeroes(t.Operation);
            rejected.kind = t.keyed;
            rejected.frame = s.frame_lease;
            control.reject(&rejected, t.unavailable);
            return 0;
        }
    }
    s.current = frame;
    s.host = host != 0;
    s.frame_lifecycle = s.lifecycle_serial;
    s.frame_started = true;
    s.frame_bound = true;
    s.frame_associated = true;
    s.retire_dispatch_done = false;
    const op = control.capture();
    @import("projectile_constructor.zig").begin();
    s.network_active = true;
    s.consumed = @splat(0);
    if (host != 0) {
        if (!control.live(&op)) return 0;
        if (s.adapter != null) for (s.pending_provenance[0..s.pending_count]) |*provenance| if (!provenanceMatches(provenance, &captured, &session, s.level)) {
            s.binding_cancelled = true;
            control.reject(&op, t.provenance);
            return 0;
        };
        frame.shot_count = @intCast(s.pending_count);
        frame.projectile_count = 0;
        @memcpy(frame.shots[0..s.pending_count], s.pending[0..s.pending_count]);
        s.pending_count = 0;
        return @intFromBool(control.live(&op));
    }
    if (!control.live(&op)) return 0;
    s.authority = frame.combat_ready != 0;
    const manager = s.read(usize, 0xe9019c);
    if (!s.valid(manager, 0x3c)) {
        if (control.live(&op)) s.failed = true;
        return @intFromBool(control.live(&op));
    }
    if (s.authority) for (0..p.SYNC_MAX_PROJECTILES) |i| {
        const object = s.legacy[i];
        if (object == 0) continue;
        if (!control.live(&op)) return 0;
        const version = s.legacy_version[i];
        var call = std.mem.zeroes(removal.Call);
        call.op = op;
        call.manager = s.read(usize, manager + 0x38);
        call.object = object;
        if (s.valid(object, 0x210)) {
            if (!control.live(&op)) return 0;
            _ = removal.observed(&call, 2);
        }
        if (!control.live(&op)) return 0;
        if (s.legacy[i] == object and s.legacy_version[i] == version) _ = control.legacySet(&op, i, 0);
    };
    var i: usize = 0;
    while (true) : (i += 1) {
        if (!control.live(&op)) return 0;
        if (i >= frame.shot_count) break;
        if (s.consumed[i] != 0 or frame.shots[i].phase != 1) continue;
        const shot = &frame.shots[i];
        const owner = if (shot.owner < 0) 0 else tracking.actorAt(shot.owner, shot.owner_generation);
        if (!control.live(&op)) return 0;
        if (shot.owner >= 0 and owner == 0) continue;
        s.consumed[i] = 1;
        _ = creation.replay(&op, manager, shot, 0, 0);
        if (!control.live(&op)) return 0;
    }
    return @intFromBool(control.live(&op));
}
fn has(frame: *const p.SyncFrame, id: u32) bool {
    var lo: usize = 0;
    var hi: usize = frame.projectile_count;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (frame.projectiles[mid].id < id) lo = mid + 1 else hi = mid;
    }
    return lo < frame.projectile_count and frame.projectiles[lo].id == id;
}
fn quiet(op: *const t.Operation) bool {
    if (!control.live(op) or s.failed or !s.dispatch_completed or s.dispatch_revision != s.dispatch_completed_revision) return false;
    if (!s.host) for (0..p.SYNC_MAX_PROJECTILES) |i| {
        const id = s.tracked[i].birth.id;
        if (id == 0) continue;
        if (!control.live(op) or !has(s.current.?, id)) return false;
    };
    return control.live(op);
}
pub export fn projectiles_dispatch_revision(original: ?*const Token, output: ?*u64) c_int {
    const token = original orelse return 0;
    const out = output orelse return 0;
    if (control.projectiles_cohort_valid(token) == 0 or s.coherent_frame_valid(token, 4) == 0) return 0;
    out.* = s.dispatch_revision;
    return @intFromBool(control.projectiles_cohort_valid(token) != 0 and s.coherent_frame_valid(token, 4) != 0);
}
pub export fn projectiles_dispatch_pending() c_int {
    const op = control.capture();
    if (op.kind != t.keyed or !control.live(&op) or s.failed or s.coherent_frame_valid(&op.frame.cohort, 4) == 0) return -1;
    if (!retire.dispatch(&op)) return -1;
    return if (quiet(&op)) 0 else 1;
}
pub export fn projectiles_dispatch_complete() c_int {
    const op = control.capture();
    if (op.kind != t.keyed or !control.live(&op) or projectiles_dispatch_pending() != 1) return 0;
    s.dispatch_completed = false;
    const frame = s.current.?;
    if (s.host) {
        s.dispatch_completed_revision = s.dispatch_revision;
        s.dispatch_completed = true;
        return 1;
    }
    const manager = s.read(usize, 0xe9019c);
    if (!s.valid(manager, 0x3c)) {
        if (control.live(&op)) s.failed = true;
    } else {
        for (frame.shots[0..frame.shot_count], 0..) |*shot, i| {
            if (!control.live(&op)) return 0;
            if (s.consumed[i] != 0 or shot.phase != 0 or !creation.canReplayAfterTick(frame.level, shot)) continue;
            s.consumed[i] = 1;
            _ = creation.replay(&op, manager, shot, 0, 0);
        }
        var i: u32 = 0;
        while (true) : (i += 1) {
            if (!control.live(&op)) return 0;
            if (i >= frame.projectile_count) break;
            const state = &frame.projectiles[i];
            const entry = tracking.find(state.id) orelse {
                var birth: u32 = 0;
                while (birth < frame.shot_count and frame.shots[birth].id != state.id) : (birth += 1) {}
                var owner: usize = 0;
                if (birth < frame.shot_count) owner = tracking.actorAt(frame.shots[birth].owner, frame.shots[birth].owner_generation) else birth = std.math.maxInt(u32);
                tracking.failure(&op, 4, owner, 0, state.id, 0, 0, birth);
                if (!control.live(&op)) return 0;
                s.failed = true;
                continue;
            };
            if (!s.valid(entry.object, 0x210)) {
                if (!control.live(&op)) return 0;
                tracking.failure(&op, 5, tracking.actorAt(entry.birth.owner, entry.birth.owner_generation), 0, state.id, entry.object, 0, std.math.maxInt(u32));
                if (!control.live(&op)) return 0;
                s.failed = true;
                continue;
            }
            if (!control.live(&op)) return 0;
            if (s.read(usize, entry.object + 0x14) != entry.resource or s.read(u32, entry.object + 8) != entry.native_stamp) {
                tracking.failure(&op, 5, tracking.actorAt(entry.birth.owner, entry.birth.owner_generation), 0, state.id, entry.object, 0, std.math.maxInt(u32));
                if (!control.live(&op)) return 0;
                s.failed = true;
                continue;
            }
            if (!tracking.correct(&op, state, entry)) return 0;
        }
        for (0..p.SYNC_MAX_PROJECTILES) |index| {
            const entry = &s.tracked[index];
            const id = entry.birth.id;
            if (id == 0) continue;
            if (!control.live(&op)) return 0;
            if (has(frame, id)) continue;
            const instance = s.instance_serial[index];
            const object = entry.object;
            const resource = entry.resource;
            var call = std.mem.zeroes(removal.Call);
            call.op = op;
            call.manager = s.read(usize, manager + 0x38);
            call.object = object;
            if (s.valid(object, 0x210)) {
                if (!control.live(&op)) return 0;
                if (s.read(usize, object + 0x14) == resource) _ = removal.observed(&call, 1);
            }
            if (!control.live(&op)) return 0;
            if (entry.birth.id == id and s.instance_serial[index] == instance) entry.* = std.mem.zeroes(t.Tracked);
        }
    }
    if (!control.live(&op) or s.failed) return 0;
    s.dispatch_completed_revision = s.dispatch_revision;
    s.dispatch_completed = true;
    return 1;
}
fn less(_: void, a: p.SyncProjectile, b: p.SyncProjectile) bool {
    return a.id < b.id;
}
pub export fn projectiles_finish() c_int {
    const op = control.capture();
    if (op.kind != t.keyed or !control.live(&op) or !quiet(&op) or s.coherent_frame_valid(&op.frame.cohort, 8) == 0) return 0;
    const frame = s.current.?;
    if (s.host) {
        for (&s.tracked) |*entry| {
            if (entry.birth.id == 0) continue;
            if (!control.live(&op)) return 0;
            if (!s.valid(entry.object, 0x210)) {
                if (!control.live(&op)) return 0;
                entry.* = std.mem.zeroes(t.Tracked);
                continue;
            }
            if (!control.live(&op)) return 0;
            if (s.read(usize, entry.object + 0x14) != entry.resource) {
                entry.* = std.mem.zeroes(t.Tracked);
                continue;
            }
            if (frame.projectile_count == p.SYNC_MAX_PROJECTILES) {
                s.failed = true;
                break;
            }
            if (!tracking.capture(&op, &frame.projectiles[frame.projectile_count], entry)) return 0;
            if (!control.live(&op)) return 0;
            frame.projectile_count += 1;
        }
        if (!control.live(&op)) return 0;
        std.mem.sortUnstable(p.SyncProjectile, frame.projectiles[0..frame.projectile_count], {}, less);
        if (!control.live(&op)) return 0;
        frame.combat_ready = @intFromBool(s.next_id != 0);
    } else {
        var i: u32 = 0;
        while (true) : (i += 1) {
            if (!control.live(&op)) return 0;
            if (i >= frame.shot_count) break;
            if (s.consumed[i] == 0) {
                const shot = &frame.shots[i];
                const owner = tracking.actorAt(shot.owner, shot.owner_generation);
                if (!control.live(&op)) return 0;
                tracking.failure(&op, 3, owner, 0, 0, 0, 0, i);
                if (!control.live(&op)) return 0;
                s.failed = true;
            }
        }
    }
    if (!control.live(&op)) return 0;
    s.clonewars_projectile_debug[0] = frame.shot_count;
    s.clonewars_projectile_debug[1] = frame.projectile_count;
    s.clonewars_projectile_debug[5] = @intFromBool(s.failed);
    s.clonewars_projectile_debug[6] = frame.sequence;
    s.clonewars_projectile_debug[10] = @truncate(@intFromPtr(&s.tracked));
    s.clonewars_projectile_debug[11] = @sizeOf(t.Tracked);
    if (s.failed or !control.live(&op)) return 0;
    @import("projectile_constructor.zig").close();
    s.current = null;
    s.frame_bound = false;
    s.frame_complete = true;
    s.network_active = false;
    s.authority = false;
    return 1;
}
