const std = @import("std");
const a = @import("authored_poi.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
const table_a = [_]u32{ 0x13572468, 0xabcdef01 };
const table_b = [_]u32{ 0x24681357, 0x10fedcba };
var arena: usize = 0;
var resource: usize = 0;
var runtime: usize = 0;
var array: usize = 0;
fn put(base: usize, offset: usize, value: usize) void {
    win.store(usize, base + offset, value);
}
fn model(index: usize) usize {
    return arena + index * 0x1000;
}
fn receiver(index: usize) usize {
    return arena + 0x20000 + index * 0x1000;
}
fn setup(depth: usize) void {
    @memset(@as([*]u8, @ptrFromInt(arena))[0..0x60000], 0);
    resource = arena + 0x40000;
    runtime = arena + 0x41000;
    array = arena + 0x42000;
    put(resource, 0x6f8, runtime);
    put(runtime, 0x68, 129);
    put(runtime, 0x6c, array);
    const poi = array + 33 * 0xe0;
    for (0..depth) |i| {
        put(model(i), 0x3c, receiver(i));
        put(model(i), 0x48, if (i + 1 < depth) model(i + 1) else 0);
        win.store(u16, model(i) + 0x5a, if (i + 1 < depth) 0x1567 else 0x1562);
        put(receiver(i), 0, @intFromPtr(&table_a));
        put(receiver(i), 0x18, model(i));
        put(receiver(i), 0x2c, resource);
        put(receiver(i), 0x30, poi);
    }
    put(poi, 0xd4, receiver(depth - 1));
}
fn unchangedFailure(input: usize) void {
    var result: a.Source = undefined;
    @memset(std.mem.asBytes(&result), 0xa5);
    const previous = result;
    win.SetLastError(0x1974);
    check(@src(), a.native_authored_poi_resolve(input, &result) == 0 and win.GetLastError() == 0x1974);
    check(@src(), std.mem.eql(u8, std.mem.asBytes(&result), std.mem.asBytes(&previous)));
}
fn success(depth: usize) void {
    var result: a.Source = undefined;
    win.SetLastError(0x1965);
    check(@src(), a.native_authored_poi_resolve(model(0), &result) != 0 and win.GetLastError() == 0x1965);
    check(@src(), result.model == model(0) and result.receiver == receiver(0) and result.authored_model == model(depth - 1) and result.authored_receiver == receiver(depth - 1));
    check(@src(), result.chain_count == depth and result.poi_count == 129 and result.poi_ordinal == 33 and result.resource == resource and result.runtime == runtime and result.array == array);
    check(@src(), result.poi == array + 33 * 0xe0 and result.receiver_class == @intFromPtr(&table_a) - win.GetModuleHandleA(null));
    check(@src(), a.native_authored_poi_revalidate(&result) != 0 and win.GetLastError() == 0x1965);
    for (0..depth) |i| check(@src(), result.chain[i].model == model(i) and result.chain[i].receiver == receiver(i));
}
pub fn main() void {
    arena = win.VirtualAlloc(0, 0x60000, 0x3000, 4);
    check(@src(), arena != 0);
    defer _ = win.VirtualFree(arena, 0, 0x8000);
    for (1..17) |depth| {
        setup(depth);
        success(depth);
    }
    setup(17);
    unchangedFailure(model(0));
    for (0..14) |mutation| {
        setup(if (mutation >= 7 and mutation <= 10) 2 else if (mutation == 11 or mutation == 12) 3 else 1);
        switch (mutation) {
            0 => put(runtime, 0x68, 0),
            1 => put(runtime, 0x68, 65537),
            2 => put(runtime, 0x6c, 0),
            3 => put(receiver(0), 0x30, array - 0xe0),
            4 => put(receiver(0), 0x30, array + 129 * 0xe0),
            5 => put(receiver(0), 0x30, array + 33 * 0xe0 + 1),
            6 => put(array + 33 * 0xe0, 0xd4, 0),
            7 => win.store(u16, model(0) + 0x5a, 0x1566),
            8 => put(receiver(0), 0x18, model(1)),
            9 => put(model(0), 0x48, 0),
            10 => put(model(0), 0x48, model(0)),
            11 => put(model(1), 0x3c, receiver(0)),
            12 => put(model(1), 0x48, model(0)),
            13 => put(receiver(0), 0, arena + 0x50000),
            else => unreachable,
        }
        unchangedFailure(model(0));
    }
    unchangedFailure(0);
    unchangedFailure(1);
    check(@src(), a.native_authored_poi_resolve(model(0), null) == 0 and a.native_authored_poi_revalidate(null) == 0);
    for (0..17) |mutation| {
        setup(3);
        var before: a.Source = undefined;
        check(@src(), a.native_authored_poi_resolve(model(0), &before) != 0);
        switch (mutation) {
            0 => put(model(0), 0x3c, receiver(2)),
            1 => put(model(0), 0x48, model(2)),
            2 => win.store(u16, model(0) + 0x5a, 0x1566),
            3 => put(receiver(0), 0x18, model(2)),
            4 => put(receiver(0), 0, @intFromPtr(&table_b)),
            5 => put(receiver(0), 0x2c, resource + 4),
            6 => put(receiver(0), 0x30, array + 34 * 0xe0),
            7 => put(resource, 0x6f8, runtime + 4),
            8 => put(runtime, 0x6c, array + 0xe0),
            9 => put(runtime, 0x68, 128),
            10 => put(array + 33 * 0xe0, 0xd4, receiver(0)),
            11 => put(receiver(2), 0, @intFromPtr(&table_b)),
            12 => put(model(2), 0x3c, receiver(1)),
            13 => put(model(2), 0x48, model(0)),
            14 => win.store(u16, model(2) + 0x5a, 0x1563),
            15 => before.poi_ordinal = 34,
            16 => before.chain_count = 17,
            else => unreachable,
        }
        win.SetLastError(0x1981);
        check(@src(), a.native_authored_poi_revalidate(&before) == 0 and win.GetLastError() == 0x1981);
    }
    setup(2);
    var reused: a.Source = undefined;
    check(@src(), a.native_authored_poi_resolve(model(0), &reused) != 0);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(model(0), 0x1000, 1, &old) != 0 and a.native_authored_poi_revalidate(&reused) == 0);
    check(@src(), win.VirtualProtect(model(0), 0x1000, 4, &old) != 0);
    @memset(@as([*]u8, @ptrFromInt(model(0)))[0..0x1000], 0);
    check(@src(), a.native_authored_poi_revalidate(&reused) == 0);
    setup(2);
    put(receiver(0), 0x2c, 0);
    success(2);
    for (0..2000) |iteration| {
        const depth = 1 + iteration % 16;
        setup(depth);
        success(depth);
        var before: a.Source = undefined;
        check(@src(), a.native_authored_poi_resolve(model(0), &before) != 0);
        put(runtime, 0x6c, array + 0xe0);
        check(@src(), a.native_authored_poi_revalidate(&before) == 0);
    }
}
