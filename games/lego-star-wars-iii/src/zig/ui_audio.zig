const std = @import("std");
extern "winmm" fn PlaySoundW(usize, usize, u32) callconv(.winapi) i32;
extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
pub const Kind = enum(u8) { hover, click, back, player1, player2, automatic, err };
const clips = [_][]const u8{
    @embedFile("assets/audio/hover.wav"),   @embedFile("assets/audio/click.wav"),   @embedFile("assets/audio/back.wav"),
    @embedFile("assets/audio/player1.wav"), @embedFile("assets/audio/player2.wav"), @embedFile("assets/audio/automatic.wav"),
    @embedFile("assets/audio/error.wav"),
};
pub var enabled = true;
pub var diagnostics: struct { played: [7]u32 = @splat(0), failures: u32 = 0 } = .{};
var last_hover: u32 = 0;
pub fn play(kind: Kind) void {
    if (!enabled) return;
    const now = GetTickCount();
    if (kind == .hover) {
        if (now -% last_hover < 75) return;
        last_hover = now;
    }
    const index = @backingInt(kind);
    const result = PlaySoundW(@intFromPtr(clips[index].ptr), 0, 7 | (if (kind == .hover) @as(u32, 0x10) else 0));
    if (result != 0) diagnostics.played[index] +%= 1 else if (kind != .hover) diagnostics.failures +%= 1;
}
pub fn player(value: i32) void {
    play(switch (value) {
        0 => .player1,
        1 => .player2,
        else => .automatic,
    });
}
pub fn toggle() void {
    if (enabled) {
        play(.back);
        enabled = false;
    } else {
        enabled = true;
        play(.click);
    }
}
