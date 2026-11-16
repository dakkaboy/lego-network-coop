const win = @import("win32.zig");
pub const Source = extern struct { manager: usize, pool: usize, definition: usize, pack: usize, faction: u32 };
pub export fn native_global_pack_registry_count() c_uint {
    if (!win.accessible(0x47699b, 3, false)) return 0;
    const opcode = win.load([3]u8, 0x47699b);
    return if (opcode[0] == 0x83 and opcode[1] == 0xfe and opcode[2] != 0 and opcode[2] < 0x80) opcode[2] else 0;
}
pub export fn native_global_pack_source(pack: usize, output: ?*Source) c_int {
    const count = native_global_pack_registry_count();
    if (output == null or count == 0 or !win.accessible(pack, 0x144, false) or win.load(u32, pack) != 0xadcef0) return 0;
    var source: Source = .{ .pack = pack, .manager = win.load(usize, pack + 0xb8), .pool = win.load(usize, pack + 0xb0), .definition = win.load(usize, pack + 0xb4), .faction = 0 };
    if (!win.accessible(source.manager, 0x180 + count * 4, false) or win.load(u32, source.manager) != 0xaded84 or
        !win.accessible(source.pool, 0x24, false) or win.load(usize, source.pool + 8) != source.manager or
        !win.accessible(source.definition, 0x34, false) or win.load(u32, source.definition) != 0xad7f74 or
        win.load(usize, source.definition + 4) != source.pool or win.load(usize, source.definition + 0x10) != pack or win.load(usize, source.definition + 0x30) != source.manager) return 0;
    source.faction = win.load(u32, source.definition + 0x18);
    if (source.faction >= count or win.load(usize, source.manager + 0x180 + source.faction * 4) != source.definition or
        win.load(u32, pack + 0x140) != source.faction or win.load(u32, pack + 0x13c) != win.load(u32, source.definition + 0x1c)) return 0;
    const pool_count = win.load(u32, source.manager + 0x28);
    if (pool_count == 0 or pool_count > 65535) return 0;
    var node = win.load(usize, source.manager + 0x20);
    var matches: u32 = 0;
    for (0..pool_count) |_| {
        if (!win.accessible(node, 0xc, false) or win.load(usize, node + 8) != source.manager) return 0;
        matches += @intFromBool(node == source.pool);
        node = win.load(usize, node + 4);
    }
    if (node != 0 or matches != 1) return 0;
    output.?.* = source;
    return 1;
}
