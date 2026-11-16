pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);

comptime {
    _ = @import("input.zig");
    _ = @import("epoch.zig");
    _ = @import("profile.zig");
    _ = @import("preload.zig");
    _ = @import("cadence.zig");
    _ = @import("model.zig");
    _ = @import("geometry.zig");
    _ = @import("reaction.zig");
    _ = @import("rigid_body.zig");
    _ = @import("context.zig");
    _ = @import("entity_match.zig");
}
