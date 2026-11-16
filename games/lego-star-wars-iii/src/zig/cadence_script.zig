const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const Source = @import("script_shoot_types.zig").Dispatch;
const Binding = extern struct { words: [32]usize };
const Captured = extern struct { lease: s.Lease, actor: usize, generation: u32 };
extern fn native_script_shoot_dispatch_source_revalidate(*const Source) c_int;
extern fn native_script_shoot_dispatch_consume(usize, usize, usize, usize, u32) u32;
fn validSource(source: ?*const Source) ?*const Source {
    const value = source orelse return null;
    return if (s.valid(@intFromPtr(value), @sizeOf(Source))) value else null;
}
fn failed(op: *const s.Lease, source: ?*const Source, reason: u32) void {
    if (!s.live(op) or !s.active or s.journal.failed != 0) return;
    const actor = if (source) |value| value.actor else 0;
    if (s.clonewars_script_shoot_failure[0] == 0) {
        var values: [16]u32 = @splat(0);
        values[0..8].* = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, reason, s.read(u32, 0xfb4b6c), @truncate(actor), if (source) |value| @truncate(value.state) else 0, if (source) |value| @truncate(value.model) else 0, if (source) |value| @truncate(value.native_stack) else 0 };
        if (source) |value| if (s.valid(value.native_stack, 32)) {
            values[8..16].* = s.read([8]u32, value.native_stack);
        };
        s.clonewars_script_shoot_failure = values;
    }
    s.journal.failed = 18;
    s.clonewars_script_shoot_debug[3] +%= 1;
    s.failed(op, actor, null, 18);
}
pub export fn cadence_script_shoot_dispatch_active() c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    return @intFromBool(s.get(&op) and s.active);
}
pub export fn cadence_script_shoot_dispatch_begin(source: ?*const Source, local: u32, canonical: ?*u32, storage: ?*Binding) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (!s.get(&op) or !s.active) return 0;
    if (s.journal.failed != 0) return -1;
    const value = validSource(source) orelse {
        failed(&op, null, 2);
        return -1;
    };
    if (canonical == null or storage == null or native_script_shoot_dispatch_source_revalidate(value) == 0 or !s.live(&op)) {
        failed(&op, validSource(source), 2);
        return -1;
    }
    s.entities_update();
    if (!s.live(&op)) return -1;
    const generation = s.entities_observed_generation(value.actor);
    if (generation == 0) {
        failed(&op, value, 2);
        return -1;
    }
    var input: p.SyncScriptShootState = undefined;
    @memcpy(std.mem.asBytes(&input), std.mem.asBytes(&value.input));
    const visible: c_int = @intFromBool(local != 0);
    const result = @import("cadence_gate.zig").apply(value.actor, p.SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY, 0, 0, visible, @ptrCast(&input), &s.clonewars_script_shoot_debug);
    if (!s.live(&op) or !s.active or s.journal.failed != 0) return -1;
    if (s.entities_observed_generation(value.actor) != generation or native_script_shoot_dispatch_source_revalidate(value) == 0 or !s.live(&op)) {
        failed(&op, value, 2);
        return -1;
    }
    if (s.journal.host == 0 and visible != result and s.clonewars_script_shoot_correction[0] == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var observed: u32 = 0;
        _ = s.entities_observed_identity(value.actor, &slot, &observed);
        s.clonewars_script_shoot_correction = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, slot, generation, @bitCast(visible), @bitCast(result), input.clock, input.state_flags, input.argument_count, input.caller_rva, input.initialize, 0 };
    }
    const captured: Captured = .{ .lease = op, .actor = value.actor, .generation = generation };
    storage.?.* = std.mem.zeroes(Binding);
    @memcpy(std.mem.asBytes(storage.?)[0..@sizeOf(Captured)], std.mem.asBytes(&captured));
    canonical.?.* = @bitCast(result);
    return 1;
}
pub export fn cadence_script_shoot_dispatch_validate(source: ?*const Source, storage: ?*const Binding) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const binding = storage orelse return 0;
    if (!s.valid(@intFromPtr(binding), @sizeOf(Binding))) return 0;
    const captured = s.read(Captured, @intFromPtr(binding));
    if (!s.live(&captured.lease) or !s.active or s.journal.failed != 0) return 0;
    const value = validSource(source) orelse return -1;
    return if (value.actor == captured.actor and s.entities_observed_generation(value.actor) == captured.generation and s.live(&captured.lease)) 1 else -1;
}
pub export fn cadence_script_shoot_dispatch_invalid(source: ?*const Source, storage: ?*const Binding, reason: u32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var op: s.Lease = undefined;
    if (storage) |binding| {
        if (!s.valid(@intFromPtr(binding), @sizeOf(Binding))) return;
        op = s.read(Captured, @intFromPtr(binding)).lease;
    } else if (!s.binding.get(&op)) return;
    failed(&op, validSource(source), reason);
}
pub export fn cadence_script_shoot_visibility(actor: usize, state: usize, model: usize, frame: usize, local: u32) u32 {
    return native_script_shoot_dispatch_consume(actor, state, model, frame, local);
}
comptime {
    std.debug.assert(@sizeOf(Captured) <= @sizeOf(Binding));
}
