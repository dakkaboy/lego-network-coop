const std = @import("std");
const s = @import("camera_state.zig");
const order = @import("camera_order.zig");
const win = s.win;
const load = s.load;
const store = s.store;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
pub const camera_test_api = struct {
    pub fn GetWindowThreadProcessId(window: usize, out: ?*u32) u32 {
        check(@src(), window == 9 and out == null);
        return win.GetCurrentThreadId();
    }
};
export fn lan_status() c_int {
    return 3;
}
var parent: usize = 0;
var context: usize = 0;
var views: [2]usize = undefined;
var targets: [2]usize = undefined;
var backgrounds: [2]usize = undefined;
var guards: [2]usize = undefined;
var root: usize = 0;
var box: usize = 0;
fn allocate(size: usize) usize {
    const value = win.VirtualAlloc(0, size, 0x3000, 4);
    check(@src(), value != 0);
    return value;
}
fn zero(address: usize, size: usize) void {
    @memset(@as([*]u8, @ptrFromInt(address))[0..size], 0);
}
fn prepare(extra: usize) void {
    s.camera_select(1);
    zero(parent, 0x2000);
    store(usize, box + 0x28, parent);
    store(usize, parent, 0xc3e248);
    store(usize, parent + 0xc, context);
    store(usize, parent + 0x1c, 0xe62090);
    store(u32, parent + 0xf20, 2);
    store(i32, parent + 0x13c0, -1);
    for (0..2) |i| {
        zero(views[i], 0xb4);
        zero(targets[i], 0x1000);
        zero(backgrounds[i], 0xac);
        store(usize, views[i], 0xc3dc94);
        store(u32, views[i] + 0x2c, 1);
        store(usize, views[i] + 0x30, context);
        store(i16, views[i] + 0xac, @intCast(i));
        store(usize, views[i] + 0xb0, parent);
        store(usize, views[i] + 0xa8, targets[i]);
        store(usize, targets[i], 0xc3db4c);
        store(usize, targets[i] + 0x10, 0xe62010);
        store(usize, targets[i] + 0x44, parent);
        store(usize, parent + 0xf24 + i * 4, views[i]);
        if (i < extra) {
            store(usize, backgrounds[i], 0xc3e21c);
            store(u32, backgrounds[i] + 0x2c, 2);
            store(usize, backgrounds[i] + 0x30, context);
            store(usize, views[i] + 0x28, backgrounds[i]);
            store(usize, parent + 0xf24 + (i + 2) * 4, backgrounds[i]);
        }
    }
    s.clonewars_camera_native_order_enabled = 1;
    s.clonewars_camera_native_order_installed = 1;
    s.personal_hooks_ready = true;
    s.clonewars_camera_threads[0] = win.GetCurrentThreadId();
    zero(0xeb8390, 0x6000);
}
fn pair() bool {
    var family: order.Family = undefined;
    return order.family(parent, &family);
}
fn enter(bridge: *order.Bridge) void {
    bridge.* = std.mem.zeroes(order.Bridge);
    bridge.in_regs[6] = parent;
    order.camera_order_enter(bridge);
}
fn scope(bridge: *order.Bridge) *align(1) order.Scope {
    return @ptrCast(&bridge.storage);
}
fn nativePrepare() void {
    var pass: u32 = 1;
    for (0..4) |i| {
        const view = load(usize, parent + 0xf24 + i * 4);
        if (view != 0 and load(u32, view + 0x2c) == 1) {
            store(u32, view + 0x34, pass);
            pass += 1;
        }
    }
}
var render_throws = false;
var render_calls: u32 = 0;
fn renderNative(_: usize, parent_arg: usize, _: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), parent_arg == parent and load(u32, parent + 0x13bc) == 0 and load(u8, 0xe63007) == 0);
    render_calls += 1;
    win.SetLastError(554);
    if (render_throws) win.RaiseException(0xe1234567, 0, 0, null);
}
fn modelNative(scene: usize, event: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), scene == 91 and event == 92 and load(u16, 0xd78430) == 0);
    render_calls += 1;
    win.SetLastError(554);
    if (render_throws) win.RaiseException(0xe1234567, 0, 0, null);
}
fn centersNative(_: usize, parent_arg: usize) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), parent_arg == parent);
    render_calls += 1;
}
fn clipNative(state: usize, parent_arg: usize, _: [*]f32, camera: usize, role: c_int) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), state == 81 and parent_arg == parent and camera == 82 and role == 1);
    render_calls += 1;
    return 7;
}
fn renderInvoke(_: usize) callconv(.c) c_int {
    @import("camera_layout.zig").renderViews(81, 0, parent, 82);
    return 1;
}
fn modelInvoke(_: usize) callconv(.c) c_int {
    @import("camera_layout.zig").modelRender(91, 0, 92);
    return 1;
}
fn layoutTests() void {
    const layout = @import("camera_layout.zig");
    const seh = @import("seh_guard.zig");
    prepare(2);
    s.original_clip = clipNative;
    s.original_layout_centers = centersNative;
    s.original_render_views = renderNative;
    var output: [4]f32 = @splat(-1);
    render_calls = 0;
    check(@src(), layout.clip(81, 0, parent, &output, 82, 1) == 1 and std.mem.eql(f32, &output, &.{ 0.5, 0.5, 0, 1 }) and render_calls == 0);
    s.clonewars_camera_fullclip &= ~@as(u32, 64);
    check(@src(), layout.clip(81, 0, parent, &output, 82, 1) == 7 and render_calls == 1);
    s.clonewars_camera_fullclip |= 64;
    layout.centers(81, 0, parent);
    check(@src(), render_calls == 2);
    for (targets) |target| check(@src(), std.mem.eql(f32, &load([4]f32, target + 0x50), &.{ 0.5, 0.5, 0, 1 }));
    for (0..2) |throws| {
        store(u32, parent + 0x13bc, 0x3f200000);
        store(u8, 0xe63007, 19);
        render_throws = throws != 0;
        check(@src(), seh.all(0, renderInvoke) == @as(c_int, @intFromBool(!render_throws)));
        check(@src(), load(u32, parent + 0x13bc) == 0x3f200000 and load(u8, 0xe63007) == 19 and win.GetLastError() == 554);
        for (targets) |target| check(@src(), load(i32, target + 0xc0) == 4 and std.mem.eql(f32, &load([4]f32, target + 0xd0), &.{ 0.5, 0.5, 0, 1 }));
    }
    const model_site: usize = 0x731d00;
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(model_site, 5, 0x40, &old) != 0);
    store(u8, model_site, 0xe9);
    store(u32, model_site + 1, @intFromPtr(&modelNative) -% model_site -% 5);
    check(@src(), win.VirtualProtect(model_site, 5, 0x20, &old) != 0);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), model_site, 5) != 0);
    prepare(2);
    var bridge: order.Bridge align(16) = undefined;
    enter(&bridge);
    nativePrepare();
    order.camera_order_leave(&bridge, 0);
    check(@src(), order.presentationReady(parent));
    for (0..2) |throws| {
        store(u16, 0xd78430, 55);
        store(u32, 0xeb8374, 1);
        render_throws = throws != 0;
        check(@src(), seh.all(0, modelInvoke) == @as(c_int, @intFromBool(!render_throws)));
        check(@src(), load(u16, 0xd78430) == 55 and win.GetLastError() == 554);
    }
}
fn roleBindings() void {
    const actors = [_]usize{ allocate(0x1440), allocate(0x1440) };
    const controllers = [_]usize{ allocate(0x800), allocate(0x800) };
    const frames = [_]usize{ allocate(0x300), allocate(0x300) };
    defer {
        for (actors ++ controllers ++ frames) |address| _ = win.VirtualFree(address, 0, 0x8000);
        store([2]usize, 0xfb4940, .{ 0, 0 });
        store(u32, root, 0);
        store(u32, box, 0);
        store(u32, box + 0x20, 0);
    }
    store(u32, root, 0xc5160c);
    store(u32, box, 0xc51554);
    store(u32, box + 0x20, 2);
    store([2]usize, 0xfb4940, actors);
    store([2]usize, box + 0x30, controllers);
    for (controllers, frames, 0..) |controller, frame, role| {
        store(usize, controller + 0x1c, frame);
        store(u16, controller + 0x750, @intCast(role));
    }
    for (0..2) |swapped| for (0..2) |logical| {
        prepare(0);
        s.camera_select(@intCast(logical));
        for (controllers, 0..) |controller, role| store(usize, controller + 0x754, actors[role ^ swapped]);
        win.SetLastError(915);
        check(@src(), s.viewRole(parent) == logical ^ swapped and win.GetLastError() == 915);
        var bridge: order.Bridge align(16) = undefined;
        enter(&bridge);
        check(@src(), scope(&bridge).admitted == 1 and scope(&bridge).selected == logical ^ swapped and scope(&bridge).logical == logical);
        check(@src(), load(usize, parent + 0xf24) == views[logical ^ swapped]);
        nativePrepare();
        order.camera_order_leave(&bridge, 0);
        check(@src(), order.presentationReady(parent) and load([2]usize, parent + 0xf24)[0] == views[0]);
        if (swapped == 1) {
            for (controllers, 0..) |controller, role| store(usize, controller + 0x754, actors[role]);
            check(@src(), !order.presentationReady(parent));
        }
    };
    for (0..10) |invalid| {
        prepare(0);
        s.camera_select(0);
        store(u32, root, 0xc5160c);
        store(u32, box, 0xc51554);
        store(u32, box + 0x20, 2);
        store([2]usize, 0xfb4940, actors);
        store([2]usize, box + 0x30, controllers);
        for (controllers, frames, 0..) |controller, frame, role| {
            store(usize, controller + 0x1c, frame);
            store(u16, controller + 0x750, @intCast(role));
            store(usize, controller + 0x754, actors[1 - role]);
        }
        switch (invalid) {
            0 => store(u32, root, 0),
            1 => store(u32, box, 0),
            2 => store(usize, box + 0x28, root),
            3 => store(u32, box + 0x20, 3),
            4 => store(usize, box + 0x34, controllers[0]),
            5 => store(u16, controllers[1] + 0x750, 0),
            6 => store(usize, controllers[1] + 0x754, actors[1]),
            7 => store(usize, controllers[1] + 0x1c, 1),
            8 => store([2]usize, 0xfb4940, .{ actors[0], actors[0] }),
            9 => store(usize, controllers[0] + 0x754, parent),
            else => unreachable,
        }
        win.SetLastError(916);
        check(@src(), s.viewRole(parent) == 0 and win.GetLastError() == 916);
    }
}
pub fn main() void {
    parent = allocate(0x2000);
    context = allocate(0x1000);
    root = allocate(0x2000);
    box = allocate(0x1000);
    defer {
        _ = win.VirtualFree(parent, 0, 0x8000);
        _ = win.VirtualFree(context, 0, 0x8000);
        _ = win.VirtualFree(root, 0, 0x8000);
        _ = win.VirtualFree(box, 0, 0x8000);
    }
    check(@src(), @intFromPtr(&owned_image) <= 0xe90000 and @intFromPtr(&owned_image) + owned_image.len >= 0xfb2000);
    store(usize, 0xe9018c, root);
    store(usize, root + 0x28, box);
    store(usize, 0xfb2e60, root);
    store(i32, root + 0x1b78, 0xe);
    store(i32, 0xe6e61c, -1);
    store(i32, 0xfb11dc, 2);
    s.game_window = 9;
    for (0..2) |i| {
        views[i] = allocate(0x1000);
        targets[i] = allocate(0x1000);
        guards[i] = allocate(0x2000);
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(guards[i] + 0x1000, 0x1000, 1, &old) != 0);
        backgrounds[i] = guards[i] + 0x1000 - 0xac;
    }
    defer for (0..2) |i| {
        _ = win.VirtualFree(views[i], 0, 0x8000);
        _ = win.VirtualFree(targets[i], 0, 0x8000);
        _ = win.VirtualFree(guards[i], 0, 0x8000);
    };
    roleBindings();
    var bridge: order.Bridge align(16) = undefined;
    for (0..3) |extra| for (0..2) |role| {
        prepare(extra);
        s.camera_select(@intCast(role));
        check(@src(), pair());
        var before: [2][0xac]u8 = undefined;
        for (0..2) |i| before[i] = load([0xac]u8, backgrounds[i]);
        enter(&bridge);
        check(@src(), scope(&bridge).admitted != 0 and load(usize, parent + 0xf24) == views[role]);
        for (0..2) |i| check(@src(), load(usize, parent + 0xf24 + (i + 2) * 4) == if (i < extra) backgrounds[i] else 0);
        nativePrepare();
        order.camera_order_leave(&bridge, 0);
        check(@src(), order.depth == 0 and order.presentationReady(parent));
        check(@src(), std.mem.eql(usize, &load([2]usize, parent + 0xf24), &views));
        for (0..2) |i| check(@src(), std.mem.eql(u8, &before[i], &load([0xac]u8, backgrounds[i])));
    };
    for (0..9) |bad| {
        prepare(2);
        switch (bad) {
            0 => store(usize, backgrounds[0], 0xc3dc94),
            1 => store(u32, backgrounds[0] + 0x2c, 1),
            2 => store(usize, backgrounds[0] + 0x30, parent),
            3 => store(usize, views[0] + 0x28, 0),
            4 => store(usize, views[1] + 0x28, backgrounds[0]),
            5 => store(usize, parent + 0xf30, backgrounds[0]),
            6 => store(usize, parent + 0xc, 0),
            7 => store(usize, views[1] + 0x30, parent),
            8 => store(usize, parent + 0xf2c, views[0]),
            else => unreachable,
        }
        check(@src(), !pair());
        enter(&bridge);
        check(@src(), scope(&bridge).admitted == 0);
        nativePrepare();
        order.camera_order_leave(&bridge, 0);
        check(@src(), order.depth == 0 and !order.presentationReady(parent));
        check(@src(), std.mem.eql(usize, &load([2]usize, parent + 0xf24), &views));
    }
    for (0..5) |mutation| {
        prepare(2);
        enter(&bridge);
        check(@src(), scope(&bridge).swapped != 0);
        nativePrepare();
        var old: u32 = 0;
        switch (mutation) {
            0 => store(usize, parent + 0xf2c, 0),
            1 => store(usize, backgrounds[0] + 0x30, parent),
            2 => store(usize, views[0] + 0x28, backgrounds[1]),
            3 => check(@src(), win.VirtualProtect(backgrounds[0], 0xac, 1, &old) != 0),
            4 => store(usize, parent + 0xc, parent),
            else => unreachable,
        }
        order.camera_order_leave(&bridge, 0);
        check(@src(), std.mem.eql(usize, &load([2]usize, parent + 0xf24), &views) and order.depth == 0 and !order.presentationReady(parent));
        if (mutation == 3) check(@src(), win.VirtualProtect(backgrounds[0], 0xac, 4, &old) != 0);
    }
    prepare(2);
    enter(&bridge);
    nativePrepare();
    order.camera_order_leave(&bridge, 0);
    check(@src(), order.presentationReady(parent));
    store(usize, views[0] + 0x28, 0);
    check(@src(), !order.presentationReady(parent));
    prepare(2);
    enter(&bridge);
    nativePrepare();
    order.camera_order_leave(&bridge, 0);
    check(@src(), order.presentationReady(parent));
    store(usize, views[0] + 0xa8, targets[1]);
    check(@src(), !order.presentationReady(parent));
    prepare(2);
    enter(&bridge);
    var inner: order.Bridge align(16) = undefined;
    enter(&inner);
    nativePrepare();
    order.camera_order_leave(&inner, 0);
    order.camera_order_leave(&bridge, 0);
    check(@src(), order.depth == 0 and !order.presentationReady(parent) and std.mem.eql(usize, &load([2]usize, parent + 0xf24), &views));
    prepare(2);
    enter(&bridge);
    nativePrepare();
    order.camera_order_leave(&bridge, 1);
    check(@src(), order.depth == 0 and !order.presentationReady(parent) and std.mem.eql(usize, &load([2]usize, parent + 0xf24), &views));
    layoutTests();
}
comptime {
    _ = @import("lexical_seh.zig");
}
