const std = @import("std");
const win = @import("win32.zig");
const guard = @import("seh_guard.zig");
pub const Ops = extern struct {
    context: usize,
    read: ?*const fn (usize, u32, *anyopaque, usize) callconv(.c) c_int,
    range: ?*const fn (usize, u32, usize, c_int) callconv(.c) c_int,
};
const Failed = error{Unreadable};
const Read = struct {
    ops: *const Ops,
    fn init(ops: ?*const Ops) Failed!Read {
        const o = ops orelse return error.Unreadable;
        if (o.read == null or o.range == null) return error.Unreadable;
        return .{ .ops = o };
    }
    fn range(self: Read, address: u32, length: usize, write: bool) Failed!void {
        if (address == 0 or length == 0 or length > std.math.maxInt(u32) - address or self.ops.range.?(self.ops.context, address, length, @intFromBool(write)) == 0) return error.Unreadable;
    }
    fn bytes(self: Read, address: u32, out: *anyopaque, length: usize) Failed!void {
        try self.range(address, length, false);
        if (self.ops.read.?(self.ops.context, address, out, length) == 0) return error.Unreadable;
    }
    fn get(self: Read, comptime T: type, address: u32) Failed!T {
        var value: T = undefined;
        try self.bytes(address, &value, @sizeOf(T));
        return value;
    }
    fn span(self: Read, address: u32, count: u32, stride: u32) Failed!void {
        if (count == 0) return;
        if (address == 0 or stride == 0 or count > (std.math.maxInt(u32) - address) / stride) return error.Unreadable;
        if (self.ops.range.?(self.ops.context, address, @as(usize, count) * stride, 0) == 0) return error.Unreadable;
    }
    const Table = struct { base: u32, count: u32 };
    fn table(self: Read, base_global: u32, count_global: u32, max: u32, stride: u32) Failed!Table {
        const t: Table = .{ .base = try self.get(u32, base_global), .count = try self.get(u32, count_global) };
        if (t.count > max) return error.Unreadable;
        try self.span(t.base, t.count, stride);
        return t;
    }
};
const aliases = [_]u32{ 0xfb519c, 0xfb847c, 0xfb4bdc, 0xfb4cb4, 0xfbc1dc, 0xfbc1cc, 0xfb3110 };
const offsets = [_]u32{ 0x5b84, 0x1c, 0xb248, 0x6238, 0x6208, 0x6210, 0xb57c };
fn bindings(read: Read, profile: u32) Failed!void {
    for (aliases, offsets) |address, offset| if (try read.get(u32, address) != profile + offset) return error.Unreadable;
}
fn profileBound(ops: ?*const Ops) Failed!void {
    const read = try Read.init(ops);
    const profile = try read.get(u32, 0xfbd8bc);
    if (profile == 0 or profile > std.math.maxInt(u32) - 0xb5c0) return error.Unreadable;
    try read.range(profile, 0xb5c0, true);
    if (try read.get(u32, profile) != 0x500) return error.Unreadable;
    try bindings(read, profile);
    const levels = try read.table(0xfb8404, 0xfb8410, 0x1c2, 0x1b0);
    const areas = try read.table(0xfb5154, 0xfb5160, 0x48, 0xd80);
    _ = try read.table(0xfbd7b8, 0xfbd7bc, 8, 0x18);
    const records = try read.get(u32, 0xe6de7c);
    const record_count = try read.get(u16, 0xe6de82);
    try read.span(records, record_count, 0x20);
    for (0..record_count) |i| {
        const address = records + @as(u32, @intCast(i)) * 0x20;
        if (try read.get(u8, address + 9) & 2 != 0) {
            const index = try read.get(i16, address);
            if (index < 0 or index >= 0x32c) return error.Unreadable;
        }
    }
    const registry = try read.get(u32, 0xe6e0bc);
    const base = try read.get(u32, registry);
    const count = try read.get(u32, registry +% 4);
    if (count > std.math.maxInt(i32)) return error.Unreadable;
    try read.span(base, count, 0x18);
    for (0..count) |i| {
        const record = base + @as(u32, @intCast(i)) * 0x18;
        const definition = try read.get(u32, record);
        if (definition == 0 or definition > std.math.maxInt(u32) - 12) return error.Unreadable;
        _ = try read.get(u32, definition + 8);
        if (try read.get(u8, record + 0x12) == 0) {
            const area = try read.get(i8, record + 0xf);
            if (area != -1) {
                if (area < 0 or area >= areas.count) return error.Unreadable;
            } else {
                const index = try read.get(i16, record + 0x10);
                if (index != -1 and (index < 0 or index >= levels.count)) return error.Unreadable;
            }
        }
    }
    if (try read.get(u32, 0xe6e124) != 0x8f02b0) return error.Unreadable;
    try read.range(0x8f02b0, 1, false);
    for (0..2) |i| {
        const callback = try read.get(u32, 0xfb4d58 + @as(u32, @intCast(i)) * 8);
        if (callback != 0) {
            if (callback != 0x403e80) return error.Unreadable;
            try read.range(callback, 1, false);
        }
    }
    const optional = try read.get(u32, 0xfbbbcc);
    if (optional != 0) {
        if (optional > std.math.maxInt(u32) - 0x21) return error.Unreadable;
        _ = try read.get(u8, optional + 0x20);
    }
    if (try read.get(u32, 0xfbd8bc) != profile) return error.Unreadable;
    try bindings(read, profile);
}
fn partyBound(read: Read, party: *const [8]u32) Failed!void {
    for (party[0..2]) |actor| {
        if (actor == 0 or actor > std.math.maxInt(u32) - 0x1440) return error.Unreadable;
        try read.range(actor, 0x1440, false);
    }
    if (try read.get(i16, party[0] + 0xdc0) < 0) return error.Unreadable;
    const resource = try read.get(u32, party[0] + 0xf08);
    _ = try read.get(u32, resource);
    const controller = try read.get(u32, party[1] + 0x6cc);
    if (controller == 0 or controller > std.math.maxInt(u32) - 0x60) return error.Unreadable;
    try read.range(controller, 0x60, false);
}
fn scene(ops: ?*const Ops, expected_level: c_int, expected_world: u32) Failed!c_int {
    const read = try Read.init(ops);
    if (expected_level < 0 or expected_world == 0) return error.Unreadable;
    const world = try read.get(u32, 0xfb4a20);
    if (world != expected_world) return error.Unreadable;
    try read.range(world, 0x22e8, false);
    const definition = try read.get(u32, world +% 0x220);
    const catalog = try read.table(0xfb8404, 0xfb8410, 0x1c2, 0x1b0);
    if (expected_level >= catalog.count or definition != catalog.base + @as(u32, @intCast(expected_level)) * 0x1b0) return error.Unreadable;
    const titles = try read.get(u32, 0xfb8414);
    if (titles == 0 or definition == titles) return error.Unreadable;
    try read.range(titles, 0x96, false);
    if (try read.get(i16, definition + 0x94) != expected_level) return error.Unreadable;
    const flags = try read.get(u32, definition + 0x50);
    if (flags & 0x40000000 != 0) return error.Unreadable;
    const pool = try read.get(u32, 0xfb2f60);
    const actor_count = try read.get(u32, 0xfb2e3c);
    if (actor_count > 4096) return error.Unreadable;
    try read.span(pool, actor_count, 0x1440);
    const party = try read.get([8]u32, 0xfb4940);
    var present = false;
    for (party) |actor| present = present or actor != 0;
    var result: c_int = 2;
    if (flags & 2 != 0 or present) {
        if (actor_count == 0) return error.Unreadable;
        try partyBound(read, &party);
        result = 1;
    }
    const checks = [_][2]u32{ .{ 0xfb4a20, world }, .{ world + 0x220, definition }, .{ definition + 0x50, flags }, .{ 0xfb8404, catalog.base }, .{ 0xfb8410, catalog.count }, .{ 0xfb2f60, pool }, .{ 0xfb2e3c, actor_count } };
    for (checks) |check| if (try read.get(u32, check[0]) != check[1]) return error.Unreadable;
    for (party, 0..) |actor, i| if (try read.get(u32, 0xfb4940 + @as(u32, @intCast(i)) * 4) != actor) return error.Unreadable;
    return result;
}
pub export fn native_scene_read(ops: ?*const Ops, address: u32, out: *anyopaque, bytes: usize) c_int {
    const read = Read.init(ops) catch return 0;
    read.bytes(address, out, bytes) catch return 0;
    return 1;
}
pub export fn native_scene_span(ops: ?*const Ops, base: u32, count: u32, stride: u32) c_int {
    const read = Read.init(ops) catch return 0;
    read.span(base, count, stride) catch return 0;
    return 1;
}
pub export fn native_profile_storage_bound(ops: ?*const Ops) c_int {
    profileBound(ops) catch return 0;
    return 1;
}
pub export fn native_scene_input_capability(ops: ?*const Ops, level: c_int, world: u32) c_int {
    return scene(ops, level, world) catch 0;
}
const native_ops: Ops = .{ .context = 0, .read = nativeRead, .range = nativeRange };
fn nativeRead(_: usize, address: u32, out: *anyopaque, length: usize) callconv(.c) c_int {
    @memcpy(@as([*]u8, @ptrCast(out))[0..length], @as([*]const u8, @ptrFromInt(address))[0..length]);
    return 1;
}
fn nativeRange(_: usize, address: u32, bytes: usize, write: c_int) callconv(.c) c_int {
    return @intFromBool(bytes > 0 and win.accessible(address, bytes, write != 0));
}
fn cachedRange(context: usize, address: u32, bytes: usize, write: c_int) callconv(.c) c_int {
    const cache: *win.AccessCache = @ptrFromInt(context);
    return @intFromBool(bytes > 0 and cache.accessible(address, bytes, write != 0));
}
pub export fn game_read_current_level() c_int {
    const area = win.load(usize, 0xfb4a20);
    if (area == 0) return -1;
    const definition = win.load(usize, area + 0x220);
    return if (definition != 0) win.load(i16, definition + 0x94) else -1;
}
pub export fn game_read_native_profile_ready() c_int {
    const player = win.load(usize, 0xfb4940);
    if (player == 0 or win.load(i16, player + 0xdc0) < 0) return 0;
    const resource = win.load(usize, player + 0xf08);
    if (resource == 0) return 0;
    _ = win.load(u32, resource);
    return 1;
}
pub export fn game_read_native_profile_storage_ready() c_int {
    var cache: win.AccessCache = .{};
    const ops: Ops = .{ .context = @intFromPtr(&cache), .read = nativeRead, .range = cachedRange };
    return native_profile_storage_bound(&ops);
}
pub export fn game_read_native_scene_input_capability(level: c_int, world: usize) c_int {
    return native_scene_input_capability(&native_ops, level, @intCast(world));
}
fn currentLevel(_: usize) callconv(.c) c_int {
    return game_read_current_level();
}
fn profileReady(_: usize) callconv(.c) c_int {
    return game_read_native_profile_ready();
}
fn storageReady(_: usize) callconv(.c) c_int {
    return game_read_native_profile_storage_ready();
}
const SceneRequest = struct { level: c_int, world: usize };
fn sceneReady(address: usize) callconv(.c) c_int {
    const r: *const SceneRequest = @ptrFromInt(address);
    return game_read_native_scene_input_capability(r.level, r.world);
}
pub export fn game_current_level() c_int {
    return guard.memory(0, currentLevel, -1);
}
pub export fn game_native_profile_ready() c_int {
    return guard.memory(0, profileReady, 0);
}
pub export fn game_native_profile_storage_ready() c_int {
    return guard.memory(0, storageReady, 0);
}
pub export fn game_native_scene_input_capability(level: c_int, world: usize) c_int {
    const r: SceneRequest = .{ .level = level, .world = world };
    return guard.memory(@intFromPtr(&r), sceneReady, 0);
}
