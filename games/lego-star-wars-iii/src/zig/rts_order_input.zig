const std = @import("std");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const Source = @import("rts_types.zig").Order;
const Machine = @import("machine_environment.zig").Environment;
const win = @import("win32.zig");
const physics = @import("physics_validation.zig");
const Original = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Scope = struct { machine: Machine, previous: ?*Scope, token: Token, source: Source, order: usize, clock: u32, delta: u32, original: Original, bound: bool };
threadlocal var current: ?*Scope = null;
var installed = false;
pub export var clonewars_rts_order_input_debug: [8]u32 = @splat(0);
pub export var clonewars_rts_order_input_failure: [16]u32 = @splat(0);
export var rts_order_ready_resume: usize = 0x55e661;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn native_rts_order_source(usize, *Source) c_int;
extern fn native_rts_order_source_live(*const Source) c_int;
extern fn physics_world_input(*p.SyncPhysicsChoice, *const Token) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn native_rts_order_ready_bridge() void;
fn live(s: *const Scope) bool {
    return coherent_frame_valid(&s.token, 4) != 0 and win.load(u32, 0xfb4b6c) == s.clock and native_rts_order_source_live(&s.source) != 0;
}
fn reject(s: *const Scope, reason: u32) void {
    clonewars_rts_order_input_debug[3] +%= 1;
    if (clonewars_rts_order_input_failure[0] == 0) clonewars_rts_order_input_failure[0..8].* = .{ reason, s.token.epoch, s.token.sequence, s.clock, @truncate(s.order), s.source.team_slot, s.source.building_ordinal, s.source.order_class };
    game_sync_native_fault(15);
}
fn input(s: *const Scope, site: u32) p.SyncPhysicsChoice {
    var c = std.mem.zeroes(p.SyncPhysicsChoice);
    c.kind = p.SYNC_PHYSICS_RTS_ORDER;
    c.site = site;
    const v = &c.payload.rts_order;
    v.clock = s.clock;
    v.team_slot = s.source.team_slot;
    v.building_ordinal = s.source.building_ordinal;
    v.order_class = s.source.order_class;
    v.source_key = s.source.gizmo.key;
    return c;
}
fn exchange(s: *Scope, c: *p.SyncPhysicsChoice) bool {
    const before = c.*;
    if (!live(s)) {
        reject(s, 2);
        return false;
    }
    if (physics_world_input(c, &s.token) != 1) {
        reject(s, 3);
        return false;
    }
    if (!live(s) or !physics.sameSource(&before, c)) {
        reject(s, 4);
        return false;
    }
    clonewars_rts_order_input_debug[0] +%= 1;
    if (!std.mem.eql(u8, std.mem.asBytes(&before.payload)[16..36], std.mem.asBytes(&c.payload)[16..36])) clonewars_rts_order_input_debug[if (c.site == 0x55e65c) 2 else 1] +%= 1;
    return true;
}
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    if (s.bound) {
        if (native_rts_order_source(s.order, &s.source) == 0) {
            reject(s, 1);
            return 0;
        }
        var c = input(s, 0x55e2c0);
        const v = &c.payload.rts_order;
        v.state = win.load(u32, s.order + 0x2e8);
        v.previous_state = win.load(u32, s.order + 0x2ec);
        v.elapsed = win.load(f32, s.order + 0x2f0);
        v.progress = win.load(f32, s.order + 0x2d4);
        if (!exchange(s, &c)) return 0;
        win.store(u32, s.order + 0x2e8, v.state);
        win.store(u32, s.order + 0x2ec, v.previous_state);
        win.store(f32, s.order + 0x2f0, v.elapsed);
        win.store(f32, s.order + 0x2d4, v.progress);
    }
    s.machine.restore();
    s.original(s.order, s.delta);
    s.machine.capture();
    return 0;
}
fn abort(address: usize) callconv(.c) void {
    const s: *Scope = @ptrFromInt(address);
    current = s.previous;
}
pub export fn native_rts_order_ready(order: usize, local: u32) u32 {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var result = local;
    if (current) |s| {
        if (s.bound) {
            if (s.order != order or !live(s)) {
                reject(s, 5);
            } else {
                var c = input(s, 0x55e65c);
                c.payload.rts_order.ready = local & 2;
                if (exchange(s, &c)) result = (local & ~@as(u32, 2)) | c.payload.rts_order.ready;
                clonewars_rts_order_input_debug[4] +%= 1;
            }
        }
    }
    return result;
}
pub export fn rts_order_input_update(order: usize, delta: u32, original: Original) void {
    var s: Scope = undefined;
    s.machine.capture();
    s.token = std.mem.zeroes(Token);
    s.source = std.mem.zeroes(Source);
    s.previous = current;
    s.order = order;
    s.delta = delta;
    s.original = original;
    s.clock = win.load(u32, 0xfb4b6c);
    s.bound = coherent_frame_get(&s.token, 4) != 0;
    current = &s;
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    current = s.previous;
    s.machine.restore();
}
pub export fn rts_order_input_install() c_int {
    if (installed) return 1;
    const expected = "\x8a\x48\x62\xd0\xe9";
    const site: usize = 0x55e65c;
    if (!win.accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected)) return 0;
    var old: u32 = 0;
    if (win.VirtualProtect(site, 5, 0x40, &old) == 0) return 0;
    win.store(u8, site, 0xe9);
    win.store(u32, site + 1, @truncate(@intFromPtr(&native_rts_order_ready_bridge) -% site -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, 5);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(site, 5, old, &ignored);
    installed = true;
    return 1;
}
comptime {
    _ = @import("rts_order_bridge.zig");
}
