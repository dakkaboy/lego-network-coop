const std = @import("std");
const loading = @import("loading.zig");
const win = @import("win32.zig");
const Loading = @import("protocol.zig").SyncLoading;
const check = @import("native_test_support.zig").check;
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var root: [0x3140]u8 align(16) = @splat(0);
var peer = std.mem.zeroes(Loading);
var published = std.mem.zeroes(Loading);
var epoch: u32 = 7;
var host: c_int = 0;
var target: c_int = 12;
var level: c_int = 12;
var status: i32 = 3;
var load_status: c_int = 0;
var complete_calls: u32 = 0;
var ready: u8 = 1;
pub export fn lan_remote_loading() Loading {
    return peer;
}
pub export fn lan_epoch() u32 {
    return epoch;
}
pub export fn lan_status() i32 {
    return status;
}
pub export fn lan_is_host() c_int {
    return host;
}
pub export fn lan_publish_loading(value: *const Loading, _: c_int) void {
    published = value.*;
}
pub export fn game_network_target_level() c_int {
    return target;
}
pub export fn game_current_level() c_int {
    return level;
}
pub export fn game_load_status() c_int {
    return load_status;
}
fn original(self: usize, _: c_int) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), self == @intFromPtr(&root));
    complete_calls += 1;
    return ready;
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) < 0x423ef0 and @intFromPtr(&owned_image) + owned_image.len > 0xfb843c);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(0x423ef0, 5, 0x40, &old) != 0);
    win.store(u8, 0x423ef0, 0xe9);
    win.store(u32, 0x423ef1, @truncate(@intFromPtr(&original) -% 0x423ef5));
    check(@src(), win.VirtualProtect(0x423ef0, 5, 0x20, &old) != 0);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), 0x423ef0, 5);
    win.store(usize, 0xadc2cc, 0x423ef0);
    check(@src(), loading.loading_install() == 1 and loading.loading_install() == 0);
    win.store(usize, 0xfb2e60, @intFromPtr(&root));
    win.store(i32, 0xfb8438, 12);
    win.store(i32, @intFromPtr(&root) + 0x1b78, 1);
    root[0x3130] = 1;
    peer = .{ .epoch = 7, .level = 12, .ready = 0, .skip = 1, .active = 1, .elapsed = 20 };
    win.store(f32, @intFromPtr(&root) + 0x3128, 10);
    loading.loading_poll();
    check(@src(), published.epoch == 7 and published.level == 12 and published.elapsed == 20 and published.skip == 1 and root[0x3130] == 5);
    peer.elapsed = 5;
    loading.loading_poll();
    check(@src(), published.elapsed == 20);
    peer.elapsed = std.math.nan(f32);
    loading.loading_poll();
    check(@src(), published.elapsed == 20);
    peer.elapsed = 30;
    host = 1;
    loading.loading_poll();
    check(@src(), published.elapsed == 20);
    host = 0;
    peer.epoch = 8;
    loading.loading_poll();
    check(@src(), published.elapsed == 20);
    peer.epoch = 7;
    const Complete = *const fn (usize, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
    const complete: Complete = @ptrFromInt(win.load(usize, 0xadc2cc));
    const object = @intFromPtr(&root);
    check(@src(), complete(object, 4) == 0 and complete_calls == 1);
    peer.ready = 1;
    check(@src(), complete(object, 4) == 1);
    peer.ready = 0;
    target = 13;
    check(@src(), complete(object, 4) == 1);
    target = 12;
    status = 0;
    check(@src(), complete(object, 4) == 1);
    status = 3;
    ready = 0;
    check(@src(), complete(object, 4) == 0);
    ready = 1;
    check(@src(), complete(object, 3) == 1);
    epoch = 8;
    peer.epoch = 7;
    loading.loading_poll();
    check(@src(), published.epoch == 8 and published.ready == 0);
    win.store(i32, @intFromPtr(&root) + 0x1b78, 0xd);
    win.store(i32, 0xe6e61c, 12);
    level = -1;
    loading.loading_poll();
    check(@src(), published.ready == 0);
    win.store(i32, 0xe6e61c, -1);
    target = 13;
    loading.loading_poll();
    check(@src(), published.ready == 0);
    target = 12;
    loading.loading_poll();
    check(@src(), published.epoch == 8 and published.level == 12 and published.ready != 0 and published.active == 0);
    level = 12;
    // The target is the current native world, but network transition completion still waits for its peer.
    epoch = 9;
    load_status = 1;
    level = -1;
    loading.loading_poll();
    check(@src(), published.ready == 0);
    level = 12;
    loading.loading_poll();
    check(@src(), published.epoch == 9 and published.level == 12 and published.ready != 0);
    load_status = 0;
    win.store(i32, @intFromPtr(&root) + 0x1b78, 0xe);
    win.store(i32, 0xe6e61c, -1);
    loading.loading_poll();
    check(@src(), published.ready != 0 and published.active == 0);
    load_status = 1;
    loading.loading_poll();
    check(@src(), published.ready == 0);
}
