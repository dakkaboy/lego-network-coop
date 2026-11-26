const std = @import("std");
const win = @import("win32.zig");
const state = @import("model_state.zig");
pub export var model_input_resume: usize = 0x9bf6b0;
pub export var request_mode_cmp_resume: usize = 0x9bf6d9;
pub export var request_mode_mov_resume: usize = 0x9bf909;
pub export var request_mode_join_resume: usize = 0x9bfa2a;
pub export var request_priority_resume: usize = 0x9bf921;
pub export var request_hidden_model_continue: usize = 0x9bf9bd;
pub export var request_visibility_continue: usize = 0x9bf9ed;
pub export var request_visibility_skip: usize = 0x9bfa25;
extern fn producer_hook() void;
extern fn model_source_thunk() void;
extern fn model_cmp_thunk() void;
extern fn model_mov_thunk() void;
extern fn model_join_thunk() void;
extern fn model_priority_thunk() void;
extern fn model_hidden_model_thunk() void;
extern fn model_visibility_thunk() void;
pub fn install() c_int {
    if (state.clonewars_model_input_installed == 31) return 1;
    state.clonewars_model_input_installed = -1;
    const sites = [_]usize{ 0x9bf280, 0x9bf6aa, 0x9bf6d2, 0x9bf903, 0x9bfa25, 0x9bf91c, 0x9bf9e7, 0x9bf9b8 };
    const prefixes = [_][]const u8{ "\x55\x8b\xec\x83\xe4\xf0", "\xd9\xc0\xd9\x44\x24\x20", "\x83\xb8\xb0\x00\x00\x00\x01", "\x8b\x80\xb0\x00\x00\x00", "\x8b\x43\x08\x85\xc0", "\x66\x83\x7b\x76\x00", "\x80\x78\x42\x00\x75\x38", "\x85\x53\x4c\x75\x68" };
    const targets = [_]usize{ @intFromPtr(&producer_hook), @intFromPtr(&model_source_thunk), @intFromPtr(&model_cmp_thunk), @intFromPtr(&model_mov_thunk), @intFromPtr(&model_join_thunk), @intFromPtr(&model_priority_thunk), @intFromPtr(&model_visibility_thunk), @intFromPtr(&model_hidden_model_thunk) };
    for (sites, prefixes) |site, prefix| if (!win.accessible(site, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..prefix.len], prefix)) return 0;
    const bridge = win.VirtualAlloc(0, 11, 0x3000, 0x40);
    if (bridge == 0) return 0;
    @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..6], prefixes[0]);
    win.store(u8, bridge + 6, 0xe9);
    win.store(u32, bridge + 7, @truncate(sites[0] +% 6 -% bridge -% 11));
    var old: [sites.len]u32 = undefined;
    var acquired: usize = 0;
    while (acquired < sites.len) : (acquired += 1) {
        if (win.VirtualProtect(sites[acquired], prefixes[acquired].len, 0x40, &old[acquired]) == 0) break;
    }
    if (acquired != sites.len) {
        while (acquired != 0) {
            acquired -= 1;
            var ignored: u32 = 0;
            _ = win.VirtualProtect(sites[acquired], prefixes[acquired].len, old[acquired], &ignored);
        }
        _ = win.VirtualFree(bridge, 0, 0x8000);
        return 0;
    }
    @import("model_input.zig").original_producer = bridge;
    for (sites, prefixes, targets) |site, prefix, target| {
        win.store(u8, site, 0xe9);
        win.store(u32, site + 1, @truncate(target -% site -% 5));
        for (5..prefix.len) |i| win.store(u8, site + i, 0x90);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, prefix.len);
    }
    while (acquired != 0) {
        acquired -= 1;
        var ignored: u32 = 0;
        _ = win.VirtualProtect(sites[acquired], prefixes[acquired].len, old[acquired], &ignored);
    }
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, 11);
    state.clonewars_model_input_installed = 31;
    return 1;
}
comptime {
    _ = @import("model_request_bridges.zig");
}
