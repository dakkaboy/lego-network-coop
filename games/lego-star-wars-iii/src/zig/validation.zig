const std = @import("std");

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

pub fn zero(value: anytype) bool {
    for (std.mem.asBytes(value)) |byte| if (byte != 0) return false;
    return true;
}

pub fn equal(a: anytype, b: anytype) bool {
    return std.mem.eql(u8, std.mem.asBytes(a), std.mem.asBytes(b));
}
