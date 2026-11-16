const source = @import("sync_input.zig").deviceSource;
const check = @import("native_test_support.zig").check;
pub fn main() void {
    var shadow: [2][0x200]u8 = undefined;
    var physical: [0x200]u8 = undefined;
    const first = @intFromPtr(&shadow[1]);
    const other = @intFromPtr(&shadow[0]);
    const device = @intFromPtr(&physical);
    var out = device;
    check(@src(), source(first, first, other, 0, 7, 7, &out) == 0 and out == 0);
    check(@src(), source(first, first, other, device, 7, 7, &out) == 0 and out == device);
    out = other;
    check(@src(), source(first, first, other, device, 7, 8, &out) == 5 and out == other);
    check(@src(), source(first, first, other, device, 7, 0, &out) == 5 and source(first, first, other, device, 7, 0xffffffff, &out) == 5);
    check(@src(), source(other, first, other, device, 7, 7, &out) == 4);
    check(@src(), source(first, first, other, 0, 0, 7, &out) == 5);
    check(@src(), source(0, first, other, 0, 0, 7, &out) == 0 and out == 0);
    check(@src(), source(device, first, other, 0, 0, 7, &out) == 0 and out == device);
}
