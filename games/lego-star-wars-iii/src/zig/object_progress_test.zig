const std = @import("std");
const progress = @import("object_progress.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const check = @import("native_test_support.zig").check;
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var world: usize = 0;
var container: usize = 0;
var handle: usize = 0;
var table: usize = 0;
var provider: usize = 0;
var registry: usize = 0;
var manager: usize = 0;
var node: usize = 0;
var recipe: usize = 0;
var regen_provider: usize = 0;
var token = std.mem.zeroes(Token);
var mode: u32 = 0;
var updates_called: u32 = 0;
var regen_calls: u32 = 0;
var valid = true;
var fault: i32 = 0;
const Update = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Regen = *const fn (usize, u8, u8, u32, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
var update: Update = undefined;
var render: Regen = undefined;
export fn lan_status() c_int {
    return if (mode == 19) 0 else 3;
}
export fn game_sync_epoch() u32 {
    return if (mode == 20) 0 else 7;
}
export fn coherent_frame_get(out: *Token, phases: u32) c_int {
    check(@src(), phases == 4);
    out.* = token;
    return 1;
}
export fn coherent_frame_valid(value: *const Token, phases: u32) c_int {
    check(@src(), phases == 4);
    return @intFromBool(valid and value.sequence == token.sequence);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
fn nativeUpdate(value: usize, _: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == manager);
    updates_called += 1;
    if (mode == 4) put(provider + 0x38, 1);
    win.SetLastError(321);
}
fn nativeRegen(value: usize, current: u8, maximum: u8, delta: u32, enabled: c_int) callconv(.{ .x86_thiscall = .{} }) u8 {
    check(@src(), value == regen_provider);
    regen_calls += 1;
    if (mode == 21 and enabled == 0) {
        check(@src(), delta == 0);
        return current;
    }
    check(@src(), current == 2 and maximum == 8 and delta == 0x3d23d70a and enabled == 1);
    switch (mode) {
        8 => win.store(u8, recipe + 0x6b, 9),
        9 => win.store(u8, regen_provider + 8, 1),
        10 => put(node, 1),
        11 => put(node + 0x88, 1),
        12 => win.store(u8, node + 0x73, 1),
        13 => put(node + 0xf0, 1),
        14 => put(node + 0x84, 1),
        15 => put(node + 0x24, 1),
        16 => win.store(u8, node + 0xec, 3),
        17 => valid = false,
        18 => put(manager + 0x24, 0),
        else => {},
    }
    win.SetLastError(777);
    return 3;
}
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn setup() void {
    token = std.mem.zeroes(Token);
    token.sequence = 100 + mode;
    token.epoch = 7;
    token.frame = world;
    token.release = 3;
    valid = true;
    fault = 0;
    updates_called = 0;
    regen_calls = 0;
    for ([_]usize{ world, container, handle, table, provider, registry, manager, node, recipe, regen_provider }) |address| @memset(@as([*]u8, @ptrFromInt(address))[0..if (address == world) @as(usize, 0x3000) else 0x1000], 0);
    put(0xfb4a20, world);
    put(0xe901dc, provider);
    put(0xe90184, registry);
    put(0xfb4b6c, 31);
    put(world + 0x22e4, container);
    put(world + 0x400, handle);
    put(container + 0xc, world);
    put(handle, table);
    put(registry + 0x28, 1);
    put(table, manager);
    put(manager, 0xc4c8ec);
    put(manager + 0x24, node);
    put(node, 0xc47e9c);
    win.store(u16, node + 0x62, 3);
    put(node + 0x88, 0x12345678);
    put(node + 0xf0, regen_provider);
    put(node + 0x84, recipe);
    win.store(u8, node + 0xec, 2);
    win.store(u8, recipe + 0x6b, 8);
}
const Snapshot = extern struct { result: i32, fault: i32, error_code: u32, updates: u32, calls: u32, debug: [4]u32, failure: [12]u32, current: u8, maximum: u8, flags: u8, render: u8 };
fn run() Snapshot {
    setup();
    progress.clonewars_object_progress_debug = @splat(0);
    progress.clonewars_object_progress_failure = @splat(0);
    var out = std.mem.zeroes(Snapshot);
    const delta: u32 = if (mode == 1) 0x7fc00001 else if (mode == 2) 0x3f800000 else 0x3d23d70a;
    if (mode == 3) put(manager, 0);
    win.SetLastError(123);
    update(manager, delta);
    if (mode == 22) update(manager, delta);
    if (mode == 5) token.owner_nonce += 1;
    if (mode == 6) put(world + 0x22e4, 0);
    if (mode == 7) put(node + 0xf0, 1);
    if (mode == 23) token.sequence += 1;
    if (mode == 24) valid = false;
    if (mode == 21) out.render = render(regen_provider, 2, 8, 0x3f800000, 1);
    out.result = progress.object_progress_world_complete(world, &token);
    out.error_code = win.GetLastError();
    out.fault = fault;
    out.updates = updates_called;
    out.calls = regen_calls;
    out.current = win.load(u8, node + 0xec);
    out.maximum = win.load(u8, recipe + 0x6b);
    out.flags = win.load(u8, node + 0x73);
    out.debug = progress.clonewars_object_progress_debug;
    out.failure = progress.clonewars_object_progress_failure;
    return out;
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 88 and @intFromPtr(&native_image) < 0x859240 and @intFromPtr(&native_image) + native_image.len > 0xfb4b6c);
    const allocations = [_]*usize{ &world, &container, &handle, &table, &provider, &registry, &manager, &node, &recipe, &regen_provider };
    for (allocations, 0..) |out, index| {
        out.* = win.VirtualAlloc(0, if (index == 0) 0x3000 else 0x1000, 0x3000, 4);
        check(@src(), out.* != 0);
    }
    defer for (allocations) |address| {
        _ = win.VirtualFree(address.*, 0, 0x8000);
    };
    var old: u32 = 0;
    for ([_]usize{ 0x87c930, 0x859240, 0x85cacb, 0xc4c92c }) |address| check(@src(), win.VirtualProtect(address, 16, 0x40, &old) != 0);
    jump(0x87c930, @intFromPtr(&nativeUpdate));
    jump(0x859240, @intFromPtr(&nativeRegen));
    put(0xc4c92c, 0x87c930);
    win.store(u8, 0x85cacb, 0xe8);
    put(0x85cacc, @as(usize, 0x859240) -% 0x85cad0);
    check(@src(), progress.object_progress_install() != 0);
    update = @ptrFromInt(win.load(usize, 0xc4c92c));
    render = @ptrFromInt(0x85cad0 +% win.load(usize, 0x85cacc));
    const expected = [_]u32{ 4055156871, 4128823614, 1071235400, 2917400967, 2950101186, 1214799811, 4140808852, 529720647, 693025387, 3661475837, 4113663082, 1123366639, 3873087709, 212152753, 1317802206, 1958350787, 815240041, 2389607317, 2500607543, 1352558241, 1352558241, 4056198927, 513053415, 1352558241, 3497971076 };
    for (expected, 0..) |hash, index| {
        mode = @intCast(index);
        var actual = run();
        for ([_]usize{ world, world, manager, provider }, 4..) |pointer, field| if (actual.failure[field] != 0) {
            check(@src(), actual.failure[field] == pointer);
            actual.failure[field] = @intCast(0x1000 + field);
        };
        var result: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| result = (result ^ byte) *% 16777619;
        if (result != hash) std.debug.print("object_progress mode={d} hash={d} expected={d}\n", .{ mode, result, hash });
        check(@src(), result == hash);
    }
}
