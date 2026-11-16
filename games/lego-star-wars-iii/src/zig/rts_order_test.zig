const std = @import("std");
const input = @import("rts_order_input.zig");
const sources = @import("rts_sources.zig");
const physics = @import("physics_validation.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const f = @import("rts_input_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var order: [0x330]u8 = @splat(0);
var building: [0x128]u8 = @splat(0);
var team: [0x1a34]u8 = @splat(0);
var descriptor: [0x34]u8 = @splat(0);
var world: [0x22e8]u8 = @splat(0);
var container: [16]u8 = @splat(0);
var registry: [0x2c]u8 = @splat(0);
var manager: [0x28]u8 = @splat(0);
var resource: [16]u8 = @splat(0);
var table: [1]usize = @splat(0);
var handle: usize = 0;
var mode: u32 = 0;
var calls: u32 = 0;
var original_calls: u32 = 0;
export fn physics_world_input(choice: *p.SyncPhysicsChoice, _: *const Token) c_int {
    calls += 1;
    check(@src(), physics.valid(choice));
    const value = &choice.payload.rts_order;
    if (choice.site == 0x55e2c0) {
        value.state = 5;
        value.previous_state = 4;
        value.elapsed = 0.5;
        value.progress = 0.1;
    } else value.ready = 2;
    switch (mode) {
        1 => value.building_ordinal += 1,
        2 => f.alive = false,
        3 => put(&building, 0x114, 0),
        4 => value.elapsed = std.math.nan(f32),
        6 => value.source_key[0] ^= 1,
        7 => put(&building, 0x124, 37),
        else => {},
    }
    win.SetLastError(999);
    return if (mode == 5) -1 else 1;
}
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn word(base: anytype, offset: usize) u32 {
    return win.load(u32, @intFromPtr(base) + offset);
}
fn original(value: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    original_calls += 1;
    check(@src(), value == @intFromPtr(&order) and delta == 0x3dcccccd and word(&order, 0x2e8) == 5 and word(&order, 0x2ec) == 4 and win.GetLastError() == 123);
    win.SetLastError(321);
    check(@src(), input.native_rts_order_ready(@intFromPtr(&order), 0xa0) == 0xa2 and win.GetLastError() == 321);
}
pub fn main() void {
    check(@src(), @intFromPtr(&native_image) < 0xfb0000 and @intFromPtr(&native_image) + native_image.len > 0xfc0000);
    win.store(u32, 0xfb4b6c, 100);
    put(&order, 0, 0xaec000);
    put(&order, 0x24, @intFromPtr(&building));
    put(&order, 0x28, @intFromPtr(&team));
    put(&team, 0, 0xaef0fc);
    put(&team, 0x1c, @intFromPtr(&descriptor));
    put(&descriptor, 0x30, 0);
    win.store(usize, 0xfb4a20, @intFromPtr(&world));
    win.store(usize, 0xe90184, @intFromPtr(&registry));
    put(&world, 0x22e4, @intFromPtr(&container));
    put(&container, 12, @intFromPtr(&world));
    table[0] = @intFromPtr(&manager);
    handle = @intFromPtr(&table);
    put(&world, 0x400, @intFromPtr(&handle));
    put(&registry, 0x28, 1);
    @memcpy(world[0x81..][0..14], "NativeMission\x00");
    @memcpy(building[0x30..][0..15], "NativeBuilding\x00");
    put(&manager, 0, 0xc4c1cc);
    put(&manager, 0x24, @intFromPtr(&building));
    put(&building, 0, 0xc47e9c);
    put(&building, 0x28, @intFromPtr(&manager));
    put(&resource, 12, @intFromPtr(&world));
    put(&team, 0x10d0, @intFromPtr(&resource));
    for (0..8) |index| {
        mode = @intCast(index);
        f.alive = true;
        put(&building, 0x114, @intFromPtr(&order));
        put(&order, 0x2e8, 2);
        put(&order, 0x2ec, 1);
        put(&order, 0x2f0, 0);
        put(&order, 0x2d4, 0);
        var source: sources.Order = undefined;
        check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) != 0);
        const before = original_calls;
        win.SetLastError(123);
        input.rts_order_input_update(@intFromPtr(&order), 0x3dcccccd, original);
        const accepted = mode == 0 or mode == 7;
        check(@src(), original_calls == before + @intFromBool(accepted));
        if (!accepted) check(@src(), word(&order, 0x2e8) == 2 and word(&order, 0x2ec) == 1 and word(&order, 0x2f0) == 0 and word(&order, 0x2d4) == 0);
        check(@src(), win.GetLastError() == (if (accepted) @as(u32, 321) else 123));
    }
    f.alive = true;
    put(&building, 0x114, @intFromPtr(&order));
    var source: sources.Order = undefined;
    check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) != 0);
    put(&building, 0x124, 89);
    check(@src(), sources.native_rts_order_source_live(&source) != 0);
    building[0x30] = 'X';
    check(@src(), sources.native_rts_order_source_live(&source) == 0);
    building[0x30] = 'N';
    table[0] = 0;
    check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) == 0);
    table[0] = @intFromPtr(&manager);
    put(&resource, 12, 0);
    check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) == 0);
    put(&resource, 12, @intFromPtr(&world));
    put(&descriptor, 0x30, p.SYNC_MAX_RTS_TEAMS);
    check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) == 0);
    put(&descriptor, 0x30, 0);
    check(@src(), sources.native_rts_order_source(@intFromPtr(&order), &source) != 0);
    put(&order, 0, 0xaec004);
    check(@src(), sources.native_rts_order_source_live(&source) == 0);
}
