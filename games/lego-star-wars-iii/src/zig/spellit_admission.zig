const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
pub export var clonewars_spellit_admission_debug: [4]u32 = @splat(0);
pub export fn cadence_spellit_admission(actor: usize, kind: u32, stage: u32, local: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return local;
    const local_valid = if (stage == 0) local == 0 or local == actor +% 0xee4 or local == actor +% 0xeec or local == actor +% 0xef0 else local <= 1;
    if (stage > 1 or (kind != 0x24 and kind != 0x25) or !s.valid(actor, 0x1440) or !local_valid) {
        s.journal.failed = 20;
        s.failed(&op, actor, null, 20);
        return local;
    }
    var state = std.mem.zeroes(p.SyncFireTaskState);
    state.repeat = s.read(u32, 0xfb4b6c);
    const result = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, @intCast(stage), @intCast(kind), @intFromBool(local != 0), @ptrCast(&state), &clonewars_spellit_admission_debug);
    return if ((local != 0) == (result != 0)) local else @bitCast(result);
}
