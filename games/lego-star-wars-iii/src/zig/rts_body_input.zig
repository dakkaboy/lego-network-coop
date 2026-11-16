const std = @import("std");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const types = @import("rts_types.zig");
const Machine = @import("machine_environment.zig").Environment;
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const physics = @import("physics_validation.zig");
const Update = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) void;
const VisibilityUpdate = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Apply = *const fn (usize, [*]const f32) callconv(.{ .x86_thiscall = .{} }) void;
const Scope = struct { machine: Machine, token: Token, source: types.Body, object: usize, state: u32, flag: u32, clock: u32, original: Update, bound: bool };
const VisibilityScope = struct { machine: Machine, token: Token, source: types.Object, object: usize, clock: u32, delta: u32, site: u32, original: ?VisibilityUpdate, bound: bool };
pub export var clonewars_rts_body_input_debug: [4]u32 = @splat(0);
pub export var clonewars_rts_body_input_failure: [12]u32 = @splat(0);
pub export var clonewars_rts_visibility_input_debug: [4]u32 = @splat(0);
pub export var clonewars_rts_visibility_input_failure: [12]u32 = @splat(0);
pub export var clonewars_rts_attack_visibility_debug: [4]u32 = @splat(0);
export var attack_visibility_resume: usize = 0x54667b;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn native_rts_body_source(usize, u32, *types.Body) c_int;
extern fn native_rts_object_source(usize, *types.Object) c_int;
extern fn physics_world_input(*p.SyncPhysicsChoice, *const Token) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn rts_attack_visibility_input_bridge() void;
fn live(s: anytype) bool {
    return coherent_frame_valid(&s.token, 4) != 0 and win.load(u32, 0xfb4b6c) == s.clock;
}
fn same(s: *const Scope) bool {
    var now: types.Body = undefined;
    return live(s) and native_rts_body_source(s.object, s.state, &now) == 1 and equal(&s.source, &now);
}
fn reject(s: *const Scope, reason: u32) void {
    if (!live(s)) return;
    clonewars_rts_body_input_debug[3] +%= 1;
    if (clonewars_rts_body_input_failure[0] == 0) clonewars_rts_body_input_failure[0..7].* = .{ reason, s.token.epoch, s.token.sequence, s.clock, @truncate(s.object), s.source.ordinal, s.state };
    game_sync_native_fault(15);
}
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    s.machine.restore();
    s.original(s.object, s.state, s.flag);
    s.machine.capture();
    if (!s.bound or !live(s)) return 0;
    const found = native_rts_body_source(s.object, s.state, &s.source);
    if (found < 0) {
        reject(s, 1);
        return 0;
    }
    if (found == 0) return 0;
    var local: [24]f32 = undefined;
    local[0..16].* = win.load([16]f32, s.source.body + 0x40);
    local[16..24].* = win.load([8]f32, s.source.dynamics + 0x20);
    var canonical = local;
    for (0..2) |part| {
        var c = std.mem.zeroes(p.SyncPhysicsChoice);
        c.kind = if (part == 0) p.SYNC_PHYSICS_RTS_BODY_BASIS else p.SYNC_PHYSICS_RTS_BODY_MOTION;
        c.site = 0x544b10;
        const v = &c.payload.spellit_body;
        v.clock = s.clock;
        v.body_class = s.source.body_class;
        v.piece_ordinal = s.source.ordinal;
        v.key = s.source.key;
        @memcpy(&v.values, local[12 * part ..][0..12]);
        // Fourth velocity lanes are native scratch and can contain non-finite bit patterns.
        if (part != 0) {
            v.values[7] = 0;
            v.values[11] = 0;
        }
        const before = c;
        if (!same(s) or physics_world_input(&c, &s.token) != 1 or !same(s) or !physics.sameSource(&before, &c)) {
            reject(s, 2);
            return 0;
        }
        if (part == 0) canonical[0..12].* = v.values else {
            @memcpy(canonical[12..19], v.values[0..7]);
            @memcpy(canonical[20..23], v.values[8..11]);
        }
    }
    if (!same(s)) {
        reject(s, 3);
        return 0;
    }
    var helper: Machine = undefined;
    helper.capture();
    const matrix: Apply = @ptrFromInt(0xa29570);
    const linear: Apply = @ptrFromInt(0x8b5cd0);
    const angular: Apply = @ptrFromInt(0x8b5e00);
    s.machine.restore();
    matrix(s.source.body, &canonical);
    helper.restore();
    if (!same(s)) {
        reject(s, 4);
        return 0;
    }
    s.machine.restore();
    linear(s.source.model, canonical[16..].ptr);
    helper.restore();
    if (!same(s)) {
        reject(s, 5);
        return 0;
    }
    s.machine.restore();
    angular(s.source.model, canonical[20..].ptr);
    helper.restore();
    if (!same(s)) {
        reject(s, 6);
        return 0;
    }
    clonewars_rts_body_input_debug[0] +%= 1;
    if (!equal(&local, &canonical)) clonewars_rts_body_input_debug[1] +%= 1;
    return 0;
}
fn abort(_: usize) callconv(.c) void {}
pub export fn rts_body_input_update(object: usize, state: u32, flag: u32, original: Update) void {
    var s: Scope = undefined;
    s.machine.capture();
    s.token = std.mem.zeroes(Token);
    s.source = std.mem.zeroes(types.Body);
    s.object = object;
    s.state = state;
    s.flag = flag;
    s.original = original;
    s.clock = win.load(u32, 0xfb4b6c);
    s.bound = coherent_frame_get(&s.token, 4) != 0;
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
}
fn visibilityReject(s: *const VisibilityScope, reason: u32) void {
    if (!live(s)) return;
    clonewars_rts_visibility_input_debug[3] +%= 1;
    if (clonewars_rts_visibility_input_failure[0] == 0) clonewars_rts_visibility_input_failure[0..6].* = .{ reason, s.token.epoch, s.token.sequence, s.clock, @truncate(s.object), s.source.ordinal };
    game_sync_native_fault(15);
}
fn visibilityInvoke(address: usize) callconv(.c) usize {
    const s: *VisibilityScope = @ptrFromInt(address);
    if (s.bound and live(s)) {
        if (native_rts_object_source(s.object, &s.source) == 0) {
            visibilityReject(s, 1);
            return 0;
        }
        var c = std.mem.zeroes(p.SyncPhysicsChoice);
        c.kind = p.SYNC_PHYSICS_RTS_VISIBILITY;
        c.site = s.site;
        const v = &c.payload.world;
        v.clock = s.clock;
        v.value = win.load(u8, s.source.pad + 0x27d);
        v.source_name = s.source.key;
        v.gizmo_class = s.source.object_class;
        v.gizmo_ordinal = s.source.ordinal;
        const before = c;
        if (physics_world_input(&c, &s.token) != 1 or !live(s)) {
            visibilityReject(s, 2);
            return 0;
        }
        var now: types.Object = undefined;
        if (native_rts_object_source(s.object, &now) == 0 or !equal(&s.source, &now) or !physics.sameSource(&before, &c)) {
            visibilityReject(s, 3);
            return 0;
        }
        if (s.site == 0x546674) {
            clonewars_rts_attack_visibility_debug[0] +%= 1;
            if (v.value != before.payload.world.value) {
                if (clonewars_rts_attack_visibility_debug[1] == 0) clonewars_rts_attack_visibility_debug[2..4].* = .{ before.payload.world.value, v.value };
                clonewars_rts_attack_visibility_debug[1] +%= 1;
            }
        }
        win.store(u8, s.source.pad + 0x27d, @truncate(v.value));
        clonewars_rts_visibility_input_debug[0] +%= 1;
        if (s.site == 0x546674) clonewars_rts_visibility_input_debug[2] +%= 1;
        if (v.value != before.payload.world.value) clonewars_rts_visibility_input_debug[1] +%= 1;
    }
    if (s.original) |original| {
        s.machine.restore();
        original(s.object, s.delta);
        s.machine.capture();
    }
    return 0;
}
pub export fn rts_visibility_input_update(object: usize, delta: u32, original: ?VisibilityUpdate, site: u32) void {
    var s: VisibilityScope = undefined;
    s.machine.capture();
    s.token = std.mem.zeroes(Token);
    s.source = std.mem.zeroes(types.Object);
    s.object = object;
    s.delta = delta;
    s.site = site;
    s.original = original;
    s.clock = win.load(u32, 0xfb4b6c);
    s.bound = coherent_frame_get(&s.token, 4) != 0;
    _ = constructor_lexical_seh(@intFromPtr(&s), visibilityInvoke, abort);
    s.machine.restore();
}
pub export fn rts_attack_visibility_input(object: usize) void {
    rts_visibility_input_update(object, 0, null, 0x546674);
}
pub export fn rts_visibility_attack_install() c_int {
    const expected = "\x8b\x43\x24\x80\xb8\x7d\x02\x00\x00\x00";
    const site: usize = 0x546671;
    if (!win.accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected)) return 0;
    var old: u32 = 0;
    if (win.VirtualProtect(site, expected.len, 0x40, &old) == 0) return 0;
    win.store(u8, site, 0xe9);
    win.store(u32, site + 1, @truncate(@intFromPtr(&rts_attack_visibility_input_bridge) -% site -% 5));
    for (5..expected.len) |i| win.store(u8, site + i, 0x90);
    const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), site, expected.len) != 0;
    var ignored: u32 = 0;
    return @intFromBool(win.VirtualProtect(site, expected.len, old, &ignored) != 0 and flushed);
}
comptime {
    _ = @import("rts_attack_bridge.zig");
}
