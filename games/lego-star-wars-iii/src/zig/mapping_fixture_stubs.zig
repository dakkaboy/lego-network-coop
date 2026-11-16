const win = @import("win32.zig");
pub export fn user_mapping_test_image_base() usize {
    return win.GetModuleHandleA(null);
}
pub export fn user_mapping_test_protect(address: usize, bytes: usize, mode: u32, old: *u32) i32 {
    return win.VirtualProtect(address, bytes, mode, old);
}
pub export fn user_mapping_test_flush(process: usize, address: usize, bytes: usize) i32 {
    return win.FlushInstructionCache(process, address, bytes);
}
pub export fn user_mapping_test_admission_wait(_: u32) void {}
pub export fn user_mapping_test_before_negative() void {}
