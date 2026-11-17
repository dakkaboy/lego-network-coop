const std = @import("std");
const win = @import("win32.zig");
const owner = @import("collision_owner.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x400000]u8 linksection(".text") = @splat(0);
const Resolve = *const fn (usize) callconv(.c) usize;
const Kind = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) u32;
const body: usize = 0x20000000;
const object: usize = 0x20010000;
const table: usize = 0x20020000;
var calls: u32 = 0;

fn kind(value: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), value == object);
    return 6;
}
fn native(value: usize) callconv(.c) usize {
    calls += 1;
    if (value == 0) return 0;
    const linked = win.load(usize, value + 0x30);
    if (linked == 0) return 0;
    const vtable = win.load(usize, linked);
    const method: Kind = @ptrFromInt(win.load(usize, vtable + 0x2c));
    return if (method(linked) == 6) win.load(usize, linked + 0x10) else 0;
}
fn invoke(value: usize) callconv(.c) c_int {
    _ = @as(Resolve, @ptrFromInt(0x42bee0))(value);
    return 1;
}

pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0x42bee0 and @intFromPtr(&image) + image.len > 0x42bef0);
    for ([_]usize{ body, object, table }) |address| check(@src(), win.VirtualAlloc(address, 0x1000, 0x3000, 4) == address);
    defer for ([_]usize{ body, object, table }) |address| {
        _ = win.VirtualFree(address, 0, 0x8000);
    };
    var protection: u32 = 0;
    check(@src(), win.VirtualProtect(0x420000, 0x10000, 0x40, &protection) != 0);
    const entry: [*]u8 = @ptrFromInt(0x42bee0);
    @memcpy(entry[0..9], "\x8b\x44\x24\x04\x56\x85\xc0\x5e\xe9");
    win.store(u32, 0x42bee9, @truncate(@intFromPtr(&native) -% 0x42beed));
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x42bee0, 13) != 0);
    win.store(usize, body + 0x30, object);
    check(@src(), support.exceptionCode(body, invoke) == 0xc0000005);
    const before = calls;
    check(@src(), owner.install() and owner.install());
    const resolve: Resolve = @ptrFromInt(0x42bee0);
    win.SetLastError(739);
    check(@src(), resolve(body) == 0 and win.GetLastError() == 739 and calls == before);
    check(@src(), std.mem.eql(u32, &owner.clonewars_collision_owner_rejected, &.{ body, object, 0, 0 }));
    check(@src(), win.load(usize, body + 0x30) == object and win.load(usize, object) == 0);
    check(@src(), resolve(0) == 0 and calls == before + 1);
    win.store(usize, body + 0x30, 0);
    check(@src(), resolve(body) == 0 and calls == before + 2);
    win.store(usize, body + 0x30, object);
    win.store(usize, object, table);
    win.store(usize, object + 0x10, 0x12345678);
    win.store(usize, table + 0x2c, @intFromPtr(&kind));
    check(@src(), resolve(body) == 0x12345678 and calls == before + 3);
    win.store(usize, table + 0x2c, 0);
    check(@src(), resolve(body) == 0 and calls == before + 3);
    win.store(usize, object, 1);
    check(@src(), resolve(body) == 0 and calls == before + 3);
    check(@src(), resolve(1) == 0 and calls == before + 3);
    check(@src(), owner.clonewars_collision_owner_debug[0] == 3 and owner.clonewars_collision_owner_debug[1] == 4);
}
