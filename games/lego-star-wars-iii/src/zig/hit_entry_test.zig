const std = @import("std");
const hit = @import("hit_entry.zig");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const Identity = @import("projectile_types.zig").Identity;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
var token = std.mem.zeroes(Token);
var session: u32 = 17;
var active = true;
var attach = true;
var reads: u32 = 0;
var cancel_read: u32 = 0;
var retire_read: u32 = 0;
var generation: u32 = 23;
var observed_generation: u32 = 23;
var native_calls: u32 = 0;
var native_error: u32 = 0;
var native_numeric: u16 = 0;
pub const hit_test_api = struct {
    pub fn lan_session_serial() u32 {
        return session;
    }
    pub fn coherent_frame_get(out: *Token, _: u32) c_int {
        out.* = token;
        return @intFromBool(active);
    }
    pub fn coherent_frame_valid(value: *const Token, phases: u32) c_int {
        return @intFromBool(active and phases == 4 and std.meta.eql(value.*, token));
    }
    pub fn entities_observed_generation(_: usize) u32 {
        return generation;
    }
    pub fn entities_allocation_live(_: usize, value: u32) c_int {
        return @intFromBool(value == 23 and generation == 23);
    }
    pub fn entities_observed_identity(pointer: usize, slot: *u32, value: *u32) c_int {
        slot.* = if (pointer == 0x1000) 1 else 2;
        value.* = observed_generation;
        return 1;
    }
    pub fn projectiles_observe_live(_: usize, out: *Identity) c_int {
        out.* = .{ .status = 1, .id = 29, .owner = 1, .weapon = 7, .owner_generation = 23, .resource_local = 0, .instance_serial = 31, .creation_count = 2 };
        return 1;
    }
    pub fn combat_damage_native_caller() u32 {
        return 0x969696;
    }
    pub fn combat_hit_bridge_attach(_: *const Token, _: usize, continuation: *usize) c_int {
        if (!attach) return 0;
        continuation.* = @intFromPtr(&nativeHit);
        return 1;
    }
    pub fn read(address: usize, output: []u8) bool {
        reads += 1;
        if (reads == cancel_read) active = false;
        if (reads == retire_read) generation += 1;
        win.SetLastError(999);
        switch (address) {
            0x1008, 0x2008 => @memcpy(output, std.mem.asBytes(&@as(u32, 0x5555))),
            0x1dc0, 0x2dc0 => @memcpy(output, std.mem.asBytes(&@as(u16, 12))),
            0x1dde, 0x2dde => @memcpy(output, std.mem.asBytes(&@as(i8, -1))),
            0xfb4b6c => @memcpy(output, std.mem.asBytes(&@as(u32, 43))),
            0xfbcb2c => @memcpy(output, std.mem.asBytes(&@as(u32, 0x3000))),
            else => return false,
        }
        return true;
    }
};
fn nativeHit(attacker: u32, victim: u32, a: u32, b: u32, c: u32, d: u32) callconv(.c) u32 {
    native_calls += 1;
    native_error = win.GetLastError();
    asm volatile ("fnstcw (%[out])"
        :
        : [out] "r" (&native_numeric),
        : .{ .memory = true });
    check(@src(), attacker == 0x1000 and victim == 0x2000 and a == 3 and b == 4 and c == 5 and d == 6);
    return 0x8181;
}
extern fn hit_entry_thunk(u32, u32, u32, u32, u32, u32) callconv(.c) u32;
fn checkpoint() void {
    var registers: [16]u32 = @splat(0);
    registers[10..16].* = .{ 0x1000, 0x2000, 3, 4, 5, 6 };
    var fx: [512]u8 align(16) = @splat(0);
    @memcpy(fx[0..2], std.mem.asBytes(&@as(u16, 0x27f)));
    @memcpy(fx[24..28], std.mem.asBytes(&@as(u32, 0x1f80)));
    hit.hit_entry_checkpoint(&registers, &fx);
}
pub fn main() void {
    token.thread = win.GetCurrentThreadId();
    token.epoch = 7;
    token.sequence = 2;
    check(@src(), hit.clonewars_hit_entry_stride == 168 and hit.clonewars_hit_entry_version == 3);
    check(@src(), hit.hit_entry_install(null) == 0);
    active = false;
    check(@src(), hit.hit_entry_install(&token) == 0);
    active = true;
    attach = false;
    check(@src(), hit.hit_entry_install(&token) == 0);
    attach = true;
    hit.hit_entry_poll(&token);
    check(@src(), hit.clonewars_hit_entry_installed == 0);
    hit.clonewars_hit_entry_request = 1;
    hit.hit_entry_poll(&token);
    check(@src(), hit.clonewars_hit_entry_installed == 1 and hit.hit_entry_install(&token) == 1);
    checkpoint();
    check(@src(), hit.clonewars_hit_entry_count == 0);
    hit.clonewars_hit_entry_enabled = 1;
    checkpoint();
    check(@src(), hit.clonewars_hit_entry_count == 1);
    const first = &hit.clonewars_hit_entry_ring[0];
    check(@src(), first.committed == 1 and first.epoch == 7 and first.sequence == 2 and first.clock == 43);
    check(@src(), first.attacker.slot == 1 and first.victim.slot == 2 and first.attacker.health == 0xffffffff and first.victim.model == 0x5555);
    check(@src(), first.shot_id == 29 and first.shot_generation == 23 and first.instance_serial == 31 and first.cw == 0x27f and first.mxcsr == 0x1f80);
    for (1..9) |read| {
        reads = 0;
        cancel_read = @intCast(read);
        active = true;
        checkpoint();
        check(@src(), hit.clonewars_hit_entry_count == 1);
    }
    cancel_read = 0;
    active = true;
    for (1..7) |read| {
        reads = 0;
        retire_read = @intCast(read);
        generation = 23;
        checkpoint();
        check(@src(), hit.clonewars_hit_entry_count == 1);
    }
    retire_read = 0;
    generation = 23;
    for (0..513) |_| checkpoint();
    check(@src(), hit.clonewars_hit_entry_count == 514 and hit.clonewars_hit_entry_ring[1].committed == 514);
    hit.clonewars_hit_entry_count = 0x7ffffffe;
    checkpoint();
    check(@src(), hit.clonewars_hit_entry_count == 0x7ffffffe);
    hit.clonewars_hit_entry_count = 0;
    var original: [512]u8 align(16) = @splat(0);
    asm volatile ("fxsave (%[out])"
        :
        : [out] "r" (&original),
        : .{ .memory = true });
    defer @import("machine_environment.zig").restoreFx(&original);
    const cw: u16 = 0x27f;
    asm volatile ("fldcw (%[cw])"
        :
        : [cw] "r" (&cw),
        : .{ .memory = true });
    win.SetLastError(711);
    check(@src(), hit_entry_thunk(0x1000, 0x2000, 3, 4, 5, 6) == 0x8181);
    check(@src(), native_calls == 1 and native_error == 711 and native_numeric == cw);
    check(@src(), hit.clonewars_hit_entry_count == 1 and hit.clonewars_hit_entry_ring[0].cw == cw);
}
