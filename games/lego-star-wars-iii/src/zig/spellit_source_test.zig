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
    const support = @import("scene_support.zig");
    setup();
    put(body + 0x28, receiver);
    win.store(u8, body + 0x19, 0x46);
    var support_key: [2]u32 = undefined;
    win.SetLastError(0xdeadbeef);
    check(@src(), support.native_scene_support_source(body, &support_key) == 1);
    check(@src(), support.native_scene_support_resolve(support_key[0], support_key[1]) == body and win.GetLastError() == 0xdeadbeef);
    put(receiver + 0x1a0, body + 0x100);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(receiver + 0x1a0, body);
    put(poi + 0xd4, 0);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0 and support.native_scene_support_resolve(support_key[0], support_key[1]) == 0);
    put(poi + 0xd4, receiver);
    put(registry + 8, 0);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(registry + 8, entry);
    put(body + 0x28, 0);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(body + 0x28, receiver);
    win.store(u8, body + 0x19, 0x20);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    setup();
    put(classes, 0x74ecb0);
    put(container + 0x3c, scene);
    zero(scene, 0x48);
    put(scene + 0x3c, scene + 8);
    put(scene + 0x40, scene + 0x10);
    put(scene + 0x30, receiver);
    put(scene + 0x34, receiver);
    put(scene + 0x44, 1);
    put(receiver + 0x28, scene + 0x10);
    put(receiver + 0x24, scene + 8);
    put(receiver + 0x18, 0);
    put(body + 0x28, receiver);
    put(body + 0x98, 0);
    win.store(u8, body + 0x19, 0x20);
    check(@src(), support.native_scene_support_source(body, &support_key) == 1);
    check(@src(), support.native_scene_support_resolve(support_key[0], support_key[1]) == body);
    put(receiver + 0x28, 0);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(receiver + 0x28, scene + 0x10);
    put(scene + 0x44, 2);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(scene + 0x44, 1);
    put(body + 0x14, receiver);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(body + 0x14, 0);
    put(body + 0x98, dynamics);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(body + 0x98, 0);
    put(entry + 0x54, 0);
    check(@src(), support.native_scene_support_source(body, &support_key) == 0);
    put(entry + 0x54, container);
    const second_receiver = receiver + 0x300;
    const second_body = body + 0x200;
    @memcpy(@as([*]u8, @ptrFromInt(second_receiver))[0..0x1a4], @as([*]const u8, @ptrFromInt(receiver))[0..0x1a4]);
    @memcpy(@as([*]u8, @ptrFromInt(second_body))[0..0xa0], @as([*]const u8, @ptrFromInt(body))[0..0xa0]);
    put(second_receiver + 0x1a0, second_body);
    put(second_body + 0x28, second_receiver);
    put(receiver + 0x24, second_receiver);
    put(second_receiver + 0x28, receiver);
    put(scene + 0x30, second_receiver);
    put(scene + 0x44, 2);
    check(@src(), support.native_scene_support_resolve(support_key[0], support_key[1]) == 0);
    const level = @import("level_support.zig");
    put(entry + 0x4c, 0);
    bytes(filename, "levels/library/temp.led\x00");
    put(receiver + 0xc, counted);
    put(second_receiver + 0xc, counted);
    win.store(u8, body + 0x19, 0x4f);
    win.store(u8, second_body + 0x19, 0x4f);
    put(dynamics + 0x200, classes + 64);
    put(dynamics + 0x300, classes + 80);
    put(body + 0x24, dynamics + 0x200);
    put(second_body + 0x24, dynamics + 0x200);
    put(receiver + 0x24, scene + 8);
    put(scene + 0x30, receiver);
    put(scene + 0x44, 1);
    check(@src(), level.source(body, &support_key));
    check(@src(), level.resolve(support_key[0], support_key[1]) == body);
    check(@src(), support.native_scene_support_source(body, &support_key) == 1 and support.native_scene_support_resolve(support_key[0], support_key[1]) == body);
    put(receiver + 0x28, 0);
    check(@src(), !level.source(body, &support_key));
    put(receiver + 0x28, scene + 0x10);
    bytes(filename, "levels/library/temp.gsc\x00");
    check(@src(), !level.source(body, &support_key));
    bytes(filename, "levels/library/temp.led\x00");
    put(entry + 0x54, 0);
    check(@src(), !level.source(body, &support_key));
    put(entry + 0x54, container);
    put(receiver + 0x24, second_receiver);
    put(scene + 0x30, second_receiver);
    put(scene + 0x44, 2);
    check(@src(), !level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == 0);
    const origins = @import("zillo_support_origin.zig");
    var first: origins.Origin = .{ .clock = 268, .actor_slot = 3, .generation = 28, .throw_slot = 0, .model = 5 };
    origins.remember(world, receiver, body, first);
    origins.remember(world, second_receiver, second_body, first);
    check(@src(), !level.source(body, &support_key));
    origins.forget(second_body);
    first.throw_slot = 1;
    origins.remember(world, second_receiver, second_body, first);
    var second_key: [2]u32 = undefined;
    check(@src(), level.source(body, &support_key) and level.source(second_body, &second_key));
    check(@src(), !std.mem.eql(u32, &support_key, &second_key) and level.resolve(support_key[0], support_key[1]) == body and level.resolve(second_key[0], second_key[1]) == second_body);
    origins.forget(body);
    check(@src(), level.resolve(support_key[0], support_key[1]) == 0 and !level.source(body, &support_key));
    origins.reset();
    origins.remember(world, receiver, body, first);
    first.throw_slot = 0;
    origins.remember(world, second_receiver, second_body, first);
    check(@src(), level.resolve(support_key[0], support_key[1]) == second_body and level.resolve(second_key[0], second_key[1]) == body);
    origins.remember(world, receiver, body, first);
    check(@src(), !level.source(body, &support_key) and !level.source(second_body, &second_key));
    origins.reset();
    check(@src(), !level.source(body, &support_key) and level.resolve(second_key[0], second_key[1]) == 0);
    put(second_body + 0x24, dynamics + 0x300);
    check(@src(), level.source(body, &support_key));
    check(@src(), level.resolve(support_key[0], support_key[1]) == body);
    put(body + 0x24, 0);
    check(@src(), !level.source(body, &support_key));
    put(body + 0x24, dynamics + 0x200);
    const shape = dynamics + 0x200;
    const second_shape = dynamics + 0x300;
    put(shape, win.GetModuleHandleA(null) + 0x8699f4);
    put(second_shape, win.GetModuleHandleA(null) + 0x8699f4);
    win.store(f32, shape + 0x14, 0.057075974);
    win.store(f32, second_shape + 0x14, 0.08712775);
    win.store(f32, shape + 0x24, -0.05885332);
    win.store(f32, shape + 0x34, 0.05885332);
    win.store(f32, second_shape + 0x24, -0.11103822);
    win.store(f32, second_shape + 0x34, 0.11103822);
    check(@src(), level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == body);
    const original_key = support_key;
    put(shape + 0x18, 0xffffffff);
    put(shape + 0x1c, 0xdeadbeef);
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &support_key, &original_key));
    @memcpy(@as([*]u8, @ptrFromInt(second_shape))[0..0x40], @as([*]const u8, @ptrFromInt(shape))[0..0x40]);
    check(@src(), !level.source(body, &support_key) and level.resolve(original_key[0], original_key[1]) == 0);
    win.store(f32, shape + 0x14, std.math.nan(f32));
    check(@src(), !level.source(body, &support_key));
    put(shape, win.GetModuleHandleA(null) + 0x8697ec);
    put(second_shape, win.GetModuleHandleA(null) + 0x8697ec);
    win.store([4]f32, shape + 0x20, .{ 0.04805127, 0.07251928, 0.017623657, 0.01 });
    win.store([4]f32, second_shape + 0x20, .{ 0.07628959, 0.09733785, 0.03570272, 0.01 });
    check(@src(), level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == body);
    const box_key = support_key;
    win.store([4]f32, shape + 0x30, .{ 90, 91, 92, std.math.nan(f32) });
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &support_key, &box_key));
    win.store(f32, shape + 0x20, -0.01);
    check(@src(), !level.source(body, &support_key));

    bytes(filename, "ZilloBeast_B_temp.led\x00");
    bytes(body_name, "plate_grey_solid\x00");
    bytes(counted, &.{ 7, '#', '3', '4', '0', '4', 0 });
    put(receiver, 0xc20f64);
    put(second_receiver, 0xc20f64);
    put(body, 0xc69eac);
    put(second_body, 0xc69eac);
    put(shape, 0xc69b0c);
    put(second_shape, 0xc69b0c);
    win.store(u8, body + 0x19, 0x20);
    win.store(u8, second_body + 0x19, 0x20);
    const plate: [16]f32 = @bitCast([16]u32{ 1060439284, 0, 3207922932, 0, 0, 1065353217, 0, 0, 1060439284, 2147483648, 1060439284, 0, 1100342237, 3178253464, 1090758888, 1065353216 });
    win.store([16]f32, body + 0x40, plate);
    win.store([16]f32, second_body + 0x40, plate);
    put(receiver + 0x24, scene + 8);
    put(scene + 0x30, receiver);
    put(scene + 0x44, 1);
    check(@src(), level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == body);
    check(@src(), support.native_scene_support_source(body, &support_key) == 1 and support.native_scene_support_resolve(support_key[0], support_key[1]) == body);
    const plate_key = support_key;
    bytes(counted, &.{ 7, '#', '2', '6', '4', '2', 0 });
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &plate_key, &support_key));
    bytes(counted, &.{ 7, '#', '2', '6', 'X', '2', 0 });
    check(@src(), !level.source(body, &support_key));
    bytes(counted, &.{ 7, '#', '2', '6', '4', '2', 0 });
    put(body + 0x98, dynamics);
    check(@src(), !level.source(body, &support_key));
    put(body + 0x98, 0);
    win.store(f32, body + 0x48, std.math.nan(f32));
    check(@src(), !level.source(body, &support_key));
    win.store([16]f32, body + 0x40, plate);
    put(receiver + 0x24, second_receiver);
    bytes(counted + 32, &.{ 7, '#', '3', '4', '0', '4', 0 });
    put(second_receiver + 0xc, counted + 32);
    put(scene + 0x30, second_receiver);
    put(scene + 0x44, 2);
    check(@src(), !level.source(body, &support_key) and level.resolve(plate_key[0], plate_key[1]) == 0);
    put(scene + 0x34, second_receiver);
    put(second_receiver + 0x28, scene + 0x10);
    put(scene + 0x44, 1);
    check(@src(), level.resolve(plate_key[0], plate_key[1]) == second_body);

    bytes(filename, "GunganGeneral_A_temp.led\x00");
    var gungan_plate = plate;
    gungan_plate[12..15].* = .{ 20, -0.01889521, 4.17 };
    win.store([16]f32, second_body + 0x40, gungan_plate);
    check(@src(), support.native_scene_support_source(second_body, &support_key) == 1);
    const gungan_key = support_key;
    check(@src(), support.native_scene_support_resolve(gungan_key[0], gungan_key[1]) == second_body);
    bytes(counted + 32, &.{ 6, '#', '6', '9', '1', 0 });
    check(@src(), level.source(second_body, &support_key) and std.mem.eql(u32, &gungan_key, &support_key));
    win.store(f32, second_body + 0x78, -15.83);
    check(@src(), level.source(second_body, &support_key) and !std.mem.eql(u32, &gungan_key, &support_key));
    check(@src(), level.resolve(gungan_key[0], gungan_key[1]) == 0);
    bytes(filename, "ZilloBeast_B_temp.led\x00");
    win.store([16]f32, second_body + 0x40, plate);

    bytes(body_name, "Rock1P1\x00");
    put(scene + 0x34, receiver);
    put(scene + 0x30, receiver);
    put(receiver + 0x24, scene + 8);
    put(receiver + 0x18, 0);
    put(second_receiver + 0x18, 0);
    put(shape, 0xc69b7c);
    const vertices = dynamics + 0x500;
    const faces = dynamics + 0x600;
    const indices = dynamics + 0x700;
    put(shape + 0x44, vertices);
    put(shape + 0x48, faces);
    put(shape + 0x4c, indices);
    win.store([3]u16, shape + 0x60, .{ 4, 4, 12 });
    win.store([8]f32, shape + 0x20, .{ 1, 1, 1, 1, 0.25, 0.25, 0.25, 1 });
    win.store([16]f32, vertices, .{ 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0 });
    win.store([8]u16, faces, .{ 3, 0, 3, 3, 3, 6, 3, 9 });
    win.store([12]u16, indices, .{ 0, 1, 2, 0, 1, 3, 0, 2, 3, 1, 2, 3 });
    check(@src(), level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == body);
    const rock_key = support_key;
    bytes(counted, &.{ 7, '#', '8', '5', '5', '1', 0 });
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &rock_key, &support_key));
    win.store(u16, indices + 2, 4);
    check(@src(), !level.source(body, &support_key) and level.resolve(rock_key[0], rock_key[1]) == 0);
    win.store(u16, indices + 2, 1);
    win.store(f32, vertices + 16, 1.25);
    check(@src(), level.source(body, &support_key) and !std.mem.eql(u32, &rock_key, &support_key));
    win.store(f32, vertices + 16, 1);
    put(second_body + 0x24, shape);
    put(receiver + 0x24, second_receiver);
    put(second_receiver + 0x28, receiver);
    put(scene + 0x30, second_receiver);
    put(scene + 0x44, 2);
    check(@src(), !level.source(body, &support_key) and level.resolve(rock_key[0], rock_key[1]) == 0);

    put(receiver + 0x24, scene + 8);
    put(scene + 0x30, receiver);
    put(scene + 0x44, 1);
    put(receiver + 0x18, model);
    put(model, 0xc50344);
    put(model + 0x3c, receiver);
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &rock_key, &support_key));
    put(model + 0x3c, second_receiver);
    check(@src(), !level.source(body, &support_key) and level.resolve(rock_key[0], rock_key[1]) == 0);
    put(model + 0x3c, receiver);

    bytes(body_name, "Rock2P2\x00");
    check(@src(), level.source(body, &support_key) and !std.mem.eql(u32, &rock_key, &support_key));
    const rock2_key = support_key;
    check(@src(), level.resolve(rock2_key[0], rock2_key[1]) == body);
    put(model, 0xc20f64);
    check(@src(), !level.source(body, &support_key) and level.resolve(rock2_key[0], rock2_key[1]) == 0);
    put(model, 0xc50344);
    put(receiver + 0x18, 0);
    check(@src(), !level.source(body, &support_key));

    bytes(body_name, "TNTSwitch_Base\x00");
    check(@src(), !level.source(body, &support_key));
    put(receiver + 0x18, model);
    check(@src(), level.source(body, &support_key) and level.resolve(support_key[0], support_key[1]) == body);
    const switch_key = support_key;
    put(model + 0x3c, second_receiver);
    check(@src(), !level.source(body, &support_key) and level.resolve(switch_key[0], switch_key[1]) == 0);

    bytes(filename, "BlueShadowVirus_C_temp.led\x00");
    bytes(body_name, "Black_Box\x00");
    put(shape, 0xc695d4);
    put(body, 0xc69eac);
    put(receiver, 0xc20f64);
    win.store(u8, body + 0x19, 0x46);
    win.store(f32, receiver + 0x70, 0.70104);
    win.store(f32, receiver + 0x78, 4.51104);
    bytes(counted, &.{ 7, '#', '1', '1', '5', '2', 0 });
    check(@src(), level.source(body, &support_key));
    const corridor_key = support_key;
    bytes(counted, &.{ 7, '#', '1', '1', '5', '3', 0 });
    check(@src(), level.source(body, &support_key) and std.mem.eql(u32, &corridor_key, &support_key));
    check(@src(), level.resolve(corridor_key[0], corridor_key[1]) == body);
    win.store(f32, receiver + 0x78, 9.21258);
    check(@src(), level.source(body, &support_key) and !std.mem.eql(u32, &corridor_key, &support_key));
}
