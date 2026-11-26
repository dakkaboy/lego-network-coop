const std = @import("std");
const p = @import("protocol.zig");
pub const win = @import("win32.zig");
pub const Lease = @import("cohort_types.zig").Lease;
pub const Journal = @import("journal.zig").Journal("cadence", "cadence_count");
pub export var clonewars_character_motion_debug: [4]u32 = @splat(0);
pub export var clonewars_character_motion_correction: [16]u32 = @splat(0);
pub export var clonewars_character_support_debug: [8]u32 = @splat(0);
pub export var clonewars_character_motion_failure: [40]u32 = @splat(0);
pub export var clonewars_character_support_local: [10]u32 = @splat(0);
pub export var clonewars_character_support_host: [10]u32 = @splat(0);
pub export var clonewars_aim_base_debug: [4]u32 = @splat(0);
pub export var clonewars_aim_base_correction: [12]u32 = @splat(0);
pub export var clonewars_actor_gate_failure: [16]u32 = @splat(0);
pub export var clonewars_force_target_debug: [4]u32 = @splat(0);
pub export var clonewars_force_target_correction: [10]u32 = @splat(0);
pub export var clonewars_force_geometry_debug: [4]u32 = @splat(0);
pub export var clonewars_force_geometry_correction: [20]u32 = @splat(0);
pub export var clonewars_spellit_query_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_query_correction: [20]u32 = @splat(0);
pub export var clonewars_spellit_node_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_node_correction: [24]u32 = @splat(0);
pub export var clonewars_spellit_node_failure: [16]u32 = @splat(0);
pub export var clonewars_script_shoot_debug: [4]u32 = @splat(0);
pub export var clonewars_script_shoot_correction: [12]u32 = @splat(0);
pub export var clonewars_script_shoot_failure: [16]u32 = @splat(0);
pub export var clonewars_rts_competitor_debug: [8]u32 = @splat(0);
pub export var clonewars_rts_competitor_correction: [10]u32 = @splat(0);
pub export var clonewars_cadence_installed: i32 = 0;
pub export var clonewars_cadence_debug: [20]u32 = @splat(0);
pub export var clonewars_cadence_failure: [14]u32 = @splat(0);
pub export var clonewars_fire_task_gate_debug: [4]u32 = @splat(0);
pub export var clonewars_attack_support_debug: [4]u32 = @splat(0);
pub export var clonewars_breakup_visibility_debug: [4]u32 = @splat(0);
pub export var clonewars_breakup_visibility_correction: [8]u32 = @splat(0);
pub export var clonewars_death_breakup_debug: [4]u32 = @splat(0);
pub export var clonewars_death_breakup_correction: [8]u32 = @splat(0);
pub export var clonewars_fall_visibility_debug: [4]u32 = @splat(0);
pub export var clonewars_fall_visibility_correction: [8]u32 = @splat(0);
pub export var clonewars_aim_task_debug: [4]u32 = @splat(0);
pub export var clonewars_aim_task_correction: [12]u32 = @splat(0);
pub export var clonewars_primary_perception_debug: [4]u32 = @splat(0);
pub var journal = std.mem.zeroes(Journal);
pub var binding: @import("cohort_binding.zig").Binding = .{};
pub var active = false;
pub var cancelled = false;
pub var last_epoch: u32 = 0;
pub var fire_task_cursor: u32 = 0;
pub var early_actor_gates: std.StaticBitSet(p.SYNC_MAX_ACTORS) = .empty;
pub const SpellItScope = struct { lease: Lease, actor: usize, manager: usize, native_frame: usize, generation: u32, node_visit: u32, node_gate_start: u32, input: p.SyncSpellItQueryState };
pub threadlocal var spellit_scopes = std.mem.zeroes([64]SpellItScope);
pub threadlocal var spellit_scope_count: usize = 0;
pub const AimTaskScope = struct { lease: Lease, actor: usize, task: usize, generation: u32, visible: c_int, prepared: bool };
pub threadlocal var aim_task_scope = std.mem.zeroes(AimTaskScope);
pub const read = win.load;
pub fn imageClass(address: usize, check_protection: bool) ?u32 {
    const image = win.GetModuleHandleA(null);
    var info: win.MemoryInfo = undefined;
    if (address <= image or win.VirtualQuery(address, &info, @sizeOf(win.MemoryInfo)) == 0 or info.state != 0x1000 or info.allocation_base != image or (check_protection and info.protection & 0x101 != 0)) return null;
    return @truncate(address - image);
}
pub fn bits(value: f32) u32 {
    return @bitCast(value);
}
pub fn valid(address: usize, size: usize) bool {
    return win.accessible(address, size, false);
}
pub extern fn entities_update() void;
pub extern fn entities_describe(*p.SyncActor, usize) void;
pub extern fn entities_slot(usize) c_int;
pub extern fn entities_resolve_reference(*const p.SyncActor) usize;
pub extern fn entities_observed_identity(usize, *u32, *u32) c_int;
pub extern fn entities_observed_generation(usize) u32;
pub extern fn entities_allocation_retained(usize, u32) c_int;
pub extern fn entities_bind_native_reference(*const p.SyncActor, usize) c_int;
pub extern fn entities_actor(u32, u32) usize;
pub extern fn entities_retained_actor(u32, u32) usize;
extern fn game_sync_native_fault(c_int) void;
pub fn live(op: *const Lease) bool {
    return binding.live(op) and journal.frame != null and @intFromPtr(journal.frame.?) == op.cohort.frame;
}
pub fn get(op: *Lease) bool {
    return binding.get(op) and live(op);
}
pub fn ready(op: *Lease) bool {
    return get(op) and active and journal.failed == 0;
}
pub fn failed(op: *const Lease, actor: usize, entry: ?*const p.SyncCadence, reason: u32) void {
    if (!live(op)) return;
    if (clonewars_cadence_failure[0] == 0) {
        var slot: u32 = std.math.maxInt(u32);
        var generation: u32 = 0;
        _ = entities_observed_identity(actor, &slot, &generation);
        if (!live(op)) return;
        clonewars_cadence_failure = .{ journal.frame.?.epoch, journal.frame.?.sequence, if (journal.host != 0) journal.frame.?.cadence_count else journal.cursor, if (entry) |e| e.slot else std.math.maxInt(u32), if (entry) |e| e.generation else 0, slot, generation, reason, if (entry) |e| e.phase else std.math.maxInt(u32), if (valid(actor, 0x1440)) read(u8, actor + 0x57) else std.math.maxInt(u32), if (entry) |e| e.period else 0, 0, 0, 0 };
        clonewars_cadence_debug[18] = journal.frame.?.sequence;
        clonewars_cadence_debug[19] = reason;
    }
    if (!live(op)) return;
    clonewars_cadence_debug[4] +%= 1;
    game_sync_native_fault(14);
}
pub fn motionFailure(reason: u32, local: ?*const p.SyncCharacterMotionState, expected: ?*const p.SyncCharacterMotionState) void {
    if (clonewars_character_motion_failure[0] != 0) return;
    clonewars_character_motion_failure[0] = reason;
    clonewars_character_motion_failure[1] = read(u32, 0xfb4b6c);
    if (local) |value| @memcpy(std.mem.sliceAsBytes(clonewars_character_motion_failure[2..19]), std.mem.asBytes(value));
    if (expected) |value| @memcpy(std.mem.sliceAsBytes(clonewars_character_motion_failure[19..36]), std.mem.asBytes(value));
}
pub fn reference(gate: *const p.SyncFireTaskGate) p.SyncActor {
    var identity = std.mem.zeroes(p.SyncActor);
    identity.slot = gate.slot;
    identity.generation = gate.generation;
    identity.spawn_tag = gate.spawn_tag;
    identity.spawn_source = gate.spawn_source;
    identity.character = gate.character;
    identity.spawn_position = gate.origin;
    return identity;
}
pub fn supportSame(a: *const p.SyncCharacterMotionState, b: *const p.SyncCharacterMotionState) bool {
    return @import("character_support.zig").same(a, b);
}
