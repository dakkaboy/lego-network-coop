const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const t = @import("model_types.zig");
const state = @import("model_state.zig");
pub fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
pub fn valid(address: usize, size: usize) bool {
    return win.accessible(address, size, false);
}
pub fn hero(slot: usize) usize {
    return read(usize, 0xfb4940 + slot * 4);
}
pub fn eligible(actor: usize, controller: usize, provider: usize) bool {
    if (!valid(actor, 0x1440) or !valid(controller, 0x60) or !valid(provider, 0x194)) return false;
    const flags = read(u32, actor + 0x50);
    return flags & 3 == 3 and flags & 0x200 == 0 and actor != hero(0) and actor != hero(1) and read(usize, actor + 0x6cc) == controller and read(u8, actor + 0x54) == 0 and read(u8, actor + 0x1dd) == 255 and read(u32, provider + 0x190) & 0x100 == 0 and read(usize, actor + 0xc00) == 0 and read(u32, 0xfc0e80) & 255 == 0;
}
pub fn capture(out: *p.SyncModelInput, actor: usize, provider: usize, x: usize, z: usize, fx: usize) bool {
    const resource = read(usize, actor + 0xf08);
    const model = read(usize, actor + 8);
    const base = read(usize, actor + 0xc08);
    if (!valid(resource, 0x30) or !valid(model, 0x43) or read(usize, model + 0x34) != provider or !valid(base, 0x228) or !valid(x, 4) or !valid(z, 4) or fx == 0) return false;
    const definition = read(usize, resource + 0x2c);
    if (!valid(definition, 0xfc) or read(u32, actor + 0xc7c) & 0x20000000 != 0) return false;
    out.* = std.mem.zeroes(p.SyncModelInput);
    out.character = read(i16, actor + 0xdc0);
    out.native_clock = read(u32, 0xfb4b6c);
    out.input_x = read(f32, x);
    out.input_z = read(f32, z);
    out.input_mode = read(u32, provider + 0xb0);
    out.period = read(u8, actor + 0x138e);
    out.phase = read(u8, actor + 0x57);
    out.elapsed = read(f32, actor + 0xe28);
    const c = &out.context;
    c.role_mask = read(u32, actor + 0x50) & 0xa00;
    c.life_54 = read(u8, actor + 0x54);
    c.axis_1dd = read(u8, actor + 0x1dd);
    c.provider_190_bit = @intFromBool(read(u32, provider + 0x190) & 0x100 != 0);
    c.normalization_mode = read(u32, 0xfb32a8);
    c.action = read(u16, actor + 0x2f4);
    c.substate_2fa = read(u8, actor + 0x2fa);
    c.c7c_block = @intFromBool(read(u32, actor + 0xc7c) & 0x800000 != 0);
    c.byte_110a = read(u8, actor + 0x110a);
    c.c84_mask = read(u32, actor + 0xc84) & 0x104000;
    c.c00_present = 0;
    c.actor_76 = read(u16, actor + 0x76);
    c.actor_1c8_mask = @intFromBool(read(u32, actor + 0x1c8) & 0x400 != 0);
    c.override_c44 = read(u32, actor + 0xc44);
    c.override_c48 = read(u32, actor + 0xc48);
    for ([_]usize{ 0x2c, 0x30, 0x34, 0xf8 }, &c.resource_speed) |offset, *value| value.* = read(u32, definition + offset);
    c.motion_alternate = @intFromBool(read(u32, resource + 0x14) & 0x2000 != 0);
    c.resource_d8_bit = @intFromBool(read(u32, definition + 0xd8) & 0x100 != 0);
    c.actor_4c_mask = @intFromBool(read(u32, actor + 0x4c) & 0x400 != 0);
    c.c7c_1000 = @intFromBool(read(u32, actor + 0xc7c) & 0x1000 != 0);
    c.cf4_raw = read(u32, actor + 0xcf4);
    c.model_42 = read(u8, model + 0x42);
    c.actor_309_mask = @intFromBool(read(u8, actor + 0x309) & 2 != 0);
    c.global_e63e14_raw = read(u32, 0xe63e14);
    c.global_fbcb88_raw = read(u32, 0xfbcb88);
    c.global_fc0e80 = read(u32, 0xfc0e80) & 255;
    c.numeric_cw = read(u16, fx) & 0x1f3f;
    c.numeric_mxcsr = read(u32, fx + 24) & 0xffc0;
    return true;
}
extern fn entities_observed_generation(usize) u32;
pub fn scopeValid(op: *const t.Lease, s: *const t.Scope, actor: usize, controller: usize, native_frame: u32) bool {
    return state.live(op) and state.scope == s and s.source != 0 and s.projection_complete == 0 and s.actor == actor and s.controller == controller and s.native_frame == native_frame and s.epoch == state.journal.frame.?.epoch and s.sequence == state.journal.frame.?.sequence and win.GetCurrentThreadId() == state.active_thread and valid(actor, 0x1440) and valid(controller, 0x60) and read(u32, actor + 0x50) & 3 == 3 and read(u32, actor + 0x50) & 0x200 == 0 and actor != hero(0) and actor != hero(1) and entities_observed_generation(actor) == s.generation and state.live(op) and read(usize, actor + 0x6cc) == controller;
}
pub fn zero(request: *const p.SyncModelInput) bool {
    return @as(u32, @bitCast(request.input_x)) & 0x7fffffff == 0 and @as(u32, @bitCast(request.input_z)) & 0x7fffffff == 0;
}
