const std = @import("std");
const win = @import("win32.zig");
const installer = @import("span_installer.zig");
const check = @import("native_test_support.zig").check;
extern "kernel32" fn GetSystemInfo(*anyopaque) callconv(.winapi) void;
const Fixture = struct {
    s: installer.Installer = std.mem.zeroes(installer.Installer),
    q: installer.Qualification = undefined,
    slot: usize = 0x11110000,
    protect_calls: u32 = 0,
    flush_calls: u32 = 0,
    write_calls: u32 = 0,
    equal_calls: u32 = 0,
    fail_protect: u32 = 0,
    fail_flush: u32 = 0,
    fail_write: u32 = 0,
    fail_equal: u32 = 0,
    race: bool = false,
    fn context(raw: usize) *Fixture {
        return @ptrFromInt(raw);
    }
    fn protect(raw: usize, _: usize, _: usize, _: u32, old: *u32) callconv(.c) i32 {
        const f = context(raw);
        f.protect_calls += 1;
        old.* = 4;
        if (f.race and f.protect_calls == 1) f.slot = 0x33330000;
        return @intFromBool(f.protect_calls != f.fail_protect);
    }
    fn flush(raw: usize, _: usize, _: usize) callconv(.c) i32 {
        const f = context(raw);
        f.flush_calls += 1;
        return @intFromBool(f.flush_calls != f.fail_flush);
    }
    fn bytes(raw: usize, len: usize) []u8 {
        return @as([*]u8, @ptrFromInt(raw))[0..len];
    }
    fn write(raw: usize, out: usize, in: usize, len: usize) callconv(.c) i32 {
        const f = context(raw);
        f.write_calls += 1;
        const failed = f.write_calls == f.fail_write;
        const n = if (failed) len / 2 else len;
        @memcpy(bytes(out, n), bytes(in, n));
        return @intFromBool(!failed);
    }
    fn equal(raw: usize, a: usize, b: usize, len: usize) callconv(.c) i32 {
        const f = context(raw);
        f.equal_calls += 1;
        return @intFromBool(f.equal_calls != f.fail_equal and std.mem.eql(u8, bytes(a, len), bytes(b, len)));
    }
    fn init(f: *Fixture, mode: u32) void {
        f.* = .{};
        var info: [48]u8 align(4) = undefined;
        GetSystemInfo(&info);
        const size = std.mem.readInt(u32, info[4..8], .little);
        check(@src(), size == 4096);
        const page = win.VirtualAlloc(0, size, 0x3000, 4);
        check(@src(), page != 0);
        f.s.slot = @intFromPtr(&f.slot);
        f.s.original_target = f.slot;
        f.s.owner_target = 0x22220000;
        f.s.code_page = page;
        f.s.code_size = size;
        f.s.forbidden = page + 0x380;
        f.s.forbidden_size = 7;
        f.s.main_thread = win.GetCurrentThreadId();
        f.s.generation = 3;
        f.s.ops = .{ .context = @intFromPtr(f), .protect = protect, .flush = flush, .write = write, .equal = equal };
        f.q = .{ .generation = 3, .thread = f.s.main_thread, .caller_verified = 1, .quiescent = 1, .owner_configured = 1, .main_confirmed = 1 };
        for (&f.s.sites, 0..) |*site, i| {
            site.address = page + 0x40 + i * 16;
            site.length = @intCast(5 + i);
            for (0..site.length) |j| {
                site.original[j] = @intCast(i * 16 + j);
                site.replacement[j] = @intCast(0xe0 + i + j);
            }
            @memcpy(bytes(site.address, site.length), site.original[0..site.length]);
        }
        if (mode >= 1 and mode <= 6) f.fail_protect = mode;
        if (mode >= 7 and mode <= 14) f.fail_write = mode - 6;
        if (mode >= 15 and mode <= 16) f.fail_flush = mode - 14;
        if (mode >= 17 and mode <= 28) f.fail_equal = mode - 16;
        switch (mode) {
            29 => f.race = true,
            30 => f.s.sites[1].address = f.s.sites[0].address + 2,
            31 => f.s.sites[0].address = f.s.forbidden,
            32 => f.q.quiescent = 0,
            33 => f.s.busy = 1,
            else => {},
        }
    }
    fn compare(f: *Fixture, index: usize, result: i32) void {
        var hash: u32 = 2166136261;
        for (bytes(f.s.code_page, f.s.code_size)) |byte| hash = (hash ^ byte) *% 16777619;
        const actual: [13]i64 = .{ result, f.slot, f.s.busy, f.s.state, f.s.ready, f.s.terminal, f.s.failure_phase, f.s.rollback_verified, f.protect_calls, f.flush_calls, f.write_calls, f.equal_calls, hash };
        check(@src(), std.mem.eql(i64, &actual, &expected[index]));
    }
};
pub fn main() void {
    for (0..34) |mode| {
        var f: Fixture = undefined;
        f.init(@intCast(mode));
        defer check(@src(), win.VirtualFree(f.s.code_page, 0, 0x8000) != 0);
        f.compare(mode * 3, installer.span_installer_bootstrap(&f.s, 1));
        f.compare(mode * 3 + 1, installer.span_installer_code(&f.s, &f.q));
        f.compare(mode * 3 + 2, installer.span_installer_confirm(&f.s, &f.q));
        if (mode == 0) {
            check(@src(), f.s.ready == 1);
            win.store(u8, f.s.sites[0].address, win.load(u8, f.s.sites[0].address) ^ 1);
            check(@src(), installer.span_installer_confirm(&f.s, &f.q) == -1);
            check(@src(), f.s.terminal == 1 and f.s.ready == 0);
        }
    }
    check(@src(), installer.span_installer_bootstrap(null, 1) == 0 and installer.span_installer_code(null, null) == 0 and installer.span_installer_confirm(null, null) == 0);
}

// Frozen results from the original x86 installer, including partial writes and rollback failures.
// Columns: result, slot, busy, state, ready, terminal, phase, rollback, protect, flush, write, equal, page FNV-1a.
const expected = [_][13]i64{
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ -1, 286326784, 0, 5, 0, 0, 3, 0, 1, 0, 0, 0, 2241802815 },
    .{ -1, 286326784, 0, 5, 0, 0, 10, 0, 1, 0, 0, 0, 2241802815 },
    .{ -1, 286326784, 0, 5, 0, 1, 30, 0, 1, 0, 0, 0, 2241802815 },
    .{ -1, 286326784, 0, 5, 0, 0, 5, 0, 3, 0, 0, 0, 2241802815 },
    .{ -1, 286326784, 0, 5, 0, 0, 10, 0, 3, 0, 0, 0, 2241802815 },
    .{ -1, 286326784, 0, 5, 0, 1, 30, 0, 3, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 13, 0, 3, 0, 0, 4, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 3, 0, 0, 4, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 26, 1, 5, 2, 8, 12, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 5, 2, 8, 12, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 20, 1, 4, 1, 5, 8, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 5, 8, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 21, 1, 4, 1, 6, 8, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 6, 8, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 22, 1, 4, 1, 7, 8, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 7, 8, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 23, 1, 4, 1, 8, 8, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 8, 8, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 25, 1, 4, 2, 8, 12, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 2, 8, 12, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ 1, 572653568, 0, 4, 1, 0, 0, 0, 4, 1, 4, 12, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 12, 0, 2, 0, 0, 1, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 1, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 12, 0, 2, 0, 0, 2, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 2, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 12, 0, 2, 0, 0, 3, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 3, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 12, 0, 2, 0, 0, 4, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 4, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 24, 1, 4, 1, 8, 9, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 8, 9, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 24, 1, 4, 1, 8, 10, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 8, 10, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 24, 1, 4, 1, 8, 11, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 8, 11, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 24, 1, 4, 1, 8, 12, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 1, 4, 1, 8, 12, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 4, 1, 4, 9, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 4, 1, 4, 10, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 4, 1, 4, 11, 1148263949 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 3, 0, 0, 0, 0, 4, 1, 4, 8, 1148263949 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 4, 1, 4, 12, 1148263949 },
    .{ -1, 858980352, 0, 5, 0, 0, 4, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 858980352, 0, 5, 0, 0, 10, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 858980352, 0, 5, 0, 1, 30, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 10, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 0, 10, 0, 2, 0, 0, 0, 2241802815 },
    .{ -1, 572653568, 0, 5, 0, 1, 30, 0, 2, 0, 0, 0, 2241802815 },
    .{ 1, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 0, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 0, 572653568, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 2241802815 },
    .{ 0, 286326784, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2241802815 },
    .{ 0, 286326784, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2241802815 },
    .{ 0, 286326784, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2241802815 },
};
