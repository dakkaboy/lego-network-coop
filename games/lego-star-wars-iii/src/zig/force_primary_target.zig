const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;

extern fn native_scene_support_source(usize, *[2]u32) c_int;
extern fn native_scene_support_resolve(u32, u32) usize;
extern fn physics_effect_body_source(usize, *[2]u32) c_int;
extern fn physics_effect_body_resolve(u32, u32) usize;

pub const Kind = enum(u32) { none, unbound, actor, effect, scene, canister, _ };

pub const Target = extern struct {
    clock: u32 = 0,
    kind: Kind = .none,
    key: [2]u32 = .{ 0, 0 },
};

const canister_gizmo_class = 0xad953c;
const canister_force_class = 0xc450fc;

fn canisterKey(gizmo: usize, key: *[2]u32) bool {
    if (!s.valid(gizmo, 0x154) or s.read(usize, gizmo) != canister_gizmo_class) return false;
    var read = Reader.init();
    var hash: Hash = .{};
    if (!hash.text(&read, gizmo + 0x30, 32, false, true)) return false;
    key.* = hash.words[0..2].*;
    return key[0] != 0 and key[1] != 0;
}

fn resolveCanister(key: [2]u32) usize {
    const world = s.read(usize, 0xfb4a20);
    const registry = s.read(usize, 0xe90184);
    const provider = s.read(usize, 0xe901dc);
    if (!s.valid(world, 0x404) or !s.valid(registry, 0x2c) or !s.valid(provider, 0x3c)) return 0;
    const handle = s.read(usize, world + 0x400);
    const count = s.read(u32, registry + 0x28);
    const index = s.read(u32, provider + 0x38);
    if (index >= count or count > 4096 or !s.valid(handle, 4)) return 0;
    const table = s.read(usize, handle);
    if (!s.valid(table, count * 4)) return 0;
    const manager = s.read(usize, table + index * 4);
    if (!s.valid(manager, 0x28) or s.read(usize, manager) != 0xc4c8ec) return 0;
    var gizmo = s.read(usize, manager + 0x24);
    var found: usize = 0;
    var left: usize = 65536;
    while (gizmo != 0 and left != 0) : (left -= 1) {
        if (!s.valid(gizmo, 0x154)) return 0;
        var candidate: [2]u32 = undefined;
        if (canisterKey(gizmo, &candidate) and std.meta.eql(key, candidate)) {
            if (found != 0) return 0;
            found = gizmo;
        }
        gizmo = s.read(usize, gizmo + 0x24);
    }
    if (found == 0 or gizmo != 0) return 0;
    const pointer = s.read(usize, found + 0x150);
    if (!s.valid(pointer, 8) or s.read(usize, pointer) != canister_force_class) return 0;
    const model = s.read(usize, found + 0x88);
    return if (model != 0 and s.read(usize, pointer + 4) == model) pointer else 0;
}

// The selector can return a Force interface from an actor, a gizmo, or a physics body.
pub fn describe(pointer: usize, clock: u32) Target {
    var result: Target = .{ .clock = clock };
    if (pointer == 0) return result;
    result.kind = .unbound;
    if (s.valid(pointer, 8) and s.read(usize, pointer) == canister_force_class) {
        const model = s.read(usize, pointer + 4);
        if (!s.valid(model, 0x54)) return result;
        const gizmo = s.read(usize, model + 0x50);
        var key: [2]u32 = undefined;
        if (canisterKey(gizmo, &key) and s.read(usize, gizmo + 0x88) == model and s.read(usize, gizmo + 0x150) == pointer) {
            result.kind = .canister;
            result.key = key;
        }
        return result;
    }
    const pool = s.read(usize, 0xfb2f60);
    const count = s.read(u32, 0xfb2e3c);
    if (pool != 0 and count <= p.SYNC_MAX_ACTORS and s.valid(pool, count * 0x1440)) {
        for (0..count) |i| {
            const actor = pool + i * 0x1440;
            if (s.read(usize, actor + 0xca4) != pointer) continue;
            var identity: [2]u32 = undefined;
            if (s.entities_observed_identity(actor, &identity[0], &identity[1]) != 0) {
                result.kind = .actor;
                result.key = identity;
                return result;
            }
        }
    }
    if (pointer >= 0x50) {
        var identity: [2]u32 = undefined;
        if (physics_effect_body_source(pointer - 0x50, &identity) != 0) {
            result.kind = .effect;
            result.key = identity;
        } else if (native_scene_support_source(pointer - 0x50, &identity) != 0) {
            result.kind = .scene;
            result.key = identity;
        }
    }
    return result;
}

pub fn resolve(target: Target) usize {
    const key = target.key;
    if (target.kind == .canister) return resolveCanister(key);
    if (target.kind == .actor) {
        const actor = s.entities_actor(key[0], key[1]);
        return if (s.valid(actor, 0x1440)) s.read(usize, actor + 0xca4) else 0;
    }
    const body = switch (target.kind) {
        .effect => physics_effect_body_resolve(key[0], key[1]),
        .scene => native_scene_support_resolve(key[0], key[1]),
        else => return 0,
    };
    return if (s.valid(body, 0x54)) body + 0x50 else 0;
}

pub fn valid(flags: u16, value: c_int, target: Target) bool {
    const no_key = target.key[0] == 0 and target.key[1] == 0;
    if (target.clock == 0) return target.kind == .none and no_key;
    if (flags != 4) return false;
    if (value == 0) return target.kind == .none and no_key;
    return switch (target.kind) {
        .unbound => no_key,
        .actor => target.key[0] < p.SYNC_MAX_ACTORS and target.key[1] != 0,
        .effect, .scene, .canister => target.key[0] != 0 and target.key[1] != 0,
        else => false,
    };
}
