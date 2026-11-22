pub const bounds = [_][4]i32{
    .{ 432, 320, 416, 64 },
    .{ 208, 448, 384, 56 },
    .{ 688, 448, 384, 56 },
    .{ 535, 295, 126, 48 },
    .{ 673, 295, 126, 48 },
    .{ 811, 295, 126, 48 },
    .{ 1060, 112, 54, 50 },
    .{ 166, 522, 146, 46 },
    .{ 814, 522, 144, 46 },
    .{ 448, 468, 384, 38 },
    .{ 535, 371, 126, 48 },
    .{ 970, 522, 144, 46 },
};
pub const keypad_title = [4]i32{ 196, 210, 376, 50 };
pub const keypad_host_ip = [4]i32{ 196, 279, 376, 36 };
pub const keypad_error = [4]i32{ 196, 381, 376, 28 };
pub const join_title = [4]i32{ 320, 220, 640, 56 };
pub const host_ip = [4]i32{ 432, 288, 416, 32 };
pub const error_message = [4]i32{ 432, 392, 416, 32 };
pub const session = [4]i32{ 320, 291, 640, 54 };
pub const host_ping = [4]i32{ 320, 348, 640, 40 };
pub const keypad_first = 12;
pub const keypad_columns = 6;
pub const keypad_count = 12;
pub const settings_title = [4]i32{ 320, 207, 640, 54 };
pub const camera = [4]i32{ 348, 295, 150, 48 };
pub const settings_panel = [4]f32{ 312, 274, 656, 164 };
pub const session_panel = [4]f32{ 386, 234, 508, 252 };
pub const hints = [4]i32{ 224, 598, 832, 28 };
pub const pad_hint_widths = [4]i32{ 124, 104, 110, 92 };

pub fn padHintIcon(index: usize, keypad: bool) [4]i32 {
    var x: i32 = if (keypad) 425 else 480;
    for (pad_hint_widths[0..index]) |width| x += width;
    return .{ x, 600, 24, 24 };
}

pub const sound = [4]i32{ 348, 371, 150, 48 };

pub fn controlBounds(id: i32, pane: u32, keypad: bool) [4]f32 {
    if (pane == 1 and keypad) {
        if (id == 0) return .{ 196, 318, 376, 58 };
        if (id == 2) return .{ 224, 412, 320, 56 };
    }
    if (id >= keypad_first) {
        const index = id - keypad_first;
        return .{
            @floatFromInt(636 + @mod(index, keypad_columns) * 78),
            @floatFromInt(274 + @divTrunc(index, keypad_columns) * 72),
            66,
            58,
        };
    }
    if (pane == 0) switch (id) {
        1 => return .{ 218, 260, 402, 158 },
        2 => return .{ 660, 260, 402, 158 },
        else => {},
    };
    if (pane == 2 and id == 1) return .{ 470, 413, 340, 54 };
    const r = bounds[@intCast(id)];
    var x: f32 = @floatFromInt(r[0]);
    if (pane == 1 and id == 2) x = 448;
    return .{ x, @floatFromInt(r[1]), @floatFromInt(r[2]), @floatFromInt(r[3]) };
}

pub fn contentShift(pane: u32, view: u32, weight: f32) f32 {
    return (1 - weight) * (if (pane < view) @as(f32, -22) else 22);
}
