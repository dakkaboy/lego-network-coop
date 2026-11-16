pub const panic = @import("root.zig").panic;
comptime {
    _ = @import("root.zig");
    _ = @import("wire.zig");
    _ = @import("frame_validation.zig");
}
