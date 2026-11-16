const p = @import("protocol.zig");
pub const Journal = extern struct {
    frame: ?*p.SyncFrame,
    cursor: u32,
    ordinal: u32,
    validated: u32,
    host: c_int,
    failed: c_int,
    pub fn fail(self: *Journal, reason: c_int) c_int {
        self.failed = reason;
        return 0;
    }
};
pub const Batch = extern struct { start: u32, count: u32, ordinal: u32, mode: u32 };
