const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");
const gate = @import("cadence_gate.zig");
const equal = @import("validation.zig").equal;
const read = s.read;
const Poi = @import("identity_types.zig").AuthoredPoi;
const Reader = @import("memory_reader.zig").Reader;
const Resource = @import("identity_types.zig").ResourceIdentity;
const Witness = extern struct { epoch: u32, source: Resource };
extern fn native_authored_poi_resolve(usize, *Poi) c_int;
extern fn native_authored_poi_revalidate(*const Poi) c_int;
extern fn native_resource_identity_resolve(usize, usize, *Resource) c_int;
extern fn entities_allocation_live(usize, u32) c_int;
const name_seed = [4]u32{ 2166136261, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35 };
fn nameKey(name: usize, key: *[4]u32) bool {
    if (name == 0) return false;
    var length: usize = 0;
    while (length < 1024) {
        var memory: s.win.MemoryInfo = undefined;
        if (s.win.VirtualQuery(name + length, &memory, @sizeOf(s.win.MemoryInfo)) == 0 or memory.state != 0x1000 or memory.protection & 0x101 != 0) return false;
        const limit = @min(memory.base + memory.region_size - name, 1024);
        while (length < limit) {
            const byte = read(u8, name + length);
            length += 1;
            inline for (0..4) |i| key[i] = (key[i] ^ byte) *% (16777619 + 2 * i);
            if (byte == 0) return length > 1;
        }
    }
    return false;
}
fn uniqueAuthoredName(witness: *const Poi, selected: usize, name: *const [4]u32) bool {
    var reader = Reader.init();
    if (!reader.readable(witness.array, @as(usize, witness.poi_count) * 0xe0) or !reader.readable(selected, 4)) return false;
    const prefix = read(u32, selected);
    for (0..witness.poi_count) |ordinal| {
        if (ordinal == witness.poi_ordinal) continue;
        const other = read(usize, witness.array + ordinal * 0xe0 + 0xb4);
        if (other == 0) continue;
        if (!reader.readable(other, 4)) return false;
        if (read(u32, other) != prefix) continue;
        var key = name_seed;
        if (nameKey(other, &key) and equal(name, &key)) return false;
    }
    return true;
}
fn resourceKey(op: *const s.Lease, resource: usize, key: *[4]u32, witness: *Witness) bool {
    var source: Resource = undefined;
    if (!s.live(op) or native_resource_identity_resolve(read(usize, 0xfb4a20), resource, &source) == 0 or !s.live(op)) return false;
    witness.* = .{ .epoch = s.journal.frame.?.epoch, .source = source };
    key.* = source.key;
    return s.live(op);
}
pub export fn cadence_spellit_node(frame: usize, gizmo: usize, node: usize, position: *[3]f32) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const scope = @import("cadence_spellit.zig").scopeFor(frame) orelse return;
    const op = scope.lease;
    var reason: u32 = 2;
    var entity: usize = 0;
    var receiver: usize = 0;
    var resource: usize = 0;
    var poi: usize = 0;
    var runtime: usize = 0;
    var array: usize = 0;
    var count: u32 = 0;
    var witness = std.mem.zeroes(Poi);
    input: {
        if (!s.valid(gizmo, 0x28) or !s.valid(node, 12) or !s.valid(@intFromPtr(position), 12) or !s.valid(scope.manager, 0x28)) break :input;
        entity = read(usize, node + 8);
        if (!s.valid(entity, 0x40)) break :input;
        receiver = read(usize, entity + 0x3c);
        if (!s.valid(receiver, 0x34)) break :input;
        resource = read(usize, receiver + 0x2c);
        poi = read(usize, receiver + 0x30);
        reason = 4;
        if (native_authored_poi_resolve(entity, &witness) == 0 or witness.receiver != receiver or !s.live(&op)) break :input;
        // The native SpellIt query rejects nodes more than one unit above or below the actor.
        // Resolute contains extra off-floor nodes whose registration order depends on the local load.
        if (s.journal.frame.?.level == 3 and std.math.isFinite(position[1]) and
            @abs(position[1] - scope.input.position[1]) > 1.001)
        {
            scope.node_visit +%= 1;
            return;
        }
        resource = witness.resource;
        poi = witness.poi;
        runtime = witness.runtime;
        array = witness.array;
        count = witness.poi_count;
        var state = std.mem.zeroes(p.SyncSpellItNodeState);
        state.clock = scope.input.clock;
        state.poi_count = count;
        state.poi_ordinal = witness.poi_ordinal;
        state.node_ordinal = scope.node_visit;
        reason = 5;
        var resource_witness: Witness = undefined;
        const component = read(usize, receiver + 0x14);
        state.gizmo_class = s.imageClass(read(usize, gizmo), true) orelse break :input;
        state.receiver_class = s.imageClass(read(usize, receiver), true) orelse break :input;
        if (!s.valid(component, 4)) break :input;
        state.component_class = s.imageClass(read(usize, component), true) orelse break :input;
        if (!resourceKey(&op, resource, &state.resource_name, &resource_witness)) break :input;
        reason = 6;
        var name = name_seed;
        const poi_name = read(usize, poi + 0xb4);
        if (!nameKey(poi_name, &name) or name[0] == 0) break :input;
        state.poi_name = name[0];
        // Resolute adds character archives to its local POI table in load order.
        const stable_name = s.journal.frame.?.level == 3 and uniqueAuthoredName(&witness, poi_name, &name);
        if (stable_name) {
            state.poi_ordinal = 0;
            state.poi_count = 1;
        }
        var current = read(usize, scope.manager + 0x24);
        reason = 7;
        while (current != gizmo and state.gizmo_ordinal < 65536) {
            if (!s.valid(current, 0x28)) break :input;
            current = read(usize, current + 0x24);
            state.gizmo_ordinal += 1;
        }
        if (current != gizmo or state.gizmo_ordinal >= 65536 or state.node_ordinal >= 65536 or !s.live(&op) or native_authored_poi_revalidate(&witness) == 0) break :input;
        if (stable_name) {
            state.node_ordinal = 0;
            state.gizmo_ordinal = 0;
        }
        state.position = position.*;
        reason = 8;
        if (!@import("validation.zig").finite(state.position)) break :input;
        const local = state;
        const replay = if (stable_name and s.journal.host == 0)
            gate.replayResoluteSpellItNode(scope, &state, &s.clonewars_spellit_node_debug)
        else
            .mismatch;
        switch (replay) {
            .matched => {},
            .absent => {
                // Exclude a guest-only query candidate through the native height check.
                position[1] = scope.input.position[1] + 2;
                scope.node_visit +%= 1;
                return;
            },
            .mismatch => _ = gate.apply(scope.actor, p.SYNC_ACTOR_SPELLIT_NODE, 0, 0, 0, @ptrCast(&state), &s.clonewars_spellit_node_debug),
        }
        if (!s.live(&op) or !s.active or s.journal.failed != 0) return;
        scope.node_visit +%= 1;
        if (s.journal.host == 0) {
            reason = 9;
            var after: Witness = undefined;
            var key: [4]u32 = undefined;
            if (!s.valid(node, 12) or !s.valid(entity, 0x40) or !s.valid(receiver, 0x34) or !s.valid(poi, 0xe0) or read(u32, 0xfb4b6c) != state.clock or read(usize, node + 8) != entity or read(usize, entity + 0x3c) != receiver or native_authored_poi_revalidate(&witness) == 0 or read(usize, poi + 0xd4) != witness.authored_receiver or read(usize, receiver + 0x14) != component or !s.valid(resource, 0x738) or read(usize, resource + 0x6f8) != runtime or !s.valid(runtime, 0x70) or read(usize, runtime + 0x6c) != array or read(u32, runtime + 0x68) != count) break :input;
            const gizmo_class = s.imageClass(read(usize, gizmo), true) orelse break :input;
            if (gizmo_class != state.gizmo_class) break :input;
            const receiver_class = s.imageClass(read(usize, receiver), true) orelse break :input;
            if (receiver_class != state.receiver_class or !s.valid(component, 4)) break :input;
            const component_class = s.imageClass(read(usize, component), true) orelse break :input;
            if (component_class != state.component_class or !resourceKey(&op, resource, &key, &after) or !equal(&resource_witness, &after) or !equal(&state.resource_name, &key) or entities_allocation_live(scope.actor, scope.generation) == 0 or !s.live(&op)) break :input;
            if (!equal(&local.position, &state.position)) {
                s.clonewars_spellit_node_debug[2] +%= 1;
                if (s.clonewars_spellit_node_correction[0] == 0) {
                    var values: [24]u32 = @splat(0);
                    values[0] = s.journal.frame.?.epoch;
                    values[1] = s.journal.frame.?.sequence;
                    @memcpy(std.mem.sliceAsBytes(values[2..15]), std.mem.asBytes(&state)[0..52]);
                    values[15..18].* = @bitCast(local.position);
                    values[18..21].* = @bitCast(state.position);
                    s.clonewars_spellit_node_correction = values;
                }
            }
            position.* = state.position;
        }
        return;
    }
    if (s.live(&op)) {
        if (s.clonewars_spellit_node_failure[0] == 0) s.clonewars_spellit_node_failure = .{ s.journal.frame.?.epoch, s.journal.frame.?.sequence, reason, scope.node_visit, scope.input.clock, @truncate(gizmo), @truncate(node), @truncate(entity), @truncate(receiver), @truncate(resource), @truncate(poi), @truncate(runtime), @truncate(array), count, @truncate(witness.authored_receiver), witness.chain_count };
        s.journal.failed = 17;
        s.clonewars_spellit_node_debug[3] +%= 1;
        s.failed(&op, scope.actor, null, 17);
    }
}
