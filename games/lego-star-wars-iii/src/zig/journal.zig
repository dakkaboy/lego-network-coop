const p = @import("protocol.zig");

pub fn Journal(comptime section: []const u8, comptime count_field: []const u8) type {
    const Array = @typeInfo(@FieldType(p.SyncFrame, section)).array;
    return extern struct {
        frame: ?*p.SyncFrame,
        cursor: u32,
        host: c_int,
        failed: c_int,
        const Self = @This();
        pub const Entry = Array.child;

        pub fn begin(self: *Self, frame: *p.SyncFrame, host: c_int) void {
            self.* = .{ .frame = frame, .cursor = 0, .host = host, .failed = 0 };
            if (host != 0) @field(frame, count_field) = 0;
        }
        pub fn fail(self: *Self, reason: c_int) c_int {
            self.failed = reason;
            return 0;
        }
        pub fn record(self: *Self, entry: ?*const Entry, comptime valid: fn (?*const Entry) bool, reason: c_int) c_int {
            const count = &@field(self.frame.?, count_field);
            if (self.failed != 0 or self.host == 0 or count.* >= Array.len or !valid(entry)) return self.fail(reason);
            @field(self.frame.?, section)[count.*] = entry.?.*;
            count.* += 1;
            return 1;
        }
        pub fn peek(self: *const Self) ?*const Entry {
            return if (self.failed == 0 and self.cursor < Array.len and self.cursor < @field(self.frame.?, count_field)) &@field(self.frame.?, section)[self.cursor] else null;
        }
        pub fn finish(self: *const Self) c_int {
            return @intFromBool(self.failed == 0 and (self.host != 0 or self.cursor == @field(self.frame.?, count_field)));
        }
    };
}
