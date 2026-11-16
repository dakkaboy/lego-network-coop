const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const Common = @import("shooter_types.zig").Actor;
const Machine = @import("machine_environment.zig").Environment;
const Identity = extern struct { pointer_local: u32, valid: u32, slot: u32, generation: u32, local_generation: u32, character: i32 };
const Actor = extern struct { common: Common, extra: [32]u32, target_2bc: Identity, target_bdc: Identity, pending_valid: u32, pending: [6]u32, held_weapon: [8]u32 };
const Record = extern struct { committed: u32, id: u32, parent: u32, kind: u32, thread: u32, caller: u32, sequence: u32, qpc_before_low: u32, qpc_before_high: u32, qpc_after_low: u32, qpc_after_high: u32, clock: u32, rng_game: u32, rng_engine: u32, clock_after: u32, rng_game_after: u32, rng_engine_after: u32, context_local: u32, arguments: [10]u32, result: u32, before: Actor, after: Actor };
const Scope = struct { record: Record, previous: ?*Scope };
const Native = *const fn (usize) callconv(.c) void;
const Attack = *const fn (usize, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) u8;
var original: Attack = undefined;
threadlocal var active: ?*Scope = null;
pub export var clonewars_decision_observer_version: u32 = 2;
pub export var clonewars_decision_observer_enabled: i32 = 0;
pub export var clonewars_decision_observer_installed: i32 = 0;
pub export var clonewars_decision_checkpoint_installed: i32 = 0;
pub export var clonewars_decision_observer_count: u32 = 0;
pub export var clonewars_decision_observer_slot: i32 = 7;
pub export var clonewars_decision_observer_character: i32 = 321;
pub export var clonewars_decision_observer_stride: u32 = @sizeOf(Record);
pub export var clonewars_decision_observer_capacity: u32 = 8192;
pub export var clonewars_decision_actor_size: u32 = @sizeOf(Actor);
pub export var clonewars_decision_extra_field_count: u32 = 32;
pub export var clonewars_decision_extra_offsets: [32]u32 = .{ 0x24, 0x28, 0x2c, 0x48, 0x6c, 0x2a0, 0x2ac, 0x2bc, 0x2c0, 0x2cc, 0x2f0, 0x2f4, 0x2f8, 0x2fc, 0x7ec, 0x7f8, 0x8dc, 0x8e0, 0xbdc, 0xc88, 0xcfc, 0xd04, 0x530, 0x540, 0xe80, 0x544, 0x1088, 0x108c, 0x300, 0x8e8, 0xddc, 0xd3c };
pub export var clonewars_decision_observer: [8192]Record = std.mem.zeroes([8192]Record);
export var decision_ammo_resume: usize = 0x878dc6;
export var decision_compat_resume: usize = 0x878e07;
export var decision_item_early_resume: usize = 0x8770cf;
export var decision_item_late_resume: usize = 0x8789be;
export var decision_cancel_pre_resume: usize = 0x878455;
export var decision_cancel_post_resume: usize = 0x878478;
extern fn entities_observed_generation(usize) u32;
extern fn entities_observed_identity(usize, *u32, *u32) c_int;
extern fn shooter_observer_actor_snapshot(*Common, usize) void;
extern fn game_sync_sequence() u32;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn decision_ammo_thunk() void;
extern fn decision_compat_thunk() void;
extern fn decision_item_early_thunk() void;
extern fn decision_item_late_thunk() void;
extern fn decision_cancel_pre_thunk() void;
extern fn decision_cancel_post_thunk() void;
fn actorPointer(pointer: u32) bool {
    const pool = obs.word(0xfb2f60);
    const count = obs.word(0xfb2e3c);
    return pool != 0 and count <= 4096 and pointer >= pool and (pointer - pool) % 0x1440 == 0 and (pointer - pool) / 0x1440 < count;
}
fn identity(pointer: u32) Identity {
    var value = std.mem.zeroes(Identity);
    value.pointer_local = pointer;
    value.slot = std.math.maxInt(u32);
    value.character = -1;
    var character: i16 = 0;
    if (!actorPointer(pointer) or !obs.read(pointer +% 0xdc0, std.mem.asBytes(&character))) return value;
    value.valid = 1;
    value.character = character;
    value.local_generation = entities_observed_generation(pointer);
    _ = entities_observed_identity(pointer, &value.slot, &value.generation);
    return value;
}
fn heldWeapon(out: *[8]u32, held: u32) void {
    @memset(out, 0);
    out[0] = held;
    var interaction: [12]u8 = undefined;
    var object: [0x115]u8 = undefined;
    var definition: [0x139]u8 = undefined;
    if (obs.read(held, &interaction)) {
        out[3] |= 1;
        out[1] = std.mem.bytesToValue(u32, interaction[8..12]);
        if (obs.read(out[1], &object)) {
            out[3] |= 2;
            out[2] = std.mem.bytesToValue(u32, object[0xac..0xb0]);
            out[5] = object[0x114];
            if (obs.read(out[2], &definition)) {
                out[3] |= 4;
                out[4] = std.mem.bytesToValue(u32, definition[0x38..0x3c]);
                out[6] = definition[0x131];
                out[7] = definition[0x138];
            }
        }
    }
}
fn snapshot(out: *Actor, actor: usize) void {
    out.* = std.mem.zeroes(Actor);
    out.common.pointer_local = @truncate(actor);
    out.common.raw_slot = std.math.maxInt(u32);
    out.common.network_slot = std.math.maxInt(u32);
    if (!actorPointer(@truncate(actor))) return;
    var raw: [0x1440]u8 = undefined;
    if (!obs.read(actor, &raw)) return;
    shooter_observer_actor_snapshot(&out.common, actor);
    for (clonewars_decision_extra_offsets, &out.extra) |field, *value| value.* = std.mem.bytesToValue(u32, raw[field..][0..4]);
    out.target_2bc = identity(std.mem.bytesToValue(u32, raw[0x2bc..0x2c0]));
    out.target_bdc = identity(std.mem.bytesToValue(u32, raw[0xbdc..0xbe0]));
    heldWeapon(&out.held_weapon, std.mem.bytesToValue(u32, raw[0x528..0x52c]));
    const pending = std.mem.bytesToValue(u32, raw[0x142c..0x1430]);
    var pending_raw: [0x144]u8 = undefined;
    if (obs.read(pending, &pending_raw)) {
        out.pending_valid = 1;
        for ([_]usize{ 0xbc, 0xcc, 0xd8, 0xdc, 0xe0, 0x140 }, &out.pending) |field, *value| value.* = std.mem.bytesToValue(u32, pending_raw[field..][0..4]);
    }
}
fn selected(actor: usize) bool {
    if (clonewars_decision_observer_enabled == 0) return false;
    const value = identity(@truncate(actor));
    if (value.valid == 0) return false;
    const slot = if (value.slot == std.math.maxInt(u32)) (@as(u32, @truncate(actor)) -% obs.word(0xfb2f60)) / 0x1440 else value.slot;
    return (clonewars_decision_observer_slot < 0 or slot == @as(u32, @bitCast(clonewars_decision_observer_slot))) and (clonewars_decision_observer_character < 0 or value.character == clonewars_decision_observer_character);
}
fn begin(scope: *Scope, kind: u32, actor: usize, context: u32, args: [10]u32, caller: u32) void {
    scope.* = .{ .record = std.mem.zeroes(Record), .previous = active };
    const r = &scope.record;
    r.id = obs.increment(&clonewars_decision_observer_count);
    r.parent = if (active) |s| s.record.id else 0;
    r.kind = kind;
    r.thread = win.GetCurrentThreadId();
    r.caller = caller;
    r.sequence = game_sync_sequence();
    r.context_local = context;
    r.arguments = args;
    r.clock = obs.word(0xfb4b6c);
    r.rng_game = obs.word(0xe637b4);
    r.rng_engine = obs.word(0xea178c);
    obs.timestamp(&r.qpc_before_low, &r.qpc_before_high);
    snapshot(&r.before, actor);
    active = scope;
}
fn finish(scope: *Scope, actor: usize, result: u32) void {
    const r = &scope.record;
    snapshot(&r.after, actor);
    r.result = result;
    r.clock_after = obs.word(0xfb4b6c);
    r.rng_game_after = obs.word(0xe637b4);
    r.rng_engine_after = obs.word(0xea178c);
    obs.timestamp(&r.qpc_after_low, &r.qpc_after_high);
    active = scope.previous;
    obs.publish(&clonewars_decision_observer[(r.id -% 1) % 8192], r);
}
const CallScope = struct { machine: Machine, scope: Scope, actor: usize, native: ?Native, result: u8 };
fn invoke(address: usize) callconv(.c) usize {
    const s: *CallScope = @ptrFromInt(address);
    s.machine.restore();
    if (s.native) |native| native(s.actor) else {
        const r = &s.scope.record;
        const a = &r.arguments;
        s.result = original(r.context_local, a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9]);
    }
    s.machine.capture();
    finish(&s.scope, s.actor, s.result);
    return s.result;
}
fn abort(address: usize) callconv(.c) void {
    const s: *CallScope = @ptrFromInt(address);
    active = s.scope.previous;
}
pub export fn decision_observer_invoke_actor(kind: u32, actor: usize, native: Native, caller: u32) void {
    if (clonewars_decision_observer_enabled == 0) {
        native(actor);
        return;
    }
    var s: CallScope = undefined;
    s.machine.capture();
    if (!selected(actor)) {
        s.machine.restore();
        native(actor);
        return;
    }
    s.actor = actor;
    s.native = native;
    s.result = 0;
    var args: [10]u32 = @splat(0);
    args[0] = @truncate(actor);
    begin(&s.scope, kind, actor, @truncate(@intFromPtr(native)), args, caller);
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
}
fn attackHook(context: usize, _: usize, a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32, a6: u32, a7: u32, a8: u32, a9: u32) callconv(.{ .x86_fastcall = .{} }) u8 {
    if (clonewars_decision_observer_enabled == 0) return original(context, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
    var s: CallScope = undefined;
    s.machine.capture();
    if (!selected(a0)) {
        s.machine.restore();
        return original(context, a0, a1, a2, a3, a4, a5, a6, a7, a8, a9);
    }
    s.actor = a0;
    s.native = null;
    s.result = 0;
    begin(&s.scope, 1, a0, @truncate(context), .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9 }, @truncate(@returnAddress()));
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
    return s.result;
}
pub export fn decision_observer_checkpoint(native_stack: usize, result: u32, caller: u32, context: usize) void {
    if (clonewars_decision_observer_enabled == 0) return;
    const parent = active orelse return;
    if (parent.record.kind != 1) return;
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var scope: Scope = undefined;
    var actor = parent.record.before.common.pointer_local;
    var args: [10]u32 = @splat(0);
    const cancel = caller == 0x87844e or caller == 0x878472;
    if (!cancel) {
        _ = obs.read(native_stack, std.mem.asBytes(&args)[0..if (caller == 0x878e02) @as(usize, 8) else 4]);
        var regs: [8]u32 = undefined;
        if (context != 0 and obs.read(context, std.mem.asBytes(&regs))) {
            args[2] = regs[0];
            args[3] = regs[1];
            args[4] = regs[4];
            args[5] = regs[6];
            args[6] = regs[5];
            args[7] = regs[2];
        }
        args[8] = @truncate(native_stack);
    }
    var global: u8 = 0;
    const global_known = obs.read(0xe650e7, std.mem.asBytes(&global));
    args[9] = if (global_known) global else std.math.maxInt(u32);
    if (caller == 0x8770ca or caller == 0x8789b9) {
        actor = args[0];
        var held: u32 = 0;
        var kind: u8 = 0;
        const readable = obs.read(actor +% 0x528, std.mem.asBytes(&held)) and held != 0 and obs.read(held +% 0x48, std.mem.asBytes(&kind));
        args[7] = @intFromBool(readable);
        args[8] = if (readable) kind else std.math.maxInt(u32);
    }
    if (cancel) {
        var regs: [8]u32 = @splat(0);
        var native_args: [2]u32 = @splat(0);
        var effective: u32 = 0;
        var magnitude: u32 = 0;
        var known: u32 = 0;
        @memset(&args, 0);
        args[8] = @truncate(native_stack);
        args[9] = if (global_known) global else std.math.maxInt(u32);
        if (context != 0 and obs.read(context, std.mem.asBytes(&regs))) {
            known |= 1;
            args[0] = regs[4];
            args[2] = regs[1];
            args[7] = regs[2];
            if (args[0] == actor) known |= 8;
            actor = regs[4];
            if (obs.read(regs[2] +% 0xc, std.mem.asBytes(&effective))) {
                known |= 2;
                args[1] = effective;
                if (effective != 0 and obs.read(effective +% 0x28, std.mem.asBytes(&magnitude))) {
                    known |= 4;
                    args[3] = magnitude;
                }
            }
        }
        if (caller == 0x878472 and obs.read(native_stack, std.mem.asBytes(&native_args))) {
            known |= 16;
            args[5] = native_args[0];
            args[6] = native_args[1];
        }
        args[4] = known;
    }
    begin(&scope, 4, actor, parent.record.context_local, args, caller);
    if (caller == 0x878dc1) heldWeapon(&scope.record.before.held_weapon, args[0]);
    finish(&scope, actor, result);
}
pub export fn decision_observer_install() c_int {
    const sites = [_]usize{ 0x876a50, 0x878dc1, 0x878e02, 0x8770ca, 0x8789b9, 0x87844e, 0x878472 };
    const expected = [_][]const u8{ "\x55\x8b\xec\x83\xe4\xf0", "\x83\xc4\x04\x85\xc0", "\x83\xc4\x08\x85\xc0", "\x83\xc4\x04\x84\xc0", "\x83\xc4\x04\x84\xc0", "\xf6\x83\x00\x03\x00\x00\x08", "\x83\xc4\x08\x83\xf8\x02" };
    const calls = [_]usize{ 0, 0x79d150, 0x7b0390, 0x7c7a70, 0x7c7a70, 0, 0x88a120 };
    const hooks = [_]usize{ @intFromPtr(&attackHook), @intFromPtr(&decision_ammo_thunk), @intFromPtr(&decision_compat_thunk), @intFromPtr(&decision_item_early_thunk), @intFromPtr(&decision_item_late_thunk), @intFromPtr(&decision_cancel_pre_thunk), @intFromPtr(&decision_cancel_post_thunk) };
    for (sites, expected, calls) |site, prefix, call| if (!win.accessible(site, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..prefix.len], prefix) or (call != 0 and (!win.accessible(site - 5, 5, false) or win.load(u8, site - 5) != 0xe8 or site +% win.load(u32, site - 4) != call))) {
        clonewars_decision_observer_installed = -1;
        return 0;
    };
    const bridge = win.VirtualAlloc(0, 11, 0x3000, 0x40);
    if (bridge == 0) {
        clonewars_decision_observer_installed = -1;
        return 0;
    }
    var old: [7]u32 = undefined;
    var protected: usize = 0;
    while (protected < sites.len) : (protected += 1) {
        if (win.VirtualProtect(sites[protected], expected[protected].len, 0x40, &old[protected]) == 0) break;
    }
    if (protected < sites.len) {
        while (protected != 0) {
            protected -= 1;
            var ignored: u32 = 0;
            _ = win.VirtualProtect(sites[protected], expected[protected].len, old[protected], &ignored);
        }
        _ = win.VirtualFree(bridge, 0, 0x8000);
        clonewars_decision_observer_installed = -1;
        return 0;
    }
    win.store([6]u8, bridge, expected[0][0..6].*);
    win.store(u8, bridge + 6, 0xe9);
    win.store(u32, bridge + 7, @truncate(sites[0] -% bridge -% 5));
    original = @ptrFromInt(bridge);
    for (sites, expected, hooks) |site, prefix, hook| {
        win.store(u8, site, 0xe9);
        win.store(u32, site + 1, @truncate(hook -% site -% 5));
        for (5..prefix.len) |i| win.store(u8, site + i, 0x90);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, prefix.len);
    }
    var i: usize = sites.len;
    while (i != 0) {
        i -= 1;
        var ignored: u32 = 0;
        _ = win.VirtualProtect(sites[i], expected[i].len, old[i], &ignored);
    }
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, 11);
    clonewars_decision_checkpoint_installed = 63;
    clonewars_decision_observer_installed = 1;
    return 1;
}
comptime {
    std.debug.assert(@sizeOf(Actor) == 624 and @sizeOf(Record) == 1364);
    _ = @import("decision_bridges.zig");
}
