const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const validation = @import("validation.zig");
const equal = validation.equal;
const root = @import("root");
const testing = if (@hasDecl(root, "world_vars_test_api")) root.world_vars_test_api else false;
var binding = std.mem.zeroes(Token);
var bound = false;
var retired = std.mem.zeroes(Token);
var retired_valid = false;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn coherent_frame_cancel_atomic(u32) void;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn world_vars_test_address(usize) usize;
extern fn world_vars_test_before_lookup() void;
extern fn world_vars_test_lookup(usize, usize, [*:0]const u8, i32, usize) usize;
fn address(native: usize) usize {
    return if (testing) world_vars_test_address(native) else native;
}
fn ptr(native: usize) usize {
    return win.load(usize, native);
}
fn readable(value: usize, length: usize) bool {
    return win.accessible(value, length, false);
}
pub export fn world_vars_cohort_valid(token: ?*const Token, phases: u32) c_int {
    const t = token orelse return 0;
    return @intFromBool(bound and t.thread == win.GetCurrentThreadId() and equal(t, &binding) and coherent_frame_valid(t, phases) != 0);
}
pub export fn world_vars_bind_cohort(token: ?*const Token) c_int {
    const t = token orelse return 0;
    if (coherent_frame_valid(t, 2) == 0 or (retired_valid and equal(t, &retired)) or (bound and !equal(t, &binding) and coherent_frame_valid(&binding, 0x3e) != 0)) return 0;
    binding = t.*;
    bound = true;
    return world_vars_cohort_valid(t, 2);
}
pub export fn world_vars_abort_cohort(token: ?*const Token) c_int {
    const t = token orelse return 0;
    if (!bound or t.thread != win.GetCurrentThreadId() or !equal(t, &binding)) return 0;
    retired = t.*;
    retired_valid = true;
    bound = false;
    return 1;
}
fn live(token: *const Token, frame: *const p.SyncFrame) bool {
    return token.frame == @intFromPtr(frame) and world_vars_cohort_valid(token, 2) != 0;
}
fn globalRegistry(manager: usize) usize {
    return if (readable(manager, 0x4c)) ptr(manager + 0x48) else 0;
}
fn areaRegistry(manager: usize, area: usize) usize {
    const index = if (readable(manager, 0x3c)) win.load(i32, manager + 0x38) else -1;
    const slots_owner = ptr(address(0xe90184));
    const count = if (readable(slots_owner, 0x2c)) win.load(i32, slots_owner + 0x28) else 0;
    if (index < 0 or index >= count or index > 4096 or !readable(area, 0x404)) return 0;
    const handle = ptr(area + 0x400);
    if (!readable(handle, 4)) return 0;
    const table = ptr(handle);
    if (!readable(table, @as(usize, @intCast(index + 1)) * 4)) return 0;
    return ptr(table + @as(usize, @intCast(index)) * 4);
}
fn collectRegistry(token: *const Token, frame: *p.SyncFrame, registry: usize, area: usize) bool {
    if (!live(token, frame)) return false;
    if (registry == 0) return true;
    if (!readable(registry, 0x64)) return false;
    var node = ptr(registry + 0x58);
    const expected = win.load(u32, registry + 0x60);
    var visited: u32 = 0;
    if (expected > p.SYNC_MAX_VARIABLES) return false;
    while (node != 0) {
        if (!live(token, frame)) return false;
        visited += 1;
        if (visited > expected + 1 or !readable(node, 0x4c) or frame.variable_count == p.SYNC_MAX_VARIABLES) return false;
        var scope = win.load(u32, node + 0x34);
        if (area != 0 and scope == area) scope = p.SYNC_VARIABLE_AREA_DECLARATION else if (scope > p.SYNC_VARIABLE_AREA) return false;
        var variable: p.SyncVariable = .{ .name = @splat(0), .scope = scope, .value = win.load(f32, node + 0x38) };
        const name = @as([*]const u8, @ptrFromInt(node + 0x14))[0..32];
        const length = std.mem.indexOfScalar(u8, name, 0) orelse name.len;
        @memcpy(variable.name[0..length], name[0..length]);
        if (!validation.worldVariable(frame.level, variable)) return false;
        frame.variables[frame.variable_count] = variable;
        frame.variable_count += 1;
        node = ptr(node + 8);
    }
    return live(token, frame);
}
fn less(_: void, a: p.SyncVariable, b: p.SyncVariable) bool {
    if (a.scope != b.scope) return a.scope < b.scope;
    const first = a.name[0 .. std.mem.indexOfScalar(u8, &a.name, 0) orelse a.name.len];
    const second = b.name[0 .. std.mem.indexOfScalar(u8, &b.name, 0) orelse b.name.len];
    return std.mem.order(u8, first, second) == .lt;
}
pub export fn world_vars_collect(frame: *p.SyncFrame) c_int {
    const token = binding;
    if (!bound or !live(&token, frame)) return 0;
    const manager = ptr(address(0xe901cc));
    const area = ptr(address(0xfb4a20));
    const global = globalRegistry(manager);
    const local = areaRegistry(manager, area);
    frame.variable_count = 0;
    if (!collectRegistry(&token, frame, global, 0) or (local != global and !collectRegistry(&token, frame, local, area)) or !live(&token, frame)) return 0;
    std.mem.sortUnstable(p.SyncVariable, frame.variables[0..frame.variable_count], {}, less);
    return @intFromBool(live(&token, frame));
}
const Lookup = struct { token: Token, manager: usize, area: usize, name: [*:0]const u8, scope: i32 };
fn lookupInvoke(raw: usize) callconv(.c) usize {
    const call: *Lookup = @ptrFromInt(raw);
    if (comptime testing) world_vars_test_before_lookup();
    if (!live(&call.token, @ptrFromInt(call.token.frame))) return 0;
    const area = if (call.scope != 0) call.area else 0;
    if (comptime testing) return world_vars_test_lookup(call.manager, area, call.name, call.scope, 0);
    const Get = *const fn (usize, usize, [*:0]const u8, i32, usize) callconv(.{ .x86_thiscall = .{} }) usize;
    return @as(Get, @ptrFromInt(0x83c9c0))(call.manager, area, call.name, call.scope, 0);
}
fn lookupAbort(raw: usize) callconv(.c) void {
    const call: *Lookup = @ptrFromInt(raw);
    if (bound and call.token.thread == win.GetCurrentThreadId() and equal(&call.token, &binding)) coherent_frame_cancel_atomic(0x10000);
}
pub export fn world_vars_apply(frame: *const p.SyncFrame) c_int {
    const token = binding;
    if (!bound or !live(&token, frame)) return 0;
    const manager = ptr(address(0xe901cc));
    const area = ptr(address(0xfb4a20));
    if (!readable(manager, 0x4c) or frame.variable_count > p.SYNC_MAX_VARIABLES) return 0;
    for (frame.variables[0..frame.variable_count]) |variable| {
        if (!live(&token, frame) or !validation.worldVariable(frame.level, variable)) return 0;
        var name: [33:0]u8 = @splat(0);
        @memcpy(name[0..32], &variable.name);
        if (variable.scope != p.SYNC_VARIABLE_GLOBAL and area == 0) return 0;
        const scope: i32 = if (variable.scope == p.SYNC_VARIABLE_AREA_DECLARATION) @bitCast(@as(u32, @truncate(area))) else @intCast(variable.scope);
        var call: Lookup = .{ .token = token, .manager = manager, .area = area, .name = &name, .scope = scope };
        const node = constructor_lexical_seh(@intFromPtr(&call), lookupInvoke, lookupAbort);
        if (!live(&token, frame)) return 0;
        if (ptr(address(0xe901cc)) != manager or ptr(address(0xfb4a20)) != area) {
            coherent_frame_cancel_atomic(0x20000);
            return 0;
        }
        if (!readable(node, 0x4c) or !live(&token, frame)) return 0;
        win.store(f32, node + 0x38, variable.value);
    }
    return @intFromBool(live(&token, frame));
}
