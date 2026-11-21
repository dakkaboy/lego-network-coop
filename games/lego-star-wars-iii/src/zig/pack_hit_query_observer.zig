const s = @import("tick_state.zig");
const identity = @import("tick_pack_identity.zig");
pub const words = 424;
pub export var clonewars_pack_hit_queries: [64][words]u32 = @splat(@splat(0));
pub export var clonewars_pack_hit_queries_cursor: u32 = 0;
const offsets = [_]usize{ 0, 4, 8, 0x10, 0x14, 0x18, 0x30, 0x34, 0x38, 0x40, 0x44, 0x48 };
pub fn reset() void {
    clonewars_pack_hit_queries_cursor = 0;
    for (&clonewars_pack_hit_queries) |*entry| entry[0] = 0;
}
pub fn observe(member: usize, stack: usize, id: identity.Identity) void {
    if (!s.ready() or !s.readable(stack, 0x860) or s.load(u32, stack) != 0x45f5a2 or
        s.load(u32, stack + 28) != 0x7a9379 or s.load(u32, stack + 40) != 0x408729 or
        s.load(u32, stack + 48) != 0x6f097c or s.load(u32, stack + 0x844) != 0x6fc9da) return;
    const count = s.load(u32, stack + 12);
    const index = s.load(u32, stack + 36);
    if (count == 0 or count > 512 or index >= count or s.load(usize, stack + 68 + index * 4) != member) return;
    const query = s.load(usize, stack + 0x848);
    const event = s.load(usize, stack + 0x84c);
    if (event != s.load(usize, stack + 32) or !s.readable(event, 12) or s.load(u32, event) != 3 or
        s.load(u32, event + 4) != 0 or !s.readable(query, 0x4c) or s.load(u32, query + 0x20) != 1) return;
    const owner = s.load(usize, event + 8);
    if (!s.readable(owner, 0x1440)) return;
    const pack = s.load(usize, member + 0x68);
    const pool = s.load(usize, pack + 0xb0);
    const grid = if (s.readable(pool, 0x14)) s.load(usize, pool + 0x10) else 0;
    const expected = s.firstExpected();
    var entry: [words]u32 = @splat(0);
    entry[1..16].* = .{ s.frame.?.sequence, s.clock(), member, owner, s.load(u32, stack + 0x85c), @bitCast(s.entities_slot(owner)), s.entities_generation(owner), event, count, index, pack, grid, s.load(u32, pack + 0xac), 0, id.key() };
    for (offsets, entry[16..28]) |offset, *value| value.* = s.load(u32, query + offset);
    entry[28..31].* = s.load([3]u32, owner + 0x24);
    entry[31] = s.load(u16, owner + 0xdc0);
    entry[32] = s.load(u32, owner + 0x50);
    entry[33] = if (expected) |gate| gate.value else 0;
    entry[34] = if (expected) |gate| gate.site else 0;
    entry[35] = if (expected) |gate| gate.clock else 0;
    entry[36] = pool;
    entry[37] = s.load(usize, pack + 0xa0);
    entry[38] = id.index;
    entry[39] = id.witness;
    var current = entry[37];
    for (0..32) |ordinal| {
        if (current == 0 or !s.readable(current, 0x80) or s.load(usize, current + 0x68) != pack) break;
        const fields = [_]u32{ s.load(u32, pack + 0x13c), s.load(u32, pack + 0x140), 0, s.load(u32, pack + 0xf8), s.load(u32, pack + 0xfc), s.load(u32, current + 0x6c), s.load(u32, current + 0x70) };
        var witness: u32 = 2166136261;
        for (fields) |field| witness = (witness ^ field) *% 16777619;
        const member_index = (id.index & 0xffff0000) | @as(u32, @intCast(ordinal));
        var result_order: u32 = 0;
        for (0..count) |result| if (s.load(usize, stack + 68 + result * 4) == current) {
            result_order = @intCast(result + 1);
            break;
        };
        const row = entry[40 + ordinal * 12 ..][0..12];
        row[0..4].* = .{ current, member_index, witness, (witness ^ member_index) *% 16777619 };
        row[4..7].* = s.load([3]u32, current + 0x20);
        row[7..12].* = .{ s.load(usize, current + 0x38), s.load(usize, current + 0x3c), fields[5], fields[6], @as(u32, s.load(u8, current + 0x60)) | result_order << 8 };
        entry[14] += 1;
        current = s.load(usize, current + 0x7c);
    }
    const cursor = clonewars_pack_hit_queries_cursor;
    const destination = &clonewars_pack_hit_queries[cursor % 64];
    @atomicStore(u32, &destination[0], 0, .release);
    destination.* = entry;
    @atomicStore(u32, &destination[0], s.frame.?.epoch, .release);
    @atomicStore(u32, &clonewars_pack_hit_queries_cursor, cursor +% 1, .release);
}
