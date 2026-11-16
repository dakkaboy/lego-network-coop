const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const read = s.read;
extern fn shooter_observer_actor_snapshot(*@import("shooter_types.zig").Actor, usize) void;
pub fn actorAt(slot: i32, generation: u32) usize {
    const actor = if (slot >= 0) s.entities_actor(@intCast(slot), generation) else 0;
    return if (s.valid(actor, 0x1440) and read(u32, actor + 0x50) & 3 == 3) actor else 0;
}
pub fn find(id: u32) ?*t.Tracked {
    for (&s.tracked) |*entry| if (entry.birth.id == id) return entry;
    return null;
}
pub fn index(entry: *const t.Tracked) usize {
    return (@intFromPtr(entry) - @intFromPtr(&s.tracked)) / @sizeOf(t.Tracked);
}
pub fn failure(op: *const t.Operation, reason: u32, owner: usize, weapon: usize, flags: u32, target: usize, caller: u32, expected: u32) void {
    if (op.kind != t.keyed or !control.live(op) or @cmpxchgStrong(i32, &s.clonewars_projectile_failure_committed, 0, -1, .seq_cst, .seq_cst) != null) return;
    var value = std.mem.zeroes(t.Failure);
    value.reason = reason;
    value.sequence = if (s.current) |frame| frame.sequence else 0;
    value.thread = s.win.GetCurrentThreadId();
    value.caller = caller;
    value.fire_caller = if (s.active_fire) |fire| fire.caller else 0;
    value.fire_mode = if (s.active_fire) |fire| @bitCast(fire.mode) else 0;
    value.clock = read(u32, 0xfb4b6c);
    value.rng_game = read(u32, 0xe637b4);
    value.rng_engine = read(u32, 0xea178c);
    value.ordinal = s.clonewars_projectile_debug[7];
    value.shot_count = if (s.current) |frame| frame.shot_count else 0;
    value.projectile_count = if (s.current) |frame| frame.projectile_count else 0;
    value.expected_index = expected;
    value.weapon = if (s.valid(weapon, 1)) @bitCast(@as(i32, read(i8, weapon))) else std.math.maxInt(u32);
    value.flags = flags;
    value.target_local = @truncate(target);
    @import("observation.zig").timestamp(&value.qpc_low, &value.qpc_high);
    if (s.current) |frame| if (expected < frame.shot_count) {
        value.expected = frame.shots[expected];
    };
    shooter_observer_actor_snapshot(&value.actor, owner);
    if (!control.live(op)) {
        @atomicStore(i32, &s.clonewars_projectile_failure_committed, 0, .seq_cst);
        return;
    }
    if (s.valid(owner, 0x1440)) {
        value.action_timer = read(u32, owner + 0x2ac);
        value.cooldown = read(u32, owner + 0x7ec);
        const pending = read(usize, owner + 0x142c);
        value.pending_local = @truncate(pending);
        if (s.valid(pending, 0x144)) {
            value.pending_valid = 1;
            for ([_]usize{ 0xbc, 0xcc, 0xd8, 0xdc, 0xe0, 0x140, 0 }, &value.pending_words) |offset, *word| word.* = read(u32, pending + offset);
        }
    }
    if (!control.live(op)) {
        @atomicStore(i32, &s.clonewars_projectile_failure_committed, 0, .seq_cst);
        return;
    }
    s.clonewars_projectile_failure = value;
    @atomicStore(i32, &s.clonewars_projectile_failure_committed, 1, .seq_cst);
}
pub export fn projectiles_observe_live(object: usize, view: *t.Identity) c_int {
    view.* = std.mem.zeroes(t.Identity);
    view.owner = -1;
    view.weapon = -1;
    const op = control.capture();
    if ((op.kind != t.keyed and op.kind != t.control) or !control.live(&op)) {
        view.status = 2;
        return 2;
    }
    if (object == 0) return 0;
    if (!s.valid(object, 0x210) or !control.live(&op)) {
        view.status = 5;
        return 5;
    }
    const resource = read(usize, object + 0x14);
    var id: u32 = 0;
    var mismatch = false;
    var ambiguous = false;
    if (resource != 0) for (s.tracked) |entry| {
        if (entry.birth.id == 0 or entry.object != object) continue;
        if (entry.resource != resource) {
            mismatch = true;
            continue;
        }
        if (id != 0) {
            id = 0;
            ambiguous = true;
            break;
        }
        id = entry.birth.id;
    };
    view.status = if (resource == 0) 5 else if (ambiguous) 4 else if (id != 0) 1 else if (mismatch) 3 else 2;
    if (view.status != 1 or !control.live(&op)) {
        view.status = 2;
        return 2;
    }
    const entry = find(id) orelse {
        view.status = 3;
        return 3;
    };
    if (entry.object != object or entry.resource != resource or !control.live(&op) or read(usize, object + 0x14) != resource) {
        view.status = 3;
        return 3;
    }
    if (read(u32, object + 8) != entry.native_stamp) {
        view.status = 7;
        return 7;
    }
    view.id = id;
    view.owner = entry.birth.owner;
    view.owner_generation = entry.birth.owner_generation;
    view.weapon = entry.birth.weapon;
    view.resource_local = @truncate(resource);
    const i = index(entry);
    view.instance_serial = s.instance_serial[i];
    view.creation_count = s.creation_count[i];
    return @intCast(view.status);
}
pub fn remember(op: *const t.Operation, shot: *const p.SyncShot, object: usize) ?*t.Tracked {
    if (!control.live(op) or (op.kind != t.keyed and op.kind != t.control)) return null;
    const birth = shot.*;
    var found = find(birth.id);
    if (found == null) for (&s.tracked) |*entry| if (entry.birth.id == 0) {
        found = entry;
        break;
    };
    const entry = found orelse {
        control.reject(op, t.capacity);
        return null;
    };
    var resource: usize = 0;
    if (s.valid(object, 0x210)) {
        if (!control.live(op)) return null;
        resource = read(usize, object + 0x14);
    }
    if (!control.live(op)) return null;
    const i = index(entry);
    if (entry.birth.id != birth.id) s.creation_count[i] = 0;
    if (object != 0) {
        if (s.next_instance_serial == std.math.maxInt(u32) or s.creation_count[i] == std.math.maxInt(u32)) {
            control.reject(op, t.exhausted);
            return null;
        }
        s.next_instance_serial += 1;
        s.instance_serial[i] = s.next_instance_serial;
        s.creation_count[i] += 1;
    }
    entry.* = .{ .birth = birth, .object = object, .resource = resource, .native_stamp = if (object != 0 and resource != 0) read(u32, object + 8) else 0 };
    control.dispatchChanged(op);
    return if (control.live(op)) entry else null;
}
pub fn context() t.ShotContext {
    return .{ .clock = read(u32, 0xfb4b6c), .rng_game = read(u32, 0xe637b4), .rng_engine = read(u32, 0xea178c), .delta = read(f32, 0xfb4b74) };
}
pub fn applyContext(value: *const t.ShotContext) void {
    s.win.store(u32, 0xfb4b6c, value.clock);
    s.win.store(u32, 0xe637b4, value.rng_game);
    s.win.store(u32, 0xea178c, value.rng_engine);
    s.win.store(f32, 0xfb4b74, value.delta);
}
pub fn captureContext(birth: *p.SyncShot) void {
    const value = context();
    birth.clock = value.clock;
    birth.rng_game = value.rng_game;
    birth.rng_engine = value.rng_engine;
    birth.delta = value.delta;
}
pub fn captureSeed(op: *const t.Operation, birth: *p.SyncShot, object: usize) void {
    if (object == 0 or !s.valid(object, 0x210) or !control.live(op)) return;
    const seed: p.SyncProjectileSeed = .{ .cast_origin = read([3]f32, object + 0xec), .age = read(f32, object + 0x12c), .expires_at = read(f32, object + 0x134), .cast_countdown = read(f32, object + 0x144) };
    if (!@import("validation.zig").finite(seed)) return;
    birth.projectile_seed = seed;
    birth.has_projectile_seed = 1;
}
pub fn applySeed(op: *const t.Operation, birth: *const p.SyncShot, object: usize) void {
    if (birth.has_projectile_seed == 0 or object == 0 or !s.valid(object, 0x210) or !control.live(op)) return;
    s.win.store([3]f32, object + 0xec, birth.projectile_seed.cast_origin);
    s.win.store(f32, object + 0x12c, birth.projectile_seed.age);
    s.win.store(f32, object + 0x134, birth.projectile_seed.expires_at);
    s.win.store(f32, object + 0x144, birth.projectile_seed.cast_countdown);
}
pub fn capture(op: *const t.Operation, state: *p.SyncProjectile, entry: *const t.Tracked) bool {
    if (!control.live(op) or op.kind != t.keyed) return false;
    const object = entry.object;
    if (!s.valid(object, 0x210) or !control.live(op)) return false;
    if (read(usize, object + 0x14) != entry.resource or read(u32, object + 8) != entry.native_stamp) {
        failure(op, 5, actorAt(entry.birth.owner, entry.birth.owner_generation), 0, entry.birth.id, object, 0, std.math.maxInt(u32));
        s.failed = true;
        return false;
    }
    var value = std.mem.zeroes(p.SyncProjectile);
    value.id = entry.birth.id;
    inline for (.{ .{ "transform", 0x24 }, .{ "position", 0xa4 }, .{ "previous", 0xbc }, .{ "velocity", 0xc8 }, .{ "direction", 0xd4 }, .{ "previous_direction", 0xe0 }, .{ "flags", 0x160 }, .{ "cast_origin", 0xec } }) |field| @field(value, field[0]) = read(@FieldType(p.SyncProjectile, field[0]), object + field[1]);
    for (t.flight_offsets, &value.flight) |offset, *flight| flight.* = read(f32, object + offset);
    if (!control.live(op)) return false;
    state.* = value;
    return true;
}
pub fn correct(op: *const t.Operation, state: *const p.SyncProjectile, entry: *t.Tracked) bool {
    if (!control.live(op) or op.kind != t.keyed) return false;
    const value = state.*;
    const object = entry.object;
    if (!s.valid(object, 0x210) or !control.live(op)) return false;
    inline for (.{ .{ "transform", 0x24 }, .{ "position", 0xa4 }, .{ "previous", 0xbc }, .{ "velocity", 0xc8 }, .{ "direction", 0xd4 }, .{ "previous_direction", 0xe0 }, .{ "flags", 0x160 }, .{ "cast_origin", 0xec } }) |field| s.win.store(@FieldType(p.SyncProjectile, field[0]), object + field[1], @field(value, field[0]));
    for (t.flight_offsets, value.flight) |offset, flight| s.win.store(f32, object + offset, flight);
    const radius = read(f32, object + 0x13c);
    for (value.position, 0..) |position, i| {
        s.win.store(f32, object + 0xf8 + i * 4, position - radius);
        s.win.store(f32, object + 0x104 + i * 4, position + radius);
    }
    return control.live(op);
}
