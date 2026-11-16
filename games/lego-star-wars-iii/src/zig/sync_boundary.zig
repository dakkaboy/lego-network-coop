pub const Boundary = extern struct { owner: ?*@import("owner_types.zig").Scope, owner_nonce: u32, thread: u32, release: u32, boundary_serial: u32 };
pub fn Authority(comptime s: type) type {
    return struct {
        pub fn valid(raw: usize, bytes: u32, _: usize) callconv(.c) c_int {
            if (raw == 0 or bytes != @sizeOf(Boundary) or !s.main_boundary_active or s.core.opened != 0 or s.win.GetCurrentThreadId() != s.window_thread) return 0;
            const boundary: *align(1) const Boundary = @ptrFromInt(raw);
            return @intFromBool(boundary.owner == s.main_boundary.owner and boundary.owner_nonce == s.main_boundary.owner_nonce and boundary.thread == s.win.GetCurrentThreadId() and boundary.release == s.main_boundary.release and boundary.release == s.api.coherent_frame_release() and boundary.boundary_serial == s.main_boundary_serial and s.api.native_owner_current() == boundary.owner and s.api.native_owner_scope_valid(boundary.owner, boundary.owner_nonce) != 0);
        }
        pub fn get(raw: ?*Boundary) c_int {
            const out = raw orelse return 0;
            if (valid(@intFromPtr(&s.main_boundary), @sizeOf(Boundary), 0) == 0) return 0;
            out.* = s.main_boundary;
            return valid(@intFromPtr(out), @sizeOf(Boundary), 0);
        }
    };
}
