const win = @import("win32.zig");
pub fn method(comptime Function: type, object: usize, index: usize) Function {
    return @ptrFromInt(win.load(usize, win.load(usize, object) + index * @sizeOf(usize)));
}
pub fn release(object: usize) void {
    if (object != 0) _ = method(*const fn (usize) callconv(.winapi) u32, object, 2)(object);
}
