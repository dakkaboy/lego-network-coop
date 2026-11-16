const options = @import("game_options");
pub const panic = @import("safety.zig").panic;
pub const DllMain = @import("camera_runtime.zig").DllMain;
pub const hit_entry_enabled = options.hit_entry;
pub const constructor_query_enabled = options.constructor_query;
pub const tracy_enabled = options.tracy;
pub const lan_port: u16 = 32510;
comptime {
    _ = @import("dll_root.zig");
    _ = @import("engine_root.zig");
    _ = @import("network_root.zig");
}
