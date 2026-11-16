const std = @import("std");
const win = @import("win32.zig");
const Machine = @import("machine_environment.zig").Environment;
pub const Record = extern struct {
    committed: u32,
    id: u32,
    parent: u32,
    thread: u32,
    caller: u32,
    epoch: u32,
    sequence: u32,
    clock_before: u32,
    rng_game_before: u32,
    rng_engine_before: u32,
    qpc_before: [2]u32,
    clock_after: u32,
    rng_game_after: u32,
    rng_engine_after: u32,
    qpc_after: [2]u32,
    descriptor_local: u32,
    second_raw: u32,
    descriptor_valid: u32,
    descriptor: [252]u8,
    pool_before: u32,
    capacity_before: u32,
    cursor_before: u32,
    pool_after: u32,
    capacity_after: u32,
    cursor_after: u32,
    result_local: u32,
    pool_index_valid: u32,
    pool_index: u32,
    payload_valid: u32,
    payload: [552]u8,
};
const Birth = *const fn (usize, u32) callconv(.c) usize;
var original: Birth = undefined;
threadlocal var active_birth: u32 = 0;
pub export var clonewars_pool_birth_enabled: i32 = 0;
pub export var clonewars_pool_birth_installed: i32 = 0;
pub export var clonewars_pool_birth_count: u32 = 0;
pub export var clonewars_pool_birth_version: u32 = 1;
pub export var clonewars_pool_birth_stride: u32 = @sizeOf(Record);
pub export var clonewars_pool_birth_capacity: u32 = 256;
pub export var clonewars_pool_birth_records: [256]Record = std.mem.zeroes([256]Record);
extern "kernel32" fn QueryPerformanceCounter(*i64) callconv(.winapi) i32;
extern fn game_sync_epoch() u32;
extern fn game_sync_sequence() u32;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
fn localRead(address: usize, output: []u8) bool {
    if (!win.accessible(address, output.len, false)) return false;
    @memcpy(output, @as([*]const u8, @ptrFromInt(address))[0..output.len]);
    return true;
}
fn word(address: usize) u32 {
    var value: u32 = 0;
    _ = localRead(address, std.mem.asBytes(&value));
    return value;
}
fn stamp(clock: *u32, game: *u32, engine: *u32, qpc: *[2]u32) void {
    clock.* = word(0xfb4b6c);
    game.* = word(0xe637b4);
    engine.* = word(0xea178c);
    var counter: i64 = 0;
    _ = QueryPerformanceCounter(&counter);
    qpc.* = @bitCast(counter);
}
fn pool(base: *u32, count: *u32, cursor: *u32) void {
    base.* = word(0xfa3d38);
    count.* = word(0xe5f480);
    cursor.* = word(0xe5f488);
}
const Scope = struct { machine: Machine, record: Record, previous: u32, result: usize };
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    const r = &s.record;
    active_birth = r.id;
    s.machine.restore();
    s.result = original(r.descriptor_local, r.second_raw);
    s.machine.capture();
    asm volatile ("fninit" ::: .{ .memory = true });
    active_birth = s.previous;
    r.result_local = @truncate(s.result);
    pool(&r.pool_after, &r.capacity_after, &r.cursor_after);
    if (r.pool_after != 0 and r.capacity_after != 0 and r.result_local >= r.pool_after) {
        const offset = r.result_local - r.pool_after;
        if (offset % 552 == 0 and offset / 552 < r.capacity_after) {
            r.pool_index_valid = 1;
            r.pool_index = offset / 552;
        }
    }
    r.payload_valid = @intFromBool(localRead(s.result, &r.payload));
    stamp(&r.clock_after, &r.rng_game_after, &r.rng_engine_after, &r.qpc_after);
    const target = &clonewars_pool_birth_records[(r.id -% 1) % 256];
    @atomicStore(u32, &target.committed, 0, .seq_cst);
    target.* = r.*;
    @atomicStore(u32, &target.committed, r.id, .seq_cst);
    return s.result;
}
fn abort(address: usize) callconv(.c) void {
    const s: *Scope = @ptrFromInt(address);
    active_birth = s.previous;
}
fn observed(descriptor: usize, second: u32, caller: u32) usize {
    var s: Scope = undefined;
    s.machine.capture();
    asm volatile ("fninit" ::: .{ .memory = true });
    s.record = std.mem.zeroes(Record);
    s.previous = active_birth;
    s.result = 0;
    const r = &s.record;
    r.id = @atomicRmw(u32, &clonewars_pool_birth_count, .Add, 1, .seq_cst) +% 1;
    r.parent = s.previous;
    r.thread = win.GetCurrentThreadId();
    r.caller = caller;
    r.epoch = game_sync_epoch();
    r.sequence = game_sync_sequence();
    r.descriptor_local = @truncate(descriptor);
    r.second_raw = second;
    r.descriptor_valid = @intFromBool(localRead(descriptor, r.descriptor[0..250]));
    pool(&r.pool_before, &r.capacity_before, &r.cursor_before);
    stamp(&r.clock_before, &r.rng_game_before, &r.rng_engine_before, &r.qpc_before);
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
    return s.result;
}
fn hook(descriptor: usize, second: u32) callconv(.c) usize {
    if (clonewars_pool_birth_enabled == 0) return original(descriptor, second);
    return observed(descriptor, second, @truncate(@returnAddress()));
}
pub export fn pool_birth_observer_install() c_int {
    const site: usize = 0x741f90;
    const expected = "\x6a\xff\x68\x76\xcf\xaa\x00";
    if (!win.accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected)) {
        clonewars_pool_birth_installed = -1;
        return 0;
    }
    const bridge = win.VirtualAlloc(0, 12, 0x3000, 0x40);
    if (bridge == 0) {
        clonewars_pool_birth_installed = -1;
        return 0;
    }
    var old: u32 = 0;
    if (win.VirtualProtect(site, 7, 0x40, &old) == 0) {
        _ = win.VirtualFree(bridge, 0, 0x8000);
        clonewars_pool_birth_installed = -1;
        return 0;
    }
    win.store([7]u8, bridge, expected[0..7].*);
    win.store(u8, bridge + 7, 0xe9);
    win.store(u32, bridge + 8, @truncate(site -% bridge -% 5));
    original = @ptrFromInt(bridge);
    win.store(u8, site, 0xe9);
    win.store(u32, site + 1, @truncate(@intFromPtr(&hook) -% site -% 5));
    win.store(u16, site + 5, 0x9090);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, 12);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, 7);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(site, 7, old, &ignored);
    clonewars_pool_birth_installed = 1;
    return 1;
}
comptime {
    std.debug.assert(@sizeOf(Record) == 924 and @offsetOf(Record, "descriptor") == 80 and @offsetOf(Record, "pool_before") == 332 and @offsetOf(Record, "payload") == 372);
}
