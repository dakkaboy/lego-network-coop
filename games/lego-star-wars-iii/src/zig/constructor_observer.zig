const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const t = @import("constructor_types.zig");
const api = if (@hasDecl(@import("root"), "constructor_test_api")) @import("root").constructor_test_api else struct {
    pub const readable = win.accessible;
    pub fn address(value: usize) usize {
        return value;
    }
    pub extern fn projectiles_constructor_cohort_valid(*const t.Lease, *const @import("cohort_types.zig").Token) c_int;
    pub extern fn projectiles_constructor_control_valid(*const t.Lease, *const @import("projectile_types.zig").ControlLease, *const @import("projectile_types.zig").Session, u64) c_int;
    pub extern fn projectiles_constructor_hooks_ready() c_int;
    pub extern fn entities_observed_generation(usize) u32;
    pub extern fn entities_allocation_live(usize, u32) c_int;
    pub extern fn entities_observed_identity(usize, *u32, *u32) c_int;
};
pub export var clonewars_constructor_observer_enabled: i32 = 0;
pub export var clonewars_constructor_observer_count: u32 = 0;
pub export var clonewars_constructor_observer_version: u32 = 1;
pub export var clonewars_constructor_observer_stride: u32 = @sizeOf(t.Record);
pub export var clonewars_constructor_observer_capacity: u32 = 512;
pub export var clonewars_constructor_observer_installed: u32 = 0;
pub export var clonewars_constructor_observer_debug: [8]u32 = @splat(0);
pub export var clonewars_constructor_observer_records: [512]t.Record = std.mem.zeroes([512]t.Record);
fn readable(pointer: usize, bytes: usize) bool {
    return api.readable(pointer, bytes, false);
}
fn context(out: *[4]u32) void {
    for ([_]usize{ 0xfb4b6c, 0xe637b4, 0xea178c, 0xfb4b74 }, 0..) |raw, i| {
        const address = api.address(raw);
        if (readable(address, 4)) out[i] = win.load(u32, address);
    }
}
fn valid(scope: *const t.Scope, lease: *const t.Lease) bool {
    if (scope.capability == t.rejected) return false;
    return if (scope.capability == t.control) api.projectiles_constructor_control_valid(lease, &scope.control, &scope.control_session, scope.reset_generation) != 0 else api.projectiles_constructor_cohort_valid(lease, &scope.cohort) != 0;
}
fn copy(out: anytype, pointer: usize) void {
    @memcpy(std.mem.asBytes(out), @as([*]const u8, @ptrFromInt(pointer))[0..@sizeOf(@TypeOf(out.*))]);
}
pub export fn constructor_begin_impl(scope: *t.Scope, call: *const t.Call) void {
    scope.ready = 0;
    scope.cohort = call.cohort;
    scope.control = call.control;
    scope.control_session = call.control_session;
    scope.reset_generation = call.reset_generation;
    scope.capability = call.capability;
    if (clonewars_constructor_observer_enabled == 0 or clonewars_constructor_observer_installed == 0) return;
    if (!valid(scope, &call.lease)) {
        clonewars_constructor_observer_debug[0] +%= 1;
        return;
    }
    const record = &scope.record;
    record.* = std.mem.zeroes(t.Record);
    record.version = 1;
    record.thread = win.GetCurrentThreadId();
    obs.timestamp(&record.qpc_before[0], &record.qpc_before[1]);
    context(&record.before);
    const input = &record.input;
    input.lease = call.lease;
    input.kind = call.kind;
    input.caller = call.caller;
    input.manager_local = call.manager;
    input.owner_local = call.owner;
    input.target_local = call.target;
    input.flags = call.flags;
    input.origin_local = call.origin;
    input.transform_local = call.transform;
    input.weapon_local = call.weapon;
    if (scope.capability != t.control and readable(call.birth, @sizeOf(@import("protocol.zig").SyncShot))) {
        copy(&input.birth, call.birth);
        input.birth_known = 1;
    }
    if (readable(call.origin, 12)) {
        copy(&input.origin, call.origin);
        input.input_valid |= 1;
    }
    if (readable(call.transform, 64)) {
        copy(&input.transform, call.transform);
        input.input_valid |= 2;
    }
    if (readable(call.weapon, 1)) {
        input.weapon = @bitCast(@as(i32, win.load(i8, call.weapon)));
        input.input_valid |= 4;
    }
    record.owner_slot = 0xffffffff;
    record.resolved_slot = 0xffffffff;
    if (readable(call.owner, 0x1440)) {
        record.owner_local_generation = api.entities_observed_generation(call.owner);
        record.owner_character = win.load(u16, call.owner + 0xdc0);
        if (record.owner_local_generation != 0 and api.entities_allocation_live(call.owner, record.owner_local_generation) != 0 and api.entities_observed_identity(call.owner, &record.owner_slot, &record.owner_generation) != 0 and (input.birth_known == 0 or (input.birth.owner == @as(i32, @bitCast(record.owner_slot)) and input.birth.owner_generation == record.owner_generation))) record.valid |= 1;
    }
    if (input.birth_known != 0 and input.birth.owner >= 0 and record.valid & 1 == 0) {
        clonewars_constructor_observer_debug[5] +%= 1;
        return;
    }
    if (!valid(scope, &input.lease)) {
        clonewars_constructor_observer_debug[1] +%= 1;
        return;
    }
    scope.ready = 1;
}
pub export fn constructor_end_impl(scope: *t.Scope, object: usize) void {
    if (clonewars_constructor_observer_enabled == 0 or scope.ready == 0) return;
    scope.ready = 0;
    const record = &scope.record;
    if (!valid(scope, &record.input.lease)) {
        clonewars_constructor_observer_debug[2] +%= 1;
        return;
    }
    record.returned_local = object;
    context(&record.after);
    obs.timestamp(&record.qpc_after[0], &record.qpc_after[1]);
    if (readable(object, 0x210)) {
        copy(&record.object_raw, object);
        record.valid |= 2;
        record.resource_local = win.load(u32, object + 0x14);
        record.descriptor_local = win.load(u32, object + 0x20c);
        const resource = record.resource_local;
        if (readable(resource, 0x78)) {
            record.resource20 = win.load(u32, resource + 0x20);
            record.resource70 = win.load(u32, resource + 0x70);
            record.resource74 = win.load(u32, resource + 0x74);
            record.valid |= 4;
        }
        const descriptor = record.descriptor_local;
        if (readable(descriptor, 0xa0)) {
            copy(&record.descriptor_raw, descriptor);
            record.descriptor_type = win.load(u8, descriptor + 0x18);
            record.valid |= 8;
            if (record.descriptor_type == 2 and win.load(u32, descriptor + 0x94) == 1) {
                const model = win.load(u32, descriptor + 0x28);
                if (readable(model, 0x34)) {
                    const user = win.load(u32, model + 0x30);
                    if (readable(user, 8) and win.load(u8, user) == 0) {
                        const actor = win.load(u32, user + 4);
                        const observed = if (readable(actor, 0x1440)) api.entities_observed_generation(actor) else 0;
                        if (observed != 0 and win.load(u32, actor + 8) == model and api.entities_allocation_live(actor, observed) != 0 and api.entities_observed_identity(actor, &record.resolved_slot, &record.resolved_generation) != 0) {
                            record.resolved_actor_local = actor;
                            record.valid |= 16;
                        }
                    }
                }
            }
        }
    }
    const wrapper = api.address(0xe9019c);
    if (readable(wrapper, 4)) {
        record.wrapper_local = win.load(u32, wrapper);
        if (readable(record.wrapper_local, 0x48)) {
            record.wrapper40 = win.load(u32, record.wrapper_local + 0x40);
            record.wrapper44 = win.load(u32, record.wrapper_local + 0x44);
            record.valid |= 32;
        }
    }
    const ray = api.address(0xfb9770);
    if (readable(ray, @sizeOf(@TypeOf(record.ray_raw)))) {
        copy(&record.ray_raw, ray);
        record.valid |= 64;
    }
    const category = api.address(0xfb97f1);
    if (readable(category, 1)) {
        record.query_category = win.load(u8, category);
        record.valid |= 128;
    }
    const normal = api.address(0xfb9810);
    if (readable(normal, 12)) {
        copy(&record.query_normal_raw, normal);
        record.valid |= 256;
    }
    if (!valid(scope, &record.input.lease)) {
        clonewars_constructor_observer_debug[3] +%= 1;
        return;
    }
    if (record.valid & 1 != 0) {
        const owner = record.input.owner_local;
        var slot: u32 = 0xffffffff;
        var generation: u32 = 0;
        if (!readable(owner, 0x1440) or api.entities_allocation_live(owner, record.owner_local_generation) == 0 or api.entities_observed_generation(owner) != record.owner_local_generation or win.load(u16, owner + 0xdc0) != record.owner_character or api.entities_observed_identity(owner, &slot, &generation) == 0 or slot != record.owner_slot or generation != record.owner_generation) {
            clonewars_constructor_observer_debug[4] +%= 1;
            return;
        }
    }
    if (!valid(scope, &record.input.lease)) {
        clonewars_constructor_observer_debug[3] +%= 1;
        return;
    }
    record.id = obs.increment(&clonewars_constructor_observer_count);
    obs.publish(&clonewars_constructor_observer_records[(record.id - 1) % 512], record);
}
pub extern fn constructor_observer_begin(*t.Scope, *const t.Call) void;
pub extern fn constructor_observer_end(*t.Scope, usize) void;
pub export fn constructor_observer_install() c_int {
    clonewars_constructor_observer_installed = @intFromBool(api.projectiles_constructor_hooks_ready() != 0);
    return @intCast(clonewars_constructor_observer_installed);
}
comptime {
    asm (@import("observer_bridge_code.zig").code("constructor_observer_begin", "constructor_begin_impl") ++ @import("observer_bridge_code.zig").code("constructor_observer_end", "constructor_end_impl"));
}
