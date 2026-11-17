const s = @import("tick_state.zig");
const std = @import("std");
const membership = @import("tick_pack_mutation.zig");
const load = s.load;
const GlobalSource = extern struct { manager: usize, pool: usize, definition: usize, pack: usize, faction: u32 };
extern fn native_global_pack_source(usize, *GlobalSource) c_int;
extern "kernel32" fn K32QueryWorkingSetEx(usize, *anyopaque, u32) callconv(.winapi) c_int;
pub export var clonewars_pack_memory_debug: [6]u32 = @splat(0);
fn queryPages(process: usize, pages: *anyopaque, bytes: u32) callconv(.winapi) c_int {
    clonewars_pack_memory_debug[1] +%= 1;
    return K32QueryWorkingSetEx(process, pages, bytes);
}
fn queryRegion(address: usize, info: *s.win.MemoryInfo, bytes: usize) callconv(.winapi) usize {
    clonewars_pack_memory_debug[2] +%= 1;
    return s.win.VirtualQuery(address, info, bytes);
}
const ListMemory = @import("list_memory.zig").ResidentCacheWithPages(queryRegion, @import("page_access.zig").ResidentPagesWithQuery(queryPages));
var page_hints: [128]usize = @splat(0);
var page_hint_count: usize = 0;
var compact_hints: [128]usize = @splat(0);
var compact_hint_count: usize = 0;
var compact_hint_member: usize = 0;
const OrdinalKey = struct { pack: usize, member: usize, head: usize, count: u32, revision: u32, epoch: u32, sequence: u32, clock: u32, host: bool };
const Ordinal = struct { key: OrdinalKey, index: u32, previous: usize, next: usize };
var ordinal: ?Ordinal = null;
pub export var clonewars_pack_ordinal_debug: [4]u32 = @splat(0);
fn rememberHints(pages: anytype, compact: bool, member: usize) void {
    var addresses: [128]usize = undefined;
    const count = pages.hints(&addresses);
    const target = if (compact) &compact_hints else &page_hints;
    for (addresses[0..count], 0..) |address, i| @atomicStore(usize, &target[i], address, .monotonic);
    @atomicStore(usize, if (compact) &compact_hint_count else &page_hint_count, count, .release);
    if (compact) @atomicStore(usize, &compact_hint_member, member, .release);
}

pub const Identity = struct {
    index: u32,
    witness: u32,
    pub fn key(self: Identity) u32 {
        return (self.witness ^ self.index) *% 16777619;
    }
};
pub fn packSource(pack: usize) ?Identity {
    if (!s.readable(pack, 0x144) or load(u32, pack) != 0xadcef0) return null;
    const manager = load(usize, pack + 0xb8);
    const pool = load(usize, pack + 0xb0);
    if (!s.readable(manager, 0x110) or load(u32, manager) != 0xaded84 or
        !s.readable(pool, 0x24) or load(usize, pool + 8) != manager) return null;
    const list = load(usize, manager + 0x10c);
    if (!s.readable(list, 4)) return null;
    var current = load(usize, list);
    var index: u32 = 0;
    while (current != 0 and current != pack) {
        if (index >= 65535 - 255 or !s.readable(current, 0x18) or load(u32, current) != 0xadcef0) return null;
        current = load(usize, current + 0x14);
        index += 1;
    }
    if (current != pack) {
        var source: GlobalSource = undefined;
        if (native_global_pack_source(pack, &source) == 0) return null;
        index = 65535 - source.faction;
    }
    var witness: u32 = 2166136261;
    for ([_]u32{ load(u32, pack + 0x13c), load(u32, pack + 0x140), load(u32, pack + 0xf8), load(u32, pack + 0xfc) }) |value|
        witness = (witness ^ value) *% 16777619;
    return .{ .index = index, .witness = witness };
}
pub fn resolve(member: usize, with_target: bool) ?Identity {
    clonewars_pack_memory_debug[0] +%= 1;
    var memory = ListMemory{};
    var hints: [128]usize = undefined;
    const compact = @atomicLoad(usize, &compact_hint_member, .acquire) == member;
    const hint_source = if (compact) &compact_hints else &page_hints;
    const count = @min(@atomicLoad(usize, if (compact) &compact_hint_count else &page_hint_count, .acquire), hints.len);
    for (hints[0..count], 0..) |*address, i| address.* = @atomicLoad(usize, &hint_source[i], .monotonic);
    // Address hints never carry permissions across a native call.
    memory.resident_pages.prefetch(hints[0..count]);
    var reused_ordinal = false;
    defer rememberHints(&memory.resident_pages, reused_ordinal, member);
    const packs = &memory;
    const members = &memory;
    if (!members.contains(member, 0x80)) return null;
    const pack = load(usize, member + 0x68);
    if (!packs.contains(pack, 0x144) or load(usize, pack) != 0xadcef0) return null;
    const manager = load(usize, pack + 0xb8);
    const list = if (packs.contains(manager, 0x110) and load(usize, manager) == 0xaded84) load(usize, manager + 0x10c) else 0;
    const definition = load(usize, pack + 0xb4);
    if (!packs.contains(list, 4) or (with_target and !packs.contains(definition, 0x20))) return null;
    var current = load(usize, list);
    var pack_index: u32 = 0;
    while (current != 0 and current != pack) {
        clonewars_pack_memory_debug[3] +%= 1;
        if (pack_index >= 65535 - 255 or !packs.contains(current, 0x18) or load(usize, current) != 0xadcef0) return null;
        current = load(usize, current + 0x14);
        pack_index += 1;
    }
    if (current != pack) {
        clonewars_pack_memory_debug[5] +%= 1;
        var source: GlobalSource = undefined;
        if (native_global_pack_source(pack, &source) == 0) return null;
        pack_index = 65535 - source.faction;
        s.clonewars_native_global_pack_debug[@intFromBool(!s.host)] +%= 1;
    }
    current = load(usize, pack + 0xa0);
    var member_index: u32 = 0;
    var previous: usize = 0;
    const frame = s.frame;
    const memoize = frame != null and @atomicLoad(u32, &membership.clonewars_pack_membership_observer_active, .acquire) != 0;
    const key: OrdinalKey = .{ .pack = pack, .member = member, .head = current, .count = load(u32, pack + 0xac), .revision = @atomicLoad(u32, &membership.clonewars_pack_membership_revision, .monotonic), .epoch = if (frame) |f| f.epoch else 0, .sequence = if (frame) |f| f.sequence else 0, .clock = load(u32, 0xfb4b6c), .host = s.host };
    var hit = false;
    // The native removal/reuse observers invalidate ordinals before links can change.
    if (memoize) if (ordinal) |saved| {
        if (std.meta.eql(saved.key, key) and load(usize, member + 0x7c) == saved.next and members.contains(current, 0x80) and load(usize, current + 0x68) == pack and
            (saved.previous == 0 or (members.contains(saved.previous, 0x80) and load(usize, saved.previous + 0x68) == pack and load(usize, saved.previous + 0x7c) == member)))
        {
            member_index = saved.index;
            previous = saved.previous;
            hit = true;
            reused_ordinal = true;
            clonewars_pack_ordinal_debug[0] +%= 1;
        }
    };
    if (!hit) {
        clonewars_pack_ordinal_debug[1] +%= 1;
        while (current != member) {
            clonewars_pack_memory_debug[4] +%= 1;
            if (member_index == 65535 or !members.contains(current, 0x80) or load(usize, current + 0x68) != pack) return null;
            previous = current;
            current = load(usize, current + 0x7c);
            member_index += 1;
        }
    }
    if (memoize) ordinal = .{ .key = key, .index = member_index, .previous = previous, .next = load(usize, member + 0x7c) };
    const fields = [_]u32{ load(u32, pack + 0x13c), load(u32, pack + 0x140), if (with_target) load(u32, definition + 0x1c) else 0, load(u32, pack + 0xf8), load(u32, pack + 0xfc), load(u32, member + 0x6c), load(u32, member + 0x70) };
    var witness: u32 = 2166136261;
    for (fields) |value| witness = (witness ^ value) *% 16777619;
    return .{ .index = pack_index << 16 | member_index, .witness = witness };
}
