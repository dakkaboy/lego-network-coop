const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
extern fn entities_allocation_live(usize, u32) c_int;
fn managerMatches(manager: usize) bool {
    const world = read(usize, 0xfb4a20);
    const provider = read(usize, 0xe90220);
    const registry = read(usize, 0xe90184);
    if (!s.valid(world, 0x404) or !s.valid(provider, 0x3c) or !s.valid(registry, 0x2c)) return false;
    const index = read(i32, provider + 0x38);
    const count = read(i32, registry + 0x28);
    const handle = read(usize, world + 0x400);
    if (index < 0 or index >= count or count > 4096 or !s.valid(handle, 4)) return false;
    const table = read(usize, handle);
    return s.valid(table, @as(usize, @intCast(index + 1)) * 4) and read(usize, table + @as(usize, @intCast(index)) * 4) == manager;
}
fn reject(op: *const s.Lease, actor: usize) void {
    if (!s.live(op)) return;
    s.journal.failed = 15;
    s.clonewars_spellit_query_debug[3] +%= 1;
    s.failed(op, actor, null, 15);
}
pub export fn cadence_spellit_prepare(actor: usize, manager: usize, frame: usize, limit: *f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return;
    input: {
        if (!s.valid(actor, 0x1440) or !s.valid(manager, 4) or !s.valid(frame, 12) or !s.valid(@intFromPtr(limit), 4) or read(usize, frame + 8) != actor or !managerMatches(manager)) break :input;
        const model = read(usize, actor + 8);
        if (model != 0 and !s.valid(model, 0x42)) break :input;
        var query = std.mem.zeroes(p.SyncSpellItQueryState);
        query.clock = read(u32, 0xfb4b6c);
        query.heading = if (model != 0) read(u16, model + 0x40) else 0;
        query.limit = limit.*;
        query.manager_class = s.imageClass(read(usize, manager), true) orelse break :input;
        query.caller_site = s.imageClass(read(usize, frame + 4), true) orelse break :input;
        query.position = read([3]f32, actor + 0x24);
        const local = query;
        s.entities_update();
        if (!s.live(&op)) return;
        const generation = s.entities_observed_generation(actor);
        if (generation == 0 or entities_allocation_live(actor, generation) == 0) break :input;
        _ = gate.apply(actor, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(&query), &s.clonewars_spellit_query_debug);
        if (!s.live(&op) or !s.active or s.journal.failed != 0) return;
        var index: usize = 0;
        while (index < s.spellit_scope_count and s.spellit_scopes[index].native_frame != frame) : (index += 1) {}
        if (index == s.spellit_scope_count) {
            if (index == s.spellit_scopes.len) break :input;
            s.spellit_scope_count += 1;
        }
        s.spellit_scopes[index] = .{ .lease = op, .actor = actor, .manager = manager, .native_frame = frame, .generation = generation, .node_visit = 0, .input = query };
        if (s.journal.host == 0) {
            limit.* = query.limit;
            if (!equal(&local, &query)) {
                s.clonewars_spellit_query_debug[2] +%= 1;
                if (s.clonewars_spellit_query_correction[0] == 0) {
                    var slot: u32 = std.math.maxInt(u32);
                    var remote: u32 = 0;
                    _ = s.entities_observed_identity(actor, &slot, &remote);
                    if (!s.live(&op)) return;
                    var values: [20]u32 = @splat(0);
                    values[0..7].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, remote, query.clock, local.heading, query.heading };
                    values[7..10].* = @bitCast(local.position);
                    values[10..13].* = @bitCast(query.position);
                    values[13..17].* = .{ s.bits(local.limit), s.bits(query.limit), query.manager_class, query.caller_site };
                    s.clonewars_spellit_query_correction = values;
                }
            }
        }
        return;
    }
    reject(&op, actor);
}
pub fn scopeFor(frame: usize) ?*s.SpellItScope {
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return null;
    for (s.spellit_scopes[0..s.spellit_scope_count]) |*scope| {
        if (scope.native_frame != frame) continue;
        if (scope.lease.serial == op.serial and equal(&scope.lease.cohort, &op.cohort) and scope.input.clock == read(u32, 0xfb4b6c) and s.valid(frame, 12) and read(usize, frame + 8) == scope.actor and entities_allocation_live(scope.actor, scope.generation) != 0 and s.live(&op)) return scope;
        break;
    }
    reject(&op, 0);
    return null;
}
pub export fn cadence_spellit_operand(frame: usize, kind: u32, local: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const scope = scopeFor(frame) orelse return local;
    return if (kind != 0) s.bits(scope.input.position[1]) else scope.input.heading;
}
pub export fn cadence_spellit_position(frame: usize, position: *[3]f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (scopeFor(frame)) |scope| position.* = scope.input.position;
}
