const std = @import("std");
const s = @import("camera_state.zig");
const order = @import("camera_order.zig");
const load = s.load;
const store = s.store;
const fast = @import("std").builtin.CallingConvention{ .x86_fastcall = .{} };
const center = [4]f32{ 0.5, 0.5, 0, 1 };
const polygon = [16]f32{ 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1 };
extern fn tag_lexical_seh(usize, *const fn (usize) callconv(.c) c_int, *const fn (usize, c_int) callconv(.c) void) c_int;
const Render = struct { first: usize, second: usize, third: usize = 0, blur: u16 = 0, separator: u32 = 0, composite: u8 = 0, model: bool };
fn renderInvoke(context: usize) callconv(.c) c_int {
    const call: *Render = @ptrFromInt(context);
    if (call.model) {
        const render: *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x731d00);
        render(call.first, call.second);
    } else s.original_render_views.?(call.first, call.second, call.third);
    return 1;
}
fn renderLeave(context: usize, _: c_int) callconv(.c) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Render = @ptrFromInt(context);
    if (call.model) store(u16, 0xd78430, call.blur) else {
        store(u32, call.second + 0x13bc, call.separator);
        store(u8, 0xe63007, call.composite);
    }
}
pub fn modelRender(scene: usize, _: usize, event: usize) callconv(fast) void {
    const enabled = load(u16, 0xd78430);
    const segment = load(u32, 0xeb8374);
    const parent = order.prepared_parent;
    const error_code = s.win.GetLastError();
    const personal = enabled != 0 and segment >= 1 and segment <= 2 and s.clonewars_camera_fullclip & 16 != 0 and s.win.GetCurrentThreadId() == s.clonewars_camera_threads[0] and s.personalFullscreen(parent) and order.presentationReady(parent);
    s.win.SetLastError(error_code);
    if (!personal) {
        const render: *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x731d00);
        render(scene, event);
        return;
    }
    store(u16, 0xd78430, 0);
    s.clonewars_camera_native_order_debug[8] +%= 1;
    var call = Render{ .first = scene, .second = event, .blur = enabled, .model = true };
    _ = tag_lexical_seh(@intFromPtr(&call), renderInvoke, renderLeave);
}
pub fn clip(state: usize, _: usize, parent: usize, output: [*]f32, camera: usize, player: c_int) callconv(fast) u8 {
    if (s.personalFullscreen(parent)) {
        @memcpy(output[0..4], &center);
        s.clonewars_camera_debug[6] +%= 1;
        return 1;
    }
    return s.original_clip.?(state, parent, output, camera, player);
}
pub fn centers(state: usize, _: usize, parent: usize) callconv(fast) void {
    s.original_layout_centers.?(state, parent);
    if (!s.personalFullscreen(parent)) return;
    for (0..4) |i| {
        const view = load(usize, parent + 0xf24 + i * 4);
        if (!s.readable(view, 0xb4) or load(i32, view + 0x2c) != 1) continue;
        const target = load(usize, view + 0xa8);
        if (s.readable(target, 0x60)) store([4]f32, target + 0x50, center);
    }
}
pub fn renderViews(state: usize, _: usize, parent: usize, view: usize) callconv(fast) void {
    if (!s.personalFullscreen(parent)) {
        s.original_render_views.?(state, parent, view);
        return;
    }
    for (0..4) |i| {
        const candidate = load(usize, parent + 0xf24 + i * 4);
        if (!s.readable(candidate, 0xb4) or load(i32, candidate + 0x2c) != 1) continue;
        const target = load(usize, candidate + 0xa8);
        if (!s.readable(target, 0xe0)) continue;
        store([16]f32, target + 0x70, polygon);
        store(i32, target + 0xc0, 4);
        store([4]f32, target + 0xd0, center);
    }
    var call = Render{ .first = state, .second = parent, .third = view, .separator = load(u32, parent + 0x13bc), .composite = load(u8, 0xe63007), .model = false };
    store(f32, parent + 0x13bc, 0);
    store(u8, 0xe63007, 0);
    _ = tag_lexical_seh(@intFromPtr(&call), renderInvoke, renderLeave);
}
pub fn forgetFocus() void {
    s.focus_manager = 0;
    s.focus_player = -1;
    s.focus_state = 0;
    s.layout_cache_manager = 0;
    s.layout_cache_fullscreen = -1;
    s.clonewars_camera_debug[7] = 0;
}
fn transition(parent: usize, state: usize) void {
    const call: *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x77a550);
    call(parent, state);
}
pub fn releaseFocus() void {
    if (s.readable(s.focus_manager, 0x1420) and s.focus_manager == s.currentManager() and load(usize, s.focus_manager + 0x1c) == 0xe62090 and s.focus_state == 0xe62070) transition(s.focus_manager, s.focus_state);
    forgetFocus();
}
fn focus(parent: usize) void {
    if (!s.ordinaryLayout(parent)) {
        if (s.focus_manager != 0 and (s.focus_manager != parent or !s.readable(parent, 0x1420) or load(usize, parent + 0x1c) != 0xe62090)) forgetFocus();
        return;
    }
    var family: order.Family = undefined;
    if (!s.personalAllowed(parent) or !order.family(parent, &family)) {
        releaseFocus();
        return;
    }
    const state = load(usize, parent + 0x1c);
    if (s.focus_manager != 0 and (s.focus_manager != parent or state != 0xe62090)) releaseFocus();
    if (state == 0xe62070) {
        s.focus_manager = parent;
        s.focus_state = state;
        transition(parent, 0xe62090);
    }
    if (s.focus_manager == parent and load(usize, parent + 0x1c) == 0xe62090) {
        s.focus_player = s.camera_selected();
        s.clonewars_camera_debug[7] = @bitCast(s.focus_player +% 1);
    }
}
pub fn update(state: usize, _: usize, parent: usize, delta: usize, flag: u8) callconv(fast) void {
    const table = load(usize, state);
    const slot: usize = if (table == s.tables[0]) 0 else if (table == s.tables[1]) 1 else 2;
    const observed = parent == s.currentManager();
    if (observed) {
        s.manager = parent;
        s.camera_init_observer_snapshot(parent, 1, s.camera_selected());
        focus(parent);
        s.camera_init_observer_snapshot(parent, 2, s.camera_selected());
        var family: order.Family = undefined;
        if (s.focus_manager == parent and s.ordinaryLayout(parent) and order.family(parent, &family) and load(usize, parent + 0x1c) == 0xe62090) {
            const full: i32 = @intFromBool(s.personalFullscreen(parent));
            if (s.layout_cache_manager != parent or s.layout_cache_fullscreen != full) {
                store(u32, 0xfb11d8, 0);
                s.layout_cache_manager = parent;
                s.layout_cache_fullscreen = full;
            }
            s.originals[2](0xe62090, parent, delta, flag);
            s.camera_init_observer_snapshot(parent, 3, s.camera_selected());
            return;
        }
        const active = load(usize, parent + 0x1c);
        if (active != state and s.readable(active, 4)) {
            const active_table = load(usize, active);
            for (s.tables, 0..) |candidate, i| if (active_table == candidate) {
                s.originals[i](active, parent, delta, flag);
                s.camera_init_observer_snapshot(parent, 3, s.camera_selected());
                return;
            };
        }
    }
    s.originals[slot](state, parent, delta, flag);
    if (observed) s.camera_init_observer_snapshot(parent, 3, s.camera_selected());
}
