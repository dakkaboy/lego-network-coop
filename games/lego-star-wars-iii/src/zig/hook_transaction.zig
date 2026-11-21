const std = @import("std");
const win = @import("win32.zig");
pub const Patch = struct { address: usize, expected: []const u8, target: usize, opcode: u8 = 0xe9 };
const max_patches = 65;
pub fn apply(patches: []const Patch) bool {
    if (patches.len == 0 or patches.len > max_patches) return false;
    for (patches) |patch| {
        if (patch.expected.len < 5 or !win.accessible(patch.address, patch.expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected)) return false;
    }
    var protections: [max_patches]u32 = undefined;
    var acquired: usize = 0;
    while (acquired < patches.len) : (acquired += 1) {
        const patch = patches[acquired];
        if (win.VirtualProtect(patch.address, patch.expected.len, 0x40, &protections[acquired]) == 0) break;
    }
    var success = acquired == patches.len;
    if (success) {
        for (patches) |patch| {
            win.store(u8, patch.address, patch.opcode);
            win.store(u32, patch.address + 1, @truncate(patch.target -% patch.address -% 5));
            for (5..patch.expected.len) |i| win.store(u8, patch.address + i, 0x90);
            if (win.FlushInstructionCache(win.GetCurrentProcess(), patch.address, patch.expected.len) == 0) success = false;
        }
        if (!success) for (patches) |patch| {
            @memcpy(@as([*]u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected);
            _ = win.FlushInstructionCache(win.GetCurrentProcess(), patch.address, patch.expected.len);
        };
    }
    // Overlapping pages must regain their protections in reverse acquisition order.
    while (acquired != 0) {
        acquired -= 1;
        const patch = patches[acquired];
        var ignored: u32 = 0;
        if (win.VirtualProtect(patch.address, patch.expected.len, protections[acquired], &ignored) == 0) success = false;
    }
    return success;
}
