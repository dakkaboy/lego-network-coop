pub const panic = @import("safety.zig").panic;
pub const lan_port: u16 = 32510;
comptime {
    _ = @import("lan.zig");
}
