const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const read = s.read;
const removal = @import("projectile_removal.zig");
const Machine = @import("machine_environment.zig").Environment;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
pub fn forget(id: u32, instance: u32) void {
    for (s.retire_pending[0..s.retire_pending_count]) |*pending| if (pending.request.id == id and pending.instance == instance) {
        pending.request.id = 0;
    };
    if (s.host) for (s.retire_batch[0..s.retire_batch_count]) |*pending| if (pending.request.id == id and pending.instance == instance) {
        pending.request.id = 0;
    };
}
pub fn managerLive(manager: usize) bool {
    const root = read(usize, 0xe9019c);
    return s.valid(root, 0x3c) and s.valid(manager, 0x28) and read(usize, root + 0x38) == manager;
}
pub fn reject(op: *const t.Operation) bool {
    s.clonewars_projectile_retire_debug[5] +%= 1;
    control.reject(op, t.provenance);
    return false;
}
pub fn enqueue(op: *const t.Operation, manager: usize, object: usize, flags: u32, effects: c_int, caller: u32) bool {
    if (caller != t.render_retire_caller or op.kind == t.unkeyed or op.kind == t.barrier) return false;
    var slot: usize = p.SYNC_MAX_PROJECTILES;
    for (s.tracked, 0..) |entry, i| if (entry.birth.id != 0 and entry.object == object) {
        if (slot != p.SYNC_MAX_PROJECTILES) {
            _ = reject(op);
            return true;
        }
        slot = i;
    };
    if (slot == p.SYNC_MAX_PROJECTILES) return false;
    if ((op.kind != t.keyed and op.kind != t.control) or !control.live(op) or flags != 0 or effects != 0 or s.instance_serial[slot] == 0 or !s.valid(object, 0x210) or read(usize, object + 0x14) != s.tracked[slot].resource or !managerLive(manager) or !control.live(op)) {
        _ = reject(op);
        return true;
    }
    if (op.session.host == 0) {
        s.clonewars_projectile_retire_debug[1] +%= 1;
        return true;
    }
    const id = s.tracked[slot].birth.id;
    const instance = s.instance_serial[slot];
    var free_slot = s.retire_pending_count;
    for (s.retire_pending[0..s.retire_pending_count], 0..) |*pending, i| {
        if (pending.request.id == 0) {
            if (free_slot == s.retire_pending_count) free_slot = i;
            continue;
        }
        if (pending.request.id == id) {
            if (pending.instance != instance or pending.object != object or pending.resource != s.tracked[slot].resource or pending.manager != manager) _ = reject(op);
            return true;
        }
    }
    if (free_slot == p.SYNC_MAX_PROJECTILES) {
        control.reject(op, t.capacity);
        return true;
    }
    var pending = std.mem.zeroes(t.Retire);
    pending.request = .{ .id = id, .flags = flags, .effects = effects, .caller = caller };
    pending.object = object;
    pending.resource = s.tracked[slot].resource;
    pending.manager = manager;
    pending.instance = instance;
    pending.source_sequence = if (op.kind == t.keyed) op.frame.cohort.sequence else 0;
    pending.provenance = .{ .epoch = op.session.epoch, .level = op.session.level, .release = if (op.kind == t.keyed) op.frame.cohort.release else op.control.release, .session = op.session.session, .generation = op.reset_generation, .committed = 1 };
    if (!control.live(op)) {
        _ = reject(op);
        return true;
    }
    s.retire_pending[free_slot] = pending;
    if (free_slot == s.retire_pending_count) s.retire_pending_count += 1;
    s.clonewars_projectile_retire_debug[0] +%= 1;
    return true;
}
fn resolve(op: *const t.Operation, pending: *t.Retire) bool {
    if (!control.live(op) or pending.request.id == 0 or pending.request.flags != 0 or pending.request.effects != 0 or pending.request.caller != t.render_retire_caller) return false;
    var slot: usize = p.SYNC_MAX_PROJECTILES;
    for (s.tracked, 0..) |entry, i| if (entry.birth.id == pending.request.id) {
        if (slot != p.SYNC_MAX_PROJECTILES) return false;
        slot = i;
    };
    if (slot == p.SYNC_MAX_PROJECTILES) return false;
    const entry = &s.tracked[slot];
    if (s.instance_serial[slot] == 0 or !s.valid(entry.object, 0x210) or entry.resource == 0 or read(usize, entry.object + 0x14) != entry.resource) return false;
    for (s.tracked, 0..) |other, i| if (i != slot and other.birth.id != 0 and other.object == entry.object) return false;
    const root = read(usize, 0xe9019c);
    if (!s.valid(root, 0x3c)) return false;
    const manager = read(usize, root + 0x38);
    if (!managerLive(manager)) return false;
    if (pending.instance != 0) {
        if (pending.instance != s.instance_serial[slot] or pending.object != entry.object or pending.resource != entry.resource or pending.manager != manager) return false;
    } else {
        pending.instance = s.instance_serial[slot];
        pending.object = entry.object;
        pending.resource = entry.resource;
        pending.manager = manager;
    }
    return control.live(op);
}
const Drain = struct { op: t.Operation, frame: *p.SyncFrame, result: bool = false };
fn invoke(context: usize) callconv(.c) usize {
    const drain: *Drain = @ptrFromInt(context);
    const op = &drain.op;
    const frame = drain.frame;
    if (s.host) {
        if (s.retire_pending_count > p.SYNC_MAX_PROJECTILES or frame.projectile_retire_count != 0) return 0;
        s.retire_batch_count = 0;
        var kept: usize = 0;
        for (0..s.retire_pending_count) |i| {
            const pending = s.retire_pending[i];
            if (pending.request.id == 0) continue;
            if (pending.source_sequence == op.frame.cohort.sequence) {
                s.retire_pending[kept] = pending;
                kept += 1;
            } else {
                s.retire_batch[s.retire_batch_count] = pending;
                s.retire_batch_count += 1;
            }
        }
        for (s.retire_pending[kept..]) |*pending| pending.* = std.mem.zeroes(t.Retire);
        s.retire_pending_count = kept;
        for (0..s.retire_batch_count) |i| {
            const pending = &s.retire_batch[i];
            if (pending.request.id == 0) continue;
            const provenance = &pending.provenance;
            if (provenance.committed == 0 or provenance.epoch != op.frame.cohort.epoch or provenance.level != s.level or provenance.release != op.frame.cohort.release or provenance.session != op.session.session or provenance.generation != s.reset_generation or (pending.source_sequence != 0 and pending.source_sequence >= op.frame.cohort.sequence) or !resolve(op, pending)) return 0;
            for (s.retire_batch[0..i]) |other| if (other.request.id == pending.request.id) return 0;
        }
    } else {
        if (frame.projectile_retire_count > p.SYNC_MAX_PROJECTILES or s.retire_pending_count != 0) return 0;
        s.retire_batch_count = frame.projectile_retire_count;
        s.retire_batch = std.mem.zeroes(@TypeOf(s.retire_batch));
        for (0..s.retire_batch_count) |i| {
            const pending = &s.retire_batch[i];
            pending.request = frame.projectile_retires[i];
            for (s.retire_batch[0..i]) |other| if (other.request.id == pending.request.id) return 0;
            if (!resolve(op, pending)) return 0;
        }
    }
    var i: usize = 0;
    while (i < s.retire_batch_count) : (i += 1) {
        if (!control.live(op) or s.current != frame) return 0;
        var pending = s.retire_batch[i];
        if (pending.request.id == 0) continue;
        if (!resolve(op, &pending)) return 0;
        var call = std.mem.zeroes(removal.Call);
        call.op = op.*;
        call.manager = pending.manager;
        call.object = pending.object;
        call.flags = pending.request.flags;
        call.effects = pending.request.effects;
        call.hook_commit = true;
        for (s.tracked, 0..) |entry, j| if (entry.birth.id == pending.request.id) {
            call.captured_id[j] = pending.request.id;
            call.captured_instance[j] = pending.instance;
        };
        if (s.host) {
            if (frame.projectile_retire_count == p.SYNC_MAX_PROJECTILES) return 0;
            frame.projectile_retires[frame.projectile_retire_count] = pending.request;
            frame.projectile_retire_count += 1;
        }
        s.clonewars_projectile_retire_debug[6] = pending.request.id;
        s.clonewars_projectile_retire_debug[7] = pending.request.caller;
        const removed = removal.observed(&call, 3);
        if (!control.live(op) or s.current != frame) return 0;
        if (removed == 0 and !resolve(op, &pending)) return 0;
        s.clonewars_projectile_retire_debug[2] +%= 1;
        if (removed == 0) s.clonewars_projectile_retire_debug[3] +%= 1;
    }
    drain.result = true;
    return 0;
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const drain: *Drain = @ptrFromInt(context);
    s.retire_draining = false;
    s.clonewars_projectile_retire_debug[4] +%= 1;
    control.exception(&drain.op);
}
pub fn dispatch(op: *const t.Operation) bool {
    if (s.retire_draining) return reject(op);
    if (s.retire_dispatch_done) return control.live(op);
    var drain: Drain = .{ .op = op.*, .frame = s.current.? };
    s.retire_draining = true;
    _ = constructor_lexical_seh(@intFromPtr(&drain), invoke, abort);
    s.retire_draining = false;
    s.retire_batch_count = 0;
    if (!drain.result or !control.live(op) or s.current != drain.frame) return reject(op);
    s.retire_dispatch_done = true;
    return true;
}
