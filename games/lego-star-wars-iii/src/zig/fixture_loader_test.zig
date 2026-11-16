const std = @import("std");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
extern "kernel32" fn LoadLibraryA([*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn CreateFileA([*:0]const u8, u32, u32, usize, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn ReadFile(usize, [*]u8, u32, *u32, usize) callconv(.winapi) i32;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
fn symbol(comptime T: type, module: usize, name: [*:0]const u8) T {
    const address = GetProcAddress(module, name);
    check(@src(), address != 0);
    return @ptrFromInt(address);
}
fn invoke(raw: usize) callconv(.c) i32 {
    const call: *const fn () callconv(.c) i32 = @ptrFromInt(raw);
    return call();
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    check(@src(), args.len == 3 or args.len == 4);
    const is_owner = std.mem.eql(u8, args[1], "owner");
    check(@src(), is_owner or std.mem.eql(u8, args[1], "mapping") or std.mem.eql(u8, args[1], "session"));
    var bytes: [4096]u8 = undefined;
    const file = CreateFileA(args[2], 0x80000000, 1, 0, 3, 0, 0);
    check(@src(), file != 0xffffffff);
    var read: u32 = 0;
    check(@src(), ReadFile(file, &bytes, bytes.len, &read, 0) != 0 and read == bytes.len);
    check(@src(), win.CloseHandle(file) != 0);
    check(@src(), std.mem.readInt(u16, bytes[0..2], .little) == 0x5a4d);
    const offset = std.mem.readInt(u32, bytes[0x3c..0x40], .little);
    check(@src(), offset < 3000);
    const nt = bytes[offset..];
    check(@src(), std.mem.readInt(u32, nt[0..4], .little) == 0x4550 and std.mem.readInt(u16, nt[24..26], .little) == 0x10b);
    const preferred = std.mem.readInt(u32, nt[52..56], .little);
    const size = std.mem.readInt(u32, nt[80..84], .little);
    check(@src(), std.mem.readInt(u32, nt[160..164], .little) != 0 and std.mem.readInt(u32, nt[164..168], .little) != 0);
    const reservation = win.VirtualAlloc(preferred, size, 0x2000, 1);
    check(@src(), reservation == preferred);
    defer check(@src(), win.VirtualFree(reservation, 0, 0x8000) != 0);
    const dll = LoadLibraryA(args[2]);
    check(@src(), dll != 0 and dll != preferred);
    if (is_owner) {
        const Call = *const fn () callconv(.c) i32;
        check(@src(), symbol(Call, dll, "run_fixture")() == 0);
        var scenario: [16]u8 = @splat(0);
        const length = GetEnvironmentVariableA("OWNER_SCENARIO", &scenario, scenario.len);
        check(@src(), length > 0 and length < scenario.len);
        if (try std.fmt.parseInt(u32, scenario[0..length], 10) == 0) {
            const raised = support.exceptionResult(GetProcAddress(dll, "raise_external"), invoke);
            check(@src(), raised.code == 0xe0011234);
            const Error = *const fn () callconv(.c) u32;
            check(@src(), symbol(Error, dll, "expected_exception_error")() == raised.last_error);
            check(@src(), symbol(Call, dll, "verify_external")() == 0);
        }
    } else {
        check(@src(), args.len == 4);
        const Call = *const fn (u32) callconv(.c) i32;
        const name = if (std.mem.eql(u8, args[1], "session")) "run_session_fixture" else "run_mapping_fixture";
        check(@src(), symbol(Call, dll, name)(try std.fmt.parseInt(u32, args[3], 10)) == 0);
    }
    check(@src(), win.FreeLibrary(dll) != 0);
}
