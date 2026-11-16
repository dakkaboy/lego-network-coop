pub const tracy_enabled = true;
pub const panic = @import("root.zig").panic;
comptime {
    _ = @import("root.zig");
}
