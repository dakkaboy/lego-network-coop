const std = @import("std");
const win = @import("win32.zig");
const observer = @import("pool_birth.zig");
const check = @import("native_test_support.zig").check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
comptime {
    _ = @import("lexical_seh.zig");
}
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
const Birth = *const fn (usize, u32) callconv(.c) usize;
var current: Birth = undefined;
var pool: [0x1000]u8 align(16) = @splat(0);
var descriptor: [0x1000]u8 align(16) = @splat(0);
var calls: u32 = 0;
var throwing = false;
pub export fn game_sync_epoch() u32 {
    return 7;
}
pub export fn game_sync_sequence() u32 {
    return 8;
}
fn nativeBirth(value: usize, second: u32) callconv(.c) usize {
    check(@src(), win.GetLastError() == 123);
    calls += 1;
    if (throwing) win.RaiseException(0xe1459876, 0, 0, null);
    if (second == 42) {
        _ = current(value, 43);
        win.SetLastError(123);
    }
    win.SetLastError(321);
    return @intFromPtr(&pool) + (second % 3) * 552;
}
fn jump(at: usize, target: usize) void {
    win.store(u8, at, 0xe9);
    win.store(u32, at + 1, @truncate(target -% at -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), at, 5);
}
fn expected(id: u32, parent: u32, second: u32) observer.Record {
    var row = std.mem.zeroes(observer.Record);
    row.committed = id;
    row.id = id;
    row.parent = parent;
    row.thread = win.GetCurrentThreadId();
    row.epoch = 7;
    row.sequence = 8;
    row.clock_before = 31;
    row.clock_after = 31;
    row.rng_game_before = 71;
    row.rng_game_after = 71;
    row.rng_engine_before = 79;
    row.rng_engine_after = 79;
    row.descriptor_local = @intFromPtr(&descriptor);
    row.second_raw = second;
    row.descriptor_valid = 1;
    @memcpy(row.descriptor[0..250], descriptor[0..250]);
    row.pool_before = @intFromPtr(&pool);
    row.pool_after = row.pool_before;
    row.capacity_before = 3;
    row.capacity_after = 3;
    row.cursor_before = 2;
    row.cursor_after = 2;
    row.pool_index_valid = 1;
    row.pool_index = second % 3;
    row.result_local = row.pool_before + row.pool_index * 552;
    row.payload_valid = 1;
    @memcpy(&row.payload, pool[row.pool_index * 552 ..][0..552]);
    return row;
}
fn normalized(rows: *[256]observer.Record) void {
    rows.* = observer.clonewars_pool_birth_records;
    for (rows) |*row| if (row.committed != 0) {
        check(@src(), row.caller != 0 and @as(i64, @bitCast(row.qpc_after)) >= @as(i64, @bitCast(row.qpc_before)));
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(row.caller, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection & 0xf0 != 0);
        row.caller = 0;
        row.qpc_before = @splat(0);
        row.qpc_after = @splat(0);
    };
}
fn throwBody(_: usize) callconv(.c) c_int {
    win.SetLastError(123);
    _ = current(@intFromPtr(&descriptor), 1);
    return 1;
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) < 0x741f90 and @intFromPtr(&owned_image) + owned_image.len > 0xfb4b70);
    for (0..250) |i| descriptor[i] = @intCast(i);
    for (0..1656) |i| pool[i] = @truncate(i);
    win.store(usize, 0xfa3d38, @intFromPtr(&pool));
    win.store(u32, 0xe5f480, 3);
    win.store(u32, 0xe5f488, 2);
    win.store(u32, 0xfb4b6c, 31);
    win.store(u32, 0xe637b4, 71);
    win.store(u32, 0xea178c, 79);
    const prefix = "\x6a\xff\x68\x76\xcf\xaa\x00";
    var old: u32 = 0;
    for (0..prefix.len) |i| {
        check(@src(), win.VirtualProtect(0x741f90, 32, 0x40, &old) != 0);
        @memcpy(@as([*]u8, @ptrFromInt(0x741f90))[0..7], prefix);
        win.store(u8, 0x741f90 + i, prefix[i] ^ 1);
        check(@src(), win.VirtualProtect(0x741f90, 32, 0x20, &old) != 0);
        check(@src(), observer.pool_birth_observer_install() == 0 and observer.clonewars_pool_birth_installed == -1 and win.load(u8, 0x741f90 + i) == prefix[i] ^ 1);
    }
    check(@src(), win.VirtualProtect(0x741f90, 32, 0x40, &old) != 0);
    @memcpy(@as([*]u8, @ptrFromInt(0x741f90))[0..7], prefix);
    win.store([3]u8, 0x741f97, .{ 0x83, 0xc4, 8 });
    jump(0x741f9a, @intFromPtr(&nativeBirth));
    check(@src(), win.VirtualProtect(0x741f90, 32, 0x20, &old) != 0);
    check(@src(), observer.pool_birth_observer_install() == 1 and observer.clonewars_pool_birth_installed == 1);
    current = @ptrFromInt(0x741f95 +% win.load(u32, 0x741f91));
    for (0..4) |mode| {
        const count: u32 = if (mode == 3) 300 else 1;
        const second: u32 = if (mode == 2) 42 else 1;
        const enabled = mode != 0;
        observer.clonewars_pool_birth_count = 0;
        observer.clonewars_pool_birth_enabled = @intFromBool(enabled);
        observer.clonewars_pool_birth_records = std.mem.zeroes([256]observer.Record);
        calls = 0;
        var expected_rows = std.mem.zeroes([256]observer.Record);
        for (0..count) |i| {
            win.SetLastError(123);
            check(@src(), current(@intFromPtr(&descriptor), second) == @intFromPtr(&pool) + (second % 3) * 552 and win.GetLastError() == 321);
            if (enabled) {
                const id: u32 = @intCast(i * (if (second == 42) @as(usize, 2) else 1) + 1);
                expected_rows[(id - 1) % 256] = expected(id, 0, second);
                if (second == 42) expected_rows[id % 256] = expected(id + 1, id, 43);
            }
        }
        check(@src(), calls == count * (if (second == 42) @as(u32, 2) else 1) and observer.clonewars_pool_birth_count == @as(u32, if (enabled) calls else 0));
        var rows: [256]observer.Record = undefined;
        normalized(&rows);
        check(@src(), std.mem.eql(u8, std.mem.asBytes(&rows), std.mem.asBytes(&expected_rows)));
    }
    observer.clonewars_pool_birth_count = 0;
    observer.clonewars_pool_birth_enabled = 1;
    observer.clonewars_pool_birth_records = std.mem.zeroes([256]observer.Record);
    throwing = true;
    check(@src(), @import("native_test_support.zig").exceptionCode(0, throwBody) == 0xe1459876);
    throwing = false;
    win.SetLastError(123);
    _ = current(@intFromPtr(&descriptor), 1);
    check(@src(), observer.clonewars_pool_birth_count == 2 and observer.clonewars_pool_birth_records[0].committed == 0 and observer.clonewars_pool_birth_records[1].parent == 0 and observer.clonewars_pool_birth_records[1].committed == 2);
}
