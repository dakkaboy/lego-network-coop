const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const load = s.load;
const store = s.store;
const equal = @import("validation.zig").equal;
const Binding = @import("rigid_types.zig").Binding;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
pub fn physicsBody(actor: usize) usize {
    if (load(u8, 0xe66e7a) == 0) return 0;
    const model = load(usize, actor + 8);
    if (!s.valid(model, 0x3c)) return 0;
    const body = load(usize, model + 0x38);
    return if (s.valid(body, 0xec)) body else 0;
}
pub fn collect(frame: *s.p.SyncFrame) bool {
    const count = load(u32, 0xfb2e3c);
    if (count > s.p.SYNC_MAX_ACTORS) return false;
    api.entities_update();
    const base = load(usize, 0xfb2f60);
    frame.actor_count = 0;
    if (count == 0) return true;
    if (!s.valid(base, count * 0x1440)) return false;
    for (0..count) |slot| {
        const actor = base + slot * 0x1440;
        const flags = load(u32, actor + 0x50);
        if (flags & 3 != 3) continue;
        if (frame.actor_count == s.p.SYNC_MAX_ACTORS) return false;
        const out = &frame.actors[frame.actor_count];
        frame.actor_count += 1;
        api.entities_describe(out, actor);
        out.slot = @intCast(slot);
        out.character = load(i16, actor + 0xdc0);
        out.flags = flags;
        out.position = load([3]f32, actor + 0x24);
        out.previous_position = load([3]f32, actor + 0x30);
        out.render_position = load([3]f32, actor + 0xf28);
        out.previous_render_position = load([3]f32, actor + 0xf40);
        out.velocity = load([3]f32, actor + 0xf10);
        out.motion_origin = load([3]f32, actor + 0xe2c);
        out.heading = load(u16, actor + 0x6c);
        out.render_heading = load(u16, actor + 0xf0c);
        out.health = load(i8, actor + 0xdde);
        out.max_health = load(u8, actor + 0xddd);
        const wallet = load(usize, actor + 0x5b0);
        out.has_wallet = @intFromBool(s.valid(wallet, 8));
        out.wallet = if (out.has_wallet != 0) load(u64, wallet) else 0;
        out.animation = .{ .frames = load([5]f32, actor + 0xee4), .current = load(i16, actor + 0x2e8), .flags = load(u16, actor + 0xef8), .clips = load([5]i16, actor + 0xefa), .reserved = 0 };
        out.body = std.mem.zeroes(s.p.SyncActorBody);
        out.rigid_body = std.mem.zeroes(s.p.SyncRigidBody);
        const body = physicsBody(actor);
        if (body != 0) out.body = .{ .active = 1, .position = load([3]f32, body + 0x70), .velocity = load([4]f32, body + 0xb0), .floor_height = load(f32, body + 0xe8) };
        var physical: Binding = undefined;
        if (api.native_actor_rigid_body(actor, &physical) != 0) {
            out.rigid_body.active = 1;
            out.rigid_body.transform = load([16]f32, physical.body + 0x40);
        }
    }
    return api.entities_collect_dormant_party(frame) != 0 and api.sync_frame_valid(frame, api.sync_frame_size(frame)) != 0;
}
fn live(token: *const s.Token) bool {
    return s.live() and api.coherent_frame_valid(token, 4) != 0;
}
fn restoreBody(actor: usize, state: *const s.p.SyncActorBody, token: *const s.Token, allocation: u32) bool {
    if (state.active == 0) return true;
    const body = physicsBody(actor);
    if (body == 0) return false;
    if (!equal(&load([3]f32, body + 0x70), &state.position)) {
        const destination = [4]f32{ state.position[0], state.position[1], state.position[2], 1 };
        const native: *const fn (usize, [*]const f32) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0xa294c0);
        native(body, &destination);
        if (!live(token) or api.entities_allocation_live(actor, allocation) == 0 or physicsBody(actor) != body) return false;
        s.clonewars_actor_pose_corrections +%= 1;
    }
    if (!equal(&load([4]f32, body + 0xb0), &state.velocity)) {
        const native: *const fn (usize, [*]const f32) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0xa08380);
        native(body, &state.velocity);
    }
    store(f32, body + 0xe8, state.floor_height);
    return true;
}
fn stillAssigned(actor: usize, allocation: u32, value: *const s.p.SyncActor, controller: usize) bool {
    return api.entities_allocation_live(actor, allocation) != 0 and api.entities_actor(value.slot, value.generation) == actor and load(usize, actor + 0x6cc) == controller;
}
pub fn correctImpl(frame: *const s.p.SyncFrame, token: *const s.Token) bool {
    if (!live(token) or api.entities_bind(frame) == 0 or !live(token)) return false;
    const count = frame.actor_count;
    if (count > s.p.SYNC_MAX_ACTORS) return false;
    for (frame.actors[0..count]) |*value| {
        if (!live(token)) return false;
        const actor = api.entities_actor(value.slot, value.generation);
        if (!s.valid(actor, 0x1440)) {
            if (value.player < 0 and value.health == 0 and api.entities_is_retired(value.slot, value.generation) != 0) continue;
            return false;
        }
        if (load(u32, actor + 0x50) & 3 != 3 or load(i16, actor + 0xdc0) != value.character) return false;
    }
    for (0..count) |i| {
        if (!live(token)) return false;
        const value = frame.actors[i];
        const actor = api.entities_actor(value.slot, value.generation);
        if (actor == 0 and value.player < 0 and value.health == 0 and api.entities_is_retired(value.slot, value.generation) != 0) continue;
        const allocation = api.entities_local_generation(actor);
        if (allocation == 0 or api.entities_allocation_live(actor, allocation) == 0) return false;
        const controller = load(usize, actor + 0x6cc);
        store(u16, actor + 0x6c, value.heading);
        store(u16, actor + 0xf0c, value.render_heading);
        if (!restoreBody(actor, &value.body, token, allocation)) return false;
        if (value.rigid_body.active != 0) {
            var physical: Binding = undefined;
            if (api.native_actor_rigid_body(actor, &physical) == 0) return false;
            if (!equal(&load([16]f32, physical.body + 0x40), &value.rigid_body.transform)) {
                api.native_rigid_body_transform(physical.body, &value.rigid_body.transform);
                if (!live(token) or api.entities_allocation_live(actor, allocation) == 0 or api.native_actor_rigid_body_same(actor, &physical) == 0) return false;
            }
        }
        if (!live(token) or !stillAssigned(actor, allocation, &value, controller)) return false;
        store([3]f32, actor + 0x24, value.position);
        store([3]f32, actor + 0xf28, value.render_position);
        store([3]f32, actor + 0x30, value.previous_position);
        store([3]f32, actor + 0xf40, value.previous_render_position);
        store([3]f32, actor + 0xf10, value.velocity);
        if (!equal(&load([3]f32, actor + 0xe2c), &value.motion_origin)) {
            const debug = &s.clonewars_actor_motion_origin_debug;
            if (debug[0] == 0) {
                debug[1..4].* = .{ load(u32, 0xfb4b6c), value.slot, value.generation };
                debug[4..7].* = @bitCast(load([3]f32, actor + 0xe2c));
                debug[7..10].* = @bitCast(value.motion_origin);
                debug[10] = frame.sequence;
                debug[11] = value.body.active;
            }
            debug[0] +%= 1;
        }
        store([3]f32, actor + 0xe2c, value.motion_origin);
        store(i8, actor + 0xdde, value.health);
        store(u8, actor + 0xddd, value.max_health);
        const wallet = load(usize, actor + 0x5b0);
        if (value.has_wallet != 0 and s.valid(wallet, 8)) store(u64, wallet, value.wallet);
        if (load(i16, actor + 0x2e8) != value.animation.current) {
            const model = load(usize, actor + 8);
            const body = if (s.valid(model, 0x40)) load(usize, model + 0x3c) else 0;
            const change: *const fn (usize, usize, c_int) callconv(.c) void = @ptrFromInt(0x8a93f0);
            change(body, actor + 0xee0, value.animation.current);
            if (!live(token) or !stillAssigned(actor, allocation, &value, controller)) return false;
        }
        store(i16, actor + 0x2e8, value.animation.current);
        store([5]f32, actor + 0xee4, value.animation.frames);
        store(u16, actor + 0xef8, value.animation.flags);
        store([5]i16, actor + 0xefa, value.animation.clips);
    }
    return true;
}
const Correct = struct { frame: *const s.p.SyncFrame, token: s.Token, bound: bool, result: bool = false };
fn invoke(context: usize) callconv(.c) usize {
    const call: *Correct = @ptrFromInt(context);
    call.result = correctImpl(call.frame, &call.token);
    return 0;
}
fn abort(context: usize) callconv(.c) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Correct = @ptrFromInt(context);
    if (call.bound and api.coherent_frame_close(&call.token) != 0) {
        api.coherent_frame_cancel_atomic(0x10000000);
        @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    }
}
pub fn correct(frame: *const s.p.SyncFrame) bool {
    var call = Correct{ .frame = frame, .token = undefined, .bound = false };
    call.bound = s.captureDispatch(&call.token);
    if (!call.bound or call.token.frame != @intFromPtr(frame)) return false;
    _ = constructor_lexical_seh(@intFromPtr(&call), invoke, abort);
    return call.result;
}
