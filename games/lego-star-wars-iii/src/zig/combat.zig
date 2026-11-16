const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const snapshot = @import("combat_snapshot.zig");
const t = @import("combat_types.zig");
const Identity = @import("collision_types.zig").Identity;
const Token = @import("cohort_types.zig").Token;
const Machine = @import("machine_environment.zig").Environment;
const Hit = *const fn (u32, u32, u32, u32, u32, u32) callconv(.c) u32;
const Death = *const fn (u32, u32, u32, u32, u32, u32) callconv(.c) void;
const GlobalUpdate = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
var original_hit: Hit = undefined;
var original_death: Death = undefined;
var original_global: GlobalUpdate = @ptrFromInt(0x760d80);
var native_hit_bridge: usize = 0;
var hit_interposer: usize = 0;
var install_state: i32 = 0;
threadlocal var global_depth: u32 = 0;
threadlocal var active_global: u32 = 0;
threadlocal var active_scope: ?*t.Scope = null;
threadlocal var flow_active: i32 = 0;
threadlocal var ticks: [12]u32 = @splat(0);
const Cause = struct { previous: ?*Cause, id: u32, status: u32, caller: u32 };
threadlocal var active_damage: ?*Cause = null;
pub export var clonewars_global_observer_installed: i32 = 0;
pub export var clonewars_global_observer_count: u32 = 0;
pub export var clonewars_global_observer_stride: u32 = @sizeOf(t.Global);
pub export var clonewars_global_observer_capacity: u32 = 512;
pub export var clonewars_global_observer_debug: [14]u32 = @splat(0);
pub export var clonewars_global_observer: [512]t.Global = std.mem.zeroes([512]t.Global);
pub export var clonewars_combat_observer_enabled: i32 = 0;
pub export var clonewars_combat_observer_installed: i32 = 0;
pub export var clonewars_combat_observer_count: u32 = 0;
pub export var clonewars_combat_observer_stride: u32 = @sizeOf(t.Record);
pub export var clonewars_combat_observer_capacity: u32 = 4096;
pub export var clonewars_combat_observer_install_thread: u32 = 0;
pub export var clonewars_combat_observer: [4096]t.Record = std.mem.zeroes([4096]t.Record);
pub export var clonewars_death_caller_debug: [8]u32 = @splat(0);
pub export var clonewars_arena_contact_count: u32 = 0;
pub export var clonewars_arena_contact: [8192][4]u32 = std.mem.zeroes([8192][4]u32);
export var arena_contact_resume: usize = 0x410cdc;
extern var clonewars_spawn_observer_enabled: i32;
extern fn game_sync_sequence() u32;
extern fn projectiles_observe_live(usize, *Identity) c_int;
extern fn reaction_client_duplicate_projectile(usize, u32) c_int;
extern fn reaction_damage_begin(*t.Receipt, usize, u32) void;
extern fn reaction_damage_complete(*const t.Receipt) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn lan_session_serial() u32;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern fn arena_contact_tap() void;
pub export fn combat_observer_projectile_created() void {
    if (clonewars_combat_observer_enabled == 0) return;
    _ = obs.increment(&clonewars_global_observer_debug[if (global_depth != 0) 1 else 2]);
    _ = obs.increment(&clonewars_global_observer_debug[if (flow_active != 0) 12 else 13]);
    if (global_depth == 0) clonewars_global_observer_debug[5] = win.GetCurrentThreadId();
}
pub export fn combat_observer_fire_requested() void {
    if (clonewars_combat_observer_enabled == 0) return;
    _ = obs.increment(&clonewars_global_observer_debug[if (global_depth != 0) 8 else 9]);
    _ = obs.increment(&clonewars_global_observer_debug[if (flow_active != 0) 10 else 11]);
    if (global_depth == 0) clonewars_global_observer_debug[5] = win.GetCurrentThreadId();
}
const GlobalScope = struct { machine: Machine, record: t.Global, previous: u32 };
fn globalAbort(address: usize) callconv(.c) void {
    const s: *GlobalScope = @ptrFromInt(address);
    global_depth -%= 1;
    active_global = s.previous;
}
fn globalInvoke(address: usize) callconv(.c) usize {
    const s: *GlobalScope = @ptrFromInt(address);
    const r = &s.record;
    active_global = r.id;
    global_depth +%= 1;
    if (global_depth > clonewars_global_observer_debug[6]) clonewars_global_observer_debug[6] = global_depth;
    obs.timestamp(&r.enter_low, &r.enter_high);
    s.machine.restore();
    original_global(r.dispatcher_local, r.packet_local);
    s.machine.capture();
    obs.timestamp(&r.leave_low, &r.leave_high);
    global_depth -%= 1;
    active_global = s.previous;
    r.packet_delta_after = obs.word(r.packet_local +% 8);
    r.engine_delta_after = if (r.engine_root_local != 0) obs.word(r.engine_root_local +% 0xe0c) else 0;
    r.sequence_after = game_sync_sequence();
    r.clock_after = obs.word(0xfb4b6c);
    r.level_after = snapshot.level();
    r.phase_after = snapshot.phase();
    r.births_after = clonewars_global_observer_debug[1];
    r.hits_after = clonewars_global_observer_debug[3];
    obs.publish(&clonewars_global_observer[(r.id -% 1) % 512], r);
    _ = obs.increment(&clonewars_global_observer_debug[0]);
    return 0;
}
pub export fn combat_observer_dispatch(dispatcher: usize, packet: usize) void {
    if (clonewars_combat_observer_enabled == 0 and clonewars_spawn_observer_enabled == 0) {
        original_global(dispatcher, packet);
        return;
    }
    var s: GlobalScope = undefined;
    s.machine.capture();
    s.record = std.mem.zeroes(t.Global);
    s.previous = active_global;
    const r = &s.record;
    r.id = obs.increment(&clonewars_global_observer_count);
    r.parent = active_global;
    r.thread = win.GetCurrentThreadId();
    r.dispatcher_local = @truncate(dispatcher);
    r.packet_local = @truncate(packet);
    r.packet_vtable = obs.word(packet);
    r.packet_zero = obs.word(packet +% 4);
    r.packet_delta_before = obs.word(packet +% 8);
    r.packet_mode = obs.word(packet +% 0xc);
    r.engine_root_local = obs.word(0xfb0afc);
    r.engine_delta_before = if (r.engine_root_local != 0) obs.word(r.engine_root_local +% 0xe0c) else 0;
    r.sequence_before = game_sync_sequence();
    r.clock_before = obs.word(0xfb4b6c);
    r.level_before = snapshot.level();
    r.phase_before = snapshot.phase();
    r.births_before = clonewars_global_observer_debug[1];
    r.hits_before = clonewars_global_observer_debug[3];
    if (r.packet_vtable != 0xc37cfc or r.packet_zero != 0) _ = obs.increment(&clonewars_global_observer_debug[7]);
    _ = constructor_lexical_seh(@intFromPtr(&s), globalInvoke, globalAbort);
    s.machine.restore();
}
fn clockBefore(r: *t.Record) void {
    obs.timestamp(&r.qpc_before_low, &r.qpc_before_high);
    r.clock = obs.word(0xfb4b6c);
    r.rng_game = obs.word(0xe637b4);
    r.rng_engine = obs.word(0xea178c);
    r.native_level = snapshot.level();
    r.native_phase = snapshot.phase();
    r.tick_enter_low = ticks[0];
    r.tick_enter_high = ticks[1];
    r.tick_leave_low = ticks[2];
    r.tick_leave_high = ticks[3];
    r.tick_sequence = ticks[4];
    r.tick_clock_enter = ticks[5];
    r.tick_clock_leave = ticks[6];
    r.tick_thread = ticks[7];
    r.frame_queued_low = ticks[8];
    r.frame_queued_high = ticks[9];
    r.frame_queued_epoch = ticks[10];
    r.frame_queued_sequence = ticks[11];
}
fn begin(scope: *t.Scope, kind: u32, caller: u32, args: [6]u32) void {
    scope.* = .{ .record = std.mem.zeroes(t.Record), .previous = active_scope };
    const r = &scope.record;
    r.id = obs.increment(&clonewars_combat_observer_count);
    if (kind == 1) {
        _ = obs.increment(&clonewars_global_observer_debug[if (global_depth != 0) 3 else 4]);
        if (global_depth == 0) clonewars_global_observer_debug[5] = win.GetCurrentThreadId();
    }
    r.parent = if (active_scope) |s| s.record.id else 0;
    r.kind = kind;
    r.caller = caller;
    r.thread = win.GetCurrentThreadId();
    r.phase = @intFromBool(flow_active == 0);
    r.arguments = args;
    clockBefore(r);
    if (kind != 3) {
        snapshot.actor(&r.before[0], if (kind == 1) args[0] else args[2]);
        snapshot.actor(&r.before[1], if (kind == 1) args[1] else args[0]);
    }
    var object = if (kind == 3) args[1] else obs.word(0xfbcb2c);
    var origin: u32 = if (kind == 3) 3 else if (object != 0) 1 else 0;
    if (object == 0) if (active_scope) |s| {
        if (s.record.source.object_local != 0) {
            object = s.record.source.object_local;
            origin = 2;
        }
    };
    snapshot.source(&r.source, object, origin);
    if (kind == 2 and args[4] != 0) {
        r.descriptor_local = args[4];
        r.descriptor_valid = @intFromBool(obs.read(args[4], std.mem.asBytes(&r.descriptor_words)));
        if (r.descriptor_valid != 0 and r.descriptor_words[7] != 0) {
            var heading: u16 = 0;
            r.heading_valid = @intFromBool(obs.read(r.descriptor_words[7], std.mem.asBytes(&heading)));
            r.heading = heading;
        }
    }
    active_scope = scope;
}
fn finish(scope: *t.Scope, result: u32) void {
    const r = &scope.record;
    r.result = result;
    if (r.kind != 3) {
        snapshot.actor(&r.after[0], if (r.kind == 1) r.arguments[0] else r.arguments[2]);
        snapshot.actor(&r.after[1], if (r.kind == 1) r.arguments[1] else r.arguments[0]);
    }
    if (r.kind == 3 and result != 0) r.source.after_status = 6 else {
        var view: Identity = undefined;
        _ = projectiles_observe_live(r.source.object_local, &view);
        r.source.after_status = if (view.status == 1 and (view.id != r.source.id or view.instance_serial != r.source.instance_serial)) 7 else view.status;
    }
    r.clock_after = obs.word(0xfb4b6c);
    r.rng_game_after = obs.word(0xe637b4);
    r.rng_engine_after = obs.word(0xea178c);
    obs.timestamp(&r.qpc_after_low, &r.qpc_after_high);
    active_scope = scope.previous;
    obs.publish(&clonewars_combat_observer[(r.id -% 1) % 4096], r);
}
pub export fn combat_damage_source_id() u32 {
    return if (active_damage) |cause| cause.id else 0;
}
pub export fn combat_damage_native_caller() u32 {
    return if (active_damage) |cause| cause.caller else 0;
}
pub export fn combat_damage_source_ready() c_int {
    return @intFromBool(clonewars_combat_observer_installed >= 0 and clonewars_combat_observer_installed & 1 != 0);
}
const HitScope = struct { machine: Machine, cause: Cause, scope: t.Scope, args: [6]u32, caller: u32, result: u32, observed: bool };
fn hitAbort(address: usize) callconv(.c) void {
    const s: *HitScope = @ptrFromInt(address);
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (s.observed and active_scope == &s.scope) active_scope = s.scope.previous;
    if (active_damage == &s.cause) active_damage = s.cause.previous;
}
fn hitInvoke(address: usize) callconv(.c) usize {
    const s: *HitScope = @ptrFromInt(address);
    var source: Identity = undefined;
    _ = projectiles_observe_live(obs.word(0xfbcb2c), &source);
    // This native caller retires the projectile independently and ignores HIT's return value.
    if (s.caller == 0x884e5c and s.args[2] == 1 and s.args[4] == 0 and s.args[5] == 1 and source.status == 1 and reaction_client_duplicate_projectile(s.args[1], source.id) != 0) return 0;
    s.cause = .{ .previous = active_damage, .id = if (source.status == 1) source.id else 0, .status = source.status, .caller = s.caller };
    active_damage = &s.cause;
    if (clonewars_combat_observer_enabled != 0) {
        begin(&s.scope, 1, s.caller, s.args);
        s.observed = true;
    }
    var receipt: t.Receipt = undefined;
    reaction_damage_begin(&receipt, s.args[1], s.cause.id);
    const a = &s.args;
    s.machine.restore();
    s.result = original_hit(a[0], a[1], a[2], a[3], a[4], a[5]);
    s.machine.capture();
    reaction_damage_complete(&receipt);
    if (s.observed) finish(&s.scope, s.result);
    active_damage = s.cause.previous;
    return s.result;
}
fn hitHook(a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32) callconv(.c) u32 {
    var s: HitScope = undefined;
    s.machine.capture();
    s.args = .{ a0, a1, a2, a3, a4, a5 };
    s.caller = @truncate(@returnAddress());
    s.result = 0;
    s.observed = false;
    _ = constructor_lexical_seh(@intFromPtr(&s), hitInvoke, hitAbort);
    s.machine.restore();
    return s.result;
}
const DeathScope = struct { machine: Machine, scope: t.Scope, args: [6]u32 };
fn deathInvoke(address: usize) callconv(.c) usize {
    const s: *DeathScope = @ptrFromInt(address);
    const a = &s.args;
    s.machine.restore();
    original_death(a[0], a[1], a[2], a[3], a[4], a[5]);
    s.machine.capture();
    finish(&s.scope, 0);
    return 0;
}
fn deathAbort(address: usize) callconv(.c) void {
    const s: *DeathScope = @ptrFromInt(address);
    combat_observer_remove_abort(&s.scope);
}
fn deathHook(a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32) callconv(.c) void {
    if (clonewars_combat_observer_enabled == 0) {
        original_death(a0, a1, a2, a3, a4, a5);
        return;
    }
    var s: DeathScope = undefined;
    s.machine.capture();
    s.args = .{ a0, a1, a2, a3, a4, a5 };
    begin(&s.scope, 2, @truncate(@returnAddress()), s.args);
    // The native adapter has 0x30 local bytes, two saved registers and six pushed arguments.
    const parent = if (s.scope.record.caller == 0x96a4b5) obs.word(@frameAddress() + 0x58) else 0;
    @atomicStore(u32, &clonewars_death_caller_debug[0], 0, .seq_cst);
    clonewars_death_caller_debug[1..].* = .{ parent, s.scope.record.caller, game_sync_sequence(), obs.word(0xfb4b6c), a0, a1, a3 };
    @atomicStore(u32, &clonewars_death_caller_debug[0], s.scope.record.id, .seq_cst);
    _ = constructor_lexical_seh(@intFromPtr(&s), deathInvoke, deathAbort);
    s.machine.restore();
}
pub export fn combat_observer_remove_begin(scope: *t.Scope, manager: usize, object: usize, flags: u32, effects: c_int, caller: u32) c_int {
    if (clonewars_combat_observer_enabled == 0) return 0;
    begin(scope, 3, caller, .{ @truncate(manager), @truncate(object), flags, @bitCast(effects), 0, 0 });
    return 1;
}
pub export fn combat_observer_remove_end(scope: *t.Scope, removed: c_int) void {
    finish(scope, @bitCast(removed));
}
pub export fn combat_observer_remove_abort(scope: *t.Scope) void {
    if (active_scope == scope) active_scope = scope.previous;
}
pub export fn combat_observer_flow(value: c_int) void {
    if (clonewars_combat_observer_enabled != 0) {
        if (value != 0) {
            obs.timestamp(&ticks[0], &ticks[1]);
            ticks[2] = 0;
            ticks[3] = 0;
            ticks[6] = 0;
            ticks[4] = game_sync_sequence();
            ticks[5] = obs.word(0xfb4b6c);
            ticks[7] = win.GetCurrentThreadId();
        } else {
            obs.timestamp(&ticks[2], &ticks[3]);
            ticks[6] = obs.word(0xfb4b6c);
        }
    }
    flow_active = value;
}
pub export fn combat_observer_frame_queued(epoch: u32, sequence: u32) void {
    if (clonewars_combat_observer_enabled == 0) return;
    obs.timestamp(&ticks[8], &ticks[9]);
    ticks[10] = epoch;
    ticks[11] = sequence;
}
pub export fn combat_observer_removal_ready() void {
    _ = @atomicRmw(i32, &clonewars_combat_observer_installed, .Or, 4, .seq_cst);
}
fn installArenaContact() void {
    var setting: [2]u8 = undefined;
    if (GetEnvironmentVariableA("CLONEWARS_ARENA_CONTACT_TRACE", &setting, setting.len) != 1 or setting[0] != '1') return;
    const site: usize = 0x410cd4;
    const prefix = "\xd9\xee\xd8\x99\x3c\x0d\x00\x00";
    if (!win.accessible(site, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..prefix.len], prefix)) return;
    var old: u32 = 0;
    if (win.VirtualProtect(site, prefix.len, 0x40, &old) == 0) return;
    win.store(u8, site, 0xe9);
    win.store(u32, site + 1, @truncate(@intFromPtr(&arena_contact_tap) -% site -% 5));
    for (5..prefix.len) |i| win.store(u8, site + i, 0x90);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, prefix.len);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(site, prefix.len, old, &ignored);
}
pub export fn combat_observer_install() c_int {
    const state = @atomicLoad(i32, &install_state, .seq_cst);
    if (state != 0) return @intFromBool(state == 1);
    const addresses = [_]usize{ 0x96a4c0, 0x968d60 };
    const prefixes = [2][6]u8{ .{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 }, .{ 0x81, 0xec, 0x80, 0, 0, 0 } };
    const hooks = [_]usize{ @intFromPtr(&hitHook), @intFromPtr(&deathHook) };
    var bridges: [2]usize = @splat(0);
    var protections: [2]u32 = @splat(0);
    var writable: usize = 0;
    var published = false;
    defer if (!published) {
        var restored = true;
        while (writable != 0) {
            writable -= 1;
            var ignored: u32 = 0;
            if (win.VirtualProtect(addresses[writable], 6, protections[writable], &ignored) == 0) restored = false;
        }
        for (bridges) |bridge| if (bridge != 0) {
            _ = win.VirtualFree(bridge, 0, 0x8000);
        };
        if (!restored) {
            @atomicStore(i32, &clonewars_combat_observer_enabled, 0, .seq_cst);
            @atomicStore(i32, &clonewars_combat_observer_installed, -1, .seq_cst);
            @atomicStore(i32, &install_state, -1, .seq_cst);
        }
    };
    for (addresses, prefixes, 0..) |address, prefix, i| {
        var actual: [6]u8 = undefined;
        if (!obs.read(address, &actual) or !std.mem.eql(u8, &actual, &prefix)) return 0;
        bridges[i] = win.VirtualAlloc(0, 11, 0x3000, 0x40);
        if (bridges[i] == 0) return 0;
        win.store([6]u8, bridges[i], prefix);
        win.store(u8, bridges[i] + 6, 0xe9);
        win.store(u32, bridges[i] + 7, @truncate(address -% bridges[i] -% 5));
        if (win.FlushInstructionCache(win.GetCurrentProcess(), bridges[i], 11) == 0) return 0;
    }
    for (addresses, 0..) |address, i| {
        if (win.VirtualProtect(address, 6, 0x40, &protections[i]) == 0) return 0;
        writable += 1;
    }
    original_hit = @ptrFromInt(bridges[0]);
    original_death = @ptrFromInt(bridges[1]);
    native_hit_bridge = bridges[0];
    clonewars_combat_observer_install_thread = win.GetCurrentThreadId();
    for (addresses, hooks) |address, hook| {
        win.store(u8, address, 0xe9);
        win.store(u32, address + 1, @truncate(hook -% address -% 5));
        win.store(u8, address + 5, 0x90);
    }
    published = true;
    var ok = true;
    for (addresses) |address| if (win.FlushInstructionCache(win.GetCurrentProcess(), address, 6) == 0) {
        ok = false;
    };
    var i: usize = 2;
    while (i != 0) {
        i -= 1;
        var ignored: u32 = 0;
        if (win.VirtualProtect(addresses[i], 6, protections[i], &ignored) == 0) ok = false;
    }
    if (!ok) {
        @atomicStore(i32, &clonewars_combat_observer_enabled, 0, .seq_cst);
        @atomicStore(i32, &clonewars_combat_observer_installed, -1, .seq_cst);
        @atomicStore(i32, &install_state, -1, .seq_cst);
        return 0;
    }
    installArenaContact();
    _ = @atomicRmw(i32, &clonewars_combat_observer_installed, .Or, 3, .seq_cst);
    @atomicStore(i32, &clonewars_global_observer_installed, 1, .seq_cst);
    @atomicStore(i32, &install_state, 1, .seq_cst);
    return 1;
}
pub export fn combat_hit_bridge_attach(token_value: ?*const Token, interposer: usize, continuation: ?*usize) c_int {
    const session = lan_session_serial();
    const thread = win.GetCurrentThreadId();
    const token = token_value orelse return 0;
    if (session == 0 or interposer == 0 or continuation == null or token.thread != thread or thread != clonewars_combat_observer_install_thread or install_state != 1 or clonewars_combat_observer_installed & 3 != 3 or coherent_frame_valid(token, 4) == 0 or native_hit_bridge == 0) return 0;
    var entry: [6]u8 = undefined;
    var bridge: [11]u8 = undefined;
    if (!obs.read(0x96a4c0, &entry) or !obs.read(native_hit_bridge, &bridge)) return 0;
    const prefix = "\x55\x8b\xec\x83\xe4\xf0";
    const branch = std.mem.bytesToValue(u32, entry[1..5]);
    if (entry[0] != 0xe9 or entry[5] != 0x90 or 0x96a4c5 +% branch != @intFromPtr(&hitHook) or !std.mem.eql(u8, bridge[0..6], prefix) or bridge[6] != 0xe9 or native_hit_bridge +% 11 +% std.mem.bytesToValue(u32, bridge[7..11]) != 0x96a4c6) return 0;
    if (hit_interposer != 0) return @intFromBool(hit_interposer == interposer and @intFromPtr(original_hit) == interposer and continuation.?.* == native_hit_bridge);
    if (@intFromPtr(original_hit) != native_hit_bridge or lan_session_serial() != session or coherent_frame_valid(token, 4) == 0) return 0;
    @atomicStore(usize, continuation.?, native_hit_bridge, .seq_cst);
    if (@cmpxchgStrong(usize, @as(*usize, @ptrCast(&original_hit)), native_hit_bridge, interposer, .seq_cst, .seq_cst) != null) return 0;
    hit_interposer = interposer;
    return 1;
}
comptime {
    _ = @import("arena_contact_bridge.zig");
}
