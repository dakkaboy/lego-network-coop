const std = @import("std");
const win = @import("win32.zig");
const Context = extern struct { prefix: [39]u32, edi: u32, esi: u32, ebx: u32, edx: u32, ecx: u32, eax: u32, ebp: u32, eip: u32, cs: u32, flags: u32, esp: u32 };
const Record = extern struct { code: u32, flags: u32, nested: usize, address: usize, parameter_count: u32, information: [15]usize };
const Exception = extern struct { record: *const Record, context: *const Context };
extern "kernel32" fn GetModuleFileNameA(usize, [*]u8, u32) callconv(.winapi) u32;
extern "kernel32" fn AddVectoredExceptionHandler(u32, *const fn (*const Exception) callconv(.winapi) i32) callconv(.winapi) usize;
extern "kernel32" fn CreateFileA([*:0]const u8, u32, u32, usize, u32, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn WriteFile(usize, [*]const u8, u32, *u32, usize) callconv(.winapi) i32;
var report_path: [260]u8 = @splat(0);
var module_base: usize = 0;
var captured: u32 = 0;
fn words(writer: *std.Io.Writer, name: []const u8, address: usize, count: u32) std.Io.Writer.Error!void {
    try writer.print("{s} @ {x:0>8}\n", .{ name, address });
    for (0..count) |i| {
        const location = address +% (i * 4);
        if (!win.accessible(location, 4, false)) break;
        try writer.print("{x:0>8}: {x:0>8}\n", .{ location, win.load(u32, location) });
    }
}
fn report(writer: *std.Io.Writer, exception: *const Exception) std.Io.Writer.Error!void {
    const c = exception.context;
    const r = exception.record;
    try writer.print("module={x:0>8} fault_rva={x:0>8}\n", .{ module_base, c.eip -% module_base });
    try writer.print("fault={x:0>8} read_write={d} address={x:0>8}\nEAX={x:0>8} EBX={x:0>8} ECX={x:0>8} EDX={x:0>8}\nESI={x:0>8} EDI={x:0>8} EBP={x:0>8} ESP={x:0>8}\n", .{ c.eip, r.information[0], r.information[1], c.eax, c.ebx, c.ecx, c.edx, c.esi, c.edi, c.ebp, c.esp });
    const root = if (win.accessible(0xfb2e60, 4, false)) win.load(usize, 0xfb2e60) else 0;
    try words(writer, "root flow", root +% 0x1b44, 32);
    try words(writer, "players", 0xfb4940, 8);
    try words(writer, "EAX object", c.eax, 48);
    try words(writer, "EBX object", c.ebx, 48);
    try words(writer, "ECX object", c.ecx, 48);
    try words(writer, "EDX object", c.edx, 48);
    try words(writer, "ESI object", c.esi, 48);
    try words(writer, "EDI object", c.edi, 48);
    try words(writer, "EDI manager views", c.edi +% 0xf24, 12);
    try words(writer, "EDI manager cameras", c.edi +% 0x13a4, 8);
    try words(writer, "fault code", c.eip, 8);
    try words(writer, "stack", c.esp, 512);
}
fn onException(exception: *const Exception) callconv(.winapi) i32 {
    if (exception.record.code != 0xc0000005 or @cmpxchgStrong(u32, &captured, 0, 1, .seq_cst, .seq_cst) != null) return 0;
    const file = CreateFileA(@ptrCast(&report_path), 0x40000000, 1, 0, 2, 0x80, 0);
    if (file == std.math.maxInt(usize)) return 0;
    defer _ = win.CloseHandle(file);
    var buffer: [32768]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    report(&writer, exception) catch return 0;
    var written: u32 = 0;
    _ = WriteFile(file, buffer[0..writer.end].ptr, @intCast(writer.end), &written, 0);
    return 0;
}
pub export fn diagnostics_install(module: usize) void {
    module_base = module;
    _ = GetModuleFileNameA(module, &report_path, report_path.len);
    report_path[report_path.len - 1] = 0;
    const length = std.mem.indexOfScalar(u8, &report_path, 0).?;
    if (std.mem.lastIndexOfScalar(u8, report_path[0..length], '\\')) |separator| {
        var writer: std.Io.Writer = .fixed(report_path[separator + 1 ..]);
        writer.print("crash-{d}.txt", .{win.GetCurrentProcessId()}) catch {};
        writer.writeByte(0) catch {
            report_path[report_path.len - 1] = 0;
        };
    }
    _ = AddVectoredExceptionHandler(1, onException);
}
comptime {
    std.debug.assert(@sizeOf(usize) == 4 and @offsetOf(Context, "eip") == 184 and @offsetOf(Context, "esp") == 196);
}
