const std = @import("std");
const s = @import("entity_state.zig");
const hooks = @import("hook_transaction.zig");
var installed = false;
extern fn entity_create_hook() usize;
extern fn entity_create_placement_thunk() void;
extern fn entity_roster_thunk() void;
extern fn entity_hub_thunk() void;
fn callBytes(site: usize, target: usize) [5]u8 {
    const relative: u32 = @truncate(target -% site -% 5);
    return .{ 0xe8, @truncate(relative), @truncate(relative >> 8), @truncate(relative >> 16), @truncate(relative >> 24) };
}
pub export fn entities_install() c_int {
    if (installed) return 1;
    const roster_first = callBytes(0x8afc3a, 0x9de240);
    const roster_second = callBytes(0x8afcbe, 0x9de240);
    const hub = callBytes(0x4eed96, 0x9de240);
    const first_select = callBytes(0x4efed4, 0x492c90);
    const next_select = callBytes(0x4f1030, 0x492c90);
    const ready_select = callBytes(0x4f0f6c, 0x492c90);
    const patches = [_]hooks.Patch{
        .{ .address = 0x7e53d0, .expected = "\xa1\x20\x4a\xfb\x00", .target = @intFromPtr(&entity_create_hook) },
        .{ .address = 0x9c63ac, .expected = "\xe8\x1f\xf0\xe1\xff", .target = @intFromPtr(&entity_create_placement_thunk), .opcode = 0xe8 },
        .{ .address = 0x8afc3a, .expected = &roster_first, .target = @intFromPtr(&entity_roster_thunk), .opcode = 0xe8 },
        .{ .address = 0x8afcbe, .expected = &roster_second, .target = @intFromPtr(&entity_roster_thunk), .opcode = 0xe8 },
        .{ .address = 0x4eed96, .expected = &hub, .target = @intFromPtr(&entity_hub_thunk), .opcode = 0xe8 },
    } ++ if (@hasDecl(@import("root"), "native_title")) [_]hooks.Patch{
        .{ .address = 0x4efed4, .expected = &first_select, .target = @intFromPtr(&@import("entity_spawn.zig").hubResourceCharacter), .opcode = 0xe8 },
        .{ .address = 0x4f1030, .expected = &next_select, .target = @intFromPtr(&@import("entity_spawn.zig").hubResourceCharacter), .opcode = 0xe8 },
        .{ .address = 0x4f0f6c, .expected = &ready_select, .target = @intFromPtr(&@import("entity_spawn.zig").hubResourceCharacter), .opcode = 0xe8 },
    } else [_]hooks.Patch{};
    for (patches) |patch| if (!s.valid(patch.address, patch.expected.len) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected)) return 0;
    const bridge = s.win.VirtualAlloc(0, 10, 0x3000, 0x40);
    if (bridge == 0) return 0;
    @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..5], patches[0].expected);
    s.win.store(u8, bridge + 5, 0xe9);
    s.win.store(u32, bridge + 6, @truncate(0x7e53d5 -% bridge -% 10));
    _ = s.win.FlushInstructionCache(s.win.GetCurrentProcess(), bridge, 10);
    const previous = s.original_create;
    s.original_create = bridge;
    if (!hooks.apply(&patches)) {
        s.original_create = previous;
        _ = s.win.VirtualFree(bridge, 0, 0x8000);
        return 0;
    }
    installed = true;
    return 1;
}
comptime {
    _ = @import("entity_registry.zig");
    _ = @import("entity_party.zig");
    _ = @import("entity_binding.zig");
    _ = @import("entity_spawn.zig");
    _ = @import("entity_bridges.zig");
}
