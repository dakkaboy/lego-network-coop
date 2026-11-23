const std = @import("std");
const hooks = @import("hook_transaction.zig");
const win = @import("win32.zig");
const log = @import("camera_log.zig").line;
const read = win.load;
const write = win.store;

const main_menu = 5;
const frontend_address = 0xfb087c;
const group_address = 0xfb0b4c;
const new_game_offset = 0x3c;
const load_game_offset = 0x4c;
const coop_offset = 0x50;
const menu_vertical_offset: f32 = 0.029;
const Init = *const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
const Select = *const fn (usize, i32) callconv(.{ .x86_thiscall = .{} }) usize;
const Configure = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
const Translate = *const fn ([*:0]const u8, ?*usize) callconv(.c) [*:0]const u8;
const SetHeader = *const fn (usize, [*:0]const u8) callconv(.{ .x86_thiscall = .{} }) void;
const original_init: Init = @ptrFromInt(0x757f60);
const original_select: Select = @ptrFromInt(0x6b15d0);
const original_configure: Configure = @ptrFromInt(0x75e770);
const original_set_header: SetHeader = @ptrFromInt(0x6a4390);

extern fn game_current_level() c_int;
extern fn game_network_level_valid(c_int) c_int;
extern fn game_native_profile_ready() c_int;
extern fn game_native_profile_storage_ready() c_int;
extern fn lan_status() c_int;

const Flow = enum { idle, requested, slots, loading };
var flow: Flow = .idle;
var menu: usize = 0;
var original_translate: ?Translate = null;

fn readable(address: usize, length: usize) bool {
    return win.accessible(address, length, false);
}

fn initialize(self: usize, source: usize) callconv(.{ .x86_thiscall = .{} }) void {
    original_init(self, source);
    const group = read(usize, group_address);
    const first = read(usize, self + new_game_offset);
    const coop = read(usize, self + coop_offset);
    if (!win.accessible(group, 0xa8, true) or !win.accessible(first, 0x5c, true) or
        !win.accessible(coop, 0x5c, true) or read(usize, group + 0x7c) != first or first == coop) return;
    const previous = read(usize, coop + 4);
    const next = read(usize, coop + 8);
    if (!win.accessible(previous, 0xc, true) or !win.accessible(next, 8, true) or
        read(usize, previous + 8) != coop or read(usize, next + 4) != coop) return;
    // Use the existing OnlineGame row and keep its siblings in their original order.
    write(u32, coop + 0x58, read(u32, first + 0x58));
    write(usize, previous + 8, next);
    write(usize, next + 4, previous);
    write(usize, coop + 4, 0);
    write(usize, coop + 8, first);
    write(usize, first + 4, coop);
    write(usize, group + 0x7c, coop);
    // Lift the six-row list clear of the native Select hint.
    write(f32, group + 0xa4, read(f32, group + 0xa4) + menu_vertical_offset);
    menu = self;
}

fn selected(group: usize, index: i32) callconv(.{ .x86_thiscall = .{} }) usize {
    const item = original_select(group, index);
    if (item == 0 or group != read(usize, group_address) or !readable(menu, 0x54)) return item;
    if (item != read(usize, menu + coop_offset)) {
        flow = .idle;
        return item;
    }
    if (lan_status() != 0) return 0;
    flow = .requested;
    log("co-op requested through the native load menu");
    return read(usize, menu + load_game_offset);
}
fn configure(self: usize) callconv(.{ .x86_thiscall = .{} }) void {
    if (self == menu) {
        const first = read(usize, self + new_game_offset);
        const coop = read(usize, self + coop_offset);
        write(u32, self + 0x5c, read(u32, self + 0x5c) | 4);
        write(u32, coop + 0x58, read(u32, first + 0x58));
    }
    original_configure(self);
}

fn localizedTitle(english: [*:0]const u8, russian: [*:0]const u8, russian_legacy: [*:0]const u8) [*:0]const u8 {
    const original = original_translate orelse @as(Translate, @ptrFromInt(0x584560));
    const new_game = std.mem.span(original("NEW_GAME", null));
    if (std.mem.startsWith(u8, new_game, "Но")) return russian;
    if (std.mem.startsWith(u8, new_game, "\xcd\xee")) return russian_legacy;
    return english;
}
fn translate(key: [*:0]const u8, resolved: ?*usize) callconv(.c) [*:0]const u8 {
    const localized = original_translate.?(key, resolved);
    if (!std.mem.eql(u8, std.mem.span(key), "NETWORK_GAME")) return localized;
    return localizedTitle("Co-op", "Кооп", "\xca\xee\xee\xef");
}
fn titleLoadHeader(widget: usize, title: [*:0]const u8) callconv(.{ .x86_thiscall = .{} }) void {
    const caption = if (flow == .idle) title else localizedTitle(
        "Load Co-op Game",
        "Загрузить игру для коопа",
        "\xc7\xe0\xe3\xf0\xf3\xe7\xe8\xf2\xfc \xe8\xe3\xf0\xf3 \xe4\xeb\xff \xea\xee\xee\xef\xe0",
    );
    original_set_header(widget, caption);
}

pub fn update() void {
    if (flow == .idle) return;
    if (lan_status() != 0) {
        flow = .idle;
        return;
    }
    const frontend = read(usize, frontend_address);
    const root = read(usize, 0xfb2e60);
    if (!readable(frontend, 0x418) or !readable(root, 0x1b7c)) return;
    const screen = read(u32, frontend + 0x408);
    const phase = read(u32, root + 0x1b78);
    const pending = read(i32, 0xe6e61c);
    if ((flow == .slots or flow == .loading) and game_network_level_valid(pending) != 0 and game_native_profile_storage_ready() != 0) {
        startHost();
        return;
    }
    switch (flow) {
        .idle => unreachable,
        .requested => {
            if (screen != main_menu) {
                flow = .slots;
            } else if (read(i32, frontend + 0x40c) < 0) flow = .idle;
        },
        .slots => {
            if (screen == main_menu) {
                flow = .idle;
            } else if (phase != 13 or game_network_level_valid(game_current_level()) != 0) {
                flow = .loading;
            }
        },
        .loading => {
            if (screen == main_menu and phase == 13) {
                flow = .idle;
            } else if (phase == 14 and game_network_level_valid(game_current_level()) != 0 and game_native_profile_ready() != 0) {
                startHost();
            }
        },
    }
}

fn startHost() void {
    flow = .idle;
    const lan = @import("lan.zig");
    const test_port = if (@import("camera_state.zig").background_capture) @import("background_loopback.zig").testPort() else null;
    if (test_port) |port| lan.startLoopback(true, port) else lan.lan_start(1, "");
    @import("game_state.zig").holdLoadedCoop();
    @import("overlay.zig").openHostedSession();
    log("co-op waiting after native save selection");
}

pub fn install() void {
    const sites = .{
        .{ 0x76010f, 0x757f60, @intFromPtr(&initialize), 0xe8 },
        .{ 0x758272, 0x6b15d0, @intFromPtr(&selected), 0xe8 },
        .{ 0x7600e7, 0x75e770, @intFromPtr(&configure), 0xe9 },
        .{ 0x7570e6, 0x6a4390, @intFromPtr(&titleLoadHeader), 0xe8 },
    };
    var instructions: [sites.len][5]u8 = undefined;
    var patches: [sites.len]hooks.Patch = undefined;
    inline for (sites, 0..) |site, index| {
        instructions[index][0] = site[3];
        std.mem.writeInt(u32, instructions[index][1..5], @truncate(@as(usize, site[1]) -% (site[0] + 5)), .little);
        patches[index] = .{ .address = site[0], .expected = &instructions[index], .target = site[2], .opcode = site[3] };
    }
    if (!hooks.apply(&patches)) return;
    _ = @import("camera_install.zig").trampoline(Translate, 0x584560, "\x83\xec\x08\x53\x8b\x1d\xf8\x0c\xeb\x00", @intFromPtr(&translate), &original_translate);
    log("native co-op title menu installed");
}
