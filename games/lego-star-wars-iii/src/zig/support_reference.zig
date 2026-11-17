const p = @import("protocol.zig");
const win = @import("win32.zig");
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
extern fn physics_effect_body_resolve(u32, u32) usize;
extern fn native_scene_support_source(usize, *[2]u32) c_int;
extern fn native_scene_support_resolve(u32, u32) usize;
pub fn capture(body: usize, output: *[2]u32, flags: *u32) bool {
    if (!win.accessible(body, 0x1a, false)) return false;
    const kind = win.load(u8, body + 0x19) & 0x60;
    if (kind != 0x40 and kind != 0x20) return false;
    if (kind == 0x40 and physics_effect_body_source(body, output) != 0) return true;
    if (native_scene_support_source(body, output) == 0) return false;
    flags.* |= p.SYNC_SUPPORT_SCENE;
    return true;
}
pub fn source(body: usize, state: *const p.SyncCharacterMotionState, output: *[2]u32) bool {
    return if (state.support_material_flags & p.SYNC_SUPPORT_SCENE != 0) native_scene_support_source(body, output) != 0 else physics_effect_body_source(body, output) != 0;
}
pub fn resolve(state: *const p.SyncCharacterMotionState) usize {
    return if (state.support_material_flags & p.SYNC_SUPPORT_SCENE != 0) native_scene_support_resolve(state.support_frame, state.support_event) else physics_effect_body_resolve(state.support_frame, state.support_event);
}
