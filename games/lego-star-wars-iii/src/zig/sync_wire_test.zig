const std = @import("std");
const p = @import("protocol.zig");
const physics = @import("physics_validation.zig");
const replay = @import("physics_replay.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("wire.zig");
    _ = @import("frame_validation.zig");
}
extern fn sync_frame_size(*const p.SyncFrame) u32;
extern fn sync_frame_valid(*const p.SyncFrame, u32) c_int;
extern fn sync_frame_encode(*const p.SyncFrame, [*]u8, u32) u32;
extern fn sync_frame_decode(*p.SyncFrame, [*]const u8, u32) c_int;
extern fn sync_frame_copy_valid(*p.SyncFrame, *const p.SyncFrame) void;
const Group = struct { name: []const u8, data: []const u8, records: usize };
const groups = [_]Group{
    .{ .name = "launch", .data = @embedFile("fixtures/wire_launch.bin"), .records = 26 },
    .{ .name = "geometry", .data = @embedFile("fixtures/wire_geometry.bin"), .records = 29 },
    .{ .name = "vehicle", .data = @embedFile("fixtures/wire_vehicle.bin"), .records = 286 },
    .{ .name = "world", .data = @embedFile("fixtures/wire_world.bin"), .records = 49 },
    .{ .name = "frame", .data = @embedFile("fixtures/wire_frame.bin"), .records = 375 },
};
const Cursor = struct {
    group: Group,
    position: usize = 0,
    record: usize = 0,
    op: u32 = 0,
    fn word(self: *@This()) u32 {
        check(@src(), self.position + 4 <= self.group.data.len);
        const value = std.mem.readInt(u32, self.group.data[self.position..][0..4], .little);
        self.position += 4;
        return value;
    }
    fn blob(self: *@This(), out: []u8) []u8 {
        const length = self.word();
        check(@src(), length <= out.len);
        @memset(out[0..length], 0);
        var offset: usize = 0;
        while (offset < length) {
            offset += self.word();
            const count = self.word();
            check(@src(), offset + count <= length and self.position + count <= self.group.data.len);
            @memcpy(out[offset..][0..count], self.group.data[self.position..][0..count]);
            offset += count;
            self.position += count;
        }
        return out[0..length];
    }
    fn expect(self: *@This(), value: u32) void {
        const expected = self.word();
        if (value != expected) std.debug.print("wire {s} record={d} operation={d}: {d} != {d}\n", .{ self.group.name, self.record, self.op, value, expected });
        check(@src(), value == expected);
    }
};
fn hash(bytes: []const u8) u32 {
    var value: u32 = 2166136261;
    for (bytes) |byte| value = (value ^ byte) *% 16777619;
    return value;
}
fn choiceBlob(cursor: *Cursor, value: *p.SyncPhysicsChoice) void {
    check(@src(), cursor.blob(std.mem.asBytes(value)).len == @sizeOf(p.SyncPhysicsChoice));
}
fn run(group: Group) void {
    var allocations: [3]usize = undefined;
    for (&allocations) |*a| {
        a.* = win.VirtualAlloc(0, @sizeOf(p.SyncFrame), 0x3000, 4);
        check(@src(), a.* != 0);
    }
    defer {
        for (allocations) |a| check(@src(), win.VirtualFree(a, 0, 0x8000) != 0);
    }
    const first: *p.SyncFrame = @ptrFromInt(allocations[0]);
    const second: *p.SyncFrame = @ptrFromInt(allocations[1]);
    const buffer = @as([*]u8, @ptrFromInt(allocations[2]))[0..@sizeOf(p.SyncFrame)];
    var cursor: Cursor = .{ .group = group };
    var choices: [4]p.SyncPhysicsChoice = undefined;
    var descriptor: [48]u8 = undefined;
    var matrix: [16]f32 = undefined;
    var scale: [3]f32 = undefined;
    while (cursor.position < group.data.len) {
        cursor.record += 1;
        cursor.op = cursor.word();
        switch (cursor.op) {
            1, 2, 3 => {
                check(@src(), cursor.blob(std.mem.asBytes(first)).len == @sizeOf(p.SyncFrame));
                switch (cursor.op) {
                    1 => cursor.expect(sync_frame_size(first)),
                    2 => {
                        const size = cursor.word();
                        cursor.expect(@bitCast(sync_frame_valid(first, size)));
                    },
                    3 => {
                        const capacity = cursor.word();
                        check(@src(), capacity <= buffer.len);
                        const size = sync_frame_encode(first, buffer.ptr, capacity);
                        cursor.expect(size);
                        cursor.expect(hash(buffer[0..size]));
                    },
                    else => unreachable,
                }
            },
            4 => {
                check(@src(), cursor.blob(std.mem.asBytes(first)).len == @sizeOf(p.SyncFrame));
                const wire = cursor.blob(buffer);
                const accepted = sync_frame_decode(first, wire.ptr, @intCast(wire.len));
                cursor.expect(@bitCast(accepted));
                // Rejected packets have no decoded frame; the legacy decoder could already have copied its header.
                cursor.expect(if (accepted != 0) hash(std.mem.asBytes(first)) else hash(""));
            },
            5 => {
                check(@src(), cursor.blob(std.mem.asBytes(first)).len == @sizeOf(p.SyncFrame));
                check(@src(), cursor.blob(std.mem.asBytes(second)).len == @sizeOf(p.SyncFrame));
                sync_frame_copy_valid(first, second);
                cursor.expect(hash(std.mem.asBytes(first)));
            },
            6 => {
                choiceBlob(&cursor, &choices[0]);
                cursor.expect(@intFromBool(physics.valid(&choices[0])));
            },
            7 => {
                choiceBlob(&cursor, &choices[0]);
                choiceBlob(&cursor, &choices[1]);
                cursor.expect(@intFromBool(physics.sameSource(&choices[0], &choices[1])));
            },
            8 => {
                check(@src(), cursor.blob(&descriptor).len == 48);
                choiceBlob(&cursor, &choices[0]);
                choiceBlob(&cursor, &choices[1]);
                cursor.expect(@intFromBool(replay.launch(&descriptor, &choices[0], &choices[1])));
                cursor.expect(hash(&descriptor));
            },
            9 => {
                check(@src(), cursor.blob(std.mem.asBytes(&matrix)).len == 64 and cursor.blob(std.mem.asBytes(&scale)).len == 12);
                for (&choices) |*entry| choiceBlob(&cursor, entry);
                cursor.expect(@intFromBool(replay.geometry(&matrix, &scale, &choices[0], &choices[1], &choices[2], &choices[3])));
                cursor.expect(hash(std.mem.asBytes(&matrix)));
                cursor.expect(hash(std.mem.asBytes(&scale)));
            },
            10 => {
                var shot: p.SyncShot = undefined;
                check(@src(), cursor.blob(std.mem.asBytes(&shot)).len == @sizeOf(p.SyncShot));
                const owner: i32 = @bitCast(cursor.word());
                const generation = cursor.word();
                const weapon: i32 = @bitCast(cursor.word());
                const source = cursor.word();
                const depth = cursor.word();
                cursor.expect(@intFromBool(@import("shot_source.zig").matches(&shot, owner, generation, weapon, @intCast(source), @intCast(depth))));
            },
            else => @panic("unknown wire fixture operation"),
        }
    }
    check(@src(), cursor.position == group.data.len and cursor.record == group.records);
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len > 1) {
        const index = try std.fmt.parseInt(usize, args[1], 10);
        check(@src(), index < groups.len);
        run(groups[index]);
        if (index == 4) accumulatedTagTime();
    } else {
        for (groups) |group| run(group);
        accumulatedTagTime();
    }
}
fn accumulatedTagTime() void {
    const memory = win.VirtualAlloc(0, @sizeOf(p.SyncFrame) * 2, 0x3000, 4);
    check(@src(), memory != 0);
    defer check(@src(), win.VirtualFree(memory, 0, 0x8000) != 0);
    const f: *p.SyncFrame = @ptrFromInt(memory);
    const decoded: *p.SyncFrame = @ptrFromInt(memory + @sizeOf(p.SyncFrame));
    f.epoch = 1;
    f.sequence = 3285;
    f.level = 12;
    f.delta = 0.0538174;
    f.engine_delta = 0.050997;
    f.tag_count = 1;
    f.cadence_count = 1;
    const tag = &f.tags[0];
    tag.* = std.mem.zeroes(p.SyncTag);
    tag.id = 8;
    tag.from = 11;
    tag.to = 5;
    tag.from_generation = 23;
    tag.to_generation = 17;
    tag.clock = 3285;
    tag.delta = 0.40869495;
    tag.from_identity = .{ .character = 229, .spawn_tag = 927624, .spawn_source = .{ .producer = 3905926279, .serial = 0 } };
    tag.to_identity = .{ .character = 123, .spawn_tag = 6054833, .spawn_source = .{ .producer = 3, .serial = 0 } };
    const cadence = &f.cadence[0];
    cadence.* = std.mem.zeroes(p.SyncCadence);
    cadence.slot = 11;
    cadence.generation = 23;
    cadence.character = tag.from_identity.character;
    cadence.spawn_tag = tag.from_identity.spawn_tag;
    cadence.spawn_source = tag.from_identity.spawn_source;
    cadence.period = 8;
    cadence.phase = 11;
    cadence.elapsed = tag.delta;
    const original_tag = tag.*;
    const original_cadence = cadence.*;
    var packet: [2048]u8 = undefined;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) != 0);
    const size = sync_frame_encode(f, &packet, packet.len);
    check(@src(), size != 0 and sync_frame_decode(decoded, &packet, size) != 0 and @import("validation.zig").equal(&decoded.tags[0], tag));
    for (0..19) |mutation| {
        tag.* = original_tag;
        cadence.* = original_cadence;
        f.cadence_count = 1;
        switch (mutation) {
            0 => tag.delta = std.math.nan(f32),
            1 => tag.delta = std.math.inf(f32),
            2 => tag.delta = -0.4,
            3 => tag.delta = 0.4,
            4 => tag.phase = 1,
            5 => f.cadence_count = 0,
            6 => cadence.generation += 1,
            7 => cadence.slot += 1,
            8 => cadence.character += 1,
            9 => cadence.spawn_tag += 1,
            10 => cadence.spawn_source.serial += 1,
            11 => cadence.elapsed = 0.05,
            12 => cadence.period = 0,
            13 => cadence.period = 256,
            14 => cadence.phase += 1,
            15 => tag.clock += 1,
            16 => {
                tag.delta = 26;
                cadence.elapsed = tag.delta;
            },
            17 => {
                f.cadence_count = 2;
                f.cadence[1] = cadence.*;
            },
            18 => tag.parent = 7,
            else => unreachable,
        }
        check(@src(), sync_frame_valid(f, sync_frame_size(f)) == 0);
    }
    tag.* = original_tag;
    cadence.* = original_cadence;
    f.cadence_count = 1;
    cadence.period = 1;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) != 0);
    cadence.* = original_cadence;
    f.tag_count = 2;
    f.tags[1] = tag.*;
    f.tags[1].id = 9;
    f.tags[1].parent = 8;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) != 0);
    f.tags[1].delta = 0.4;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) == 0);
    f.tag_count = 1;
    cadence.period = 255;
    cadence.phase = 30;
    cadence.elapsed = 25.5;
    tag.delta = cadence.elapsed;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) != 0);
    f.cadence_count = 0;
    tag.delta = 0.05;
    check(@src(), sync_frame_valid(f, sync_frame_size(f)) != 0);
}
