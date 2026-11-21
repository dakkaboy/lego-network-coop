const std = @import("std");
const s = @import("camera_state.zig");
const api = s.platform;
const window = @import("camera_window.zig");
const log = @import("camera_log.zig").line;
fn openLog(module: usize) void {
    var path: [260:0]u8 = @splat(0);
    const length = api.GetModuleFileNameA(module, &path, 260);
    if (length == 0 or length >= 260) return;
    const last = std.mem.lastIndexOfScalar(u8, path[0..length], '\\') orelse return;
    var writer = std.Io.Writer.fixed(path[last + 1 .. 260]);
    writer.print("camera-{d}.log", .{s.win.GetCurrentProcessId()}) catch return;
    path[last + 1 + writer.end] = 0;
    const handle = api.CreateFileA(&path, 4, 3, 0, 4, 0x80, 0);
    if (handle != std.math.maxInt(usize)) s.log_file = handle;
}
fn initialize(module: usize) callconv(.winapi) u32 {
    s.camera_module = module;
    openLog(module);
    log("camera build 5: persistent D3D hook, in-game LAN screen, 60 FPS");
    if (api.GetModuleHandleW(null) != 0x400000 or !s.readable(s.tables[0], 0x74) or s.load(usize, s.tables[0] + 8) != 0x784ec0 or s.load(usize, s.tables[1] + 8) != 0x7751b0 or s.load(usize, s.tables[2] + 8) != 0x785340) {
        log("unsupported executable; hooks not installed");
        return 1;
    }
    var setting: [8]u8 = undefined;
    s.background_capture = api.GetEnvironmentVariableA("CLONEWARS_BACKGROUND_CAPTURE", &setting, setting.len) > 0 and setting[0] == '1';
    var attempt: u32 = 0;
    while (attempt < 400 and s.game_window == 0) : (attempt += 1) {
        _ = api.EnumWindows(window.find, 0);
        if (s.game_window == 0) api.Sleep(50);
    }
    if (s.game_window == 0) {
        log("game window not found; hooks not installed");
        return 1;
    }
    if (s.background_capture) {
        const position = window.backgroundPosition(s.game_window, 0, 0);
        _ = api.SetWindowPos(s.game_window, 1, position.x, position.y, 0, 0, 0x11);
    }
    s.coop_set_window(s.game_window, s.background_capture);
    _ = s.game_sync_prepare_worker(api.GetWindowThreadProcessId(s.game_window, null));
    var config: [260:0]u16 = undefined;
    const display = window.displayConfig(&config);
    const wide = std.unicode.utf8ToUtf16LeStringLiteral;
    var apply_display = !s.background_capture and api.GetPrivateProfileIntW(wide("Display"), wide("Windowed"), 0, display) == 1;
    const display_started = api.GetTickCount();
    var was_down = false;
    while (api.IsWindow(s.game_window) != 0) {
        const tick = api.GetTickCount();
        if (apply_display and tick -% display_started >= 5000 and s.game_current_level() >= 0 and s.readable(s.load(usize, 0xf925d4), 4)) {
            apply_display = false;
            _ = api.PostMessageW(s.game_window, s.window_message, 0, 0);
        }
        var foreground_pid: u32 = 0;
        _ = api.GetWindowThreadProcessId(api.GetForegroundWindow(), &foreground_pid);
        const down = @as(u16, @bitCast(api.GetAsyncKeyState(0x7b))) & 0x8000 != 0;
        if (down and !was_down and foreground_pid == s.win.GetCurrentProcessId()) _ = api.PostMessageW(s.game_window, s.menu_message, 0, 0);
        was_down = down;
        api.Sleep(12);
    }
    return 0;
}
pub export fn DllMain(module: usize, reason: u32, _: usize) callconv(.winapi) i32 {
    if (reason == 1) {
        _ = api.DisableThreadLibraryCalls(module);
        const thread = api.CreateThread(0, 0, initialize, module, 0, null);
        if (thread != 0) _ = s.win.CloseHandle(thread);
    }
    return 1;
}
comptime {
    _ = @import("camera_install.zig");
}
