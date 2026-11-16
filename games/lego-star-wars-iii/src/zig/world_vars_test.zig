const std = @import("std");
const vars = @import("world_vars.zig");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const support = @import("native_test_support.zig");
const check = support.check;
pub const world_vars_test_api = true;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
var active = std.mem.zeroes(Token);
var valid = true;
var cancellation: u32 = 0;
var lookups: u32 = 0;
var before_mode: u32 = 0;
var applied: c_int = 0;
var manager_global: usize = 0;
var area_global: usize = 0;
var slots_global: usize = 0;
var handle: usize = 0;
var table: [1]usize = @splat(0);
var manager: [0x4c]u8 = @splat(0);
var replacement_manager: [0x4c]u8 = @splat(0);
var area: [0x404]u8 = @splat(0);
var slots: [0x2c]u8 = @splat(0);
var global_registry: [0x64]u8 = @splat(0);
var area_registry: [0x64]u8 = @splat(0);
var nodes: [4][0x4c]u8 = @splat(@splat(0));
export fn coherent_frame_valid(token: *const Token, phases: u32) c_int {
    return @intFromBool(valid and phases & 2 != 0 and std.mem.eql(u8, std.mem.asBytes(token), std.mem.asBytes(&active)));
}
export fn coherent_frame_cancel_atomic(reason: u32) void {
    cancellation |= reason;
    valid = false;
}
export fn world_vars_test_address(address: usize) usize {
    return switch (address) {
        0xe901cc => @intFromPtr(&manager_global),
        0xfb4a20 => @intFromPtr(&area_global),
        0xe90184 => @intFromPtr(&slots_global),
        else => unreachable,
    };
}
export fn world_vars_test_before_lookup() void {
    if (before_mode == 1) valid = false;
    if (before_mode == 2) win.RaiseException(0xe1771234, 0, 0, null);
}
export fn world_vars_test_lookup(owner: usize, context: usize, name: [*:0]const u8, scope: i32, unused: usize) usize {
    check(@src(), owner == @intFromPtr(&manager) and unused == 0);
    lookups += 1;
    if (before_mode == 3) manager_global = @intFromPtr(&replacement_manager);
    for (&nodes, 0..) |*node, i| {
        const local = node[0x14..0x34];
        const length = std.mem.indexOfScalar(u8, local, 0) orelse local.len;
        if (!std.mem.eql(u8, local[0..length], std.mem.span(name))) continue;
        const expected: i32 = if (i == 3) @intCast(@intFromPtr(&area)) else if (i == 2) 1 else 0;
        check(@src(), scope == expected and context == if (scope != 0) @intFromPtr(&area) else @as(usize, 0));
        return @intFromPtr(node);
    }
    return 0;
}
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn setup() void {
    manager_global = @intFromPtr(&manager);
    area_global = @intFromPtr(&area);
    slots_global = @intFromPtr(&slots);
    put(&manager, 0x48, @intFromPtr(&global_registry));
    put(&manager, 0x38, 0);
    put(&slots, 0x28, 1);
    put(&area, 0x400, @intFromPtr(&handle));
    handle = @intFromPtr(&table);
    table[0] = @intFromPtr(&area_registry);
    put(&global_registry, 0x58, @intFromPtr(&nodes[0]));
    put(&global_registry, 0x60, 2);
    put(&area_registry, 0x58, @intFromPtr(&nodes[2]));
    put(&area_registry, 0x60, 2);
    nodes = @splat(@splat(0));
    for (&nodes, [_][]const u8{ "Zeta", "Alpha", "Area", "Declaration" }, 0..) |*node, name, i| {
        put(node, 8, if (i == 0) @intFromPtr(&nodes[1]) else if (i == 2) @intFromPtr(&nodes[3]) else 0);
        @memcpy(node[0x14..][0..name.len], name);
        put(node, 0x34, if (i == 3) @intFromPtr(&area) else if (i == 2) 1 else 0);
        win.store(f32, @intFromPtr(node) + 0x38, @floatFromInt(i));
    }
}
fn hash(bytes: []const u8) u32 {
    var result: u32 = 2166136261;
    for (bytes) |byte| result = (result ^ byte) *% 16777619;
    return result;
}
fn nodeHash() u32 {
    var copy = nodes;
    const pointers = [_]usize{ @intFromPtr(&nodes[0]), @intFromPtr(&nodes[1]), @intFromPtr(&nodes[2]), @intFromPtr(&nodes[3]), @intFromPtr(&area) };
    for (&copy) |*node| for ([_]usize{ 8, 0x34 }) |offset| {
        var value = std.mem.readInt(u32, node[offset..][0..4], .little);
        for (pointers, 0..) |pointer, i| if (value == pointer) {
            value = @intCast(0x1000 + i);
        };
        std.mem.writeInt(u32, node[offset..][0..4], value, .little);
    };
    return hash(std.mem.asBytes(&copy));
}
fn collect(frame: *p.SyncFrame, result: c_int, count: u32, expected_hash: u32) void {
    @memset(std.mem.sliceAsBytes(&frame.variables), 0xa5);
    frame.variable_count = 0;
    check(@src(), vars.world_vars_collect(frame) == result and frame.variable_count == count);
    check(@src(), hash(std.mem.sliceAsBytes(&frame.variables)) == expected_hash);
}
fn apply(raw: usize) callconv(.c) c_int {
    applied = vars.world_vars_apply(@ptrFromInt(raw));
    return applied;
}
pub fn main() void {
    const allocator = std.heap.page_allocator;
    const frame = allocator.create(p.SyncFrame) catch unreachable;
    defer allocator.destroy(frame);
    frame.* = std.mem.zeroes(p.SyncFrame);
    frame.epoch = 1;
    frame.sequence = 1;
    active = .{ .owner = 0x1000, .owner_nonce = 1, .cohort_nonce = 1, .thread = win.GetCurrentThreadId(), .release = 1, .epoch = 1, .sequence = 1, .frame = @intFromPtr(frame) };
    setup();
    check(@src(), vars.world_vars_bind_cohort(&active) == 1);
    collect(frame, 1, 4, 4050293772);
    check(@src(), std.mem.eql(u8, frame.variables[0].name[0..5], "Alpha") and frame.variables[3].scope == p.SYNC_VARIABLE_AREA_DECLARATION);
    for (frame.variables[0..4]) |*variable| variable.value += 10;
    for ([_]i32{ 1, 0, -99, 0 }, [_]u32{ 0, 0, 0x10000, 0x20000 }, [_]u32{ 4, 0, 0, 1 }, 0..) |result, cancelled, calls, mode| {
        before_mode = @intCast(mode);
        valid = true;
        cancellation = 0;
        lookups = 0;
        manager_global = @intFromPtr(&manager);
        const observed = support.exceptionResult(@intFromPtr(frame), apply);
        check(@src(), observed.code == if (mode == 2) @as(u32, 0xe1771234) else 0);
        check(@src(), (if (observed.code != 0) @as(c_int, -99) else applied) == result);
        check(@src(), cancellation == cancelled and lookups == calls and nodeHash() == 1324051833);
    }
    before_mode = 0;
    valid = true;
    setup();
    put(&nodes[1], 8, @intFromPtr(&nodes[0]));
    collect(frame, 0, 3, 2292982544);
    setup();
    put(&nodes[0], 0x34, 77);
    collect(frame, 0, 0, 366853573);
    setup();
    check(@src(), vars.world_vars_abort_cohort(&active) == 1 and vars.world_vars_bind_cohort(&active) == 0);
    active.cohort_nonce = 2;
    check(@src(), vars.world_vars_bind_cohort(&active) == 1);
    collect(frame, 1, 4, 4050293772);
}
comptime {
    _ = @import("lexical_seh.zig");
}
