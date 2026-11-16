const std = @import("std");
pub fn follow(value: f32, target: f32, dt: f32, tau: f32) f32 {
    return target + (value - target) * @exp(-dt / tau);
}
test "transition duration is stable at 30, 60 and 144 FPS" {
    var results: [3]f32 = undefined;
    for ([_]u32{ 30, 60, 144 }, 0..) |fps, i| {
        var value: f32 = 0;
        for (0..fps) |_| value = follow(value, 1, 1 / @as(f32, @floatFromInt(fps)), 0.065);
        results[i] = value;
    }
    try std.testing.expectApproxEqAbs(results[0], results[1], 0.00001);
    try std.testing.expectApproxEqAbs(results[0], results[2], 0.00001);
}
test "interrupted movement reverses from the current position" {
    const before = follow(0, 1, 0.07, 0.065);
    const next = follow(before, 0, 1.0 / 60.0, 0.065);
    try std.testing.expect(before > 0.5 and before < 1);
    try std.testing.expect(next > 0 and next < before);
    try std.testing.expect(next > before * 0.7);
}
test "crossfade keeps total opacity one during rapid navigation" {
    var weights = [4]f32{ 1, 0, 0, 0 };
    for (0..300) |frame| {
        const target = frame / 7 % 4;
        var sum: f32 = 0;
        for (&weights, 0..) |*value, i| {
            value.* = follow(value.*, if (i == target) 1 else 0, 1.0 / 144.0, 0.065);
            sum += value.*;
        }
        try std.testing.expectApproxEqAbs(@as(f32, 1), sum, 0.00001);
    }
}
