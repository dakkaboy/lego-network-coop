const s = @import("sync_state.zig");
const api = s.api;
const install = @import("sync_install.zig");
const authority = @import("sync_authority.zig");
const prepare = @import("sync_prepare.zig");
const finish = @import("sync_finish.zig");
fn invalidate(_: u32, _: usize) callconv(.c) void {
    api.coherent_frame_cancel_atomic(0x08000000);
}
pub export fn game_sync_prepare_worker(window_thread: u32) c_int {
    const platform = @import("sync_platform.zig");
    var setting: [8]u8 = undefined;
    s.neutral_background_input = platform.environment("CLONEWARS_BACKGROUND_CAPTURE", &setting, setting.len) == 1 and setting[0] == '1';
    s.enabled = !(platform.environment("CLONEWARS_ENABLE_EXPERIMENTAL_SYNC", &setting, setting.len) == 1 and setting[0] == '0');
    if (!s.enabled) return -1;
    s.window_thread = window_thread;
    const callbacks = @import("span_types.zig").Callbacks{ .version = 5, .user = 0, .reject_atomic = authority.reject, .install_safe = install.safe, .dependencies_ready = install.ready, .main_confirmed = prepare.confirmed, .control_context = prepare.control, .enter = prepare.enter, .marker = prepare.marker, .finish = finish.finish, .end = finish.end };
    if (api.lan_set_session_invalidator(invalidate, 0) == 0) return 0;
    if (window_thread == 0 or api.span_engine_prepare(&s.adapter, 0x760000, 0xadc268, 0xadc24c, 0xfb0afc, window_thread, 1, &callbacks) == 0) return 0;
    return api.span_engine_publish_bootstrap(&s.adapter);
}
comptime {
    _ = @import("sync_epoch.zig");
    _ = @import("sync_bindings.zig");
    _ = @import("sync_authority.zig");
    _ = @import("sync_preload.zig");
}
