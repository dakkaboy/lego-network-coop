const p = @import("protocol.zig");
const projectile = @import("projectile_types.zig");
const Token = @import("cohort_types.zig").Token;
pub const Lease = extern struct { serial: u32, nonce: u32, frame_local: u32, epoch: u32, sequence: u32, frame_valid: u32 };
pub const Call = extern struct { lease: Lease, birth: usize, manager: usize, owner: usize, origin: usize, transform: usize, weapon: usize, flags: u32, target: usize, kind: u32, caller: u32, cohort: Token, control: projectile.ControlLease, control_session: projectile.Session, reset_generation: u64, capability: u32 };
pub const Birth = extern struct { id: u32, owner: i32, weapon: i32, owner_generation: u32, flags: u32, origin: [3]f32, transform: [16]f32, phase: u32, clock: u32, rng_game: u32, rng_engine: u32, delta: f32 };
pub const Input = extern struct { lease: Lease, kind: u32, caller: u32, manager_local: u32, owner_local: u32, target_local: u32, birth_known: u32, birth: Birth, origin: [3]u32, transform: [16]u32, flags: u32, weapon: u32, input_valid: u32, origin_local: u32, transform_local: u32, weapon_local: u32 };
pub const Record = extern struct {
    committed: u32,
    id: u32,
    version: u32,
    thread: u32,
    qpc_before: [2]u32,
    qpc_after: [2]u32,
    before: [4]u32,
    after: [4]u32,
    input: Input,
    owner_slot: u32,
    owner_generation: u32,
    owner_local_generation: u32,
    owner_character: u32,
    returned_local: u32,
    resource_local: u32,
    valid: u32,
    descriptor_local: u32,
    descriptor_type: u32,
    resolved_actor_local: u32,
    resolved_slot: u32,
    resolved_generation: u32,
    wrapper_local: u32,
    wrapper40: u32,
    wrapper44: u32,
    resource20: u32,
    resource70: u32,
    resource74: u32,
    object_raw: [132]u32,
    ray_raw: [32]u32,
    descriptor_raw: [40]u32,
    query_category: u32,
    query_normal_raw: [3]u32,
};
pub const Scope = extern struct { ready: u32, record: Record, cohort: Token, control: projectile.ControlLease, control_session: projectile.Session, reset_generation: u64, capability: u32 };
pub const none = 0;
pub const frame = 1;
pub const control = 2;
pub const rejected = 3;
comptime {
    const std = @import("std");
    std.debug.assert(@sizeOf(Birth) == @offsetOf(p.SyncShot, "has_launch_center"));
    std.debug.assert(@sizeOf(Input) == 264 and @sizeOf(Record) == 1232);
}
