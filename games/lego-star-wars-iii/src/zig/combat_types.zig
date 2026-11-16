pub const Actor = extern struct { pointer_local: u32, raw_slot: u32, local_generation: u32, network_slot: u32, network_generation: u32, valid: u32, character: i32, health: i32, flags: u32, life_54: u32, state_2f4: u32, c78: u32, c80: u32, c8c: u32, c94: u32, c98: u32, ca0: u32, invulnerability_d3c: u32, death_de6: u32, handle_142c: u32 };
pub const Source = extern struct { status: u32, id: u32, object_local: u32, resource_local: u32, owner_local: u32, owner: i32, weapon: i32, owner_generation: u32, flags_160: u32, flags_164: u32, resource_74: u32, damage_4a: u32, position: [3]f32, after_status: u32, origin: u32, instance_serial: u32, creation_count: u32 };
pub const Record = extern struct {
    committed: u32,
    id: u32,
    parent: u32,
    kind: u32,
    thread: u32,
    caller: u32,
    phase: u32,
    qpc_before_low: u32,
    qpc_before_high: u32,
    qpc_after_low: u32,
    qpc_after_high: u32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    clock_after: u32,
    rng_game_after: u32,
    rng_engine_after: u32,
    arguments: [6]u32,
    result: u32,
    before: [2]Actor,
    after: [2]Actor,
    source: Source,
    descriptor_local: u32,
    descriptor_valid: u32,
    descriptor_words: [11]u32,
    heading_valid: u32,
    heading: u32,
    native_level: u32,
    native_phase: u32,
    tick_enter_low: u32,
    tick_enter_high: u32,
    tick_leave_low: u32,
    tick_leave_high: u32,
    tick_sequence: u32,
    tick_clock_enter: u32,
    tick_clock_leave: u32,
    tick_thread: u32,
    frame_queued_low: u32,
    frame_queued_high: u32,
    frame_queued_epoch: u32,
    frame_queued_sequence: u32,
};
pub const Scope = extern struct { record: Record, previous: ?*Scope };
pub const Global = extern struct { committed: u32, id: u32, parent: u32, thread: u32, enter_low: u32, enter_high: u32, leave_low: u32, leave_high: u32, dispatcher_local: u32, packet_local: u32, packet_vtable: u32, packet_zero: u32, packet_delta_before: u32, packet_delta_after: u32, packet_mode: u32, engine_root_local: u32, engine_delta_before: u32, engine_delta_after: u32, sequence_before: u32, sequence_after: u32, clock_before: u32, clock_after: u32, births_before: u32, births_after: u32, hits_before: u32, hits_after: u32, level_before: u32, level_after: u32, phase_before: u32, phase_after: u32 };
pub const Receipt = extern struct { lease: @import("cohort_types.zig").Lease, cursor: u32, slot: u32, generation: u32, source_id: u32, actor: usize, local_generation: u32, hit: @import("protocol.zig").SyncReactionHitOutcome, valid: c_int };
comptime {
    const assert = @import("std").debug.assert;
    assert(@sizeOf(Actor) == 80 and @sizeOf(Source) == 76 and @sizeOf(Record) == 608 and @sizeOf(Global) == 120 and @sizeOf(Receipt) == 100);
}
