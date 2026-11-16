const std = @import("std");
const abi = @import("abi.zig");
const p = @import("protocol.zig");
const Frame = p.SyncFrame;
const header_size = @offsetOf(Frame, "actors");
const checksum_offset = @offsetOf(Frame, "checksum");
const storage = @import("frame_storage.zig");
const sections = storage.sections;

extern fn sync_frame_valid(*const Frame, u32) c_int;

fn sectionInfo(comptime name: []const u8) std.builtin.Type.Array {
    return @typeInfo(@FieldType(Frame, name)).array;
}
fn readWord(bytes: []const u8, comptime name: []const u8) u32 {
    const offset = @offsetOf(Frame, name);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}
fn encodedSize(header: []const u8) u32 {
    if (header.len < header_size or readWord(header, "geometry_calls") > 64) return 0;
    var size: u32 = header_size;
    inline for (sections) |section| {
        const info = comptime sectionInfo(section[0]);
        const count = readWord(header, section[1]);
        if (count > info.len) return 0;
        size += count * @sizeOf(info.child);
    }
    return size;
}
fn packetChecksum(bytes: []const u8) u32 {
    var value: u32 = 2166136261;
    for (bytes, 0..) |byte, i| value = (value ^ @as(u8, if (i >= checksum_offset and i < checksum_offset + 4) 0 else byte)) *% 16777619;
    return value;
}

export fn sync_checksum(data: [*]const u8, size: u32) u32 {
    return abi.checksum(data[0..size]);
}
export fn sync_profile_valid(profile: *const p.SyncProfile) c_int {
    return @intFromBool(profile.epoch != 0 and abi.validLevel(profile.level) and
        std.mem.readInt(u32, profile.data[0..4], .little) == 0x500 and profile.checksum == abi.checksum(&profile.data));
}
export fn sync_frame_size(frame: *const Frame) u32 {
    return encodedSize(std.mem.asBytes(frame)[0..header_size]);
}
export fn sync_frame_copy_valid(destination: *Frame, source: *const Frame) void {
    @memcpy(std.mem.asBytes(destination)[0..header_size], std.mem.asBytes(source)[0..header_size]);
    inline for (sections) |section| {
        const count = @field(source, section[1]);
        @memcpy(@field(destination, section[0])[0..count], @field(source, section[0])[0..count]);
    }
}
export fn sync_frame_encode(frame: *const Frame, buffer: [*]u8, capacity: u32) u32 {
    const size = sync_frame_size(frame);
    if (size == 0 or size > capacity or sync_frame_valid(frame, size) == 0) return 0;
    const bytes = buffer[0..size];
    storage.pack(frame, bytes);
    std.mem.writeInt(u32, bytes[checksum_offset..][0..4], packetChecksum(bytes), .little);
    return size;
}
export fn sync_frame_decode(frame: *Frame, buffer: [*]const u8, size: u32) c_int {
    const bytes = buffer[0..size];
    if (size < header_size or encodedSize(bytes[0..header_size]) != size or
        readWord(bytes, "checksum") != packetChecksum(bytes)) return 0;
    storage.unpack(frame, bytes);
    return sync_frame_valid(frame, size);
}
