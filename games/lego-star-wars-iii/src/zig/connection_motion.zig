const std = @import("std");
const motion = @import("ui_motion.zig");
pub const Model = struct {
    progress: f32 = 0,
    confirmation: f32 = 0,
    elapsed: f32 = 0,
    stage: i32 = 0,
    pub fn advance(self: *Model, stage: i32, dt: f32, reduced: bool) void {
        if (stage != self.stage) {
            self.elapsed = 0;
            self.stage = stage;
        }
        if (stage == 1 or stage == 2) self.elapsed += dt;
        const goal: f32 = switch (stage) {
            1 => 0.78,
            2 => 0.78,
            3 => 1,
            else => 0,
        };
        self.progress = if (reduced) goal else motion.follow(self.progress, goal, dt, if (stage == 3) 0.14 else 0.30);
        self.confirmation = if (reduced) (if (stage == 3) @as(f32, 1) else 0) else motion.follow(self.confirmation, if (stage == 3) 1 else 0, dt, 0.12);
    }
    pub fn peerX(self: Model) f32 {
        return 850 - 174 * self.progress;
    }
    pub fn peerY(_: Model, _: bool) f32 {
        return 300;
    }
    pub fn pulseX(self: Model) f32 {
        return (750 - 180 * (self.elapsed * 0.85 - @floor(self.elapsed * 0.85))) / 1280;
    }
};
test "pending connection never docks or signals success" {
    var model: Model = .{};
    for (0..600) |_| model.advance(2, 1.0 / 60.0, false);
    try std.testing.expect(model.peerX() > 710);
    try std.testing.expectEqual(@as(f32, 0), model.confirmation);
    try std.testing.expectApproxEqAbs(@as(f32, 0.78), model.progress, 0.0001);
}
test "host and client waiting remain on the player axis" {
    for ([_]i32{ 1, 2, 3, 0 }) |stage| {
        var model: Model = .{};
        for (0..180) |_| {
            model.advance(stage, 1.0 / 60.0, false);
            try std.testing.expectEqual(@as(f32, 300), model.peerY(false));
        }
        if (stage == 1 or stage == 2) {
            try std.testing.expectApproxEqAbs(@as(f32, 714.28), model.peerX(), 0.02);
            try std.testing.expectEqual(@as(f32, 0), model.confirmation);
        }
    }
}
test "confirmed connection docks smoothly and cancellation clears success" {
    var model: Model = .{};
    for (0..60) |_| model.advance(2, 1.0 / 60.0, false);
    const before = model.peerX();
    model.advance(3, 1.0 / 60.0, false);
    try std.testing.expect(model.peerX() < before and before - model.peerX() < 8);
    for (0..90) |_| model.advance(3, 1.0 / 60.0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 676), model.peerX(), 0.01);
    for (0..120) |_| model.advance(0, 1.0 / 60.0, false);
    try std.testing.expect(model.confirmation < 0.0001);
}
test "reduced motion uses static truthful states" {
    var model: Model = .{};
    model.advance(2, 0.01, true);
    try std.testing.expectApproxEqAbs(@as(f32, 714.28), model.peerX(), 0.01);
    try std.testing.expectEqual(@as(f32, 300), model.peerY(true));
    try std.testing.expectEqual(@as(f32, 0), model.confirmation);
    model.advance(3, 0.01, true);
    try std.testing.expectEqual(@as(f32, 1), model.confirmation);
}
