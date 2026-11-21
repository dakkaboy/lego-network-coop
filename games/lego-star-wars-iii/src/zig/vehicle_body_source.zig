const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const win = s.win;
const read = s.read;

pub const Identity = struct { slot: u32, generation: u32, character: u16, actor: usize };

fn components(access: *win.AccessCache) ?[]align(1) const usize {
    const manager = read(usize, 0xfbdb3c);
    if (!access.accessible(manager, 0x160, false)) return null;
    const count = read(u32, manager + 0x15c);
    if (count == 0 or count > 4096 or !access.accessible(manager + 0x160, count * 4, false)) return null;
    return @as([*]align(1) const usize, @ptrFromInt(manager + 0x160))[0..count];
}

fn registered(access: *win.AccessCache, body: usize, flags: u8) ?Identity {
    if (!access.accessible(body, 0xa0, false) or read(usize, body) != 0xc69eac or
        read(u8, body + 0x19) != flags or read(usize, body + 0x28) != 0) return null;
    var result: ?Identity = null;
    for (components(access) orelse return null) |component| {
        if (!access.accessible(component, 0x2a0, false)) return null;
        const driver = read(usize, component + 0x294);
        if (driver == 0) continue;
        if (!access.accessible(driver, 0x264, false)) return null;
        if (read(usize, driver + 0x260) != body) continue;
        if (result != null) return null;
        const actor = read(usize, component + 0x29c);
        if (!access.accessible(actor, 0x1440, false) or read(u32, actor + 0x50) & 3 != 3) return null;
        var slot: u32 = undefined;
        var generation: u32 = undefined;
        if (s.entities_observed_identity(actor, &slot, &generation) == 0 or slot >= p.SYNC_MAX_ACTORS or
            generation == 0 or s.entities_actor(slot, generation) != actor) return null;
        result = .{ .slot = slot, .generation = generation, .character = read(u16, actor + 0xdc0), .actor = actor };
    }
    return result;
}

pub fn identify(access: *win.AccessCache, body: usize) ?Identity {
    return registered(access, body, 0x42);
}

fn primaryBody(access: *win.AccessCache, body: usize, flags: u8, character: u16, comptime expected: anytype) ?Identity {
    const identity = registered(access, body, flags) orelse return null;
    if (identity.character != character) return null;
    const shape = read(usize, body + 0x24);
    if (!access.accessible(shape, 4, false) or read(usize, shape) != 0xc69b0c) return null;
    const name = read(usize, body + 0x1c);
    if (!access.accessible(name, expected.len, false) or !std.meta.eql(read([expected.len]u8, name), expected.*)) return null;
    var registrations: u32 = 0;
    for (components(access) orelse return null) |component| {
        if (!access.accessible(component, 0x2a0, false)) return null;
        if (read(usize, component + 0x29c) == identity.actor and read(usize, component + 0x294) != 0)
            registrations += 1;
    }
    if (registrations != 1) return null;
    return identity;
}

pub fn alignmentBody(access: *win.AccessCache, body: usize, flags: u8) ?Identity {
    if (flags != 0x42 and flags != 0x43) return null;
    return primaryBody(access, body, flags, 417, "BARC2\x00");
}

pub fn rxSuspensionBody(access: *win.AccessCache, body: usize, flags: u8) ?Identity {
    if (flags != 0x42 and flags != 0x43) return null;
    const identity = primaryBody(access, body, flags, 429, "StunTank\x00") orelse return null;
    const name = read(usize, identity.actor + 0x14);
    const expected = "stun_tank_chassis\x00";
    if (!access.accessible(name, expected.len, false) or !std.meta.eql(read([expected.len]u8, name), expected.*)) return null;
    return identity;
}

pub fn supportKey(body: usize, output: *[2]u32) bool {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or lease.cohort.thread != win.GetCurrentThreadId() or s.journal.frame.?.level != 112) return false;
    var access: win.AccessCache = .{};
    const first = alignmentBody(&access, body, 0x42) orelse return false;
    var fresh: win.AccessCache = .{};
    const second = alignmentBody(&fresh, body, 0x42) orelse return false;
    if (!std.meta.eql(first, second) or !s.live(&lease)) return false;
    var hash: @import("fingerprint.zig").Hash = .{};
    hash.bytes("zillo-barc-primary-support");
    hash.number(first.slot);
    hash.number(first.generation);
    hash.number(first.character);
    const key = hash.words[0..2].*;
    if (key[0] == 0 or key[1] == 0) return false;
    output.* = key;
    return true;
}
