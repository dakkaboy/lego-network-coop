const std = @import("std");
const p = @import("protocol.zig");
const state = @import("physics_state.zig");
const validation = @import("physics_validation.zig");
const breakup = @import("breakup_source.zig");
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const Lease = @import("cohort_types.zig").Lease;
const Machine = @import("machine_environment.zig").Environment;
const Choice = p.SyncPhysicsChoice;
const NativeSpin = *const fn (usize) callconv(.c) u32;
var originals: [2]NativeSpin = undefined;
const Binding = @import("effect_binding.zig").Binding;
var bindings = std.mem.zeroes([p.SYNC_MAX_ACTORS]Binding);
const NativeUpdate = *const fn (f32) callconv(.c) void;
var original_update: NativeUpdate = undefined;
pub export var clonewars_effect_update_debug: [12]u32 = @splat(0);
pub export var effect_rest_resume: usize = 0x743cb1;
pub export var effect_moving_resume: usize = 0x7445ad;
extern fn physics_effect_rest_thunk() void;
pub export var clonewars_breakup_launch_debug: [4]u32 = @splat(0);
pub export var clonewars_breakup_source_failure: [8]u32 = @splat(0);
pub export var clonewars_breakup_launch_motion_debug: [14]u32 = @splat(0);
pub export var clonewars_breakup_geometry_debug: [8]u32 = @splat(0);
pub export var clonewars_breakup_geometry_local: [19]u32 = @splat(0);
pub export var clonewars_breakup_geometry_host: [19]u32 = @splat(0);
pub export var clonewars_effect_birth_debug: [8]u32 = @splat(0);
pub export var clonewars_effect_lifetime_debug: [10]u32 = @splat(0);
export var breakup_launch_native: usize = 0x966af0;
export var effect_birth_resume: usize = 0x7427df;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn spellit_input_install() c_int;
extern fn module_rng_input_install() c_int;
extern fn vehicle_rng_input_install() c_int;
extern fn physics_breakup_launch_thunk() void;
extern fn physics_effect_birth_thunk() void;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn readable(address: usize, length: usize) bool {
    return win.accessible(address, length, false);
}
fn describeHandle(handle: usize, choice: *Choice) bool {
    return @import("breakup_source.zig").resolve(handle, state.frame.?.epoch, &choice.payload.basic.name_hash);
}
fn describe(effect: usize, kind: u32, site: u32, choice: *Choice) bool {
    if (!readable(effect, 0x168)) return false;
    choice.* = std.mem.zeroes(Choice);
    choice.kind = kind;
    choice.site = site;
    const basic = &choice.payload.basic;
    basic.flags = read(u32, effect + 0x11c);
    if (!describeHandle(effect + 0x160, choice)) return false;
    basic.model = read(u16, effect + 0x156);
    basic.clock = read(u32, 0xfb4b6c);
    basic.recipe = read([6]u32, effect + 0x124);
    basic.rng = read(u32, 0xe5f498);
    return validation.valid(choice);
}
const LaunchSource = struct { site: u32 = 0x905f38, model: u32, name: [2]u32 = @splat(0) };
fn launchSource(descriptor: usize, handle: usize, native_frame: usize) LaunchSource {
    var source: LaunchSource = .{ .model = read(u16, descriptor + 4) };
    const caller = if (readable(native_frame, 16)) read(usize, native_frame + 4) else 0;
    const team_breakup = caller == breakup.team_breakup_site;
    if (caller == breakup.rts_breakup_site) {
        source.site = breakup.rts_breakup_site;
        // This caller supplies a local object pointer. The mesh and launch recipe identify the debris.
        source.model = 0;
        if (read(usize, native_frame + 12) != descriptor) return source;
    }
    if (team_breakup) {
        source.site = breakup.team_breakup_site;
        source.model = breakup.team_breakup_type;
    }
    var mesh: [2]u32 = undefined;
    if (!breakup.resolve(handle, state.frame.?.epoch, &mesh)) return source;
    if (!team_breakup) {
        source.name = mesh;
    } else if (read(usize, native_frame + 12) == descriptor) {
        // This caller stores a native owner pointer in the descriptor's model
        // field. The effect constructor still needs the original pointer.
        source.name = breakup.teamBreakupKey(
            read(usize, 0xfb4a20),
            read(usize, descriptor + 4),
            read(usize, native_frame + 8),
            mesh,
        ) orelse @splat(0);
    }
    return source;
}
fn applyLaunch(descriptor: usize, source: LaunchSource) void {
    var local = std.mem.zeroes(Choice);
    local.kind = p.SYNC_PHYSICS_BREAKUP_LAUNCH;
    local.site = source.site;
    const basic = &local.payload.basic;
    basic.flags = 0x40000000 | @as(u32, if (read(u8, descriptor + 0x2d) != 0) 0x10 else 0);
    basic.model = source.model;
    basic.name_hash = source.name;
    basic.clock = read(u32, 0xfb4b6c);
    basic.recipe = read([6]u32, descriptor + 8);
    basic.rng = read(u32, 0xe637b4);
    if (!validation.valid(&local)) {
        _ = state.fail(1, &local, null);
        clonewars_breakup_launch_debug[3] +%= 1;
        return;
    }
    if (!state.live()) return;
    if (state.host) {
        if (!state.record(local)) {
            _ = state.fail(2, &local, null);
            clonewars_breakup_launch_debug[3] +%= 1;
            return;
        }
        clonewars_breakup_launch_debug[0] +%= 1;
        return;
    }
    const entry = state.expectedEntry();
    if (entry == null or !@import("physics_replay.zig").launch(@ptrFromInt(descriptor), &local, entry.?)) {
        _ = state.fail(3, &local, entry);
        clonewars_breakup_launch_debug[3] +%= 1;
        return;
    }
    const canonical = &entry.?.payload.basic;
    if (!std.mem.eql(u32, basic.recipe[2..6], canonical.recipe[2..6])) {
        if (clonewars_breakup_launch_motion_debug[13] == 0) {
            const values = [_]u32{ state.frame.?.epoch, state.frame.?.sequence, basic.clock, basic.model, basic.name_hash[0], basic.recipe[2], basic.recipe[3], basic.recipe[4], basic.recipe[5], canonical.recipe[2], canonical.recipe[3], canonical.recipe[4], canonical.recipe[5] };
            @memcpy(clonewars_breakup_launch_motion_debug[0..13], &values);
        }
        clonewars_breakup_launch_motion_debug[13] +%= 1;
    }
    if (basic.rng != canonical.rng) {
        clonewars_breakup_launch_debug[2] +%= 1;
        if (state.clonewars_breakup_launch_correction[0] == 0) state.clonewars_breakup_launch_correction = .{ state.frame.?.epoch, state.frame.?.sequence, basic.clock, basic.model, basic.name_hash[0], basic.rng, canonical.rng, local.site };
    }
    // The original constructor must retain its advances of the shared game stream.
    win.store(u32, 0xe637b4, canonical.rng);
    state.consume(1);
    clonewars_breakup_launch_debug[1] +%= 1;
}
fn geometryFailure(reason: u32, local: *const Choice, expected: ?*const Choice) void {
    clonewars_breakup_geometry_debug[3] +%= 1;
    _ = state.fail(reason, local, expected);
}
fn applyGeometry(descriptor: usize, source: LaunchSource, matrix: usize, scale: usize) void {
    var basis = std.mem.zeroes(Choice);
    var size = std.mem.zeroes(Choice);
    basis.kind = p.SYNC_PHYSICS_BREAKUP_BASIS;
    size.kind = p.SYNC_PHYSICS_BREAKUP_SCALE;
    basis.site = source.site;
    size.site = basis.site;
    const b = &basis.payload.breakup_basis;
    const s = &size.payload.basic;
    b.clock = read(u32, 0xfb4b6c);
    s.clock = b.clock;
    b.model = source.model;
    s.model = b.model;
    s.flags = 0x40000000 | @as(u32, if (read(u8, descriptor + 0x2d) != 0) 0x10 else 0);
    if (!readable(matrix, 64) or !readable(scale, 12)) {
        geometryFailure(1, &basis, null);
        return;
    }
    b.name_hash = source.name;
    s.name_hash = b.name_hash;
    b.matrix = read([16]f32, matrix);
    s.recipe[0..3].* = read([3]u32, scale);
    if (!validation.valid(&basis) or !validation.valid(&size)) {
        geometryFailure(1, &basis, null);
        return;
    }
    if (!state.live()) return;
    if (state.host) {
        if (state.frame.?.physics_choice_count > p.SYNC_MAX_PHYSICS_CHOICES - 2) {
            geometryFailure(2, &basis, null);
            return;
        }
        _ = state.record(basis);
        _ = state.record(size);
        clonewars_breakup_geometry_debug[0] +%= 1;
        return;
    }
    const expected = if (state.cursor + 1 < state.frame.?.physics_choice_count) state.expectedEntry() else null;
    if (expected == null) {
        geometryFailure(3, &basis, null);
        return;
    }
    const first = expected.?;
    const second = &state.frame.?.physics_choices[state.cursor + 1];
    if (!validation.sameSource(&basis, first) or !validation.sameSource(&size, second)) {
        geometryFailure(3, &basis, first);
        return;
    }
    const eb = &first.payload.breakup_basis;
    const es = &second.payload.basic;
    if (!equal(&b.matrix, &eb.matrix) or !equal(s.recipe[0..3], es.recipe[0..3])) {
        if (clonewars_breakup_geometry_debug[2] == 0) {
            clonewars_breakup_geometry_local[0..16].* = @bitCast(b.matrix);
            clonewars_breakup_geometry_local[16..19].* = s.recipe[0..3].*;
            clonewars_breakup_geometry_host[0..16].* = @bitCast(eb.matrix);
            clonewars_breakup_geometry_host[16..19].* = es.recipe[0..3].*;
            clonewars_breakup_geometry_debug[4..8].* = .{ b.clock, b.model, b.name_hash[0], state.frame.?.sequence };
        }
        clonewars_breakup_geometry_debug[2] +%= 1;
    }
    if (!state.live()) return;
    if (!@import("physics_replay.zig").geometry(@ptrFromInt(matrix), @ptrFromInt(scale), &basis, &size, first, second)) {
        geometryFailure(3, &basis, first);
        return;
    }
    state.consume(2);
    clonewars_breakup_geometry_debug[1] +%= 1;
}
pub export fn physics_apply_breakup_launch(descriptor: usize, handle: usize, matrix: usize, scale: usize, model: usize, native_frame: usize) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (!state.active or state.failed or !state.live() or !readable(descriptor, 0x30) or read(u8, descriptor + 0x2c) == 0) return;
    _ = breakup.register(handle, model, state.frame.?.epoch);
    const source = launchSource(descriptor, handle, native_frame);
    applyLaunch(descriptor, source);
    if (!state.failed and state.live()) applyGeometry(descriptor, source, matrix, scale);
    if (state.failed and clonewars_breakup_source_failure[0] == 0) {
        clonewars_breakup_source_failure[0..4].* = .{ @truncate(descriptor), @truncate(handle), @truncate(matrix), @truncate(scale) };
        if (readable(handle, 8)) {
            clonewars_breakup_source_failure[4..6].* = read([2]u32, handle);
            const mesh = read(usize, handle + 4);
            if (readable(mesh, 0xb8)) {
                const name = read(usize, mesh + 0xb4);
                clonewars_breakup_source_failure[6] = @truncate(name);
                if (readable(name, 1)) clonewars_breakup_source_failure[7] = read(u8, name);
            }
        }
    }
}
pub export fn physics_effect_birth(node: usize) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const pool = read(usize, 0xfa3d38);
    const count = read(u32, 0xe5f480);
    const offset = node -% pool;
    if (node == 0 or pool == 0 or offset % 0x228 != 0 or offset / 0x228 >= count or offset / 0x228 >= p.SYNC_MAX_ACTORS or !readable(node, 0x228)) return;
    const binding = &bindings[offset / 0x228];
    binding.* = std.mem.zeroes(Binding);
    if (!state.active or !state.live() or state.failed or read(u32, node + 0x11c) & 0x40000000 == 0 or read(u32, node + 0x15c) & 1 == 0) return;
    const receiver = read(usize, node + 0x1f8);
    if (!readable(receiver, 0x1a4)) return;
    const body = read(usize, receiver + 0x1a0);
    const resource = read(usize, node + 0x164);
    if (!readable(body, 0xb0)) {
        _ = state.fail(1, null, null);
        return;
    }
    var choice = std.mem.zeroes(Choice);
    choice.kind = p.SYNC_PHYSICS_EFFECT_BIRTH;
    choice.site = 0x7427d8;
    const b = &choice.payload.basic;
    b.clock = read(u32, 0xfb4b6c);
    b.flags = read(u32, node + 0x11c);
    b.model = read(u16, node + 0x156);
    b.recipe[0..3].* = .{ read(u32, node + 0xf8), read(u32, node + 0x100), read(u32, node + 0x104) };
    if (!describeHandle(node + 0x160, &choice) or !validation.valid(&choice)) {
        _ = state.fail(1, &choice, null);
        return;
    }
    const event = if (state.host) state.frame.?.physics_choice_count else state.cursor;
    if (state.host) {
        if (!state.record(choice)) {
            _ = state.fail(2, &choice, null);
            return;
        }
    } else {
        const expected = state.expectedEntry();
        if (expected == null or !validation.sameSource(&choice, expected.?)) {
            _ = state.fail(3, &choice, expected);
            return;
        }
        if (!state.live() or state.failed) return;
        if (!win.accessible(node, 0x228, true) or read(usize, node + 0x1f8) != receiver or read(usize, node + 0x164) != resource or !readable(receiver, 0x1a4) or read(usize, receiver + 0x1a0) != body) {
            _ = state.fail(1, &choice, expected);
            return;
        }
        const lifetime = expected.?.payload.basic.recipe[0..3];
        if (!std.mem.eql(u32, b.recipe[0..3], lifetime)) {
            if (clonewars_effect_lifetime_debug[0] == 0) {
                clonewars_effect_lifetime_debug[1..4].* = .{ state.frame.?.sequence, b.clock, event + 1 };
                clonewars_effect_lifetime_debug[4..7].* = b.recipe[0..3].*;
                clonewars_effect_lifetime_debug[7..10].* = lifetime[0..3].*;
            }
            clonewars_effect_lifetime_debug[0] +%= 1;
        }
        win.store(u32, node + 0xf8, lifetime[0]);
        win.store(u32, node + 0x100, lifetime[1]);
        win.store(u32, node + 0x104, lifetime[2]);
        state.consume(1);
    }
    binding.* = .{ .node = node, .receiver = receiver, .body = body, .resource = resource, .epoch = state.frame.?.epoch, .sequence = state.frame.?.sequence, .event = event + 1, .release = state.lease.cohort.release };
    clonewars_effect_birth_debug[@intFromBool(!state.host)] +%= 1;
    clonewars_effect_birth_debug[2..6].* = .{ binding.epoch, binding.sequence, binding.event, b.name_hash[0] };
}
pub export fn physics_effect_body_source(body: usize, source: ?*[2]u32) c_int {
    if (source == null or body == 0 or !state.live() or state.failed) return 0;
    const count = read(u32, 0xe5f480);
    const pool = read(usize, 0xfa3d38);
    if (count > p.SYNC_MAX_ACTORS or pool == 0) return 0;
    var revoked: u32 = 0;
    const result = @import("effect_binding.zig").resolve(bindings[0..count], body, state.frame.?.epoch, state.lease.cohort.release, EffectContext{ .pool = pool, .body = body }, effectLive, source.?, &revoked);
    clonewars_effect_birth_debug[6] +%= revoked;
    if (result < 0) {
        clonewars_effect_birth_debug[7] +%= 1;
        _ = state.fail(7, null, null);
        return 0;
    }
    return result;
}
pub export fn physics_effect_body_resolve(sequence: u32, event: u32) usize {
    if (!state.live() or state.failed) return 0;
    const count = read(u32, 0xe5f480);
    const pool = read(usize, 0xfa3d38);
    if (count > p.SYNC_MAX_ACTORS or pool == 0) return 0;
    var body: usize = 0;
    var revoked: u32 = 0;
    const result = @import("effect_binding.zig").bodyForSource(bindings[0..count], .{ sequence, event }, state.frame.?.epoch, state.lease.cohort.release, pool, effectSourceLive, &body, &revoked);
    clonewars_effect_birth_debug[6] +%= revoked;
    if (result < 0) {
        clonewars_effect_birth_debug[7] +%= 1;
        _ = state.fail(7, null, null);
        return 0;
    }
    return if (result == 1) body else 0;
}
pub export fn physics_effect_ordering_source(body: usize, source: *[2]u32) c_int {
    if (body == 0 or !state.live() or state.failed) return 0;
    const count = read(u32, 0xe5f480);
    const pool = read(usize, 0xfa3d38);
    if (count > p.SYNC_MAX_ACTORS or pool == 0) return 0;
    source.* = @import("effect_binding.zig").orderingSource(bindings[0..count], body, state.frame.?.epoch, state.lease.cohort.release, pool, effectSourceLive) orelse return 0;
    return 1;
}
fn effectSourceLive(binding: *const Binding, index: usize, pool: usize) bool {
    return effectLive(binding, index, .{ .pool = pool, .body = binding.body });
}
const EffectContext = struct { pool: usize, body: usize };
fn effectLive(binding: *const Binding, index: usize, context: EffectContext) bool {
    const node = context.pool + index * 0x228;
    return node == binding.node and readable(node, 0x228) and read(u32, node + 0x15c) & 1 != 0 and read(u32, node + 0x11c) & 0x40000000 != 0 and read(usize, node + 0x1f8) == binding.receiver and read(usize, node + 0x164) == binding.resource and readable(binding.receiver, 0x1a4) and read(usize, binding.receiver + 0x1a0) == context.body;
}

fn effectInput(local: *const Choice) ?u32 {
    if (!validation.valid(local)) {
        _ = state.fail(1, local, null);
        return null;
    }
    if (state.host) {
        if (!state.record(local.*)) {
            _ = state.fail(2, local, null);
            return null;
        }
        return local.payload.basic.recipe[0];
    }
    if (local.kind == p.SYNC_PHYSICS_EFFECT_REST) {
        return state.rest(local) orelse { _ = state.fail(3, local, state.expectedEntry()); return null; };
    }
    const expected = state.expectedEntry();
    if (expected == null or !validation.sameSource(local, expected.?)) {
        _ = state.fail(3, local, expected);
        return null;
    }
    const result = expected.?.payload.basic.recipe[0];
    if (!state.live() or state.failed) return null;
    state.consume(1);
    return result;
}

pub fn effectStep(delta: f32) f32 {
    if (!state.live() or state.failed) {
        clonewars_effect_update_debug[1] +%= 1;
        return delta;
    }
    clonewars_effect_update_debug[0] +%= 1;
    var local = std.mem.zeroes(Choice);
    local.kind = p.SYNC_PHYSICS_EFFECT_STEP;
    local.site = 0x743bb0;
    local.payload.basic.clock = read(u32, 0xfb4b6c);
    local.payload.basic.recipe[0] = @bitCast(delta);
    const bits = effectInput(&local) orelse return delta;
    clonewars_effect_update_debug[4] +%= @intFromBool(bits != local.payload.basic.recipe[0]);
    return @bitCast(bits);
}

fn updateHook(delta: f32) callconv(.c) void {
    var machine: Machine = undefined;
    const mxcsr: u32 = 0x1f80;
    machine.save(&mxcsr);
    const canonical = effectStep(delta);
    machine.restore();
    original_update(canonical);
}

pub export fn physics_effect_rest(node: usize, native_mask: u32) u32 {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const mask = native_mask & 0x41;
    if (!state.live() or state.failed) {
        clonewars_effect_update_debug[3] +%= 1;
        return mask;
    }
    const pool = read(usize, 0xfa3d38);
    const count = read(u32, 0xe5f480);
    const offset = node -% pool;
    if (pool == 0 or count > p.SYNC_MAX_ACTORS or offset % 0x228 != 0 or offset / 0x228 >= count) return mask;
    const index = offset / 0x228;
    const binding = &bindings[index];
    // Unjournaled visual effects and effects born before this lease stay native.
    if (binding.epoch != state.frame.?.epoch or binding.release != state.lease.cohort.release or binding.sequence == 0 or binding.event == 0) return mask;
    if (!effectSourceLive(binding, index, pool) or read(u32, node + 0x15c) & 2 != 0) {
        _ = state.fail(1, null, null);
        return mask;
    }
    clonewars_effect_update_debug[2] +%= 1;
    var local = std.mem.zeroes(Choice);
    local.kind = p.SYNC_PHYSICS_EFFECT_REST;
    local.site = 0x743ca8;
    const b = &local.payload.basic;
    b.flags = read(u32, node + 0x11c);
    b.model = read(u16, node + 0x156);
    b.clock = read(u32, 0xfb4b6c);
    b.name_hash = .{ binding.sequence, binding.event };
    b.recipe[0] = mask;
    b.recipe[1] = read(u32, node + 0x198);
    const result = effectInput(&local) orelse return mask;
    if (!state.live() or state.failed or !effectSourceLive(binding, index, pool)) return mask;
    if (result != mask) {
        if (clonewars_effect_update_debug[5] == 0) clonewars_effect_update_debug[6..12].* = .{ state.frame.?.sequence, b.clock, binding.sequence, binding.event, mask, result };
        clonewars_effect_update_debug[5] +%= 1;
    }
    return result;
}

const SpinScope = struct { machine: Machine, effect: usize, kind: u32, site: u32, result: u32, saved_rng: u32, seeded: bool, seeded_lease: Lease };
fn restoreSeed(scope: *SpinScope) void {
    if (scope.seeded and state.live() and scope.seeded_lease.serial == state.lease.serial and equal(&scope.seeded_lease.cohort, &state.lease.cohort)) win.store(u32, 0xe5f498, scope.saved_rng);
    scope.seeded = false;
}
fn invoke(address: usize) callconv(.c) usize {
    const scope: *SpinScope = @ptrFromInt(address);
    const effect = scope.effect;
    // Visual particles share this stream but do not enter the physical source journal.
    if (state.active and readable(effect, 0x168) and read(u32, effect + 0x11c) & 0x40000000 != 0 and read(usize, effect + 0x164) != 0) {
        if (!state.live() or state.failed) return 0;
        var local: Choice = undefined;
        if (!describe(effect, scope.kind, scope.site, &local)) {
            _ = state.fail(1, null, null);
            return 0;
        }
        if (!state.live()) return 0;
        if (state.host) {
            if (!state.record(local)) {
                _ = state.fail(2, &local, null);
                return 0;
            }
        } else {
            const entry = state.expectedEntry();
            if (entry == null or !validation.sameSource(entry.?, &local)) {
                _ = state.fail(3, &local, entry);
                return 0;
            }
            scope.saved_rng = local.payload.basic.rng;
            scope.seeded_lease = state.lease;
            scope.seeded = true;
            win.store(u32, 0xe5f498, entry.?.payload.basic.rng);
            state.consume(1);
            state.clonewars_physics_input_debug[3] +%= @intFromBool(local.payload.basic.rng != entry.?.payload.basic.rng);
        }
    }
    scope.machine.restore();
    scope.result = originals[scope.kind - 1](effect);
    scope.machine.capture();
    restoreSeed(scope);
    return 0;
}
fn abortSpin(address: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    restoreSeed(@ptrFromInt(address));
}
fn spin(effect: usize, kind: u32, site: u32) u32 {
    var scope: SpinScope = undefined;
    scope.machine.capture();
    scope.seeded = false;
    scope.result = 0;
    scope.effect = effect;
    scope.kind = kind;
    scope.site = site;
    _ = constructor_lexical_seh(@intFromPtr(&scope), invoke, abortSpin);
    scope.machine.restore();
    return scope.result;
}
fn axisHook(effect: usize) callconv(.c) u32 {
    return spin(effect, p.SYNC_PHYSICS_AXIS_SPIN, @truncate(@returnAddress()));
}
fn rotationHook(effect: usize) callconv(.c) u32 {
    return spin(effect, p.SYNC_PHYSICS_ROTATION_SPIN, @truncate(@returnAddress()));
}
fn patch(address: usize, length: usize, target: usize, call: bool) bool {
    var old: u32 = 0;
    if (win.VirtualProtect(address, length, 0x40, &old) == 0) return false;
    win.store(u8, address, if (call) 0xe8 else 0xe9);
    win.store(u32, address + 1, @truncate(target -% address -% 5));
    for (5..length) |i| win.store(u8, address + i, 0x90);
    const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), address, length) != 0;
    var ignored: u32 = 0;
    return win.VirtualProtect(address, length, old, &ignored) != 0 and flushed;
}
pub export fn physics_input_install() c_int {
    const birth = [_]u8{ 0x8b, 0x8c, 0x24, 8, 2, 0, 0 };
    const launch = [_]u8{ 0xe8, 0xb8, 0x0b, 6, 0 };
    const addresses = [_]usize{ 0x71ab90, 0x71ac10 };
    const prefixes = [2][6]u8{ .{ 0x56, 0x57, 0x8b, 0x7c, 0x24, 0x0c }, .{ 0x56, 0x68, 0x98, 0xf4, 0xe5, 0 } };
    const update_prefix = [_]u8{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 };
    const rest_prefix = [_]u8{ 0xf6, 0xc4, 0x41, 0x0f, 0x85, 0xfc, 8, 0, 0 };
    if (!readable(0x743bb0, 6) or !equal(&read([6]u8, 0x743bb0), &update_prefix) or !readable(0x743ca8, 9) or !equal(&read([9]u8, 0x743ca8), &rest_prefix)) return 0;
    if (!readable(0x7427d8, birth.len) or !equal(&read([7]u8, 0x7427d8), &birth) or !readable(0x905f33, launch.len) or !equal(&read([5]u8, 0x905f33), &launch)) return 0;
    for (addresses, prefixes) |address, prefix| if (!readable(address, 6) or !equal(&read([6]u8, address), &prefix)) return 0;
    if (spellit_input_install() == 0 or module_rng_input_install() == 0 or vehicle_rng_input_install() == 0) return 0;
    const update_bridge = @import("observation.zig").install(0x743bb0, &update_prefix, @intFromPtr(&updateHook)) orelse return 0;
    original_update = @ptrFromInt(update_bridge);
    if (!patch(0x743ca8, 9, @intFromPtr(&physics_effect_rest_thunk), false)) return 0;
    if (!patch(0x7427d8, 7, @intFromPtr(&physics_effect_birth_thunk), false)) return 0;
    const hooks = [_]NativeSpin{ axisHook, rotationHook };
    for (addresses, prefixes, hooks, 0..) |address, prefix, hook, i| {
        const bridge = win.VirtualAlloc(0, 11, 0x3000, 4);
        if (bridge == 0) return 0;
        win.store([6]u8, bridge, prefix);
        win.store(u8, bridge + 6, 0xe9);
        win.store(u32, bridge + 7, @truncate(address +% 6 -% bridge -% 11));
        var old: u32 = 0;
        if (win.VirtualProtect(bridge, 11, 0x20, &old) == 0) return 0;
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, 11);
        originals[i] = @ptrFromInt(bridge);
        if (!patch(address, 6, @intFromPtr(hook), false)) return 0;
    }
    if (!patch(0x905f33, 5, @intFromPtr(&physics_breakup_launch_thunk), true)) return 0;
    state.clonewars_physics_input_debug[4] = 3;
    return 1;
}
comptime {
    _ = @import("physics_bridges.zig");
    asm (@import("effect_update_bridge.zig").code);
}
