const std = @import("std");
const win = @import("win32.zig");
pub const Patch = @import("span_installer_types.zig").Patch;
pub const Ops = @import("span_installer_types.zig").Ops;
pub const Installer = @import("span_installer_types.zig").Installer;
pub const Qualification = @import("span_installer_types.zig").Qualification;
extern "kernel32" fn GetSystemInfo(*anyopaque) callconv(.winapi) void;
fn protect(s: *Installer, address: usize, n: usize, mode: u32, old: *u32) bool {
    return (if (s.ops.protect) |f| f(s.ops.context, address, n, mode, old) else win.VirtualProtect(address, n, mode, old)) != 0;
}
fn flush(s: *Installer, address: usize, n: usize) bool {
    return (if (s.ops.flush) |f| f(s.ops.context, address, n) else win.FlushInstructionCache(win.GetCurrentProcess(), address, n)) != 0;
}
fn bytes(address: usize, n: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..n];
}
fn write(s: *Installer, address: usize, value: []const u8) bool {
    if (s.ops.write) |f| return f(s.ops.context, address, @intFromPtr(value.ptr), value.len) != 0;
    @memcpy(bytes(address, value.len), value);
    return true;
}
fn equal(s: *Installer, address: usize, value: []const u8) bool {
    if (s.ops.equal) |f| return f(s.ops.context, address, @intFromPtr(value.ptr), value.len) != 0;
    return std.mem.eql(u8, bytes(address, value.len), value);
}
fn overlap(a: usize, an: usize, b: usize, bn: usize) bool {
    return an != 0 and bn != 0 and a < b +% bn and b < a +% an;
}
fn slotRead(s: *Installer) usize {
    return @atomicLoad(usize, @as(*usize, @ptrFromInt(s.slot)), .seq_cst);
}
fn slotExchange(s: *Installer, expected: usize, value: usize) usize {
    return @cmpxchgStrong(usize, @as(*usize, @ptrFromInt(s.slot)), expected, value, .seq_cst, .seq_cst) orelse expected;
}
fn schema(s: *Installer) bool {
    if (s.slot == 0 or s.slot & 3 != 0 or !win.accessible(s.slot, 4, false)) return false;
    var info: [48]u8 align(4) = undefined;
    GetSystemInfo(&info);
    const page_size = std.mem.readInt(u32, info[4..8], .little);
    const page = s.code_page;
    if (page == 0 or s.code_size != page_size or page_size == 0 or page % page_size != 0 or !win.accessible(page, s.code_size, false)) return false;
    if (s.forbidden_size != 0 and (s.forbidden == 0 or !win.accessible(s.forbidden, s.forbidden_size, false))) return false;
    for (&s.sites, 0..) |*p, i| {
        const a = p.address;
        if (p.length < 5 or p.length > 8 or a < page or p.length > std.math.maxInt(usize) - a or a + p.length > page + s.code_size or overlap(a, p.length, s.forbidden, s.forbidden_size)) return false;
        for (s.sites[0..i]) |previous| if (overlap(a, p.length, previous.address, previous.length)) return false;
    }
    return true;
}
fn allBytes(s: *Installer, installed: bool) bool {
    for (&s.sites) |*p| if (!equal(s, p.address, (if (installed) &p.replacement else &p.original)[0..p.length])) return false;
    return true;
}
fn qualified(s: *Installer, q: ?*const Qualification) bool {
    const value = q orelse return false;
    return value.generation == s.generation and value.thread != 0 and value.thread == win.GetCurrentThreadId() and value.thread == s.main_thread and value.caller_verified != 0 and value.quiescent != 0 and value.owner_configured != 0;
}
fn fail(s: *Installer, phase: u32, terminal: bool) c_int {
    @atomicStore(i32, &s.ready, 0, .seq_cst);
    s.failure_phase = phase;
    if (terminal) s.terminal = 1;
    @atomicStore(i32, &s.state, 5, .seq_cst);
    return -1;
}
fn lock(s: *Installer) bool {
    return @cmpxchgStrong(i32, &s.busy, 0, 1, .seq_cst, .seq_cst) == null;
}
pub export fn span_installer_bootstrap(installer: ?*Installer, configured: u32) c_int {
    const s = installer orelse return 0;
    if (configured == 0 or !lock(s)) return 0;
    defer @atomicStore(i32, &s.busy, 0, .seq_cst);
    if (s.terminal != 0 or s.slot == 0 or s.slot & 3 != 0 or s.original_target == 0 or s.owner_target == 0 or s.owner_target == s.original_target or !win.accessible(s.slot, 4, false)) return fail(s, 1, false);
    const seen = slotRead(s);
    if (seen == s.owner_target and s.state >= 1 and s.state <= 4) return 1;
    if (seen != s.original_target) return fail(s, 2, false);
    @atomicStore(i32, &s.ready, 0, .seq_cst);
    var old: u32 = 0;
    var ignored: u32 = 0;
    if (!protect(s, s.slot, 4, 4, &old)) return fail(s, 3, false);
    if (slotExchange(s, s.original_target, s.owner_target) != s.original_target) {
        const restored = protect(s, s.slot, 4, old, &ignored);
        return fail(s, 4, !restored);
    }
    if (!protect(s, s.slot, 4, old, &ignored)) {
        const rolled_back = slotExchange(s, s.owner_target, s.original_target) == s.owner_target;
        const restored = protect(s, s.slot, 4, old, &ignored);
        return fail(s, 5, !rolled_back or !restored);
    }
    @atomicStore(i32, &s.state, 1, .seq_cst);
    return 1;
}
fn rollback(s: *Installer, phase: u32, was_protected: bool, old: u32) c_int {
    var ignored: u32 = 0;
    var protected = was_protected;
    var ok = true;
    if (!protected) {
        protected = protect(s, s.code_page, s.code_size, 0x40, &ignored);
        if (!protected) ok = false;
    }
    if (protected) {
        for (&s.sites) |*p| if (!write(s, p.address, p.original[0..p.length])) {
            ok = false;
        };
        if (!allBytes(s, false)) ok = false;
        if (!flush(s, s.code_page, s.code_size)) ok = false;
        if (!protect(s, s.code_page, s.code_size, old, &ignored)) ok = false;
    }
    s.rollback_verified = @intFromBool(ok);
    return fail(s, phase, !ok);
}
pub export fn span_installer_code(installer: ?*Installer, q: ?*const Qualification) c_int {
    const s = installer orelse return 0;
    if (!qualified(s, q) or !lock(s)) return 0;
    defer @atomicStore(i32, &s.busy, 0, .seq_cst);
    if (s.terminal != 0 or !schema(s) or slotRead(s) != s.owner_target) return fail(s, 10, false);
    if (s.state == 3 or s.state == 4) {
        if (allBytes(s, true)) return 1;
        return fail(s, 11, true);
    }
    if (s.state != 1 or !allBytes(s, false)) return fail(s, 12, false);
    @atomicStore(i32, &s.ready, 0, .seq_cst);
    @atomicStore(i32, &s.state, 2, .seq_cst);
    s.rollback_verified = 0;
    var old: u32 = 0;
    var ignored: u32 = 0;
    if (!protect(s, s.code_page, s.code_size, 0x40, &old)) return fail(s, 13, false);
    for (&s.sites, 0..) |*p, i| if (!write(s, p.address, p.replacement[0..p.length])) return rollback(s, @intCast(20 + i), true, old);
    if (!allBytes(s, true)) return rollback(s, 24, true, old);
    if (!flush(s, s.code_page, s.code_size)) return rollback(s, 25, true, old);
    if (!protect(s, s.code_page, s.code_size, old, &ignored)) return rollback(s, 26, true, old);
    @atomicStore(i32, &s.state, 3, .seq_cst);
    return 1;
}
pub export fn span_installer_confirm(installer: ?*Installer, q: ?*const Qualification) c_int {
    const s = installer orelse return 0;
    if (!qualified(s, q) or q.?.main_confirmed == 0 or !lock(s)) return 0;
    defer @atomicStore(i32, &s.busy, 0, .seq_cst);
    if (s.terminal == 0 and (s.state == 3 or s.state == 4) and schema(s) and slotRead(s) == s.owner_target and allBytes(s, true)) {
        @atomicStore(i32, &s.state, 4, .seq_cst);
        @atomicStore(i32, &s.ready, 1, .seq_cst);
        return 1;
    }
    return fail(s, 30, true);
}
