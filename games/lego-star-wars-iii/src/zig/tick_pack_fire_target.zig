const std = @import("std");
const s = @import("tick_state.zig");
extern fn entities_update() void;
extern fn entities_actor(u32, u32) usize;
extern fn entities_resolve_identity(*const s.p.SyncFrame, u32, u32) usize;
extern fn entities_observed_generation(usize) u32;
extern fn entities_allocation_retained(usize, u32) c_int;
extern fn entities_spawn_source(usize, *u32) s.p.SyncSpawnSource;
extern fn entities_bind_native_reference(*const s.p.SyncActor, usize) c_int;
pub export var clonewars_pack_fire_target_debug: [4]u32 = @splat(0);
pub export var clonewars_pack_fire_target_correction: [12]u32 = @splat(0);
pub export var clonewars_pack_fire_target_failure: [10]u32 = @splat(0);
pub const sites = s.consecutive(s.site.PACK_FIRE_FIELDS, s.site.PACK_FIRE_TARGET, 1);
const Words = [s.site.PACK_FIRE_FIELDS]u32;
fn fail(reason: u32, member: usize, source: *const Words) bool {
    if (s.ready()) {
        if (clonewars_pack_fire_target_failure[0] == 0) clonewars_pack_fire_target_failure = .{ reason, s.frame.?.sequence, s.clock(), @truncate(member), source[0], source[1], source[2], 0, 0, 0 };
        clonewars_pack_fire_target_debug[3] +%= 1;
        s.fail(8, sites[0], s.clock(), s.firstExpected());
    }
    return false;
}
fn describe(actor: usize) ?[3]u32 {
    if (actor == 0) return .{ 0, 0, 0 };
    if (!s.readable(actor, 0x1440)) return null;
    // Native mode 18 still aims at allocated actors after their active bit clears.
    const local_generation = entities_observed_generation(actor);
    if (local_generation == 0 or entities_allocation_retained(actor, local_generation) == 0) return null;
    const slot = s.entities_slot(actor);
    const generation = s.entities_generation(actor);
    const character = s.load(i16, actor + 0xdc0);
    if (slot < 0 or slot >= s.p.SYNC_MAX_ACTORS or generation == 0 or character < 0) return null;
    return .{ @as(u32, @intCast(slot)) + 1, generation, @intCast(character) };
}
fn resolve(source: *const Words) usize {
    if (source[0] == 0) return 0;
    const slot = source[0] - 1;
    var actor = entities_actor(slot, source[1]);
    if (actor == 0) {
        actor = entities_resolve_identity(s.frame.?, slot, source[1]);
        if (actor != 0) _ = s.entities_bind_native_actor(s.frame.?, actor);
        actor = entities_actor(slot, source[1]);
    }
    if (actor == 0 and source[9] != 0) {
        var reference = std.mem.zeroes(s.p.SyncActor);
        reference.slot = slot;
        reference.generation = source[1];
        reference.character = @intCast(source[2]);
        reference.spawn_tag = source[8];
        reference.spawn_source = .{ .producer = source[9], .serial = source[10] };
        const pool = s.load(usize, 0xfb2f60);
        const count = s.load(u32, 0xfb2e3c);
        if (count > s.p.SYNC_MAX_ACTORS or !s.readable(pool, count * 0x1440)) return 0;
        for (0..count) |i| {
            const candidate = pool + i * 0x1440;
            if (s.load(i16, candidate + 0xdc0) != reference.character) continue;
            if (entities_bind_native_reference(&reference, candidate) != 0) return entities_actor(slot, source[1]);
        }
    }
    return actor;
}
pub fn apply(member: usize) bool {
    var local: Words = @splat(0);
    if (!s.ready() or !s.readable(member, 0xa0)) return fail(1, member, &local);
    const before = s.load([0xa0]u8, member);
    const target = s.load(usize, member + 0x88);
    var effective = target;
    local[3..7].* = s.load([4]u32, member + 0x8c);
    local[7] = s.load(u8, member + 0x9c) & 1;
    entities_update();
    if (!s.ready()) return false;
    var source = local;
    if (s.host) {
        if (target != 0 and @import("target_retirement.zig").witnessed(target)) effective = 0;
        local[0..3].* = describe(effective) orelse return fail(2, member, &local);
        if (effective != 0) {
            const identity = entities_spawn_source(target, &local[8]);
            local[9] = identity.producer;
            local[10] = identity.serial;
        }
        source = local;
        if (!s.capacity(sites.len, sites[0])) return false;
    } else {
        const gates = s.expected(sites.len) orelse return fail(3, member, &source);
        for (gates, sites, &source) |gate, site, *word| {
            if (gate.site != site or gate.clock != s.clock() or !s.valid.gateValid(gate)) return fail(3, member, &source);
            word.* = gate.value;
        }
    }
    for (source, sites) |value, site| if (!s.valid.gateValid(.{ .site = site, .clock = s.clock(), .value = value })) return fail(3, member, &source);
    if ((source[0] == 0 and (source[1] != 0 or source[2] != 0 or source[8] != 0 or source[9] != 0 or source[10] != 0)) or (source[0] != 0 and source[1] == 0)) return fail(3, member, &source);
    const canonical_target = if (s.host) effective else resolve(&source);
    if (!s.ready()) return false;
    entities_update();
    if (!s.ready()) return false;
    const current = describe(canonical_target) orelse return fail(4, member, &source);
    if (canonical_target != 0) {
        var tag: u32 = 0;
        const identity = entities_spawn_source(canonical_target, &tag);
        if (tag != source[8] or identity.producer != source[9] or identity.serial != source[10]) return fail(4, member, &source);
    } else if (source[8] != 0 or source[9] != 0 or source[10] != 0) return fail(4, member, &source);
    if (!std.mem.eql(u32, &current, source[0..3]) or !s.win.accessible(member + 0x88, 0x15, true) or !std.mem.eql(u8, &before, &s.load([0xa0]u8, member))) return fail(4, member, &source);
    var ignored: Words = undefined;
    s.run(&source, &sites, &ignored);
    if (!s.ready()) return false;
    clonewars_pack_fire_target_debug[@intFromBool(!s.host)] +%= 1;
    if (s.host and effective != target) {
        s.store(usize, member + 0x88, effective);
    }
    if (!s.host) {
        if (target != canonical_target or !std.mem.eql(u32, local[3..], source[3..])) {
            if (clonewars_pack_fire_target_debug[2] == 0) clonewars_pack_fire_target_correction = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), @truncate(member), s.load(u8, member + 0x60), @truncate(target), @truncate(canonical_target), source[0], source[1], source[2], local[3], source[3] };
            clonewars_pack_fire_target_debug[2] +%= 1;
        }
        // Mode 9 stores falling speed here; mode 18 requires an actor pointer.
        s.store(usize, member + 0x88, canonical_target);
        s.store([4]u32, member + 0x8c, source[3..7].*);
        s.store(u8, member + 0x9c, s.load(u8, member + 0x9c) & 0xfe | @as(u8, @truncate(source[7])));
    }
    return true;
}
