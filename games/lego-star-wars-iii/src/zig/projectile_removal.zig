const std = @import("std");
const p = @import("protocol.zig");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const retire = @import("projectile_retire.zig");
const Scope = @import("combat_types.zig").Scope;
const Machine = @import("machine_environment.zig").Environment;
const read = s.read;
pub const Call = struct {
    op: t.Operation,
    manager: usize,
    object: usize,
    flags: u32,
    effects: c_int,
    observation: Scope,
    observing: bool,
    captured_id: [p.SYNC_MAX_PROJECTILES]u32,
    captured_instance: [p.SYNC_MAX_PROJECTILES]u32,
    captured_legacy: [p.SYNC_MAX_PROJECTILES]u64,
    hook_commit: bool,
};
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn combat_observer_remove_begin(*Scope, usize, usize, u32, c_int, u32) c_int;
extern fn combat_observer_remove_end(*Scope, c_int) void;
extern fn combat_observer_remove_abort(*Scope) void;
extern fn projectile_remove_complete(*Call, usize) void;
fn invoke(context: usize) callconv(.c) usize {
    const call: *Call = @ptrFromInt(context);
    const native: t.Remove = @ptrFromInt(0x846460);
    return native(call.manager, call.object, call.flags, call.effects);
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Call = @ptrFromInt(context);
    if (call.observing) combat_observer_remove_abort(&call.observation);
    control.exception(&call.op);
}
fn commit(call: *Call) void {
    for (&s.tracked, 0..) |*entry, i| if (call.captured_id[i] != 0 and entry.birth.id == call.captured_id[i] and s.instance_serial[i] == call.captured_instance[i] and entry.object == call.object) {
        retire.forget(call.captured_id[i], call.captured_instance[i]);
        entry.object = 0;
        if (call.op.session.host != 0) entry.* = std.mem.zeroes(t.Tracked);
        control.dispatchChanged(&call.op);
    };
    for (s.legacy, 0..) |legacy, i| if (call.captured_legacy[i] != 0 and legacy == call.object and s.legacy_version[i] == call.captured_legacy[i]) {
        _ = control.legacySet(&call.op, i, 0);
    };
}
export fn projectile_remove_complete_impl(call: *Call, result: usize) void {
    const removed: u8 = @truncate(result);
    if (!control.live(&call.op)) {
        if (call.observing) combat_observer_remove_abort(&call.observation);
        return;
    }
    if (call.observing) combat_observer_remove_end(&call.observation, removed);
    if (!call.hook_commit or removed == 0 or (call.op.kind != t.keyed and call.op.kind != t.control) or !control.live(&call.op)) return;
    commit(call);
}
pub fn observed(call: *Call, reason: u32) u8 {
    if ((call.op.kind == t.keyed or call.op.kind == t.control) and control.live(&call.op)) {
        call.observing = combat_observer_remove_begin(&call.observation, call.manager, call.object, call.flags, call.effects, @truncate(@returnAddress())) != 0;
        if (call.observing) call.observation.record.arguments[4] = reason;
    }
    const removed: u8 = @truncate(constructor_lexical_seh(@intFromPtr(call), invoke, abort));
    projectile_remove_complete(call, removed);
    return removed;
}
pub export fn projectile_remove_hook(manager: usize, _: usize, object: usize, flags: u32, effects: c_int) callconv(.{ .x86_fastcall = .{} }) u8 {
    var call = std.mem.zeroes(Call);
    call.op = control.capture();
    control.admit(&call.op);
    call.manager = manager;
    call.object = object;
    call.flags = flags;
    call.effects = effects;
    call.hook_commit = true;
    if (retire.enqueue(&call.op, manager, object, flags, effects, @truncate(@returnAddress()))) return 0;
    if ((call.op.kind == t.keyed or call.op.kind == t.control) and control.live(&call.op)) for (s.tracked, 0..) |entry, i| if (entry.object == object) {
        call.captured_id[i] = entry.birth.id;
        call.captured_instance[i] = s.instance_serial[i];
    };
    if ((call.op.kind == t.keyed or call.op.kind == t.control) and control.live(&call.op)) for (s.legacy, 0..) |legacy, i| if (legacy == object) {
        call.captured_legacy[i] = s.legacy_version[i];
    };
    return observed(&call, 0);
}
pub var native_pool_release: t.PoolRelease = @ptrFromInt(0x69c9b0);
const Pool = struct { removal: Call, request: usize, arguments: [3]u32, native_stamp: u32, qualified: bool };
extern fn projectile_pool_complete(*Pool, usize) void;
fn contains(op: *const t.Operation, manager: usize, object: usize, stamp: u32) c_int {
    if (!control.live(op) or !retire.managerLive(manager)) return -1;
    const count = read(u32, manager + 0x2c);
    var visited: u32 = 0;
    if (count == std.math.maxInt(u32)) return -1;
    var node = read(usize, manager + 0x28);
    while (node != 0) : (node = read(usize, node + 0xc)) {
        if (!control.live(op) or !s.valid(node, 0x18)) return -1;
        visited += 1;
        if (visited > count) return -1;
        if (node == object and read(u32, node + 8) == stamp) return 1;
    }
    return if (control.live(op)) 0 else -1;
}
fn poolInvoke(context: usize) callconv(.c) usize {
    const call: *Pool = @ptrFromInt(context);
    return native_pool_release(call.request, call.arguments[0], call.arguments[1], call.arguments[2]);
}
fn poolAbort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Pool = @ptrFromInt(context);
    control.exception(&call.removal.op);
}
export fn projectile_pool_complete_impl(call: *Pool, _: usize) void {
    const removal = &call.removal;
    if (!call.qualified or !control.live(&removal.op)) return;
    const retained = contains(&removal.op, removal.manager, removal.object, call.native_stamp);
    if (retained < 0) {
        control.reject(&removal.op, t.provenance);
        return;
    }
    if (retained != 0) {
        s.clonewars_projectile_pool_release_debug[2] +%= 1;
        return;
    }
    s.clonewars_projectile_pool_release_debug[1] +%= 1;
    for (&s.tracked, 0..) |*entry, i| if (removal.captured_id[i] != 0 and entry.birth.id == removal.captured_id[i] and s.instance_serial[i] == removal.captured_instance[i] and entry.object == removal.object) {
        retire.forget(removal.captured_id[i], removal.captured_instance[i]);
        entry.object = 0;
        if (removal.op.session.host != 0) entry.* = std.mem.zeroes(t.Tracked);
        s.clonewars_projectile_pool_release_debug[3] +%= 1;
        control.dispatchChanged(&removal.op);
    };
    for (s.legacy, 0..) |legacy, i| if (removal.captured_legacy[i] != 0 and legacy == removal.object and s.legacy_version[i] == removal.captured_legacy[i]) {
        _ = control.legacySet(&removal.op, i, 0);
    };
}
pub export fn projectile_pool_release_hook(request: usize, _: usize, a: u32, b: u32, d: u32) callconv(.{ .x86_fastcall = .{} }) usize {
    const saved = s.win.GetLastError();
    var call = std.mem.zeroes(Pool);
    const removal = &call.removal;
    call.request = request;
    call.arguments = .{ a, b, d };
    removal.op = control.capture();
    control.admit(&removal.op);
    if ((removal.op.kind == t.keyed or removal.op.kind == t.control) and control.live(&removal.op) and s.valid(request, 0x18)) {
        const root = read(usize, 0xe9019c);
        const manager = if (s.valid(root, 0x3c)) read(usize, root + 0x38) else 0;
        const pool = if (s.valid(manager, 0x30)) read(usize, manager + 0x20) else 0;
        removal.manager = manager;
        removal.object = read(usize, request + 4);
        if (s.valid(pool, 8) and read(usize, pool + 4) == read(usize, request) and s.valid(removal.object, 0x210)) {
            call.native_stamp = read(u32, removal.object + 8);
            if (contains(&removal.op, manager, removal.object, call.native_stamp) == 1) {
                call.qualified = true;
                s.clonewars_projectile_pool_release_debug[0] +%= 1;
                for (s.tracked, 0..) |entry, i| if (entry.birth.id != 0 and entry.object == removal.object and entry.native_stamp == call.native_stamp and entry.resource == read(usize, removal.object + 0x14)) {
                    removal.captured_id[i] = entry.birth.id;
                    removal.captured_instance[i] = s.instance_serial[i];
                };
                for (s.legacy, 0..) |legacy, i| if (legacy == removal.object) {
                    removal.captured_legacy[i] = s.legacy_version[i];
                };
                s.clonewars_projectile_pool_release_debug[4] = @truncate(@returnAddress());
                s.clonewars_projectile_pool_release_debug[5] = read(u32, 0xfb4b6c);
                s.clonewars_projectile_pool_release_debug[6] = call.native_stamp;
            }
        }
    }
    s.win.SetLastError(saved);
    const result = constructor_lexical_seh(@intFromPtr(&call), poolInvoke, poolAbort);
    projectile_pool_complete(&call, result);
    return result;
}
comptime {
    asm (@import("native_completion.zig").code("projectile_remove_complete", "projectile_remove_complete_impl"));
    asm (@import("native_completion.zig").code("projectile_pool_complete", "projectile_pool_complete_impl"));
}
