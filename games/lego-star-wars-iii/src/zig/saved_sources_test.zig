const std = @import("std");
const s = @import("saved_sources.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var native_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var storage_ready: c_int = 1;
var world: [0x2300]u8 = @splat(0);
var definition: [0x1b0]u8 = @splat(0);
var provider: [4]u8 = @splat(0);
var provider_table: [0x7c]u8 = @splat(0);
var profile: [4]u8 = @splat(0);
var manager: [0x6b8]u8 = @splat(0);
var owner: [0x214]u8 = @splat(0);
var other_owner: [0x214]u8 = @splat(0);
var registry: [8 + 192 * 20]u8 = @splat(0);
var records: [200]u8 = @splat(0);
var frame: [0x18]u8 = @splat(0);
export fn game_native_profile_storage_ready() c_int {
    return storage_ready;
}
fn put(base: anytype, offset: usize, value: usize) void {
    win.store(usize, @intFromPtr(base) + offset, value);
}
fn setup() void {
    inline for (.{ &world, &definition, &manager, &owner, &other_owner, &registry, &frame }) |buffer| @memset(buffer, 0);
    @memset(@as([*]u8, @ptrFromInt(0xfb4f20))[0 .. 8 * 0x2c], 0);
    storage_ready = 1;
    win.store(usize, 0xfb4a20, @intFromPtr(&world));
    win.store(usize, 0xfbd8bc, @intFromPtr(&profile));
    put(&profile, 0, 0x500);
    put(&world, 0x220, @intFromPtr(&definition));
    win.store(i16, @intFromPtr(&definition) + 0x94, 0);
    win.store(usize, 0xfb8404, @intFromPtr(&definition));
    win.store(u32, 0xfb8410, 1);
    win.store(usize, 0xe90218, @intFromPtr(&provider));
    put(&provider, 0, @intFromPtr(&provider_table));
    win.store(u32, 0xfb4f18, 2);
    win.store(u16, 0xfb4f20 + 0x24, 0x37);
    win.store(u32, 0xfb4f20 + 0x10, 0x456);
    put(&world, 0x22e4, @intFromPtr(&provider_table));
    put(&provider_table, 0xc, @intFromPtr(&world));
    put(&frame, 8, @intFromPtr(&manager));
    put(&manager, 0, 0xae68bc);
    put(&manager, 4, 2);
    put(&manager, 8, 7);
    put(&manager, 0x68, @intFromPtr(&registry) + 8);
    put(&manager, 0x6c, 3);
    put(&manager, 0x98, @intFromPtr(&owner));
    win.store(usize, 0xe906b0, @intFromPtr(&registry));
    put(&registry, 8, 7);
    put(&registry, 12, 3);
    put(&registry, 16, @intFromPtr(&manager));
    put(&registry, 20, 4);
    put(&owner, 0xb8, 9);
    win.store(i8, @intFromPtr(&owner) + 0x1b4, 2);
    put(&owner, 0xcc, @intFromPtr(&records));
}
fn canonical(value: usize) u32 {
    const pointers = [_]usize{ @intFromPtr(&world), @intFromPtr(&definition), @intFromPtr(&profile), @intFromPtr(&provider), @intFromPtr(&provider_table), 0xfb4f20, @intFromPtr(&manager), @intFromPtr(&registry), @intFromPtr(&registry) + 8, @intFromPtr(&owner), @intFromPtr(&records), @intFromPtr(&frame) };
    for (pointers, 0..) |pointer, i| if (value == pointer) return @intCast(0x1000 + i);
    return @intCast(value);
}
fn hashBytes(bytes: []const u8) u32 {
    var result: u32 = 2166136261;
    for (bytes) |byte| result = (result ^ byte) *% 16777619;
    return result;
}
fn rosterHash(source: s.Roster) u32 {
    var copy = source;
    inline for (.{ "world", "definition", "profile", "provider", "provider_class", "record" }) |field| @field(copy, field) = canonical(@field(copy, field));
    return hashBytes(std.mem.asBytes(&copy));
}
fn hubHash(source: s.Hub) u32 {
    var copy = source;
    inline for (.{ "world", "definition", "profile", "manager", "registry", "registration", "owner", "records", "record", "native_frame" }) |field| @field(copy, field) = canonical(@field(copy, field));
    const value = std.mem.readInt(u32, copy.registration_data[8..12], .little);
    std.mem.writeInt(u32, copy.registration_data[8..12], canonical(value), .little);
    return hashBytes(std.mem.asBytes(&copy));
}
pub fn main() void {
    check(@src(), @sizeOf(s.Roster) == 76 and @sizeOf(s.Hub) == 192 and @intFromPtr(&native_image) < 0xe90000 and @intFromPtr(&native_image) + native_image.len > 0xfc0000);
    setup();
    const roster_args = [_]u32{ 0x37, 0xfb4f24, 0x456, 0xfb4f34, 0, 1, 0, 0, 0, 0, 0, 0xffffffff };
    const hub_args = [_]u32{ 1, @intFromPtr(&records), 3, @intFromPtr(&records) + 16, 0, 1, 0, 0, 0, 0, 0, 0xffffffff };
    var roster: s.Roster = undefined;
    var hub: s.Hub = undefined;
    var reason: u32 = 99;
    check(@src(), s.native_roster_source_resolve(0xfb4f48, &roster_args, &roster) == 1);
    check(@src(), s.native_hub_source_resolve(@intFromPtr(&owner), @intFromPtr(&frame), &hub_args, &hub, &reason) == 1 and reason == 0);
    for (@import("saved_source_expected.zig").rows, 0..) |expected, mutation| {
        setup();
        var args = hub_args;
        switch (mutation) {
            1 => storage_ready = 0,
            2 => put(&profile, 0, 0),
            3 => win.store(i16, @intFromPtr(&definition) + 0x94, -1),
            4 => put(&definition, 0x50, 0x40000000),
            5 => win.store(u32, 0xfb8410, 0),
            6 => win.store(u32, 0xfb4f18, 9),
            7 => win.store(u8, @intFromPtr(&definition) + 0x130, 3),
            8 => win.store(u32, 0xfb4f20, 9),
            9 => put(&manager, 0, 1),
            10 => put(&frame, 0x14, 1),
            11 => put(&registry, 8, 0),
            12 => put(&manager, 0x6c, 9),
            13 => put(&registry, 24, 1),
            14 => {
                @memcpy(registry[28..48], registry[8..28]);
                put(&registry, 36, @intFromPtr(&other_owner));
            },
            15 => {
                put(&owner, 0x9c, @intFromPtr(&other_owner));
                put(&other_owner, 0xb8, 9);
            },
            16 => put(&owner, 0x9c, @intFromPtr(&owner)),
            17 => put(&owner, 0xb8, 0),
            18 => win.store(i8, @intFromPtr(&owner) + 0x1b4, -1),
            19 => put(&frame, 0xc, 2),
            20 => put(&owner, 0xcc, 1),
            else => if (mutation >= 21 and mutation < 33) {
                args[mutation - 21] ^= 0x80000000;
            },
        }
        var a: s.Roster = undefined;
        @memset(std.mem.asBytes(&a), 0x5a);
        win.SetLastError(0x12345678);
        const x = s.native_roster_source_resolve(0xfb4f48, &roster_args, &a);
        check(@src(), win.GetLastError() == 0x12345678);
        var b: s.Hub = undefined;
        @memset(std.mem.asBytes(&b), 0xa5);
        reason = 99;
        win.SetLastError(0x87654321);
        const y = s.native_hub_source_resolve(@intFromPtr(&owner), @intFromPtr(&frame), &args, &b, &reason);
        check(@src(), win.GetLastError() == 0x87654321);
        const actual = [_]u32{ @intCast(x), rosterHash(a), @intCast(s.native_roster_source_revalidate(&roster, 0)), @intCast(y), reason, hubHash(b), @intCast(s.native_hub_source_revalidate(&hub)) };
        if (!std.mem.eql(u32, &actual, &expected)) std.debug.print("saved_sources mutation={d} actual={any} expected={any}\n", .{ mutation, actual, expected });
        check(@src(), std.mem.eql(u32, &actual, &expected));
    }
    setup();
    var out: s.Hub = undefined;
    check(@src(), s.native_hub_source_resolve(1, @intFromPtr(&frame), &hub_args, &out, &reason) == 0 and reason == 1);
    const rawHub: *const fn (usize, usize, usize, *s.Hub, *u32) callconv(.c) c_int = @ptrCast(&s.native_hub_source_resolve);
    check(@src(), rawHub(@intFromPtr(&owner), @intFromPtr(&frame), 1, &out, &reason) == 0 and reason == 9);
}
