const s = @import("camera_state.zig");
const com = @import("com.zig");
pub const release = com.release;
pub fn addRef(object: usize) void {
    _ = com.method(*const fn (usize) callconv(.winapi) u32, object, 1)(object);
}
pub fn description(surface: usize, out: *s.Description) i32 {
    return com.method(*const fn (usize, *s.Description) callconv(.winapi) i32, surface, 12)(surface, out);
}
pub fn backbuffer(device: usize, out: *usize) i32 {
    return com.method(*const fn (usize, u32, u32, u32, *usize) callconv(.winapi) i32, device, 18)(device, 0, 0, 0, out);
}
pub fn target(device: usize, out: *usize) i32 {
    return com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, device, 38)(device, 0, out);
}
pub fn setTarget(device: usize, surface: usize) i32 {
    return com.method(s.SetTarget, device, 37)(device, 0, surface);
}
pub fn setViewport(device: usize, viewport_value: *const s.Viewport) i32 {
    return com.method(s.SetViewport, device, 47)(device, viewport_value);
}
pub fn viewport(device: usize, out: *s.Viewport) i32 {
    return com.method(*const fn (usize, *s.Viewport) callconv(.winapi) i32, device, 48)(device, out);
}
pub fn scissor(device: usize, out: *s.Rect) i32 {
    return com.method(*const fn (usize, *s.Rect) callconv(.winapi) i32, device, 76)(device, out);
}
pub fn state(device: usize, name: u32, out: *u32) i32 {
    return com.method(*const fn (usize, u32, *u32) callconv(.winapi) i32, device, 58)(device, name, out);
}
pub fn stretch(device: usize, source: usize, source_rect: ?*const s.Rect, destination: usize, destination_rect: ?*const s.Rect, filter: u32) i32 {
    return com.method(*const fn (usize, usize, ?*const s.Rect, usize, ?*const s.Rect, u32) callconv(.winapi) i32, device, 34)(device, source, source_rect, destination, destination_rect, filter);
}
pub fn create(device: usize, width: u32, height: u32, format: u32, out: *usize) i32 {
    return com.method(*const fn (usize, u32, u32, u32, u32, u32, i32, *usize, usize) callconv(.winapi) i32, device, 28)(device, width, height, format, 0, 0, 0, out, 0);
}
pub fn textureType(texture: usize) u32 {
    return com.method(*const fn (usize) callconv(.winapi) u32, texture, 10)(texture);
}
pub fn surfaceLevel(texture: usize, out: *usize) i32 {
    return com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, texture, 18)(texture, 0, out);
}
pub fn stateBlock(device: usize, out: *usize) i32 {
    return com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, device, 59)(device, 1, out);
}
pub fn capture(block: usize) i32 {
    return com.method(*const fn (usize) callconv(.winapi) i32, block, 4)(block);
}
pub fn apply(block: usize) i32 {
    return com.method(*const fn (usize) callconv(.winapi) i32, block, 5)(block);
}
pub fn begin(device: usize) i32 {
    return com.method(*const fn (usize) callconv(.winapi) i32, device, 41)(device);
}
pub fn end(device: usize) i32 {
    return com.method(*const fn (usize) callconv(.winapi) i32, device, 42)(device);
}
pub fn releaseTraceSurfaces() void {
    for (&s.trace_surfaces) |*surface| {
        release(surface.*);
        surface.* = 0;
    }
    s.clonewars_camera_surfaces = @splat(@splat(0));
}
pub fn releaseTargets() void {
    release(s.selected_target);
    s.selected_target = 0;
    release(s.camera_surface);
    s.camera_surface = 0;
    release(s.tap_surface);
    s.tap_surface = 0;
}
