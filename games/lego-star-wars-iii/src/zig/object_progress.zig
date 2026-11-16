const std = @import("std");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const Machine = @import("machine_environment.zig").Environment;
const Update = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Regen = *const fn (usize, u8, u8, u32, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
const Source = struct { token: Token, world: usize, container: usize, handle: usize, table: usize, provider: usize, manager: usize, index: u32, count: u32, delta: f32, pending: bool };
threadlocal var source = std.mem.zeroes(Source);
var installed = false;
pub export var clonewars_object_progress_debug: [4]u32 = @splat(0);
pub export var clonewars_object_progress_failure: [12]u32 = @splat(0);
extern fn lan_status() c_int;
extern fn game_sync_epoch() u32;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn game_sync_native_fault(c_int) void;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn readable(address: usize, length: usize) bool {
    return length != 0 and win.accessible(address, length, false);
}
fn networked() bool {
    return lan_status() == 3 and game_sync_epoch() != 0;
}
fn live(token: *const Token) bool {
    return coherent_frame_valid(token, 4) != 0;
}
fn witness(s: *Source) bool {
    if (!readable(s.world, 0x22e8)) return false;
    s.container = read(usize, s.world + 0x22e4);
    s.handle = read(usize, s.world + 0x400);
    s.provider = read(usize, 0xe901dc);
    const registry = read(usize, 0xe90184);
    if (!readable(s.container, 0x10) or read(usize, s.container + 0xc) != s.world or !readable(s.handle, 4) or !readable(s.provider, 0x3c) or !readable(registry, 0x2c)) return false;
    s.index = read(u32, s.provider + 0x38);
    s.count = read(u32, registry + 0x28);
    s.table = read(usize, s.handle);
    if (s.count == 0 or s.count > 4096 or s.index >= s.count or !readable(s.table, s.count * 4)) return false;
    s.manager = read(usize, s.table + s.index * 4);
    return readable(s.manager, 0x28) and read(u32, s.manager) == 0xc4c8ec;
}
fn sameWitness(s: *const Source) bool {
    var now = std.mem.zeroes(Source);
    now.world = s.world;
    return witness(&now) and now.container == s.container and now.handle == s.handle and now.table == s.table and now.provider == s.provider and now.manager == s.manager and now.index == s.index and now.count == s.count;
}
fn member(s: *const Source, object: usize) bool {
    var node = read(usize, s.manager + 0x24);
    var n: u32 = 0;
    while (node != 0 and n < 65536) : (n += 1) {
        if (!readable(node, 0x28)) return false;
        if (node == object) return true;
        node = read(usize, node + 0x24);
    }
    return false;
}
fn reject(reason: u32, s: *const Source) void {
    clonewars_object_progress_debug[3] +%= 1;
    if (clonewars_object_progress_failure[2] == 0) clonewars_object_progress_failure = .{ s.token.epoch, s.token.sequence, reason, read(u32, 0xfb4b6c), @truncate(s.world), read(u32, 0xfb4a20), @truncate(s.manager), @truncate(s.provider), s.index, s.count, @bitCast(s.delta), @intFromBool(s.pending) };
    game_sync_native_fault(15);
}
fn updateHook(manager: usize, _: usize, delta: u32) callconv(.{ .x86_fastcall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    var token = std.mem.zeroes(Token);
    const bound = networked() and coherent_frame_get(&token, 4) != 0;
    var next = std.mem.zeroes(Source);
    next.token = token;
    next.delta = @bitCast(delta);
    if (bound) {
        next.world = read(usize, 0xfb4a20);
        if (!std.math.isFinite(next.delta) or next.delta < 0 or next.delta > 0.1 or !witness(&next) or next.manager != manager or (source.pending and live(&source.token))) reject(1, &next) else next.pending = true;
    }
    const update: Update = @ptrFromInt(0x87c930);
    machine.restore();
    update(manager, delta);
    machine.capture();
    if (next.pending and live(&next.token)) {
        if (sameWitness(&next)) source = next else reject(2, &next);
    }
    machine.restore();
}
fn renderRegen(provider: usize, _: usize, current: u8, maximum: u8, delta: f32, enabled: c_int) callconv(.{ .x86_fastcall = .{} }) u8 {
    var machine: Machine = undefined;
    machine.capture();
    const separate = networked();
    if (separate) clonewars_object_progress_debug[1] +%= 1;
    const bits: u32 = if (separate) 0 else @bitCast(delta);
    const regenerate: Regen = @ptrFromInt(0x859240);
    machine.restore();
    return regenerate(provider, current, maximum, bits, if (separate) 0 else enabled);
}
pub export fn object_progress_world_complete(world: usize, token_value: ?*const Token) c_int {
    const token = token_value orelse return 0;
    if (!live(token)) return 0;
    if (source.pending and !live(&source.token)) source = std.mem.zeroes(Source);
    if (!source.pending) return 1;
    const s = source;
    source = std.mem.zeroes(Source);
    if (s.world != world or !equal(&s.token, token) or !sameWitness(&s)) {
        reject(3, &s);
        return 0;
    }
    var node = read(usize, s.manager + 0x24);
    var count: u32 = 0;
    while (node != 0) {
        count += 1;
        if (count > 65536 or !live(&s.token) or !sameWitness(&s) or !readable(node, 0xf4)) {
            reject(4, &s);
            return 0;
        }
        const next = read(usize, node + 0x24);
        const provider = read(usize, node + 0xf0);
        if (read(u8, node + 0x73) == 0 and read(usize, node + 0x88) != 0 and read(u16, node + 0x62) & 3 == 3 and provider != 0) {
            const recipe = read(usize, node + 0x84);
            if (!readable(provider, 0x18) or !readable(recipe, 0x6c)) {
                reject(5, &s);
                return 0;
            }
            const kind = read(usize, node);
            const model = read(usize, node + 0x88);
            const binding = read([4]u32, provider + 8);
            const current = read(u8, node + 0xec);
            const maximum = read(u8, recipe + 0x6b);
            const regenerate: Regen = @ptrFromInt(0x859240);
            const result = regenerate(provider, current, maximum, @bitCast(s.delta), 1);
            if (!live(&s.token) or !sameWitness(&s) or !readable(node, 0xf4) or !readable(provider, 0x18) or !readable(recipe, 0x6c) or read(u8, recipe + 0x6b) != maximum or !equal(&binding, &read([4]u32, provider + 8)) or read(usize, node) != kind or read(usize, node + 0x88) != model or read(u8, node + 0x73) != 0 or read(u16, node + 0x62) & 3 != 3 or read(usize, node + 0xf0) != provider or read(usize, node + 0x84) != recipe or read(usize, node + 0x24) != next or read(u8, node + 0xec) != current) {
                reject(6, &s);
                return 0;
            }
            if (result != current) {
                if (!member(&s, node) or !live(&s.token)) {
                    reject(7, &s);
                    return 0;
                }
                win.store(u8, node + 0xec, result);
            }
            clonewars_object_progress_debug[0] +%= 1;
        }
        node = next;
    }
    clonewars_object_progress_debug[2] +%= 1;
    return @intFromBool(live(&s.token));
}
pub export fn object_progress_install() c_int {
    if (installed) return 1;
    const slot: usize = 0xc4c92c;
    const call: usize = 0x85cacb;
    if (!readable(slot, 4) or read(usize, slot) != 0x87c930 or !readable(call, 5) or read(u8, call) != 0xe8 or call +% 5 +% read(u32, call + 1) != 0x859240) return 0;
    var call_protection: u32 = 0;
    var slot_protection: u32 = 0;
    var ignored: u32 = 0;
    if (win.VirtualProtect(call, 5, 0x40, &call_protection) == 0) return 0;
    if (win.VirtualProtect(slot, 4, 4, &slot_protection) == 0) {
        _ = win.VirtualProtect(call, 5, call_protection, &ignored);
        return 0;
    }
    win.store(u32, call + 1, @truncate(@intFromPtr(&renderRegen) -% call -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), call, 5);
    win.store(usize, slot, @intFromPtr(&updateHook));
    _ = win.VirtualProtect(call, 5, call_protection, &ignored);
    _ = win.VirtualProtect(slot, 4, slot_protection, &ignored);
    installed = true;
    return 1;
}
