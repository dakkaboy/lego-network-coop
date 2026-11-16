const std = @import("std");
const s = @import("tag_state.zig");
const p = s.p;
const guard = @import("tag_guard.zig");
const native = @import("tag_native.zig");
pub fn replay(index: usize, preserve_context: bool, outcome: ?*s.Outcome) c_int {
    var authority: s.Guard = undefined;
    if (!guard.frame(&authority)) return 0;
    const frame = s.current.?;
    if (index >= frame.tag_count or index >= p.SYNC_MAX_TAGS) return 0;
    const tag = frame.tags[index];
    if (s.consumed[index] != 0) return 1;
    if (tag.id <= s.replay_cursor) {
        if (!s.progress()) return 0;
        s.consumed[index] = 1;
        return 1;
    }
    if (tag.id != s.replay_cursor + 1 or tag.parent != s.active_event) {
        s.failed = 1;
        return 0;
    }
    const from = native.resolveIdentity(tag.from, tag.from_generation, &tag.from_identity, &authority);
    if (!guard.valid(&authority)) return 0;
    const to = native.resolveIdentity(tag.to, tag.to_generation, &tag.to_identity, &authority);
    if (!guard.valid(&authority)) return 0;
    if (from == 0 or to == 0 or from == to) {
        s.failed = 2;
        return 0;
    }
    const previous = s.readClock();
    if (!guard.valid(&authority)) return 0;
    s.writeClock(.{ .clock = tag.clock, .rng_game = tag.rng_game, .rng_engine = tag.rng_engine, .delta = tag.delta });
    const parent = s.active_event;
    s.active_event = tag.id;
    if (!s.progress()) return 0;
    s.consumed[index] = 1;
    s.replay_cursor = tag.id;
    const result = native.callOriginal(from, to, &tag.arguments, &authority, outcome);
    if (!guard.valid(&authority)) return 0;
    if (result == 1) {
        _ = s.entities_bind_tick(frame);
        if (!guard.valid(&authority)) return 0;
    }
    s.active_event = parent;
    if (preserve_context) s.writeClock(previous);
    if (result != 1) {
        s.failed = 3;
        return 0;
    }
    var i = index + 1;
    while (i < frame.tag_count) : (i += 1) {
        if (!guard.valid(&authority)) return 0;
        if (s.consumed[i] == 0 and frame.tags[i].parent == tag.id) {
            s.failed = 6;
            return 0;
        }
    }
    s.replay_completed +%= 1;
    if (parent == 0) {
        s.last_applied = s.replay_cursor;
        s.clonewars_tag_debug[1] +%= s.replay_completed;
        s.clonewars_tag_debug[9] +%= s.replay_corrected;
        s.clonewars_tag_debug[5] = s.last_applied;
        s.clonewars_tag_debug[7] = @bitCast(tag.from);
        s.clonewars_tag_debug[8] = @bitCast(tag.to);
        s.replay_completed = 0;
        s.replay_corrected = 0;
    }
    return 1;
}
fn apply(from: usize, to: usize, args: *const [6]i32, outcome: *s.Outcome) c_int {
    var authority = std.mem.zeroes(s.Guard);
    var session = std.mem.zeroes(s.Session);
    const frame = guard.frame(&authority);
    if (!frame) {
        const classified = if (s.session_provider) |provider| provider(&session) != 0 else false;
        if (!classified or session.classification == 0) {
            s.reject(20);
            return if (s.lan_is_host() != 0) native.callOriginal(from, to, args, null, outcome) else 0;
        }
        if (session.classification == 1 or session.classification == 2 or session.classification == 3) return native.callOriginal(from, to, args, null, outcome);
        if (session.classification != 4) {
            s.reject(20);
            return if (s.lan_is_host() != 0) native.callOriginal(from, to, args, null, outcome) else 0;
        }
        if (s.lan_is_host() == 0) {
            s.clonewars_tag_debug[2] +%= 1;
            return 0;
        }
        var control: s.ControlLease = undefined;
        if (s.failed != 0 or s.current != null or session.session == 0 or session.session == std.math.maxInt(u32) or s.adapter == null or s.span_engine_control_get(s.adapter.?, &control) == 0 or control.epoch != session.epoch or control.level != session.level or ((!s.active or s.epoch != control.epoch) and !((s.initial_control_available or session.session > s.last_authorized_session or (session.session == s.last_authorized_session and control.epoch > s.last_authorized_epoch)) and s.epoch == 0 and s.next_id == 0 and s.pending_count == 0))) {
            s.reject(21);
            return native.callOriginal(from, to, args, null, outcome);
        }
        if (!s.active) {
            s.epoch = control.epoch;
            s.active_session = session.session;
            s.last_authorized_session = session.session;
            s.last_authorized_epoch = control.epoch;
            s.host = true;
            s.active = true;
            s.initial_control_available = false;
        }
        authority = std.mem.zeroes(s.Guard);
        authority.kind = 2;
        authority.control = control;
        authority.serial = s.scope_serial;
        authority.pending_generation = s.pending_generation;
        authority.epoch = s.epoch;
        authority.session = session.session;
    }
    if (!guard.valid(&authority)) {
        s.reject(21);
        return if (s.lan_is_host() != 0) native.callOriginal(from, to, args, null, outcome) else 0;
    }
    const actor_update = frame and s.active_event == 0 and s.actor_update != null and s.actor_update.?.actor == from and guard.valid(&s.actor_update.?.guard);
    if (frame and !s.host) {
        const borrowed = s.current.?;
        var i: usize = 0;
        while (guard.valid(&authority) and i < borrowed.tag_count) : (i += 1) {
            if (s.consumed[i] != 0) continue;
            const tag = borrowed.tags[i];
            if (tag.parent != s.active_event or (tag.phase != 0 and s.active_event == 0)) break;
            if (tag.source == p.SYNC_TAG_ACTOR_UPDATE and (!actor_update or tag.clock != s.readClock().clock)) break;
            const expected_from = native.resolveIdentity(tag.from, tag.from_generation, &tag.from_identity, &authority);
            if (!guard.valid(&authority)) return 0;
            if (expected_from == from) {
                const expected_to = native.resolveIdentity(tag.to, tag.to_generation, &tag.to_identity, &authority);
                if (!guard.valid(&authority)) return 0;
                const different = expected_to != 0 and expected_to != to;
                const result = replay(i, false, outcome);
                if (result != 0 and guard.valid(&authority) and different) {
                    if (s.active_event != 0) s.replay_corrected +%= 1 else s.clonewars_tag_debug[9] +%= 1;
                }
                return result;
            }
            break;
        }
        s.clonewars_tag_debug[2] +%= 1;
        return 0;
    }
    s.entities_update();
    if (!guard.valid(&authority)) return native.callOriginal(from, to, args, null, outcome);
    var tag = std.mem.zeroes(p.SyncTag);
    tag.parent = s.active_event;
    tag.phase = @intFromBool(!frame);
    tag.source = if (actor_update) p.SYNC_TAG_ACTOR_UPDATE else p.SYNC_TAG_UNSCOPED;
    tag.from = s.entities_slot(from);
    if (!guard.valid(&authority)) return native.callOriginal(from, to, args, null, outcome);
    tag.to = s.entities_slot(to);
    if (!guard.valid(&authority)) return native.callOriginal(from, to, args, null, outcome);
    tag.from_generation = s.entities_local_generation(from);
    if (!guard.valid(&authority)) return native.callOriginal(from, to, args, null, outcome);
    tag.to_generation = s.entities_local_generation(to);
    if (!guard.valid(&authority)) return native.callOriginal(from, to, args, null, outcome);
    if (!native.captureIdentity(from, tag.from_generation, &tag.from_identity, &authority) or !native.captureIdentity(to, tag.to_generation, &tag.to_identity, &authority)) {
        if (guard.valid(&authority)) {
            s.failed = 4;
            s.reject(21);
        }
        return native.callOriginal(from, to, args, null, outcome);
    }
    tag.arguments = args.*;
    const context = s.readClock();
    tag.clock = context.clock;
    tag.rng_game = context.rng_game;
    tag.rng_engine = context.rng_engine;
    tag.delta = context.delta;
    if (s.clonewars_tag_identity_debug[0] != authority.session or s.clonewars_tag_identity_debug[1] != authority.epoch) {
        @atomicStore(u32, &s.clonewars_tag_identity_debug[0], 0, .seq_cst);
        s.clonewars_tag_identity_debug[1..18].* = .{ authority.epoch, if (frame) s.current.?.sequence else 0, tag.clock, @bitCast(tag.from), tag.from_generation, @bitCast(tag.from_identity.character), tag.from_identity.spawn_tag, tag.from_identity.spawn_source.producer, tag.from_identity.spawn_source.serial, @bitCast(tag.to), tag.to_generation, @bitCast(tag.to_identity.character), tag.to_identity.spawn_tag, tag.to_identity.spawn_source.producer, tag.to_identity.spawn_source.serial, tag.phase, 1 };
        @atomicStore(u32, &s.clonewars_tag_identity_debug[0], authority.session, .seq_cst);
    }
    const count: usize = if (frame) s.current.?.tag_count else s.pending_count;
    if (count == p.SYNC_MAX_TAGS or tag.from < 0 or tag.to < 0 or tag.from == tag.to or tag.from_generation == 0 or tag.to_generation == 0 or s.next_id == std.math.maxInt(u32)) {
        s.failed = 4;
        s.reject(21);
        return native.callOriginal(from, to, args, null, outcome);
    }
    s.next_id += 1;
    tag.id = s.next_id;
    if (frame) {
        s.current.?.tags[s.current.?.tag_count] = tag;
        s.current.?.tag_count += 1;
    } else {
        s.pending[s.pending_count] = tag;
        s.pending_count += 1;
        s.provenance[count] = .{ .epoch = authority.control.epoch, .release = authority.control.release, .session = authority.session, .level = authority.control.level, .generation = s.pending_generation, .committed = 0 };
    }
    const parent = s.active_event;
    s.active_event = tag.id;
    const result = native.callOriginal(from, to, args, &authority, outcome);
    if (!guard.valid(&authority)) return result;
    s.active_event = parent;
    if (result != 1) {
        if (s.next_id == tag.id) {
            s.next_id -= 1;
            if (frame) s.current.?.tag_count -= 1 else s.pending_count -= 1;
        } else s.failed = 7;
        return result;
    }
    if (!frame) s.provenance[count].committed = 1;
    if (!s.progress()) return result;
    s.clonewars_tag_debug[0] +%= 1;
    s.clonewars_tag_debug[6] = s.next_id;
    s.clonewars_tag_debug[4] = @intCast(s.pending_count);
    return result;
}
pub export fn tag_transfer_hook(from: usize, to: usize, a: i32, b: i32, c: i32, d: i32, e: i32, f: i32) c_int {
    var outcome: s.Outcome = undefined;
    outcome.machine.capture();
    outcome.seen = false;
    defer outcome.machine.restore();
    return apply(from, to, &.{ a, b, c, d, e, f }, &outcome);
}
