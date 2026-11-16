const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const equal = @import("validation.zig").equal;
var tag_binding = std.mem.zeroes(@import("tag_state.zig").FrameBinding);
fn tagBind(token: *const s.Token) callconv(.c) c_int {
    return @intFromBool(api.tags_bind_cohort(token) != 0 and api.tags_frame_binding_get(&tag_binding) != 0 and equal(token, &tag_binding.token));
}
fn tagValid(token: *const s.Token, phases: u32) callconv(.c) c_int {
    return @intFromBool(equal(token, &tag_binding.token) and api.tags_cohort_valid(token, phases) != 0);
}
fn tagAbort(token: *const s.Token) callconv(.c) void {
    if (equal(token, &tag_binding.token)) _ = api.tags_abort_frame(&tag_binding);
}
fn Journal(comptime prefix: []const u8) type {
    return struct {
        var lease = std.mem.zeroes(@import("cohort_types.zig").Lease);
        fn bind(token: *const s.Token) callconv(.c) c_int {
            return @intFromBool(@field(api, prefix ++ "bind_cohort")(token) != 0 and @field(api, prefix ++ "frame_lease_get")(&lease) != 0 and equal(token, &lease.cohort));
        }
        fn valid(token: *const s.Token, phases: u32) callconv(.c) c_int {
            return @intFromBool(equal(token, &lease.cohort) and api.coherent_frame_valid(token, phases) != 0 and @field(api, prefix ++ "frame_cancelled")(&lease) == 0);
        }
        fn abort(token: *const s.Token) callconv(.c) void {
            if (equal(token, &lease.cohort)) _ = @field(api, prefix ++ "abort_frame")(&lease);
        }
    };
}
fn npcBind(token: *const s.Token) callconv(.c) c_int {
    return api.npc_input_bind_cohort(&s.npc_inputs, token);
}
fn npcValid(token: *const s.Token, phases: u32) callconv(.c) c_int {
    return api.npc_input_cohort_valid(&s.npc_inputs, token, phases);
}
fn npcAbort(token: *const s.Token) callconv(.c) void {
    _ = api.npc_input_abort_cohort(&s.npc_inputs, token);
}
fn worldBind(token: *const s.Token) callconv(.c) c_int {
    return api.world_vars_bind_cohort(token);
}
fn worldValid(token: *const s.Token, phases: u32) callconv(.c) c_int {
    return api.world_vars_cohort_valid(token, phases);
}
fn worldAbort(token: *const s.Token) callconv(.c) void {
    _ = api.world_vars_abort_cohort(token);
}
fn Ready(comptime id: usize) type {
    return struct {
        fn ready() callconv(.c) c_int {
            return @intFromBool(s.module_install_mask & (@as(u32, 1) << id) != 0);
        }
    };
}
pub fn actual() [8]s.CohortBinding {
    const projectiles = Journal("projectiles_");
    const geometry = Journal("geometry_");
    const cadence = Journal("cadence_");
    const model = Journal("model_input_");
    const reaction = Journal("reaction_");
    return .{
        .{ .version = 1, .ready = Ready(0).ready, .bind_metadata = tagBind, .valid = tagValid, .abort_metadata = tagAbort },
        .{ .version = 1, .ready = Ready(1).ready, .bind_metadata = projectiles.bind, .valid = projectiles.valid, .abort_metadata = projectiles.abort },
        .{ .version = 1, .ready = Ready(2).ready, .bind_metadata = geometry.bind, .valid = geometry.valid, .abort_metadata = geometry.abort },
        .{ .version = 1, .ready = Ready(3).ready, .bind_metadata = cadence.bind, .valid = cadence.valid, .abort_metadata = cadence.abort },
        .{ .version = 1, .ready = Ready(4).ready, .bind_metadata = model.bind, .valid = model.valid, .abort_metadata = model.abort },
        .{ .version = 1, .ready = Ready(5).ready, .bind_metadata = npcBind, .valid = npcValid, .abort_metadata = npcAbort },
        .{ .version = 1, .ready = Ready(6).ready, .bind_metadata = reaction.bind, .valid = reaction.valid, .abort_metadata = reaction.abort },
        .{ .version = 1, .ready = Ready(7).ready, .bind_metadata = worldBind, .valid = worldValid, .abort_metadata = worldAbort },
    };
}
pub export fn game_sync_coherent_register_actual_modules() c_int {
    if (s.core.owner != null or s.tick_thread == 0 or s.win.GetCurrentThreadId() != s.tick_thread) return 0;
    for (actual(), 0..) |binding, i| if (@import("sync_registry.zig").game_sync_coherent_register_cohort(@intCast(i), &binding) == 0) return 0;
    return 1;
}
