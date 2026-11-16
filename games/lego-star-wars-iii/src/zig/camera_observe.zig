const std = @import("std");
const s = @import("camera_state.zig");
const gpu = @import("camera_gpu.zig");
const load = s.load;
fn trace(kind: u32) ?*[12]u32 {
    if (s.clonewars_camera_fullclip & 32 == 0 or !s.personalAllowed(s.manager)) return null;
    const index = @atomicRmw(i32, &s.clonewars_camera_trace_count, .Add, 1, .seq_cst);
    if (index < 0 or index >= 512) return null;
    const record = &s.clonewars_camera_trace[@intCast(index)];
    record[0] = kind;
    record[1] = s.trace_frame;
    record[2] = load(u32, 0xeb8374);
    record[3] = s.win.GetCurrentThreadId();
    record[4] = s.trace_target;
    return record;
}
pub fn setTarget(device: usize, index: u32, surface: usize) callconv(.winapi) i32 {
    const result = s.original_set_target(device, index, surface);
    if (device == s.game_device and index == 0) {
        s.trace_target = surface;
        if (trace(1)) |record| {
            var description: s.Description = undefined;
            record[5] = @bitCast(result);
            if (surface != 0 and gpu.description(surface, &description) >= 0) {
                record[6..12].* = .{ description.width, description.height, description.format, description.multisample, description.usage, description.pool };
                if (description.width == s.trace_width and description.height == s.trace_height) for (&s.trace_surfaces, 0..) |*stored, i| {
                    if (stored.* == surface) break;
                    if (stored.* == 0) {
                        gpu.addRef(surface);
                        stored.* = surface;
                        s.clonewars_camera_surfaces[i] = .{ surface, description.width, description.height, description.format, description.multisample, load(u32, 0xeb8374) };
                        break;
                    }
                };
            }
        }
    }
    return result;
}
pub fn setViewport(device: usize, viewport: ?*const s.Viewport) callconv(.winapi) i32 {
    const result = s.original_set_viewport(device, viewport);
    if (device == s.game_device) if (trace(2)) |record| if (viewport) |value| {
        record[5..9].* = .{ value.x, value.y, value.width, value.height };
    };
    return result;
}
pub fn setScissor(device: usize, rectangle: ?*const s.Rect) callconv(.winapi) i32 {
    const result = s.original_set_scissor(device, rectangle);
    if (device == s.game_device) if (trace(4)) |record| if (rectangle) |value| {
        record[5..9].* = .{ @bitCast(value.left), @bitCast(value.top), @bitCast(value.right), @bitCast(value.bottom) };
    };
    return result;
}
pub fn setState(device: usize, state: u32, value: u32) callconv(.winapi) i32 {
    const result = s.original_set_state(device, state, value);
    if (device == s.game_device and (state == 174 or state == 152 or state == 52 or state == 56 or state == 57 or state == 168)) if (trace(3)) |record| {
        record[5] = state;
        record[6] = value;
    };
    return result;
}
pub fn observeGpu(view: usize, parent: usize, role: i32, thread: u32, forced: bool) void {
    if ((!forced and s.clonewars_camera_gpu_observation_enabled == 0) or s.game_device == 0 or role < 0 or role > 1 or thread != s.clonewars_camera_threads[0]) return;
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const mxcsr: u32 = 0x1f80;
    asm volatile ("fninit; ldmxcsr (%[value])"
        :
        : [value] "r" (&mxcsr),
        : .{ .memory = true });
    var row: [40]u32 = @splat(0);
    for ([_]usize{ 11, 13, 18, 25, 30 }) |i| row[i] = 0x8000000a;
    row[1..8].* = .{ 1, @intCast(role), view, parent, thread, load(u32, 0xfb4b6c), load(u32, 0xfb4b74) };
    const engine = load(usize, 0xfb0afc);
    if (s.readable(engine, 0xe10)) row[8] = load(u32, engine + 0xe0c);
    var time: i64 = 0;
    _ = s.platform.QueryPerformanceCounter(&time);
    row[9] = @truncate(@as(u64, @bitCast(time)));
    row[10] = @truncate(@as(u64, @bitCast(time)) >> 32);
    var target: usize = 0;
    row[11] = @bitCast(gpu.target(s.game_device, &target));
    if (@as(i32, @bitCast(row[11])) >= 0 and target != 0) {
        row[12] = target;
        var description: s.Description = undefined;
        row[13] = @bitCast(gpu.description(target, &description));
        if (@as(i32, @bitCast(row[13])) >= 0) row[14..18].* = .{ description.width, description.height, description.format, description.multisample };
        gpu.release(target);
    }
    var viewport: s.Viewport = undefined;
    row[18] = @bitCast(gpu.viewport(s.game_device, &viewport));
    if (@as(i32, @bitCast(row[18])) >= 0) row[19..25].* = .{ viewport.x, viewport.y, viewport.width, viewport.height, @bitCast(viewport.min_z), @bitCast(viewport.max_z) };
    var rectangle: s.Rect = undefined;
    row[25] = @bitCast(gpu.scissor(s.game_device, &rectangle));
    if (@as(i32, @bitCast(row[25])) >= 0) row[26..30].* = .{ @bitCast(rectangle.left), @bitCast(rectangle.top), @bitCast(rectangle.right), @bitCast(rectangle.bottom) };
    var enabled: u32 = 0;
    row[30] = @bitCast(gpu.state(s.game_device, 174, &enabled));
    row[31] = enabled;
    row[32] = s.clonewars_camera_fullclip;
    row[33] = @bitCast(s.camera_selected());
    row[34] = 0xffffffff;
    if (s.readable(parent, 0xf24)) {
        row[34] = load(u32, parent + 0xf20);
        row[35] |= 1;
    }
    const destination = &s.clonewars_camera_gpu_observation[@intCast(role)];
    @atomicStore(u32, &destination[0], 0, .seq_cst);
    destination[1..40].* = row[1..40].*;
    s.gpu_observation_serial +%= 1;
    if (s.gpu_observation_serial == 0) s.gpu_observation_serial +%= 1;
    @atomicStore(u32, &destination[0], s.gpu_observation_serial, .seq_cst);
}
pub export fn camera_compositor_sample(view: usize, parent: usize, native_result: u32, phase: u32, call_id: ?*u32) void {
    if (s.clonewars_camera_compositor_enabled == 0 or s.clonewars_camera_compositor_count >= 128) return;
    const thread = s.win.GetCurrentThreadId();
    if (thread != s.clonewars_camera_threads[0] or !s.readable(view, 0xb4) or !s.readable(parent, 0x13c8)) return;
    if (load(u32, view) != 0xc3dc94 or load(u32, parent) != 0xc3e248) return;
    const role = load(i16, view + 0xac);
    if (role < 0 or role > 1 or phase > 1 or call_id == null) return;
    if (phase == 0) {
        if (s.compositor_call_serial == 0xffffffff) return;
        s.compositor_call_serial += 1;
        call_id.?.* = s.compositor_call_serial;
    }
    if (call_id.?.* == 0) return;
    var row: [80]u32 = @splat(0);
    var valid: u32 = 3;
    row[1..6].* = .{ 2, @as(u32, @bitCast(s.clonewars_camera_compositor_count)) +% 1, thread, load(u32, 0xfb4b6c), load(u32, 0xfb4b74) };
    var time: i64 = 0;
    _ = s.platform.QueryPerformanceCounter(&time);
    row[6] = @truncate(@as(u64, @bitCast(time)));
    row[7] = @truncate(@as(u64, @bitCast(time)) >> 32);
    row[8..15].* = .{ view, parent, @intCast(role), load(u32, view + 0x34), load(u32, 0xeb8374), load(u32, parent + 0x13c4), @as(u32, load(u8, 0xe63007)) | @as(u32, load(u8, 0xe63008)) << 8 | @as(u32, load(u8, 0xe63009)) << 16 };
    const gate = load(usize, 0xf9c80c);
    row[15] = gate;
    row[16] = 0xffffffff;
    if (s.readable(gate, 0x24)) {
        row[16] = load(u32, gate + 0x20);
        valid |= 4;
    }
    row[17..21].* = .{ load(u32, 0xfb2e6c), load(u32, 0xfb11dc), load(u32, 0xfb11fc), load(u32, 0xfb1200) };
    const target = load(usize, view + 0xa8);
    row[21] = target;
    if (s.readable(target, 0x3c)) {
        valid |= 8;
        const object = load(usize, target + 0x30);
        row[22] = object;
        row[23] = load(u32, target + 0x38);
        if (s.readable(object, 0xd80)) {
            valid |= 16;
            const pair = load(usize, object + 0xd7c);
            row[24] = pair;
            if (s.readable(pair, 8)) {
                valid |= 32;
                row[25..27].* = load([2]u32, pair);
            }
        }
    }
    row[27..31].* = .{ valid, native_result & 255, s.clonewars_camera_fullclip, @bitCast(s.camera_selected()) };
    row[32] = phase;
    row[33] = call_id.?.*;
    row[34] = @intFromBool(phase == 1);
    const before_gpu = s.gpu_observation_serial;
    observeGpu(view, parent, role, thread, true);
    if (s.gpu_observation_serial != before_gpu) {
        row[31] = 1;
        row[40..80].* = s.clonewars_camera_gpu_observation[@intCast(role)];
    }
    const index: u32 = @bitCast(s.clonewars_camera_compositor_count);
    if (index >= 128) return;
    const output = &s.clonewars_camera_compositor_rows[index];
    @atomicStore(u32, &output[0], 0, .seq_cst);
    output[1..80].* = row[1..80].*;
    @atomicStore(u32, &output[0], index + 1, .seq_cst);
    @atomicStore(i32, &s.clonewars_camera_compositor_count, @intCast(index + 1), .seq_cst);
}
fn captureImpl(view: usize, parent: usize) void {
    if (!s.readable(view, 0xb4) or load(usize, view) != 0xc3dc94) return;
    const player = load(i16, view + 0xac);
    const thread = s.win.GetCurrentThreadId();
    if (player >= 0 and player < 2) s.clonewars_camera_threads[@intCast(player + 1)] = thread;
    observeGpu(view, parent, player, thread, false);
    if (thread != s.clonewars_camera_threads[0] or s.clonewars_camera_fullclip & 4 != 0) return;
    if (!s.personalAllowed(parent) or !s.ordinaryLayout(parent) or load(u32, parent + 0xf20) != 2 or s.focus_manager != parent or load(usize, parent + 0x1c) != 0xe62090 or !s.readable(view, 0xb4) or load(usize, view) != 0xc3dc94 or s.game_device == 0) return;
    var surface: usize = 0;
    if (gpu.target(s.game_device, &surface) < 0) return;
    defer gpu.release(surface);
    if (player >= 0 and player < 2) {
        s.clonewars_camera_debug[@intCast(player)] = surface;
        var viewport: s.Viewport = undefined;
        if (gpu.viewport(s.game_device, &viewport) >= 0) {
            var description: s.Description = undefined;
            _ = gpu.description(surface, &description);
            const i: usize = @intCast(player);
            s.clonewars_camera_viewport[i * 6 ..][0..6].* = .{ viewport.x, viewport.y, viewport.width, viewport.height, description.width, description.height };
            var rectangle: s.Rect = undefined;
            var enabled: u32 = 0;
            if (gpu.scissor(s.game_device, &rectangle) >= 0) s.clonewars_camera_viewport[12 + i * 5 ..][0..4].* = .{ @bitCast(rectangle.left), @bitCast(rectangle.top), @bitCast(rectangle.right), @bitCast(rectangle.bottom) };
            _ = gpu.state(s.game_device, 174, &enabled);
            s.clonewars_camera_viewport[16 + i * 5] = enabled;
        }
    }
    if (player != s.viewRole(parent)) return;
    var description: s.Description = undefined;
    _ = gpu.description(surface, &description);
    s.clonewars_camera_debug[2] = description.width;
    s.clonewars_camera_debug[3] = description.height;
    s.clonewars_camera_debug[5] +%= 1;
    if (s.tap_surface != 0) {
        var stored: s.Description = undefined;
        _ = gpu.description(s.tap_surface, &stored);
        if (stored.width != description.width or stored.height != description.height or stored.format != description.format) {
            gpu.release(s.tap_surface);
            s.tap_surface = 0;
        }
    }
    if (s.tap_surface == 0) _ = gpu.create(s.game_device, description.width, description.height, description.format, &s.tap_surface);
    if (s.tap_surface != 0 and gpu.stretch(s.game_device, surface, null, s.tap_surface, null, 0) >= 0) {
        gpu.release(s.selected_target);
        gpu.addRef(s.tap_surface);
        s.selected_target = s.tap_surface;
        s.selected_target_player = player;
    }
}
pub fn captureView(view: usize, parent: usize) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    captureImpl(view, parent);
}
pub fn finishView(view: usize) callconv(.c) void {
    s.original_view_finish(view);
    captureView(view, s.currentManager());
}
