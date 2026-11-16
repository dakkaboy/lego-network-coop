const std = @import("std");
const s = @import("tag_state.zig");
extern fn tag_transfer_hook() void;
pub export fn tags_install() c_int {
    if (s.adapter == null or s.session_provider == null) return 0;
    const site: usize = 0x8ae680;
    const expected = "\x83\xec\x28\x56\x8b\x74\x24\x30";
    if (!s.win.accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected)) return 0;
    const bridge = s.win.VirtualAlloc(0, 13, 0x3000, 0x40);
    if (bridge == 0) return 0;
    @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..8], expected);
    s.win.store(u8, bridge + 8, 0xe9);
    s.win.store(u32, bridge + 9, @truncate(site +% 8 -% bridge -% 13));
    const previous = s.original;
    s.original = @ptrFromInt(bridge);
    const patches = [_]@import("hook_transaction.zig").Patch{.{ .address = site, .expected = expected, .target = @intFromPtr(&tag_transfer_hook) }};
    if (!@import("hook_transaction.zig").apply(&patches)) {
        s.original = previous;
        _ = s.win.VirtualFree(bridge, 0, 0x8000);
        return 0;
    }
    _ = s.win.FlushInstructionCache(s.win.GetCurrentProcess(), bridge, 13);
    return 1;
}
comptime {
    _ = @import("tag_guard.zig");
    _ = @import("tag_native.zig");
    _ = @import("tag_events.zig");
    _ = @import("tag_actor_update.zig");
    _ = @import("tag_frame.zig");
}
