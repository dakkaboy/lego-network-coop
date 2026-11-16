const std = @import("std");
const win = @import("win32.zig");
const t = @import("constructor_types.zig");
const observer = @import("constructor_observer.zig");
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
var alive = true;
var hooks_ready = true;
var allocation: u32 = 13;
var generation: u32 = 11;
var checks: u32 = 0;
var cancel_at: u32 = 0;
var actor: [0x1440]u8 align(16) = @splat(0);
var object: [0x210]u8 align(16) = @splat(0);
var resource: [0x78]u8 align(16) = @splat(0);
var descriptor: [0xa0]u8 align(16) = @splat(0);
var model: [0x34]u8 align(16) = @splat(0);
var user: [8]u8 align(16) = @splat(0);
var wrapper: [0x48]u8 align(16) = @splat(0);
var wrapper_pointer: usize = 0;
var ray: [32]u32 = @splat(0x1234);
var normal: [3]u32 = .{ 1, 2, 3 };
var category: u8 = 7;
var clock: u32 = 43;
pub const constructor_test_api = struct {
    pub fn readable(pointer: usize, bytes: usize, write: bool) bool {
        return win.accessible(pointer, bytes, write);
    }
    pub fn address(raw: usize) usize {
        return switch (raw) {
            0xe9019c => @intFromPtr(&wrapper_pointer),
            0xfb9770 => @intFromPtr(&ray),
            0xfb97f1 => @intFromPtr(&category),
            0xfb9810 => @intFromPtr(&normal),
            0xfb4b6c, 0xe637b4, 0xea178c, 0xfb4b74 => @intFromPtr(&clock),
            else => 0,
        };
    }
    fn valid() c_int {
        checks += 1;
        win.SetLastError(919);
        return @intFromBool(alive and checks != cancel_at);
    }
    pub fn projectiles_constructor_cohort_valid(_: *const t.Lease, _: *const @import("cohort_types.zig").Token) c_int {
        return valid();
    }
    pub fn projectiles_constructor_control_valid(_: *const t.Lease, _: *const @import("projectile_types.zig").ControlLease, _: *const @import("projectile_types.zig").Session, _: u64) c_int {
        return valid();
    }
    pub fn projectiles_constructor_hooks_ready() c_int {
        return @intFromBool(hooks_ready);
    }
    pub fn entities_observed_generation(_: usize) u32 {
        return allocation;
    }
    pub fn entities_allocation_live(_: usize, value: u32) c_int {
        return @intFromBool(value == 13 and allocation == 13);
    }
    pub fn entities_observed_identity(_: usize, slot: *u32, out: *u32) c_int {
        slot.* = 7;
        out.* = generation;
        return 1;
    }
};
fn currentCw() u16 {
    var value: u16 = 0;
    asm volatile ("fnstcw (%[out])"
        :
        : [out] "r" (&value),
        : .{ .memory = true });
    return value;
}
pub fn main() void {
    hooks_ready = false;
    check(@src(), observer.constructor_observer_install() == 0);
    hooks_ready = true;
    check(@src(), observer.constructor_observer_install() == 1);
    observer.clonewars_constructor_observer_enabled = 1;
    var birth = std.mem.zeroes(@import("protocol.zig").SyncShot);
    birth.id = 19;
    birth.owner = 7;
    birth.owner_generation = 11;
    var origin: [3]f32 = .{ 1, 2, 3 };
    var transform: [16]f32 = @splat(4);
    var weapon: i8 = -2;
    var call = std.mem.zeroes(t.Call);
    call.birth = @intFromPtr(&birth);
    call.origin = @intFromPtr(&origin);
    call.transform = @intFromPtr(&transform);
    call.weapon = @intFromPtr(&weapon);
    call.owner = @intFromPtr(&actor);
    call.capability = t.frame;
    win.store(u16, @intFromPtr(&actor) + 0xdc0, 23);
    win.store(usize, @intFromPtr(&actor) + 8, @intFromPtr(&model));
    win.store(usize, @intFromPtr(&model) + 0x30, @intFromPtr(&user));
    win.store(usize, @intFromPtr(&user) + 4, @intFromPtr(&actor));
    win.store(usize, @intFromPtr(&object) + 0x14, @intFromPtr(&resource));
    win.store(usize, @intFromPtr(&object) + 0x20c, @intFromPtr(&descriptor));
    win.store(u8, @intFromPtr(&descriptor) + 0x18, 2);
    win.store(u32, @intFromPtr(&descriptor) + 0x94, 1);
    win.store(usize, @intFromPtr(&descriptor) + 0x28, @intFromPtr(&model));
    wrapper_pointer = @intFromPtr(&wrapper);
    var scope = std.mem.zeroes(t.Scope);
    const cw = currentCw();
    win.SetLastError(711);
    observer.constructor_observer_begin(&scope, &call);
    check(@src(), scope.ready == 1 and currentCw() == cw and win.GetLastError() == 711);
    observer.constructor_observer_end(&scope, @intFromPtr(&object));
    check(@src(), scope.ready == 0 and observer.clonewars_constructor_observer_count == 1 and currentCw() == cw and win.GetLastError() == 711);
    const first = &observer.clonewars_constructor_observer_records[0];
    check(@src(), first.committed == 1 and first.valid == 511 and first.input.birth_known == 1 and first.input.birth.id == 19 and first.input.input_valid == 7 and first.input.weapon == 0xfffffffe);
    check(@src(), first.owner_slot == 7 and first.owner_generation == 11 and first.owner_local_generation == 13 and first.resolved_actor_local == @intFromPtr(&actor) and first.resolved_slot == 7);
    check(@src(), first.ray_raw[31] == 0x1234 and first.query_category == 7 and first.query_normal_raw[2] == 3 and first.before[0] == 43);
    observer.constructor_observer_end(&scope, @intFromPtr(&object));
    check(@src(), observer.clonewars_constructor_observer_count == 1);
    for (1..6) |position| {
        checks = 0;
        cancel_at = @intCast(position);
        observer.constructor_observer_begin(&scope, &call);
        observer.constructor_observer_end(&scope, @intFromPtr(&object));
        check(@src(), observer.clonewars_constructor_observer_count == 1);
    }
    cancel_at = 0;
    observer.constructor_observer_begin(&scope, &call);
    allocation = 14;
    observer.constructor_observer_end(&scope, @intFromPtr(&object));
    check(@src(), observer.clonewars_constructor_observer_count == 1);
    allocation = 13;
    observer.constructor_observer_begin(&scope, &call);
    generation = 12;
    observer.constructor_observer_end(&scope, @intFromPtr(&object));
    check(@src(), observer.clonewars_constructor_observer_count == 1);
    generation = 11;
    birth.owner_generation = 12;
    observer.constructor_observer_begin(&scope, &call);
    check(@src(), scope.ready == 0);
    birth.owner_generation = 11;
    call.capability = t.rejected;
    observer.constructor_observer_begin(&scope, &call);
    check(@src(), scope.ready == 0);
    call.capability = t.control;
    observer.constructor_observer_begin(&scope, &call);
    check(@src(), scope.ready == 1 and scope.record.input.birth_known == 0);
    observer.constructor_observer_end(&scope, 0);
    check(@src(), observer.clonewars_constructor_observer_count == 2 and observer.clonewars_constructor_observer_records[1].returned_local == 0);
    alive = false;
    observer.constructor_observer_begin(&scope, &call);
    check(@src(), scope.ready == 0);
}
