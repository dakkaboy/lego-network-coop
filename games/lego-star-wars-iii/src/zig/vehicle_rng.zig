const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const Binding = @import("rigid_types.zig").Binding;
const vehicleSite = @import("physics_validation.zig").vehicleSite;
pub export var clonewars_vehicle_rng_debug: [4]u32 = @splat(0);
pub export var clonewars_vehicle_rng_correction: [12]u32 = @splat(0);
pub export var clonewars_vehicle_rng_failure: [12]u32 = @splat(0);
export var vehicle_rng_float_native: usize = 0x573100;
export var vehicle_rng_integer_native: usize = 0x573160;
var installed = false;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn entities_local_generation(usize) u32;
extern fn entities_allocation_retained(usize, u32) c_int;
extern fn native_actor_rigid_body(usize, *Binding) c_int;
extern fn native_actor_rigid_body_same(usize, *const Binding) c_int;
extern fn entities_describe(*p.SyncActor, usize) void;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn physics_vehicle_rng_input(*p.SyncPhysicsChoice, usize, *const Token) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn vehicle_rng_float_thunk() void;
extern fn vehicle_rng_integer_thunk() void;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn readable(address: usize, length: usize) bool {
    return length != 0 and win.accessible(address, length, false);
}
fn reject(token: *const Token, component: usize, site: u32, reason: u32) void {
    if (coherent_frame_valid(token, 4) == 0) return;
    clonewars_vehicle_rng_debug[3] +%= 1;
    if (clonewars_vehicle_rng_failure[2] == 0) {
        const values = [_]u32{ token.epoch, token.sequence, reason, read(u32, 0xfb4b6c), site, @truncate(component) };
        @memcpy(clonewars_vehicle_rng_failure[0..6], &values);
    }
    game_sync_native_fault(15);
}
pub export fn physics_apply_vehicle_rng(component: usize, site: u32) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var token = std.mem.zeroes(Token);
    if (coherent_frame_get(&token, 4) == 0) return;
    if (!vehicleSite(site) or !readable(component, 0x2a0) or read(u32, component + 0x60) != 4) {
        reject(&token, component, site, 1);
        return;
    }
    const actor = read(usize, component + 0x29c);
    const generation = entities_local_generation(actor);
    var source = std.mem.zeroes(Binding);
    if (entities_allocation_retained(actor, generation) == 0 or native_actor_rigid_body(actor, &source) == 0 or source.component != component) {
        if (clonewars_vehicle_rng_failure[2] == 0) {
            const driver = read(usize, component + 0x294);
            const body = if (readable(driver, 0x264)) read(usize, driver + 0x260) else 0;
            const manager = read(usize, 0xfbdb3c);
            var registered: u32 = 0;
            if (readable(manager, 0x160)) {
                const count = read(u32, manager + 0x15c);
                if (count <= p.SYNC_MAX_ACTORS and readable(manager + 0x160, count * 4)) {
                    for (0..count) |i| if (read(usize, manager + 0x160 + i * 4) == component) {
                        registered = 1;
                    };
                }
            }
            const values = [_]u32{ @truncate(actor), generation, if (readable(actor, 0x54)) read(u32, actor + 0x50) else 0, @truncate(driver), @truncate(body), registered };
            @memcpy(clonewars_vehicle_rng_failure[6..12], &values);
        }
        reject(&token, component, site, 2);
        return;
    }
    var identity = std.mem.zeroes(p.SyncActor);
    entities_describe(&identity, actor);
    var input = std.mem.zeroes(p.SyncPhysicsChoice);
    input.kind = p.SYNC_PHYSICS_VEHICLE_RNG;
    input.site = site;
    const value = &input.payload.vehicle_rng;
    value.clock = read(u32, 0xfb4b6c);
    value.value = read(u32, 0xea178c);
    value.slot = 0xffffffff;
    _ = entities_observed_identity(actor, &value.slot, &value.generation);
    value.character = read(i16, actor + 0xdc0);
    value.spawn_tag = identity.spawn_tag;
    value.spawn_source = identity.spawn_source;
    value.vehicle_type = 4;
    const seed = value.value;
    if (coherent_frame_valid(&token, 4) == 0 or physics_vehicle_rng_input(&input, actor, &token) != 1 or coherent_frame_valid(&token, 4) == 0 or read(u32, 0xfb4b6c) != value.clock or entities_allocation_retained(actor, generation) == 0 or native_actor_rigid_body_same(actor, &source) == 0 or read(u32, 0xea178c) != seed) {
        reject(&token, component, site, 3);
        return;
    }
    win.store(u32, 0xea178c, value.value);
    clonewars_vehicle_rng_debug[0] +%= 1;
    if (seed != value.value) {
        clonewars_vehicle_rng_debug[1] +%= 1;
        if (clonewars_vehicle_rng_correction[0] == 0) {
            const values = [_]u32{ token.epoch, token.sequence, value.clock, site, value.slot, value.generation, @bitCast(value.character), value.spawn_tag, value.spawn_source.producer, value.spawn_source.serial, seed, value.value };
            @memcpy(&clonewars_vehicle_rng_correction, &values);
        }
    }
}
const sites = [_]usize{ 0x997f03, 0x997f14, 0x997f25, 0x99803e, 0x998085, 0x9980b4, 0x99813e, 0x9981cf, 0x998288, 0x9982b7, 0x9982ee };
pub export fn vehicle_rng_input_install() c_int {
    if (installed) return 1;
    for (sites) |site| {
        const target: usize = if (site == 0x9981cf) 0x573160 else 0x573100;
        if (!readable(site, 5) or read(u8, site) != 0xe8 or site +% 5 +% read(u32, site + 1) != target) return 0;
    }
    for (sites) |site| {
        var old: u32 = 0;
        if (win.VirtualProtect(site, 5, 0x40, &old) == 0) return 0;
        const target = if (site == 0x9981cf) @intFromPtr(&vehicle_rng_integer_thunk) else @intFromPtr(&vehicle_rng_float_thunk);
        win.store(u32, site + 1, @truncate(target -% site -% 5));
        const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), site, 5) != 0;
        var ignored: u32 = 0;
        if (win.VirtualProtect(site, 5, old, &ignored) == 0 or !flushed) return 0;
    }
    installed = true;
    clonewars_vehicle_rng_debug[2] = 1;
    return 1;
}
comptime {
    _ = @import("vehicle_rng_bridge.zig");
}
