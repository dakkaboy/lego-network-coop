const a = @import("abi.zig");
const check = @import("native_test_support.zig").check;
comptime {
    _ = @import("input.zig");
}
pub fn main() void {
    var buffer: a.InputBuffer = undefined;
    a.input_buffer_reset(&buffer);
    const press = a.SyncInput{ .held = 0x8000, .pressed = 0x8000, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
    const release = a.SyncInput{ .held = 0, .pressed = 0, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
    a.input_buffer_sample(&buffer, &press);
    for (0..8) |_| a.input_buffer_sample(&buffer, &release);
    var delivered = a.input_buffer_take(&buffer);
    check(@src(), delivered.held == 0 and delivered.pressed == 0x8000 and delivered.analog_x == 128 and delivered.aim_y == 128);
    check(@src(), a.input_buffer_take(&buffer).pressed == 0);
    a.input_buffer_sample(&buffer, &press);
    const jump = a.SyncInput{ .held = 0x4000, .pressed = 0x4000, .analog_x = 230, .analog_y = 128, .aim_x = 11, .aim_y = 219 };
    a.input_buffer_sample(&buffer, &jump);
    delivered = a.input_buffer_take(&buffer);
    check(@src(), delivered.pressed == 0xc000 and delivered.held == 0x4000 and delivered.analog_x == 230 and delivered.aim_x == 11 and delivered.aim_y == 219);
    check(@src(), a.input_buffer_take(&buffer).pressed == 0);
    a.input_buffer_sample(&buffer, &press);
    a.input_buffer_reset(&buffer);
    delivered = a.input_buffer_take(&buffer);
    check(@src(), delivered.held == 0 and delivered.pressed == 0 and delivered.analog_x == 128);
}
