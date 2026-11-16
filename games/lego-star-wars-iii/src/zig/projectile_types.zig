const p = @import("protocol.zig");
pub const Lease = @import("cohort_types.zig").Lease;
pub const ControlLease = @import("span_types.zig").Lease;
pub const Adapter = @import("span_types.zig").Adapter;
pub const Session = extern struct { epoch: u32, level: i32, host: u32, classification: u32, session: u32 };
pub const Reject = extern struct { epoch: u32, level: i32, release: u32, sequence: u32, capability: u32 };
pub const SessionProvider = *const fn (*Session, usize) callconv(.c) c_int;
pub const RejectProvider = *const fn (u32, *const Reject, usize) callconv(.c) void;
pub const Operation = extern struct { kind: u32, serial: u32, frame: Lease, control: ControlLease, session: Session, reset_generation: u64 };
pub const Tracked = extern struct { birth: p.SyncShot, object: usize, resource: usize, native_stamp: u32 };
pub const Provenance = extern struct { epoch: u32, level: i32, release: u32, session: u32, generation: u64, committed: u32 };
pub const Retire = extern struct { request: p.SyncProjectileRetireRequest, object: usize, resource: usize, manager: usize, instance: u32, source_sequence: u32, provenance: Provenance };
pub const Fire = struct { previous: ?*Fire, actor: usize, caller: u32, mode: c_int, operation: Operation, cleanup_stamp: u32, local_generation: u32 };
pub const Launch = struct { previous: ?*Launch, operation: *const Operation, shot: *p.SyncShot, owner: usize, origin: usize, transform: usize, center_visited: bool };
pub const Failure = extern struct {
    reason: u32,
    sequence: u32,
    thread: u32,
    caller: u32,
    fire_caller: u32,
    fire_mode: u32,
    clock: u32,
    rng_game: u32,
    rng_engine: u32,
    ordinal: u32,
    shot_count: u32,
    projectile_count: u32,
    expected_index: u32,
    weapon: u32,
    flags: u32,
    target_local: u32,
    qpc_low: u32,
    qpc_high: u32,
    expected: p.SyncShot,
    actor: @import("shooter_types.zig").Actor,
    action_timer: u32,
    cooldown: u32,
    pending_local: u32,
    pending_valid: u32,
    pending_words: [7]u32,
};
pub const Identity = extern struct { status: u32, id: u32, owner: i32, weapon: i32, owner_generation: u32, resource_local: u32, instance_serial: u32, creation_count: u32 };
pub const ShotContext = extern struct { clock: u32, rng_game: u32, rng_engine: u32, delta: f32 };
pub const Create = *const fn (usize, usize, usize, usize, usize, u32, usize) callconv(.{ .x86_thiscall = .{} }) usize;
pub const CreateSecondary = *const fn (usize, usize, usize, usize, usize, u32, u32, usize) callconv(.{ .x86_thiscall = .{} }) usize;
pub const Remove = *const fn (usize, usize, u32, c_int) callconv(.{ .x86_thiscall = .{} }) u8;
pub const PoolRelease = *const fn (usize, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) usize;
pub const FireNative = *const fn (usize, usize, usize, c_int, usize, usize) callconv(.{ .x86_thiscall = .{} }) void;
pub const unkeyed = 1;
pub const keyed = 2;
pub const rejected = 3;
pub const control = 4;
pub const barrier = 5;
pub const client_decline = 6;
pub const control_fault = 7;
pub const unavailable = 1;
pub const exception = 2;
pub const abandoned = 3;
pub const provenance = 4;
pub const capacity = 5;
pub const exhausted = 6;
pub const offline = 1;
pub const bootstrap = 2;
pub const transition = 3;
pub const established = 4;
pub const fault = 5;
pub const actor_followup_site = 0x81f5bb;
pub const child_site = 0x8633e0;
pub const render_retire_caller = 0x85ba24;
pub const flight_offsets = [_]usize{ 0x12c, 0x130, 0x134, 0x138, 0x154, 0x158, 0x15c, 0x128, 0x13c, 0x140, 0x144, 0x148, 0x14c, 0x150 };
comptime {
    @import("std").debug.assert(@sizeOf(Failure) == 684);
}
