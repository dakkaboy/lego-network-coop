const std = @import("std");
const s = @import("camera_state.zig");
const load = s.load;
const store = s.store;
const equal = @import("validation.zig").equal;
pub export const camera_order_default_mxcsr: u32 = 0x1f80;
pub threadlocal var depth: u32 = 0;
threadlocal var nested = false;
pub const Family = extern struct { views: [2]usize, targets: [2]usize, backgrounds: [2]usize, children: [2]usize, context: usize };
pub var prepared_parent: usize = 0;
pub var prepared_role: i32 = -1;
pub var prepared_logical: i32 = -1;
pub var prepared: Family = std.mem.zeroes(Family);
pub const Scope = extern struct { parent: usize, family: Family, thread: u32, entered: u32, admitted: u32, swapped: u32, selected: u32, logical: u32 };
pub const Bridge = extern struct {
    in_fx: [512]u8,
    out_fx: [512]u8,
    in_regs: [9]u32,
    out_regs: [9]u32,
    in_error: u32,
    out_error: u32,
    entry_esp: u32,
    saved_esp: u32,
    target: usize,
    reserved: u32,
    helper_fx: [512]u8,
    reserved_metadata: [120]u8,
    argument: u32,
    storage: [1024]u8,
};
comptime {
    if (@offsetOf(Bridge, "target") != 1112 or @offsetOf(Bridge, "argument") != 1752 or @offsetOf(Bridge, "storage") != 1756 or @sizeOf(Scope) > 1024) @compileError("camera order bridge ABI");
}
pub fn family(parent: usize, out: *Family) bool {
    if (!s.readable(parent, 0x1420) or parent != s.currentManager() or load(usize, parent) != 0xc3e248) return false;
    const slots = load([4]usize, parent + 0xf24);
    if (slots[0] == 0 or slots[1] == 0 or slots[0] == slots[1]) return false;
    var roles: u32 = 0;
    for (0..2) |i| {
        const view = slots[i];
        if (!s.readable(view, 0xb4) or load(usize, view) != 0xc3dc94 or load(u32, view + 0x2c) != 1 or load(usize, view + 0xb0) != parent) return false;
        const role = load(i16, view + 0xac);
        if (role < 0 or role > 1 or roles & (@as(u32, 1) << @intCast(role)) != 0) return false;
        roles |= @as(u32, 1) << @intCast(role);
        const target = load(usize, view + 0xa8);
        if (!s.readable(target, 0x48) or load(usize, target) != 0xc3db4c or load(usize, target + 0x44) != parent or load(usize, target + 0x10) != 0xe62010) return false;
        out.views[i] = view;
        out.targets[i] = target;
    }
    if (roles != 3) return false;
    out.context = 0;
    for (0..2) |i| {
        out.backgrounds[i] = slots[i + 2];
        out.children[i] = load(usize, out.views[i] + 0x28);
    }
    if (out.backgrounds[0] == 0 and out.backgrounds[1] == 0) return out.children[0] == 0 and out.children[1] == 0;
    out.context = load(usize, parent + 0xc);
    if (!s.readable(out.context, 4) or (out.backgrounds[0] != 0 and out.backgrounds[0] == out.backgrounds[1])) return false;
    for (0..2) |i| {
        if (load(usize, out.views[i] + 0x30) != out.context) return false;
        const child = out.children[i];
        const background = out.backgrounds[i];
        if (child != 0 and child != out.backgrounds[0] and child != out.backgrounds[1]) return false;
        if (background == 0) continue;
        if (background == out.views[0] or background == out.views[1] or !s.readable(background, 0xac) or load(usize, background) != 0xc3e21c or load(u32, background + 0x2c) != 2 or load(usize, background + 0x30) != out.context or @as(u32, @intFromBool(out.children[0] == background)) + @intFromBool(out.children[1] == background) != 1) return false;
    }
    return true;
}
fn restoreLive(scope: *const Scope) bool {
    const parent = scope.parent;
    const f = &scope.family;
    if (parent != s.currentManager() or !s.readable(parent, 0x1420) or load(usize, parent) != 0xc3e248) return false;
    const slots = load([2]usize, parent + 0xf24);
    if (slots[0] != f.views[1] or slots[1] != f.views[0]) return false;
    for (f.views, f.targets) |view, target| if (!s.readable(view, 0xb4) or load(usize, view) != 0xc3dc94 or load(usize, view + 0xb0) != parent or load(usize, view + 0xa8) != target or !s.readable(target, 0x48) or load(usize, target) != 0xc3db4c or load(usize, target + 0x44) != parent) return false;
    return true;
}
pub export fn camera_order_enter(bridge: *Bridge) void {
    const scope: *align(1) Scope = @ptrCast(&bridge.storage);
    scope.* = std.mem.zeroes(Scope);
    bridge.target = 0x77fe40;
    scope.entered = 1;
    scope.thread = s.win.GetCurrentThreadId();
    depth +%= 1;
    if (depth > 1) {
        nested = true;
        return;
    }
    nested = false;
    if (depth != 1 or scope.thread != s.clonewars_camera_threads[0] or scope.thread != s.platform.GetWindowThreadProcessId(s.game_window, null)) return;
    prepared_parent = 0;
    prepared_role = -1;
    prepared_logical = -1;
    if (s.clonewars_camera_native_order_enabled == 0 or s.clonewars_camera_native_order_installed != 1) return;
    const parent = bridge.in_regs[6];
    if (scope.thread != s.clonewars_camera_threads[0] or scope.thread != s.platform.GetWindowThreadProcessId(s.game_window, null) or !s.personalFullscreen(parent)) return;
    var f: Family = undefined;
    if (!family(parent, &f)) return;
    const logical = s.camera_selected();
    if (logical < 0 or logical > 1) return;
    const selected = s.viewRole(parent);
    if (selected < 0 or selected > 1) return;
    scope.parent = parent;
    scope.family = f;
    scope.selected = @intCast(selected);
    scope.logical = @intCast(logical);
    scope.admitted = 1;
    const copy_resolved_view = s.clonewars_camera_fullclip & 16 != 0;
    const selected_first = load(i16, f.views[0] + 0xac) == selected;
    if (copy_resolved_view != selected_first) {
        store([2]usize, parent + 0xf24, .{ f.views[1], f.views[0] });
        scope.swapped = 1;
        s.clonewars_camera_native_order_debug[0] +%= 1;
    }
    s.clonewars_camera_native_order_debug[1] +%= 1;
}
fn moveHud(scope: *align(1) const Scope) void {
    if (s.clonewars_camera_fullclip & 16 == 0) return;
    const first_view = scope.family.views[scope.swapped];
    const last_view = scope.family.views[@intFromBool(scope.swapped == 0)];
    if (load(i16, first_view + 0xac) != scope.selected or load(u32, first_view + 0x34) != 1 or load(u32, last_view + 0x34) != 2) return;
    const first: usize = 0xeb8390 + 0x14f0;
    const last = first + 0x14f0;
    if (load(usize, first + 0x40) != 0 or load(usize, first + 0x64) != 0 or load(usize, last + 0x40) != 0x7560b0 or load(usize, last + 0x64) != last_view) return;
    store(usize, first + 0x64, first_view);
    store(usize, first + 0x40, 0x7560b0);
    store(usize, last + 0x40, 0);
    store(usize, last + 0x64, 0);
    s.clonewars_camera_native_order_debug[7] +%= 1;
}
pub export fn camera_order_leave(bridge: *Bridge, unwound: c_int) void {
    const scope: *align(1) Scope = @ptrCast(&bridge.storage);
    var restored = true;
    if (scope.swapped != 0) {
        restored = restoreLive(@alignCast(scope));
        if (restored) {
            store([2]usize, scope.parent + 0xf24, scope.family.views);
            s.clonewars_camera_native_order_debug[2] +%= 1;
        } else s.clonewars_camera_native_order_debug[3] +%= 1;
    }
    if (scope.admitted != 0 and !nested and unwound == 0 and restored and s.clonewars_camera_native_order_enabled != 0 and scope.parent == s.currentManager()) {
        var f: Family = undefined;
        if (family(scope.parent, &f) and equal(&f, &scope.family) and s.camera_selected() == @as(i32, @intCast(scope.logical)) and s.viewRole(scope.parent) == @as(i32, @intCast(scope.selected))) {
            moveHud(scope);
            prepared_parent = scope.parent;
            prepared = f;
            prepared_role = @intCast(scope.selected);
            prepared_logical = @intCast(scope.logical);
            s.clonewars_camera_native_order_debug[4] = bridge.out_regs[7];
            s.clonewars_camera_native_order_debug[5] +%= 1;
        }
    }
    if (unwound != 0) s.clonewars_camera_native_order_debug[6] +%= 1;
    if (scope.entered != 0 and depth != 0) depth -= 1;
}
pub fn presentationReady(parent: usize) bool {
    if (s.clonewars_camera_native_order_enabled == 0 or s.clonewars_camera_native_order_installed != 1 or depth != 0 or parent != prepared_parent or prepared_logical != s.camera_selected() or prepared_role != s.viewRole(parent)) return false;
    var f: Family = undefined;
    return family(parent, &f) and equal(&f, &prepared);
}
pub fn reset() void {
    s.layout_cache_manager = 0;
    s.layout_cache_fullscreen = -1;
    prepared_parent = 0;
    prepared_role = -1;
    prepared_logical = -1;
    prepared.views = @splat(0);
}
