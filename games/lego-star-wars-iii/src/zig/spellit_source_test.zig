const std = @import("std");
const source = @import("spellit_source.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
comptime {
    _ = @import("spellit_identity.zig");
}
const world = 0x20000000;
const container = 0x20010000;
const provider = 0x20020000;
const manager_registry = 0x20030000;
const manager = 0x20040000;
const gizmo = 0x20050000;
const scene = 0x20060000;
const piece = 0x20070000;
const entity = 0x20080000;
const model = 0x20090000;
const receiver = 0x200a0000;
const resource = 0x200b0000;
const runtime = 0x200c0000;
const poi = 0x200d0000;
const registry = 0x200e0000;
const entry = 0x200f0000;
const body = 0x20100000;
const dynamics = 0x20110000;
const table = 0x20120000;
const adapter = 0x20130000;
const file_table = 0x20140000;
const handle = 0x20150000;
const filename = 0x20160000;
const logical_name = 0x20170000;
const poi_name = 0x20180000;
const body_name = 0x20190000;
const counted = 0x201a0000;
const classes = 0xb10000;
var checksum: u32 = 0;
fn put(address: usize, value: usize) void {
    win.store(usize, address, value);
}
fn bytes(address: usize, value: []const u8) void {
    @memcpy(@as([*]u8, @ptrFromInt(address))[0..value.len], value);
}
fn zero(address: usize, size: usize) void {
    @memset(@as([*]u8, @ptrFromInt(address))[0..size], 0);
}
fn emit(value: anytype) void {
    for (std.mem.asBytes(&value)) |byte| checksum = (checksum ^ byte) *% 16777619;
}
fn capture(comptime T: type, function: anytype, args: anytype, output: *T) c_int {
    @memset(std.mem.asBytes(output), 0xa5);
    win.SetLastError(0xdeadbeef);
    const result = @call(.auto, function, args ++ .{output});
    check(@src(), win.GetLastError() == 0xdeadbeef);
    emit(result);
    emit(output.*);
    return result;
}
fn setup() void {
    zero(world, 0x2300);
    zero(gizmo, 0x230);
    zero(piece, 0x120);
    zero(model, 0x60);
    zero(receiver, 0x1a4);
    zero(resource, 0x738);
    zero(registry, 8 + 199 * 4);
    zero(entry, 0x58);
    zero(runtime, 0x70);
    zero(poi, 0xe0);
    zero(body, 0xa0);
    zero(dynamics, 0x50);
    bytes(world + 0x81, "Area\x00");
    bytes(gizmo + 0x30, "SpellIt\x00");
    put(0xfb4a20, world);
    put(0xe90220, provider);
    put(0xe90184, manager_registry);
    put(world + 0x22e4, container);
    put(container, classes);
    put(container + 0xc, world);
    put(world + 0x400, handle);
    put(handle, table);
    put(table, manager);
    put(provider + 0x38, 0);
    put(manager_registry + 0x28, 1);
    put(manager, classes + 16);
    put(manager + 0x24, gizmo);
    put(gizmo, 0xc480ac);
    put(gizmo + 0xc, counted);
    put(0xc480ac + 0xf4, 0x823340);
    put(0xc480ac + 0x13c, 0x823350);
    put(gizmo + 0xb4, scene);
    put(gizmo + 0xa8, piece);
    put(gizmo + 0xac, piece);
    put(gizmo + 0xb0, 1);
    put(gizmo + 0x84, adapter);
    put(gizmo + 0x88, 1);
    put(piece + 0xfc, gizmo);
    put(piece + 0xf0, entity);
    put(piece + 0x100, model);
    put(piece + 8, entity);
    put(entity + 8, model);
    put(scene + 0x2c, entity);
    put(adapter, entity);
    put(adapter + 4, model);
    put(model + 0x3c, receiver);
    win.store(u16, model + 0x5a, 0x200);
    put(receiver, classes + 32);
    put(receiver + 0x18, model);
    put(receiver + 0x2c, resource);
    put(receiver + 0x30, poi);
    put(resource + 0x6f8, runtime);
    put(runtime + 0x68, 1);
    put(runtime + 0x6c, poi);
    put(poi + 0xd4, receiver);
    put(poi + 0xb4, poi_name);
    put(0xf9dd10, registry);
    put(registry + 8, entry);
    put(entry, file_table);
    put(file_table + 4, 0x45cf20);
    put(entry + 0x34, filename);
    put(entry + 0x40, logical_name);
    put(entry + 0x4c, resource);
    put(entry + 0x54, container);
    put(receiver + 0x1a0, body);
    put(body, classes + 48);
    put(body + 0x98, dynamics);
    put(body + 0x1c, body_name);
}
pub fn main() void {
    check(@src(), win.GetModuleHandleA(null) == 0x400000 and @intFromPtr(&image) < 0xc480ac and @intFromPtr(&image) + image.len > 0xfbd8c0);
    check(@src(), win.VirtualAlloc(world, 0x1b0000, 0x3000, 4) == world);
    defer _ = win.VirtualFree(world, 0, 0x8000);
    bytes(filename, "levels/library/source.gsc\x00");
    bytes(logical_name, "Source\x00");
    bytes(poi_name, "Point\x00");
    bytes(body_name, "Physical\x00");
    bytes(counted, &.{ 5, 'P', 'a', 'd', 0 });
    const expected = [_]u32{ 1150066443, 3160548143, 3160548143, 3160548143, 1106791625, 1106791625, 3520989849, 1241217360, 1241217360, 1241217360, 1241217360, 1241217360, 1241217360, 1241217360, 1241217360, 3993968359, 624238586, 2253614050, 1043635628, 3465522020, 146033753, 3986414723, 1737958362, 2610070487, 2455454040, 1241217360, 1285392639, 3139121455 };
    for (expected, 0..) |hash, mutation| {
        checksum = 2166136261;
        setup();
        var original: source.Source = undefined;
        var original_piece: source.Piece = undefined;
        var original_body: source.Body = undefined;
        check(@src(), capture(source.Source, source.native_spellit_source_resolve, .{gizmo}, &original) == 1);
        check(@src(), capture(source.Piece, source.native_spellit_piece_resolve, .{ &original, piece }, &original_piece) == 1);
        check(@src(), capture(source.Body, source.native_spellit_body_resolve, .{ &original, piece }, &original_body) == 1);
        switch (mutation) {
            1 => put(gizmo + 0x24, gizmo),
            2 => put(gizmo + 0xb0, 2),
            3 => put(gizmo + 0x88, 0),
            4 => put(piece, piece),
            5 => put(piece + 4, piece),
            6 => put(piece + 0xfc, model),
            7 => put(entity + 8, gizmo),
            8 => put(adapter + 4, 0),
            9 => put(scene + 0x2c, model),
            10 => put(poi + 0xd4, model),
            11 => put(runtime + 0x6c, model),
            12 => put(runtime + 0x68, 0),
            13 => put(resource + 0x6f8, model),
            14 => put(entry + 0x54, model),
            15 => put(gizmo + 0xc, 0),
            16 => win.store(u8, gizmo + 0x30, 'X'),
            17 => put(piece + 0x110, 3),
            18 => put(body + 0x98, 0),
            19 => put(receiver + 0x1a0, std.math.maxInt(usize)),
            20 => win.store(u16, model + 0x5a, 0),
            21 => put(body + 0x1c, filename),
            22 => put(body, classes),
            23 => put(poi + 0xb4, logical_name),
            24 => win.store(u8, world + 0x81, 'B'),
            25 => put(piece + 0xf0, model),
            26 => put(gizmo + 0xa8, 0),
            27 => put(gizmo + 0xac, 0),
            else => {},
        }
        var fresh: source.Source = undefined;
        _ = capture(source.Source, source.native_spellit_source_resolve, .{gizmo}, &fresh);
        emit(source.native_spellit_source_revalidate(&original));
        var fresh_piece: source.Piece = undefined;
        _ = capture(source.Piece, source.native_spellit_piece_resolve, .{ &original, piece }, &fresh_piece);
        emit(source.native_spellit_piece_revalidate(&original, &original_piece));
        var fresh_body: source.Body = undefined;
        _ = capture(source.Body, source.native_spellit_body_resolve, .{ &original, piece }, &fresh_body);
        emit(source.native_spellit_body_matches(&original, &original_body));
        var state: source.State = undefined;
        _ = capture(source.State, source.native_spellit_body_read, .{ &original, &original_body }, &state);
        var count: u32 = 99;
        var key: [4]u32 = @splat(0);
        emit(source.native_spellit_selection_snapshot(&original, &count, &key));
        emit(count);
        emit(key);
        if (checksum != hash) std.debug.print("spellit source mutation={d} hash={d} expected={d}\n", .{ mutation, checksum, hash });
        check(@src(), checksum == hash);
    }
}
