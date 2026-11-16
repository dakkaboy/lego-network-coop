const s = @import("tick_state.zig");
const load = s.load;
const store = s.store;
const readable = s.readable;
const coefficients = [_]u32{ 0xfb0fc4, 0xfb0fa8, 0xfb0fb4, 0xfb102c, 0xfb0fb0, 0xfb0fac, 0xfb1028, 0xfb0fa0, 0xfb1014, 0xfb0fc0, 0xfb1070, 0xfb1018, 0xfb101c, 0xfb0fb8, 0xfb0fa4, 0xfb0fbc, 0xfb0fc8 };
pub fn finite(value: u32) bool {
    return value & 0x7fffffff < 0x7f800000;
}
fn byte(hash: *[2]u32, value: u8) void {
    hash[0] = (hash[0] ^ value) *% 16777619;
    hash[1] = (hash[1] ^ value) *% 0x85ebca6b;
}
fn text(hash: *[2]u32, address: usize) bool {
    if (address == 0) return false;
    for (0..512) |i| {
        if (!readable(address + i, 1)) return false;
        const value = load(u8, address + i);
        byte(hash, value);
        if (value == 0) return i != 0;
    }
    return false;
}
fn descriptor(hash: *[2]u32, address: usize) bool {
    if (!readable(address, 0xc0)) return false;
    const level = load(i16, address + 0x10);
    const ordinal = load(u16, address + 0x16);
    if (level < -1 or level >= 4096 or !text(hash, load(usize, address + 0xc)) or !text(hash, load(usize, address + 8))) return false;
    const bits: u16 = @bitCast(level);
    byte(hash, @truncate(bits));
    byte(hash, @truncate(bits >> 8));
    byte(hash, @truncate(ordinal));
    byte(hash, @truncate(ordinal >> 8));
    return true;
}
fn witness(track: usize, hash: *[2]u32, level: i32) bool {
    const world = load(usize, 0xfb4a20);
    const manager = load(usize, 0xe901f4);
    const tracks = load(usize, 0xfa1c98);
    if (!readable(world, 0x224) or !readable(manager, 0x90) or !readable(tracks, 0x34)) return false;
    const definition = load(usize, world + 0x220);
    if (!readable(definition, 0x96) or load(i16, definition + 0x94) != level) return false;
    const current = load(usize, manager + 0x84);
    const instance = load(usize, manager + 0x88);
    if (!readable(instance, 0x14)) return false;
    const request = load(usize, instance + 0xc);
    if (!readable(request, 0x18) or load(usize, request + 8) != current) return false;
    const provider = load(usize, request + 0x14);
    if (!readable(provider, 0xc)) return false;
    const owner = load(usize, provider);
    const limit = load(u32, manager + 0x30);
    if (limit == 0 or limit > 4096) return false;
    var node = load(usize, manager + 0x28);
    var current_matches: u32 = 0;
    var owner_matches: u32 = 0;
    var i: u32 = 0;
    while (node != 0 and i < limit) : (i += 1) {
        if (!readable(node, 0xc0)) return false;
        current_matches += @intFromBool(node == current);
        owner_matches += @intFromBool(node == owner);
        node = load(usize, node + 4);
    }
    if (node != 0 or current_matches != 1 or owner_matches != 1) return false;
    const components = load(usize, owner + 0xa0);
    if (!readable(components, 0x24)) return false;
    const handle = load(usize, components + 0x20);
    if (handle == 0) return false;
    var matched: usize = 0;
    for (0..3) |j| {
        const entry = load(usize, tracks + 0x28 + j * 4);
        if (entry == 0) continue;
        if (!readable(entry, 0xc)) return false;
        if (load(usize, entry + 4) != handle) continue;
        if (matched != 0) return false;
        matched = entry;
    }
    if (matched != track) return false;
    hash.* = .{ 2166136261, 0x9e3779b9 };
    return descriptor(hash, current) and descriptor(hash, owner);
}
pub export fn native_tick_clock_input(hash: ?*const [2]u32, sample: u32) u32 {
    if (!s.ready()) return sample;
    const time = s.clock();
    if (hash == null or !finite(sample)) {
        s.fail(6, 0x7b8b08, time, null);
        return sample;
    }
    const sites = [_]u32{ 0x7b8ae1, 0x7b8afd, 0x7b8b08 };
    const values = [_]u32{ hash.?[0], hash.?[1], sample };
    if (s.host) {
        if (!s.capacity(3, 0x7b8b08)) return sample;
        const f = s.frame.?;
        for (sites, values) |at, value| {
            f.tick_gates[f.tick_gate_count] = .{ .site = at, .clock = time, .value = value };
            f.tick_gate_count += 1;
        }
        s.clonewars_native_tick_debug[0] +%= 3;
        s.clonewars_native_clock_debug[0] +%= 1;
        return sample;
    }
    const expected = s.expected(3) orelse {
        s.fail(5, 0x7b8b08, time, null);
        return sample;
    };
    for (expected, sites, values, 0..) |gate, at, value, i| if (!s.valid.gateValid(gate) or gate.site != at or gate.clock != time or (i < 2 and gate.value != value)) {
        s.fail(5, at, time, &expected[i]);
        return sample;
    };
    const result = expected[2].value;
    s.cursor += 3;
    s.clonewars_native_tick_debug[1] +%= 3;
    s.clonewars_native_clock_debug[1] +%= 1;
    if (result != sample) {
        s.clonewars_native_clock_debug[2] +%= 1;
        if (s.clonewars_native_clock_correction[0] == 0) s.clonewars_native_clock_correction = .{ s.frame.?.epoch, s.frame.?.sequence, time, hash.?[0], hash.?[1], sample, result, s.cursor - 3, 0x7b8b08, 0 };
    }
    return result;
}
pub export fn native_track_clock(track: usize) callconv(.{ .x86_thiscall = .{} }) f32 {
    const getter: *const fn (usize) callconv(.{ .x86_thiscall = .{} }) f32 = @ptrFromInt(0x6c11d0);
    var sample: f32 = if (track != 0) getter(track) else load(f32, 0xad76dc);
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const preload_level = s.game_sync_preload_level();
    var hash: [2]u32 = undefined;
    if (preload_level >= 0) sample = @bitCast(s.game_sync_preload_track_input(if (witness(track, &hash, preload_level)) &hash else null, @bitCast(sample))) else if (s.ready()) {
        if (!witness(track, &hash, s.frame.?.level)) {
            s.clonewars_native_clock_debug[3] +%= 1;
            s.fail(6, 0x7b8b08, s.clock(), null);
        } else sample = @bitCast(native_tick_clock_input(&hash, @bitCast(sample)));
    }
    return sample;
}
pub export fn native_tick_elapsed_input() c_int {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (!s.ready()) return 0;
    const local = load(u32, s.site.GAME_TIME);
    const time = s.clock();
    var values: [coefficients.len]u32 = undefined;
    var canonical: [coefficients.len]u32 = undefined;
    for (coefficients, &values) |at, *value| {
        value.* = load(u32, at);
        if (!(value.* <= 0x3f800000 or value.* == 0x80000000)) {
            s.fail(6, at, time, null);
            return 0;
        }
    }
    if (!finite(local)) {
        s.fail(6, s.site.GAME_TIME, time, null);
        return 0;
    }
    const result = s.decision(s.site.GAME_TIME, local);
    for (coefficients, values, &canonical) |at, value, *output| output.* = s.decision(at, value);
    if (!s.ready()) return 0;
    store(u32, s.site.GAME_TIME, result);
    for (coefficients, canonical) |at, value| store(u32, at, value);
    s.clonewars_native_elapsed_debug[@intFromBool(!s.host)] +%= 1;
    if (!s.host and !@import("std").mem.eql(u32, &values, &canonical)) s.clonewars_native_elapsed_debug[2] +%= 1;
    if (!s.host and local != result) s.clonewars_native_elapsed_debug[3] +%= 1;
    return 1;
}
