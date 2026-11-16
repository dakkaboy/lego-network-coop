const std = @import("std");
const v = @import("vehicle_rng.zig");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const Binding = @import("rigid_types.zig").Binding;
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var actor: usize = 0;
var component: usize = 0;
var driver: usize = 0;
var body: usize = 0;
var manager: usize = 0;
var mode: u32 = 0;
var retention_calls: u32 = 0;
var input_calls: u32 = 0;
var fault: i32 = 0;
var valid = true;
var captured = std.mem.zeroes(p.SyncPhysicsChoice);
export fn coherent_frame_get(out: *Token, phases: u32) c_int {
    check(@src(), phases == 4);
    out.* = std.mem.zeroes(Token);
    out.epoch = 7;
    out.sequence = 8;
    return @intFromBool(mode != 13);
}
export fn coherent_frame_valid(_: *const Token, _: u32) c_int {
    return @intFromBool(valid);
}
export fn entities_local_generation(_: usize) u32 {
    return 19;
}
export fn entities_allocation_retained(_: usize, generation: u32) c_int {
    check(@src(), generation == 19);
    retention_calls += 1;
    return @intFromBool(mode != 3 and !(mode == 11 and retention_calls > 1));
}
export fn native_actor_rigid_body(_: usize, out: *Binding) c_int {
    out.* = .{ .component = if (mode == 5) actor else component, .driver = driver, .body = body, .dynamics = 0 };
    return @intFromBool(mode != 4);
}
export fn native_actor_rigid_body_same(_: usize, _: *const Binding) c_int {
    return @intFromBool(mode != 10);
}
export fn entities_describe(out: *p.SyncActor, _: usize) void {
    out.* = std.mem.zeroes(p.SyncActor);
    out.spawn_tag = 21;
    out.spawn_source = .{ .producer = 2, .serial = 23 };
}
export fn entities_observed_identity(_: usize, slot: *u32, generation: *u32) c_int {
    slot.* = 3;
    generation.* = 5;
    return 1;
}
export fn physics_vehicle_rng_input(input: *p.SyncPhysicsChoice, _: usize, _: *const Token) c_int {
    input_calls += 1;
    captured = input.*;
    if (mode != 12) input.payload.vehicle_rng.value += 100;
    if (mode == 7) win.store(u32, 0xfb4b6c, 32);
    if (mode == 8) valid = false;
    if (mode == 9) win.store(u32, 0xea178c, 1);
    win.SetLastError(777);
    return @intFromBool(mode != 6);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
const Snapshot = extern struct { debug: [4]u32, correction: [12]u32, failure: [12]u32, clock: u32, seed: u32, calls: u32, retained: u32, fault: i32, input: p.SyncPhysicsChoice };
fn run() Snapshot {
    valid = true;
    retention_calls = 0;
    input_calls = 0;
    fault = 0;
    captured = std.mem.zeroes(p.SyncPhysicsChoice);
    win.store(u32, 0xfb4b6c, 31);
    win.store(u32, 0xea178c, 71);
    win.store(u32, component + 0x60, if (mode == 2) 3 else 4);
    v.clonewars_vehicle_rng_debug = @splat(0);
    v.clonewars_vehicle_rng_correction = @splat(0);
    v.clonewars_vehicle_rng_failure = @splat(0);
    win.SetLastError(1234);
    v.physics_apply_vehicle_rng(component, if (mode == 1) 0x12345678 else 0x997f03);
    check(@src(), win.GetLastError() == 1234);
    var out = std.mem.zeroes(Snapshot);
    out.debug = v.clonewars_vehicle_rng_debug;
    out.correction = v.clonewars_vehicle_rng_correction;
    out.failure = v.clonewars_vehicle_rng_failure;
    out.clock = win.load(u32, 0xfb4b6c);
    out.seed = win.load(u32, 0xea178c);
    out.calls = input_calls;
    out.retained = retention_calls;
    out.fault = fault;
    out.input = captured;
    return out;
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 220 and @intFromPtr(&native_image) < 0x997f03 and @intFromPtr(&native_image) + native_image.len > 0xfbdb40);
    for ([_]*usize{ &actor, &component, &driver, &body, &manager }, 0..) |out, index| {
        out.* = win.VirtualAlloc(0, if (index == 0) 0x2000 else 0x1000, 0x3000, 4);
        check(@src(), out.* != 0);
    }
    defer for ([_]usize{ actor, component, driver, body, manager }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    win.store(usize, component + 0x29c, actor);
    win.store(usize, component + 0x294, driver);
    win.store(usize, driver + 0x260, body);
    win.store(i16, actor + 0xdc0, 321);
    win.store(usize, 0xfbdb3c, manager);
    win.store(u32, manager + 0x15c, 1);
    win.store(usize, manager + 0x160, component);
    const expected = [_]u32{ 1519178640, 2242678103, 2761207308, 2269857333, 2269857333, 2269857333, 3412641363, 2367379239, 2930807976, 366954954, 3363934316, 3363934316, 840227634, 335046301 };
    for (expected, 0..) |hash, index| {
        mode = @intCast(index);
        var actual = run();
        if (mode == 0) check(@src(), actual.seed == 171 and actual.debug[1] == 1);
        for ([_]usize{ 5, 6, 9, 10 }, [_]usize{ component, actor, driver, body }) |field, pointer| if (actual.failure[field] != 0) {
            check(@src(), actual.failure[field] == pointer);
            actual.failure[field] = @intCast(0x1000 + field);
        };
        var result: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| result = (result ^ byte) *% 16777619;
        check(@src(), result == hash);
    }
    const sites = [_]usize{ 0x997f03, 0x997f14, 0x997f25, 0x99803e, 0x998085, 0x9980b4, 0x99813e, 0x9981cf, 0x998288, 0x9982b7, 0x9982ee };
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(0x997000, 0x2000, 0x40, &old) != 0);
    for (sites) |site| {
        win.store(u8, site, 0xe8);
        win.store(u32, site + 1, @as(u32, if (site == 0x9981cf) 0x573160 else 0x573100) -% site -% 5);
    }
    win.store(u8, sites[3], 0x90);
    check(@src(), v.vehicle_rng_input_install() == 0);
    win.store(u8, sites[3], 0xe8);
    check(@src(), v.vehicle_rng_input_install() != 0 and v.vehicle_rng_input_install() != 0 and v.clonewars_vehicle_rng_debug[2] == 1);
}
