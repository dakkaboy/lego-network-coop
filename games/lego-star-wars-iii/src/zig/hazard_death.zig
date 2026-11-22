const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
pub export var clonewars_hazard_death_debug: [4]u32 = @splat(0);
pub export var clonewars_hazard_observer_enabled: u32 = 0;
pub export var clonewars_hazard_source_debug: [16]u32 = @splat(0);
pub export fn cadence_hazard_death(actor: usize, status: u32, controller: usize, frame: usize) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const mask = (status >> 8) & 0x41;
    var op: s.Lease = undefined;
    if (!s.ready(&op)) return mask;
    if (clonewars_hazard_observer_enabled != 0) {
        const word = @import("observation.zig").word;
        const path = word(controller +% 4);
        const model = word(path +% 4);
        const definition = word(word(model +% 0xd8) +% 0x2c);
        const count = clonewars_hazard_source_debug[0] +% 1;
        @atomicStore(u32, &clonewars_hazard_source_debug[0], 0, .seq_cst);
        clonewars_hazard_source_debug[1..].* = .{ op.cohort.epoch, op.cohort.sequence, word(0xfb4b6c), actor, controller, word(frame +% 4), path, model, definition, word(definition +% 0x130) & 255, word(path +% 0x158), frame, word(controller), word(frame), word(frame +% 8) };
        @atomicStore(u32, &clonewars_hazard_source_debug[0], count, .seq_cst);
    }
    if (!s.valid(actor, 0x1440)) {
        s.journal.failed = 21;
        s.failed(&op, actor, null, 21);
        return 0x40;
    }
    const packet = s.journal.frame.?;
    // Geonosis can reach the boundary check on the guest after the host's last actor gate.
    // Without a host decision the guest must leave the actor alive.
    if (packet.level == 79 and s.journal.host == 0 and s.fire_task_cursor == packet.fire_task_gate_count) {
        return if (mask != 0) mask else 0x40;
    }
    var state = std.mem.zeroes(p.SyncFireTaskState);
    state.repeat = s.read(u32, 0xfb4b6c);
    const crossed = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_HAZARD_DEATH, 0, 0, @intFromBool(mask == 0), @ptrCast(&state), &clonewars_hazard_death_debug);
    // Keep the native TEST parity when the moving boundary decision agrees with the host.
    return if (crossed != 0) 0 else if (mask != 0) mask else 0x40;
}
