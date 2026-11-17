const admission = @import("spellit_admission.zig");
const Machine = @import("machine_environment.zig").Environment;
const default_mxcsr: u32 = 0x1f80;
pub export var spellit_actor_eligible_native: usize = 0x8c2610;
pub export var spellit_action_matches_native: usize = 0x9f7650;
pub export fn spellit_actor_eligible(actor: usize) u32 {
    const native: *const fn (usize) callconv(.c) u32 = @ptrFromInt(spellit_actor_eligible_native);
    const local = native(actor);
    var machine: Machine = undefined;
    machine.save(&default_mxcsr);
    defer machine.restore();
    return admission.cadence_spellit_admission(actor, 0, 2, @intFromBool(local != 0));
}
pub export fn spellit_action_matches(actor: usize, action: i32) u32 {
    const native: *const fn (usize, i32) callconv(.c) u32 = @ptrFromInt(spellit_action_matches_native);
    const local = native(actor, action);
    var machine: Machine = undefined;
    machine.save(&default_mxcsr);
    defer machine.restore();
    return admission.cadence_spellit_admission(actor, 0, 3, @intFromBool(local != 0));
}
