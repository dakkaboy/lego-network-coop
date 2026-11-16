const std = @import("std");
pub const Domain = enum(u32) { epoch = 1, profile = 2, preload = 3, coherent = 4 };
pub const Event = extern struct {
    epoch: u32,
    sequence: u32,
    domain: Domain,
    kind: u32,
    local: u32,
    remote: u32,
    detail: u32,
};
const Slot = extern struct { committed: u32, event: Event };

pub fn Ring(comptime capacity: usize) type {
    comptime std.debug.assert(capacity > 0 and std.math.isPowerOfTwo(capacity));
    return extern struct {
        version: u32 = 1,
        capacity: u32 = capacity,
        stride: u32 = @sizeOf(Slot),
        head: u32 = 0,
        dropped: u32 = 0,
        busy: u32 = 0,
        slots: [capacity]Slot = std.mem.zeroes([capacity]Slot),
        const Self = @This();

        pub fn push(self: *Self, event: Event) bool {
            // Hooks must never wait for another producer or a reentrant callback.
            if (@cmpxchgStrong(u32, &self.busy, 0, 1, .acquire, .monotonic) != null) {
                _ = @atomicRmw(u32, &self.dropped, .Add, 1, .monotonic);
                return false;
            }
            defer @atomicStore(u32, &self.busy, 0, .release);
            const head = @atomicLoad(u32, &self.head, .monotonic);
            if (head == std.math.maxInt(u32)) {
                _ = @atomicRmw(u32, &self.dropped, .Add, 1, .monotonic);
                return false;
            }
            const id = head + 1;
            const slot = &self.slots[(id - 1) & (capacity - 1)];
            @atomicStore(u32, &slot.committed, 0, .seq_cst);
            const source: *const [@sizeOf(Event) / 4]u32 = @ptrCast(&event);
            const target: *[@sizeOf(Event) / 4]u32 = @ptrCast(&slot.event);
            for (source, target) |value, *word| @atomicStore(u32, word, value, .seq_cst);
            @atomicStore(u32, &slot.committed, id, .seq_cst);
            @atomicStore(u32, &self.head, id, .release);
            return true;
        }

        pub fn read(self: *const Self, id: u32) error{ InvalidId, Overwritten, Incomplete }!Event {
            if (id == 0) return error.InvalidId;
            const head = @atomicLoad(u32, &self.head, .acquire);
            if (id > head) return error.Incomplete;
            if (head - id >= capacity) return error.Overwritten;
            const slot = &self.slots[(id - 1) & (capacity - 1)];
            if (@atomicLoad(u32, &slot.committed, .seq_cst) != id) return error.Incomplete;
            var event: Event = undefined;
            const target: *[@sizeOf(Event) / 4]u32 = @ptrCast(&event);
            const source: *const [@sizeOf(Event) / 4]u32 = @ptrCast(&slot.event);
            for (source, target) |*word, *value| value.* = @atomicLoad(u32, word, .seq_cst);
            if (@atomicLoad(u32, &slot.committed, .seq_cst) != id) return error.Incomplete;
            return event;
        }
    };
}

export var clonewars_zig_trace: Ring(512) = .{};

pub fn record(domain: Domain, epoch: u32, sequence: u32, kind: u32, local: u32, remote: u32, detail: u32) void {
    _ = clonewars_zig_trace.push(.{ .epoch = epoch, .sequence = sequence, .domain = domain, .kind = kind, .local = local, .remote = remote, .detail = detail });
}
pub export fn clonewars_zig_trace_event(domain: u32, epoch: u32, sequence: u32, kind: u32, local: u32, remote: u32, detail: u32) void {
    if (domain < 1 or domain > 4) return;
    record(@fromBackingInt(@intCast(domain)), epoch, sequence, kind, local, remote, detail);
}

test "trace: overwrite is explicit and retained events remain exact" {
    var ring: Ring(4) = .{};
    for (1..8) |i| try std.testing.expect(ring.push(.{ .epoch = 1, .sequence = @intCast(i), .domain = .epoch, .kind = 0, .local = 0, .remote = 0, .detail = 0 }));
    try std.testing.expectError(error.InvalidId, ring.read(0));
    try std.testing.expectError(error.Overwritten, ring.read(3));
    try std.testing.expectEqual(@as(u32, 4), (try ring.read(4)).sequence);
    try std.testing.expectEqual(@as(u32, 7), (try ring.read(7)).sequence);
    try std.testing.expectError(error.Incomplete, ring.read(8));
}

test "trace: reentry and serial exhaustion drop without blocking or wrap" {
    var ring: Ring(4) = .{};
    const event: Event = .{ .epoch = 1, .sequence = 1, .domain = .preload, .kind = 0, .local = 0, .remote = 0, .detail = 0 };
    ring.busy = 1;
    try std.testing.expect(!ring.push(event));
    ring.busy = 0;
    ring.head = std.math.maxInt(u32);
    try std.testing.expect(!ring.push(event));
    try std.testing.expectEqual(std.math.maxInt(u32), ring.head);
    try std.testing.expectEqual(@as(u32, 2), ring.dropped);
}
