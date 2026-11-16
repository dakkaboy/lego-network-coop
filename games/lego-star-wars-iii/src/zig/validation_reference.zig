const std = @import("std");
const p = @import("protocol.zig");
const expected = @import("validation_expected.zig");
extern fn sync_frame_size(*const p.SyncFrame) u32;

const Hash = struct {
    value: u64 = 14695981039346656037,
    fn add(self: *@This(), bytes: []const u8) void {
        for (bytes) |byte| self.value = (self.value ^ byte) *% 1099511628211;
    }
    fn raw(self: *@This(), address: *const anyopaque, len: usize) void {
        self.add(@as([*]const u8, @ptrCast(address))[0..len]);
    }
    fn word(self: *@This(), value: u32) void {
        self.add(std.mem.asBytes(&value));
    }
};
fn frameHash(frame: *const p.SyncFrame) Hash {
    var hash: Hash = .{};
    hash.add(std.mem.asBytes(frame)[0..@offsetOf(p.SyncFrame, "actors")]);
    hash.add(std.mem.asBytes(&frame.physics_choices[0]));
    hash.add(std.mem.asBytes(&frame.fire_task_gates[0]));
    return hash;
}

// Answers and wire bytes were captured from the original C validators. The digest
// binds their order and input bytes, so fixture changes cannot reuse stale answers.
pub const Cursor = struct {
    group: expected.Group,
    bool_index: usize = 0,
    encoded_index: usize = 0,
    records: usize = 0,
    digest: Hash = .{},

    pub fn init(index: usize) Cursor {
        return .{ .group = expected.groups[index] };
    }
    pub fn finish(self: *const Cursor) void {
        std.debug.assert(self.bool_index == self.group.bool_count);
        std.debug.assert(self.records == self.group.records);
        std.debug.assert(self.encoded_index == self.group.encoded.len);
        std.debug.assert(self.digest.value == self.group.digest);
    }
    fn record(self: *Cursor, tag: u32, result: u32, key: u64, encoded: []const u8) void {
        const header: [5]u32 = .{ tag, result, @truncate(key), @truncate(key >> 32), @intCast(encoded.len) };
        self.digest.add(std.mem.asBytes(&header));
        self.digest.add(encoded);
        self.records += 1;
    }
    fn answer(self: *Cursor, tag: u32, hash: Hash) c_int {
        std.debug.assert(self.bool_index < self.group.bool_count);
        const index = self.bool_index;
        self.bool_index += 1;
        const result = (self.group.bits[index / 8] >> @as(u3, @intCast(index % 8))) & 1;
        self.record(tag, result, hash.value, &.{});
        return result;
    }
    pub fn physicsValid(self: *Cursor, choice: *const p.SyncPhysicsChoice) c_int {
        var hash: Hash = .{};
        hash.add(std.mem.asBytes(choice));
        return self.answer(1, hash);
    }
    pub fn physicsSource(self: *Cursor, a: *const p.SyncPhysicsChoice, b: *const p.SyncPhysicsChoice) c_int {
        var hash: Hash = .{};
        hash.add(std.mem.asBytes(a));
        hash.add(std.mem.asBytes(b));
        return self.answer(2, hash);
    }
    pub fn tickValid(self: *Cursor, gate: *const p.SyncTickGate) c_int {
        var hash: Hash = .{};
        hash.add(std.mem.asBytes(gate));
        return self.answer(3, hash);
    }
    pub fn tickStream(self: *Cursor, gates: [*]const p.SyncTickGate, count: u32) c_int {
        var hash: Hash = .{};
        hash.raw(gates, count * @sizeOf(p.SyncTickGate));
        hash.word(count);
        return self.answer(4, hash);
    }
    pub fn frameValid(self: *Cursor, frame: *const p.SyncFrame, size: u32) c_int {
        var hash = frameHash(frame);
        hash.word(size);
        return self.answer(5, hash);
    }
    pub fn frameSize(self: *Cursor, frame: *const p.SyncFrame) u32 {
        const size = sync_frame_size(frame);
        self.record(6, size, frameHash(frame).value, &.{});
        return size;
    }
    pub fn frameEncode(self: *Cursor, frame: *const p.SyncFrame, output: [*]u8, capacity: u32) u32 {
        std.debug.assert(self.encoded_index < self.group.encoded.len);
        const encoded = self.group.encoded[self.encoded_index];
        self.encoded_index += 1;
        std.debug.assert(encoded.len <= capacity);
        @memcpy(output[0..encoded.len], encoded);
        var hash = frameHash(frame);
        hash.word(capacity);
        self.record(7, @intCast(encoded.len), hash.value, encoded);
        return @intCast(encoded.len);
    }
};
