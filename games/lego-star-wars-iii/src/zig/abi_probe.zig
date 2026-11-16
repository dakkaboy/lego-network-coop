const std = @import("std");
const p = @import("protocol.zig");
fn mix(hash: u32, value: usize) u32 {
    return (hash ^ @as(u32, @intCast(value))) *% 16777619;
}
fn signature(comptime T: type) u32 {
    var hash = mix(mix(2166136261, @sizeOf(T)), @alignOf(T));
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        hash = mix(mix(hash, @offsetOf(T, name)), @sizeOf(@FieldType(T, name)));
    }
    return hash;
}
export fn clonewars_zig_wire_abi(index: u32) u32 {
    const signatures = comptime blk: {
        @setEvalBranchQuota(100000);
        break :blk [_]u32{
            signature(p.SyncProfile),
            signature(p.SyncLoading),
            signature(p.SyncPreloadInput),
            signature(p.SyncPreloadTrack),
            signature(p.SyncPreloadReceipt),
            signature(p.SyncWorldReady),
            signature(p.SyncInput),
            signature(p.SyncAnimation),
            signature(p.SyncProjectileSeed),
            signature(p.SyncShot),
            signature(p.SyncProjectile),
            signature(p.SyncSpawnSource),
            signature(p.SyncTagIdentity),
            signature(p.SyncTag),
            signature(p.SyncActorBody),
            signature(p.SyncRigidBody),
            signature(p.SyncActor),
            signature(p.SyncVariable),
            signature(p.SyncActorInput),
            signature(p.SyncCadence),
            signature(p.SyncCollider),
            signature(p.SyncItemRange),
            signature(p.SyncReactionHitOutcome),
            signature(p.SyncReactionChoice),
            signature(p.SyncModelInputContext),
            signature(p.SyncModelInput),
            signature(p.SyncSpawnTimer),
            signature(p.SyncFireTaskState),
            signature(p.SyncAimTaskState),
            signature(p.SyncAimBaseState),
            signature(p.SyncForceQueryState),
            signature(p.SyncForceGeometryState),
            signature(p.SyncSpellItQueryState),
            signature(p.SyncRtsCompetitorState),
            signature(p.SyncCharacterMotionState),
            signature(p.SyncSpellItNodeState),
            signature(p.SyncScriptShootState),
            signature(p.SyncPrimaryPerceptionState),
            signature(p.SyncFireTaskGate),
            signature(p.SyncRtsTeamTimers),
            signature(p.SyncSpawnTimerChoice),
            signature(p.SyncPhysicsWorldInput),
            signature(p.SyncPhysicsModuleInput),
            signature(p.SyncPhysicsGunJamInput),
            signature(p.SyncPhysicsSpellItPoseInput),
            signature(p.SyncPhysicsSpellItStepInput),
            signature(p.SyncPhysicsSpellItSelectionInput),
            signature(p.SyncPhysicsSpellItBodyInput),
            signature(p.SyncPhysicsVehicleRngInput),
            signature(p.SyncPhysicsBreakupBasisInput),
            signature(p.SyncPhysicsRtsOrderInput),
            signature(p.SyncPhysicsRtsGeneratorInput),
            signature(p.SyncPhysicsChoice),
            signature(p.SyncTickGate),
            signature(p.SyncProjectileRetireRequest),
            signature(p.SyncFrame),
        };
    };
    return if (index < signatures.len) signatures[index] else 0;
}
