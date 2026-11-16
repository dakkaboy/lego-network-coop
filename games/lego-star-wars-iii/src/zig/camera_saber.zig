const std = @import("std");
const s = @import("camera_state.zig");
const load = s.load;
const hooks = @import("hook_transaction.zig");
const producers = [_]usize{ 0x7966e2, 0x7c8286, 0x7c82dd, 0x8c9b6c, 0x8cc0c2, 0x906b95, 0x97b532, 0x97b697, 0x99d59b, 0x9aae7a, 0x9b2b1d, 0x9b2be5, 0x9b5fdf, 0x9b62ef, 0x9b64c8 };
pub export fn saber_allow_network_weapon_fx(actor: usize) c_int {
    if (s.lan_status() != 3 or s.game_sync_status() != 2 or load(u8, 0xfbc161) != 0 or !s.readable(actor, 0x1440) or load(u32, actor + 0x50) & 3 != 3 or load(u8, actor + 0x54) != 0 or load(u8, actor + 0x10ec) == 0 or load(i8, actor + 0xdde) <= 0) return 0;
    const weapon = load(usize, actor + 0x528);
    if (!s.readable(weapon, 0x4c) or load(u8, weapon + 0x49) & 8 != 0 or load(u8, weapon + 0x4a) & 0x40 != 0) return 0;
    const descriptor = load(usize, weapon + 8);
    if (!s.readable(descriptor, 0xb0)) return 0;
    const definition = load(usize, descriptor + 0xac);
    if (!s.readable(definition, 0x12e) or load(u16, definition + 0x12c) & 0xe0 != 0x40 or load(u32, definition + 0x38) & 0x80000 == 0) return 0;
    s.clonewars_saber_host_repair[0] +%= 1;
    s.clonewars_saber_host_repair[2] = load(u32, 0xfb4b6c);
    return 1;
}
pub noinline fn producer(positions: usize, life: f32, color: u32, handle: ?*usize, mode: u32, actor: usize) callconv(.c) void {
    const caller = @returnAddress() -% 5;
    var index: usize = 0;
    while (index < producers.len and producers[index] != caller) : (index += 1) {}
    const record = &s.clonewars_saber_producer[index];
    record[1..7].* = .{ load(u32, 0xfb4b6c), actor, if (handle) |value| @intFromPtr(value) else 0, color, @bitCast(life), load(u32, 0xfbca90) };
    const call: *const fn (usize, f32, u32, ?*usize, u32, usize) callconv(.c) void = @ptrFromInt(0x906b00);
    call(positions, life, color, handle, mode, actor);
    record[7] = load(u32, 0xfbca90);
    record[8] = if (handle) |value| value.* else 0;
    record[0] +%= 1;
}
pub fn age(delta: f32) callconv(.c) void {
    const record = &s.clonewars_saber_producer[16];
    record[1] = load(u32, 0xfb4b6c);
    record[5] = @bitCast(delta);
    record[6] = load(u32, 0xfbca90);
    const call: *const fn (f32) callconv(.c) void = @ptrFromInt(0x906920);
    call(delta);
    record[7] = load(u32, 0xfbca90);
    record[0] +%= 1;
}
pub fn installPass(at: usize, native: usize, target: usize) void {
    var expected: [5]u8 = undefined;
    expected[0] = 0xe8;
    std.mem.writeInt(u32, expected[1..5], @truncate(native -% at -% 5), .little);
    const patches = [_]hooks.Patch{.{ .address = at, .expected = &expected, .target = target, .opcode = 0xe8 }};
    _ = hooks.apply(&patches);
}
extern fn saber_weapon_visibility_gate() void;
extern fn saber_actor_batch_tap() void;
extern fn saber_pass_first() void;
extern fn saber_pass_last() void;
extern fn saber_submit_glow_indexed() void;
extern fn saber_submit_glow_plain() void;
extern fn saber_submit_glow_repeat_indexed() void;
extern fn saber_submit_glow_repeat_plain() void;
extern fn saber_submit_core_indexed() void;
extern fn saber_submit_core_plain() void;
extern fn saber_submit_other() void;
pub fn install() void {
    const patches = [_]hooks.Patch{.{ .address = 0x7c7d7c, .expected = "\x80\x78\x42\x00\x74\x67", .target = @intFromPtr(&saber_weapon_visibility_gate) }};
    if (hooks.apply(&patches)) s.clonewars_saber_host_repair[1] = 1;
    var setting: [2]u8 = undefined;
    if (s.platform.GetEnvironmentVariableA("CLONEWARS_SABER_PASS_TRACE", &setting, setting.len) != 1 or setting[0] != '1') return;
    installPass(0x7add49, 0x9b6c20, @intFromPtr(&saber_actor_batch_tap));
    for (producers) |at| installPass(at, 0x906b00, @intFromPtr(&producer));
    installPass(0x888549, 0x906920, @intFromPtr(&age));
    installPass(0x8447b5, 0x907470, @intFromPtr(&saber_pass_first));
    installPass(0x8447f4, 0x907470, @intFromPtr(&saber_pass_last));
    const Site = struct { at: usize, native: usize, target: usize };
    const submits = [_]Site{ .{ .at = 0x5c0f45, .native = 0x5be930, .target = @intFromPtr(&saber_submit_glow_indexed) }, .{ .at = 0x5c0f58, .native = 0x5bee90, .target = @intFromPtr(&saber_submit_glow_plain) }, .{ .at = 0x5c1039, .native = 0x5be930, .target = @intFromPtr(&saber_submit_glow_repeat_indexed) }, .{ .at = 0x5c104c, .native = 0x5bee90, .target = @intFromPtr(&saber_submit_glow_repeat_plain) }, .{ .at = 0x5c1078, .native = 0x5be930, .target = @intFromPtr(&saber_submit_core_indexed) }, .{ .at = 0x5c109e, .native = 0x5bee90, .target = @intFromPtr(&saber_submit_core_plain) }, .{ .at = 0x907c2b, .native = 0x5be910, .target = @intFromPtr(&saber_submit_other) } };
    for (submits) |entry| installPass(entry.at, entry.native, entry.target);
}
