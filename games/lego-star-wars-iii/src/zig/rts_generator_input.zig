const std = @import("std");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const Source = @import("rts_types.zig").Generator;
const Machine = @import("machine_environment.zig").Environment;
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const physics = @import("physics_validation.zig");
const Original = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Scope = struct { machine: Machine, token: Token, source: Source, object: usize, clock: u32, delta: u32, original: Original, bound: bool };
pub export var clonewars_rts_generator_input_debug: [8]u32 = @splat(0);
pub export var clonewars_rts_generator_input_failure: [16]u32 = @splat(0);
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn native_rts_generator_source(usize, *Source) c_int;
extern fn native_rts_generator_source_live(*const Source) c_int;
extern fn physics_world_input(*p.SyncPhysicsChoice, *const Token) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
fn live(s: *const Scope) bool {
    return coherent_frame_valid(&s.token, 4) != 0 and win.load(u32, 0xfb4b6c) == s.clock and native_rts_generator_source_live(&s.source) != 0;
}
fn reject(s: *const Scope, reason: u32) void {
    clonewars_rts_generator_input_debug[3] +%= 1;
    if (clonewars_rts_generator_input_failure[0] == 0) clonewars_rts_generator_input_failure[0..9].* = .{ reason, s.token.epoch, s.token.sequence, s.clock, @truncate(s.object), s.source.team_slot, s.source.index, s.source.side, s.source.object_class };
    game_sync_native_fault(15);
}
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    if (s.bound) {
        if (native_rts_generator_source(s.object, &s.source) == 0) {
            reject(s, 1);
            return 0;
        }
        var choice = std.mem.zeroes(p.SyncPhysicsChoice);
        choice.kind = p.SYNC_PHYSICS_RTS_GENERATOR;
        choice.site = 0x547d30;
        const v = &choice.payload.rts_generator;
        v.clock = s.clock;
        v.team_slot = s.source.team_slot;
        v.index = s.source.index;
        v.side = s.source.side;
        v.object_class = s.source.object_class;
        v.state = win.load(u32, s.object + 0x264);
        v.delta = @bitCast(s.delta);
        v.elapsed = win.load(f32, s.object + 0x26c);
        v.countdown = win.load(f32, s.object + 0x270);
        v.phase_time = win.load(f32, s.object + 0x274);
        v.previous_state = win.load(u32, s.object + 0x268);
        v.timer_delta = win.load(f32, s.source.engine + 0xe0c);
        v.rng_game = win.load(u32, 0xe637b4);
        v.rng_engine = win.load(u32, 0xea178c);
        v.rng_effects = win.load(u32, 0xe5f498);
        const before = choice;
        if (!live(s)) {
            reject(s, 2);
            return 0;
        }
        if (physics_world_input(&choice, &s.token) != 1) {
            reject(s, 3);
            return 0;
        }
        if (!live(s) or !physics.sameSource(&before, &choice)) {
            reject(s, 4);
            return 0;
        }
        clonewars_rts_generator_input_debug[0] +%= 1;
        if (!std.mem.eql(u8, std.mem.asBytes(&before.payload)[24..60], std.mem.asBytes(&choice.payload)[24..60])) clonewars_rts_generator_input_debug[1] +%= 1;
        if (!equal(&before.payload.rts_generator.delta, &v.delta)) {
            clonewars_rts_generator_input_debug[2] +%= 1;
            if (clonewars_rts_generator_input_debug[4] == 0) clonewars_rts_generator_input_debug[4..7].* = .{ s.clock, @bitCast(before.payload.rts_generator.delta), @bitCast(v.delta) };
        }
        s.delta = @bitCast(v.delta);
        win.store([3]f32, s.object + 0x26c, .{ v.elapsed, v.countdown, v.phase_time });
        win.store(u32, s.object + 0x268, v.previous_state);
        win.store(f32, s.source.engine + 0xe0c, v.timer_delta);
        win.store(u32, 0xe637b4, v.rng_game);
        win.store(u32, 0xea178c, v.rng_engine);
        win.store(u32, 0xe5f498, v.rng_effects);
    }
    s.machine.restore();
    s.original(s.object, s.delta);
    s.machine.capture();
    return 0;
}
fn abort(_: usize) callconv(.c) void {}
pub export fn rts_generator_input_update(object: usize, delta: u32, original: Original) void {
    var s: Scope = undefined;
    s.machine.capture();
    s.token = std.mem.zeroes(Token);
    s.source = std.mem.zeroes(Source);
    s.object = object;
    s.delta = delta;
    s.original = original;
    s.clock = win.load(u32, 0xfb4b6c);
    s.bound = coherent_frame_get(&s.token, 4) != 0;
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
}
