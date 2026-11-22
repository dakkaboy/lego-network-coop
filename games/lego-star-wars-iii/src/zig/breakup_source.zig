const win = @import("win32.zig");
const Hash = @import("fingerprint.zig").Hash;
const Entry = struct { resource: usize = 0, runtime: usize = 0, key: [4]u32 = @splat(0) };
var entries: [@import("protocol.zig").SYNC_MAX_ACTORS]Entry = @splat(.{});
var current_epoch: u32 = 0;
pub export var clonewars_breakup_source_debug: [6]u32 = @splat(0);
pub const rts_breakup_site = 0x54ef4d;
pub const team_breakup_site = 0x540475;
pub const team_breakup_type = 0x1f;

fn span(address: usize, length: usize) bool {
    return win.accessible(address, length, false);
}
fn load(address: usize) usize {
    return win.load(usize, address);
}
pub fn teamBreakupKey(world: usize, source: usize, receiver: usize, mesh: [2]u32) ?[2]u32 {
    if (!span(source, 0x14c) or receiver == 0 or load(source + 0x14) != receiver or
        load(source + 0x140) != source or load(source + 0x148) != 1 or load(source + 0xc) != team_breakup_type) return null;
    const team = load(source + 8);
    if (!span(team, 0x1820) or load(team) != 0xaef0fc) return null;
    const resource = load(team + 0x10d0);
    const descriptor = load(team + 0x1c);
    if (world == 0 or !span(resource, 0x10) or load(resource + 0xc) != world or !span(descriptor, 0x34)) return null;
    const slot = load(descriptor + 0x30);
    const count = load(team + 0x181c);
    if (slot >= @import("protocol.zig").SYNC_MAX_RTS_TEAMS or count == 0 or count > 65535) return null;

    // The native team owns an intrusive list, with forward links at +4.
    var list = load(team + 0x1814);
    var previous: usize = 0;
    var ordinal: ?u32 = null;
    var hash: Hash = .{};
    hash.bytes("team-breakup");
    hash.number(@intCast(slot));
    hash.number(@intCast(count));
    for (0..count) |index| {
        if (!span(list, 0x14) or load(list) != previous or load(list + 8) != team) return null;
        const kind = win.load(u32, list + 0xc);
        if (kind >= 0x23) return null;
        hash.number(kind);
        if (list == source) ordinal = @intCast(index);
        previous = list;
        list = load(list + 4);
    }
    if (list != 0 or previous != load(team + 0x1818)) return null;
    hash.number(ordinal orelse return null);
    for (mesh) |word| hash.number(word);
    return hash.words[0..2].*;
}
fn epoch(value: u32) void {
    if (value == current_epoch) return;
    entries = @splat(.{});
    current_epoch = value;
    clonewars_breakup_source_debug[2] = value;
}
fn anonymous(mesh: usize) bool {
    if (!span(mesh, 0xb8)) return false;
    const name = load(mesh + 0xb4);
    return name == 0 or (span(name, 1) and (win.load(u8, name) == 0 or win.load(u8, name) == 255));
}
pub fn register(handle: usize, model: usize, next_epoch: u32) bool {
    epoch(next_epoch);
    if (!span(handle, 8) or !anonymous(load(handle + 4)) or !span(model, 0x9d8)) return false;
    const resource = load(handle);
    if (!span(resource, 0x738)) return false;
    const definition = load(model + 0x18);
    if (!span(definition, 0x20)) return false;
    const asset = load(definition + 0x1c);
    if (!span(asset, 0x48) or win.load(u32, asset + 0x18) != 2) return false;
    const root = load(asset + 0x44);
    if (root != resource and (root == 0 or load(resource + 0x734) != root)) return false;
    const runtime = load(resource + 0x6f8);
    if (!span(runtime, 0x70)) return false;
    var hash: Hash = .{};
    hash.bytes("anonymous-breakup-mesh");
    hash.number(if (root == resource) 0 else win.load(u32, model + 0x9d4));
    const name = load(asset + 0x34);
    if (name == 0) return false;
    for (0..512) |i| {
        if (!span(name + i, 1)) return false;
        const value = win.load(u8, name + i);
        if (value == 0) {
            if (i == 0) return false;
            var free: ?*Entry = null;
            for (&entries) |*entry| {
                if (entry.resource == resource) {
                    entry.* = .{ .resource = resource, .runtime = runtime, .key = hash.words };
                    clonewars_breakup_source_debug[0] +%= 1;
                    return true;
                }
                if (entry.resource == 0 and free == null) free = entry;
            }
            const entry = free orelse return false;
            entry.* = .{ .resource = resource, .runtime = runtime, .key = hash.words };
            clonewars_breakup_source_debug[0] +%= 1;
            return true;
        }
        hash.byte(value);
    }
    return false;
}
pub fn resolve(handle: usize, next_epoch: u32, out: *[2]u32) bool {
    epoch(next_epoch);
    if (!span(handle, 8)) return false;
    const mesh = load(handle + 4);
    if (!span(mesh, 0xb8)) return false;
    const name = load(mesh + 0xb4);
    if (!anonymous(mesh)) {
        var hash: u32 = 2166136261;
        var second: u32 = 0x9e3779b9;
        for (0..128) |i| {
            if (!span(name +% i, 1)) return false;
            const value = win.load(u8, name +% i);
            if (value == 0 or value == 255) {
                out.* = .{ hash, second };
                return true;
            }
            hash = (hash ^ value) *% 16777619;
            second = (second ^ value) *% 0x85ebca6b;
        }
        return false;
    }
    // Starhawk and other native assets can have unnamed meshes. Keep the asset
    // filename from the launching model for constructors and later spin updates.
    const resource = load(handle);
    for (&entries) |*entry| {
        if (entry.resource != resource or resource == 0) continue;
        if (!span(resource, 0x6fc) or load(resource + 0x6f8) != entry.runtime or !span(entry.runtime, 0x70)) return false;
        const array = load(entry.runtime + 0x6c);
        const count = win.load(u32, entry.runtime + 0x68);
        if (array == 0 or mesh < array or (mesh - array) % 0xe0 != 0) return false;
        const index = (mesh - array) / 0xe0;
        if (index >= count or count > 65536) return false;
        var hash: Hash = .{ .words = entry.key };
        hash.number(@intCast(index));
        out.* = hash.words[0..2].*;
        clonewars_breakup_source_debug[1] +%= 1;
        clonewars_breakup_source_debug[3..6].* = .{ @intCast(index), out[0], out[1] };
        return true;
    }
    return false;
}
