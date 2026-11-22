const std = @import("std");
const s = @import("camera_state.zig");
const layout = @import("camera_layout.zig");
const window = @import("camera_window.zig");
const hooks = @import("hook_transaction.zig");
const log = @import("camera_log.zig").line;
extern fn camera_order_hook() void;
extern fn camera_target_end() void;
extern fn background_device_guard() void;
export const background_device_continue: usize = 0x63b307;
export const background_device_skip: usize = 0x63b310;
pub fn callAt(site: usize, native: usize, target: usize, allowed: bool, prefix: []const u8) c_int {
    if (!allowed or site == 0 or native == 0 or target == 0 or !s.readable(native, prefix.len) or !s.readable(site, 5) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(native))[0..prefix.len], prefix) or s.load(u8, site) != 0xe8) return 0;
    const destination = site +% 5 +% s.load(u32, site + 1);
    if (destination == target) return 1;
    if (destination != native) return 0;
    var expected: [5]u8 = undefined;
    expected[0] = 0xe8;
    std.mem.writeInt(u32, expected[1..5], @truncate(native -% site -% 5), .little);
    const patches = [_]hooks.Patch{.{ .address = site, .expected = &expected, .target = target, .opcode = 0xe8 }};
    return @intFromBool(hooks.apply(&patches));
}
fn replace(comptime Function: type, at: usize, expected: usize, replacement: usize, original: *?Function) void {
    if (s.load(usize, at) != expected) return;
    var protection: u32 = 0;
    if (s.win.VirtualProtect(at, 4, 4, &protection) == 0) return;
    original.* = @ptrFromInt(expected);
    s.store(usize, at, replacement);
    var unused: u32 = 0;
    _ = s.win.VirtualProtect(at, 4, protection, &unused);
}
fn trampoline(comptime Function: type, at: usize, prefix: []const u8, target: usize, original: *?Function) bool {
    if (!s.readable(at, prefix.len) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(at))[0..prefix.len], prefix)) return false;
    const bridge = s.win.VirtualAlloc(0, prefix.len + 5, 0x3000, 0x40);
    if (bridge == 0) return false;
    const bytes: [*]u8 = @ptrFromInt(bridge);
    @memcpy(bytes[0..prefix.len], prefix);
    s.store(u8, bridge + prefix.len, 0xe9);
    s.store(u32, bridge + prefix.len + 1, @truncate(at +% prefix.len -% bridge -% prefix.len -% 5));
    if (s.win.FlushInstructionCache(s.win.GetCurrentProcess(), bridge, prefix.len + 5) == 0) {
        _ = s.win.VirtualFree(bridge, 0, 0x8000);
        return false;
    }
    const previous = original.*;
    original.* = @ptrFromInt(bridge);
    const patches = [_]hooks.Patch{.{ .address = at, .expected = prefix, .target = target }};
    if (!hooks.apply(&patches)) {
        original.* = previous;
        _ = s.win.VirtualFree(bridge, 0, 0x8000);
        return false;
    }
    return true;
}
pub fn mainInstall(module: usize) bool {
    s.diagnostics_install(module);
    if (s.background_capture) {
        // A background device reset can leave a surface without its native interface.
        const patches = [_]hooks.Patch{.{ .address = 0x63b302, .expected = "\x8b\x08\x8d\x56\x10", .target = @intFromPtr(&background_device_guard) }};
        if (hooks.apply(&patches)) log("background device reset guard installed");
    }
    for (s.tables, &s.originals) |table, *original| {
        const target = table + 8;
        var protection: u32 = 0;
        if (s.win.VirtualProtect(target, 4, 4, &protection) == 0) {
            log("VirtualProtect failed");
            return false;
        }
        original.* = @ptrFromInt(s.load(usize, target));
        _ = @atomicRmw(usize, @as(*usize, @ptrFromInt(target)), .Xchg, @intFromPtr(&layout.update), .seq_cst);
        var unused: u32 = 0;
        _ = s.win.VirtualProtect(target, 4, protection, &unused);
    }
    s.previous_proc = @bitCast(s.platform.GetWindowLongW(s.game_window, -4));
    s.win.SetLastError(0);
    const replaced = s.platform.SetWindowLongW(s.game_window, -4, @bitCast(@as(usize, @intFromPtr(&window.procedure))));
    if (replaced == 0 and s.win.GetLastError() != 0) s.previous_proc = 0;
    log(if (s.previous_proc != 0) "F12 menu installed; camera override off" else "window hook failed");
    if (s.previous_proc == 0) return false;
    s.network_window_configure(s.game_window);
    const loading = s.loading_install() != 0;
    log(if (loading) "loading completion and intro synchronization installed" else "loading hook validation failed");
    replace(s.Centers, s.tables[2] + 0x48, 0x775360, @intFromPtr(&layout.centers), &s.original_layout_centers);
    replace(s.Clip, s.tables[0] + 0x24, 0x775020, @intFromPtr(&layout.clip), &s.original_clip);
    _ = trampoline(s.Views, 0x7815f0, "\x55\x8b\xec\x83\xe4\xf0", @intFromPtr(&layout.renderViews), &s.original_render_views);
    s.personal_hooks_ready = s.original_layout_centers != null and s.original_clip != null and s.original_render_views != null;
    if (s.clonewars_camera_native_order_installed == 0) {
        const result = callAt(0x7834ed, 0x77fe40, @intFromPtr(&camera_order_hook), s.win.GetCurrentThreadId() == s.platform.GetWindowThreadProcessId(s.game_window, null), "\x83\xec\x0c\x53\x55\x33\xd2");
        s.clonewars_camera_native_order_installed = if (result == 1) 1 else -1;
    }
    _ = callAt(0x732bd9, 0x731d00, @intFromPtr(&layout.modelRender), s.clonewars_camera_native_order_installed == 1, "\x55\x8b\xec\x83\xe4\xf0\x6a\xff");
    log(if (s.personal_hooks_ready) "native fullscreen camera hooks installed" else "native fullscreen camera hooks incomplete");
    @import("camera_saber.zig").install();
    var finish: ?*const fn (usize) callconv(.c) void = null;
    if (trampoline(*const fn (usize) callconv(.c) void, 0x756080, "\x8b\x4c\x24\x04\xa1\x14\x0b\xfb\x00", @intFromPtr(&@import("camera_observe.zig").finishView), &finish)) {
        s.original_view_finish = finish.?;
        log("native view finish capture hook installed");
    }
    const end_site: usize = 0x781659;
    if (s.readable(end_site, 5) and s.load(u8, end_site) == 0xe8 and end_site +% 5 +% s.load(u32, end_site + 1) == 0x77afa0) {
        var prefix: [5]u8 = undefined;
        prefix[0] = 0xe8;
        std.mem.writeInt(u32, prefix[1..5], 0x77afa0 -% end_site -% 5, .little);
        const patches = [_]hooks.Patch{.{ .address = end_site, .expected = &prefix, .target = @intFromPtr(&camera_target_end), .opcode = 0xe8 }};
        if (hooks.apply(&patches)) log("native camera surface tap installed");
    }
    return s.personal_hooks_ready and loading;
}
pub export fn camera_install_qualified_main() c_int {
    if (s.game_window == 0 or s.win.GetCurrentThreadId() != s.platform.GetWindowThreadProcessId(s.game_window, null) or s.main_install_state < 0) return 0;
    if (s.main_install_state == 0) {
        s.main_install_state = -1;
        if (!mainInstall(s.camera_module)) return 0;
        s.main_install_state = 1;
    }
    @import("camera_present.zig").install();
    return 1;
}
comptime {
    _ = @import("camera_resume.zig");
    _ = @import("camera_bridges.zig");
}
