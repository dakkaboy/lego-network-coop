const s = @import("camera_state.zig");
const gpu = @import("camera_gpu.zig");
const order = @import("camera_order.zig");
const load = s.load;
pub fn copyNative(device: usize, parent: usize) bool {
    const player = s.viewRole(parent);
    if (!s.personalFullscreen(parent) or !order.presentationReady(parent)) return false;
    var view: usize = 0;
    for (0..4) |i| {
        const candidate = load(usize, parent + 0xf24 + i * 4);
        if (s.readable(candidate, 0xb4) and load(i32, candidate + 0x2c) == 1 and load(i16, candidate + 0xac) == player) view = candidate;
    }
    if (view == 0 or load(u32, view + 0x34) != 1) return false;
    const target = load(usize, view + 0xa8);
    if (!s.readable(target, 0x3c)) return false;
    const id = load(u32, target + 0x38);
    const registry = load(usize, 0xec07c0);
    if (id == 0 or id > load(u32, 0xec07d0) or !s.readable(registry + (id - 1) * 4, 4)) return false;
    const entry = load(usize, registry + (id - 1) * 4);
    if (!s.readable(entry, 0x58)) return false;
    const texture = load(usize, entry + 0x54);
    if (!s.readable(texture, 0x30)) return false;
    const native = load(usize, texture + 0x2c);
    if (!s.readable(native, 4) or !s.readable(load(usize, native), 22 * 4) or gpu.textureType(native) != 3) return false;
    var surface: usize = 0;
    var backbuffer: usize = 0;
    if (gpu.surfaceLevel(native, &surface) < 0) return false;
    defer gpu.release(surface);
    var copied: i32 = @bitCast(@as(u32, 0x80004005));
    if (gpu.backbuffer(device, &backbuffer) >= 0) {
        defer gpu.release(backbuffer);
        var source: s.Description = undefined;
        var destination: s.Description = undefined;
        _ = gpu.description(surface, &source);
        _ = gpu.description(backbuffer, &destination);
        s.clonewars_camera_debug[0] = surface;
        s.clonewars_camera_debug[1] = id;
        s.clonewars_camera_debug[2] = source.width;
        s.clonewars_camera_debug[3] = source.height;
        if (source.width == destination.width and source.height == destination.height) copied = gpu.stretch(device, surface, null, backbuffer, null, 0);
    }
    s.clonewars_camera_debug[4] = @bitCast(copied);
    if (copied >= 0) s.clonewars_camera_debug[5] +%= 1;
    return copied >= 0;
}
pub fn crop(device: usize) c_int {
    if (s.clonewars_camera_fullclip & 16 != 0 and copyNative(device, s.currentManager())) return 1;
    const parent = s.manager;
    if (!s.personalAllowed(parent) or !s.ordinaryLayout(parent) or load(u32, parent + 0xf20) != 2 or s.focus_manager != parent or load(usize, parent + 0x1c) != 0xe62090) {
        gpu.release(s.selected_target);
        s.selected_target = 0;
        return 0;
    }
    if (s.personalFullscreen(parent) and order.presentationReady(parent)) return 0;
    if (s.selected_target != 0 and s.selected_target_player != s.viewRole(parent)) {
        gpu.release(s.selected_target);
        s.selected_target = 0;
    }
    if (s.selected_target != 0) {
        var backbuffer: usize = 0;
        var copied: i32 = @bitCast(@as(u32, 0x80004005));
        if (gpu.backbuffer(device, &backbuffer) >= 0) {
            copied = if (backbuffer == s.selected_target) 0 else gpu.stretch(device, s.selected_target, null, backbuffer, null, 2);
            gpu.release(backbuffer);
        }
        gpu.release(s.selected_target);
        s.selected_target = 0;
        s.clonewars_camera_debug[4] = @bitCast(copied);
        if (copied >= 0) return 0;
    }
    const player = s.viewRole(parent);
    if (player < 0 or !s.readable(parent, 0x1420) or load(usize, parent) != 0xc3e248) return 0;
    var chosen: usize = 0;
    for (0..4) |i| {
        const view = load(usize, parent + 0xf24 + i * 4);
        if (s.readable(view, 0xb4) and load(usize, view) == 0xc3dc94 and load(i32, view + 0x2c) == 1 and load(i16, view + 0xac) == player) chosen = view;
    }
    if (chosen == 0) return 0;
    const rect = load([4]f32, chosen + 4);
    for (rect) |value| if (!@import("validation.zig").finite(value)) return 0;
    if (rect[0] < 0 or rect[1] < 0 or rect[2] > 1 or rect[3] > 1 or rect[2] <= 0 or rect[3] <= 0 or (rect[0] == 0 and rect[1] == 0 and rect[2] == 1 and rect[3] == 1)) return 0;
    var backbuffer: usize = 0;
    if (gpu.backbuffer(device, &backbuffer) < 0) return 0;
    defer gpu.release(backbuffer);
    var description: s.Description = undefined;
    _ = gpu.description(backbuffer, &description);
    if (s.camera_surface != 0 and (s.camera_width != description.width or s.camera_height != description.height or s.camera_format != description.format)) {
        gpu.release(s.camera_surface);
        s.camera_surface = 0;
    }
    if (s.camera_surface == 0 and gpu.create(device, description.width, description.height, description.format, &s.camera_surface) >= 0) {
        s.camera_width = description.width;
        s.camera_height = description.height;
        s.camera_format = description.format;
    }
    const width: f32 = @floatFromInt(description.width);
    const height: f32 = @floatFromInt(description.height);
    const coords = [4]f32{ rect[0] * width, rect[1] * height, (rect[0] + rect[2]) * width, (rect[1] + rect[3]) * height };
    for (coords) |value| if (value < @as(f32, @floatFromInt(@import("std").math.minInt(i32))) or value >= 2147483648.0) return 0;
    var source = s.Rect{ .left = @intFromFloat(coords[0]), .top = @intFromFloat(coords[1]), .right = @intFromFloat(coords[2]), .bottom = @intFromFloat(coords[3]) };
    if (source.right > @as(i32, @bitCast(description.width))) source.right = @bitCast(description.width);
    if (source.bottom > @as(i32, @bitCast(description.height))) source.bottom = @bitCast(description.height);
    if (s.camera_surface != 0 and source.right > source.left and source.bottom > source.top and gpu.stretch(device, backbuffer, &source, s.camera_surface, null, 2) >= 0) _ = gpu.stretch(device, s.camera_surface, null, backbuffer, null, 0);
    return 0;
}
