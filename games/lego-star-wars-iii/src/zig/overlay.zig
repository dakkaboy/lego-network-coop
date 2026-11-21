const std = @import("std");
const win = @import("win32.zig");
const com = @import("com.zig");
const motion = @import("ui_motion.zig");
pub const audio = @import("ui_audio.zig");
var last_camera: i32 = -2;
const layout = @import("art_layout.zig");
pub const scene = @import("overlay_art.zig");
pub const Hud = extern struct { health: c_int, max_health: c_int, has_studs: c_int, studs: u64 };
const Rect = extern struct { left: i32, top: i32, right: i32, bottom: i32 };
const Viewport = extern struct { x: u32, y: u32, width: u32, height: u32, min_z: f32, max_z: f32 };
const Bounds = struct { x: f32, y: f32, w: f32, h: f32 };
const MouseTracking = extern struct { size: u32, flags: u32, window: usize, hover_time: u32 };
const api = struct {
    extern "shell32" fn ShellExecuteW(usize, [*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, c_int) callconv(.winapi) usize;
    extern "gdi32" fn AddFontMemResourceEx(usize, u32, usize, *u32) callconv(.winapi) usize;
    extern "gdi32" fn RemoveFontMemResourceEx(usize) callconv(.winapi) i32;
    extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(.winapi) usize;
    extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
    extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
    extern "user32" fn GetKeyState(c_int) callconv(.winapi) i16;
    extern "user32" fn TrackMouseEvent(*MouseTracking) callconv(.winapi) i32;
    extern "user32" fn SetCursor(usize) callconv(.winapi) usize;
    extern "user32" fn SystemParametersInfoW(u32, u32, *i32, u32) callconv(.winapi) i32;
    extern "user32" fn OpenClipboard(usize) callconv(.winapi) i32;
    extern "user32" fn CloseClipboard() callconv(.winapi) i32;
    extern "user32" fn GetClipboardData(u32) callconv(.winapi) usize;
    extern "kernel32" fn GlobalLock(usize) callconv(.winapi) usize;
    extern "kernel32" fn GlobalUnlock(usize) callconv(.winapi) i32;
    extern "kernel32" fn GlobalSize(usize) callconv(.winapi) usize;
};
extern fn lan_status() c_int;
extern fn lan_error() i32;
extern fn lan_is_host() c_int;
extern fn lan_start(c_int, [*:0]const u8) void;
extern fn lan_stop() void;
extern fn camera_select(c_int) void;
extern fn camera_selected() c_int;
extern fn game_can_return_to_hub() c_int;
extern fn game_request_return_to_hub() c_int;
extern fn game_sync_status() c_int;
extern fn game_sync_restart_required() c_int;
var opened = false;
var want_open = false;
var opening: f32 = 0;
var previous_block: u8 = 0;
var view: u32 = 0;
var weights = [4]f32{ 1, 0, 0, 0 };
var last_tick: u32 = 0;
var focused: i32 = 1;
var hovered: i32 = -1;
var pointer_position: ?[2]f32 = null;
var tracking_pointer = false;
var background_capture = false;
var pressed: i32 = -1;
var selected_address = false;
var invalid = false;
var confirm_hub = false;
var address: [16:0]u8 = @splat(0);
var normal_font: usize = 0;
var font_registration: usize = 0;
const font_bytes = @embedFile("assets/fonts/RussoOne-Regular.ttf");
var large_font: usize = 0;
var hint_font: usize = 0;
var scale: f32 = 1;
var ox: f32 = 0;
var oy: f32 = 0;
var font_scale: f32 = 0;
var reduced = false;
var checked_motion = false;
fn wide(comptime value: []const u8) [*:0]const u16 {
    return std.unicode.utf8ToUtf16LeStringLiteral(value);
}
fn active() bool {
    const s = lan_status();
    return s >= 1 and s <= 3;
}
fn change(next: u32) void {
    view = next;
    pressed = -1;
    hovered = -1;
    invalid = false;
    confirm_hub = false;
    focused = switch (next) {
        1 => 0,
        2 => 1,
        3 => 3,
        else => 1,
    };
    selected_address = next == 1;
}
pub fn previewView(next: u32) void {
    if (next < 4) change(next);
}
pub fn previewSnapshot() struct { view: u32, opening: f32, focus: i32, invalid: bool, menu: bool, sound: bool, audio_failures: u32, weights: [4]f32 } {
    return .{ .view = view, .opening = opening, .focus = focused, .invalid = invalid, .menu = opened, .sound = audio.enabled, .audio_failures = audio.diagnostics.failures, .weights = weights };
}
pub fn settled() bool {
    return opening > 0.995 and weights[view] > 0.995;
}
fn enabled(id: i32, pane: u32) bool {
    if (id == 6 or id == 7 or id == 11) return true;
    return switch (pane) {
        0 => id == 1 or id == 2,
        1 => id == 0 or id == 2 or id == 8,
        2 => id == 1,
        3 => (id >= 3 and id <= 5) or id == 8 or (id == 9 and game_can_return_to_hub() != 0) or id == 10,
        else => false,
    };
}
fn bounds(id: i32, pane: u32) Bounds {
    if (id < 0 or id > 11) return .{ .x = 0, .y = 0, .w = 0, .h = 0 };
    const r = layout.bounds[@intCast(id)];
    var x = @as(f32, @floatFromInt(r[0]));
    if ((pane == 1 and id == 2) or (pane == 2 and id == 1)) x = 448;
    return .{ .x = x, .y = @floatFromInt(r[1]), .w = @floatFromInt(r[2]), .h = @floatFromInt(r[3]) };
}
fn contentShift(pane: u32) f32 {
    return (1 - weights[pane]) * (if (pane < view) @as(f32, -22) else 22);
}
fn hit(x: f32, y: f32) i32 {
    if (view == 3 and y >= 268 and y < 332) {
        const xx = x - contentShift(3);
        if (xx >= 608 and xx < 672) return 4;
        if (xx >= 776 and xx < 840) return 5;
        if (xx >= 448 and xx < 496) return 3;
    }
    for (0..12) |i| {
        const id: @TypeOf(focused) = @intCast(i);
        if (!enabled(id, view)) continue;
        const r = bounds(id, view);
        const shift = if (id == 6 or id == 7 or id == 11) @as(f32, 0) else contentShift(view);
        if (x >= r.x + shift and x < r.x + r.w + shift and y >= r.y and y < r.y + r.h) return id;
    }
    return -1;
}
fn validAddress() bool {
    const s = std.mem.sliceTo(&address, 0);
    var parts = std.mem.splitScalar(u8, s, '.');
    var count: u32 = 0;
    while (parts.next()) |part| {
        if (part.len == 0 or part.len > 3 or (part.len > 1 and part[0] == '0')) return false;
        var n: u32 = 0;
        for (part) |c| {
            if (c < '0' or c > '9') return false;
            n = n * 10 + c - '0';
        }
        if (n > 255) return false;
        count += 1;
    }
    return count == 4;
}
fn paste(window: usize) void {
    if (api.OpenClipboard(window) == 0) return;
    defer _ = api.CloseClipboard();
    const h = api.GetClipboardData(13);
    if (h == 0) return;
    const p = api.GlobalLock(h);
    if (p == 0) return;
    defer _ = api.GlobalUnlock(h);
    const text: [*]const u16 = @ptrFromInt(p);
    const cap = @min(api.GlobalSize(h) / 2, 256);
    var length: usize = 0;
    while (length < cap and text[length] != 0) : (length += 1) {}
    if (length == cap) return;
    var start: usize = 0;
    while (start < length and std.ascii.isWhitespace(@intCast(@min(text[start], 255)))) : (start += 1) {}
    while (length > start and std.ascii.isWhitespace(@intCast(@min(text[length - 1], 255)))) : (length -= 1) {}
    if (length - start > 15 or length == start) return;
    var out: [16:0]u8 = @splat(0);
    for (text[start..length], 0..) |c, i| {
        if ((c < '0' or c > '9') and c != '.') return;
        out[i] = @intCast(c);
    }
    address = out;
    selected_address = false;
    invalid = false;
}
fn activate(id: i32) void {
    if (!enabled(id, view)) return;
    if (id == 10) {
        audio.toggle();
        return;
    }
    if (id >= 3 and id <= 5) {
        const player = id - 4;
        if (camera_selected() != player) {
            camera_select(player);
            last_camera = player;
            audio.player(player);
        }
        return;
    }
    if (view == 1 and id == 2 and !validAddress()) {
        invalid = true;
        focused = 0;
        selected_address = true;
        audio.play(.err);
        return;
    }
    if (id != 0) audio.play(if (id == 6 or id == 8) .back else .click);
    if (id == 11) {
        _ = api.ShellExecuteW(0, wide("open"), wide("https://github.com/dakkaboy/lego-network-coop"), null, null, 1);
        return;
    }
    if (id == 6) {
        want_open = false;
        return;
    }
    if (id == 7) {
        change(if (view == 3) (if (active()) @as(u32, 2) else 0) else 3);
        return;
    }
    if (id == 8) {
        change(if (active()) 2 else 0);
        return;
    }
    if (id == 0) {
        selected_address = true;
        return;
    }

    if (id == 9) {
        if (!confirm_hub) {
            confirm_hub = true;
        } else if (game_request_return_to_hub() != 0) {
            want_open = false;
        }
        return;
    }
    if (view == 0 and id == 1) {
        lan_start(1, &address);
        change(2);
        return;
    }
    if (view == 0 and id == 2) {
        change(1);
        return;
    }
    if (view == 1 and id == 2) {
        if (!validAddress()) {
            invalid = true;
            focused = 0;
            selected_address = true;
            return;
        }
        lan_start(0, &address);
        change(2);
        return;
    }
    if (view == 2 and id == 1) {
        lan_stop();
        change(0);
    }
}
fn releaseFonts() void {
    com.release(normal_font);
    com.release(large_font);
    com.release(hint_font);
    hint_font = 0;
    normal_font = 0;
    large_font = 0;
}
fn fonts(device: usize) bool {
    if (font_registration == 0) {
        var count: u32 = 0;
        font_registration = api.AddFontMemResourceEx(@intFromPtr(font_bytes.ptr), font_bytes.len, 0, &count);
        if (font_registration == 0) return false;
    }
    if (normal_font != 0 and @abs(font_scale - scale) > 0.01) releaseFonts();
    if (normal_font != 0) return true;
    const library = api.GetModuleHandleW(wide("d3dx9_41.dll"));
    if (library == 0) return false;
    const entry = api.GetProcAddress(library, "D3DXCreateFontW");
    if (entry == 0) return false;
    const Create = *const fn (usize, i32, u32, u32, u32, i32, u32, u32, u32, u32, [*:0]const u16, *usize) callconv(.winapi) i32;
    const create: Create = @ptrFromInt(entry);
    if (create(device, @intFromFloat(@max(1, 30 * scale)), 0, 400, 1, 0, 1, 0, 4, 0, wide("Russo One"), &normal_font) < 0) return false;
    if (create(device, @intFromFloat(@max(1, 42 * scale)), 0, 400, 1, 0, 1, 0, 4, 0, wide("Russo One"), &large_font) < 0) {
        releaseFonts();
        return false;
    }
    if (create(device, @intFromFloat(@max(1, 22 * scale)), 0, 400, 1, 0, 1, 0, 4, 0, wide("Russo One"), &hint_font) < 0) {
        releaseFonts();
        return false;
    }
    font_scale = scale;
    return true;
}
fn paint(value: [*:0]const u16, r: Bounds, alpha: f32, color: u32, large: bool, shift: f32, surface: bool) void {
    if (alpha < 0.005) return;
    var font = if (large) large_font else if (r.h <= 30) hint_font else normal_font;
    const Draw = *const fn (usize, usize, [*:0]const u16, i32, *Rect, u32, u32) callconv(.winapi) i32;
    var measure = Rect{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    _ = com.method(Draw, font, 15)(font, 0, value, -1, &measure, 0x420, 0xffffffff);
    if (@as(f32, @floatFromInt(measure.right - measure.left)) > r.w * scale - 4) {
        font = if (large) normal_font else hint_font;
    }
    var rect = Rect{ .left = @intFromFloat(ox + (r.x + shift) * scale), .top = @intFromFloat(oy + r.y * scale), .right = @intFromFloat(ox + (r.x + r.w + shift) * scale), .bottom = @intFromFloat(oy + (r.y + r.h) * scale) };
    const a: u32 = @intFromFloat(@min(1, alpha) * 255);
    if (surface) {
        var lower = rect;
        lower.top += 1;
        lower.bottom += 1;
        _ = com.method(Draw, font, 15)(font, 0, value, -1, &lower, 0x25, ((a / 4) << 24) | 0x00fff2d9);
        var upper = rect;
        upper.top -= 1;
        upper.bottom -= 1;
        _ = com.method(Draw, font, 15)(font, 0, value, -1, &upper, 0x25, ((a / 6) << 24) | 0x000b1722);
    } else {
        for ([_][2]i32{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 } }) |d| {
            var halo = rect;
            halo.left += d[0];
            halo.right += d[0];
            halo.top += d[1];
            halo.bottom += d[1];
            _ = com.method(Draw, font, 15)(font, 0, value, -1, &halo, 0x25, ((a / 12) << 24) | 0x00277492);
        }
    }
    _ = com.method(Draw, font, 15)(font, 0, value, -1, &rect, 0x25, (a << 24) | (color & 0xffffff));
}
fn label(value: [*:0]const u16, r: Bounds, alpha: f32, color: u32, large: bool, shift: f32) void {
    paint(value, r, alpha, color, large, shift, false);
}
fn textRect(r: [4]i32) Bounds {
    return .{ .x = @floatFromInt(r[0]), .y = @floatFromInt(r[1]), .w = @floatFromInt(r[2]), .h = @floatFromInt(r[3]) };
}
fn key(value: [*:0]const u16, id: i32, pane: u32, alpha: f32, large: bool) void {
    var r = bounds(id, pane);
    r.y += scene.pressOffset(id);
    const padding: f32 = if (id >= 3 and id <= 5) 6 else 16;
    r.x += padding;
    r.w -= padding * 2;
    const dark = id != 6 and id != 7;
    var color: u32 = if (dark) 0xff211706 else 0xfff7eedc;
    if (id >= 3 and id <= 5) {
        const t = scene.selection(id);
        color = 0xff000000;
        for ([_]u5{ 0, 8, 16 }) |shift_bits| {
            const from = @as(f32, @floatFromInt((@as(u32, 0xfff3ecda) >> shift_bits) & 255));
            const to = @as(f32, @floatFromInt((@as(u32, 0xff211706) >> shift_bits) & 255));
            color |= @as(u32, @intFromFloat(from + (to - from) * t)) << shift_bits;
        }
    }

    if (id == 10) color = if (audio.enabled) 0xff211706 else 0xfff3ecda;
    paint(value, r, alpha, color, large, if (id == 6 or id == 7 or id == 11) 0 else contentShift(pane), true);
}
fn advance() void {
    const player = camera_selected();
    if (last_camera != -2 and player != last_camera) audio.player(player);
    last_camera = player;
    if (!checked_motion) {
        var on: i32 = 1;
        if (api.SystemParametersInfoW(0x1042, 0, &on, 0) != 0) reduced = on == 0;
        checked_motion = true;
    }
    const now = api.GetTickCount();
    const dt = if (last_tick == 0) @as(f32, 1.0 / 60.0) else @min(0.1, @as(f32, @floatFromInt(now -% last_tick)) / 1000);
    last_tick = now;
    opening = if (reduced) @as(f32, @floatFromInt(@intFromBool(want_open))) else motion.follow(opening, if (want_open) 1 else 0, dt, if (want_open) 0.055 else 0.04);
    for (&weights, 0..) |*value, i| value.* = if (reduced) (if (i == view) @as(f32, 1) else 0) else motion.follow(value.*, if (i == view) 1 else 0, dt, 0.065);
    if (!want_open and opening < 0.005) {
        opened = false;
        const flags = win.load(u8, 0xf91eb4);
        win.store(u8, 0xf91eb4, (flags & ~@as(u8, 2)) | previous_block);
    }
}
pub export fn coop_draw(device: usize, _: *const [2]Hud) void {
    if (!opened) return;
    if (view == 2 and lan_status() == 0) change(0);
    if (view == 2 and lan_status() == 4) change(1);
    advance();
    if (!opened) return;
    var vp: Viewport = undefined;
    if (com.method(*const fn (usize, *Viewport) callconv(.winapi) i32, device, 48)(device, &vp) < 0 or vp.width == 0 or vp.height == 0) return;
    scale = @min(@as(f32, @floatFromInt(vp.width)) / 1280, @as(f32, @floatFromInt(vp.height)) / 720);
    ox = (@as(f32, @floatFromInt(vp.width)) - 1280 * scale) / 2;
    oy = (@as(f32, @floatFromInt(vp.height)) - 720 * scale) / 2 + (1 - opening) * 8 * scale;
    if (!fonts(device)) return;
    _ = scene.draw(device, vp.width, vp.height, scale, ox, oy, .{ .hovered = hovered, .pressed = pressed, .focused = focused, .camera = camera_selected(), .lan = lan_status(), .is_host = lan_is_host() != 0, .hub = game_can_return_to_hub() != 0, .address_focus = view == 1 and focused == 0, .address_invalid = invalid, .fault = game_sync_restart_required() != 0, .view = view, .weights = weights, .opening = opening, .reduced = reduced, .sound_enabled = audio.enabled });
    for (weights, 0..) |weight, pane_index| {
        const a = weight * opening;
        if (a < 0.005) continue;
        const pane: u32 = @intCast(pane_index);
        const shift = contentShift(pane);
        switch (pane) {
            0 => {
                key(wide("CREATE GAME"), 1, pane, a, true);
                key(wide("CONNECT"), 2, pane, a, true);
            },
            1 => {
                label(wide("Join game"), textRect(layout.join_title), a, 0xfff8edce, true, shift);
                label(wide("Host IP"), textRect(layout.host_ip), a, 0xffbacbd7, false, shift);
                var ip: [17]u16 = @splat(0);
                const len = std.mem.len(@as([*:0]const u8, &address));
                for (address[0..len], ip[0..len]) |c, *out| out.* = c;
                label(@ptrCast(&ip), bounds(0, pane), a, if (focused == 0 and selected_address and len > 0) 0xff94e7ff else 0xfff8edce, true, shift);
                if (focused == 0 and (!selected_address or len == 0) and api.GetTickCount() % 900 < 450) {
                    var measured = Rect{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
                    _ = com.method(*const fn (usize, usize, [*:0]const u16, i32, *Rect, u32, u32) callconv(.winapi) i32, large_font, 15)(large_font, 0, @ptrCast(&ip), -1, &measured, 0x420, 0xffffffff);
                    var caret = bounds(0, pane);
                    caret.x += (caret.w + @as(f32, @floatFromInt(measured.right - measured.left)) / scale) / 2 + 1;
                    caret.w = 10;
                    label(wide("|"), caret, a, 0xffd4f5ff, true, shift);
                }
                if (invalid or lan_status() == 4) label(if (invalid) wide("Invalid IP") else switch (lan_error()) {
                    10061 => wide("Connection refused"),
                    10060 => wide("Connection timed out"),
                    else => wide("Connection failed"),
                }, textRect(layout.error_message), a, 0xffffa697, false, shift);
                key(wide("CONNECT"), 2, pane, a, true);
                key(wide("BACK"), 8, pane, a, false);
            },
            2 => {
                const status = if (game_sync_restart_required() != 0) wide("Restart the game") else if (lan_status() == 3) wide("Connected") else if (lan_is_host() != 0) wide("Waiting for player") else wide("Connecting…");
                label(status, textRect(layout.session), a, if (lan_status() == 3) 0xffa9edcc else 0xfff8edce, false, shift);
                key(if (lan_status() == 3) wide("DISCONNECT") else wide("CANCEL"), 1, pane, a, true);
            },
            3 => {
                label(wide("Camera"), textRect(layout.camera), a, 0xfff8edce, true, shift);
                key(wide("Auto"), 3, pane, a, false);
                key(wide("Player 1"), 4, pane, a, false);
                key(wide("Player 2"), 5, pane, a, false);
                label(wide("Sound"), textRect(layout.sound), a, 0xfff8edce, false, shift);
                key(if (audio.enabled) wide("On") else wide("Off"), 10, pane, a, false);
                if (game_can_return_to_hub() != 0) key(if (confirm_hub) wide("RETURN TO HUB?") else wide("RETURN TO HUB"), 9, pane, a, true);
                key(wide("BACK"), 8, pane, a, false);
            },
            else => {},
        }
    }
    label(wide("TAB"), textRect(layout.tab), opening, 0xfff5eedb, false, 0);
    label(wide("ENTER"), textRect(layout.enter), opening, 0xfff5eedb, false, 0);
    label(wide("ESC"), textRect(layout.esc), opening, 0xfff5eedb, false, 0);
    if (want_open) if (pointer_position) |position| scene.drawPointer(device, position, scale);
}
pub export fn coop_toggle() void {
    if (!opened) {
        opened = true;
        want_open = true;
        pointer_position = null;
        opening = 0;
        last_tick = 0;
        const flags = win.load(u8, 0xf91eb4);
        previous_block = flags & 2;
        win.store(u8, 0xf91eb4, flags | 2);
        change(if (active()) 2 else 0);
        return;
    }
    want_open = !want_open;
}
pub export fn coop_release_fonts() void {
    releaseFonts();
    if (font_registration != 0) {
        _ = api.RemoveFontMemResourceEx(font_registration);
        font_registration = 0;
    }
    scene.release();
}
pub export fn coop_fonts_lost() void {
    for ([_]usize{ normal_font, large_font, hint_font }) |f| if (f != 0) {
        _ = com.method(*const fn (usize) callconv(.winapi) i32, f, 16)(f);
    };
    scene.lost();
}
pub export fn coop_fonts_reset() void {
    for ([_]usize{ normal_font, large_font, hint_font }) |f| if (f != 0) {
        _ = com.method(*const fn (usize) callconv(.winapi) i32, f, 17)(f);
    };
    scene.reset();
}
pub export fn coop_set_window(_: usize, capture: bool) void {
    background_capture = capture;
}
pub export fn coop_input(window: usize, message: u32, wp: usize, lp: isize) c_int {
    if (message == 0x2a3) tracking_pointer = false;
    if (!opened) return 0;
    if (message == 0x20 and want_open and @as(u16, @truncate(@as(usize, @bitCast(lp)))) == 1) {
        _ = api.SetCursor(0);
        return 1;
    }
    if (message == 0x2a3 or message == 8 or message == 0x1f or (message == 0x1c and wp == 0)) {
        pressed = -1;
        hovered = -1;
        pointer_position = null;
        return 0;
    }
    if (message == 0x100 and wp == 27) {
        audio.play(.back);
        if (confirm_hub) confirm_hub = false else if (view == 1 or view == 3) change(if (active()) 2 else 0) else want_open = false;
        return 1;
    }
    if (message == 0x100 and (wp == 9 or (wp >= 0x25 and wp <= 0x28))) {
        const back = wp == 0x25 or wp == 0x26 or (wp == 9 and api.GetKeyState(0x10) < 0);
        var next = focused;
        for (0..12) |_| {
            next = @mod(next + (if (back) @as(i32, 11) else 1), 12);
            if (enabled(next, view)) break;
        }
        if (focused != next) audio.play(.hover);
        focused = next;
        selected_address = next == 0;
        return 1;
    }
    if (message == 0x100 and wp == 13) {
        if (@as(usize, @bitCast(lp)) & (1 << 30) == 0) activate(if (focused == 0) 2 else focused);
        return 1;
    }
    if (message == 0x100 and view == 1 and focused == 0) {
        const ctrl = api.GetKeyState(0x11) < 0;
        if (ctrl and wp == 'A') {
            selected_address = true;
            return 1;
        }
        if (ctrl and wp == 'V') {
            paste(window);
            return 1;
        }
        if (wp == 0x2e) {
            address[0] = 0;
            selected_address = false;
            invalid = false;
            return 1;
        }
    }
    if (message >= 0x200 and message <= 0x202) {
        const bits: u32 = @truncate(@as(usize, @bitCast(lp)));
        const px: f32 = @floatFromInt(@as(i16, @bitCast(@as(u16, @truncate(bits)))));
        const py: f32 = @floatFromInt(@as(i16, @bitCast(@as(u16, @truncate(bits >> 16)))));
        pointer_position = .{ px, py };
        // The offscreen window receives test messages while the system pointer stays on the desktop.
        if (!tracking_pointer and window != 0 and !background_capture) {
            var request = MouseTracking{ .size = @sizeOf(MouseTracking), .flags = 2, .window = window, .hover_time = 0 };
            tracking_pointer = api.TrackMouseEvent(&request) != 0;
        }
        const x = (px - ox) / scale;
        const y = (py - oy) / scale;
        scene.pointer(x, y);
        const before_hover = hovered;
        hovered = hit(x, y);
        if (hovered >= 0 and hovered != before_hover and message == 0x200) audio.play(.hover);
        if (message == 0x201) pressed = hovered;
        if (message == 0x202) {
            const clicked = pressed;
            pressed = -1;
            if (clicked >= 0 and clicked == hovered) {
                focused = clicked;
                activate(clicked);
            }
        }
    }
    if (message == 0x102 and view == 1 and focused == 0 and (wp == 8 or wp == '.' or (wp >= '0' and wp <= '9'))) {
        if (selected_address) address[0] = 0;
        selected_address = false;
        invalid = false;
        const len = std.mem.len(@as([*:0]const u8, &address));
        if (wp == 8 and len > 0) address[len - 1] = 0;
        if (wp != 8 and len < 15) {
            address[len] = @intCast(wp);
            address[len + 1] = 0;
        }
    }
    return @intFromBool((message >= 0x100 and message <= 0x109) or (message >= 0x200 and message <= 0x20e));
}
