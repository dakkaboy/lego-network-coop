const std = @import("std");
const s = @import("projectile_state.zig");
const t = s.t;
const control = @import("projectile_control.zig");
const Scope = @import("shooter_types.zig").Scope;
const Machine = @import("machine_environment.zig").Environment;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn shooter_observer_fire_begin(*Scope, usize, usize, c_int, usize, usize, u32) c_int;
extern fn shooter_observer_fire_end(*Scope) void;
extern fn shooter_observer_fire_abort(*Scope) void;
extern fn combat_observer_fire_requested() void;
extern fn projectile_fire_complete(*Call, usize) void;
const Call = struct { fire: t.Fire, observation: Scope, observing: bool, receiver: usize, actor: usize, output1: usize, output2: usize, weapon: usize, mode: c_int };
fn unlink(call: *Call) void {
    if (s.active_fire == &call.fire and call.fire.cleanup_stamp == s.fire_cleanup_stamp) s.active_fire = if (control.live(&call.fire.operation)) call.fire.previous else null;
}
fn invoke(context: usize) callconv(.c) usize {
    const call: *Call = @ptrFromInt(context);
    const native: t.FireNative = @ptrFromInt(0x879710);
    native(call.receiver, call.actor, call.weapon, call.mode, call.output1, call.output2);
    return 0;
}
fn abort(context: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const call: *Call = @ptrFromInt(context);
    if (call.observing) shooter_observer_fire_abort(&call.observation);
    control.exception(&call.fire.operation);
    unlink(call);
}
export fn projectile_fire_complete_impl(call: *Call, _: usize) void {
    if (!control.live(&call.fire.operation)) {
        if (call.observing) shooter_observer_fire_abort(&call.observation);
        unlink(call);
        return;
    }
    if (call.observing) shooter_observer_fire_end(&call.observation);
    unlink(call);
}
pub export fn projectile_fire_hook(receiver: usize, actor: usize, weapon: usize, mode: c_int, output1: usize, output2: usize) callconv(.{ .x86_thiscall = .{} }) void {
    var call = std.mem.zeroes(Call);
    call.receiver = receiver;
    call.actor = actor;
    call.weapon = weapon;
    call.mode = mode;
    call.output1 = output1;
    call.output2 = output2;
    call.fire.operation = control.capture();
    control.admit(&call.fire.operation);
    call.fire.previous = s.active_fire;
    call.fire.cleanup_stamp = s.fire_cleanup_stamp;
    call.fire.actor = actor;
    call.fire.caller = @truncate(@returnAddress());
    call.fire.mode = mode;
    if (call.fire.operation.kind == t.keyed and control.live(&call.fire.operation)) {
        call.fire.local_generation = s.entities_observed_generation(actor);
        if (control.live(&call.fire.operation)) {
            call.observing = shooter_observer_fire_begin(&call.observation, actor, weapon, mode, output1, output2, call.fire.caller) != 0;
            if (control.live(&call.fire.operation)) {
                combat_observer_fire_requested();
                s.clonewars_fire_debug[0] +%= 1;
            }
        }
    }
    s.active_fire = &call.fire;
    _ = constructor_lexical_seh(@intFromPtr(&call), invoke, abort);
    projectile_fire_complete(&call, 0);
}
comptime {
    asm (@import("native_completion.zig").code("projectile_fire_complete", "projectile_fire_complete_impl"));
}
