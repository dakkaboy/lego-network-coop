pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
comptime {
    _ = @import("tick_input.zig");
    _ = @import("gizmo_source.zig");
    _ = @import("global_pack.zig");
    _ = @import("rts_sources.zig");
}
