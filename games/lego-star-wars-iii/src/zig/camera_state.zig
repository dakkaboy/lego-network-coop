const std = @import("std");
pub const win = @import("win32.zig");
pub const load = win.load;
pub const store = win.store;
pub const platform = @import("camera_platform_dispatch.zig");
pub const Rect = @import("window_api.zig").Rect;
pub const Point = @import("window_api.zig").Point;
pub const Machine = @import("machine_environment.zig").Environment;
pub const Update = *const fn (usize, usize, usize, u8) callconv(.{ .x86_thiscall = .{} }) void;
pub const Clip = *const fn (usize, usize, [*]f32, usize, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
pub const Centers = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
pub const Views = *const fn (usize, usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
pub const Present = *const fn (usize, ?*const Rect, ?*const Rect, usize, usize) callconv(.winapi) i32;
pub const Reset = *const fn (usize, usize) callconv(.winapi) i32;
pub const SetTarget = *const fn (usize, u32, usize) callconv(.winapi) i32;
pub const SetViewport = *const fn (usize, ?*const Viewport) callconv(.winapi) i32;
pub const SetScissor = *const fn (usize, ?*const Rect) callconv(.winapi) i32;
pub const SetState = *const fn (usize, u32, u32) callconv(.winapi) i32;
pub const Viewport = extern struct { x: u32, y: u32, width: u32, height: u32, min_z: f32, max_z: f32 };
pub const Description = extern struct { format: u32, kind: u32, usage: u32, pool: u32, multisample: u32, quality: u32, width: u32, height: u32 };
pub var originals: [3]Update = undefined;
pub const tables = [_]usize{ 0xc3de2c, 0xc3df2c, 0xc3e044 };
pub var previous_proc: usize = 0;
pub var camera_module: usize = 0;
pub var main_install_state: i32 = 0;
pub var game_window: usize = 0;
pub var selected: i32 = -1;
pub var manager: usize = 0;
pub var camera_surface: usize = 0;
pub var camera_width: u32 = 0;
pub var camera_height: u32 = 0;
pub var camera_format: u32 = 0;
pub var selected_target: usize = 0;
pub var tap_surface: usize = 0;
pub var selected_target_player: i32 = -1;
pub var gpu_observation_serial: u32 = 0;
pub var compositor_call_serial: u32 = 0;
pub var trace_frame: u32 = 0;
pub var trace_target: u32 = 0;
pub var trace_width: u32 = 0;
pub var trace_height: u32 = 0;
pub var trace_surfaces: [8]usize = @splat(0);
pub var original_set_target: SetTarget = undefined;
pub var original_set_viewport: SetViewport = undefined;
pub var original_set_scissor: SetScissor = undefined;
pub var original_set_state: SetState = undefined;
pub var original_present: Present = undefined;
pub var original_reset: Reset = undefined;
pub var original_clip: ?Clip = null;
pub var original_layout_centers: ?Centers = null;
pub var original_render_views: ?Views = null;
pub var original_view_finish: *const fn (usize) callconv(.c) void = undefined;
pub var personal_hooks_ready = false;
pub var focus_manager: usize = 0;
pub var focus_state: usize = 0;
pub var focus_player: i32 = -1;
pub var layout_cache_manager: usize = 0;
pub var layout_cache_fullscreen: i32 = -1;
pub var log_file: usize = 0;
pub var menu_closed_at: u32 = 0;
pub const menu_message: u32 = 0x8342;
pub const window_message: u32 = 0x8344;
pub const renderer_message: u32 = 0x8345;
pub var background_capture = false;
pub var game_device: usize = 0;
pub var frame_timer: usize = 0;
pub var frequency: i64 = 0;
pub var frame_deadline: i64 = 0;
pub const Hud = extern struct { health: c_int, max_health: c_int, has_studs: c_int, studs: u64 };
pub extern fn lan_status() c_int;
pub extern fn game_sync_status() c_int;
pub extern fn game_sync_inspect() void;
pub extern fn network_window_update() void;
pub extern fn network_window_configure(usize) void;
pub extern fn network_window_message(usize, u32, usize, isize) c_int;
pub extern fn capture_frame(usize) void;
pub extern fn capture_reset() void;
pub extern fn coop_draw(usize, *const [2]Hud) void;
pub extern fn coop_set_window(usize, bool) void;
pub extern fn coop_fonts_lost() void;
pub extern fn coop_fonts_reset() void;
pub extern fn coop_release_fonts() void;
pub extern fn coop_toggle() void;
pub extern fn coop_input(usize, u32, usize, isize) c_int;
pub extern fn game_request_reload(c_int) void;
pub extern fn game_request_level(c_int) void;
pub extern fn game_current_level() c_int;
pub extern fn game_sync_prepare_worker(u32) c_int;
pub extern fn loading_install() c_int;
pub extern fn diagnostics_install(usize) void;
pub extern fn camera_init_observer_snapshot(usize, u32, c_int) void;
pub fn readable(address: usize, bytes: usize) bool {
    var info: win.MemoryInfo = undefined;
    return address != 0 and win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.state == 0x1000 and info.protection & 0x101 == 0 and address +% bytes <= info.base +% info.region_size;
}
pub export fn camera_select(player: c_int) void {
    if (player >= -1 and player <= 1) @atomicStore(i32, &selected, player, .seq_cst);
}
pub export fn camera_selected() c_int {
    return @atomicLoad(i32, &selected, .seq_cst);
}
pub export var clonewars_camera_role_debug: [8]u32 = @splat(0);
pub fn viewRole(parent: usize) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const logical = camera_selected();
    if (logical < 0 or logical > 1) return logical;
    if (!readable(parent, 0x1420) or load(u32, parent) != 0xc3e248) return logical;
    const root = load(usize, 0xe9018c);
    if (!readable(root, 0x2c) or load(u32, root) != 0xc5160c) return logical;
    const box = load(usize, root + 0x28);
    if (!readable(box, 0x38) or load(u32, box) != 0xc51554 or load(usize, box + 0x28) != parent or load(u32, box + 0x20) != 2) return logical;
    const actors = load([2]usize, 0xfb4940);
    if (actors[0] == actors[1] or !readable(actors[0], 0x1440) or !readable(actors[1], 0x1440)) return logical;
    const controllers = load([2]usize, box + 0x30);
    if (controllers[0] == controllers[1]) return logical;
    var roles: [2]u16 = undefined;
    var owners: u32 = 0;
    var labels: u32 = 0;
    var selected_controller: usize = 0;
    for (controllers) |controller| {
        if (!readable(controller, 0x758) or !readable(load(usize, controller + 0x1c), 0x148)) return logical;
        const role = load(u16, controller + 0x750);
        const actor = load(usize, controller + 0x754);
        const slot: u5 = if (actor == actors[0]) 0 else if (actor == actors[1]) 1 else return logical;
        if (role > 1 or labels & (@as(u32, 1) << @intCast(role)) != 0 or owners & (@as(u32, 1) << slot) != 0) return logical;
        roles[slot] = role;
        labels |= @as(u32, 1) << @intCast(role);
        owners |= @as(u32, 1) << slot;
        if (slot == @as(u32, @intCast(logical))) selected_controller = controller;
    }
    if (owners != 3 or labels != 3) return logical;
    const resolved = roles[@intCast(logical)];
    if (resolved != logical) clonewars_camera_role_debug = .{ clonewars_camera_role_debug[0] +% 1, @intCast(logical), resolved, actors[@intCast(logical)], selected_controller, parent, actors[0], actors[1] };
    return resolved;
}
pub fn currentManager() usize {
    const root = load(usize, 0xe9018c);
    const box = if (readable(root, 0x2c)) load(usize, root + 0x28) else 0;
    const camera = if (readable(box, 0x2c)) load(usize, box + 0x28) else 0;
    return if (readable(camera, 0x1420) and load(usize, camera) == 0xc3e248) camera else 0;
}
pub fn personalAllowed(parent: usize) bool {
    const root = load(usize, 0xfb2e60);
    return camera_selected() >= 0 and lan_status() == 3 and readable(parent, 0x1420) and parent == currentManager() and readable(root, 0x1b7c) and load(i32, root + 0x1b78) == 0xe and load(u8, 0xfbc161) == 0 and load(i32, 0xe6e61c) < 0 and load(i32, 0xfb11dc) == 2;
}
pub fn ordinaryLayout(parent: usize) bool {
    return readable(parent, 0x1420) and load(u32, parent + 0xf20) <= 2 and load(i32, parent + 0x13c0) == -1 and load(u32, parent + 0x13d8) == 0;
}
pub fn personalFullscreen(parent: usize) bool {
    var family: @import("camera_order.zig").Family = undefined;
    return personal_hooks_ready and clonewars_camera_native_order_enabled != 0 and clonewars_camera_native_order_installed == 1 and clonewars_camera_fullclip & 64 != 0 and personalAllowed(parent) and ordinaryLayout(parent) and load(u32, parent + 0xf20) == 2 and load(usize, parent + 0x1c) == 0xe62090 and @import("camera_order.zig").family(parent, &family);
}
pub export var clonewars_saber_pass: [2][5]u32 = std.mem.zeroes([2][5]u32);
pub export var clonewars_saber_list: [2][3]u32 = std.mem.zeroes([2][3]u32);
pub export var clonewars_saber_actor_batch: [4]u32 = std.mem.zeroes([4]u32);
pub export var clonewars_saber_submit: [7][5]u32 = std.mem.zeroes([7][5]u32);
pub export var clonewars_saber_producer: [17][9]u32 = std.mem.zeroes([17][9]u32);
pub export var clonewars_camera_debug: [8]u32 = std.mem.zeroes([8]u32);
pub export var clonewars_camera_viewport: [22]u32 = std.mem.zeroes([22]u32);
pub export var clonewars_camera_gpu_observation_enabled: i32 = 0;
pub export var clonewars_camera_gpu_observation: [2][40]u32 = std.mem.zeroes([2][40]u32);
pub export var clonewars_camera_compositor_enabled: i32 = 0;
pub export var clonewars_camera_compositor_version: u32 = 2;
pub export var clonewars_camera_compositor_stride: u32 = 320;
pub export var clonewars_camera_compositor_capacity: u32 = 128;
pub export var clonewars_camera_compositor_count: i32 = 0;
pub export var clonewars_camera_compositor_rows: [128][80]u32 = std.mem.zeroes([128][80]u32);
pub export var clonewars_camera_fullclip: u32 = 84;
pub export var clonewars_camera_threads: [3]u32 = std.mem.zeroes([3]u32);
pub export var clonewars_camera_trace_count: i32 = 0;
pub export var clonewars_camera_trace: [512][12]u32 = std.mem.zeroes([512][12]u32);
pub export var clonewars_camera_preview: u32 = 0;
pub export var clonewars_camera_surfaces: [8][6]u32 = std.mem.zeroes([8][6]u32);
pub export var clonewars_saber_host_repair: [4]u32 = std.mem.zeroes([4]u32);
pub export var clonewars_background_window_version: u32 = 1;
pub export var clonewars_background_window_stride: u32 = 64;
pub export var clonewars_background_window_commit: i32 = 0;
pub export var clonewars_background_window_state: [16]u32 = std.mem.zeroes([16]u32);
pub export var clonewars_camera_native_order_enabled: i32 = 1;
pub export var clonewars_camera_native_order_installed: i32 = 0;
pub export var clonewars_camera_native_order_debug: [16]u32 = std.mem.zeroes([16]u32);
