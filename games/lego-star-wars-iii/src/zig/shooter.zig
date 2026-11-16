const std = @import("std");
const win = @import("win32.zig");
const Machine = @import("machine_environment.zig").Environment;
const types = @import("shooter_types.zig");
const Actor = types.Actor;
const Record = types.Record;
const Scope = types.Scope;
const Native = *const fn (usize) callconv(.c) void;
var originals: [3]Native = undefined;
threadlocal var active_scope: ?*Scope = null;
pub export var clonewars_shooter_observer_enabled: i32 = 0;
pub export var clonewars_shooter_observer_installed: i32 = 0;
pub export var clonewars_shooter_observer_count: u32 = 0;
pub export var clonewars_shooter_observer_character: i32 = 321;
pub export var clonewars_shooter_actor_field_count: u32 = 63;
pub export var clonewars_shooter_observer_stride: u32 = @sizeOf(Record);
pub export var clonewars_shooter_observer_capacity: u32 = 8192;
pub export var clonewars_shooter_actor_offsets: [63]u32 = .{ 0x4c, 0x50, 0x54, 0x100, 0x108, 0x10c, 0x110, 0x114, 0x118, 0x11c, 0x120, 0x124, 0x128, 0x12c, 0x130, 0x134, 0x138, 0x13c, 0x140, 0x144, 0x180, 0x2a0, 0x2e8, 0x2f4, 0x346, 0x348, 0x55c, 0x610, 0x67c, 0x680, 0x6a8, 0x6ac, 0x6b0, 0x6cc, 0x8d8, 0x8e8, 0x8ec, 0x8f8, 0xbdc, 0xbe0, 0xbe4, 0xbe8, 0xc78, 0xc80, 0xc8c, 0xc94, 0xee0, 0xee4, 0xee8, 0xeec, 0xef0, 0xef4, 0xef8, 0xefc, 0xf00, 0xf04, 0xf08, 0xe28, 0x142c, 0xd88, 0x10ec, 0xb80, 0x760 };
pub export var clonewars_shooter_observer: [8192]Record = std.mem.zeroes([8192]Record);
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.winapi) i32;
extern fn entities_observed_generation(usize) u32;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn game_sync_sequence() u32;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
fn localRead(address: usize, output: []u8) bool {
    if (!win.accessible(address, output.len, false)) return false;
    @memcpy(output, @as([*]const u8, @ptrFromInt(address))[0..output.len]);
    return true;
}
fn word(address: usize) u32 {
    var value: u32 = 0;
    _ = localRead(address, std.mem.asBytes(&value));
    return value;
}
fn actorSnapshot(out: *Actor, actor: usize) void {
    out.* = std.mem.zeroes(Actor);
    out.pointer_local = @truncate(actor);
    out.raw_slot = std.math.maxInt(u32);
    out.network_slot = std.math.maxInt(u32);
    var raw: [0x1440]u8 = undefined;
    if (!localRead(actor, &raw)) return;
    out.valid = 1;
    out.local_generation = entities_observed_generation(actor);
    _ = entities_observed_identity(actor, &out.network_slot, &out.network_generation);
    const pool = word(0xfb2f60);
    const count = word(0xfb2e3c);
    const offset = actor -% pool;
    if (pool != 0 and offset % 0x1440 == 0 and offset / 0x1440 < count) out.raw_slot = @intCast(offset / 0x1440);
    out.character = std.mem.bytesToValue(i16, raw[0xdc0..0xdc2]);
    for (clonewars_shooter_actor_offsets, &out.words) |field, *value| value.* = std.mem.bytesToValue(u32, raw[field..][0..4]);
    out.controller_local = std.mem.bytesToValue(u32, raw[0x6cc..0x6d0]);
    out.controller_valid = @intFromBool(localRead(out.controller_local, std.mem.asBytes(&out.controller_words)));
    out.model_local = std.mem.bytesToValue(u32, raw[8..12]);
    var flags: u8 = 0;
    out.model_valid = @intFromBool(localRead(out.model_local +% 0x29, std.mem.asBytes(&flags)));
    out.model_flags29 = flags;
    const resource = std.mem.bytesToValue(u32, raw[0xf08..0xf0c]);
    out.resource24_local = word(resource +% 0x24);
    const actor100 = std.mem.bytesToValue(u32, raw[0x100..0x104]);
    out.actor100_valid = @intFromBool(localRead(actor100, std.mem.asBytes(&out.actor100_word0)));
    var active: u8 = 0;
    out.model_active42_valid = @intFromBool(localRead(out.model_local +% 0x42, std.mem.asBytes(&active)));
    out.model_active42 = active;
    out.global_fb32a8 = word(0xfb32a8);
}
pub export fn shooter_observer_actor_snapshot(out: *Actor, actor: usize) void {
    actorSnapshot(out, actor);
}
fn begin(scope: *Scope, kind: u32, actor: usize, caller: u32) void {
    scope.* = std.mem.zeroes(Scope);
    const r = &scope.record;
    r.id = @atomicRmw(u32, &clonewars_shooter_observer_count, .Add, 1, .seq_cst) +% 1;
    r.kind = kind;
    r.caller = caller;
    r.parent = if (active_scope) |s| s.record.id else 0;
    r.thread = win.GetCurrentThreadId();
    r.sequence = game_sync_sequence();
    r.clock = word(0xfb4b6c);
    r.rng_game = word(0xe637b4);
    r.rng_engine = word(0xea178c);
    var q: i64 = 0;
    _ = QueryPerformanceCounter(&q);
    const bits: [2]u32 = @bitCast(q);
    r.qpc_before_low = bits[0];
    r.qpc_before_high = bits[1];
    actorSnapshot(&r.before, actor);
    scope.previous = active_scope;
    active_scope = scope;
}
fn finish(scope: *Scope) void {
    const r = &scope.record;
    actorSnapshot(&r.after, r.before.pointer_local);
    r.clock_after = word(0xfb4b6c);
    r.rng_game_after = word(0xe637b4);
    r.rng_engine_after = word(0xea178c);
    var q: i64 = 0;
    _ = QueryPerformanceCounter(&q);
    const bits: [2]u32 = @bitCast(q);
    r.qpc_after_low = bits[0];
    r.qpc_after_high = bits[1];
    active_scope = scope.previous;
    const target = &clonewars_shooter_observer[(r.id -% 1) % 8192];
    @atomicStore(u32, &target.committed, 0, .seq_cst);
    target.* = r.*;
    @atomicStore(u32, &target.committed, r.id, .seq_cst);
}
const ActorScope = struct { machine: Machine, record: Scope, actor: usize, native: Native };
fn invoke(address: usize) callconv(.c) usize {
    const s: *ActorScope = @ptrFromInt(address);
    s.machine.restore();
    s.native(s.actor);
    s.machine.capture();
    finish(&s.record);
    return 0;
}
fn abort(address: usize) callconv(.c) void {
    const s: *ActorScope = @ptrFromInt(address);
    shooter_observer_fire_abort(&s.record);
}
fn observe(kind: u32, native: Native, actor: usize, caller: u32) void {
    if (clonewars_shooter_observer_enabled == 0) {
        native(actor);
        return;
    }
    var s: ActorScope = undefined;
    s.machine.capture();
    var character: i16 = -1;
    _ = localRead(actor +% 0xdc0, std.mem.asBytes(&character));
    if (clonewars_shooter_observer_character >= 0 and character != clonewars_shooter_observer_character) {
        s.machine.restore();
        native(actor);
        return;
    }
    s.actor = actor;
    s.native = native;
    begin(&s.record, kind, actor, caller);
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
}
fn lateHook(actor: usize) callconv(.c) void {
    observe(1, originals[0], actor, @truncate(@returnAddress()));
}
fn parentHook(actor: usize) callconv(.c) void {
    observe(3, originals[1], actor, @truncate(@returnAddress()));
}
fn updateHook(actor: usize) callconv(.c) void {
    observe(4, originals[2], actor, @truncate(@returnAddress()));
}
pub export fn shooter_observer_fire_begin(scope: *Scope, actor: usize, weapon: usize, mode: c_int, out1: usize, out2: usize, caller: u32) c_int {
    if (clonewars_shooter_observer_enabled == 0) return 0;
    if (active_scope) |s| s.record.child_fire_count +%= 1;
    begin(scope, 2, actor, caller);
    const r = &scope.record;
    r.arguments_local = .{ @truncate(actor), @truncate(weapon), @bitCast(mode), @truncate(out1), @truncate(out2) };
    var value: i8 = -1;
    r.weapon_valid = @intFromBool(localRead(weapon, std.mem.asBytes(&value)));
    r.weapon = @bitCast(@as(i32, value));
    return 1;
}
pub export fn shooter_observer_fire_end(scope: *Scope) void {
    finish(scope);
}
pub export fn shooter_observer_fire_abort(scope: *Scope) void {
    if (active_scope == scope) active_scope = scope.previous;
}
pub export fn shooter_observer_install() c_int {
    const addresses = [_]usize{ 0x9b5190, 0x9bb240, 0x9b5ce0 };
    const prefixes = [_][]const u8{ "\x53\x55\x8b\x2d\x20\x4a\xfb\x00", "\x83\xec\x18\xd9\xe8", "\x55\x8b\xec\x83\xe4\xf0" };
    const hooks = [_]Native{ lateHook, parentHook, updateHook };
    for (addresses, prefixes) |address, prefix| if (!win.accessible(address, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..prefix.len], prefix)) {
        clonewars_shooter_observer_installed = -1;
        return 0;
    };
    for (addresses, prefixes, hooks, 0..) |address, prefix, native_hook, i| {
        const bridge = win.VirtualAlloc(0, prefix.len + 5, 0x3000, 0x40);
        var old: u32 = 0;
        if (bridge == 0 or win.VirtualProtect(address, prefix.len, 0x40, &old) == 0) {
            clonewars_shooter_observer_installed = -1;
            return 0;
        }
        @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..prefix.len], prefix);
        win.store(u8, bridge + prefix.len, 0xe9);
        win.store(u32, bridge + prefix.len + 1, @truncate(address -% bridge -% 5));
        originals[i] = @ptrFromInt(bridge);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, prefix.len + 5);
        win.store(u8, address, 0xe9);
        win.store(u32, address + 1, @truncate(@intFromPtr(native_hook) -% address -% 5));
        for (5..prefix.len) |j| win.store(u8, address + j, 0x90);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), address, prefix.len);
        var ignored: u32 = 0;
        _ = win.VirtualProtect(address, prefix.len, old, &ignored);
        _ = @atomicRmw(i32, &clonewars_shooter_observer_installed, .Or, @as(i32, 1) << @intCast(i), .seq_cst);
    }
    return 1;
}
