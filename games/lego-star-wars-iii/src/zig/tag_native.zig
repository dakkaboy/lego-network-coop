const std = @import("std");
const s = @import("tag_state.zig");
const guard = @import("tag_guard.zig");
const equal = @import("validation.zig").equal;
extern fn tag_lexical_seh(usize, *const fn (usize) callconv(.c) c_int, *const fn (usize, c_int) callconv(.c) void) c_int;
pub export fn tags_observe_controller_handoffs(version: ?s.AssignmentVersion, remap: ?s.AssignmentRemap) void {
    s.assignment_version = version;
    s.assignment_remap = remap;
    s.assignment_thread = s.win.GetCurrentThreadId();
    s.assignment_registration +%= 1;
}
fn resolveOwner(actor: usize, generation: u32, controller: usize, owner: *usize, owner_generation: *u32) c_int {
    if (s.win.GetCurrentThreadId() != s.assignment_thread) return 0;
    var current = s.controller;
    while (current) |scope| : (current = scope.previous) {
        if (!scope.valid or scope.serial != s.scope_serial or scope.registration != s.assignment_registration or !guard.valid(&scope.authority)) continue;
        const index: usize = if (scope.actors[0] == actor and scope.generations[0] == generation) 0 else if (scope.actors[1] == actor and scope.generations[1] == generation) 1 else continue;
        if (scope.controllers[index] != controller or s.entities_allocation_live(scope.actors[0], scope.generations[0]) == 0 or s.entities_allocation_live(scope.actors[1], scope.generations[1]) == 0) continue;
        if (!guard.valid(&scope.authority)) continue;
        const now0 = s.win.load(usize, scope.actors[0] + 0x6cc);
        const now1 = s.win.load(usize, scope.actors[1] + 0x6cc);
        const swapped = now0 == scope.controllers[1] and now1 == scope.controllers[0];
        const unchanged = now0 == scope.controllers[0] and now1 == scope.controllers[1];
        if (!guard.valid(&scope.authority) or (!swapped and !unchanged)) continue;
        const resolved = if (swapped) 1 - index else index;
        owner.* = scope.actors[resolved];
        owner_generation.* = scope.generations[resolved];
        return 1;
    }
    return 0;
}
pub export fn tags_resolve_controller_owner(actor: usize, generation: u32, controller: usize, owner: ?*usize, owner_generation: ?*u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (owner == null or owner_generation == null) return 0;
    return resolveOwner(actor, generation, controller, owner.?, owner_generation.?);
}
const Call = struct { scope: s.ControllerScope, authority: s.Guard, from: usize, to: usize, args: [6]i32, linked: bool, keyed: bool, incoming: s.Machine, outgoing: s.Machine, outcome: ?*s.Outcome };
fn observing(call: *const Call) bool {
    return call.keyed and guard.valid(&call.authority) and s.assignment_version != null and s.assignment_remap != null and s.win.GetCurrentThreadId() == s.assignment_thread;
}
fn invoke(context: usize) callconv(.c) c_int {
    const call: *Call = @ptrFromInt(context);
    if (observing(call)) {
        if (s.controller) |scope| if (guard.valid(&scope.authority)) {
            s.assignment_remap.?(s.assignment_version.?());
        };
        call.scope.registration = s.assignment_registration;
        call.scope.assignment_version = s.assignment_version.?();
    }
    const scope = &call.scope;
    scope.previous = s.controller;
    scope.serial = s.scope_serial;
    scope.authority = call.authority;
    scope.actors = .{ call.from, call.to };
    s.controller = scope;
    call.linked = true;
    prepare: {
        if (!observing(call)) break :prepare;
        scope.generations[0] = s.entities_local_generation(call.from);
        if (!guard.valid(&call.authority)) break :prepare;
        scope.generations[1] = s.entities_local_generation(call.to);
        if (!guard.valid(&call.authority)) break :prepare;
        if (call.from != call.to and s.entities_allocation_live(call.from, scope.generations[0]) != 0 and s.entities_allocation_live(call.to, scope.generations[1]) != 0) {
            if (!guard.valid(&call.authority)) break :prepare;
            scope.controllers[0] = s.win.load(usize, call.from + 0x6cc);
            scope.controllers[1] = s.win.load(usize, call.to + 0x6cc);
            scope.valid = scope.controllers[0] != scope.controllers[1] and s.win.accessible(scope.controllers[0], 4, false) and s.win.accessible(scope.controllers[1], 4, false);
        }
    }
    call.incoming.restore();
    const a = &call.args;
    const result = s.original(call.from, call.to, a[0], a[1], a[2], a[3], a[4], a[5]);
    call.outgoing.capture();
    if (call.outcome) |outcome| {
        outcome.machine = call.outgoing;
        outcome.seen = true;
    }
    if (scope.valid and guard.valid(&call.authority) and scope.serial == s.scope_serial and scope.registration == s.assignment_registration) s.assignment_remap.?(scope.assignment_version);
    return result;
}
fn leave(context: usize, completed: c_int) callconv(.c) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Call = @ptrFromInt(context);
    if (call.linked) {
        if (s.controller == &call.scope) s.controller = call.scope.previous else s.reject(23);
    }
    if (completed == 0 and call.keyed) {
        var matched = call.authority.serial == s.scope_serial and call.authority.epoch == s.epoch;
        if (call.authority.kind == 1) matched = matched and s.cohort_bound and call.authority.binding == s.binding_serial and equal(&call.authority.frame, &s.cohort) and s.coherent_frame_release() == call.authority.frame.release else matched = matched and s.adapter != null and s.span_engine_control_valid(s.adapter.?, &call.authority.control) != 0;
        if (matched) {
            s.failed = 8;
            s.scope_was_cancelled = true;
            s.reject(22);
        }
    }
}
pub fn callOriginal(from: usize, to: usize, args: *const [6]i32, authority: ?*const s.Guard, outcome: ?*s.Outcome) c_int {
    var incoming: s.Machine = undefined;
    incoming.capture();
    var call = std.mem.zeroes(Call);
    call.incoming = incoming;
    call.outcome = outcome;
    if (outcome) |value| if (!value.seen) {
        call.incoming = value.machine;
    };
    call.from = from;
    call.to = to;
    call.args = args.*;
    if (authority) |value| call.authority = value.*;
    call.keyed = authority != null and authority.?.kind != 0;
    const result = tag_lexical_seh(@intFromPtr(&call), invoke, leave);
    call.outgoing.restore();
    return result;
}
pub fn captureIdentity(actor: usize, generation: u32, identity: *s.p.SyncTagIdentity, authority: *const s.Guard) bool {
    if (!guard.valid(authority) or generation == 0 or s.entities_allocation_live(actor, generation) == 0 or !guard.valid(authority)) return false;
    var reference = std.mem.zeroes(s.p.SyncActor);
    s.entities_describe(&reference, actor);
    if (!guard.valid(authority) or reference.generation != generation or s.entities_allocation_live(actor, generation) == 0 or !guard.valid(authority)) return false;
    reference.character = s.win.load(i16, actor + 0xdc0);
    if (reference.character < 0 or reference.character >= 4096) return false;
    identity.* = .{ .character = reference.character, .spawn_tag = reference.spawn_tag, .spawn_source = reference.spawn_source };
    return guard.valid(authority);
}
pub fn resolveIdentity(slot: i32, generation: u32, identity: *const s.p.SyncTagIdentity, authority: *const s.Guard) usize {
    if (!guard.valid(authority)) return 0;
    const reference = @import("tag_reference.zig").reference(slot, generation, identity) orelse return 0;
    const actor = s.entities_resolve_reference(&reference);
    return if (guard.valid(authority)) actor else 0;
}
