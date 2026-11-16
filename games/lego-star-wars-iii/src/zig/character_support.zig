const p = @import("protocol.zig");
const win = @import("win32.zig");
const valid = @import("fire_validation.zig").supportValid;
pub fn same(a: *const p.SyncCharacterMotionState, b: *const p.SyncCharacterMotionState) bool {
    return valid(a) and valid(b) and a.support_frame == b.support_frame and a.support_event == b.support_event;
}
pub fn replay(body: usize, local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    if (!same(local, expected)) return false;
    if (expected.support_frame == 0) return true;
    if (body == 0) return false;
    win.store([4]f32, body + 0x110, expected.support_anchor);
    win.store([3]f32, body + 0xf0, expected.support_normal);
    win.store(u16, body + 0x102, @truncate(expected.support_material_flags));
    win.store(u32, body + 0xc0, (win.load(u32, body + 0xc0) & ~@as(u32, 1)) | (expected.support_material_flags >> 16));
    return true;
}
