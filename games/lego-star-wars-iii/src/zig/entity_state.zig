const std = @import("std");
pub const p = @import("protocol.zig");
pub const win = @import("win32.zig");
pub const Key = @import("entity_types.zig").Key;
pub const SpawnIdentity = @import("entity_types.zig").SpawnIdentity;
pub const Roster = @import("saved_source_types.zig").Roster;
pub const Hub = @import("saved_source_types.zig").Hub;
pub const Local = extern struct { key: Key, origin: [3]f32, model: usize, origin_ready: c_int };
pub const Binding = extern struct { remote_generation: u32, local_generation: u32, local_slot: c_int };
pub const Assigned = extern struct { local_generation: u32, remote_generation: u32, remote_slot: u32 };
pub const Retired = extern struct { slot: u32, generation: u32 };
pub const RosterScope = struct { previous: ?*RosterScope, source: Roster, hub: Hub, created: usize, generation: u32, allocations: u32, qualified: c_int, kind: c_int };
pub const Pending = struct { source: Roster, actor: usize, generation: u32, active: bool };
pub var local = std.mem.zeroes([p.SYNC_MAX_ACTORS]Local);
pub var keys = std.mem.zeroes([p.SYNC_MAX_ACTORS]Key);
pub var bindings = std.mem.zeroes([p.SYNC_MAX_ACTORS]Binding);
pub var known = std.mem.zeroes([p.SYNC_MAX_ACTORS]Binding);
pub var assigned = std.mem.zeroes([p.SYNC_MAX_ACTORS]Assigned);
pub var inverse: [p.SYNC_MAX_ACTORS]c_int = @splat(0);
pub var pool: usize = 0;
pub var birth_counter: u32 = 0;
pub var retired = std.mem.zeroes([p.SYNC_MAX_PROJECTILES]Retired);
pub var retired_head: usize = 0;
pub var original_create: usize = 0;
pub threadlocal var spawn_context = std.mem.zeroes(SpawnIdentity);
pub threadlocal var roster_scope: ?*RosterScope = null;
pub var pending = std.mem.zeroes([8]Pending);
pub export var clonewars_entity_debug: [12]u32 = @splat(0);
pub export var clonewars_roster_source_debug: [8]u32 = @splat(0);
pub export var clonewars_hub_source_debug: [16]u32 = @splat(0);
const api = if (@hasDecl(@import("root"), "entity_test_api")) @import("root").entity_test_api else struct {
    pub fn pool() usize {
        return win.load(usize, 0xfb2f60);
    }
    pub fn player(index: usize) usize {
        return win.load(usize, 0xfb4940 + index * 4);
    }
};
pub const nativePool = api.pool;
pub const player = api.player;
pub const read = win.load;
pub extern fn game_actor_count() c_int;
pub extern fn lan_is_host() c_int;
pub extern fn native_roster_source_revalidate(*const Roster, usize) c_int;
pub extern fn native_hub_source_revalidate(*const Hub) c_int;
pub extern fn entities_allocation_live(usize, u32) c_int;
pub extern fn entities_allocation_retained(usize, u32) c_int;
pub extern fn entities_update() void;
pub extern fn entities_resolve_reference(?*const p.SyncActor) usize;
pub extern fn entities_is_retired(u32, u32) c_int;
pub extern fn entity_match_unique(*const Key, [*]const Key, [*]const u8, c_uint) c_int;
pub fn count() usize {
    return @intCast(game_actor_count());
}
pub fn valid(pointer: usize, size: usize) bool {
    return win.accessible(pointer, size, false);
}
pub fn generation() u32 {
    birth_counter +%= 1;
    if (birth_counter == 0) birth_counter +%= 1;
    return birth_counter;
}
pub fn rawSlot(actor: usize) c_int {
    const offset = actor -% pool;
    return if (actor != 0 and pool != 0 and offset % 0x1440 == 0 and offset / 0x1440 < p.SYNC_MAX_ACTORS) @intCast(offset / 0x1440) else -1;
}
pub fn address(slot: usize) usize {
    return pool + slot * 0x1440;
}
pub fn currentPool() void {
    const now = nativePool();
    if (now == pool) return;
    pool = now;
    local = std.mem.zeroes(@TypeOf(local));
    resetBindings();
    pending = std.mem.zeroes(@TypeOf(pending));
}
pub fn resetBindings() void {
    bindings = std.mem.zeroes(@TypeOf(bindings));
    known = std.mem.zeroes(@TypeOf(known));
    assigned = std.mem.zeroes(@TypeOf(assigned));
    retired = std.mem.zeroes(@TypeOf(retired));
    retired_head = 0;
    inverse = @splat(-1);
}
pub fn matches(candidate: *const Key, state: *const p.SyncActor) bool {
    return candidate.character == state.character and candidate.spawn_source.producer == state.spawn_source.producer and candidate.spawn_source.serial == state.spawn_source.serial and (state.spawn_source.producer == 0 or candidate.spawn_tag == state.spawn_tag);
}
pub fn key(state: *const p.SyncActor) Key {
    return .{ .generation = state.generation, .spawn_tag = state.spawn_tag, .character = state.character, .spawn_source = state.spawn_source };
}
pub fn claim(remote: u32, local_slot: usize, generation_remote: u32) void {
    const value: Binding = .{ .remote_generation = generation_remote, .local_generation = local[local_slot].key.generation, .local_slot = @intCast(local_slot) };
    bindings[remote] = value;
    known[remote] = value;
    assigned[local_slot] = .{ .local_generation = value.local_generation, .remote_generation = value.remote_generation, .remote_slot = remote };
}
pub fn claimedElsewhere(slot: usize, generation_local: u32, remote: u32, generation_remote: u32) bool {
    const a = &assigned[slot];
    return a.local_generation == generation_local and (a.remote_slot != remote or a.remote_generation != generation_remote);
}
