const std = @import("std");
const p = @import("protocol.zig");
const Queue = @import("frame_queue.zig").Queue;
const storage = @import("frame_storage.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("dll_root.zig");
}
pub fn main() void {
    const allocator = std.heap.page_allocator;
    const frame = allocator.create(p.SyncFrame) catch unreachable;
    defer allocator.destroy(frame);
    const received = allocator.create(p.SyncFrame) catch unreachable;
    defer allocator.destroy(received);
    frame.* = std.mem.zeroes(p.SyncFrame);
    frame.epoch = 7;
    frame.checksum = 0xdeadbeef;
    var queue: Queue = .{ .allocator = allocator };
    defer queue.clear();
    check(@src(), !queue.pop(received) and queue.epoch() == null);
    for (0..4) |round| {
        for (0..p.SYNC_QUEUE_SIZE) |i| {
            frame.sequence = @intCast(round * p.SYNC_QUEUE_SIZE + i);
            check(@src(), queue.push(frame));
        }
        check(@src(), !queue.push(frame));
        for (0..p.SYNC_QUEUE_SIZE) |i| {
            check(@src(), queue.epoch() == 7 and queue.pop(received));
            check(@src(), received.sequence == round * p.SYNC_QUEUE_SIZE + i and received.checksum == 0xdeadbeef);
        }
        check(@src(), queue.count == 0 and queue.epoch() == null and !queue.pop(null));
    }
    inline for (storage.sections, 0..) |section, index| {
        @field(frame, section[1]) = 1;
        @memset(std.mem.asBytes(&@field(frame, section[0])[0]), @intCast(index + 1));
    }
    frame.tick_gate_count = p.SYNC_MAX_TICK_GATES;
    for (&frame.tick_gates, 0..) |*gate, index| gate.* = .{ .site = 0x888889, .clock = @intCast(index / 15), .value = @intCast(index & 1) };
    const snapshot = allocator.create(p.SyncFrame) catch unreachable;
    defer allocator.destroy(snapshot);
    snapshot.* = frame.*;
    check(@src(), queue.push(frame));
    frame.tick_gates[0].value ^= 1;
    @memset(std.mem.asBytes(received), 0xa5);
    check(@src(), queue.pop(received));
    check(@src(), received.tick_gate_count == p.SYNC_MAX_TICK_GATES and received.tick_gates[0].value == 0 and received.tick_gates[p.SYNC_MAX_TICK_GATES - 1].value == 1);
    inline for (storage.sections) |section| {
        const count = @field(snapshot, section[1]);
        check(@src(), std.mem.eql(u8, std.mem.sliceAsBytes(@field(snapshot, section[0])[0..count]), std.mem.sliceAsBytes(@field(received, section[0])[0..count])));
        if (count < @field(received, section[0]).len) for (std.mem.asBytes(&@field(received, section[0])[count])) |byte| check(@src(), byte == 0xa5);
    }
    check(@src(), std.mem.eql(u8, std.mem.asBytes(snapshot)[0..storage.header_size], std.mem.asBytes(received)[0..storage.header_size]));
    frame.* = std.mem.zeroes(p.SyncFrame);
    for (0..p.SYNC_QUEUE_SIZE) |_| check(@src(), queue.push(frame));
    queue.clear();
    check(@src(), queue.count == 0 and queue.head == 0 and queue.epoch() == null);
    for (queue.slots) |slot| check(@src(), slot == null);
    var buffer: [storage.header_size - 1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    var refused: Queue = .{ .allocator = fixed.allocator() };
    check(@src(), !refused.push(frame) and refused.count == 0 and refused.epoch() == null);
}
