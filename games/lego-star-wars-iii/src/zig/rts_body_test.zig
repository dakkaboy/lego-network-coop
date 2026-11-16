const std = @import("std");
const input = @import("rts_body_input.zig");
const sources = @import("rts_sources.zig");
const physics = @import("physics_validation.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const f = @import("rts_input_fixture.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
export var obj: [0x290]u8 = @splat(0);
var pad: [0x280]u8 = @splat(0);
var team: [0x10d4]u8 = @splat(0);
var world: [0x22e8]u8 = @splat(0);
var resource: [0x10]u8 = @splat(0);
var descriptor: [0x34]u8 = @splat(0);
var model: [0x60]u8 = @splat(0);
var receiver: [0x1a4]u8 = @splat(0);
var body: [0xa0]u8 = @splat(0);
var dynamics: [0x50]u8 = @splat(0);
var gizmo_manager: [0x2c]u8 = @splat(0);
var gizmo_registry: [0x2c]u8 = @splat(0);
var container: [0x10]u8 = @splat(0);
var world_handle: usize = 0;
var manager_table: usize = 0;
var create_model = false;
var mode: u32 = 0;
var inputs: u32 = 0;
var originals: u32 = 0;
var applies: u32 = 0;
var expected: [24]f32 = @splat(0);
var local_lanes: [2]u32 = @splat(0);
var visibility_originals: u32 = 0;
var canonical_visibility: u32 = 1;
export var retained: f64 = 0;
export var cw_before: u16 = 0;
export var cw_after: u16 = 0;
export var mx_before: u32 = 0;
export var mx_after: u32 = 0;
export var branch: u32 = 0;
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
export fn physics_world_input(choice: *p.SyncPhysicsChoice, _: *const Token) c_int {
    check(@src(), physics.valid(choice));
    inputs += 1;
    if (choice.kind == p.SYNC_PHYSICS_RTS_VISIBILITY) {
        choice.payload.world.value = canonical_visibility;
        if (mode == 12) f.alive = false;
        if (mode == 11) choice.payload.world.source_name[0] ^= 1;
    } else {
        const part: usize = @intFromBool(choice.kind == p.SYNC_PHYSICS_RTS_BODY_MOTION);
        const values = &choice.payload.spellit_body;
        values.values = expected[12 * part ..][0..12].*;
        if (part != 0) {
            values.values[7] = 0;
            values.values[11] = 0;
        }
        switch (mode) {
            1 => values.key[0] ^= 1,
            2 => f.alive = false,
            3 => put(&pad, 0x114, 0),
            4 => values.values[0] = std.math.nan(f32),
            else => {},
        }
    }
    win.SetLastError(999);
    return 1;
}
fn matrix(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&body) and std.mem.eql(f32, values[0..16], expected[0..16]));
    applies += 1;
    win.SetLastError(777);
}
fn linear(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&model) and std.mem.eql(f32, values[0..3], expected[16..19]) and @as(u32, @bitCast(values[3])) == local_lanes[0]);
    applies += 1;
}
fn angular(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&model) and std.mem.eql(f32, values[0..3], expected[20..23]) and @as(u32, @bitCast(values[3])) == local_lanes[1]);
    applies += 1;
}
fn original(value: usize, state: u32, flag: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&obj) and state == 5 and flag == 1 and win.GetLastError() == 123);
    originals += 1;
    if (create_model) put(&obj, 0x28c, @intFromPtr(&model));
    win.SetLastError(321);
}
fn visibilityOriginal(value: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&obj) and delta == 1234 and win.GetLastError() == 123);
    if (f.enabled) check(@src(), pad[0x27d] == 1);
    visibility_originals += 1;
    win.SetLastError(321);
}
fn jump(address: usize, target: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 5, 0x40, &old) != 0);
    win.store(u8, address, 0xe9);
    win.store(usize, address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn updateBody() void {
    win.SetLastError(123);
    input.rts_body_input_update(@intFromPtr(&obj), 5, 1, original);
    check(@src(), win.GetLastError() == 321);
}
fn continuation() callconv(.c) void {}
extern fn attack_visibility_flags(usize) u32;
comptime {
    asm (
        \\.text
        \\_attack_visibility_flags:
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\call _rts_attack_visibility_input_bridge
        \\pushfl
        \\popl %eax
        \\popl %ebx
        \\ret
    );
}
pub fn main() void {
    check(@src(), @intFromPtr(&native_image) < 0xa29570 and @intFromPtr(&native_image) + native_image.len > 0xfb4b70);
    jump(0xa29570, @intFromPtr(&matrix));
    jump(0x8b5cd0, @intFromPtr(&linear));
    jump(0x8b5e00, @intFromPtr(&angular));
    win.store(usize, 0xe90184, @intFromPtr(&gizmo_registry));
    put(&gizmo_registry, 0x28, 1);
    put(&world, 0x400, @intFromPtr(&world_handle));
    world_handle = @intFromPtr(&manager_table);
    manager_table = @intFromPtr(&gizmo_manager);
    put(&gizmo_manager, 0, 0xaea284);
    put(&gizmo_manager, 0x24, @intFromPtr(&pad));
    put(&pad, 0, 0xaee174);
    put(&pad, 0x28, @intFromPtr(&gizmo_manager));
    put(&world, 0x22e4, @intFromPtr(&container));
    put(&container, 0xc, @intFromPtr(&world));
    win.store(usize, 0xfb4a20, @intFromPtr(&world));
    win.store(u32, 0xfb4b6c, 100);
    put(&obj, 0, 0xaeea9c);
    put(&obj, 0x24, @intFromPtr(&pad));
    put(&obj, 0x28, @intFromPtr(&team));
    put(&team, 0, 0xaef0fc);
    put(&team, 0x1c, @intFromPtr(&descriptor));
    put(&team, 0x34, @intFromPtr(&pad));
    put(&team, 0x10d0, @intFromPtr(&resource));
    put(&resource, 0xc, @intFromPtr(&world));
    @memcpy(world[0x81..][0..12], "NativeWorld\x00");
    @memcpy(pad[0x30..][0..10], "NativePad\x00");
    put(&model, 0x3c, @intFromPtr(&receiver));
    put(&model, 0x58, 0x02000000);
    put(&receiver, 0x1a0, @intFromPtr(&body));
    put(&body, 0, 0xc69eac);
    put(&body, 0x28, @intFromPtr(&receiver));
    put(&body, 0x98, @intFromPtr(&dynamics));
    put(&body, 0x1c, @intFromPtr("NativeBody"));
    for ([_]usize{ 0, 5, 10, 15 }) |index| expected[index] = 1;
    expected[12] = 2;
    expected[16] = 3;
    expected[20] = 4;
    for (0..5) |index| {
        mode = @intCast(index);
        f.alive = true;
        put(&pad, 0x114, @intFromPtr(&obj));
        put(&obj, 0x28c, @intFromPtr(&model));
        const before = originals;
        const applied = applies;
        updateBody();
        check(@src(), originals == before + 1 and applies == applied + (if (mode == 0) @as(u32, 3) else 0));
    }
    f.alive = true;
    mode = 0;
    put(&pad, 0x114, @intFromPtr(&obj));
    put(&obj, 0x28c, @intFromPtr(&model));
    const motion = [_]u32{ 0xc15ebcdb, 0x40fd3fb2, 0x41325b0f, 0xffffffff, 0x3611424b, 0x427c0146, 0xb6236a94, 0xbf229959 };
    win.store([8]u32, @intFromPtr(&dynamics) + 0x20, motion);
    expected[16..24].* = @bitCast(motion);
    local_lanes = .{ motion[3], motion[7] };
    const successful = applies;
    updateBody();
    check(@src(), applies == successful + 3);
    for ([_]usize{ 0, 1, 2, 4, 5, 6 }) |lane| {
        put(&dynamics, 0x20 + lane * 4, 0x7fc00000);
        var sample = std.mem.zeroes(p.SyncPhysicsChoice);
        sample.kind = p.SYNC_PHYSICS_RTS_BODY_MOTION;
        sample.site = 0x544b10;
        sample.payload.spellit_body.key[0] = 1;
        sample.payload.spellit_body.body_class = 0x869eac;
        sample.payload.spellit_body.values[4..7].* = win.load([3]f32, @intFromPtr(&dynamics) + 0x20);
        sample.payload.spellit_body.values[8..11].* = win.load([3]f32, @intFromPtr(&dynamics) + 0x30);
        check(@src(), !physics.valid(&sample));
        put(&dynamics, 0x20 + lane * 4, motion[lane]);
    }
    put(&obj, 0x28c, 0);
    var before = originals;
    var prior = inputs;
    updateBody();
    check(@src(), originals == before + 1 and inputs == prior);
    create_model = true;
    before = originals;
    prior = inputs;
    updateBody();
    check(@src(), originals == before + 1 and inputs == prior + 2);
    prior = inputs;
    create_model = false;
    f.enabled = false;
    put(&obj, 0x24, 0);
    before = originals;
    updateBody();
    check(@src(), originals == before + 1 and inputs == prior and f.faults == 3);
    f.enabled = true;
    put(&obj, 0x24, @intFromPtr(&pad));
    for (10..13) |index| {
        mode = @intCast(index);
        f.alive = true;
        pad[0x27d] = 0;
        const n = visibility_originals;
        win.SetLastError(123);
        input.rts_visibility_input_update(@intFromPtr(&obj), 1234, visibilityOriginal, 0x5525e0);
        check(@src(), visibility_originals == n + @intFromBool(mode == 10) and win.GetLastError() == (if (mode == 10) @as(u32, 321) else 123) and pad[0x27d] == @intFromBool(mode == 10));
    }
    f.enabled = false;
    const n = visibility_originals;
    prior = inputs;
    win.SetLastError(123);
    input.rts_visibility_input_update(@intFromPtr(&obj), 1234, visibilityOriginal, 0x5525e0);
    check(@src(), visibility_originals == n + 1 and inputs == prior and pad[0x27d] == 0);
    var object_source: sources.Object = undefined;
    put(&team, 0x34, 0);
    check(@src(), sources.native_rts_object_source(@intFromPtr(&obj), &object_source) != 0);
    put(&gizmo_manager, 0x24, 0);
    check(@src(), sources.native_rts_object_source(@intFromPtr(&obj), &object_source) == 0);
    put(&gizmo_manager, 0x24, @intFromPtr(&pad));
    f.enabled = true;
    f.alive = true;
    mode = 10;
    canonical_visibility = 0;
    pad[0x27d] = 1;
    const native_originals = visibility_originals;
    const attack_inputs = input.clonewars_rts_visibility_input_debug[2];
    win.SetLastError(123);
    input.rts_visibility_input_update(@intFromPtr(&obj), 0, null, 0x546674);
    check(@src(), pad[0x27d] == 0 and visibility_originals == native_originals and input.clonewars_rts_visibility_input_debug[2] == attack_inputs + 1 and win.GetLastError() == 123);
    check(@src(), std.mem.eql(u32, &input.clonewars_rts_attack_visibility_debug, &.{ 1, 1, 1, 0 }));
    jump(0x54667b, @intFromPtr(&continuation));
    pad[0x27d] = 1;
    win.SetLastError(123);
    asm volatile (
        \\fnstcw _cw_before
        \\stmxcsr _mx_before
        \\fld1
        \\pushl $_obj
        \\call _attack_visibility_flags
        \\addl $4,%%esp
        \\movl %%eax,_branch
        \\fstpl _retained
        \\fnstcw _cw_after
        \\stmxcsr _mx_after
        ::: .{ .memory = true, .cc = true, .eax = true, .ecx = true, .edx = true });
    check(@src(), branch & 0x40 != 0 and pad[0x27d] == 0 and win.GetLastError() == 123 and retained == 1 and cw_before == cw_after and mx_before == mx_after);
    canonical_visibility = 1;
    pad[0x27d] = 0;
    win.SetLastError(123);
    check(@src(), attack_visibility_flags(@intFromPtr(&obj)) & 0x40 == 0 and pad[0x27d] == 1 and win.GetLastError() == 123);
    mode = 11;
    pad[0x27d] = 0;
    win.SetLastError(123);
    input.rts_visibility_input_update(@intFromPtr(&obj), 0, null, 0x546674);
    check(@src(), pad[0x27d] == 0 and win.GetLastError() == 123);
    var attack = std.mem.zeroes(p.SyncPhysicsChoice);
    attack.kind = p.SYNC_PHYSICS_RTS_VISIBILITY;
    attack.site = 0x546674;
    attack.payload.world.source_name[0] = 1;
    attack.payload.world.gizmo_class = 0xaee6dc;
    check(@src(), physics.valid(&attack));
    attack.payload.world.value = 2;
    check(@src(), !physics.valid(&attack));
    attack.payload.world.value = 0;
    attack.site += 1;
    check(@src(), !physics.valid(&attack));
    var sample = std.mem.zeroes(p.SyncPhysicsChoice);
    sample.kind = p.SYNC_PHYSICS_RTS_BODY_MOTION;
    sample.site = 0x544b10;
    sample.payload.spellit_body.key[0] = 1;
    sample.payload.spellit_body.body_class = 0x869eac;
    check(@src(), physics.valid(&sample));
    for ([_]usize{ 7, 11 }) |lane| {
        var invalid = sample;
        invalid.payload.spellit_body.values[lane] = 1;
        check(@src(), !physics.valid(&invalid));
    }
    sample.kind = p.SYNC_PHYSICS_RTS_BODY_BASIS;
    check(@src(), physics.valid(&sample));
    var other = sample;
    other.payload.spellit_body.values[0] = 7;
    check(@src(), physics.sameSource(&sample, &other));
    other.payload.spellit_body.piece_ordinal = 1;
    check(@src(), !physics.sameSource(&sample, &other));
    other = sample;
    other.site = 0x840660;
    check(@src(), !physics.valid(&other));
}
