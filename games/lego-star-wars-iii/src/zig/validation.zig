const std = @import("std");
const p = @import("protocol.zig");

pub fn finite(value: anytype) bool {
    switch (@typeInfo(@TypeOf(value))) {
        .float => return std.math.isFinite(value),
        .array => for (value) |element| {
            if (!finite(element)) return false;
        },
        .@"struct" => |info| inline for (info.field_names) |field| {
            if (!finite(@field(value, field))) return false;
        },
        .@"union" => @compileError("Select the active union member before validating floats"),
        else => {},
    }
    return true;
}

pub fn worldVariable(level: i32, variable: p.SyncVariable) bool {
    if (variable.name[0] == 0 or variable.scope > p.SYNC_VARIABLE_AREA_DECLARATION) return false;
    if (finite(variable.value)) return true;

    // Storm over Ryloth A can store +inf in either native wave counter.
    const wave_a = "WaveADestroyed".* ++ @as([32 - "WaveADestroyed".len]u8, @splat(0));
    const wave_b = "WaveBDestroyed".* ++ @as([32 - "WaveBDestroyed".len]u8, @splat(0));
    return level == 83 and variable.scope == p.SYNC_VARIABLE_GLOBAL and
        @as(u32, @bitCast(variable.value)) == 0x7f800000 and
        (std.mem.eql(u8, &variable.name, &wave_a) or std.mem.eql(u8, &variable.name, &wave_b));
}

pub fn zero(value: anytype) bool {
    for (std.mem.asBytes(value)) |byte| if (byte != 0) return false;
    return true;
}

pub fn equal(a: anytype, b: anytype) bool {
    return std.mem.eql(u8, std.mem.asBytes(a), std.mem.asBytes(b));
}
