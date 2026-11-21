const std = @import("std");
const camera = @import("camera_state.zig");
const log = @import("camera_log.zig").line;
const lan = @import("lan.zig");
const session = @import("lan_state.zig");
const game = @import("game_state.zig");
const api = @import("game_api.zig");

const Role = enum { unconfigured, disabled, host, client };
var role: Role = .unconfigured;
var requested_level: ?i32 = null;
var last_status: i32 = -1;
var last_report: u32 = 0;
fn setting(name: [:0]const u8, buffer: []u8) []const u8 {
    const size = camera.platform.GetEnvironmentVariableA(name, buffer.ptr, @intCast(buffer.len));
    return if (size < buffer.len) buffer[0..size] else "";
}

pub fn skipIntro() bool {
    return (role == .host or role == .client) and session.lan_status() == 3;
}

pub fn update() void {
    if (role == .unconfigured) {
        var buffer: [32]u8 = undefined;
        const value = setting("CLONEWARS_LOOPBACK_ROLE", &buffer);
        role = if (std.mem.eql(u8, value, "host")) .host else if (std.mem.eql(u8, value, "client")) .client else .disabled;
        if (role == .host) {
            requested_level = std.fmt.parseInt(i32, setting("CLONEWARS_LOOPBACK_LEVEL", &buffer), 10) catch null;
        }
        if (role != .disabled) lan.startLoopback(role == .host);
    }
    if (role == .disabled) return;

    const status = session.lan_status();
    const level = camera.game_current_level();
    if (status == 3) {
        if (requested_level) |target| {
            if (game.game_network_level_valid(target) != 0) {
                game.game_request_level(target);
                requested_level = null;
            }
        }
    }

    const now = camera.platform.GetTickCount();
    if (status == last_status and now -% last_report < 5000) return;
    last_status = status;
    last_report = now;
    var buffer: [160]u8 = undefined;
    const message = std.fmt.bufPrint(&buffer, "loopback {s}: lan={d} error={d} level={d} epoch_level={d} sync={d} sequence={d} peer_ack={d}", .{
        @tagName(role),         status,                   session.lan_error(),    level, api.game_sync_epoch_level(),
        api.game_sync_status(), api.game_sync_sequence(), session.lan_peer_ack(),
    }) catch return;
    log(message);
}
