const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const tracking = @import("projectile_tracking.zig");
const launch = @import("projectile_launch.zig");
const shot_source = @import("shot_source.zig");
const Machine = @import("machine_environment.zig").Environment;
fn isDefenseTurretWeapon(level: i32, weapon: i32, flags: u32, source: u8) bool {
    return (level == 79 and (weapon == 29 or weapon == 31) or level == 24 and weapon == 31) and
        flags == 0x800 and source == p.SYNC_SHOT_WEAPON;
}
fn isDefenseTurret(actor: usize) bool {
    return s.valid(actor, 0x1440) and s.read(u16, actor + 0xdc0) == 466;
}
fn isBombRoomPadmeShot(actor: usize, weapon: i32, flags: u32, source: u8, depth: u32, origin: [3]f32) bool {
    return weapon == 7 and flags == 0 and depth == 0 and
        (source == p.SYNC_SHOT_WEAPON or source == p.SYNC_SHOT_ACTOR_FOLLOWUP) and
        origin[0] < -17 and origin[2] > 24 and
        s.valid(actor, 0x1440) and s.read(u16, actor + 0xdc0) == 188;
}
pub fn canReplayAfterTick(level: i32, shot: *const p.SyncShot) bool {
    if (shot_source.isGeonosisBarrage(level, shot.owner, shot.weapon, shot.flags, shot.source)) return true;
    if (level == 73 and shot.owner == -1 and shot.weapon == 7 and shot.flags == 0x20010892 and
        shot.source == p.SYNC_SHOT_PROJECTILE_CHILD and shot.depth == 1 and shot.has_projectile_seed != 0 and
        shot.origin[2] >= 33 and shot.origin[2] <= 42) return true;
    if (level == 74 and isBombRoomPadmeShot(tracking.actorAt(shot.owner, shot.owner_generation), shot.weapon, shot.flags, shot.source, shot.depth, shot.origin)) return true;
    return isDefenseTurretWeapon(level, shot.weapon, shot.flags, shot.source) and
        isDefenseTurret(tracking.actorAt(shot.owner, shot.owner_generation));
}
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn combat_observer_projectile_created() void;
fn native(op: *const t.Operation, birth: ?*const p.SyncShot, kind: u32, caller: u32, manager: usize, owner: usize, origin: usize, transform: usize, weapon: usize, flags: u32, target: usize, source: u8, depth: u32) usize {
    if (source == p.SYNC_SHOT_WEAPON) {
        if (@import("projectile_constructor.zig").enabled) return @import("projectile_constructor.zig").create(op, manager, owner, origin, transform, weapon, flags, target, birth, kind, caller);
        const primary: t.Create = @ptrFromInt(0x869060);
        return primary(manager, owner, origin, transform, weapon, flags, target);
    }
    const secondary: t.CreateSecondary = @ptrFromInt(0x8630f0);
    return secondary(manager, owner, origin, transform, weapon, flags, depth, target);
}
const Replay = struct { op: t.Operation, manager: usize, owner: usize = 0, target: usize, birth: p.SyncShot, weapon: i8 = 0, caller: u32, launch: t.Launch = undefined, incoming: t.ShotContext = undefined, context_active: bool = false };
extern fn projectile_replay_complete(*Replay, usize) void;
export fn projectile_replay_complete_impl(call: *Replay, object: usize) void {
    const op = &call.op;
    if (!control.live(op)) return;
    tracking.applySeed(op, &call.birth, object);
    if (!control.live(op)) return;
    if (object != 0) combat_observer_projectile_created();
    if (!control.live(op)) return;
    if (call.birth.source == p.SYNC_SHOT_WEAPON) s.win.store(usize, 0xe8ed28, 0);
    _ = tracking.remember(op, &call.birth, object);
    if (control.live(op)) {
        s.clonewars_projectile_debug[3] +%= 1;
        if (call.birth.owner == 1) s.clonewars_projectile_debug[9] +%= 1;
    }
}
fn replayLeave(call: *Replay, completed: bool) void {
    launch.leave(&call.launch);
    if (!call.context_active or !control.live(&call.op)) return;
    call.context_active = false;
    // Only replay inside the native call advances the frame's RNG.
    if (completed and call.birth.phase == 0 and call.caller != 0) {
        const after = tracking.context();
        call.incoming.rng_game = after.rng_game;
        call.incoming.rng_engine = after.rng_engine;
    }
    tracking.applyContext(&call.incoming);
}
fn replayInvoke(context: usize) callconv(.c) usize {
    const call: *Replay = @ptrFromInt(context);
    if (!control.live(&call.op)) return 0;
    call.launch = .{ .previous = s.launch, .operation = &call.op, .shot = &call.birth, .owner = call.owner, .origin = @intFromPtr(&call.birth.origin), .transform = @intFromPtr(&call.birth.transform), .center_visited = false };
    s.launch = &call.launch;
    call.incoming = tracking.context();
    const birth: t.ShotContext = .{ .clock = call.birth.clock, .rng_game = call.birth.rng_game, .rng_engine = call.birth.rng_engine, .delta = call.birth.delta };
    call.context_active = true;
    tracking.applyContext(&birth);
    const object = native(&call.op, &call.birth, if (call.birth.phase == 1) 3 else 2, call.caller, call.manager, call.owner, @intFromPtr(&call.birth.origin), @intFromPtr(&call.birth.transform), @intFromPtr(&call.weapon), call.birth.flags, call.target, call.birth.source, call.birth.depth);
    const saved = s.win.GetLastError();
    replayLeave(call, true);
    s.win.SetLastError(saved);
    if (@intFromBool(call.launch.center_visited) != call.birth.has_launch_center) s.clonewars_shot_center_debug[3] +%= 1;
    projectile_replay_complete(call, object);
    return object;
}
fn replayAbort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Replay = @ptrFromInt(context);
    replayLeave(call, false);
    control.exception(&call.op);
}
pub fn replay(op: *const t.Operation, manager: usize, shot: *const p.SyncShot, target: usize, caller: u32) usize {
    if (!control.live(op) or op.kind != t.keyed) return 0;
    var call: Replay = .{ .op = op.*, .manager = manager, .target = target, .birth = shot.*, .caller = caller };
    call.weapon = @truncate(call.birth.weapon);
    call.owner = tracking.actorAt(call.birth.owner, call.birth.owner_generation);
    if (!control.live(op)) return 0;
    if (call.birth.owner >= 0 and call.owner == 0 and s.entities_is_retired(@intCast(call.birth.owner), call.birth.owner_generation) == 0) {
        if (control.live(op)) s.failed = true;
        return 0;
    }
    return constructor_lexical_seh(@intFromPtr(&call), replayInvoke, replayAbort);
}
const Call = struct {
    op: t.Operation,
    manager: usize,
    owner: usize,
    target: usize,
    origin: usize,
    transform: usize,
    weapon: usize,
    flags: u32,
    caller: u32,
    path: u32 = 0,
    shot_index: usize = 0,
    depth: u32 = 0,
    source: u8 = 0,
    birth: ?*p.SyncShot = null,
    launch: t.Launch = undefined,
};
extern fn projectile_create_commit(*Call, usize) void;
fn create(call: *Call) usize {
    return native(&call.op, call.birth, if (call.path == 3) 4 else if (call.path == 2) 1 else 0, call.caller, call.manager, call.owner, call.origin, call.transform, call.weapon, call.flags, call.target, call.source, call.depth);
}
export fn projectile_create_commit_impl(call: *Call, object: usize) void {
    const op = &call.op;
    if (!control.live(op)) {
        if (op.kind == t.control) control.reject(op, t.abandoned);
        return;
    }
    if (object != 0) combat_observer_projectile_created();
    if (!control.live(op)) {
        if (op.kind == t.control) control.reject(op, t.abandoned);
        return;
    }
    if (call.path == 1) {
        if (object != 0) for (s.legacy, 0..) |legacy, i| if (legacy == 0) {
            _ = control.legacySet(op, i, object);
            break;
        };
        return;
    }
    if (call.path == 2 or call.path == 3) tracking.captureSeed(op, call.birth.?, object);
    if (!control.live(op)) return;
    if (call.path == 3) {
        if (call.shot_index >= s.pending_count or s.pending[call.shot_index].id != call.birth.?.id) {
            control.reject(op, t.provenance);
            return;
        }
        s.pending[call.shot_index] = call.birth.?.*;
        if (tracking.remember(op, call.birth.?, object) == null or !control.live(op)) return;
        s.pending_provenance[call.shot_index].committed = 1;
        return;
    }
    if (call.path == 2) {
        s.current.?.shots[call.shot_index] = call.birth.?.*;
        _ = tracking.remember(op, call.birth.?, object);
        if (control.live(op)) {
            s.clonewars_projectile_debug[2] +%= 1;
            if (call.birth.?.owner == 1) s.clonewars_projectile_debug[9] +%= 1;
        }
    }
}
fn withLaunch(call: *Call, birth: *p.SyncShot) usize {
    call.launch = .{ .previous = s.launch, .operation = &call.op, .shot = birth, .owner = call.owner, .origin = call.origin, .transform = call.transform, .center_visited = false };
    s.launch = &call.launch;
    const object = create(call);
    launch.leave(&call.launch);
    return object;
}
fn invoke(context: usize) callconv(.c) usize {
    const call: *Call = @ptrFromInt(context);
    const op = &call.op;
    if (call.source != p.SYNC_SHOT_WEAPON and (op.kind != t.keyed or (s.launch != null and s.launch.?.shot.phase == 1))) return create(call);
    control.admit(op);
    if (op.kind == t.client_decline or op.kind == t.control_fault) return 0;
    if (op.kind == t.control) {
        if (op.session.host == 0) return 0;
        if (!control.live(op)) {
            control.reject(op, t.abandoned);
            return 0;
        }
        if (s.pending_count == p.SYNC_MAX_SHOTS) {
            control.reject(op, t.capacity);
            return 0;
        }
        if (s.next_id == std.math.maxInt(u32)) {
            control.reject(op, t.exhausted);
            return 0;
        }
        s.entities_update();
        if (!control.live(op)) {
            control.reject(op, t.abandoned);
            return 0;
        }
        var birth = std.mem.zeroes(p.SyncShot);
        birth.owner = s.entities_slot(call.owner);
        birth.owner_generation = s.entities_generation(call.owner);
        if (!control.live(op)) return 0;
        if (!s.valid(call.weapon, 1) or !s.valid(call.origin, 12) or !s.valid(call.transform, 64) or !control.live(op) or (call.owner != 0 and birth.owner < 0) or s.read(i8, call.weapon) < 0) {
            control.reject(op, t.unavailable);
            return 0;
        }
        s.next_id += 1;
        birth.id = s.next_id;
        birth.weapon = s.read(i8, call.weapon);
        birth.flags = call.flags;
        birth.phase = 1;
        tracking.captureContext(&birth);
        birth.origin = s.read(@FieldType(p.SyncShot, "origin"), call.origin);
        birth.transform = s.read(@FieldType(p.SyncShot, "transform"), call.transform);
        if (!control.live(op)) return 0;
        call.path = 3;
        call.shot_index = s.pending_count;
        s.pending[s.pending_count] = birth;
        s.pending_provenance[s.pending_count] = .{ .epoch = op.control.epoch, .level = op.control.level, .release = op.control.release, .session = op.session.session, .generation = op.reset_generation, .committed = 0 };
        s.pending_count += 1;
        call.birth = &birth;
        const object = withLaunch(call, &birth);
        projectile_create_commit(call, object);
        return object;
    }
    if (op.kind != t.keyed or !control.live(op)) return create(call);
    s.clonewars_projectile_debug[7] +%= 1;
    if (!s.host) {
        if (!s.authority) {
            call.path = 1;
            const object = create(call);
            projectile_create_commit(call, object);
            return object;
        }
        const slot = s.entities_slot(call.owner);
        const generation = s.entities_generation(call.owner);
        if (!control.live(op)) return 0;
        if (!s.valid(call.weapon, 1) or !control.live(op)) return 0;
        const weapon = s.read(i8, call.weapon);
        const level = s.current.?.level;
        const can_defer = (call.owner == 0 and call.target == 0 and shot_source.isGeonosisBarrage(level, slot, weapon, call.flags, call.source)) or
            (slot >= 0 and isDefenseTurretWeapon(level, weapon, call.flags, call.source) and isDefenseTurret(call.owner)) or
            (level == 74 and slot >= 0 and s.valid(call.origin, 12) and
                (call.source == p.SYNC_SHOT_WEAPON or call.target == 0) and
                isBombRoomPadmeShot(call.owner, weapon, call.flags, call.source, call.depth, s.read([3]f32, call.origin)));
        var i: u32 = 0;
        while (control.live(op) and i < s.current.?.shot_count) : (i += 1) {
            const shot = &s.current.?.shots[i];
            if (s.consumed[i] != 0 or shot.phase != 0) continue;
            if (shot_source.matches(shot, slot, generation, weapon, call.source, @truncate(call.depth))) {
                s.consumed[i] = 1;
                return replay(op, call.manager, shot, call.target, call.caller);
            }
            if (can_defer) return 0;
            if (canReplayAfterTick(level, shot)) continue;
            tracking.failure(op, 1, call.owner, call.weapon, call.flags, call.target, call.caller, i);
            if (control.live(op)) s.failed = true;
            break;
        }
        if (!can_defer and control.live(op)) {
            tracking.failure(op, 2, call.owner, call.weapon, call.flags, call.target, call.caller, std.math.maxInt(u32));
            s.failed = true;
            s.clonewars_projectile_debug[4] +%= 1;
        }
        return 0;
    }
    if (s.current.?.shot_count == p.SYNC_MAX_SHOTS) {
        s.failed = true;
        return 0;
    }
    s.entities_update();
    if (!control.live(op)) return 0;
    if (s.next_id == std.math.maxInt(u32)) {
        control.reject(op, t.exhausted);
        return 0;
    }
    var birth = std.mem.zeroes(p.SyncShot);
    s.next_id += 1;
    birth.id = s.next_id;
    birth.owner = s.entities_slot(call.owner);
    birth.owner_generation = s.entities_generation(call.owner);
    if (!control.live(op)) return 0;
    if (!s.valid(call.weapon, 1) or !control.live(op)) return 0;
    birth.weapon = s.read(i8, call.weapon);
    birth.flags = call.flags;
    if ((call.owner != 0 and birth.owner < 0) or !s.valid(call.origin, 12) or !s.valid(call.transform, 64) or birth.weapon < 0) {
        if (control.live(op)) s.failed = true;
        return create(call);
    }
    birth.source = call.source;
    birth.depth = @truncate(call.depth);
    if (!control.live(op)) return 0;
    tracking.captureContext(&birth);
    birth.origin = s.read(@FieldType(p.SyncShot, "origin"), call.origin);
    birth.transform = s.read(@FieldType(p.SyncShot, "transform"), call.transform);
    if (!control.live(op)) return 0;
    const i = s.current.?.shot_count;
    s.current.?.shot_count += 1;
    s.current.?.shots[i] = birth;
    call.path = 2;
    call.shot_index = i;
    call.birth = &birth;
    const object = withLaunch(call, &birth);
    projectile_create_commit(call, object);
    return object;
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Call = @ptrFromInt(context);
    launch.leave(&call.launch);
    control.exception(&call.op);
}
pub export fn projectile_create_hook(manager: usize, _: usize, owner: usize, origin: usize, transform: usize, weapon: usize, flags: u32, target: usize) callconv(.{ .x86_fastcall = .{} }) usize {
    var call: Call = .{ .op = control.capture(), .manager = manager, .owner = owner, .target = target, .origin = origin, .transform = transform, .weapon = weapon, .flags = flags, .caller = @truncate(@returnAddress()) };
    return constructor_lexical_seh(@intFromPtr(&call), invoke, abort);
}
pub export fn projectile_create_secondary_hook(manager: usize, _: usize, owner: usize, origin: usize, transform: usize, weapon: usize, flags: u32, depth: u32, target: usize) callconv(.{ .x86_fastcall = .{} }) usize {
    const caller: u32 = @truncate(@returnAddress());
    var call: Call = .{ .op = control.capture(), .manager = manager, .owner = owner, .target = target, .origin = origin, .transform = transform, .weapon = weapon, .flags = flags, .caller = caller, .depth = depth, .source = if (caller == t.actor_followup_site + 5) p.SYNC_SHOT_ACTOR_FOLLOWUP else p.SYNC_SHOT_PROJECTILE_CHILD };
    return constructor_lexical_seh(@intFromPtr(&call), invoke, abort);
}
comptime {
    asm (@import("native_completion.zig").code("projectile_replay_complete", "projectile_replay_complete_impl"));
    asm (@import("native_completion.zig").code("projectile_create_commit", "projectile_create_commit_impl"));
}
