const std = @import("std");
const p = @import("protocol.zig");
const validation = @import("physics_validation.zig");
pub fn launch(descriptor: *[48]u8, local: *const p.SyncPhysicsChoice, expected: *const p.SyncPhysicsChoice) bool {
    if (local.kind != p.SYNC_PHYSICS_BREAKUP_LAUNCH or !validation.sameSource(local, expected)) return false;
    @memcpy(descriptor[0x10..0x20], std.mem.sliceAsBytes(expected.payload.basic.recipe[2..6]));
    return true;
}
pub fn geometry(matrix: *align(1) [16]f32, scale: *align(1) [3]f32, local_basis: *const p.SyncPhysicsChoice, local_scale: *const p.SyncPhysicsChoice, basis: *const p.SyncPhysicsChoice, size: *const p.SyncPhysicsChoice) bool {
    if (local_basis.kind != p.SYNC_PHYSICS_BREAKUP_BASIS or local_scale.kind != p.SYNC_PHYSICS_BREAKUP_SCALE or
        !validation.sameSource(local_basis, basis) or !validation.sameSource(local_scale, size) or
        basis.payload.breakup_basis.clock != size.payload.basic.clock or basis.payload.breakup_basis.model != size.payload.basic.model or
        !std.mem.eql(u32, &basis.payload.breakup_basis.name_hash, &size.payload.basic.name_hash)) return false;
    matrix.* = basis.payload.breakup_basis.matrix;
    scale.* = @bitCast(size.payload.basic.recipe[0..3].*);
    return true;
}
