const std = @import("std");
pub const p = @import("protocol.zig");
pub const win = @import("win32.zig");
pub const state = @import("tick_state.zig");
pub const input = @import("tick_input.zig");
pub const clock = @import("tick_clock.zig");
pub const world = @import("tick_world.zig");
pub const actor = @import("tick_actor.zig");
pub const pose = @import("tick_pack_pose.zig");
pub const pack = @import("tick_pack_control.zig");
pub const sites = @import("tick_sites.zig");
pub const machine = @import("tick_journal_machine_fixture.zig");
pub const check = @import("native_test_support.zig").check;
const Token = @import("cohort_types.zig").Token;
pub var bound = std.mem.zeroes(Token);
pub var phase: u32 = 1;
pub var faults: u32 = 0;
pub var alive = true;
pub var lan_state: i32 = 0;
pub var turret_pilot: usize = 0;
pub var turret_pilot_generation: u32 = 17;
pub var pack_target_mutation: u32 = 0;
pub var retained_target_bound = false;
export fn entities_spawn_source(actor_value: usize, site: *u32) p.SyncSpawnSource {
    if (actor_value != turret_pilot) return .{ .producer = 0, .serial = 0 };
    site.* = 0x5c64b1;
    return .{ .producer = 8, .serial = 0 };
}
export fn entities_bind_native_reference(ref: *const p.SyncActor, actor_value: usize) c_int {
    if (actor_value != turret_pilot or ref.slot != 12 or ref.generation != turret_pilot_generation or ref.character != 183 or ref.spawn_tag != 0x5c64b1 or ref.spawn_source.producer != 8 or ref.spawn_source.serial != 0) return 0;
    retained_target_bound = true;
    return 1;
}
export fn entities_update() void {}
export fn entities_observed_generation(actor_value: usize) u32 {
    return if (actor_value == turret_pilot) 29 else 0;
}
export fn entities_allocation_retained(actor_value: usize, generation: u32) c_int {
    return @intFromBool(actor_value == turret_pilot and generation == 29 and pack_target_mutation != 2 and win.load(u32, actor_value + 0x50) & 1 != 0);
}
export fn entities_actor(slot: u32, generation: u32) usize {
    if (slot != 12 or generation != turret_pilot_generation) return 0;
    if (pack_target_mutation == 3 and !retained_target_bound) return 0;
    if (pack_target_mutation == 1) turret_pilot_generation += 1;
    return turret_pilot;
}
export fn entities_resolve_identity(_: *const p.SyncFrame, _: u32, _: u32) usize {
    return 0;
}
pub export var getter_calls: u32 = 0;
pub export var getter_sample: u32 = 0;
pub var wait_draws: u32 = 0;
pub const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
var storage: usize = 0;
var used: usize = 0;
pub export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("gizmo_source.zig");
    _ = @import("global_pack.zig");
    _ = @import("rts_sources.zig");
    _ = machine;
    _ = @import("tick_pack_mutation.zig");
}
export fn lan_status() i32 {
    return lan_state;
}
export fn game_sync_status() c_int {
    return if (alive) 2 else 0;
}
export fn game_sync_epoch() u32 {
    return bound.epoch;
}
export fn world_vars_cohort_valid(token: *const Token, phases: u32) c_int {
    return @intFromBool(alive and token.frame == bound.frame and token.epoch == bound.epoch and token.sequence == bound.sequence and token.cohort_nonce == bound.cohort_nonce and phases & (@as(u32, 1) << @intCast(phase)) != 0);
}
export fn game_sync_native_fault(code: c_int) void {
    check(@src(), code == 22);
    faults += 1;
}
export fn entities_slot(value: usize) c_int {
    return if (value == turret_pilot) 12 else -1;
}
export fn entities_generation(value: usize) u32 {
    return if (value == turret_pilot) turret_pilot_generation else 0;
}
export fn entities_bind_native_actor(_: *const p.SyncFrame, _: usize) c_int {
    return 0;
}
export fn game_sync_preload_flow_input(_: usize, request: u32) u32 {
    return request;
}
export fn game_sync_preload_level() c_int {
    return -1;
}
export fn game_sync_preload_track_input(_: *const [2]u32, time: u32) u32 {
    return time;
}
pub fn waitOriginal() callconv(.c) f32 {
    wait_draws += 1;
    return 0.25;
}
pub fn addr(value: anytype) usize {
    return switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => @intCast(value),
        .pointer => |info| if (info.size == .slice) @intFromPtr(value.ptr) else @intFromPtr(value),
        else => @compileError("fixture address required"),
    };
}
pub fn put(value: anytype, offset: usize, bits: anytype) void {
    win.store(u32, addr(value) + offset, @intCast(addr(bits)));
}
pub fn shortPut(value: anytype, offset: usize, bits: i16) void {
    win.store(i16, addr(value) + offset, bits);
}
pub fn word(value: anytype, offset: usize) u32 {
    return win.load(u32, addr(value) + offset);
}
pub fn equal(a: anytype, b: anytype, length: usize) bool {
    return std.mem.eql(u8, @as([*]const u8, @ptrFromInt(addr(a)))[0..length], @as([*]const u8, @ptrFromInt(addr(b)))[0..length]);
}
pub fn copy(a: anytype, b: anytype, length: usize) void {
    @memcpy(@as([*]u8, @ptrFromInt(addr(a)))[0..length], @as([*]const u8, @ptrFromInt(addr(b)))[0..length]);
}
pub fn buffer(length: usize) []u8 {
    used = std.mem.alignForward(usize, used, 16);
    check(@src(), used + length <= 0x1000000);
    const result = @as([*]u8, @ptrFromInt(storage + used))[0..length];
    used += length;
    @memset(result, 0);
    return result;
}
pub fn begin(host: bool) void {
    phase = 1;
    check(@src(), input.native_tick_begin(frame, @intFromBool(host), &bound) != 0);
    phase = 2;
}
pub fn next(host: bool) void {
    frame.epoch += 1;
    bound.epoch += 1;
    begin(host);
}
pub fn finish() bool {
    return input.native_tick_finish() != 0;
}
pub fn stream(start: usize, count: usize) bool {
    return @import("tick_validation.zig").streamValid(frame.tick_gates[start..][0..count]);
}
pub fn cancel() void {
    input.native_tick_cancel(&bound);
}
pub fn reset(group: u32) void {
    cancel();
    @memset(std.mem.asBytes(frame), 0);
    frame.epoch = 10000 + group * 1000;
    frame.sequence = 1;
    frame.level = 6;
    bound = std.mem.zeroes(Token);
    bound.frame = @intFromPtr(frame);
    bound.epoch = frame.epoch;
    bound.sequence = 1;
    bound.cohort_nonce = 7;
    alive = true;
    faults = 0;
    lan_state = 0;
    used = 0;
    put(0xfb4b6c, 0, 100);
}
pub fn open() void {
    check(@src(), @intFromPtr(&image) < 0x431000 and @intFromPtr(&image) + image.len > 0xfc0000);
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(@intFromPtr(&image), image.len, 0x40, &old) != 0);
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    storage = win.VirtualAlloc(0, 0x1000000, 0x3000, 4);
    check(@src(), storage != 0);
}
pub fn close() void {
    cancel();
    check(@src(), win.VirtualFree(storage, 0, 0x8000) != 0 and win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
}
pub fn patch(address: usize, code: []const u8) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, code.len, 0x40, &old) != 0);
    copy(address, code, code.len);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, code.len) != 0);
}
pub const Numeric = struct {
    cw0: u16 = 0,
    cw1: u16 = 0,
    mx0: u32 = 0,
    mx1: u32 = 0,
    retained: f64 = 0,
    pub fn push(self: *@This()) void {
        asm volatile ("fnstcw (%[cw]); stmxcsr (%[mx]); fld1"
            :
            : [cw] "r" (&self.cw0),
              [mx] "r" (&self.mx0),
            : .{ .memory = true });
    }
    pub fn pop(self: *@This()) void {
        asm volatile ("fstpl (%[value]); fnstcw (%[cw]); stmxcsr (%[mx])"
            :
            : [value] "r" (&self.retained),
              [cw] "r" (&self.cw1),
              [mx] "r" (&self.mx1),
            : .{ .memory = true });
    }
    pub fn verify(self: *const @This()) void {
        check(@src(), self.retained == 1 and self.cw0 == self.cw1 and self.mx0 == self.mx1);
    }
};
