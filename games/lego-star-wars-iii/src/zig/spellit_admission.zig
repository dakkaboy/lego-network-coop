const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
pub export var clonewars_spellit_admission_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_eligibility_debug: [10]u32 = @splat(0);
pub export var clonewars_spellit_manager_debug: [10]u32 = @splat(0);
pub export fn cadence_spellit_admission(actor: usize, kind: u32, stage: u32, local: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return local;
    const local_valid = if (stage == 0) local == 0 or local == actor +% 0xee4 or local == actor +% 0xeec or local == actor +% 0xef0 else local <= 1;
    const valid_kind = if (stage <= 1) kind == 0x24 or kind == 0x25 else kind == 0;
    if (stage > 5 or !valid_kind or !s.valid(actor, 0x1440) or !local_valid) {
        s.journal.failed = 20;
        s.failed(&op, actor, null, 20);
        return local;
    }
    var state = std.mem.zeroes(p.SyncFireTaskState);
    state.repeat = s.read(u32, 0xfb4b6c);
    const result = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, @intCast(stage), @intCast(kind), @intFromBool(local != 0), @ptrCast(&state), &clonewars_spellit_admission_debug);
    if (stage >= 2 and s.live(&op) and s.journal.failed == 0) {
        const debug = if (stage >= 4) &clonewars_spellit_manager_debug else &clonewars_spellit_eligibility_debug;
        const part = if (stage >= 4) stage - 4 else stage - 2;
        debug[part] +%= 1;
        if ((local != 0) != (result != 0)) {
            debug[part + 2] +%= 1;
            if (debug[4] == 0 and s.valid(actor, 0x1440)) debug[4..10].* = .{ state.repeat, stage, s.read(u16, actor + 0xdc0), s.read(u16, actor + 0x2f4), local, @intFromBool(result != 0) };
        }
    }
    return if ((local != 0) == (result != 0)) local else @bitCast(result);
}
