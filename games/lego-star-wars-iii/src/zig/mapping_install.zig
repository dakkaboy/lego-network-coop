const std = @import("std");
const win = @import("win32.zig");
const m = @import("mapping_types.zig");
const contract = @import("mapping_contract.zig");
const root = @import("root");
const testing = if (@hasDecl(root, "mapping_test_api")) root.mapping_test_api else false;
const original_addresses = [_]usize{ 0x57b1a0, 0x582da0, 0x57b2a0, 0x57b530, 0xab67f0, 0x58988f, 0x5898e1, 0x589660 };
const lengths = [_]usize{ 5, 5, 5, 5, 5, 6, 6, 7 };
const prefixes = [_][7]u8{ .{ 0x56, 0x8b, 0x74, 0x24, 8, 0, 0 }, .{ 0x56, 0x8b, 0x74, 0x24, 8, 0, 0 }, .{ 0x68, 0, 9, 0, 0, 0, 0 }, .{ 0x33, 0xd2, 0x83, 0xc8, 0xff, 0, 0 }, .{ 0x32, 0xc0, 0x83, 0xc9, 0xff, 0, 0 }, .{ 0x89, 0x15, 0x70, 0x1a, 0xeb, 0, 0 }, .{ 0x89, 0x15, 0x70, 0x1a, 0xeb, 0, 0 }, .{ 0x6a, 0xff, 0x68, 0x68, 0x12, 0xaa, 0 } };
var addresses: [8]usize = @splat(0);
var image_base: usize = 0;
var slab: usize = 0;
var targets: [8]usize = @splat(0);
var main_thread: u32 = 0;
pub export var clonewars_user_mapping_installed: i32 = 0;
export var mapping_resume_a: usize = 0;
export var mapping_resume_b: usize = 0;
extern fn user_mapping_test_image_base() usize;
extern fn user_mapping_test_protect(usize, usize, u32, *u32) i32;
extern fn user_mapping_test_flush(usize, usize, usize) i32;
extern fn user_mapping_configure(*const m.Config) c_int;
extern fn user_mapping_binding_ready(u32) c_int;
extern fn user_mapping_enable() c_int;
extern fn user_mapping_invalidate_runtime() void;
extern fn user_mapping_mapper_entry() void;
extern fn user_mapping_setter_entry() void;
extern fn user_mapping_reset_all_entry() void;
extern fn user_mapping_reset_01_entry() void;
extern fn user_mapping_initializer_entry() void;
extern fn user_mapping_poller_entry() void;
extern fn mapping_user0_a_thunk() void;
extern fn mapping_user0_b_thunk() void;
fn protect(address: usize, bytes: usize, protection: u32, old: *u32) bool {
    return (if (testing) user_mapping_test_protect(address, bytes, protection, old) else win.VirtualProtect(address, bytes, protection, old)) != 0;
}
fn flush(address: usize, bytes: usize) bool {
    return (if (testing) user_mapping_test_flush(win.GetCurrentProcess(), address, bytes) else win.FlushInstructionCache(win.GetCurrentProcess(), address, bytes)) != 0;
}
fn memory(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn expected(index: usize) [7]u8 {
    var value = prefixes[index];
    if (index == 5 or index == 6) std.mem.writeInt(u32, value[2..6], @truncate(image_base + 0xeb1a70 - 0x400000), .little);
    if (index == 7) std.mem.writeInt(u32, value[3..7], @truncate(image_base + 0xaa1268 - 0x400000), .little);
    return value;
}
fn nativeContractValid() bool {
    for (contract.bodies, 0..) |body, i| {
        var expected_bytes: [192]u8 = undefined;
        @memcpy(expected_bytes[0..body.bytes.len], body.bytes);
        for (contract.relocations) |r| if (r >= body.address and r + 4 <= body.address + body.bytes.len) {
            const offset = r - body.address;
            const value = std.mem.readInt(u32, expected_bytes[offset..][0..4], .little);
            std.mem.writeInt(u32, expected_bytes[offset..][0..4], value +% @as(u32, @truncate(image_base -% 0x400000)), .little);
        };
        const skip: usize = if (i < 5) 5 else 0;
        const address = image_base + body.address - 0x400000 + skip;
        if (!win.accessible(address, body.bytes.len - skip, false) or !std.mem.eql(u8, memory(address, body.bytes.len - skip), expected_bytes[skip..body.bytes.len])) return false;
    }
    return true;
}
pub export fn user_mapping_install_ready() c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (clonewars_user_mapping_installed != 127 or win.GetCurrentThreadId() != main_thread or slab == 0) return 0;
    for (addresses, lengths, targets, 0..) |address, length, target, i| {
        if (!win.accessible(address, length, false) or win.load(u8, address) != 0xe9 or address +% 5 +% win.load(u32, address + 1) != target) return 0;
        for (5..length) |j| if (win.load(u8, address + j) != 0x90) return 0;
        const original = expected(i);
        const trampoline = slab + i * 16;
        if (!win.accessible(trampoline, 16, false) or !std.mem.eql(u8, memory(trampoline, length), original[0..length])) return 0;
        if (i == 5 or i == 6) {
            if (win.load(u8, trampoline + length) != 0xc3) return 0;
        } else if (win.load(u8, trampoline + length) != 0xe9 or trampoline +% length +% 5 +% win.load(u32, trampoline + length + 1) != address + length) return 0;
    }
    return @intFromBool(nativeContractValid());
}
fn disableInstallation() void {
    user_mapping_invalidate_runtime();
    @atomicStore(i32, &clonewars_user_mapping_installed, -1, .seq_cst);
}
fn restorePages(pages: []const usize, old: []const u32) bool {
    var ok = true;
    var count = pages.len;
    while (count > 0) {
        count -= 1;
        var ignored: u32 = 0;
        if (!protect(pages[count], 4096, old[count], &ignored)) ok = false;
    }
    return ok;
}
pub export fn user_mapping_install_safe(config: ?*const m.InstallConfig) c_int {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const c = config orelse return 0;
    if (c.main_thread == 0 or win.GetCurrentThreadId() != c.main_thread or c.original_source_valid == null or c.install_allowed == null or c.install_allowed.?(c.user) == 0 or clonewars_user_mapping_installed < 0) return 0;
    if (clonewars_user_mapping_installed == 127) return user_mapping_install_ready();
    image_base = if (testing) user_mapping_test_image_base() else win.GetModuleHandleA(null);
    if (!testing and image_base != 0x400000) return 0;
    for (&addresses, original_addresses) |*address, original| address.* = image_base + original - 0x400000;
    mapping_resume_a = addresses[5] + 6;
    mapping_resume_b = addresses[6] + 6;
    for (addresses, lengths, 0..) |address, length, i| {
        const value = expected(i);
        if (!win.accessible(address, length, false) or !std.mem.eql(u8, memory(address, length), value[0..length])) return 0;
    }
    if (!nativeContractValid()) return 0;
    const new_slab = win.VirtualAlloc(0, 8 * 16, 0x3000, 0x40);
    if (new_slab == 0) return 0;
    const entrypoints = [_]usize{ @intFromPtr(&user_mapping_mapper_entry), @intFromPtr(&user_mapping_setter_entry), @intFromPtr(&user_mapping_reset_all_entry), @intFromPtr(&user_mapping_reset_01_entry), @intFromPtr(&user_mapping_initializer_entry), @intFromPtr(&mapping_user0_a_thunk), @intFromPtr(&mapping_user0_b_thunk), @intFromPtr(&user_mapping_poller_entry) };
    var cfg: m.Config = .{ .version = 2, .main_thread = c.main_thread, .targets = @splat(0), .native_table = image_base + 0xeb1a70 - 0x400000, .native_owners = image_base + 0xead92c - 0x400000, .original_source_valid = c.original_source_valid };
    var pages: [8]usize = undefined;
    var old: [8]u32 = undefined;
    var page_count: usize = 0;
    for (addresses, lengths, 0..) |address, length, i| {
        const trampoline = new_slab + i * 16;
        const value = expected(i);
        @memcpy(memory(trampoline, length), value[0..length]);
        if (i == 5 or i == 6) win.store(u8, trampoline + length, 0xc3) else {
            win.store(u8, trampoline + length, 0xe9);
            win.store(u32, trampoline + length + 1, @truncate(address -% trampoline -% 5));
        }
        cfg.targets[i] = trampoline;
        const page = address & ~@as(usize, 4095);
        if (std.mem.indexOfScalar(usize, pages[0..page_count], page) == null) {
            pages[page_count] = page;
            page_count += 1;
        }
    }
    var protected: usize = 0;
    while (protected < page_count) : (protected += 1) if (!protect(pages[protected], 4096, 0x40, &old[protected])) break;
    if (protected != page_count or c.install_allowed.?(c.user) == 0 or user_mapping_configure(&cfg) == 0) {
        if (!restorePages(pages[0..protected], old[0..protected])) disableInstallation();
        _ = win.VirtualFree(new_slab, 0, 0x8000);
        return 0;
    }
    slab = new_slab;
    main_thread = c.main_thread;
    for (addresses, lengths, entrypoints, 0..) |address, length, target, i| {
        targets[i] = target;
        win.store(u8, address, 0xe9);
        win.store(u32, address + 1, @truncate(target -% address -% 5));
        @memset(memory(address + 5, length - 5), 0x90);
    }
    var publication_ok = restorePages(pages[0..protected], old[0..protected]);
    if (!flush(new_slab, 8 * 16)) publication_ok = false;
    for (pages[0..page_count]) |page| if (!flush(page, 4096)) {
        publication_ok = false;
    };
    if (!publication_ok) {
        disableInstallation();
        return 0;
    }
    @atomicStore(i32, &clonewars_user_mapping_installed, 127, .seq_cst);
    if (user_mapping_install_ready() == 0 or user_mapping_binding_ready(127) == 0 or user_mapping_enable() == 0) {
        disableInstallation();
        return 0;
    }
    return 1;
}
fn testSlab() callconv(.c) usize {
    return slab;
}
comptime {
    if (testing) @export(&testSlab, .{ .name = "user_mapping_test_slab" });
    asm (
        \\.text
        \\.globl _mapping_user0_a_thunk
        \\_mapping_user0_a_thunk:
        \\ pushl _mapping_resume_a
        \\ jmp _user_mapping_user0_a_entry
        \\.globl _mapping_user0_b_thunk
        \\_mapping_user0_b_thunk:
        \\ pushl _mapping_resume_b
        \\ jmp _user_mapping_user0_b_entry
    );
}
