const s = @import("camera_state.zig");
pub fn line(text: []const u8) void {
    if (s.log_file == 0) return;
    var written: u32 = 0;
    _ = s.platform.WriteFile(s.log_file, text.ptr, @intCast(text.len), &written, 0);
    _ = s.platform.WriteFile(s.log_file, "\r\n", 2, &written, 0);
}
