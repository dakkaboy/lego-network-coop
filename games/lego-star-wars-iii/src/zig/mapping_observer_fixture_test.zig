pub const panic = @import("safety.zig").panic;
pub const mapping_test_api = true;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
pub export fn run_mapping_fixture(choice: u32) i32 {
    return @import("mapping_test_fixture.zig").run(choice);
}
comptime {
    _ = @import("mapping_fixture_runtime.zig");
    _ = @import("mapping_fixture_stubs.zig");
}
