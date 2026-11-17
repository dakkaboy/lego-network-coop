const std = @import("std");
const s = @import("tick_state.zig");
const identity = @import("tick_pack_identity.zig");
const v = s.site;
pub export var clonewars_pack_spawn_debug: [6]u32 = @splat(0);
pub export var clonewars_pack_spawn_correction: [24]u32 = @splat(0);
pub export var clonewars_pack_spawn_context: [32]u32 = @splat(0);
pub export var clonewars_pack_spawn_births: [64][24]u32 = @splat(@splat(0));
pub export var clonewars_pack_spawn_births_cursor: u32 = 0;
pub export var pack_spawn_random: usize = 0x6d60d0;
pub export var pack_spawn_allocate: usize = 0x6d75e0;
const Source = struct { bytes: [0xcc]u8, pack: usize, identity: identity.Identity, values: [7]u32 };
const Draw = struct { epoch: u32, sequence: u32, clock: u32, source: usize, pool: usize, values: [7]u32, local: u32, canonical: u32, complete: bool };
var draw: ?Draw = null;
pub fn reset() void {
    draw = null;
    clonewars_pack_spawn_debug = @splat(0);
    clonewars_pack_spawn_correction = @splat(0);
    clonewars_pack_spawn_context = @splat(0);
    clonewars_pack_spawn_births_cursor = 0;
    for (&clonewars_pack_spawn_births) |*entry| entry[0] = 0;
}
fn reject(at: u32) void {
    clonewars_pack_spawn_debug[3] +%= 1;
    s.fail(4, at, s.clock(), s.firstExpected());
}
fn hash(values: []const u32) u32 {
    var result: u32 = 2166136261;
    for (values) |value| result = (result ^ value) *% 16777619;
    return result;
}
fn describe(source: usize, pool: usize, bounds: [2]u32) ?Source {
    if (!s.readable(source, 0xcc) or s.load(u8, source + 0x80) == 0 or !s.readable(pool, 0x24)) return null;
    const pack = s.load(usize, source + 0xac);
    const id = identity.packSource(pack) orelse return null;
    if (s.load(usize, pack + 0xb0) != pool) return null;
    const base = s.load([5]u32, source + 0x60);
    for (base) |value| if (value & 0x7fffffff >= 0x7f800000) return null;
    if (@as(f32, @bitCast(base[4])) < 0) return null;
    for (bounds) |value| if (value & 0x7fffffff >= 0x7f800000) return null;
    if (@as(f32, @bitCast(bounds[0])) > @as(f32, @bitCast(bounds[1]))) return null;
    const row = s.load(u32, source + 0xb4);
    const slot = s.load(u32, source + 0xb0);
    const skin = s.load(u32, source + 0xc8);
    if (row > 65535 or slot > 65535 or skin > 65535) return null;
    return .{ .bytes = s.load([0xcc]u8, source), .pack = pack, .identity = id, .values = .{ id.index, id.witness, row, slot, skin, hash(&base), hash(&bounds) } };
}
fn sameDraw(previous: Draw, source: usize, pool: usize, values: *const [7]u32) bool {
    return previous.epoch == s.frame.?.epoch and previous.sequence == s.frame.?.sequence and previous.clock == s.clock() and
        previous.source == source and previous.pool == pool and std.mem.eql(u32, &previous.values, values);
}
fn birth(source: usize, pool: usize, stack: usize) void {
    const previous = draw orelse return;
    if (!previous.complete or !sameDraw(previous, source, pool, &previous.values) or !s.readable(source, 0xcc) or
        !s.readable(stack, 16) or s.load(u32, stack) != v.PACK_SPAWN_BIRTH + 5 or
        s.load(u32, stack + 4) != previous.values[4] or s.load(u32, stack + 12) > 65535) return;
    const position = s.load(usize, stack + 8);
    if (!s.readable(position, 16)) return;
    const pack = s.load(usize, source + 0xac);
    const id = identity.packSource(pack) orelse return;
    if (id.index != previous.values[0] or id.witness != previous.values[1] or s.load(usize, pack + 0xb0) != pool or
        s.load(u32, source + 0xb4) != previous.values[2] or s.load(u32, source + 0xb0) != previous.values[3]) return;
    var entry: [24]u32 = @splat(0);
    entry[1..8].* = .{ previous.sequence, previous.clock, id.index, id.witness, previous.values[2], previous.values[3], previous.values[4] };
    entry[8..12].* = s.load([4]u32, source + 0x60);
    entry[12] = s.load(u32, source + 0x70);
    entry[13..17].* = s.load([4]u32, position);
    entry[17..24].* = .{ s.load(u32, stack + 12), s.load(u32, 0xea178c), previous.local, previous.canonical, source, pool, @intFromBool(!s.host) };
    const cursor = clonewars_pack_spawn_births_cursor;
    const destination = &clonewars_pack_spawn_births[cursor % 64];
    @atomicStore(u32, &destination[0], 0, .release);
    destination.* = entry;
    @atomicStore(u32, &destination[0], previous.epoch, .release);
    @atomicStore(u32, &clonewars_pack_spawn_births_cursor, cursor +% 1, .release);
    clonewars_pack_spawn_debug[4 + @as(usize, @intFromBool(!s.host))] +%= 1;
    draw = null;
}
pub export fn native_pack_spawn_input(source: usize, pool: usize, stack: usize, at: u32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (!s.ready()) return;
    clonewars_pack_spawn_context = @splat(0);
    clonewars_pack_spawn_context[0..7].* = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), at, source, pool, stack };
    if (at == v.PACK_SPAWN_BIRTH) {
        birth(source, pool, stack);
        return;
    }
    if ((at != v.PACK_SPAWN_X and at != v.PACK_SPAWN_Z) or !s.readable(stack, 12) or s.load(u32, stack) != at + 5) {
        reject(at);
        return;
    }
    const bounds = s.load([2]u32, stack + 4);
    const description = describe(source, pool, bounds) orelse {
        reject(at);
        return;
    };
    clonewars_pack_spawn_context[8..15].* = description.values;
    clonewars_pack_spawn_context[15] = s.load(u32, 0xea178c);
    if (s.expected(8)) |expected| for (clonewars_pack_spawn_context[16..24], expected) |*value, gate| { value.* = gate.value; };
    clonewars_pack_spawn_context[24..29].* = s.load([5]u32, source + 0x60);
    if (at == v.PACK_SPAWN_Z and (draw == null or draw.?.complete or !sameDraw(draw.?, source, pool, &description.values))) {
        reject(at);
        return;
    }
    const local_seed = s.load(u32, 0xea178c);
    var local: [8]u32 = undefined;
    local[0..7].* = description.values;
    local[7] = local_seed;
    const sites = s.consecutive(8, at, 1);
    if (s.host) {
        if (!s.capacity(8, at)) return;
    } else if (!s.match(&local, &sites, 7, true)) return;
    var result: [8]u32 = undefined;
    s.run(&local, &sites, &result);
    if (!s.ready()) return;
    const fresh = describe(source, pool, bounds) orelse {
        reject(at);
        return;
    };
    if (!std.mem.eql(u8, &description.bytes, &fresh.bytes) or !std.mem.eql(u32, &description.values, &fresh.values)) {
        reject(at);
        return;
    }
    clonewars_pack_spawn_debug[@intFromBool(!s.host)] +%= 1;
    if (at == v.PACK_SPAWN_X) draw = .{ .epoch = s.frame.?.epoch, .sequence = s.frame.?.sequence, .clock = s.clock(), .source = source, .pool = pool, .values = description.values, .local = local_seed, .canonical = result[7], .complete = false } else draw.?.complete = true;
    if (!s.host and local_seed != result[7]) {
        clonewars_pack_spawn_debug[2] +%= 1;
        if (clonewars_pack_spawn_correction[0] == 0) {
            clonewars_pack_spawn_correction[0..15].* = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), at, description.values[0], description.values[1], description.values[2], description.values[3], description.values[4], local_seed, result[7], source, pool, bounds[0], bounds[1] };
            clonewars_pack_spawn_correction[15..20].* = s.load([5]u32, source + 0x60);
        }
        s.store(u32, 0xea178c, result[7]);
    }
}
