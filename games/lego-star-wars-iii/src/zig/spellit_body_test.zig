const std = @import("std");
const source = @import("spellit_source.zig");
const types = @import("identity_types.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var piece: [0x120]u8 = @splat(0);
var model: [0x60]u8 = @splat(0);
var receiver: [0x1a4]u8 = @splat(0);
var body: [0xa0]u8 = @splat(0);
var dynamics: [0x50]u8 = @splat(0);
var vtable: [8]u32 = @splat(0);
const name = "NativeBody";
const other_name = "ReplacedBody";
var alive = true;
var matrix_calls: u32 = 0;
var linear_calls: u32 = 0;
var angular_calls: u32 = 0;
var mutation: u32 = 0;
export var body_source: source.Source = std.mem.zeroes(source.Source);
export var body_binding: source.Body = std.mem.zeroes(source.Body);
export var body_canonical: source.State = std.mem.zeroes(source.State);
export var body_control: u16 = 0x7f;
export var body_before: u16 = 0;
export var body_after: u16 = 0;
export var body_mx_before: u32 = 0;
export var body_mx_after: u32 = 0;
export var body_retained: f64 = 0;
export var body_result: c_int = 0;
export fn native_authored_poi_resolve(_: usize, _: *types.AuthoredPoi) c_int {
    return 0;
}
export fn native_resource_identity_resolve(_: usize, _: usize, _: *types.ResourceIdentity) c_int {
    return 0;
}
export fn body_lease(_: usize) c_int {
    return @intFromBool(alive);
}
fn pointer(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn nativeEnvironment() void {
    var control: u16 = 0;
    asm volatile ("fnstcw (%[cw])"
        :
        : [cw] "r" (&control),
        : .{ .memory = true });
    check(@src(), control == 0x7f);
}
fn clobber() void {
    win.SetLastError(777);
    asm volatile ("fninit; fldz; pcmpeqd %%xmm0,%%xmm0" ::: .{ .memory = true, .xmm0 = true });
}
fn matrix(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    nativeEnvironment();
    check(@src(), value == @intFromPtr(&body));
    matrix_calls += 1;
    @memcpy(body[0x40..][0..64], std.mem.sliceAsBytes(values[0..16]));
    if (mutation == 1) alive = false;
    if (mutation == 2) pointer(&body, 0x98, 0);
    clobber();
}
fn linear(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    nativeEnvironment();
    check(@src(), value == @intFromPtr(&model));
    linear_calls += 1;
    @memcpy(dynamics[0x20..][0..16], std.mem.sliceAsBytes(values[0..4]));
    clobber();
}
fn angular(value: usize, values: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    nativeEnvironment();
    check(@src(), value == @intFromPtr(&model));
    angular_calls += 1;
    @memcpy(dynamics[0x30..][0..16], std.mem.sliceAsBytes(values[0..4]));
    clobber();
}
fn install(address: usize, target: usize) void {
    const site = win.GetModuleHandleA(null) + address - 0x400000;
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(site, 5, 0x40, &old) != 0);
    win.store(u8, site, 0xe9);
    win.store(usize, site + 1, target -% site -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), site, 5) != 0);
}
extern fn invoke_body() void;
comptime {
    asm (
        \\.text
        \\_invoke_body:
        \\pushal
        \\fninit
        \\fldcw _body_control
        \\fnstcw _body_before
        \\stmxcsr _body_mx_before
        \\fld1
        \\pushl $0
        \\pushl $_body_lease
        \\pushl $_body_canonical
        \\pushl $_body_binding
        \\pushl $_body_source
        \\call _native_spellit_body_apply
        \\addl $20,%esp
        \\movl %eax,_body_result
        \\fstpl _body_retained
        \\fnstcw _body_after
        \\stmxcsr _body_mx_after
        \\popal
        \\ret
    );
}
fn apply() c_int {
    return source.native_spellit_body_apply(&body_source, &body_binding, &body_canonical, body_lease, 0);
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0x729570 and @intFromPtr(&image) + image.len > 0xa29575);
    install(0xa29570, @intFromPtr(&matrix));
    install(0x8b5cd0, @intFromPtr(&linear));
    install(0x8b5e00, @intFromPtr(&angular));
    body_source.gizmo = @intFromPtr(&body_source);
    body_binding.piece = @intFromPtr(&piece);
    body_binding.model = @intFromPtr(&model);
    body_binding.receiver = @intFromPtr(&receiver);
    body_binding.body = @intFromPtr(&body);
    body_binding.dynamics = @intFromPtr(&dynamics);
    body_binding.name = @intFromPtr(name);
    pointer(&piece, 0xfc, body_source.gizmo);
    pointer(&piece, 0x100, @intFromPtr(&model));
    pointer(&model, 0x3c, @intFromPtr(&receiver));
    win.store(u16, @intFromPtr(&model) + 0x5a, 0x200);
    pointer(&receiver, 0x1a0, @intFromPtr(&body));
    pointer(&body, 0, @intFromPtr(&vtable));
    pointer(&body, 0x98, @intFromPtr(&dynamics));
    pointer(&body, 0x1c, @intFromPtr(name));
    body_binding.body_class = @intCast(@intFromPtr(&vtable) - win.GetModuleHandleA(null));
    var key: [4]u32 = .{ 2166136261, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35 };
    const name_bytes = [_]u8{ 10, 0, 0, 0 } ++ "NativeBody".*;
    for (name_bytes) |byte| for (&key, 0..) |*word, i| {
        word.* = (word.* ^ byte) *% @as(u32, @intCast(16777619 + 2 * i));
    };
    body_binding.name_key = key;
    body_canonical.basis[0] = 1;
    body_canonical.basis[5] = 1;
    body_canonical.basis[10] = 1;
    body_canonical.position[0] = 7;
    body_canonical.position[3] = 1;
    body_canonical.linear[1] = 2;
    body_canonical.angular[2] = 3;
    for (0..3) |i| {
        mutation = @intCast(i);
        alive = true;
        pointer(&body, 0x98, @intFromPtr(&dynamics));
        @memset(body[0x40..][0..64], 0);
        @memset(dynamics[0x20..][0..32], 0);
        matrix_calls = 0;
        linear_calls = 0;
        angular_calls = 0;
        win.SetLastError(321);
        invoke_body();
        const err = win.GetLastError();
        check(@src(), body_result == @intFromBool(i == 0) and matrix_calls == 1 and linear_calls == @intFromBool(i == 0) and angular_calls == @intFromBool(i == 0));
        check(@src(), body_retained == 1 and body_before == body_after and body_mx_before == body_mx_after and err == 321);
    }
    alive = false;
    matrix_calls = 0;
    linear_calls = 0;
    angular_calls = 0;
    check(@src(), apply() == 0 and matrix_calls == 0 and linear_calls == 0 and angular_calls == 0);
    alive = true;
    mutation = 0;
    pointer(&body, 0x98, @intFromPtr(&dynamics));
    body_canonical.linear[0] = std.math.nan(f32);
    check(@src(), apply() == 0 and matrix_calls == 0 and linear_calls == 0 and angular_calls == 0);
    body_canonical.linear[0] = 0;
    pointer(&body, 0x1c, @intFromPtr(other_name));
    check(@src(), source.native_spellit_body_matches(&body_source, &body_binding) == 0);
    check(@src(), apply() == 0 and matrix_calls == 0 and linear_calls == 0 and angular_calls == 0);
    pointer(&body, 0x1c, @intFromPtr(name));
    body_canonical.linear[3] = @bitCast(@as(u32, 0xffffffff));
    body_canonical.angular[3] = @bitCast(@as(u32, 0x7fc12345));
    win.SetLastError(321);
    invoke_body();
    check(@src(), body_result == 1 and matrix_calls == 1 and linear_calls == 1 and angular_calls == 1);
    check(@src(), win.load(u32, @intFromPtr(&dynamics) + 0x2c) == 0xffffffff and win.load(u32, @intFromPtr(&dynamics) + 0x3c) == 0x7fc12345);
    check(@src(), body_retained == 1 and body_before == body_after and body_mx_before == body_mx_after and win.GetLastError() == 321);
    const good = body_canonical;
    for (0..24) |lane| {
        if (lane == 19 or lane == 23) continue;
        body_canonical = good;
        @as(*[24]f32, @ptrCast(&body_canonical))[lane] = std.math.nan(f32);
        check(@src(), apply() == 0 and matrix_calls == 1 and linear_calls == 1 and angular_calls == 1);
    }
}
