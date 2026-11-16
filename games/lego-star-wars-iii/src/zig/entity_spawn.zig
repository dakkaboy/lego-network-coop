const std = @import("std");
const s = @import("entity_state.zig");
const p = s.p;
const read = s.read;
const Machine = @import("machine_environment.zig").Environment;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn native_roster_source_resolve(usize, *const [12]u32, *s.Roster) c_int;
extern fn native_hub_source_resolve(usize, usize, *const [12]u32, *s.Hub, *u32) c_int;
fn create(site: u32, source: p.SyncSpawnSource) usize {
    const original: *const fn () callconv(.c) usize = @ptrFromInt(s.original_create);
    const actor = original();
    s.currentPool();
    const raw = s.rawSlot(actor);
    if (raw >= 0) {
        const entry = &s.local[@intCast(raw)];
        entry.* = std.mem.zeroes(s.Local);
        entry.key.generation = s.generation();
        entry.key.spawn_tag = site;
        entry.key.spawn_source = source;
        s.clonewars_entity_debug[0] +%= 1;
    }
    return actor;
}
pub export fn entity_create_hook() usize {
    const caller = @returnAddress();
    var source = std.mem.zeroes(p.SyncSpawnSource);
    if (caller == 0x9c5ce6) {
        if (s.roster_scope) |scope| if (scope.qualified != 0) {
            const actor = create(@truncate(caller - 0x400000), source);
            scope.allocations +%= 1;
            if (scope.allocations == 1) {
                scope.created = actor;
                const raw = s.rawSlot(actor);
                scope.generation = if (raw >= 0) s.local[@intCast(raw)].key.generation else 0;
            }
            return actor;
        };
        if (s.spawn_context.source.producer != 0) return create(s.spawn_context.site, s.spawn_context.source);
    }
    if (caller == 0x9c5ef6) {
        const party = read(u32, 0xfb4968);
        if (party < 8) source = .{ .producer = 1, .serial = party };
    }
    return create(if (caller >= 0x400000 and caller < 0x1100000) @truncate(caller - 0x400000) else 0, source);
}
pub export fn entity_create_placement(descriptor: u32, instance: u32) usize {
    return create(0x5c63b1, .{ .producer = descriptor +% 1, .serial = instance });
}
const Constructor = *const fn (u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32) callconv(.c) usize;
const Call = struct { scope: s.RosterScope, arguments: [12]u32, incoming: Machine, outgoing: Machine, linked: bool };
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Call = @ptrFromInt(context);
    if (call.linked and s.roster_scope == &call.scope) s.roster_scope = call.scope.previous;
    call.linked = false;
    if (call.scope.kind != 0) s.clonewars_hub_source_debug[4] +%= 1 else s.clonewars_roster_source_debug[4] +%= 1;
}
fn revalidate(scope: *const s.RosterScope) bool {
    return if (scope.kind != 0) s.native_hub_source_revalidate(&scope.hub) != 0 else s.native_roster_source_revalidate(&scope.source, 0) != 0;
}
fn invoke(context: usize) callconv(.c) usize {
    const call: *Call = @ptrFromInt(context);
    const scope = &call.scope;
    scope.previous = s.roster_scope;
    s.roster_scope = scope;
    call.linked = true;
    const constructor: Constructor = @ptrFromInt(0x9de240);
    const a = &call.arguments;
    call.incoming.restore();
    const actor = constructor(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]);
    call.outgoing.capture();
    s.roster_scope = scope.previous;
    call.linked = false;
    if (scope.qualified != 0) {
        const debug = if (scope.kind != 0) s.clonewars_hub_source_debug[0..] else s.clonewars_roster_source_debug[0..];
        debug[1] +%= 1;
        const raw = s.rawSlot(actor);
        if (actor != 0 and actor == scope.created and scope.allocations == 1 and raw >= 0 and s.local[@intCast(raw)].key.generation == scope.generation and revalidate(scope)) {
            s.entities_update();
            const slot: usize = @intCast(raw);
            if (s.local[slot].key.generation == scope.generation and s.entities_allocation_live(actor, scope.generation) != 0 and read(i16, actor + 0xdc0) == @as(i32, @bitCast(a[0])) and revalidate(scope)) {
                if (scope.kind != 0) {
                    s.local[slot].key.spawn_tag = 0x5c5ce6;
                    s.local[slot].key.spawn_source = .{ .producer = scope.hub.owner_id, .serial = scope.hub.serial };
                    s.clonewars_hub_source_debug[2] +%= 1;
                } else {
                    const ordinal = scope.source.ordinal;
                    const pending = &s.pending[ordinal];
                    if (!pending.active) {
                        pending.* = .{ .source = scope.source, .actor = actor, .generation = scope.generation, .active = true };
                        s.clonewars_roster_source_debug[6] = ordinal;
                        s.clonewars_roster_source_debug[7] = scope.generation;
                    } else debug[5] +%= 1;
                }
            } else debug[5] +%= 1;
        } else debug[5] +%= 1;
    }
    return actor;
}
fn construct(saved: [*]const u32, hub: bool) usize {
    var incoming: Machine = undefined;
    incoming.capture();
    var call = std.mem.zeroes(Call);
    call.incoming = incoming;
    call.arguments = saved[10..22].*;
    if (hub) {
        call.scope.kind = 1;
        var reason: u32 = 0;
        call.scope.qualified = native_hub_source_resolve(saved[1], saved[2], &call.arguments, &call.scope.hub, &reason);
        s.clonewars_hub_source_debug[0] +%= 1;
        s.clonewars_hub_source_debug[6..16].* = .{ reason, call.scope.hub.owner_id, @bitCast(call.scope.hub.level), call.scope.hub.ordinal, call.scope.hub.manager_id, call.scope.hub.manager_generation, saved[1], if (s.valid(saved[2], 0x18)) read(u32, saved[2] + 8) else 0, saved[2], call.arguments[0] };
        if (call.scope.qualified == 0) s.clonewars_hub_source_debug[3] +%= 1;
    } else {
        call.scope.qualified = native_roster_source_resolve(saved[1], &call.arguments, &call.scope.source);
        s.clonewars_roster_source_debug[0] +%= 1;
        if (call.scope.qualified == 0) s.clonewars_roster_source_debug[3] +%= 1;
    }
    const actor = constructor_lexical_seh(@intFromPtr(&call), invoke, abort);
    call.outgoing.restore();
    return actor;
}
pub export fn entity_roster_constructor(saved: [*]const u32) usize {
    return construct(saved, false);
}
pub export fn entity_hub_constructor(saved: [*]const u32) usize {
    return construct(saved, true);
}
