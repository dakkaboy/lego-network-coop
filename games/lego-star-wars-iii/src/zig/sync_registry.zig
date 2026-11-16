const s = @import("sync_state.zig");
pub export fn game_sync_coherent_register_cohort(id: c_int, raw: ?*const s.CohortBinding) c_int {
    if (id < 0 or id >= 8 or raw == null) return 0;
    const binding = raw.?;
    if (binding.version != 1 or binding.ready == null or binding.bind_metadata == null or binding.valid == null or binding.abort_metadata == null or s.core.owner != null or s.tick_thread == 0 or s.win.GetCurrentThreadId() != s.tick_thread) return 0;
    const index: usize = @intCast(id);
    const bit = @as(u32, 1) << @as(u5, @intCast(id));
    if (s.registered & bit != 0) {
        const previous = &s.bindings[index];
        return @intFromBool(previous.version == binding.version and previous.ready == binding.ready and previous.bind_metadata == binding.bind_metadata and previous.valid == binding.valid and previous.abort_metadata == binding.abort_metadata);
    }
    s.bindings[index] = binding.*;
    s.registered |= bit;
    return 1;
}
pub export fn game_sync_coherent_missing() u32 {
    var missing: u32 = 255 & ~s.registered;
    for (s.bindings, 0..) |binding, i| if (s.registered & (@as(u32, 1) << @as(u5, @intCast(i))) != 0 and binding.ready.?() == 0) {
        missing |= @as(u32, 1) << @as(u5, @intCast(i));
    };
    return missing;
}
