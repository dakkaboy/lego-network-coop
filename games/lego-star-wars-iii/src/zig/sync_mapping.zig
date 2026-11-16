const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const input = @import("sync_input.zig");
const m = @import("mapping_types.zig");
fn sourceValid(raw: usize, bytes: u32) callconv(.c) c_int {
    return authority.game_sync_main_boundary_valid(raw, bytes, 0);
}
fn currentSession(_: usize) callconv(.c) u32 {
    return api.lan_session_serial();
}
fn installAllowed(_: usize) callconv(.c) c_int {
    const owner = api.native_owner_current();
    return @intFromBool(s.win.GetCurrentThreadId() == s.window_thread and s.core.owner == null and owner != null and api.native_owner_scope_valid(owner, api.native_owner_scope_nonce(owner)) != 0);
}
pub fn install() bool {
    if (s.mapping_configured) return api.user_mapping_install_ready() != 0;
    const configuration = m.InstallConfig{ .main_thread = s.window_thread, .original_source_valid = sourceValid, .install_allowed = installAllowed, .user = 0 };
    if (api.user_mapping_install_safe(&configuration) == 0) return false;
    const session = m.SessionConfig{ .version = 1, .main_thread = s.window_thread, .safe_main_valid = authority.game_sync_main_boundary_valid, .current_session = currentSession, .user = 0 };
    if (api.user_mapping_session_configure(&session) == 0) return false;
    s.mapping_configured = true;
    return true;
}
fn valid(boundary: *const s.MainBoundary) bool {
    return authority.game_sync_main_boundary_valid(@intFromPtr(boundary), @sizeOf(s.MainBoundary), 0) != 0;
}
pub fn prepare(boundary: *s.MainBoundary, requested: *bool) bool {
    requested.* = false;
    if (!valid(boundary) or !s.mapping_configured) return false;
    const session = api.lan_session_serial();
    const connected = api.lan_status() == 3;
    if (s.mapping_session != 0 and (!connected or session != s.mapping_session)) {
        _ = api.user_mapping_session_retire(s.mapping_session, 1);
        s.mapping_session = 0;
        s.owned_mapping = false;
        input.assignmentRemap(input.assignmentVersion());
        @memset(std.mem.asBytes(&s.remote_device), 0);
        @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    }
    if (authority.game_sync_coherent_restore_pending() != 0) {
        for (0..2) |slot| {
            if (!valid(boundary)) return false;
            input.releaseAssignment(slot);
        }
        if (!valid(boundary)) return false;
        @atomicStore(u32, &s.deferred_assignment_restore, 0, .seq_cst);
        if (!valid(boundary)) {
            @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
            return false;
        }
    }
    if (connected and session != 0 and session != 0xffffffff) {
        if (api.user_mapping_session_begin(session) == 0) return false;
        s.mapping_session = session;
    }
    var n: u32 = 0;
    while (api.user_mapping_session_pending() != 0 and n < 32) : (n += 1) {
        if (!valid(boundary)) return false;
        const result = api.user_mapping_session_drain(@intFromPtr(boundary), @sizeOf(s.MainBoundary), session);
        if (result == 4 or result == 5) {
            authority.reject(30, 0);
            return false;
        }
        if (result == 2 or result == 6) return false;
    }
    if (api.user_mapping_session_pending() != 0 or !valid(boundary)) return false;
    if (!connected) return true;
    var status: @import("tag_state.zig").Session = undefined;
    if (authority.tagSession(&status) == 0) return false;
    if (status.classification == 4 and s.load(i32, 0xeb1a78) < 0 and s.load(u8, 0xead928 + 13 * 0x90) != 0) {
        var request = std.mem.zeroes(m.Request);
        request.user = 1;
        request.requested = 13;
        request.saved_negative = s.load(i32, 0xeb1a78);
        request.source.epoch = s.interval.epoch;
        request.source.level = @bitCast(s.interval.level);
        request.source.release = boundary.release;
        request.source.owner_nonce = boundary.owner_nonce;
        request.source.assignment = @truncate(s.assignment_lease_serial);
        request.source.proof_bytes = @sizeOf(s.MainBoundary);
        @memcpy(request.source.proof[0..@sizeOf(s.MainBoundary)], std.mem.asBytes(boundary));
        var key: m.Key = undefined;
        requested.* = true;
        const acquired = api.user_mapping_session_owned_request(session, &request, &key);
        if (!valid(boundary)) return false;
        if (acquired == 0) {
            authority.reject(30, 0);
            return false;
        }
        s.owned_mapping = true;
    }
    if (s.owned_mapping) {
        var current: m.Observation = undefined;
        if (api.user_mapping_session_device_get(session, &current) == 0) return false;
    }
    return valid(boundary);
}
pub fn pollWitnessSame(regs: [*]const u32, receiver: usize, release: u32, session: u32, epoch: u32, level: i32) bool {
    const framework = regs[7];
    const saved_bit: u8 = if (regs[8] & 0x40 != 0) 0 else 2;
    return api.coherent_frame_release() == release and api.lan_session_serial() == session and s.interval.epoch == epoch and s.interval.level == level and s.load(usize, 0xfb0afc) == receiver and s.load(usize, 0xfb0b70) == framework and s.valid(framework, 0x4e) and s.load(u8, framework + 0x4d) & 2 == saved_bit;
}
