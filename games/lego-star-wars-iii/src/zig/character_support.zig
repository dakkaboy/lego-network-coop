const p = @import("protocol.zig");
const win = @import("win32.zig");
const valid = @import("fire_validation.zig").supportValid;
pub fn accepts(body: usize, state: *const p.SyncCharacterMotionState) bool {
    if (!win.accessible(body, 0x1a, false)) return false;
    const kind = win.load(u8, body + 0x19) & 0x60;
    return kind == 0x40 or (kind == 0x20 and state.support_material_flags & p.SYNC_SUPPORT_SCENE != 0);
}
pub fn same(a: *const p.SyncCharacterMotionState, b: *const p.SyncCharacterMotionState) bool {
    return valid(a) and valid(b) and a.support_frame == b.support_frame and a.support_event == b.support_event and (a.support_material_flags & (p.SYNC_SUPPORT_ABSENT | p.SYNC_SUPPORT_SCENE)) == (b.support_material_flags & (p.SYNC_SUPPORT_ABSENT | p.SYNC_SUPPORT_SCENE));
}
pub fn canRelease(local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    return valid(local) and valid(expected) and local.support_material_flags & p.SYNC_SUPPORT_ABSENT == 0 and expected.support_material_flags == p.SYNC_SUPPORT_ABSENT;
}
pub fn release(body: usize, previous: usize, local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    if (!canRelease(local, expected) or !win.accessible(body, 0x140, true) or win.load(usize, body + 0xec) != previous or (local.support_frame != 0 and previous == 0)) return false;
    // The native ground probe (a15fd0) clears this borrowed pointer before looking for a new contact.
    win.store(usize, body + 0xec, 0);
    return true;
}
pub fn canAcquire(local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    return valid(local) and valid(expected) and expected.support_frame != 0 and
        !same(local, expected);
}
pub fn acquire(body: usize, support: usize, local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    if (!canAcquire(local, expected) or !win.accessible(body, 0x140, true) or !accepts(support, expected)) return false;
    // The native contact setter (a08650) stores a borrowed body pointer, not an owning reference.
    win.store(usize, body + 0xec, support);
    var matched = local.*;
    matched.support_frame = expected.support_frame;
    matched.support_event = expected.support_event;
    matched.support_material_flags = (matched.support_material_flags & ~(p.SYNC_SUPPORT_ABSENT | p.SYNC_SUPPORT_SCENE)) | (expected.support_material_flags & p.SYNC_SUPPORT_SCENE);
    return replay(body, &matched, expected);
}
pub fn replay(body: usize, local: *const p.SyncCharacterMotionState, expected: *const p.SyncCharacterMotionState) bool {
    if (!same(local, expected)) return false;
    if (expected.support_frame == 0) return true;
    if (body == 0) return false;
    win.store([4]f32, body + 0x110, expected.support_anchor);
    win.store([3]f32, body + 0xf0, expected.support_normal);
    win.store(u16, body + 0x102, @truncate(expected.support_material_flags));
    win.store(u32, body + 0xc0, (win.load(u32, body + 0xc0) & ~@as(u32, 1)) | ((expected.support_material_flags >> 16) & 1));
    return true;
}
