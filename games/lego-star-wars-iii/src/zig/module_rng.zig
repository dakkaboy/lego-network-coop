const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const Machine = @import("machine_environment.zig").Environment;
const physics = @import("physics_validation.zig");
pub export var clonewars_module_rng_debug: [4]u32 = @splat(0);
pub export var clonewars_module_rng_failure: [12]u32 = @splat(0);
pub export var clonewars_module_rng_correction: [8]u32 = @splat(0);
pub export var clonewars_gun_jam_rng_debug: [4]u32 = @splat(0);
pub export var clonewars_gun_jam_rng_correction: [8]u32 = @splat(0);
export var gun_jam_native_rng: usize = 0x573100;
const Entry = extern struct { id: u32, generation: u32, object: usize, kind: u32, flags: u32 };
const Reference = extern struct { kind: usize, name: [64]u8, binding: usize };
const Witness = extern struct {
    object: usize,
    world: usize,
    container: usize,
    world_handle: usize,
    registry: usize,
    entry: usize,
    record: Entry,
    kind: u32,
    descriptor: Reference,
    references: [3][3]Reference,
    burst_min: u8,
    burst_max: u8,
    channel_count: u8,
    weapon: i8,
    intervals: [3]u32,
};
const Scope = struct { machine: Machine, token: Token, source: Witness, object: usize, clock: u32, seed: u32, bound: bool };
var installed = false;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn physics_module_input(*p.SyncPhysicsChoice, *const Token) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn gun_jam_rng_thunk() void;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn readable(address: usize, length: usize) bool {
    return length > 0 and win.accessible(address, length, false);
}
fn reference(address: usize, expected: usize, out: *Reference) bool {
    if (!readable(address, 0x54) or read(usize, address) != expected) return false;
    out.* = .{ .kind = expected, .name = read([64]u8, address + 4), .binding = read(usize, address + 0x50) };
    return std.mem.indexOfScalar(u8, &out.name, 0) != null;
}
fn registeredModule(object: usize, kind: usize, length: usize, out: *Witness) bool {
    out.* = std.mem.zeroes(Witness);
    out.object = object;
    out.world = read(usize, 0xfb4a20);
    out.registry = read(usize, 0xe906b0);
    if (!readable(object, length) or read(usize, object) != kind or !readable(out.world, 0x22e8) or !readable(out.registry, 8 + 192 * @sizeOf(Entry))) return false;
    out.container = read(usize, out.world + 0x22e4);
    out.world_handle = read(usize, out.world + 0x400);
    if (!readable(out.container, 0x10) or read(usize, out.container + 0xc) != out.world or !readable(out.world_handle, 4)) return false;
    out.entry = read(usize, object + 0x68);
    const first = out.registry + 8;
    const offset = out.entry -% first;
    if (offset >= 192 * @sizeOf(Entry) or offset % @sizeOf(Entry) != 0 or !readable(out.entry, @sizeOf(Entry))) return false;
    out.record = read(Entry, out.entry);
    out.kind = read(u32, object + 4);
    if (out.record.id == 0 or out.kind == 0 or out.record.kind != 4 or out.record.object != object or out.record.flags & 0xff != 0 or read(u32, object + 8) != out.record.id or read(u32, object + 0x6c) != out.record.generation) return false;
    for (0..192) |i| {
        const other = read(Entry, out.registry + 8 + i * @sizeOf(Entry));
        if (other.kind == 4 and other.flags & 0xff == 0 and other.id == out.record.id and other.object != 0 and other.object != object) return false;
    }
    return true;
}
fn witness(object: usize, out: *Witness) bool {
    if (!registeredModule(object, 0xae6b3c, 0x3e8, out) or !reference(object + 0x10, 0xae2df0, &out.descriptor)) return false;
    out.burst_min = read(u8, object + 0x3ca);
    out.burst_max = read(u8, object + 0x3c9);
    out.channel_count = read(u8, object + 0x3c8);
    out.weapon = read(i8, object + 0x3d0);
    if (out.burst_min >= out.burst_max or out.channel_count > 3) return false;
    for ([_]usize{ 0x3d4, 0x3d8, 0x3e0 }, &out.intervals) |offset, *interval| {
        interval.* = read(u32, object + offset);
        if (!std.math.isFinite(@as(f32, @bitCast(interval.*)))) return false;
    }
    for (0..out.channel_count) |i| for (0..3) |j| {
        if (!reference(object + 0x98 + i * 0x110 + j * 0x54, if (j == 2) 0xae2d50 else 0xae2d30, &out.references[i][j])) return false;
    };
    return true;
}
fn live(scope: *const Scope) bool {
    return coherent_frame_valid(&scope.token, 4) != 0 and read(u32, 0xfb4b6c) == scope.clock;
}
fn sameWitness(scope: *const Scope) bool {
    var now: Witness = undefined;
    return witness(scope.object, &now) and std.mem.eql(u8, std.mem.asBytes(&now), std.mem.asBytes(&scope.source));
}
fn reject(scope: *const Scope, reason: u32) void {
    clonewars_module_rng_debug[3] +%= 1;
    if (clonewars_module_rng_failure[2] == 0) {
        const s = &scope.source;
        const values = [_]u32{ scope.token.epoch, scope.token.sequence, reason, scope.clock, @truncate(scope.object), s.record.id, s.record.generation, s.kind, s.burst_min, s.burst_max, s.channel_count, scope.seed };
        @memcpy(&clonewars_module_rng_failure, &values);
    }
    game_sync_native_fault(15);
}
fn choice(scope: *const Scope) p.SyncPhysicsChoice {
    var result = std.mem.zeroes(p.SyncPhysicsChoice);
    result.kind = p.SYNC_PHYSICS_MODULE_SEED;
    result.site = 0x4da6d0;
    const value = &result.payload.module;
    const s = &scope.source;
    value.clock = scope.clock;
    value.value = scope.seed;
    value.module_id = s.record.id;
    value.module_type = s.kind;
    value.module_generation = s.record.generation;
    value.module_class = 0x6e6b3c;
    value.burst_min = s.burst_min;
    value.burst_max = s.burst_max;
    value.channel_count = s.channel_count;
    value.weapon = s.weapon;
    value.intervals = @bitCast(s.intervals);
    return result;
}
fn invoke(address: usize) callconv(.c) usize {
    const scope: *Scope = @ptrFromInt(address);
    if (scope.bound) {
        if (!live(scope) or !witness(scope.object, &scope.source)) {
            reject(scope, 1);
            return 0;
        }
        var input = choice(scope);
        var expected = input;
        if (!live(scope) or physics_module_input(&input, &scope.token) != 1) {
            reject(scope, 2);
            return 0;
        }
        expected.payload.module.value = input.payload.module.value;
        if (!live(scope) or !sameWitness(scope) or read(u32, 0xea178c) != scope.seed or !std.mem.eql(u8, std.mem.asBytes(&input), std.mem.asBytes(&expected))) {
            reject(scope, 3);
            return 0;
        }
        win.store(u32, 0xea178c, input.payload.module.value);
        clonewars_module_rng_debug[0] +%= 1;
        if (input.payload.module.value != scope.seed) {
            clonewars_module_rng_debug[1] +%= 1;
            if (clonewars_module_rng_correction[0] == 0) {
                const values = [_]u32{ scope.token.epoch, scope.token.sequence, scope.clock, scope.source.record.id, scope.source.record.generation, scope.source.kind, scope.seed, input.payload.module.value };
                @memcpy(&clonewars_module_rng_correction, &values);
            }
        }
    }
    // The original update and its children retain every advance of this shared RNG stream.
    scope.machine.restore();
    @as(*const fn (usize) callconv(.{ .x86_thiscall = .{} }) void, @ptrFromInt(0x4da6d0))(scope.object);
    scope.machine.capture();
    clonewars_module_rng_debug[2] +%= 1;
    return 0;
}
fn abortUpdate(address: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const scope: *Scope = @ptrFromInt(address);
    if (scope.bound) reject(scope, 4);
}
fn updateHook(object: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var scope: Scope = undefined;
    scope.machine.capture();
    scope.token = std.mem.zeroes(Token);
    scope.source = std.mem.zeroes(Witness);
    scope.object = object;
    scope.bound = coherent_frame_get(&scope.token, 4) != 0;
    scope.clock = read(u32, 0xfb4b6c);
    scope.seed = read(u32, 0xea178c);
    _ = constructor_lexical_seh(@intFromPtr(&scope), invoke, abortUpdate);
    scope.machine.restore();
}
fn gunJamWitness(object: usize, candidates: u32, out: *p.SyncPhysicsChoice) bool {
    var source: Witness = undefined;
    if (!registeredModule(object, 0xae36e4, 0xb0, &source)) return false;
    out.* = std.mem.zeroes(p.SyncPhysicsChoice);
    out.kind = p.SYNC_PHYSICS_GUN_JAM_SEED;
    out.site = 0x4acb53;
    const jam = &out.payload.gun_jam;
    jam.clock = read(u32, 0xfb4b6c);
    jam.value = read(u32, 0xea178c);
    jam.module_id = source.record.id;
    jam.module_type = source.kind;
    jam.module_generation = source.record.generation;
    jam.member_count = read(u32, object + 0xac);
    jam.candidate_count = candidates;
    jam.clip = read(i16, object + 0xa4);
    jam.remaining = read(f32, object + 0x98);
    jam.minimum = read(f32, object + 0x9c);
    jam.maximum = read(f32, object + 0xa0);
    return true;
}
pub export fn gun_jam_rng_checkpoint(object: usize, candidates: u32) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var token: Token = undefined;
    if (coherent_frame_get(&token, 4) == 0) return;
    var input: p.SyncPhysicsChoice = undefined;
    var observed: p.SyncPhysicsChoice = undefined;
    if (!gunJamWitness(object, candidates, &input) or physics_module_input(&input, &token) != 1 or !gunJamWitness(object, candidates, &observed) or input.payload.gun_jam.module_generation != observed.payload.gun_jam.module_generation or !physics.sameSource(&input, &observed) or coherent_frame_valid(&token, 4) == 0) {
        clonewars_gun_jam_rng_debug[2] +%= 1;
        game_sync_native_fault(15);
        return;
    }
    const source = &input.payload.gun_jam;
    win.store(u32, 0xea178c, source.value);
    clonewars_gun_jam_rng_debug[0] +%= 1;
    clonewars_gun_jam_rng_debug[3] = source.clock;
    if (source.value != observed.payload.gun_jam.value) {
        clonewars_gun_jam_rng_debug[1] +%= 1;
        if (clonewars_gun_jam_rng_correction[0] == 0) {
            const correction = [_]u32{ token.epoch, token.sequence, source.clock, source.module_id, observed.payload.gun_jam.value, source.value, source.candidate_count, @bitCast(source.clip) };
            @memcpy(&clonewars_gun_jam_rng_correction, &correction);
        }
    }
}
pub export fn module_rng_input_install() c_int {
    if (installed) return 1;
    const slot: *usize = @ptrFromInt(0xae6b64);
    const expected = "\x51\xd9\x05\x74\x4b\xfb\x00\x53\x56\xd9\x5c\x24\x08";
    const draw: usize = 0x4acb53;
    const draw_call = "\xe8\xa8\x65\x0c\x00";
    if (!readable(@intFromPtr(slot), 4) or slot.* != 0x4da6d0 or !readable(0x4da6d0, expected.len) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(0x4da6d0))[0..expected.len], expected) or !readable(draw, draw_call.len) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(draw))[0..draw_call.len], draw_call)) return 0;
    var protection: u32 = 0;
    var ignored: u32 = 0;
    if (win.VirtualProtect(@intFromPtr(slot), 4, 4, &protection) == 0) return 0;
    var draw_protection: u32 = 0;
    if (win.VirtualProtect(draw, draw_call.len, 0x40, &draw_protection) == 0) {
        _ = win.VirtualProtect(@intFromPtr(slot), 4, protection, &ignored);
        return 0;
    }
    const prior = @cmpxchgStrong(usize, slot, 0x4da6d0, @intFromPtr(&updateHook), .seq_cst, .seq_cst);
    _ = win.VirtualProtect(@intFromPtr(slot), 4, protection, &ignored);
    if (prior != null) {
        _ = win.VirtualProtect(draw, draw_call.len, draw_protection, &ignored);
        return 0;
    }
    win.store(u8, draw, 0xe9);
    win.store(u32, draw + 1, @truncate(@intFromPtr(&gun_jam_rng_thunk) -% 0x4acb58));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), draw, draw_call.len);
    _ = win.VirtualProtect(draw, draw_call.len, draw_protection, &ignored);
    installed = true;
    return 1;
}
comptime {
    _ = @import("gun_jam_bridge.zig");
}
