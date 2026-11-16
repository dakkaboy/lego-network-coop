const std = @import("std");
const win = @import("win32.zig");
const Ring = @import("trace.zig").Ring(512);
const module_name = "clonewars-camera.dll";
const symbol = "clonewars_zig_trace";
const Module = extern struct {
    size: u32,
    module_id: u32,
    process_id: u32,
    global_usage: u32,
    process_usage: u32,
    base: usize,
    image_size: u32,
    handle: usize,
    name: [256]u16,
    path: [260]u16,
};
extern "kernel32" fn CreateToolhelp32Snapshot(u32, u32) callconv(.winapi) usize;
extern "kernel32" fn Module32FirstW(usize, *Module) callconv(.winapi) i32;
extern "kernel32" fn Module32NextW(usize, *Module) callconv(.winapi) i32;

const Image = struct {
    process: usize,
    base: usize,
    size: usize,
    fn address(self: Image, rva: usize, bytes: usize) !usize {
        if (rva > self.size or bytes > self.size - rva or self.base > std.math.maxInt(usize) - rva) return error.InvalidImageOffset;
        return self.base + rva;
    }
    fn read(self: Image, rva: usize, output: []u8) !void {
        try readRemote(self.process, try self.address(rva, output.len), output);
    }
    fn word(self: Image, rva: usize) !u32 {
        var bytes: [4]u8 = undefined;
        try self.read(rva, &bytes);
        return std.mem.readInt(u32, &bytes, .little);
    }
};
fn readRemote(process: usize, address: usize, bytes: []u8) !void {
    var read: usize = 0;
    if (win.ReadProcessMemory(process, address, bytes.ptr, bytes.len, &read) == 0 or read != bytes.len) return error.ProcessMemoryReadFailed;
}
fn sameName(name: []const u16) bool {
    if (name.len < module_name.len + 1 or name[module_name.len] != 0) return false;
    for (module_name, name[0..module_name.len]) |expected, actual| {
        if (actual > 127 or std.ascii.toLower(@intCast(actual)) != expected) return false;
    }
    return true;
}
fn findImage(process: usize, pid: u32) !Image {
    const snapshot = CreateToolhelp32Snapshot(0x18, pid);
    if (snapshot == std.math.maxInt(usize)) return error.ModuleSnapshotFailed;
    defer _ = win.CloseHandle(snapshot);
    var module = std.mem.zeroes(Module);
    module.size = @sizeOf(Module);
    if (Module32FirstW(snapshot, &module) == 0) return error.ModuleListFailed;
    while (true) {
        if (sameName(&module.name)) return .{ .process = process, .base = module.base, .size = module.image_size };
        if (Module32NextW(snapshot, &module) == 0) return error.ModNotLoaded;
    }
}
fn traceAddress(image: Image) !usize {
    var dos: [64]u8 = undefined;
    try image.read(0, &dos);
    if (std.mem.readInt(u16, dos[0..2], .little) != 0x5a4d) return error.InvalidExecutable;
    const nt = std.mem.readInt(u32, dos[60..64], .little);
    if (nt > 1024 * 1024) return error.InvalidExecutable;
    var header: [128]u8 = undefined;
    try image.read(nt, &header);
    if (std.mem.readInt(u32, header[0..4], .little) != 0x4550 or std.mem.readInt(u16, header[4..6], .little) != 0x14c or
        std.mem.readInt(u16, header[24..26], .little) != 0x10b) return error.UnsupportedExecutable;
    const export_rva = std.mem.readInt(u32, header[120..124], .little);
    const export_size = std.mem.readInt(u32, header[124..128], .little);
    if (export_rva == 0 or export_size < 40) return error.TraceNotExported;
    var directory: [40]u8 = undefined;
    try image.read(export_rva, &directory);
    const functions = std.mem.readInt(u32, directory[20..24], .little);
    const names = std.mem.readInt(u32, directory[24..28], .little);
    const function_table = std.mem.readInt(u32, directory[28..32], .little);
    const name_table = std.mem.readInt(u32, directory[32..36], .little);
    const ordinal_table = std.mem.readInt(u32, directory[36..40], .little);
    if (names > 65536 or functions > 65536) return error.InvalidExportTable;
    _ = try image.address(function_table, functions * 4);
    _ = try image.address(name_table, names * 4);
    _ = try image.address(ordinal_table, names * 2);
    for (0..names) |i| {
        const name_rva = try image.word(@as(usize, name_table) + i * 4);
        var name: [symbol.len + 1]u8 = undefined;
        image.read(name_rva, &name) catch continue;
        if (!std.mem.eql(u8, &name, symbol ++ "\x00")) continue;
        var ordinal_bytes: [2]u8 = undefined;
        try image.read(@as(usize, ordinal_table) + i * 2, &ordinal_bytes);
        const ordinal = std.mem.readInt(u16, &ordinal_bytes, .little);
        if (ordinal >= functions) return error.InvalidExportTable;
        const rva = try image.word(@as(usize, function_table) + @as(usize, ordinal) * 4);
        if (rva >= export_rva and rva - export_rva < export_size) return error.ForwardedTraceSymbol;
        return image.address(rva, @sizeOf(Ring));
    }
    return error.TraceNotExported;
}
pub fn capture(pid: u32, output: *[@sizeOf(Ring)]u8) !void {
    const process = win.OpenProcess(0x1010, 0, pid);
    if (process == 0) return error.ProcessOpenFailed;
    defer _ = win.CloseHandle(process);
    const image = try findImage(process, pid);
    const address = try traceAddress(image);
    const header_size = @offsetOf(Ring, "slots");
    @memset(output, 0);
    try readRemote(process, address, output[0..header_size]);
    if (std.mem.readInt(u32, output[0..4], .little) != 1 or std.mem.readInt(u32, output[4..8], .little) != 512 or
        std.mem.readInt(u32, output[8..12], .little) != 32) return error.UnsupportedTraceLayout;
    const head = std.mem.readInt(u32, output[12..16], .little);
    if (head == 0) return;
    var id: u32 = if (head > 512) head - 511 else 1;
    while (true) {
        const offset = header_size + ((id - 1) & 511) * 32;
        var committed: [4]u8 = undefined;
        try readRemote(process, address + offset, &committed);
        if (std.mem.readInt(u32, &committed, .little) == id) {
            var event: [28]u8 = undefined;
            try readRemote(process, address + offset + 4, &event);
            try readRemote(process, address + offset, &committed);
            if (std.mem.readInt(u32, &committed, .little) == id) {
                @memcpy(output[offset..][0..4], &committed);
                @memcpy(output[offset + 4 ..][0..28], &event);
            }
        }
        if (id == head) break;
        id += 1;
    }
    @memset(output[20..24], 0);
}
