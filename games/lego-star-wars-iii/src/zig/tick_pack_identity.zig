const s = @import("tick_state.zig");
const load = s.load;
const GlobalSource = extern struct { manager: usize, pool: usize, definition: usize, pack: usize, faction: u32 };
extern fn native_global_pack_source(usize, *GlobalSource) c_int;
const ListMemory = @import("list_memory.zig").ResidentCache(s.win.VirtualQuery);

pub const Identity = struct {
    index: u32,
    witness: u32,
    pub fn key(self: Identity) u32 {
        return (self.witness ^ self.index) *% 16777619;
    }
};
pub fn resolve(member: usize, with_target: bool) ?Identity {
    var packs = ListMemory{};
    var members = ListMemory{};
    const pack = load(usize, member + 0x68);
    if (!packs.contains(pack, 0x144) or load(usize, pack) != 0xadcef0) return null;
    const manager = load(usize, pack + 0xb8);
    const list = if (packs.contains(manager, 0x110) and load(usize, manager) == 0xaded84) load(usize, manager + 0x10c) else 0;
    const definition = load(usize, pack + 0xb4);
    if (!packs.contains(list, 4) or (with_target and !packs.contains(definition, 0x20))) return null;
    var current = load(usize, list);
    var pack_index: u32 = 0;
    while (current != 0 and current != pack) {
        if (pack_index >= 65535 - 255 or !packs.contains(current, 0x18) or load(usize, current) != 0xadcef0) return null;
        current = load(usize, current + 0x14);
        pack_index += 1;
    }
    if (current != pack) {
        var source: GlobalSource = undefined;
        if (native_global_pack_source(pack, &source) == 0) return null;
        pack_index = 65535 - source.faction;
        s.clonewars_native_global_pack_debug[@intFromBool(!s.host)] +%= 1;
    }
    current = load(usize, pack + 0xa0);
    var member_index: u32 = 0;
    while (current != member) {
        if (member_index == 65535 or !members.contains(current, 0x80) or load(usize, current + 0x68) != pack) return null;
        current = load(usize, current + 0x7c);
        member_index += 1;
    }
    const fields = [_]u32{ load(u32, pack + 0x13c), load(u32, pack + 0x140), if (with_target) load(u32, definition + 0x1c) else 0, load(u32, pack + 0xf8), load(u32, pack + 0xfc), load(u32, member + 0x6c), load(u32, member + 0x70) };
    var witness: u32 = 2166136261;
    for (fields) |value| witness = (witness ^ value) *% 16777619;
    return .{ .index = pack_index << 16 | member_index, .witness = witness };
}
