const std = @import("std");
const f = @import("native_probe_fixture.zig");
const binding = @import("effect_binding.zig");
const support = @import("character_support.zig");
const p = @import("protocol.zig");
const physics = @import("physics_validation.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var effect_birth_resume: usize = 0;
export var breakup_launch_native: usize = 0;
var calls: u32 = 0;
pub const probe_registers =
    \\movl $0x87654321,0x204(%esp)
    \\movl _argument,%eax
;
export fn physics_effect_birth(node: usize) void {
    const err = win.GetLastError();
    check(@src(), node == f.argument);
    calls += 1;
    asm volatile ("fninit; pcmpeqd %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7" ::: .{ .xmm0 = true, .xmm7 = true });
    win.SetLastError(err);
}
export fn physics_apply_breakup_launch(_: usize, _: usize, _: usize, _: usize, _: usize, _: usize) void {
    unreachable;
}
fn live(_: *const binding.Binding, index: usize, flags: *const [4]bool) bool {
    return flags[index];
}
extern fn native_exit() void;
extern fn resume_exit() void;
extern fn physics_effect_birth_thunk() void;
comptime {
    _ = @import("physics_bridges.zig");
    asm (
        \\.text
        \\_native_exit:
        \\movl 0x208(%esp),%ecx
        \\ret
        \\_resume_exit: ret
    );
}
pub fn main() void {
    effect_birth_resume = @intFromPtr(&resume_exit);
    const object: usize = 0x1234;
    var bindings: [4]binding.Binding = @splat(.{});
    var flags = [_]bool{ false, true, false, false };
    var source: [2]u32 = .{ 99, 99 };
    var revoked: u32 = 0;
    bindings[0] = .{ .body = object, .epoch = 7, .sequence = 10, .event = 55 };
    bindings[1] = .{ .body = object, .epoch = 7, .sequence = 22, .event = 20 };
    check(@src(), binding.resolve(&bindings, object, 7, 0, &flags, live, &source, &revoked) == 1 and source[0] == 22 and source[1] == 20 and revoked == 1 and bindings[0].body == 0);
    flags[1] = false;
    flags[2] = true;
    bindings[2] = bindings[1];
    bindings[2].sequence = 23;
    bindings[2].event = 30;
    check(@src(), binding.resolve(&bindings, object, 7, 0, &flags, live, &source, &revoked) == 1 and source[0] == 23 and revoked == 1 and bindings[1].body == 0);
    flags[3] = true;
    bindings[3] = bindings[2];
    bindings[3].event = 31;
    source = .{ 99, 99 };
    check(@src(), binding.resolve(&bindings, object, 7, 0, &flags, live, &source, &revoked) == -1 and std.mem.eql(u32, &source, &.{ 99, 99 }));
    check(@src(), binding.resolve(&bindings, object, 8, 0, &flags, live, &source, &revoked) == 0 and std.mem.eql(u32, &source, &.{ 99, 99 }));
    check(@src(), binding.resolve(&bindings, object, 7, 1, &flags, live, &source, &revoked) == 0 and std.mem.eql(u32, &source, &.{ 99, 99 }));
    var resolved_body: usize = 0x9999;
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 7, 0, &flags, live, &resolved_body, &revoked) == 1 and resolved_body == object);
    resolved_body = 0x9999;
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 8, 0, &flags, live, &resolved_body, &revoked) == 0 and resolved_body == 0x9999);
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 7, 1, &flags, live, &resolved_body, &revoked) == 0 and resolved_body == 0x9999);
    bindings[3] = bindings[2];
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 7, 0, &flags, live, &resolved_body, &revoked) == -1 and resolved_body == 0x9999);
    flags[3] = false;
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 7, 0, &flags, live, &resolved_body, &revoked) == 1 and revoked == 1 and bindings[3].body == 0);
    flags[2] = false;
    resolved_body = 0x9999;
    check(@src(), binding.bodyForSource(&bindings, .{ 23, 30 }, 7, 0, &flags, live, &resolved_body, &revoked) == 0 and revoked == 1 and resolved_body == 0x9999);
    for (0..3000) |i| {
        f.argument = if (i % 2 != 0) 0 else 0x12345678;
        f.entry = @intFromPtr(&native_exit);
        f.invoke_thunk();
        const fx = f.observed_fx;
        const regs = f.observed_regs;
        f.entry = @intFromPtr(&physics_effect_birth_thunk);
        win.SetLastError(123);
        const before = calls;
        f.invoke_thunk();
        check(@src(), calls == before + 1 and win.GetLastError() == 123);
        f.expectSame(@src(), &fx, &regs);
    }
    var body: [0x140]u8 = @splat(0xa4);
    var before = body;
    var local = std.mem.zeroes(p.SyncCharacterMotionState);
    var host = local;
    local.support_frame = 7;
    host.support_frame = 7;
    local.support_event = 3;
    host.support_event = 3;
    host.support_anchor[0] = 2;
    host.support_anchor[3] = 1;
    host.support_normal[1] = 1;
    host.support_material_flags = 0x10400;
    check(@src(), support.replay(@intFromPtr(&body), &local, &host));
    check(@src(), std.mem.eql(u8, body[0x110..0x120], std.mem.asBytes(&host.support_anchor)) and win.load(u32, @intFromPtr(&body) + 0xc0) == 0xa4a4a4a5 and win.load(u16, @intFromPtr(&body) + 0x102) == 0x400);
    for (body, before, 0..) |actual, expected, i| if (!(i >= 0x110 and i < 0x120) and !(i >= 0xf0 and i < 0xfc) and !(i >= 0x102 and i < 0x104) and !(i >= 0xc0 and i < 0xc4)) check(@src(), actual == expected);
    before = body;
    host.support_event += 1;
    check(@src(), !support.replay(@intFromPtr(&body), &local, &host) and std.mem.eql(u8, &body, &before));
    host.support_event -= 1;
    host.support_anchor[2] = std.math.nan(f32);
    check(@src(), !support.replay(@intFromPtr(&body), &local, &host) and std.mem.eql(u8, &body, &before));
    local = std.mem.zeroes(p.SyncCharacterMotionState);
    host = local;
    check(@src(), support.replay(0, &local, &host));
    host.support_event = 1;
    check(@src(), !@import("fire_validation.zig").supportValid(&host));
    host.support_frame = 3321;
    host.support_event = 40;
    host.support_anchor = .{ 0.06, -0.1, -0.05, 1 };
    host.support_normal = .{ -0.9, 0.05, -0.1 };
    host.support_material_flags = 0x10000;
    var contact: [0x20]u8 = @splat(0);
    contact[0x19] = 0x40;
    body = before;
    check(@src(), support.canAcquire(&local, &host) and !support.same(&local, &host));
    check(@src(), support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), win.load(usize, @intFromPtr(&body) + 0xec) == @intFromPtr(&contact));
    local = host;
    host = std.mem.zeroes(p.SyncCharacterMotionState);
    before = body;
    check(@src(), !support.canRelease(&local, &host) and !support.release(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), std.mem.eql(u8, &body, &before));
    host.support_material_flags = p.SYNC_SUPPORT_ABSENT;
    check(@src(), support.canRelease(&local, &host) and !support.same(&local, &host));
    check(@src(), support.release(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), win.load(usize, @intFromPtr(&body) + 0xec) == 0);
    for (body, before, 0..) |actual, expected, i| if (!(i >= 0xec and i < 0xf0)) check(@src(), actual == expected);
    body = before;
    check(@src(), !support.release(@intFromPtr(&body), @intFromPtr(&contact) + 4, &local, &host) and std.mem.eql(u8, &body, &before));
    local = std.mem.zeroes(p.SyncCharacterMotionState);
    check(@src(), support.release(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    local = host;
    host.support_frame = 13;
    host.support_event = 17;
    check(@src(), !@import("fire_validation.zig").supportValid(&host));
    host.support_material_flags = 0;
    check(@src(), support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), std.mem.eql(u8, body[0x110..0x120], std.mem.asBytes(&host.support_anchor)) and std.mem.eql(u8, body[0xf0..0xfc], std.mem.asBytes(&host.support_normal)));
    before = body;
    contact[0x19] = 0x20;
    check(@src(), !support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host) and std.mem.eql(u8, &before, &body));
    contact[0x19] = 0x40;
    host.support_anchor[0] = std.math.nan(f32);
    check(@src(), !support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host) and std.mem.eql(u8, &before, &body));
    host.support_anchor[0] = 0.06;
    local.support_material_flags = 0;
    local.support_frame = 9747;
    local.support_event = 35;
    host.support_frame = 9747;
    host.support_event = 20;
    check(@src(), !support.same(&local, &host) and support.canAcquire(&local, &host));
    check(@src(), support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), win.load(usize, @intFromPtr(&body) + 0xec) == @intFromPtr(&contact));
    var birth = std.mem.zeroes(p.SyncPhysicsChoice);
    birth.kind = p.SYNC_PHYSICS_EFFECT_BIRTH;
    birth.site = 0x7427d8;
    birth.payload.basic.flags = 0x40000000;
    birth.payload.basic.model = 4;
    birth.payload.basic.clock = 12;
    birth.payload.basic.name_hash[0] = 1;
    check(@src(), physics.valid(&birth));
    var other = birth;
    other.payload.basic.name_hash[0] += 1;
    check(@src(), !physics.sameSource(&birth, &other));
    other = birth;
    other.payload.basic.clock += 1;
    check(@src(), !physics.sameSource(&birth, &other));
    birth.payload.basic.recipe[0] = @bitCast(std.math.nan(f32));
    check(@src(), !physics.valid(&birth));
    local = host;
    host.support_material_flags = p.SYNC_SUPPORT_SCENE | 0x10000;
    check(@src(), !support.same(&local, &host) and support.canAcquire(&local, &host));
    const old_flags = win.load(u32, @intFromPtr(&body) + 0xc0);
    check(@src(), support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    check(@src(), win.load(u32, @intFromPtr(&body) + 0xc0) == (old_flags | 1));
    contact[0x19] = 0x20;
    check(@src(), support.acquire(@intFromPtr(&body), @intFromPtr(&contact), &local, &host));
    host.support_material_flags &= ~p.SYNC_SUPPORT_SCENE;
    check(@src(), !support.accepts(@intFromPtr(&contact), &host));
    host.support_material_flags |= p.SYNC_SUPPORT_SCENE;
    host.support_frame = 0;
    host.support_event = 0;
    check(@src(), !@import("fire_validation.zig").supportValid(&host));
}
