const std = @import("std");
const p = @import("protocol.zig");
const storage = @import("frame_storage.zig");
extern fn sync_frame_size(*const p.SyncFrame) u32;
pub const Queue = struct {
    allocator: std.mem.Allocator,
    slots: [p.SYNC_QUEUE_SIZE]?[]u8 = @splat(null),
    head: usize = 0,
    count: usize = 0,
    pub fn push(self: *Queue, frame: *const p.SyncFrame) bool {
        if (self.count == self.slots.len) return false;
        const size = sync_frame_size(frame);
        if (size == 0) return false;
        const bytes = self.allocator.alloc(u8, size) catch return false;
        storage.pack(frame, bytes);
        self.slots[(self.head + self.count) % self.slots.len] = bytes;
        self.count += 1;
        return true;
    }
    pub fn epoch(self: *const Queue) ?u32 {
        if (self.count == 0) return null;
        return std.mem.readInt(u32, self.slots[self.head].?[0..4], .little);
    }
    pub fn pop(self: *Queue, frame: ?*p.SyncFrame) bool {
        if (self.count == 0) return false;
        const bytes = self.slots[self.head].?;
        if (frame) |out| storage.unpack(out, bytes);
        self.allocator.free(bytes);
        self.slots[self.head] = null;
        self.head = (self.head + 1) % self.slots.len;
        self.count -= 1;
        return true;
    }
    pub fn clear(self: *Queue) void {
        while (self.pop(null)) {}
        self.head = 0;
    }
};
