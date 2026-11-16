const std = @import("std");
const root = @import("root");
const enabled = if (@hasDecl(root, "tracy_enabled")) root.tracy_enabled else false;
const Source = extern struct { name: [*:0]const u8, function: [*:0]const u8, file: [*:0]const u8, line: u32, color: u32 };
const Context = extern struct { id: u32, active: i32, connection_id: u64 };
extern fn ___tracy_emit_zone_begin(*const Source, i32) Context;
extern fn ___tracy_emit_zone_end(Context) void;
extern fn ___tracy_emit_frame_mark(?[*:0]const u8) void;

pub const Zone = struct {
    context: if (enabled) Context else void,
    pub fn end(self: Zone) void {
        if (enabled) ___tracy_emit_zone_end(self.context);
    }
};
pub inline fn zone(comptime source: std.builtin.SourceLocation, comptime name: [:0]const u8) Zone {
    if (!enabled) return .{ .context = {} };
    const location = struct {
        const value: Source = .{ .name = name, .function = source.fn_name, .file = source.file, .line = source.line, .color = 0 };
    };
    return .{ .context = ___tracy_emit_zone_begin(&location.value, 1) };
}
pub fn frame() void {
    if (enabled) ___tracy_emit_frame_mark("network");
}
