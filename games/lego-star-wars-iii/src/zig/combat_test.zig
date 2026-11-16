const std = @import("std");
const c = @import("combat.zig");
const t = @import("combat_types.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
extern "kernel32" fn SetEnvironmentVariableA([*:0]const u8, [*:0]const u8) callconv(.winapi) c_int;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
export var clonewars_spawn_observer_enabled: i32 = 0;
comptime {
    _ = @import("lexical_seh.zig");
}
const pool: usize = 0x20000000;
const shot: usize = 0x20010000;
const resource: usize = 0x20020000;
const flow: usize = 0x20030000;
const area: usize = 0x20040000;
const definition: usize = 0x20050000;
const engine: usize = 0x20060000;
const packet: usize = 0x20070000;
const dispatcher: usize = 0x20080000;
const descriptor: usize = 0x20090000;
const heading: usize = 0x200a0000;
const Hit = *const fn (u32, u32, u32, u32, u32, u32) callconv(.c) u32;
const Death = *const fn (u32, u32, u32, u32, u32, u32) callconv(.c) void;
var hit: Hit = undefined;
var death: Death = undefined;
var continuation: Hit = undefined;
var throwing = false;
var mode: u32 = 0;
var calls: u32 = 0;
var begins: u32 = 0;
var completes: u32 = 0;
var depth: u32 = 0;
var observed_source: u32 = 0;
var observed_caller: u32 = 0;
export fn game_sync_sequence() u32 {
    return 8;
}
export fn entities_observed_generation(_: usize) u32 {
    return 7;
}
export fn entities_observed_identity(actor: usize, slot: *u32, generation: *u32) c_int {
    slot.* = @intFromBool(actor != pool);
    generation.* = 9;
    return @intFromBool(actor != 0);
}
export fn lan_session_serial() u32 {
    return 3;
}
export fn coherent_frame_valid(_: *const Token, phase: u32) c_int {
    check(@src(), phase == 4);
    return 1;
}
export fn projectiles_observe_live(object: usize, out: *@import("collision_types.zig").Identity) c_int {
    out.* = std.mem.zeroes(@import("collision_types.zig").Identity);
    out.status = if (object == 0) 0 else if (mode == 2) 2 else 1;
    out.id = if (mode == 6 and calls != 0) 23 else 17;
    out.owner = 2;
    out.weapon = 4;
    out.owner_generation = 9;
    out.resource_local = resource;
    out.instance_serial = 19;
    out.creation_count = 29;
    return 1;
}
export fn reaction_client_duplicate_projectile(actor: usize, id: u32) c_int {
    check(@src(), actor == pool + 0x1440 and id == 17);
    return @intFromBool(mode == 17);
}
export fn reaction_damage_begin(receipt: *t.Receipt, actor: usize, id: u32) void {
    check(@src(), actor == pool + 0x1440 and id == (if (mode == 2) @as(u32, 0) else 17));
    receipt.* = std.mem.zeroes(t.Receipt);
    receipt.source_id = id;
    begins += 1;
}
export fn reaction_damage_complete(receipt: *const t.Receipt) void {
    check(@src(), receipt.source_id == (if (mode == 2) @as(u32, 0) else 17));
    completes += 1;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn nativeHit(a0: u32, a1: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) u32 {
    check(@src(), a0 == pool and a1 == pool + 0x1440);
    calls += 1;
    observed_source = c.combat_damage_source_id();
    observed_caller = c.combat_damage_native_caller();
    check(@src(), observed_source == (if (mode == 2) @as(u32, 0) else 17));
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    if (mode == 7 and depth == 0) {
        depth += 1;
        _ = callHit();
        depth -= 1;
    }
    if (mode == 8) {
        put(0xfbcb2c, 0);
        var scope = std.mem.zeroes(t.Scope);
        check(@src(), c.combat_observer_remove_begin(&scope, dispatcher, 0, 3, 1, 0x884e5c) != 0);
        c.combat_observer_remove_end(&scope, 1);
        put(0xfbcb2c, shot);
    }
    win.SetLastError(321);
    return 71;
}
fn nativeDeath(_: u32, _: u32, _: u32, _: u32, _: u32, _: u32) callconv(.c) void {
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    win.SetLastError(321);
}
fn nativeGlobal(d: usize, value: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), d == dispatcher and value == packet);
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    c.combat_observer_projectile_created();
    c.combat_observer_fire_requested();
    if (mode == 12 and depth == 0) {
        depth += 1;
        c.combat_observer_dispatch(d, value);
        depth -= 1;
    }
    put(packet + 8, 99);
    win.SetLastError(321);
}
fn interposer(a: u32, b: u32, d: u32, e: u32, f: u32, g: u32) callconv(.c) u32 {
    return continuation(a, b, d, e, f, g);
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn caller(address: usize, target: usize) void {
    for (0..6) |i| @memcpy(bytes(address + i * 4, 4), &[_]u8{ 0xff, 0x74, 0x24, 0x18 });
    win.store(u8, address + 24, 0xe8);
    put(address + 25, target -% address -% 29);
    @memcpy(bytes(address + 29, 4), &[_]u8{ 0x83, 0xc4, 0x18, 0xc3 });
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 33) != 0);
}
fn callHit() u32 {
    caller(0x700000, @intFromPtr(hit));
    return @as(Hit, @ptrFromInt(0x700000))(pool, pool + 0x1440, 1, 0, 0, 1);
}
fn setup() void {
    calls = 0;
    begins = 0;
    completes = 0;
    depth = 0;
    observed_source = 0;
    observed_caller = 0;
    @memset(bytes(pool, 0x4000), 0);
    win.store(u16, pool + 0xdc0, 321);
    win.store(u16, pool + 0x1440 + 0xdc0, 33);
    put(0xfb2f60, pool);
    put(0xfb2e3c, 2);
    put(0xfbcb2c, shot);
    put(shot + 0x14, if (mode == 3) 1 else resource);
    put(0xfb2e60, flow);
    put(flow + 0x1b78, 14);
    put(0xfb4a20, area);
    put(area + 0x220, definition);
    win.store(u16, definition + 0x94, 9);
    put(0xfb0afc, engine);
    put(engine + 0xe0c, 73);
    put(packet, if (mode == 11) 1 else 0xc37cfc);
    put(packet + 8, 79);
    put(0xfb4b6c, 31);
    put(0xe637b4, 71);
    put(0xea178c, 79);
    put(descriptor + 28, heading);
    win.store(u16, heading, 123);
}
const Snapshot = extern struct { count: u32, global_count: u32, calls: u32, begins: u32, completes: u32, source: u32, caller: u32, debug: [14]u32, records: [4]t.Record, globals: [2]t.Global };
fn normalizeThread(value: *u32) void {
    if (value.* != 0) {
        check(@src(), value.* == win.GetCurrentThreadId());
        value.* = 0;
    }
}
fn run() Snapshot {
    setup();
    caller(0x700100, @intFromPtr(death));
    c.clonewars_combat_observer_count = 0;
    c.clonewars_global_observer_count = 0;
    @memset(std.mem.sliceAsBytes(c.clonewars_combat_observer[0..4]), 0);
    @memset(std.mem.sliceAsBytes(c.clonewars_global_observer[0..2]), 0);
    c.clonewars_global_observer_debug = @splat(0);
    c.clonewars_combat_observer_enabled = @intFromBool(mode != 0);
    c.combat_observer_flow(0);
    if (mode == 4) c.combat_observer_flow(1);
    if (mode == 5) c.combat_observer_frame_queued(7, 8);
    if (mode < 9) {
        _ = callHit();
    } else if (mode < 13) {
        c.combat_observer_dispatch(dispatcher, packet);
    } else if (mode == 13) {
        @as(Death, @ptrFromInt(0x700100))(pool, 0, pool + 0x1440, 0, descriptor, 0);
    } else if (mode < 17) {
        var outer = std.mem.zeroes(t.Scope);
        var inner = std.mem.zeroes(t.Scope);
        check(@src(), c.combat_observer_remove_begin(&outer, dispatcher, shot, 3, 1, 19) != 0);
        if (mode == 15) {
            check(@src(), c.combat_observer_remove_begin(&inner, dispatcher, shot, 4, 1, 23) != 0);
            c.combat_observer_remove_abort(&inner);
        }
        c.combat_observer_remove_end(&outer, @intFromBool(mode == 14));
    } else {
        caller(0x884e3f, @intFromPtr(hit));
        _ = @as(Hit, @ptrFromInt(0x884e3f))(pool, pool + 0x1440, 1, 0, 0, 1);
    }
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    out.count = c.clonewars_combat_observer_count;
    out.global_count = c.clonewars_global_observer_count;
    out.calls = calls;
    out.begins = begins;
    out.completes = completes;
    out.source = observed_source;
    out.caller = observed_caller;
    check(@src(), out.count <= 4 and out.global_count <= 2);
    out.records = c.clonewars_combat_observer[0..4].*;
    out.globals = c.clonewars_global_observer[0..2].*;
    out.debug = c.clonewars_global_observer_debug;
    for (&out.records) |*r| {
        normalizeThread(&r.thread);
        normalizeThread(&r.tick_thread);
        r.qpc_before_low = 0;
        r.qpc_before_high = 0;
        r.qpc_after_low = 0;
        r.qpc_after_high = 0;
        r.tick_enter_low = 0;
        r.tick_enter_high = 0;
        r.tick_leave_low = 0;
        r.tick_leave_high = 0;
        r.frame_queued_low = 0;
        r.frame_queued_high = 0;
    }
    for (&out.globals) |*r| {
        r.enter_low = 0;
        r.enter_high = 0;
        r.leave_low = 0;
        r.leave_high = 0;
        normalizeThread(&r.thread);
    }
    normalizeThread(&out.debug[5]);
    return out;
}
fn invokeThrow(global: usize) callconv(.c) c_int {
    if (global != 0) c.combat_observer_dispatch(dispatcher, packet) else _ = callHit();
    return 1;
}
fn protect(address: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 0x10000, 0x40, &old) != 0);
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 2756 and @intFromPtr(&image) < 0x700000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for (0..11) |i| {
        const a = pool + i * 0x10000;
        check(@src(), win.VirtualAlloc(a, if (i == 0) 0x4000 else if (i == 3) 0x3000 else 0x1000, 0x3000, 4) == a);
    }
    defer {
        for (0..11) |i| check(@src(), win.VirtualFree(pool + i * 0x10000, 0, 0x8000) != 0);
    }
    for ([_]usize{ 0x700000, 0x760000, 0x880000, 0x960000, 0xfb0000, 0xe60000, 0xea0000 }) |a| protect(a);
    check(@src(), SetEnvironmentVariableA("CLONEWARS_ARENA_CONTACT_TRACE", "0") != 0);
    jump(0x760d80, @intFromPtr(&nativeGlobal));
    @memcpy(bytes(0x96a4c0, 6), &[_]u8{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 });
    @memcpy(bytes(0x96a4c6, 3), &[_]u8{ 0x89, 0xec, 0x5d });
    jump(0x96a4c9, @intFromPtr(&nativeHit));
    @memcpy(bytes(0x968d60, 6), &[_]u8{ 0x81, 0xec, 0x80, 0, 0, 0 });
    @memcpy(bytes(0x968d66, 6), &[_]u8{ 0x81, 0xc4, 0x80, 0, 0, 0 });
    jump(0x968d6c, @intFromPtr(&nativeDeath));
    check(@src(), c.combat_observer_install() != 0);
    hit = @ptrFromInt(0x96a4c5 +% win.load(u32, 0x96a4c1));
    death = @ptrFromInt(0x968d65 +% win.load(u32, 0x968d61));
    check(@src(), c.combat_damage_source_ready() != 0);
    const expected = [_]u32{ 2379352728, 1063889564, 1385064487, 683100105, 1763438837, 2128659540, 317557042, 1350154642, 2423601907, 4199146274, 4199146274, 2761506009, 3839906701, 1864065699, 1016164792, 2190317517, 3044850126, 965628949 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        const out = run();
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("combat mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
    }
    mode = 1;
    setup();
    c.clonewars_combat_observer_enabled = 1;
    throwing = true;
    check(@src(), support.exceptionCode(0, invokeThrow) == 0xe1459876 and c.combat_damage_source_id() == 0);
    check(@src(), support.exceptionCode(1, invokeThrow) == 0xe1459876);
    throwing = false;
    @memset(bytes(0x96a410, 0xb0), 0x90);
    @memcpy(bytes(0x96a410, 5), "\x83\xec\x30\x53\x56");
    for (0..6) |i| @memcpy(bytes(0x96a415 + i * 4, 4), "\xff\x74\x24\x50");
    win.store(u8, 0x96a4b0, 0xe8);
    put(0x96a4b1, @intFromPtr(death) -% 0x96a4b5);
    @memcpy(bytes(0x96a4b5, 9), "\x83\xc4\x18\x5e\x5b\x83\xc4\x30\xc3");
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x96a410, 0xb0) != 0);
    caller(0x700200, 0x96a410);
    @as(Death, @ptrFromInt(0x700200))(pool, 3, 0, 1, descriptor, 0);
    check(@src(), c.clonewars_death_caller_debug[0] != 0 and c.clonewars_death_caller_debug[1] == 0x70021d and c.clonewars_death_caller_debug[2] == 0x96a4b5);
    _ = callHit();
    check(@src(), c.clonewars_combat_observer[(c.clonewars_combat_observer_count - 1) % 4096].parent == 0);
    c.combat_observer_dispatch(dispatcher, packet);
    check(@src(), c.clonewars_global_observer[(c.clonewars_global_observer_count - 1) % 512].parent == 0);
    setup();
    jump(0x96a4c0, @intFromPtr(hit));
    var token = std.mem.zeroes(Token);
    token.thread = win.GetCurrentThreadId();
    var target: usize = 0;
    check(@src(), c.combat_hit_bridge_attach(null, @intFromPtr(&interposer), &target) == 0);
    token.thread += 1;
    check(@src(), c.combat_hit_bridge_attach(&token, @intFromPtr(&interposer), &target) == 0);
    token.thread -= 1;
    check(@src(), c.combat_hit_bridge_attach(&token, @intFromPtr(&interposer), &target) != 0 and target != 0);
    continuation = @ptrFromInt(target);
    check(@src(), c.combat_hit_bridge_attach(&token, @intFromPtr(&interposer), &target) != 0);
    check(@src(), c.combat_hit_bridge_attach(&token, @intFromPtr(&nativeHit), &target) == 0);
    check(@src(), callHit() == 71);
}
