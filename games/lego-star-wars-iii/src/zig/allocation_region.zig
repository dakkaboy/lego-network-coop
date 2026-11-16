const std = @import("std");
const win = @import("win32.zig");
pub const Info = extern struct { base: usize, protection: u32, flags: u32, size: usize, committed: usize };
const Query = *const fn (usize, usize, u32, *anyopaque, usize, *usize) callconv(.winapi) c_int;
extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
var function: usize = std.math.maxInt(usize);
fn queryFunction() ?Query {
    var address = @atomicLoad(usize, &function, .acquire);
    if (address == std.math.maxInt(usize)) {
        const module = win.GetModuleHandleA("kernelbase.dll");
        const resolved = if (module != 0) GetProcAddress(module, "QueryVirtualMemoryInformation") else 0;
        address = @cmpxchgStrong(usize, &function, std.math.maxInt(usize), resolved, .acq_rel, .acquire) orelse resolved;
    }
    return if (address != 0) @ptrFromInt(address) else null;
}
pub fn private(address: usize) ?Info {
    const query = queryFunction() orelse return null;
    // WOW64 also writes eight bytes beyond the documented 20-byte structure.
    var bytes: [64]u8 align(@alignOf(Info)) = @splat(0);
    var returned: usize = 0;
    if (query(win.GetCurrentProcess(), address, 0, &bytes, bytes.len, &returned) == 0 or returned < @sizeOf(Info) or returned > bytes.len) return null;
    const info = @as(*const Info, @ptrCast(&bytes)).*;
    if (info.flags & 0x3f != 1 or info.base == 0 or info.size == 0 or info.size > std.math.maxInt(usize) - info.base or address < info.base or address - info.base >= info.size) return null;
    return info;
}
