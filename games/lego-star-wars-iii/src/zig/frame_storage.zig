const std = @import("std");
const Frame = @import("protocol.zig").SyncFrame;
pub const header_size = @offsetOf(Frame, "actors");
pub const sections = .{
    .{ "actors", "actor_count" },                         .{ "variables", "variable_count" },
    .{ "shots", "shot_count" },                           .{ "projectiles", "projectile_count" },
    .{ "tags", "tag_count" },                             .{ "actor_inputs", "actor_input_count" },
    .{ "cadence", "cadence_count" },                      .{ "geometry", "geometry_count" },
    .{ "reactions", "reaction_count" },                   .{ "model_inputs", "model_input_count" },
    .{ "spawn_timers", "spawn_timer_count" },             .{ "fire_task_gates", "fire_task_gate_count" },
    .{ "rts_team_timers", "rts_team_timer_count" },       .{ "spawn_timer_choices", "spawn_timer_choice_count" },
    .{ "physics_choices", "physics_choice_count" },       .{ "tick_gates", "tick_gate_count" },
    .{ "projectile_retires", "projectile_retire_count" },
};
pub fn pack(frame: *const Frame, bytes: []u8) void {
    @memcpy(bytes[0..header_size], std.mem.asBytes(frame)[0..header_size]);
    var tail: usize = header_size;
    inline for (sections) |section| {
        const data = std.mem.sliceAsBytes(@field(frame, section[0])[0..@field(frame, section[1])]);
        @memcpy(bytes[tail..][0..data.len], data);
        tail += data.len;
    }
    std.debug.assert(tail == bytes.len);
}
pub fn unpack(frame: *Frame, bytes: []const u8) void {
    @memcpy(std.mem.asBytes(frame)[0..header_size], bytes[0..header_size]);
    var tail: usize = header_size;
    inline for (sections) |section| {
        const data = std.mem.sliceAsBytes(@field(frame, section[0])[0..@field(frame, section[1])]);
        @memcpy(data, bytes[tail..][0..data.len]);
        tail += data.len;
    }
    std.debug.assert(tail == bytes.len);
}
