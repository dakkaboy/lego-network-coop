const std = @import("std");
const s = @import("camera_state.zig");
const gpu = @import("camera_gpu.zig");
const observe = @import("camera_observe.zig");
const order = @import("camera_order.zig");
const log = @import("camera_log.zig").line;
var rate_started: u32 = 0;
var rate_frames: u32 = 0;
fn addedWork(device: usize) void {
    if (device != s.game_device) return;
    s.clonewars_camera_threads[0] = s.win.GetCurrentThreadId();
    s.network_window_update();
    s.trace_frame +%= 1;
    s.game_sync_inspect();
    _ = @import("camera_image.zig").crop(device);
    const preview = s.clonewars_camera_preview;
    if (preview >= 1 and preview <= 8 and s.trace_surfaces[preview - 1] != 0 and s.personalAllowed(s.manager)) {
        var backbuffer: usize = 0;
        if (gpu.backbuffer(device, &backbuffer) >= 0) {
            s.clonewars_camera_debug[4] = @bitCast(gpu.stretch(device, s.trace_surfaces[preview - 1], null, backbuffer, null, 0));
            gpu.release(backbuffer);
        }
    }
    var saved: usize = 0;
    var target: usize = 0;
    var backbuffer: usize = 0;
    if (gpu.stateBlock(device, &saved) >= 0) {
        _ = gpu.capture(saved);
        _ = gpu.target(device, &target);
        if (gpu.backbuffer(device, &backbuffer) >= 0) {
            var description: s.Description = undefined;
            if (gpu.description(backbuffer, &description) >= 0) {
                s.trace_width = description.width;
                s.trace_height = description.height;
                _ = gpu.setTarget(device, backbuffer);
                const viewport = s.Viewport{ .x = 0, .y = 0, .width = description.width, .height = description.height, .min_z = 0, .max_z = 1 };
                _ = gpu.setViewport(device, &viewport);
                if (gpu.begin(device) >= 0) {
                    const hud: [2]s.Hud = std.mem.zeroes([2]s.Hud);
                    s.coop_draw(device, &hud);
                    _ = gpu.end(device);
                }
            }
            gpu.release(backbuffer);
        }
        if (target != 0) {
            _ = gpu.setTarget(device, target);
            gpu.release(target);
        }
        _ = gpu.apply(saved);
        gpu.release(saved);
    }
    s.capture_frame(device);
    var now: i64 = 0;
    _ = s.platform.QueryPerformanceCounter(&now);
    if (s.frame_deadline > now and s.frame_timer != 0 and s.frequency > 0) {
        const due: i64 = -@divTrunc((s.frame_deadline - now) * 10000000, s.frequency);
        if (due < 0 and s.platform.SetWaitableTimer(s.frame_timer, &due, 0, 0, 0, 0) != 0) _ = s.platform.WaitForSingleObject(s.frame_timer, 100);
    }
    _ = s.platform.QueryPerformanceCounter(&now);
    s.frame_deadline = now + @divTrunc(s.frequency, 60);
    const tick = s.platform.GetTickCount();
    if (rate_started == 0) rate_started = tick;
    rate_frames +%= 1;
    if (tick -% rate_started >= 5000) {
        var buffer: [80]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        writer.print("present rate: {d:.1} FPS", .{@as(f64, @floatFromInt(rate_frames)) * 1000.0 / @as(f64, @floatFromInt(tick -% rate_started))}) catch {};
        log(buffer[0..writer.end]);
        rate_frames = 0;
        rate_started = tick;
    }
}
pub fn present(device: usize, source: ?*const s.Rect, destination: ?*const s.Rect, window: usize, dirty: usize) callconv(.winapi) i32 {
    var machine: s.Machine = undefined;
    machine.capture();
    addedWork(device);
    machine.restore();
    return s.original_present(device, source, destination, window, dirty);
}
pub fn reset(device: usize, parameters: usize) callconv(.winapi) i32 {
    var machine: s.Machine = undefined;
    machine.capture();
    order.reset();
    s.capture_reset();
    gpu.releaseTraceSurfaces();
    gpu.releaseTargets();
    if (device == s.game_device) s.coop_fonts_lost();
    machine.restore();
    const result = s.original_reset(device, parameters);
    machine.capture();
    if (device == s.game_device and result >= 0) {
        s.coop_fonts_reset();
        install();
    }
    machine.restore();
    return result;
}
fn patchSlot(comptime Function: type, table: usize, index: usize, replacement: Function, original: *Function) void {
    const entry = table + index * 4;
    const target = @intFromPtr(replacement);
    if (s.load(usize, entry) == target) return;
    var protection: u32 = 0;
    if (s.win.VirtualProtect(entry, 4, 4, &protection) == 0) return;
    original.* = @ptrFromInt(s.load(usize, entry));
    s.store(usize, entry, target);
    var unused: u32 = 0;
    _ = s.win.VirtualProtect(entry, 4, protection, &unused);
}
pub fn install() void {
    const device = s.load(usize, 0xf925d4);
    if (device == 0 or !s.readable(device, 4)) return;
    if (s.game_device != 0 and device != s.game_device) {
        order.reset();
        s.capture_reset();
        s.coop_release_fonts();
        gpu.releaseTraceSurfaces();
        gpu.releaseTargets();
    }
    s.game_device = device;
    const table = s.load(usize, device);
    if (!s.readable(table, 79 * 4)) return;
    if (s.load(usize, table + 17 * 4) == @intFromPtr(&present)) return;
    patchSlot(s.SetTarget, table, 37, &observe.setTarget, &s.original_set_target);
    patchSlot(s.SetViewport, table, 47, &observe.setViewport, &s.original_set_viewport);
    patchSlot(s.SetScissor, table, 75, &observe.setScissor, &s.original_set_scissor);
    patchSlot(s.SetState, table, 57, &observe.setState, &s.original_set_state);
    s.original_present = @ptrFromInt(s.load(usize, table + 17 * 4));
    if (s.load(usize, table + 16 * 4) != @intFromPtr(&reset)) s.original_reset = @ptrFromInt(s.load(usize, table + 16 * 4));
    _ = s.platform.QueryPerformanceFrequency(&s.frequency);
    if (s.frame_timer == 0) s.frame_timer = s.platform.CreateWaitableTimerExW(0, null, 2, 0x1f0003);
    if (s.frame_timer == 0) s.frame_timer = s.platform.CreateWaitableTimerW(0, 0, null);
    var protection: u32 = 0;
    if (s.win.VirtualProtect(table + 16 * 4, 8, 4, &protection) == 0) return;
    _ = @atomicRmw(usize, @as(*usize, @ptrFromInt(table + 16 * 4)), .Xchg, @intFromPtr(&reset), .seq_cst);
    _ = @atomicRmw(usize, @as(*usize, @ptrFromInt(table + 17 * 4)), .Xchg, @intFromPtr(&present), .seq_cst);
    var unused: u32 = 0;
    _ = s.win.VirtualProtect(table + 16 * 4, 8, protection, &unused);
    log("in-game LAN interface installed; frame limit 60 FPS");
}
