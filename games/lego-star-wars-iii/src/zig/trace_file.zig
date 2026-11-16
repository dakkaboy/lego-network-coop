const std = @import("std");
const trace = @import("trace.zig");
const Snapshot = trace.Ring(512);
const header_size = @offsetOf(Snapshot, "slots");

fn word(bytes: []const u8, index: usize) u32 {
    return std.mem.readInt(u32, bytes[index * 4 ..][0..4], .little);
}

pub fn decode(bytes: []const u8, after: u32, out: *std.Io.Writer) !void {
    if (bytes.len != @sizeOf(Snapshot)) return error.InvalidSnapshotSize;
    const capacity = word(bytes, 1);
    const stride = word(bytes, 2);
    const head = word(bytes, 3);
    if (word(bytes, 0) != 1 or capacity != 512 or stride != 32) return error.UnsupportedTraceLayout;
    if (after > head) return error.FutureCursor;
    const oldest = if (head > capacity) head - capacity + 1 else 1;
    const start = if (after < head) @max(oldest, after + 1) else 0;
    const overwritten = if (start != 0 and oldest > after) oldest - after - 1 else 0;
    try out.print("{{\"type\":\"summary\",\"head\":{d},\"dropped\":{d},\"overwritten\":{d}}}\n", .{ head, word(bytes, 4), overwritten });
    if (start == 0) return;
    var id = start;
    while (true) {
        const offset = header_size + ((id - 1) % capacity) * stride;
        const row = bytes[offset..][0..stride];
        if (word(row, 0) != id) {
            try out.print("{{\"type\":\"incomplete\",\"id\":{d}}}\n", .{id});
        } else {
            try out.print("{{\"id\":{d},\"epoch\":{d},\"sequence\":{d},\"domain\":{d},\"kind\":{d},\"local\":{d},\"remote\":{d},\"detail\":{d}}}\n", .{ id, word(row, 1), word(row, 2), word(row, 3), word(row, 4), word(row, 5), word(row, 6), word(row, 7) });
        }
        if (id == head) break;
        id += 1;
    }
}

pub fn main(init: std.process.Init) !void {
    run(init) catch |err| {
        std.debug.print("Trace read failed: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}

fn run(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 4 and std.mem.eql(u8, args[1], "capture")) {
        var snapshot: [@sizeOf(Snapshot)]u8 = undefined;
        try @import("trace_capture.zig").capture(try std.fmt.parseInt(u32, args[2], 10), &snapshot);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = args[3], .data = &snapshot });
        return;
    }
    if (args.len < 2 or args.len > 3) {
        std.debug.print("Usage: clonewars-trace <snapshot.bin> [after]\n       clonewars-trace capture <pid> <snapshot.bin>\n", .{});
        std.process.exit(2);
    }
    const after = if (args.len == 3) try std.fmt.parseInt(u32, args[2], 10) else 0;
    var bytes: [@sizeOf(Snapshot) + 1]u8 = undefined;
    const snapshot = try std.Io.Dir.cwd().readFile(init.io, args[1], &bytes);
    var buffer: [4096]u8 = undefined;
    var output: std.Io.File.Writer = .init(.stdout(), init.io, &buffer);
    try decode(snapshot, after, &output.interface);
    try output.interface.flush();
}

test "trace file: report loss and reject malformed snapshots" {
    var ring: Snapshot = .{};
    for (1..515) |i| _ = ring.push(.{ .epoch = 5, .sequence = @intCast(i), .domain = .preload, .kind = 1, .local = 1, .remote = 0, .detail = 0 });
    var buffer: [128 * 1024]u8 = undefined;
    var out = std.Io.Writer.fixed(&buffer);
    try decode(std.mem.asBytes(&ring), 0, &out);
    try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\"overwritten\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\"sequence\":514") != null);
    try std.testing.expectError(error.InvalidSnapshotSize, decode(std.mem.asBytes(&ring)[0..12], 0, &out));
    try std.testing.expectError(error.FutureCursor, decode(std.mem.asBytes(&ring), 515, &out));
    ring.version = 2;
    try std.testing.expectError(error.UnsupportedTraceLayout, decode(std.mem.asBytes(&ring), 0, &out));
}

test "trace file: do not emit incomplete rows as events" {
    var ring: Snapshot = .{};
    _ = ring.push(.{ .epoch = 5, .sequence = 1, .domain = .profile, .kind = 1, .local = 1, .remote = 0, .detail = 0 });
    ring.slots[0].committed = 0;
    var buffer: [1024]u8 = undefined;
    var out = std.Io.Writer.fixed(&buffer);
    try decode(std.mem.asBytes(&ring), 0, &out);
    try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\"type\":\"incomplete\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.buffered(), "\"sequence\"") == null);
}
