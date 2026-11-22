pub const bounds = [_][4]i32{
    .{ 432, 320, 416, 64 },
    .{ 208, 448, 384, 80 },
    .{ 688, 448, 384, 80 },
    .{ 400, 344, 144, 56 },
    .{ 568, 344, 144, 56 },
    .{ 736, 344, 144, 56 },
    .{ 1120, 112, 64, 64 },
    .{ 96, 592, 164, 56 },
    .{ 912, 592, 176, 48 },
    .{ 448, 496, 384, 48 },
    .{ 568, 420, 144, 56 },
    .{ 1040, 592, 144, 56 },
};
pub const join_title = [4]i32{ 320, 220, 640, 56 };
pub const host_ip = [4]i32{ 432, 288, 416, 32 };
pub const error_message = [4]i32{ 432, 392, 416, 32 };
pub const session = [4]i32{ 320, 400, 640, 40 };
pub const camera = [4]i32{ 320, 224, 640, 40 };
pub const hints = [4]i32{ 224, 672, 832, 28 };
pub const sound = [4]i32{ 400, 420, 144, 56 };

pub fn controlBounds(id: i32, pane: u32) [4]f32 {
    const r = bounds[@intCast(id)];
    var x: f32 = @floatFromInt(r[0]);
    if ((pane == 1 and id == 2) or (pane == 2 and id == 1)) x = 448;
    return .{ x, @floatFromInt(r[1]), @floatFromInt(r[2]), @floatFromInt(r[3]) };
}

pub fn contentShift(pane: u32, view: u32, weight: f32) f32 {
    return (1 - weight) * (if (pane < view) @as(f32, -22) else 22);
}
