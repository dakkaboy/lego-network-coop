const std = @import("std");
const p = @import("protocol.zig");
const types = @import("spellit_types.zig");
const state = @import("spellit_hop_state.zig");
const Scope = state.Scope;
const obs = @import("observation.zig");
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const physics = @import("physics_validation.zig");
const Machine = @import("machine_environment.zig").Environment;
pub export var clonewars_spellit_body_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_body_correction: [8]u32 = @splat(0);
const Cache = struct { next: ?*Cache, gizmo: usize, source: types.Source, bindings: []types.Body };
threadlocal var first: ?*Cache = null;
threadlocal var cache_release: u32 = 0;
threadlocal var cache_epoch: u32 = 0;
const Input = struct { binding: types.Body, local: types.State, canonical: types.State };
extern fn native_spellit_body_matches(*const types.Source, *const types.Body) c_int;
extern fn native_spellit_body_resolve(*const types.Source, usize, *types.Body) c_int;
extern fn native_spellit_body_read(*const types.Source, *const types.Body, *types.State) c_int;
extern fn native_spellit_body_apply(*const types.Source, *const types.Body, *const types.State, types.Live, usize) c_int;
extern fn native_spellit_source_revalidate(*const types.Source) c_int;
extern fn physics_world_input(*p.SyncPhysicsChoice, *const @import("cohort_types.zig").Token) c_int;
fn free(address: usize) void {
    if (address != 0) _ = obs.HeapFree(obs.GetProcessHeap(), 0, address);
}
pub fn cleanup(s: *Scope) void {
    free(s.inputs_allocation);
    free(s.bindings_allocation);
    s.inputs_allocation = 0;
    s.bindings_allocation = 0;
}
fn clear() void {
    while (first) |cache| {
        const next = cache.next;
        if (cache.bindings.len != 0) free(@intFromPtr(cache.bindings.ptr));
        free(@intFromPtr(cache));
        first = next;
    }
}
fn same(s: *const Scope, source: *const types.Source, bindings: []const types.Body) bool {
    if (!equal(&s.source, source) or bindings.len != s.source.piece_count) return false;
    var piece = s.source.piece_head;
    var previous: usize = 0;
    for (bindings) |*body| {
        if (!state.live(s) or piece != body.piece or !win.accessible(piece, 0x104, false)) return false;
        const prior = win.load(usize, piece);
        const next = win.load(usize, piece + 4);
        if (prior != previous or native_spellit_body_matches(&s.source, body) == 0) return false;
        previous = piece;
        piece = next;
    }
    return piece == 0 and previous == s.source.piece_tail;
}
fn fail(s: *const Scope) bool {
    if (state.live(s)) {
        clonewars_spellit_body_debug[3] +%= 1;
        state.reject(s, 20, p.SYNC_PHYSICS_SPELLIT_BODY_BASIS);
    }
    return false;
}
fn guard(address: usize) callconv(.c) c_int {
    return @intFromBool(state.live(@ptrFromInt(address)));
}
pub fn apply(s: *Scope) bool {
    if (!state.live(s)) return false;
    if (cache_release != s.token.release or cache_epoch != s.token.epoch) {
        clear();
        cache_release = s.token.release;
        cache_epoch = s.token.epoch;
    }
    defer cleanup(s);
    var cache = first;
    while (cache) |node| {
        if (node.gizmo == s.gizmo) break;
        cache = node.next;
    }
    if (cache == null or !same(s, &cache.?.source, cache.?.bindings)) {
        if (s.source.piece_count > 65536) return fail(s);
        const count = s.source.piece_count;
        var bindings: []types.Body = &.{};
        if (count != 0) {
            s.bindings_allocation = obs.HeapAlloc(obs.GetProcessHeap(), 0, count * @sizeOf(types.Body));
            if (s.bindings_allocation == 0) return fail(s);
            bindings = @as([*]types.Body, @ptrFromInt(s.bindings_allocation))[0..count];
        }
        var piece = s.source.piece_head;
        for (bindings) |*body| {
            if (!state.live(s) or !win.accessible(piece, 0x104, false)) return fail(s);
            body.* = std.mem.zeroes(types.Body);
            if (native_spellit_body_resolve(&s.source, piece, body) < 0) return fail(s);
            if (!state.live(s)) return false;
            piece = win.load(usize, piece + 4);
        }
        if (!same(s, &s.source, bindings)) return fail(s);
        if (cache == null) {
            const address = obs.HeapAlloc(obs.GetProcessHeap(), 0, @sizeOf(Cache));
            if (address == 0) return fail(s);
            const node: *Cache = @ptrFromInt(address);
            node.* = .{ .next = first, .gizmo = s.gizmo, .source = s.source, .bindings = bindings };
            first = node;
            cache = node;
        } else {
            if (cache.?.bindings.len != 0) free(@intFromPtr(cache.?.bindings.ptr));
            cache.?.source = s.source;
            cache.?.bindings = bindings;
        }
        s.bindings_allocation = 0;
    }
    var count: usize = 0;
    for (cache.?.bindings) |binding| if (binding.dynamics != 0) {
        count += 1;
    };
    if (count > p.SYNC_MAX_PHYSICS_CHOICES / 2) return fail(s);
    var inputs: []Input = &.{};
    if (count != 0) {
        s.inputs_allocation = obs.HeapAlloc(obs.GetProcessHeap(), 0, count * @sizeOf(Input));
        if (s.inputs_allocation == 0) return fail(s);
        inputs = @as([*]Input, @ptrFromInt(s.inputs_allocation))[0..count];
    }
    // Copy bindings before callbacks can invalidate the cohort and clear its cache.
    var index: usize = 0;
    for (cache.?.bindings) |binding| {
        if (binding.dynamics == 0) continue;
        inputs[index].binding = binding;
        index += 1;
    }
    for (inputs) |*input| {
        if (!state.live(s) or native_spellit_body_read(&s.source, &input.binding, &input.local) == 0) return fail(s);
        input.canonical = input.local;
        for (0..2) |part| {
            var choice = std.mem.zeroes(p.SyncPhysicsChoice);
            choice.kind = if (part == 0) p.SYNC_PHYSICS_SPELLIT_BODY_BASIS else p.SYNC_PHYSICS_SPELLIT_BODY_MOTION;
            choice.site = 0x840660;
            const values = &choice.payload.spellit_body;
            values.clock = s.clock;
            values.key = input.binding.key;
            values.body_class = input.binding.body_class;
            values.piece_ordinal = input.binding.piece_ordinal;
            @memcpy(std.mem.asBytes(&values.values), std.mem.asBytes(&input.local)[part * 48 ..][0..48]);
            if (part != 0) {
                // Velocity fourth lanes are native scratch, including 0xffffffff.
                values.values[7] = 0;
                values.values[11] = 0;
            }
            if (!physics.valid(&choice)) return fail(s);
            var expected = choice;
            if (!state.live(s) or physics_world_input(&choice, &s.token) != 1 or !state.live(s)) return fail(s);
            expected.payload.spellit_body.values = values.values;
            if (!equal(&choice, &expected) or !physics.valid(&choice)) return fail(s);
            if (part == 0) {
                input.canonical.basis = values.values;
            } else {
                input.canonical.position = values.values[0..4].*;
                input.canonical.linear[0..3].* = values.values[4..7].*;
                input.canonical.angular[0..3].* = values.values[8..11].*;
            }
        }
    }
    if (!state.live(s) or native_spellit_source_revalidate(&s.source) == 0) return fail(s);
    for (inputs) |*input| {
        var current: types.State = undefined;
        if (!state.live(s) or native_spellit_body_read(&s.source, &input.binding, &current) == 0 or !equal(&current, &input.local)) return fail(s);
    }
    for (inputs) |*input| {
        if (!state.live(s)) return false;
        const corrected = !equal(&input.local, &input.canonical);
        var helper: Machine = undefined;
        helper.capture();
        s.machine.restore();
        const applied = native_spellit_body_apply(&s.source, &input.binding, &input.canonical, guard, @intFromPtr(s));
        helper.restore();
        if (applied == 0) return fail(s);
        if (!state.live(s)) return false;
        clonewars_spellit_body_debug[0] +%= 1;
        if (!corrected) {
            clonewars_spellit_body_debug[1] +%= 1;
            continue;
        }
        clonewars_spellit_body_debug[2] +%= 1;
        if (clonewars_spellit_body_correction[0] == 0) clonewars_spellit_body_correction = .{ s.token.epoch, s.token.sequence, s.clock, input.binding.piece_ordinal, input.binding.body_class, input.binding.key[0], input.binding.key[1], s.source.key.gizmo_ordinal };
    }
    return state.live(s);
}
