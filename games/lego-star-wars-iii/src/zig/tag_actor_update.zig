const std = @import("std");
const s = @import("tag_state.zig");
const guard = @import("tag_guard.zig");
const native = @import("tag_native.zig");
const events = @import("tag_events.zig");
extern fn tag_lexical_seh(usize, *const fn (usize) callconv(.c) c_int, *const fn (usize, c_int) callconv(.c) void) c_int;
fn invoke(context: usize) callconv(.c) c_int {
    const scope: *s.ActorUpdate = @ptrFromInt(context);
    s.actor_update = scope;
    const outcome = &scope.outcome;
    outcome.machine.restore();
    scope.update(scope.actor);
    outcome.machine.capture();
    if (!s.host and guard.valid(&scope.guard) and s.failed == 0) {
        const frame = s.current.?;
        var i: usize = 0;
        while (i < frame.tag_count) : (i += 1) {
            if (s.consumed[i] != 0) continue;
            const tag = &frame.tags[i];
            if (tag.source != s.p.SYNC_TAG_ACTOR_UPDATE or tag.clock != s.readClock().clock) break;
            const from = native.resolveIdentity(tag.from, tag.from_generation, &tag.from_identity, &scope.guard);
            if (!guard.valid(&scope.guard) or from != scope.actor or events.replay(i, false, outcome) == 0 or !guard.valid(&scope.guard)) break;
        }
    }
    return 0;
}
fn leave(context: usize, _: c_int) callconv(.c) void {
    const scope: *s.ActorUpdate = @ptrFromInt(context);
    s.actor_update = scope.previous;
}
pub export fn tags_actor_update(actor: usize, update: *const fn (usize) callconv(.c) void) void {
    var scope: s.ActorUpdate = undefined;
    scope.outcome.machine.capture();
    scope.outcome.seen = false;
    scope.previous = s.actor_update;
    scope.actor = actor;
    scope.update = update;
    if (s.active_event != 0 or !guard.frame(&scope.guard) or s.coherent_frame_valid(&scope.guard.frame, 4) == 0) {
        scope.outcome.machine.restore();
        update(actor);
        return;
    }
    _ = tag_lexical_seh(@intFromPtr(&scope), invoke, leave);
    scope.outcome.machine.restore();
}
