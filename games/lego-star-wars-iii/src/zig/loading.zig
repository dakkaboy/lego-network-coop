const std = @import("std");
const win = @import("win32.zig");
const Loading = @import("protocol.zig").SyncLoading;
extern fn lan_remote_loading() Loading;
extern fn lan_epoch() u32;
extern fn lan_status() i32;
extern fn lan_is_host() c_int;
extern fn lan_publish_loading(*const Loading, c_int) void;
extern fn game_network_target_level() c_int;
extern fn game_current_level() c_int;
extern fn game_load_status() c_int;
fn initial(epoch: u32, level: i32) Loading {
    return .{ .epoch = epoch, .level = level, .ready = 0, .skip = 0, .active = 0, .elapsed = 0 };
}
var own = initial(0, -1);
const Complete = *const fn (usize, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
var original: Complete = undefined;
var was_loading = false;
fn updateClock(root: usize, level: i32) void {
    const peer = lan_remote_loading();
    const phase = win.load(i32, root + 0x1b78);
    const in_loading = phase >= 1 and phase <= 3;
    const epoch = lan_epoch();
    if (own.epoch != epoch or own.level != level or (in_loading and !was_loading)) own = initial(epoch, level);
    was_loading = in_loading;
    var flags = win.load(u8, root + 0x3130);
    own.active = @intFromBool(flags & 1 != 0);
    if (own.active == 0) return;
    var skip = flags & 4 != 0;
    if (comptime @hasDecl(@import("root"), "background_loopback")) {
        skip = skip or @import("root").background_loopback.skipIntro();
    }
    if (epoch != 0 and lan_status() == 3 and peer.epoch == epoch and peer.level == level) {
        skip = skip or peer.skip != 0;
        if (lan_is_host() == 0 and peer.active != 0 and std.math.isFinite(peer.elapsed) and peer.elapsed > win.load(f32, root + 0x3128)) win.store(f32, root + 0x3128, peer.elapsed);
    }
    if (skip) {
        flags |= 4;
        win.store(u8, root + 0x3130, flags);
    }
    own.skip = @intFromBool(skip);
    const elapsed = win.load(f32, root + 0x3128);
    own.elapsed = if (std.math.isFinite(elapsed) and elapsed >= 0 and elapsed < 86400) elapsed else 0;
}
fn complete(self: usize, _: usize, kind: c_int) callconv(.{ .x86_fastcall = .{} }) u8 {
    if (kind != 4 or !win.accessible(self, 0x3134, false)) return original(self, kind);
    const level = win.load(i32, 0xfb8438);
    updateClock(self, level);
    const ready = original(self, kind);
    own.ready = @intFromBool(ready != 0);
    lan_publish_loading(&own, 0);
    if (ready == 0 or lan_status() != 3) return ready;
    const target = game_network_target_level();
    const peer = lan_remote_loading();
    if (level == target and (peer.epoch != own.epoch or peer.level != level or peer.ready == 0)) return 0;
    return ready;
}
pub export fn loading_poll() void {
    const root = win.load(usize, 0xfb2e60);
    if (!win.accessible(root, 0x3134, false)) return;
    const epoch = lan_epoch();
    if (own.epoch != epoch) {
        own = initial(epoch, -1);
        was_loading = false;
    }
    const phase = win.load(i32, root + 0x1b78);
    const native_level = win.load(i32, 0xfb8438);
    if (phase >= 1 and phase <= 3) {
        updateClock(root, native_level);
    } else {
        const current = game_current_level();
        const native_idle = win.load(i32, 0xe6e61c) < 0;
        const idle = native_idle and game_load_status() != 1;
        // An opening world can already be current while the network transition is still pending.
        const opening = phase == 0xd and native_idle and (idle or current == native_level) and
            epoch != 0 and lan_status() == 3 and native_level >= 0 and native_level == game_network_target_level();
        if (opening or (phase == 0xe and current >= 0)) {
            own.level = if (opening) native_level else current;
            own.ready = @intFromBool(opening or idle);
            own.active = 0;
            was_loading = false;
        }
    }
    lan_publish_loading(&own, 0);
}
pub export fn loading_install() c_int {
    const slot: *usize = @ptrFromInt(0xadc2cc);
    if (slot.* != 0x423ef0) return 0;
    var old: u32 = 0;
    if (win.VirtualProtect(@intFromPtr(slot), 4, 4, &old) == 0) return 0;
    original = @ptrFromInt(slot.*);
    _ = @atomicRmw(usize, slot, .Xchg, @intFromPtr(&complete), .seq_cst);
    _ = win.VirtualProtect(@intFromPtr(slot), 4, old, &old);
    return 1;
}
