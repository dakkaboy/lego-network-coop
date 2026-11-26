const std = @import("std");
const s = @import("cadence_state.zig");
const p = @import("protocol.zig");
const ci = @import("cadence_input.zig");
const cb = @import("cadence_basic.zig");
const ct = @import("cadence_tasks.zig");
const cf = @import("cadence_force.zig");
const cs = @import("cadence_script.zig");
const csp = @import("cadence_spellit.zig");
const cn = @import("cadence_spellit_node.zig");
const cm = @import("cadence_motion.zig");
const cp = @import("cadence_perception.zig");
const gate = @import("cadence_gate.zig");
const fixture = @import("cadence_runtime_fixture.zig");
const win = s.win;
const check = @import("native_test_support.zig").check;
const Token = @import("cohort_types.zig").Token;
const Poi = @import("identity_types.zig").AuthoredPoi;
const Resource = @import("identity_types.zig").ResourceIdentity;
const Script = @import("script_shoot_types.zig").Dispatch;
comptime {
    _ = @import("cadence.zig");
}
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
const actor: usize = 0x20000000;
const other: usize = 0x20010000;
const model: usize = 0x20020000;
const task: usize = 0x20030000;
const wrapper: usize = 0x20040000;
const brain: usize = 0x20050000;
const component: usize = 0x20060000;
const competitor: usize = 0x20070000;
const body: usize = 0x20080000;
const support: usize = 0x20090000;
const manager: usize = 0x200a0000;
const world: usize = 0x200b0000;
const provider: usize = 0x200c0000;
const registry: usize = 0x200d0000;
const table: usize = 0x200e0000;
const node: usize = 0x200f0000;
const gizmo: usize = 0x20100000;
const entity: usize = 0x20110000;
const receiver: usize = 0x20120000;
const resource: usize = 0x20130000;
const runtime: usize = 0x20140000;
const poi: usize = 0x20150000;
const name: usize = 0x20160000;
const native_frame: *[8]u32 = @ptrFromInt(0x20170000);
const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
var script_source: Script = undefined;
var mode: u32 = 0;
var client = false;
var valid = true;
var retained = true;
var proof = true;
var updates: u32 = 0;
var describes: u32 = 0;
var resolves: u32 = 0;
var bound_reserves: u32 = 0;
var fault: c_int = 0;
var support_reads: u32 = 0;
export var cadence_fixture_entry: usize = 0;
export var cadence_fixture_actor: usize = 0;
export var cadence_fixture_task: usize = 0;
export var cadence_fixture_frame: usize = 0;
export var cadence_fixture_value: u32 = 0;
export var cadence_fixture_branch: u32 = 0;
extern fn invoke_period() void;
extern fn invoke_fire() void;
extern fn invoke_support() void;
extern fn invoke_perception() void;
extern fn invoke_force_first_target(*const u32, u32) u32;
extern fn saber_target_queue(usize) c_int;
extern fn allow_cont() void;
extern fn skip_cont() void;
export fn coherent_frame_valid(_: *const Token, _: u32) c_int {
    return @intFromBool(valid);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn entities_update() void {
    updates += 1;
}
export fn entities_describe(out: *p.SyncActor, a: usize) void {
    describes += 1;
    out.* = std.mem.zeroes(p.SyncActor);
    out.generation = 19;
    out.spawn_tag = 23;
    out.spawn_source = .{ .producer = 29, .serial = 31 };
    out.spawn_position[0] = if (a == actor) 1 else 2;
}
export fn entities_slot(a: usize) c_int {
    if (mode == 58 and a == node) return 9;
    return if (a == actor) 7 else 8;
}
export fn entities_observed_generation(_: usize) u32 {
    return 19;
}
export fn entities_observed_identity(a: usize, slot: *u32, generation: *u32) c_int {
    if ((mode == 60 or mode == 62) and a == runtime) return 0;
    slot.* = (if (a == actor) @as(u32, 7) else 8) - @as(u32, if (mode == 59) 7 else 0);
    generation.* = if (client and mode == 17) 20 else 19;
    return @intFromBool(a != 0);
}
export fn entities_allocation_retained(_: usize, _: u32) c_int {
    return @intFromBool(retained);
}
export fn entities_allocation_live(_: usize, _: u32) c_int {
    return @intFromBool(retained);
}
export fn entities_bind_native_reference(_: *const p.SyncActor, _: usize) c_int {
    bound_reserves += 1;
    return 1;
}
export fn entities_actor(slot: u32, generation: u32) usize {
    if (mode == 60 and generation != 19) return 0;
    if (mode == 62) return 0;
    return if (slot == 7) actor else other;
}
export fn entities_retained_actor(slot: u32, generation: u32) usize {
    return if (mode == 62 and slot == 7 and generation == 19) actor else 0;
}
export fn entities_resolve_reference(state: *const p.SyncActor) usize {
    resolves += 1;
    if (client and mode == 39) valid = false;
    if (client and mode == 52) put(body + 0xec, support + 0x200);
    if (client and mode == 55) retained = false;
    if (client and mode == 25) put(poi + 0xd4, 0);
    if (client and (mode == 12 or (mode == 33 and state.slot == 8))) return 0;
    const resolved = if (state.slot == 7) actor else if (state.slot == 9 and mode == 58) node else other;
    if ((state.character == 417 or state.character == 429) and state.character != win.load(i16, resolved + 0xdc0)) return 0;
    return resolved;
}
var island_plate_body: usize = 0;
export fn native_scene_support_source(candidate: usize, source: *[2]u32) c_int {
    if (candidate == 0 or candidate != island_plate_body) return 0;
    source.* = .{ 112, 84 };
    return 1;
}
var island_effect_body: usize = 0;
export fn physics_effect_ordering_source(candidate: usize, source: *[2]u32) c_int {
    if (candidate == 0 or candidate != island_effect_body) return 0;
    source.* = .{ 824, 3 };
    return 1;
}
export fn native_scene_support_resolve(_: u32, _: u32) usize {
    return 0;
}
export fn physics_effect_body_source(object: usize, out: *[2]u32) c_int {
    support_reads += 1;
    if ((mode == 51 and client) or (mode == 53 and !client) or (mode == 50 and client and support_reads > 1)) return 0;
    if (client and mode >= 45) {
        check(@src(), object == support or object == support + 0x200);
        out.* = .{ 13, if (object == support) 18 else if (mode == 47) 19 else 17 };
        return 1;
    }
    check(@src(), object == support);
    out.* = .{ 13, if (client and (mode == 28 or mode == 42)) 18 else 17 };
    return 1;
}
export fn physics_effect_body_resolve(sequence: u32, event: u32) usize {
    check(@src(), sequence == 13 and event == 17 and client);
    if (mode == 28 or mode == 41 or mode == 46) return 0;
    if (mode >= 45) return support + 0x200;
    if (mode == 43) win.store(u8, support + 0x19, 0x20);
    return support;
}
export fn native_authored_poi_resolve(object: usize, out: *Poi) c_int {
    check(@src(), object == entity);
    out.* = std.mem.zeroes(Poi);
    out.model = entity;
    out.receiver = receiver;
    out.authored_model = entity;
    out.authored_receiver = receiver;
    out.resource = resource;
    out.runtime = runtime;
    out.array = poi;
    out.poi = poi;
    out.poi_count = 1;
    out.receiver_class = 0x780000;
    out.chain_count = 1;
    return @intFromBool(mode != 24);
}
export fn native_authored_poi_revalidate(_: *const Poi) c_int {
    return @intFromBool(proof);
}
export fn native_resource_identity_resolve(w: usize, r: usize, out: *Resource) c_int {
    check(@src(), w == world and r == resource);
    out.* = std.mem.zeroes(Resource);
    out.key = .{ 1, 2, 3, 4 };
    out.world = world;
    out.actual_resource = resource;
    return @intFromBool(proof);
}
export fn native_script_shoot_dispatch_source_revalidate(_: *const Script) c_int {
    return @intFromBool(proof);
}
export fn native_script_shoot_dispatch_consume(_: usize, _: usize, _: usize, _: usize, local: u32) u32 {
    return local;
}
export fn native_script_shoot_dispatch_install() c_int {
    return 1;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn float(address: usize, value: f32) void {
    win.store(f32, address, value);
}
fn setup() void {
    valid = true;
    retained = true;
    proof = true;
    client = false;
    fault = 0;
    updates = 0;
    describes = 0;
    resolves = 0;
    bound_reserves = 0;
    support_reads = 0;
    @memset(std.mem.asBytes(frame), 0);
    for (0..23) |i| @memset(@as([*]u8, @ptrFromInt(0x20000000 + i * 0x10000))[0..0x2000], 0);
    native_frame.* = @splat(0);
    const words = [_][2]u32{ .{ actor + 0x50, 3 }, .{ other + 0x50, 3 }, .{ actor + 8, model }, .{ model + 0x34, brain }, .{ model + 0x38, body }, .{ brain + 0x198, 1 }, .{ wrapper + 4, actor }, .{ task, 0x880000 }, .{ task + 0x10, other }, .{ competitor, 0x880000 }, .{ competitor + 0xd0, actor }, .{ component + 0x8c, competitor }, .{ actor + 0x142c, component }, .{ body, 0x880000 }, .{ body + 0xec, support }, .{ 0xfb4a20, world }, .{ 0xe90220, provider }, .{ 0xe90184, registry }, .{ world + 0x400, table }, .{ table, registry }, .{ registry, manager }, .{ registry + 0x28, 1 }, .{ manager, 0x880000 }, .{ manager + 0x24, gizmo }, .{ gizmo, 0x880000 }, .{ node + 8, entity }, .{ entity + 0x3c, receiver }, .{ receiver, 0x880000 }, .{ receiver + 0x14, component }, .{ receiver + 0x2c, resource }, .{ receiver + 0x30, poi }, .{ component, 0x880000 }, .{ resource + 0x6f8, runtime }, .{ runtime + 0x6c, poi }, .{ runtime + 0x68, 1 }, .{ poi + 0xd4, receiver }, .{ poi + 0xb4, name }, .{ 0xfb4b6c, 43 }, .{ 0xea178c, 47 }, .{ 0xe637b4, 53 } };
    for (words) |word| put(word[0], word[1]);
    win.store(i16, actor + 0xdc0, 12);
    win.store(i16, other + 0xdc0, 13);
    win.store(u8, actor + 0x57, 1);
    float(actor + 0xe28, 0.5);
    win.store(u8, model + 0x42, 1);
    win.store(u16, model + 0x40, 71);
    float(task + 0x14, 1);
    float(task + 0x18, 2);
    float(task + 0x1c, 3);
    win.store(u16, body + 0xc8, 2);
    win.store(u8, support + 0x19, 0x40);
    win.store(u8, support + 0x219, if (mode == 48) 0x20 else 0x40);
    float(body + 0x110, 1);
    float(body + 0xf4, 1);
    win.store(u16, body + 0x102, 3);
    native_frame[1] = 0x890000;
    native_frame[2] = actor;
    @memcpy(@as([*]u8, @ptrFromInt(name))[0..6], "piece\x00");
    frame.epoch = 100 + mode;
    frame.sequence = 83;
    script_source = std.mem.zeroes(Script);
    script_source.actor = actor;
    script_source.model = model;
    script_source.state = task;
    script_source.native_stack = @intFromPtr(native_frame);
    script_source.input.clock = 43;
    script_source.input.model_class = 0x780000;
    script_source.input.brain_class = 0x780004;
    script_source.input.state_class = 0x780008;
    script_source.input.argument_count = 2;
    fixture.clear();
}
const Binding = extern struct { words: [32]usize };
const Snapshot = extern struct { finish: c_int, result: c_int, validated: c_int, fault: c_int, period: u32, argument: u32, heading: u32, height: u32, err: u32, updates: u32, describes: u32, resolves: u32, bound_reserves: u32, delta: f32, points: [6]f32, position: [3]f32, velocity: [4]f32, engine_seed: u32, game_seed: u32, actor_state: [0x1d0]u8, task_state: [0x30]u8, body_state: [0x140]u8, competitor_state: [0xd4]u8, cadence: p.SyncCadence, gates: [2]p.SyncFireTaskGate, cadence_count: u32, gate_count: u32, binding: Binding, diagnostics: fixture.Diagnostics };
fn perform(out: *Snapshot) void {
    out.period = if (client) 7 else 2;
    out.delta = if (client) 0.2 else 0.1;
    out.argument = @intFromBool(!client);
    out.position = .{ if (client) 7 else 1, 2, 3 };
    out.velocity[0] = if (client) 7 else 1;
    for (&out.points, 0..) |*value, i| value.* = @floatFromInt(i + @as(usize, if (client) 10 else 1));
    if (client) {
        put(0xea178c, 59);
        put(0xe637b4, 61);
        float(actor + 0xe28, 1.5);
        float(task + 0x1c, 5);
        win.store(u8, model + 0x42, 0);
        float(body + 0x110, 2);
        win.store(u16, body + 0xc8, 5);
        float(competitor + 0x60, 2);
    }
    switch (mode) {
        0...2 => {
            if (mode == 1 and client) win.store(u8, actor + 0x57, 2);
            if (mode == 2) out.period = 0;
            cb.cadence_apply_period(actor, &out.period);
        },
        3 => {
            win.store(u16, task + 4, p.SYNC_FIRE_TASK_QUEUES_SHOT);
            win.store(u16, task + 6, 3);
            _ = cb.cadence_apply_fire_task_gate(actor, task, @intFromBool(!client), &out.delta);
        },
        4 => {
            out.result = @intFromBool(!client);
            _ = cb.cadence_apply_attack_support(actor, &out.result);
        },
        5 => out.result = cb.cadence_apply_breakup_visibility(actor, @intFromBool(!client)),
        6 => cb.cadence_apply_death_breakup(actor, &out.argument),
        7 => out.result = cb.cadence_apply_fall_visibility(actor, @intFromBool(!client)),
        8...10 => {
            if (mode == 9 and client) float(task + 0x14, 4);
            if (mode != 10) _ = ct.cadence_prepare_aim_task(actor, task);
            out.result = ct.cadence_aim_task_visibility(actor, task, @intFromBool(!client));
        },
        11...13 => {
            if (mode == 12) put(actor + 0x50, 1);
            if (mode == 13 and client) put(competitor, 0x880004);
            ct.cadence_prepare_rts_competitor(competitor, &out.delta);
        },
        14, 15 => {
            put(task + 4, component);
            if (mode == 15 and client) put(component, 0x880004);
            _ = ct.cadence_prepare_aim_base(task, wrapper, &out.delta);
        },
        16, 17 => out.result = cf.cadence_force_target_visibility(actor, other, 3, @intFromBool(!client)),
        18, 19 => cf.cadence_force_geometry_input(actor, other, if (client and mode == 19) 4 else 3, &out.points),
        20...25 => {
            if (client) {
                win.store(u16, model + 0x40, 73);
                float(actor + 0x24, 7);
                if (mode == 21) put(0xfb4b6c, 44);
            }
            var limit: f32 = if (client) 9 else 4;
            csp.cadence_spellit_prepare(actor, manager, @intFromPtr(native_frame), &limit);
            out.delta = limit;
            if (mode >= 22) {
                if (client and mode == 23) @memcpy(@as([*]u8, @ptrFromInt(name))[0..6], "other\x00");
                cn.cadence_spellit_node(@intFromPtr(native_frame), gizmo, node, &out.position);
            }
            out.heading = csp.cadence_spellit_operand(@intFromPtr(native_frame), 0, 99);
            out.height = csp.cadence_spellit_operand(@intFromPtr(native_frame), 1, 99);
            csp.cadence_spellit_position(@intFromPtr(native_frame), out.points[0..3]);
        },
        26...30, 40...55 => {
            if (mode == 26) put(body + 0xec, 0);
            if (mode == 29) out.velocity[0] = std.math.nan(f32);
            if (mode == 30) put(model + 0x38, 0);
            if (client and mode >= 40 and mode <= 44) put(body + 0xec, 0);
            if (client and mode == 44) put(body, 0x880004);
            if ((!client and mode >= 49 and mode != 53) or mode == 54) put(body + 0xec, 0);
            if (client and mode >= 49 and mode != 54) put(body + 0xec, support);
            cm.cadence_character_motion_input(actor, body, &out.velocity);
        },
        31...33 => {
            put(actor + 0x164, if (client or mode != 32) other else 0);
            float(actor + 0x168, if (client) 19 else 5);
            put(actor + 0x1c8, if (client) 0 else 32);
            cp.cadence_primary_perception(actor);
        },
        34...36 => {
            if (client and mode == 35) script_source.input.argument_hash[0] = 1;
            if (client and mode == 36) proof = false;
            var canonical: u32 = 9;
            out.result = cs.cadence_script_shoot_dispatch_begin(&script_source, @intFromBool(!client), &canonical, @ptrCast(&out.binding));
            out.argument = canonical;
            out.validated = cs.cadence_script_shoot_dispatch_validate(&script_source, @ptrCast(&out.binding));
        },
        else => {
            var debug: [4]u32 = @splat(0);
            if (!(client and mode == 38)) out.result = gate.apply(actor, if (client and mode == 37) p.SYNC_ACTOR_FALL_VISIBILITY else p.SYNC_ACTOR_BREAKUP_VISIBILITY, 0, 0, @intFromBool(!client), null, &debug);
        },
    }
}
fn run() Snapshot {
    setup();
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    win.SetLastError(1234);
    perform(&out);
    out.finish = ci.cadence_finish();
    check(@src(), ci.cadence_abort_frame(&lease) != 0);
    client = true;
    frame.sequence += 1;
    token.release += 1;
    token.sequence = frame.sequence;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    win.SetLastError(1234);
    perform(&out);
    out.err = win.GetLastError();
    out.finish = ci.cadence_finish();
    check(@src(), ci.cadence_abort_frame(&lease) != 0);
    out.fault = fault;
    out.updates = updates;
    out.describes = describes;
    out.resolves = resolves;
    out.bound_reserves = bound_reserves;
    out.engine_seed = win.load(u32, 0xea178c);
    out.game_seed = win.load(u32, 0xe637b4);
    @memcpy(&out.actor_state, @as([*]const u8, @ptrFromInt(actor))[0..out.actor_state.len]);
    @memcpy(&out.task_state, @as([*]const u8, @ptrFromInt(task))[0..out.task_state.len]);
    @memcpy(&out.body_state, @as([*]const u8, @ptrFromInt(body))[0..out.body_state.len]);
    @memcpy(&out.competitor_state, @as([*]const u8, @ptrFromInt(competitor))[0..out.competitor_state.len]);
    out.cadence = frame.cadence[0];
    out.gates = frame.fire_task_gates[0..2].*;
    out.cadence_count = frame.cadence_count;
    out.gate_count = frame.fire_task_gate_count;
    out.diagnostics = fixture.capture();
    if (out.binding.words[0] != 0) {
        check(@src(), out.binding.words[4] == win.GetCurrentThreadId());
        out.binding.words[4] = 0;
    }
    return out;
}
fn protect(address: usize, length: usize, protection: u32) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, length, protection, &old) != 0);
}
fn jump(address: usize, target: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, target -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
var contact_shot: u32 = 0;
const ProjectileIdentity = @import("projectile_types.zig").Identity;
export fn projectiles_observe_live(object: usize, out: *ProjectileIdentity) c_int {
    if (object == body and contact_shot != 0) {
        out.* = std.mem.zeroes(ProjectileIdentity);
        out.id = contact_shot;
        out.weapon = 7;
        return 1;
    }
    return 0;
}
fn installedHooks() void {
    const patches = @import("cadence_install.zig").patches();
    check(@src(), patches.len == 66);
    for (patches) |patch| {
        check(@src(), (patch.address & 0xffff) + patch.expected.len <= 0x10000);
        protect(patch.address & ~@as(usize, 0xffff), 0x10000, 0x40);
        @memcpy(@as([*]u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected);
    }
    win.store(u8, 0x96d954, 0xc3);
    win.store(u8, 0x464b44, 0xc3);
    win.store(u8, 0x464b71, 0xc3);
    win.store(u8, 0x8789f7, 0xc3);
    win.store(u8, 0x9ddc1f, 0xc3);
    win.store(u8, 0x84bd13, 0xc3);
    win.store(u8, 0x84bd21, 0xc3);
    jump(0x42fe42, @intFromPtr(&allow_cont));
    jump(0x42fff6, @intFromPtr(&skip_cont));
    for (patches) |bad| {
        win.store(u8, bad.address, 0xcc);
        check(@src(), ci.cadence_install() == 0);
        win.store(u8, bad.address, bad.expected[0]);
        for (patches) |patch| check(@src(), std.mem.eql(u8, patch.expected, @as([*]const u8, @ptrFromInt(patch.address))[0..patch.expected.len]));
    }
    for (patches) |patch| protect(patch.address & ~@as(usize, 0xffff), 0x10000, 0x20);
    check(@src(), ci.cadence_install() != 0 and ci.cadence_install() != 0 and ci.cadence_ready() != 0);
    const controller_table: u32 = 0x12345678;
    check(@src(), invoke_force_first_target(&controller_table, 0) == controller_table);
    check(@src(), invoke_force_first_target(&controller_table, 0x23456789) == 0x23456789);
    for (patches) |patch| {
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(patch.address, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
    mode = 0;
    setup();
    var stack: [16]u32 = @splat(0);
    cadence_fixture_actor = actor;
    cadence_fixture_task = task;
    cadence_fixture_frame = @intFromPtr(&stack);
    win.store(u16, task + 4, p.SYNC_FIRE_TASK_QUEUES_SHOT);
    win.store(u16, task + 6, 3);
    float(@intFromPtr(&stack) + 0x14, 0.1);
    put(actor + 0x164, other);
    float(actor + 0x168, 5);
    put(actor + 0x1c8, 32);
    frame.epoch = 2000;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    cadence_fixture_entry = 0x96d94a;
    cadence_fixture_value = 2;
    invoke_period();
    check(@src(), win.load(u8, actor + 0x138e) == 2);
    cadence_fixture_entry = 0x42fe2b;
    invoke_fire();
    check(@src(), cadence_fixture_branch == 1);
    cadence_fixture_entry = 0x8789f0;
    cadence_fixture_value = 1;
    invoke_support();
    check(@src(), cadence_fixture_value == 1);
    cadence_fixture_entry = 0x9ddc19;
    invoke_perception();
    check(@src(), ci.cadence_finish() != 0 and frame.cadence_count == 1 and frame.fire_task_gate_count == 3 and ci.cadence_abort_frame(&lease) != 0);
    client = true;
    frame.sequence += 1;
    token.release += 1;
    token.sequence = frame.sequence;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    win.store(u8, model + 0x42, 0);
    float(@intFromPtr(&stack) + 0x14, 0.2);
    put(actor + 0x164, 0);
    put(actor + 0x1c8, 0);
    cadence_fixture_entry = 0x96d94a;
    cadence_fixture_value = 7;
    invoke_period();
    check(@src(), cadence_fixture_value == 2 and win.load(u8, actor + 0x138e) == 2);
    cadence_fixture_entry = 0x42fe2b;
    invoke_fire();
    check(@src(), cadence_fixture_branch == 1 and stack[5] == 0x3dcccccd);
    cadence_fixture_entry = 0x8789f0;
    cadence_fixture_value = 0;
    invoke_support();
    check(@src(), cadence_fixture_value == 1);
    cadence_fixture_entry = 0x9ddc19;
    invoke_perception();
    check(@src(), win.load(usize, actor + 0x164) == other and win.load(f32, actor + 0x168) == 5);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}

comptime {
    asm (
        \\.text
        \\.globl _invoke_force_first_target
        \\_invoke_force_first_target:
        \\    pushl %ebx
        \\    pushl %esi
        \\    movl 12(%esp),%ebx
        \\    movl 16(%esp),%eax
        \\    xorl %esi,%esi
        \\    movl $0x84bd0d,%edx
        \\    call *%edx
        \\    popl %esi
        \\    popl %ebx
        \\    ret
    );
}
const island_order = struct {
    extern fn zillo_island_order_before_solve(usize, usize) void;
    extern fn zillo_island_order_before_contacts(usize, usize) void;
};

fn zilloIslandOrder() void {
    const order = island_order;
    const origins = @import("zillo_support_origin.zig");
    setup();
    frame.epoch = 16000;
    frame.level = 112;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);

    var island_data: [0x18]u8 = @splat(0);
    var bodies: [3][0xa4]u8 = @splat(@splat(0));
    var owners: [3][0x1a4]u8 = @splat(@splat(0));
    var labels: [3][32]u8 = @splat(@splat(0));
    var edges: [3][0x20]u8 = @splat(@splat(0));
    const island = @intFromPtr(&island_data);
    var nodes: [3]usize = undefined;
    var links: [3]usize = undefined;
    for (0..3) |index| {
        const collider = @intFromPtr(&bodies[index]);
        const collider_owner = @intFromPtr(&owners[index]);
        labels[index][0] = 'A' + @as(u8, @intCast(index));
        nodes[index] = collider;
        links[index] = @intFromPtr(&edges[index]);
        put(collider, 0xc69eac);
        win.store(u8, collider + 0x19, 0x4f);
        put(collider + 0x1c, @intFromPtr(&labels[index]));
        put(collider + 0x28, collider_owner);
        put(collider + 0x34, island);
        put(collider_owner, 0xc20f64);
        put(collider_owner + 0x1a0, collider);
        origins.remember(world, collider_owner, collider, .{ .clock = 607, .actor_slot = 4, .generation = 29, .throw_slot = 2, .model = 5 });
        put(links[index], 0xc696d4);
    }
    put(island + 8, nodes[1]);
    put(nodes[1] + 0x10, nodes[2]);
    put(nodes[2] + 0x14, nodes[1]);
    put(nodes[2] + 0x10, nodes[0]);
    put(nodes[0] + 0x14, nodes[2]);
    order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, island + 8) == nodes[0] and win.load(usize, nodes[0] + 0x14) == 0 and
        win.load(usize, nodes[0] + 0x10) == nodes[1] and win.load(usize, nodes[1] + 0x14) == nodes[0] and
        win.load(usize, nodes[1] + 0x10) == nodes[2] and win.load(usize, nodes[2] + 0x14) == nodes[1] and
        win.load(usize, nodes[2] + 0x10) == 0);

    put(island + 0xc, links[0]);
    put(links[0] + 4, links[1]);
    put(links[1] + 8, links[0]);
    put(links[1] + 4, links[2]);
    put(links[2] + 8, links[1]);
    for ([_][2]usize{ .{ nodes[1], nodes[2] }, .{ nodes[0], nodes[2] }, .{ nodes[0], nodes[1] } }, links) |pair, link| {
        put(link + 0xc, pair[0]);
        put(link + 0x10, pair[1]);
        put(link + 0x1c, link + 0x18);
    }
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 0xc) == links[2] and win.load(usize, links[2] + 8) == 0 and
        win.load(usize, links[2] + 4) == links[1] and win.load(usize, links[1] + 8) == links[2] and
        win.load(usize, links[1] + 4) == links[0] and win.load(usize, links[0] + 8) == links[1] and
        win.load(usize, links[0] + 4) == 0);
    check(@src(), win.load(usize, links[0] + 0xc) == nodes[1] and win.load(usize, links[0] + 0x10) == nodes[2] and
        win.load(usize, links[0] + 0x1c) == links[0] + 0x18);
    put(links[2] + 0x10, nodes[2]);
    const previous = edges;
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), std.meta.eql(edges, previous) and win.load(usize, island + 0xc) == links[2]);

    var polygon_body: [0xa4]u8 = @splat(0);
    var polygon_owner: [0x1a4]u8 = @splat(0);
    var polygon_class: u32 = 0xc695d4;
    const polygon = @intFromPtr(&polygon_body);
    const polygon_source = @intFromPtr(&polygon_owner);
    put(polygon, 0xc69eac);
    win.store(u8, polygon + 0x19, 0x40);
    put(polygon + 0x1c, @intFromPtr("polySurface77"));
    put(polygon + 0x24, @intFromPtr(&polygon_class));
    put(polygon + 0x28, polygon_source);
    put(polygon_source, 0xc20f64);
    put(polygon_source + 0x1a0, polygon);
    put(island + 0xc, links[0]);
    for ([_][2]usize{ .{ polygon, nodes[2] }, .{ nodes[0], nodes[2] }, .{ nodes[0], nodes[1] } }, links, 0..) |pair, link, index| {
        put(link + 4, if (index + 1 == links.len) 0 else links[index + 1]);
        put(link + 8, if (index == 0) 0 else links[index - 1]);
        put(link + 0xc, pair[0]);
        put(link + 0x10, pair[1]);
    }
    const unresolved = edges;
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), std.meta.eql(edges, unresolved) and win.load(usize, island + 0xc) == links[0]);
    island_effect_body = polygon;
    put(polygon_source + 0x1a0, nodes[2]);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), std.meta.eql(edges, unresolved) and win.load(usize, island + 0xc) == links[0]);
    put(polygon_source + 0x1a0, polygon);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 0xc) == links[2] and win.load(usize, links[2] + 4) == links[1] and
        win.load(usize, links[1] + 4) == links[0] and win.load(usize, links[0] + 0xc) == polygon);
    island_effect_body = 0;
    edges = unresolved;
    put(island + 0xc, links[0]);
    const native_birth: origins.Polygon = .{ .root_clock = 800, .clock = 825, .mode = 4 };
    origins.rememberPolygon(world, polygon_source, polygon, native_birth);
    check(@src(), std.meta.eql(origins.polygon(world, polygon_source, polygon).?, native_birth) and
        origins.polygon(world, polygon_source + 4, polygon) == null);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 0xc) == links[2] and win.load(usize, links[2] + 4) == links[1] and
        win.load(usize, links[1] + 4) == links[0] and win.load(usize, links[0] + 4) == 0);
    check(@src(), win.load(usize, links[0] + 0xc) == polygon and win.load(usize, links[0] + 0x10) == nodes[2] and
        win.load(usize, links[0] + 0x1c) == links[0] + 0x18);
    origins.rememberPolygon(world, nodes[1], nodes[2], native_birth);
    check(@src(), origins.polygon(world, polygon_source, polygon) == null and origins.polygon(world, nodes[1], nodes[2]) == null);
    origins.forget(polygon);
    var later_birth = native_birth;
    later_birth.clock += 2;
    origins.rememberPolygon(world, polygon_source, polygon, later_birth);
    check(@src(), std.meta.eql(origins.polygon(world, polygon_source, polygon).?, later_birth));

    origins.forget(nodes[0]);
    const effect = nodes[0];
    island_effect_body = effect;
    put(effect + 0x24, @intFromPtr(&polygon_class));
    put(island + 8, effect);
    put(effect + 0x10, polygon);
    put(effect + 0x14, 0);
    put(polygon + 0x14, effect);
    put(polygon + 0x34, island);
    order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, island + 8) == polygon and win.load(usize, polygon + 0x14) == 0 and
        win.load(usize, polygon + 0x10) == effect and win.load(usize, effect + 0x14) == polygon and
        win.load(usize, effect + 0x10) == 0);
    put(island + 0xc, links[0]);
    put(links[0] + 4, links[1]);
    put(links[0] + 8, 0);
    put(links[0] + 0xc, effect);
    put(links[0] + 0x10, polygon);
    put(links[1] + 4, 0);
    put(links[1] + 8, links[0]);
    put(links[1] + 0xc, polygon);
    put(links[1] + 0x10, effect);
    put(polygon + 0x34, 0);
    const bad_island = edges;
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), std.meta.eql(edges, bad_island) and win.load(usize, island + 0xc) == links[0]);
    put(polygon + 0x34, island);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 0xc) == links[1] and win.load(usize, links[1] + 4) == links[0] and
        win.load(usize, links[0] + 8) == links[1] and win.load(usize, links[0] + 4) == 0);

    var petal_body: [0xa4]u8 = @splat(0);
    var petal_owner: [0x1a4]u8 = @splat(0);
    var petal_class: u32 = 0xc69b0c;
    const petal = @intFromPtr(&petal_body);
    const petal_source = @intFromPtr(&petal_owner);
    put(petal, 0xc69eac);
    win.store(u8, petal + 0x19, 0x40);
    put(petal + 0x1c, @intFromPtr("Petals_2"));
    put(petal + 0x24, @intFromPtr(&petal_class));
    put(petal + 0x28, petal_source);
    put(petal + 0x34, island);
    put(petal_source, 0xc20f64);
    put(petal_source + 0x1a0, petal);
    put(island + 8, effect);
    put(effect + 0x14, 0);
    put(effect + 0x10, petal);
    put(petal + 0x14, effect);
    put(petal + 0x10, polygon);
    put(polygon + 0x14, petal);
    put(polygon + 0x10, 0);
    put(island + 0xc, links[0]);
    put(links[0] + 4, links[1]);
    put(links[0] + 8, 0);
    put(links[0] + 0xc, effect);
    put(links[0] + 0x10, polygon);
    put(links[1] + 4, 0);
    put(links[1] + 8, links[0]);
    put(links[1] + 0xc, petal);
    put(links[1] + 0x10, effect);

    order.zillo_island_order_before_solve(island, 0xa3a835);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 8) == effect and win.load(usize, island + 0xc) == links[0]);
    island_plate_body = petal;
    put(petal_source + 0x1a0, polygon);
    order.zillo_island_order_before_solve(island, 0xa3a835);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 8) == effect and win.load(usize, island + 0xc) == links[0]);
    put(petal_source + 0x1a0, petal);
    order.zillo_island_order_before_solve(island, 0xa3a835);
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 8) == petal and win.load(usize, petal + 0x14) == 0 and
        win.load(usize, petal + 0x10) == polygon and win.load(usize, polygon + 0x14) == petal and
        win.load(usize, polygon + 0x10) == effect and win.load(usize, effect + 0x14) == polygon and
        win.load(usize, effect + 0x10) == 0);
    check(@src(), win.load(usize, island + 0xc) == links[1] and win.load(usize, links[1] + 4) == links[0] and
        win.load(usize, links[0] + 8) == links[1] and win.load(usize, links[0] + 4) == 0 and
        win.load(usize, links[1] + 0xc) == petal and win.load(usize, links[1] + 0x10) == effect and
        win.load(usize, links[0] + 0xc) == effect and win.load(usize, links[0] + 0x10) == polygon);
    island_plate_body = 0;
    island_effect_body = 0;

    var large_bodies: [24][0xa4]u8 = @splat(@splat(0));
    var large_owners: [24][0x1a4]u8 = @splat(@splat(0));
    var large_labels: [24][32]u8 = @splat(@splat(0));
    for (&large_bodies, &large_owners, &large_labels, 0..) |*collider_data, *owner_data, *label, index| {
        const collider = @intFromPtr(collider_data);
        const collider_owner = @intFromPtr(owner_data);
        label[0] = 'A' + @as(u8, @intCast(index));
        put(collider, 0xc69eac);
        win.store(u8, collider + 0x19, 0x4f);
        put(collider + 0x1c, @intFromPtr(label));
        put(collider + 0x28, collider_owner);
        put(collider_owner, 0xc20f64);
        put(collider_owner + 0x1a0, collider);
        origins.remember(world, collider_owner, collider, .{ .clock = 809, .actor_slot = 4, .generation = 29, .throw_slot = 2, .model = 5 });
    }
    var large_edges: [276][0x20]u8 = @splat(@splat(0));
    var index: usize = 0;
    for (0..large_bodies.len) |first| {
        for (first + 1..large_bodies.len) |second| {
            const link = @intFromPtr(&large_edges[index]);
            put(link, 0xc696d4);
            put(link + 4, if (index == 0) 0 else @intFromPtr(&large_edges[index - 1]));
            put(link + 8, if (index + 1 == large_edges.len) 0 else @intFromPtr(&large_edges[index + 1]));
            put(link + 0xc, @intFromPtr(&large_bodies[first]));
            put(link + 0x10, @intFromPtr(&large_bodies[second]));
            index += 1;
        }
    }
    check(@src(), index == large_edges.len);
    const old_head = @intFromPtr(&large_edges[large_edges.len - 1]);
    const old_tail = @intFromPtr(&large_edges[0]);
    put(island + 8, @intFromPtr(&large_bodies[0]));
    put(island + 0xc, old_head);
    put(old_tail + 8, 0);
    const invalid_chain = large_edges;
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), std.meta.eql(large_edges, invalid_chain) and win.load(usize, island + 0xc) == old_head);
    put(old_tail + 8, @intFromPtr(&large_edges[1]));
    order.zillo_island_order_before_contacts(island, 0xa3665d);
    var previous_link: usize = 0;
    var current_link = win.load(usize, island + 0xc);
    for (&large_edges) |*link_data| {
        check(@src(), current_link == @intFromPtr(link_data));
        check(@src(), win.load(usize, current_link + 8) == previous_link);
        previous_link = current_link;
        current_link = win.load(usize, current_link + 4);
    }
    check(@src(), current_link == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn zilloDishIslandOrder() void {
    const origins = @import("zillo_support_origin.zig");
    setup();
    frame.epoch = 16003;
    frame.level = 112;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);

    put(world + 0x22e4, provider);
    put(provider, 0xada098);
    put(provider + 0xc, world);
    put(0xf9dd10, registry);
    put(registry + 8 + 84 * 4, resource);
    put(resource + 0x54, provider);
    put(resource + 0x34, @intFromPtr("ZilloBeast_B_temp.led"));
    put(resource + 0x40, @intFromPtr("ZilloBeast_B_temp"));

    const labels = [_][:0]const u8{ "plate_grey_solid", "joint1", "joint2", "joint3", "joint4", "joint5", "signal_base", "joint11", "signal_dish", "joint12", "FrontBody" };
    const classes = [_]u32{ 0xc69b0c, 0xc695d4, 0xc69b0c, 0xc695d4, 0xc69b0c, 0xc69b0c, 0xc69b7c, 0xc69b7c, 0xc695d4, 0xc69b0c, 0xc69b0c };
    var island_data: [0x18]u8 = @splat(0);
    var physics_data: [0x14]u8 = @splat(0);
    var bodies: [labels.len][0xa4]u8 = @splat(@splat(0));
    var owners: [labels.len][0x1a4]u8 = @splat(@splat(0));
    var counted: [labels.len][24]u8 = @splat(@splat(0));
    var names: [labels.len][32]u8 = @splat(@splat(0));
    var shapes = classes;
    const island = @intFromPtr(&island_data);
    const physics = @intFromPtr(&physics_data);
    const last = labels.len - 1;
    var nodes: [labels.len]usize = undefined;
    for (labels, 0..) |label, index| {
        const owner = @intFromPtr(&owners[index]);
        const collider = @intFromPtr(&bodies[index]);
        nodes[index] = collider;
        counted[index][0] = @intCast(label.len + 2);
        @memcpy(counted[index][1 .. label.len + 1], label);
        @memcpy(names[index][0..label.len], label);
        put(owner, 0xc20f64);
        win.store(u8, owner + 6, 84);
        put(owner + 0xc, @intFromPtr(&counted[index]));
        put(owner + 0x1c, if (index == 0 or index == last) 0 else @intFromPtr(&owners[index - 1]));
        put(owner + 0x20, if (index + 1 < last) @intFromPtr(&owners[index + 1]) else 0);
        put(owner + 0x1a0, collider);
        put(collider, 0xc69eac);
        win.store(u16, collider + 0x18, if (index == 0) 0x2001 else 0x4f01);
        put(collider + 0x1c, @intFromPtr(&names[index]));
        put(collider + 0x24, @intFromPtr(&shapes[index]));
        put(collider + 0x28, owner);
        put(collider + 0x2c, physics);
        put(collider + 0x34, island);
        put(collider + 0x90, 0x41000131);
        if (index != 0) {
            put(collider + 0x10, if (index > 1) @intFromPtr(&bodies[index - 1]) else 0);
            put(collider + 0x14, if (index < last) @intFromPtr(&bodies[index + 1]) else 0);
        }
    }
    origins.remember(world, @intFromPtr(&owners[last]), nodes[last], .{ .clock = 9869, .actor_slot = 4, .generation = 29, .throw_slot = 0, .model = 28 });
    put(island + 8, nodes[last]);
    island_plate_body = nodes[0];
    const original = bodies;

    put(@intFromPtr(&owners[0]) + 0x20, @intFromPtr(&owners[2]));
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), std.meta.eql(bodies, original));
    put(@intFromPtr(&owners[0]) + 0x20, @intFromPtr(&owners[1]));
    put(nodes[6] + 0x2c, 0);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    put(nodes[6] + 0x2c, physics);
    check(@src(), std.meta.eql(bodies, original));
    island_plate_body = 0;
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), std.meta.eql(bodies, original));
    island_plate_body = nodes[0];
    defer island_plate_body = 0;

    put(nodes[0] + 0x2c, 0);
    put(nodes[0] + 0x34, 0);
    put(nodes[0] + 0x90, 0x41000110);
    put(0xfb0b10, 0);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, island + 8) == nodes[last] and win.load(usize, nodes[last] + 0x10) == nodes[last - 1]);

    var scheduler_data: [0x30]u8 = @splat(0);
    var schedule_node_data: [0xc]u8 = @splat(0);
    var schedule_entry_data: [0xc]u8 = @splat(0);
    var listener_data: [0x28]u8 = @splat(0);
    const scheduler = @intFromPtr(&scheduler_data);
    const schedule_node = @intFromPtr(&schedule_node_data);
    const schedule_entry = @intFromPtr(&schedule_entry_data);
    const listener = @intFromPtr(&listener_data);
    put(0xfb0b10, scheduler);
    defer put(0xfb0b10, 0);
    put(scheduler + 0x2c, schedule_node);
    put(schedule_node + 8, schedule_entry);
    put(schedule_entry, listener);
    put(listener, 0xc213dc);
    put(listener + 0xc, provider);
    put(listener + 0x24, island);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, nodes[last] + 0x10) == nodes[last - 1]);
    put(listener + 0x24, physics);
    put(nodes[0] + 0x90, 0x41000111);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, nodes[last] + 0x10) == nodes[last - 1]);
    put(nodes[0] + 0x90, 0x41000110);
    put(nodes[0] + 0x2c, island);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, nodes[last] + 0x10) == nodes[last - 1]);
    put(nodes[0] + 0x2c, 0);
    island_order.zillo_island_order_before_solve(island, 0xa3a835);
    check(@src(), win.load(usize, island + 8) == nodes[last] and win.load(usize, nodes[last] + 0x10) == nodes[1]);
    for (1..last) |index| {
        check(@src(), win.load(usize, nodes[index] + 0x14) == nodes[if (index == 1) last else index - 1]);
        check(@src(), win.load(usize, nodes[index] + 0x10) == if (index + 1 < last) nodes[index + 1] else 0);
    }

    var edges: [2][0x20]u8 = @splat(@splat(0));
    const first = @intFromPtr(&edges[0]);
    const second = @intFromPtr(&edges[1]);
    put(island + 0xc, first);
    put(first + 4, second);
    put(second + 8, first);
    for ([_]usize{ first, second }, [_]usize{ nodes[9], nodes[5] }) |link, part| {
        put(link, 0xc696d4);
        put(link + 0xc, nodes[last]);
        put(link + 0x10, part);
    }
    island_order.zillo_island_order_before_contacts(island, 0xa3665d);
    check(@src(), win.load(usize, island + 0xc) == second and win.load(usize, second + 4) == first and
        win.load(usize, first + 8) == second and win.load(usize, first + 4) == 0 and
        win.load(usize, first + 0x10) == nodes[9] and win.load(usize, second + 0x10) == nodes[5]);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    put(0xf9dd10, 0);
    put(world + 0x22e4, 0);
}

fn zilloBarcSupport() void {
    const reference = @import("support_reference.zig");
    const rules = @import("character_support.zig");
    const source = @import("vehicle_body_source.zig");
    mode = 53;
    setup();
    frame.epoch = 16001;
    frame.level = 112;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);

    put(0xfbdb3c, manager);
    put(manager + 0x15c, 1);
    put(manager + 0x160, component);
    put(component + 0x294, task);
    put(component + 0x29c, other);
    win.store(u16, other + 0xdc0, 417);
    win.store([6]u8, name, "BARC2\x00".*);
    put(node, 0xc69b0c);
    for ([_]usize{ support, support + 0x200 }) |collider| {
        put(collider, 0xc69eac);
        win.store(u8, collider + 0x19, 0x42);
        put(collider + 0x1c, name);
        put(collider + 0x24, node);
    }
    put(task + 0x260, support);
    var key: [2]u32 = undefined;
    var flags: u32 = 0;
    check(@src(), reference.capture(support, &key, &flags) and flags == p.SYNC_SUPPORT_VEHICLE);
    var state = std.mem.zeroes(p.SyncCharacterMotionState);
    state.support_frame = key[0];
    state.support_event = key[1];
    state.support_material_flags = flags;
    var verified: [2]u32 = undefined;
    check(@src(), reference.source(support, &state, &verified) and std.meta.eql(key, verified));

    put(task + 0x260, support + 0x200);
    check(@src(), !reference.source(support, &state, &verified));
    check(@src(), reference.source(support + 0x200, &state, &verified) and std.meta.eql(key, verified));
    put(manager + 0x15c, 2);
    put(manager + 0x164, component);
    check(@src(), !reference.source(support + 0x200, &state, &verified));
    put(manager + 0x164, wrapper);
    put(wrapper + 0x294, brain);
    put(wrapper + 0x29c, other);
    put(brain + 0x260, support);
    check(@src(), !reference.source(support + 0x200, &state, &verified));
    put(manager + 0x15c, 1);
    put(node, 0xc699f4);
    check(@src(), !reference.source(support + 0x200, &state, &verified));
    put(node, 0xc69b0c);

    client = true;
    mode = 17;
    check(@src(), source.supportKey(support + 0x200, &verified) and !std.meta.eql(key, verified));
    var stale = state;
    stale.support_event = verified[1];
    check(@src(), !rules.same(&state, &stale) and !rules.canAcquire(&state, &stale));
    var absent = std.mem.zeroes(p.SyncCharacterMotionState);
    absent.support_material_flags = p.SYNC_SUPPORT_ABSENT;
    check(@src(), !rules.canAcquire(&absent, &state) and !rules.canRelease(&state, &absent));
    check(@src(), reference.resolve(&state) == 0);
    stale.support_material_flags |= p.SYNC_SUPPORT_SCENE;
    check(@src(), !@import("fire_validation.zig").supportValid(&stale));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    put(0xfbdb3c, 0);
}

fn zilloBarcAlignment() void {
    const alignment = @import("barc_alignment.zig");
    mode = 53;
    setup();
    frame.epoch = 16002;
    frame.level = 112;
    put(0xfbdb3c, manager);
    put(manager + 0x15c, 1);
    put(manager + 0x160, component);
    put(component + 0x294, task);
    put(component + 0x29c, other);
    win.store(u8, component + 0x166b, 4);
    win.store(u16, other + 0xdc0, 417);
    win.store([6]u8, name, "BARC2\x00".*);
    put(node, 0xc69b0c);
    put(task, 0xc5fff4);
    put(task + 0x260, support);
    put(support, 0xc69eac);
    win.store(u8, support + 0x19, 0x43);
    put(support + 0x1c, name);
    put(support + 0x24, node);
    put(support + 0x28, 0);
    put(0xfb4b6c, 428);

    var stack: [30]u32 = @splat(0);
    const entry = @intFromPtr(&stack);
    const matrix = entry + 0x38;
    stack[0..6].* = .{ 0x9977ce, support, matrix, 0, 1, 0 };
    const host = [_]f32{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 20, 30, 1 };
    const guest = [_]f32{ 0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 11, 22, 33, 1 };
    win.store([16]f32, matrix, host);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    var support_key: [2]u32 = undefined;
    check(@src(), !@import("vehicle_body_source.zig").supportKey(support, &support_key));
    alignment.barc_alignment_input(component, entry);
    check(@src(), frame.fire_task_gate_count == 1 and @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    for (0..5) |attempt| {
        token.release += 1;
        win.store([16]f32, matrix, guest);
        win.store(u8, support + 0x19, if (attempt == 4) 0x44 else 0x43);
        frame.fire_task_gates[0].slot = if (attempt == 1) 7 else 8;
        frame.fire_task_gates[0].payload.barc_alignment.clock = if (attempt == 2) 427 else 428;
        frame.fire_task_gates[0].payload.barc_alignment.body_flags = if (attempt == 3) 0x42 else 0x43;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        alignment.barc_alignment_input(component, entry);
        var expected = guest;
        if (attempt == 0) expected[0..12].* = host[0..12].*;
        check(@src(), std.meta.eql(win.load([16]f32, matrix), expected));
        check(@src(), (ci.cadence_finish() != 0) == (attempt == 0) and ci.cadence_abort_frame(&lease) != 0);
    }
    const suspension = @import("barc_suspension.zig");
    const validGate = @import("fire_validation.zig").valid;
    client = false;
    token.release += 1;
    win.store(u8, support + 0x19, 0x43);
    win.store(u8, component + 0x1664, 0);
    win.store(u8, component + 0x1667, 0);
    win.store(u16, component + 0x936, 2);
    put(component + 0x298, wrapper);
    put(wrapper + 0x268, 0x46);
    put(support + 0x98, body);
    put(task + 0x240, body);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), suspension.barc_suspension_input(component, 0x44) == 0x44);
    check(@src(), frame.fire_task_gate_count == 1 and validGate(&frame.fire_task_gates[0]));
    const recorded = frame.fire_task_gates[0];
    check(@src(), recorded.kind == p.SYNC_ACTOR_BARC_SUSPENSION and recorded.value == 0 and recorded.slot == 8);
    var malformed = recorded;
    malformed.value = 2;
    check(@src(), !validGate(&malformed));
    malformed = recorded;
    malformed.payload.barc_suspension.cache_index = 2;
    check(@src(), !validGate(&malformed));
    malformed = recorded;
    malformed.payload.storage[12] = 1;
    check(@src(), !validGate(&malformed));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    put(wrapper + 0x268, 0x47);
    for (0..7) |attempt| {
        token.release += 1;
        frame.fire_task_gates[0] = recorded;
        if (attempt == 1) frame.fire_task_gates[0].slot = 7;
        if (attempt == 2) frame.fire_task_gates[0].payload.barc_suspension.clock = 427;
        if (attempt == 3) frame.fire_task_gates[0].payload.barc_suspension.body_flags = 0x42;
        if (attempt == 4) frame.fire_task_gates[0].payload.barc_suspension.cache_index = 1;
        put(task + 0x240, if (attempt == 5) competitor else body);
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        const local: u32 = if (attempt == 6) 0x44 else 0x45;
        check(@src(), suspension.barc_suspension_input(component, local) == if (attempt == 0) 0x44 else local);
        check(@src(), win.load(u32, wrapper + 0x268) == 0x47 and win.load(u16, component + 0x936) == 2);
        check(@src(), (ci.cadence_finish() != 0) == (attempt == 0) and ci.cadence_abort_frame(&lease) != 0);
    }

    client = false;
    token.release += 1;
    win.store(u16, other + 0xdc0, 429);
    put(other + 0x14, name + 0x40);
    win.store([18]u8, name + 0x40, "stun_tank_chassis\x00".*);
    win.store([9]u8, name, "StunTank\x00".*);
    put(component + 0x60, 4);
    put(wrapper + 0x268, 0x46);
    put(task + 0x240, body);
    win.store(u8, support + 0x19, 0x42);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), suspension.barc_suspension_input(component, 0x44) == 0x44);
    check(@src(), frame.fire_task_gate_count == 1 and validGate(&frame.fire_task_gates[0]));
    const rx_recorded = frame.fire_task_gates[0];
    check(@src(), rx_recorded.character == 429 and rx_recorded.slot == 8 and rx_recorded.generation == 19);
    check(@src(), !@import("vehicle_body_source.zig").supportKey(support, &support_key));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    put(wrapper + 0x268, 0x47);
    for (0..6) |attempt| {
        token.release += 1;
        frame.fire_task_gates[0] = rx_recorded;
        win.store(u8, name, if (attempt == 1) 'X' else 'S');
        win.store(u8, name + 0x40, if (attempt == 2) 'x' else 's');
        put(component + 0x60, if (attempt == 3) 5 else 4);
        put(support + 0x28, if (attempt == 4) competitor else 0);
        if (attempt == 5) frame.fire_task_gates[0].character = 417;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        const expected_phase: u32 = if (attempt == 0) 0x44 else 0x45;
        const phase = suspension.barc_suspension_input(component, 0x45);
        if (phase != expected_phase) std.debug.print("RX suspension case {d}: phase {d}, expected {d}\n", .{ attempt, phase, expected_phase });
        check(@src(), phase == expected_phase);
        check(@src(), win.load(u32, wrapper + 0x268) == 0x47 and win.load(u16, component + 0x936) == 2);
        check(@src(), (ci.cadence_finish() != 0) == (attempt == 0) and ci.cadence_abort_frame(&lease) != 0);
    }
    put(0xfbdb3c, 0);
}

fn rylothFighterDeath() void {
    const decide = @import("ryloth_fighter_death.zig").ryloth_fighter_death_input;
    const validate = @import("fire_validation.zig").valid;
    mode = 57;
    setup();
    frame.level = 83;
    win.store(i16, actor + 0xdc0, 381);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    win.store(i8, actor + 0xdde, 7);
    check(@src(), decide(actor) == 0 and decide(other) == 1);
    win.store(i8, actor + 0xdde, -1);
    check(@src(), decide(actor) == 1 and frame.fire_task_gate_count == 2);
    check(@src(), validate(&frame.fire_task_gates[0]) and validate(&frame.fire_task_gates[1]));
    var malformed = frame.fire_task_gates[0];
    malformed.character = 382;
    check(@src(), !validate(&malformed));
    malformed = frame.fire_task_gates[0];
    malformed.payload.storage[0] = 1;
    check(@src(), !validate(&malformed));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), decide(actor) == 0);
    win.store(i8, actor + 0xdde, 7);
    check(@src(), decide(actor) == 1 and fault == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn geonosisVehicleDeath() void {
    const decide = @import("geonosis_vehicle_death.zig").geonosis_vehicle_death_input;
    mode = 60;
    setup();
    frame.level = 79;
    win.store(i16, actor + 0xdc0, 417);
    put(actor + 0x142c, model);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), decide(actor, model, 0x20) == 0x20);
    check(@src(), decide(actor, model, 0x40000020) == 0x40000020 and frame.fire_task_gate_count == 2);
    for (frame.fire_task_gates[0..2]) |*entry| check(@src(), @import("fire_validation.zig").valid(entry));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    put(model + 0x84, 0x40000020);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), decide(actor, model, 0x40000020) == 0x20 and win.load(u32, model + 0x84) == 0x20);
    check(@src(), decide(actor, model, 0x20) == 0x40000020 and fault == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}
fn hiddenEnemyForceEligibility() void {
    const eligible = @import("force_request.zig").eligible;
    const tubeContact = @import("tube_contact.zig").contact;
    const meleeContact = @import("melee_contact.zig").melee_contact;
    const meleeBounds = @import("melee_contact.zig").melee_bounds;
    const meleeImpact = @import("melee_contact.zig").melee_impact;
    mode = 58;
    setup();
    frame.level = 64;
    put(actor + 0x50, 0x203);
    win.store([3]f32, model + 0x50, .{ 1, 2, 3 });
    put(model + 0xd4, other);
    win.store(u8, model + 0x1d2, 0x20);
    put(model + 0x188, 0x9053f0);
    put(model + 0x11c, 0x839b);
    put(0xfa3d38, model);
    put(0xe5f480, 416);
    win.store(i16, other + 0xdc0, 196);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), !eligible(actor, .area, false) and eligible(actor, .area, true) and eligible(actor, .action, true) and !eligible(actor, .available, false));
    check(@src(), eligible(other, .area, true) and frame.fire_task_gate_count == 4);
    check(@src(), tubeContact(actor, 0, .search, true) and tubeContact(actor, model, .candidate, true));
    check(@src(), tubeContact(actor, model, .entry, true) and !tubeContact(actor, model, .hold, false));
    win.store(f32, model + 0xf4, 0.015625);
    check(@src(), meleeImpact(model, 0x1801) == 0x1801 and frame.fire_task_gate_count == 9);
    check(@src(), meleeBounds(actor, model) == 2 and meleeContact(actor, model, 0) == 0 and frame.fire_task_gate_count == 9);
    check(@src(), meleeContact(actor, model, 1) == 1 and frame.fire_task_gate_count == 10);
    check(@src(), std.meta.eql(frame.fire_task_gates[6].payload.tube_position, [3]f32{ 1, 2, 3 }));
    for (frame.fire_task_gates[0..10]) |*entry| check(@src(), @import("fire_validation.zig").valid(entry));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), !eligible(actor, .area, true) and eligible(actor, .area, false) and eligible(actor, .action, false) and !eligible(actor, .available, true));
    check(@src(), tubeContact(actor, 0, .search, false) and tubeContact(actor, model, .candidate, false));
    check(@src(), tubeContact(actor, model, .entry, false) and !tubeContact(actor, model, .hold, true));
    win.store(f32, model + 0xf4, 0.01);
    check(@src(), meleeImpact(model, 0x1805) == 0x1801 and win.load(f32, model + 0xf4) == 0.015625);
    check(@src(), meleeBounds(other, model) == 2);
    check(@src(), meleeBounds(actor, model) == 1 and meleeContact(actor, model, 0) == 1);
    check(@src(), meleeBounds(actor, model) == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn blueShadowContactDecisions() void {
    const apply = @import("cadence_gate.zig").apply;
    const firstTarget = @import("force_request.zig").force_request_first_target;
    mode = 58;
    setup();
    frame.level = 73;
    win.store(i16, actor + 0xdc0, 184);
    win.store(i16, other + 0xdc0, 333);
    put(actor + 0x50, 0x203);
    put(model + 0x238, actor);
    win.store(u8, model + 0x25d, 1);
    put(0xe901dc, provider);
    put(manager, 0xc4c8ec);
    put(gizmo, 0xad953c);
    put(gizmo + 0x88, entity);
    put(entity + 0x50, gizmo);
    @memcpy(@as([*]u8, @ptrFromInt(gizmo + 0x30))[0..17], "iVindi_Can_03_Bl1");
    put(gizmo + 0x150, task);
    put(task, 0xc450fc);
    put(task + 4, entity);
    put(wrapper, 0xc450fc);
    put(wrapper + 4, entity);
    const token: Token = .{
        .owner = actor,
        .owner_nonce = 1,
        .cohort_nonce = 0,
        .thread = win.GetCurrentThreadId(),
        .release = frame.epoch,
        .epoch = frame.epoch,
        .sequence = frame.sequence,
        .frame = @intFromPtr(frame),
    };
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var projectile = [2]u32{ 1411, 209 };
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    win.store(u8, model + 0x25c, 1);
    put(model + 0x24, other);
    win.store(u8, model + 0x28, 2);
    check(@src(), saber_target_queue(model) == 1);
    win.store(u8, model + 0x25c, 0);
    check(@src(), saber_target_queue(model) == 1);
    win.store(u8, model + 0x25d, 0);
    check(@src(), saber_target_queue(model) == 0);
    check(@src(), apply(actor, p.SYNC_ACTOR_PROJECTILE_BRANCH, 0, 0, 0, @ptrCast(&projectile), &debug) == 0);
    check(@src(), firstTarget(actor, 0) == 0);
    check(@src(), firstTarget(actor, support + 0x50) == support + 0x50);
    check(@src(), firstTarget(actor, task) == task);
    check(@src(), frame.fire_task_gate_count == 7);
    for (frame.fire_task_gates[0..7]) |*entry| check(@src(), @import("fire_validation.zig").valid(entry));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    var guest_token = token;
    guest_token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&guest_token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    put(model + 0x24, 0);
    win.store(u8, model + 0x28, 0);
    win.store(u8, model + 0x25d, 1);
    check(@src(), saber_target_queue(model) == 1);
    check(@src(), win.load(u8, model + 0x25c) == 1 and win.load(usize, model + 0x24) == other and win.load(u8, model + 0x28) == 2);
    check(@src(), saber_target_queue(model) == 1);
    check(@src(), win.load(u8, model + 0x25c) == 0);
    check(@src(), saber_target_queue(model) == 0 and win.load(u8, model + 0x25d) == 1);
    check(@src(), apply(actor, p.SYNC_ACTOR_PROJECTILE_BRANCH, 0, 0, 1, @ptrCast(&projectile), &debug) == 0);
    check(@src(), firstTarget(actor, support + 0x250) == 0);
    check(@src(), firstTarget(actor, 0) == support + 0x250);
    put(gizmo + 0x150, wrapper);
    check(@src(), firstTarget(actor, 0) == wrapper);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

export fn combat_damage_native_caller() u32 {
    return if (contact_shot != 0) 0x81f27f else 0;
}

export fn combat_damage_source_id() u32 {
    return contact_shot;
}

fn blueShadowProjectileAction() void {
    const hit_action = @import("projectile_actor_branch.zig").projectile_hit_action;
    mode = 58;
    setup();
    frame.level = 73;
    frame.sequence = 2102;
    put(0xfb4b6c, 2104);
    win.store(u16, actor + 0xdc0, 184);
    contact_shot = 125;
    defer contact_shot = 0;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), hit_action(actor, 0x800) == 0 and frame.fire_task_gate_count == 1);
    check(@src(), @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), hit_action(actor, 0x904) == 0 and s.fire_task_cursor == 1);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn blueShadowPlayerProjectileContact(level: i32, character: u16, id: u32) void {
    const hit = @import("projectile_actor_branch.zig").projectile_player_hit;
    mode = 58;
    setup();
    frame.level = level;
    win.store(u16, actor + 0xdc0, character);
    contact_shot = id;
    defer contact_shot = 0;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), hit(actor, body) == 1 and frame.fire_task_gate_count == 1 and @import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    contact_shot -= 1;
    check(@src(), hit(actor, body) == 0 and s.fire_task_cursor == 0);
    contact_shot += 1;
    check(@src(), hit(actor, body) == 1 and hit(actor, body) == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}
fn forceReleaseCountdown(level: i32) void {
    const expired = @import("force_request.zig").force_release_expired;
    const eligible = @import("force_request.zig").eligible;
    mode = 58;
    setup();
    frame.level = level;
    win.store(i16, actor + 0xdc0, if (level == 7) 333 else 321);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), expired(actor, 0x100) == 0 and expired(actor, 0) == 1);
    check(@src(), frame.fire_task_gate_count == 2);
    if (level == 71) {
        win.store(u16, other + 0xdc0, 181);
        put(other + 0x50, 0x203);
        win.store(f32, other + 0x28, 5.8);
        check(@src(), eligible(other, .area, true) and eligible(other, .action, true) and
            eligible(other, .available, true) and !eligible(other, .first_target, false));
        check(@src(), frame.fire_task_gate_count == 6);
    }
    for (frame.fire_task_gates[0..frame.fire_task_gate_count]) |*entry| check(@src(), @import("fire_validation.zig").valid(entry));
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), expired(actor, 0) == 0 and expired(actor, 0x100) == 1);
    if (level == 71) {
        check(@src(), eligible(other, .area, false) and eligible(other, .action, false) and
            eligible(other, .available, false) and !eligible(other, .first_target, true));
    }
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    if (level == 71) {
        const apply = gate.apply;
        var motion = std.mem.zeroes(p.SyncCharacterMotionState);
        motion.clock = 45139;
        put(0xfb4b6c, motion.clock);
        for ([_]u16{ 321, 333 }) |character| {
            win.store(u16, actor + 0xdc0, character);
            win.store(u16, other + 0xdc0, character);
            client = false;
            token.release += 1;
            check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
            _ = apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
            check(@src(), expired(actor, 0x100) == 0);
            _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
            check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

            client = true;
            token.release += 1;
            check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
            _ = apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
            _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
            check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
        }
    }
    if (level != 74 and level != 73 and level != 71) return;
    if (level == 73) win.store(u16, other + 0xdc0, 333);
    if (level == 71) {
        win.store(u16, actor + 0xdc0, 333);
        win.store(u16, other + 0xdc0, 333);
    }

    const apply = gate.apply;
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.clock = 42;
    put(0xfb4b6c, 42);
    for ([_]bool{ false, true }) |with_support| {
        client = false;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        _ = apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        if (with_support) _ = apply(actor, p.SYNC_FIRE_ATTACK_SUPPORT, 0, 0, 0, null, &debug);
        _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        _ = apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        if (with_support) _ = apply(actor, p.SYNC_FIRE_ATTACK_SUPPORT, 0, 0, 0, null, &debug);
        check(@src(), expired(actor, 0) == 0 and s.fire_task_cursor == (if (with_support) @as(u32, 2) else 1));
        _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }
}

fn geonosisCompanionMotionOrder() void {
    mode = 58;
    setup();
    frame.level = 79;
    win.store(u16, other + 0xdc0, 259);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.velocity[0] = 2;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, null, &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), frame.fire_task_gate_count == 2 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    motion.velocity[0] = 3;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), motion.velocity[0] == 2 and s.fire_task_cursor == 0);
    check(@src(), gate.apply(actor, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 0, null, &debug) == 1);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    client = false;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_RTS_COMPETITOR, 0, 0, 1, null, &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_RTS_COMPETITOR, 0, 0, 2, null, &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_RTS_COMPETITOR, 0, 0, 0, null, &debug) == 2 and s.fire_task_cursor == 0);
    check(@src(), gate.apply(actor, p.SYNC_ACTOR_RTS_COMPETITOR, 0, 0, 0, null, &debug) == 1);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn blueShadowCompanionMotionOrder(level: i32) void {
    const lab = level == 73;
    const corridor = level == 74;
    mode = 58;
    setup();
    frame.level = level;
    win.store(u16, other + 0xdc0, if (lab) 138 else if (corridor) 184 else 156);
    if (lab) {
        win.store(u16, actor + 0xdc0, 184);
        win.store(u16, node + 0xdc0, 188);
        put(0xfb4944, other);
    }
    if (corridor) {
        win.store(u16, actor + 0xdc0, 181);
        put(0xfb4944, actor);
    }
    defer put(0xfb4944, 0);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var query = std.mem.zeroes(p.SyncForceQueryState);
    var geometry = std.mem.zeroes(p.SyncForceGeometryState);
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    query.caster_slot = 7;
    query.caster_generation = 1;
    query.clock = 43;
    geometry.caster_slot = query.caster_slot;
    geometry.caster_generation = 1;
    geometry.clock = query.clock;
    motion.clock = query.clock;
    var second_query = query;
    second_query.mode = 2;
    var admission = std.mem.zeroes(p.SyncFireTaskState);
    admission.repeat = query.clock;
    var spellit_query = std.mem.zeroes(p.SyncSpellItQueryState);
    spellit_query.clock = query.clock;
    motion.velocity[0] = 2;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(other, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, @ptrCast(&query), &debug);
    if (lab) {
        _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 0, @ptrCast(&second_query), &debug);
    } else {
        _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_GEOMETRY, 0, 0, 0, @ptrCast(&geometry), &debug);
    }
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    if (lab or corridor) {
        _ = gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, @intFromBool(lab), @ptrCast(&admission), &debug);
        _ = gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
    }
    if (lab) {
        _ = gate.apply(other, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 1, @ptrCast(&spellit_query), &debug);
        _ = gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 0, @ptrCast(&admission), &debug);
        _ = gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 1, @ptrCast(&admission), &debug);
    }
    const gate_count: u32 = if (lab) 8 else if (corridor) 5 else 3;
    check(@src(), frame.fire_task_gate_count == gate_count and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    motion.velocity[0] = 3;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), motion.velocity[0] == 2 and s.fire_task_cursor == 0);
    if (lab or corridor) {
        check(@src(), gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 0, @ptrCast(&admission), &debug) == @intFromBool(lab));
        check(@src(), gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 1, @ptrCast(&admission), &debug) == 0);
    }
    if (lab) {
        check(@src(), gate.apply(other, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(&spellit_query), &debug) == 1 and s.fire_task_cursor == 0);
        check(@src(), gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 1, @ptrCast(&admission), &debug) == 0);
        check(@src(), gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug) == 1 and s.fire_task_cursor == 0);
    }
    check(@src(), gate.apply(other, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 0, @ptrCast(&query), &debug) == 1);
    if (lab) {
        _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 0, @ptrCast(&second_query), &debug);
    } else {
        _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_GEOMETRY, 0, 0, 0, @ptrCast(&geometry), &debug);
    }
    check(@src(), s.fire_task_cursor == gate_count and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    if (lab) {
        frame.fire_task_gates[1].payload.force.clock += 1;
    } else {
        frame.fire_task_gates[1].payload.force_geometry.caster_generation = 2;
    }
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);
    if (lab) {
        fault = 0;
        token.release += 1;
        frame.fire_task_gates[1].payload.force.clock = query.clock;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        _ = gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
        check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);

        for (0..3) |path| {
            const target_found = path == 0;
            const declined = path == 2;
            client = false;
            fault = 0;
            query.mode = 1;
            query.caster_generation = 19;
            var fallback = query;
            fallback.mode = 2;
            token.release += 1;
            check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
            labForceAdmission(actor, declined, &admission, &spellit_query, &debug);
            labForceChecks(actor, declined, &debug);
            if (!declined) {
                _ = gate.apply(node, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, @ptrCast(&query), &debug);
                _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_ELIGIBILITY, 4, 0, @intFromBool(target_found), null, &debug);
            }
            if (!target_found) {
                if (!declined) _ = gate.apply(node, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, @ptrCast(&fallback), &debug);
                _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
                _ = gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 0, @ptrCast(&admission), &debug);
            }
            _ = gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 0, @ptrCast(&admission), &debug);
            _ = gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
            check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

            client = true;
            token.release += 1;
            check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
            labForceAdmission(actor, declined, &admission, &spellit_query, &debug);
            const cursor: u32 = if (declined) 4 else 1;
            const request = @import("force_request.zig").force_request_begin;
            put(actor + 0x50, 0x200);
            put(0xfb4b6c, query.clock + 1);
            check(@src(), request(actor) == 0 and s.fire_task_cursor == cursor);
            put(0xfb4b6c, query.clock);
            check(@src(), request(actor) == 1 and s.fire_task_cursor == cursor);
            if (!target_found) {
                _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
                check(@src(), gate.apply(other, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 1, @ptrCast(&admission), &debug) == 0);
            }
            check(@src(), gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 1, @ptrCast(&admission), &debug) == 0);
            check(@src(), gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 1, @ptrCast(&admission), &debug) == 0);
            check(@src(), s.fire_task_cursor == cursor and fault == 0);
            labForceChecks(actor, declined, &debug);
            if (!declined) {
                _ = gate.apply(node, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, @ptrCast(&query), &debug);
                _ = gate.apply(actor, p.SYNC_ACTOR_FORCE_ELIGIBILITY, 4, 0, @intFromBool(target_found), null, &debug);
                if (!target_found) _ = gate.apply(node, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 1, @ptrCast(&fallback), &debug);
            }
            check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
        }

        client = false;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        labForceAdmission(actor, true, &admission, &spellit_query, &debug);
        _ = gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 0, @ptrCast(&admission), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        labForceAdmission(actor, true, &admission, &spellit_query, &debug);
        const request = @import("force_request.zig").force_request_begin;
        check(@src(), request(actor) == -1 and s.fire_task_cursor == 4);
        check(@src(), gate.apply(node, p.SYNC_ACTOR_SPELLIT_ADMISSION, 4, 0, 1, @ptrCast(&admission), &debug) == 0);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }
}

fn labForceAdmission(caster: usize, declined: bool, admission: *p.SyncFireTaskState, query: *p.SyncSpellItQueryState, debug: *[4]u32) void {
    if (declined) {
        for ([_]u16{ 4, 5, 2, 3 }, [_]c_int{ 1, 1, 0, 0 }) |stage, value| {
            _ = gate.apply(caster, p.SYNC_ACTOR_SPELLIT_ADMISSION, stage, 0, value, @ptrCast(admission), debug);
        }
    } else _ = gate.apply(caster, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(query), debug);
}

fn labForceChecks(caster: usize, declined: bool, debug: *[4]u32) void {
    _ = gate.apply(caster, p.SYNC_ACTOR_FORCE_ELIGIBILITY, 0, 0, 1, null, debug);
    _ = gate.apply(caster, p.SYNC_ACTOR_FORCE_ELIGIBILITY, 1, 0, @intFromBool(!declined), null, debug);
    if (!declined) _ = gate.apply(caster, p.SYNC_ACTOR_FORCE_ELIGIBILITY, 2, 0, 1, null, debug);
}

fn blueShadowDroidMotionOrder(character: u16, extra_motion: bool, scripted_target: bool) void {
    mode = 58;
    setup();
    frame.level = 70;
    win.store(u16, actor + 0xdc0, character);
    win.store(u16, other + 0xdc0, 321);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.velocity[0] = 2;
    const lead = if (scripted_target) p.SYNC_ACTOR_PRIMARY_PERCEPTION else p.SYNC_ACTOR_AIM_BASE;
    const lead_flags = if (scripted_target) p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET else 0;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(other, @intCast(lead), lead_flags, 0, 0, null, &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 1, null, &debug);
    if (extra_motion) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    const count: u32 = if (extra_motion) 4 else 3;
    check(@src(), frame.fire_task_gate_count == count and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    motion.velocity[0] = 3;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), motion.velocity[0] == 2 and s.fire_task_cursor == 0);
    _ = gate.apply(other, @intCast(lead), lead_flags, 0, 0, null, &debug);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, null, &debug) == 1);
    if (extra_motion) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), s.fire_task_cursor == count);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    if (scripted_target) {
        frame.fire_task_gates[0].payload.perception.clock = 1;
    } else if (character == 337) {
        frame.fire_task_gates[0].payload.aim_base.clock = 1;
    } else {
        frame.fire_task_gates[1] = frame.fire_task_gates[count - 1];
        frame.fire_task_gates[1].kind = p.SYNC_ACTOR_AIM_TASK;
    }
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn blueShadowPadmeSupport() void {
    mode = 58;
    setup();
    frame.level = 74;
    win.store(u16, actor + 0xdc0, 188);
    put(0xfb4b6c, 42);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var admission = std.mem.zeroes(p.SyncFireTaskState);
    admission.repeat = 42;
    win.store(u16, other + 0xdc0, 199);
    win.store(f32, other + 0x24, -7.311);
    var query = std.mem.zeroes(p.SyncSpellItQueryState);
    query.clock = 42;
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.clock = query.clock;
    for ([_]bool{ false, true }) |followed_by_jar_jar| {
        client = false;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        _ = gate.apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, 3, 0, 0, @ptrCast(&admission), &debug);
        if (followed_by_jar_jar) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        _ = gate.apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, 3, 0, 0, @ptrCast(&admission), &debug);
        var attack_support: c_int = 0;
        check(@src(), cb.cadence_apply_attack_support(actor, &attack_support) == 1 and attack_support == 0 and s.fire_task_cursor == 1);
        if (followed_by_jar_jar) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }
    for (0..3) |variant| {
        const trailing = variant == 1;
        const prior_kind: u32 = if (variant == 2) p.SYNC_ACTOR_SPELLIT_ADMISSION else p.SYNC_ACTOR_SPELLIT_QUERY;
        const stage: u16 = if (variant == 2) 3 else 0;
        const state: [*]u8 = if (variant == 2) @ptrCast(&admission) else @ptrCast(&query);
        client = false;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        _ = gate.apply(actor, prior_kind, stage, 0, 0, state, &debug);
        _ = gate.apply(actor, p.SYNC_FIRE_ATTACK_SUPPORT, 0, 0, 3, null, &debug);
        if (!trailing) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        _ = gate.apply(actor, prior_kind, stage, 0, 0, state, &debug);
        if (!trailing) _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and s.fire_task_cursor == frame.fire_task_gate_count and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }

    win.store(f32, actor + 0x24, -6.6884594);
    const admission_call = @import("spellit_admission.zig").cadence_spellit_admission;
    client = false;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), admission_call(actor, 0, 4, 1) == 0 and admission_call(actor, 0, 5, 1) == 0 and s.fire_task_cursor == 1);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    win.store(f32, actor + 0x24, -22.89929);
    win.store(f32, actor + 0x2c, 26.65648);
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    var attack_support: c_int = 3;
    check(@src(), cb.cadence_apply_attack_support(actor, &attack_support) == 1 and s.fire_task_cursor == 1);
    _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    win.store(f32, actor + 0x24, -6.6884594);
    win.store(f32, actor + 0x2c, 0);

    put(0xfb4940, actor);
    defer put(0xfb4940, 0);
    query.manager_class = 0x84c2ac;
    query.caller_site = 0x457f0a;
    for ([_]bool{ false, true }) |empty_query| {
        const stages: []const u16 = if (empty_query) &.{ 4, 5, 2, 0, 1 } else &.{ 4, 5, 2, 3 };
        const results: []const c_int = if (empty_query) &.{ 0, 1, 1, 0, 1 } else &.{ 0, 1, 0, 0 };
        client = false;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        for (stages, results) |stage, result| {
            _ = gate.apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, stage, if (stage < 2) 0x24 else 0, result, @ptrCast(&admission), &debug);
        }
        if (empty_query) _ = gate.apply(actor, p.SYNC_ACTOR_SPELLIT_QUERY, 0, 0, 0, @ptrCast(&query), &debug);
        _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        _ = gate.apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
        check(@src(), s.fire_task_cursor == frame.fire_task_gate_count and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }
}

fn blueShadowVindiSupport(character: u16) void {
    mode = 58;
    setup();
    frame.level = 73;
    win.store(u16, actor + 0xdc0, 201);
    win.store(u16, other + 0xdc0, character);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.clock = 42;
    var admission = std.mem.zeroes(p.SyncFireTaskState);
    admission.repeat = motion.clock;
    const apply = gate.apply;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
    _ = apply(actor, p.SYNC_FIRE_ATTACK_SUPPORT, 0, 0, 3, null, &debug);
    _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
    _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), s.fire_task_cursor == 3 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = apply(actor, p.SYNC_ACTOR_SPELLIT_ADMISSION, 5, 0, 0, @ptrCast(&admission), &debug);
    motion.clock += 1;
    _ = apply(other, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn blueShadowNativeOpponent(assigned: bool) void {
    const select: *const fn (usize, usize) callconv(.c) usize = if (assigned) &cp.cadence_script_assigned_target else &cp.cadence_script_attack_target;
    mode = 58;
    setup();
    frame.level = 70;
    win.store(u16, actor + 0xdc0, 333);
    win.store(u16, other + 0xdc0, 191);
    win.store(u32, 0xfb4b6c, 102);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), select(actor, other) == other and select(actor, 0) == 0);
    check(@src(), frame.fire_task_gate_count == 2 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    const selected = &frame.fire_task_gates[0];
    const flags = if (assigned) p.SYNC_PERCEPTION_SCRIPT_ASSIGNED_TARGET else p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET;
    check(@src(), selected.kind == p.SYNC_ACTOR_PRIMARY_PERCEPTION and selected.flags == flags and selected.payload.perception.clock == 102);
    check(@src(), selected.payload.perception.target_character == 191 and selected.payload.perception.target_generation == 19);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), cp.swamp_script_fallback(actor) == @intFromBool(!assigned));
    check(@src(), cp.swamp_script_fallback(other) == 0 and s.fire_task_cursor == 0);
    check(@src(), select(actor, 0) == other and select(actor, other) == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    win.store(u32, 0xfb4b6c, 103);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), cp.swamp_script_fallback(actor) == 0);
    check(@src(), select(actor, 0) == 0 and fault == 14);
    check(@src(), ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);

    client = false;
    token.release += 1;
    put(0xfb4940, other);
    put(0xfb4944, model);
    win.store(u16, model + 0xdc0, 156);
    win.store(u8, other + 0xdde, 0);
    win.store(u8, model + 0xdde, 0);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    const before_revive: u32 = @intFromBool(assigned);
    check(@src(), select(actor, other) == other and frame.fire_task_gate_count == before_revive);
    win.store(u8, model + 0xdde, 1);
    check(@src(), select(actor, model) == model and frame.fire_task_gate_count == before_revive + 1);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn blueShadowReleasedAim() void {
    mode = 59;
    setup();
    frame.level = 70;
    win.store(u16, other + 0xdc0, 321);
    put(other + 8, model);
    put(other + 0x50, 0x18003);
    put(task + 0x10, 0);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), frame.fire_task_gate_count == 1 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    put(task + 0x10, actor);
    put(other + 0xbdc, actor);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), win.load(usize, task + 0x10) == 0 and win.load(usize, other + 0xbdc) == 0);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    put(task + 0x10, actor);
    put(other + 0xbdc, actor);
    put(other + 0x50, 0x8003);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), win.load(usize, task + 0x10) == actor and win.load(usize, other + 0xbdc) == actor);
    check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn blueShadowRecordedAim(level: i32, retained_lift_target: bool, corridor_droid: bool) void {
    const stale = level != 70;
    mode = if (stale) 60 else 59;
    setup();
    frame.level = level;
    win.store(u16, actor + 0xdc0, if (level == 73) 138 else if (stale) 184 else 191);
    win.store(f32, actor + 0x24, 39);
    win.store(f32, other + 0x24, if (corridor_droid) 3.1796846 else 41);
    win.store(u8, actor + 0xdde, 4);
    win.store(u16, other + 0xdc0, if (level == 73 or corridor_droid) 333 else 321);
    win.store(u16, component + 0xdc0, if (corridor_droid) 199 else 181);
    if (level == 73) put(actor + 0x50, 0x1001);
    put(other + 8, model);
    put(0xfb4940, actor);
    put(0xfb4944, if (level == 73 or corridor_droid) component else 0);
    put(task + 0x10, actor);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    if (corridor_droid) win.store(u8, model + 0x42, 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), frame.fire_task_gate_count == 1 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    const stale_target = if (stale) runtime else 0;
    put(task + 0x10, stale_target);
    put(other + 0xbdc, if (level == 73 or retained_lift_target) actor else stale_target);
    if (retained_lift_target) {
        mode = 62;
        put(actor + 0x50, 0x8005);
    }
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), win.load(usize, task + 0x10) == actor);
    if (stale) check(@src(), win.load(usize, other + 0xbdc) == actor);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    if (retained_lift_target) {
        token.release += 1;
        put(task + 0x10, actor);
        put(other + 0xbdc, stale_target);
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        check(@src(), ct.cadence_prepare_aim_task(other, task) == 1 and s.fire_task_cursor == 1);
        check(@src(), win.load(usize, task + 0x10) == actor and win.load(usize, other + 0xbdc) == stale_target);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }

    if (level == 73) {
        token.release += 1;
        win.store(u16, runtime + 0xdc0, 138);
        put(runtime + 0x50, 0x1001);
        put(task + 0x10, runtime);
        put(other + 0xbdc, 0);
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        check(@src(), ct.cadence_prepare_aim_task(other, task) == 1 and s.fire_task_cursor == 1);
        check(@src(), win.load(usize, task + 0x10) == runtime and win.load(usize, other + 0xbdc) == 0);
        check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
    }

    token.release += 1;
    put(task + 0x10, stale_target);
    if (level == 73) {
        frame.fire_task_gates[0].payload.aim.target_character = 188;
    } else {
        frame.fire_task_gates[0].payload.aim.target_generation += 1;
    }
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = ct.cadence_prepare_aim_task(other, task);
    check(@src(), win.load(usize, task + 0x10) == stale_target and fault == 14);
    check(@src(), ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);

    if (level != 73) return;
    fault = 0;
    frame.sequence = 1;
    token.sequence = 1;
    token.release += 1;
    win.store(u16, other + 0xdc0, 321);
    win.store(u16, runtime + 0xdc0, 138);
    put(runtime + 0x50, 0x1001);
    put(other + 0xbdc, actor);
    frame.fire_task_gates[0].character = 321;
    frame.fire_task_gates[0].payload.aim.target_character = 138;
    frame.fire_task_gates[1] = frame.fire_task_gates[0];
    frame.fire_task_gates[1].kind = p.SYNC_ACTOR_FORCE_VISIBILITY;
    var query = std.mem.zeroes(p.SyncForceQueryState);
    query.clock = frame.fire_task_gates[0].payload.aim.clock;
    query.mode = 1;
    frame.fire_task_gates[1].payload.force = query;
    frame.fire_task_gate_count = 2;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), ct.cadence_prepare_aim_task(other, task) == 1 and s.fire_task_cursor == 1);
    put(task + 0x10, runtime);
    put(other + 0xbdc, runtime);
    check(@src(), ct.cadence_prepare_aim_task(other, task) == 0 and s.fire_task_cursor == 1);
    var debug: [4]u32 = @splat(0);
    _ = gate.apply(other, p.SYNC_ACTOR_FORCE_VISIBILITY, 0, 0, 0, @ptrCast(&query), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn blueShadowGuestOnlyAim(clone_dead: bool, lab_sequence: u32, droid: u16, both_alive: bool) void {
    mode = 58;
    setup();
    const lab_resume = lab_sequence != 0;
    frame.level = if (lab_resume) 73 else 70;
    if (lab_resume) frame.sequence = lab_sequence;
    win.store(u16, actor + 0xdc0, droid);
    win.store(u16, other + 0xdc0, 191);
    win.store(u16, component + 0xdc0, if (lab_resume) 181 else 156);
    win.store(u8, component + 0xdde, if (clone_dead) 0 else 4);
    if (both_alive) win.store(u8, other + 0xdde, 4);
    put(0xfb4940, other);
    put(0xfb4944, component);
    const last_target = if (clone_dead) 0 else component;
    const target = if (clone_dead) other else component;
    put(actor + 0xbdc, last_target);
    put(task + 0x10, target);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var delta: f32 = 0.015;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    if (clone_dead) _ = gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, null, &debug);
    var probe = std.mem.zeroes(p.SyncPrimaryPerceptionState);
    probe.clock = win.load(u32, 0xfb4b6c);
    if (both_alive) {
        win.store(u16, other + 0xdc0, 321);
        _ = gate.apply(other, p.SYNC_ACTOR_PRIMARY_PERCEPTION, p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET, 0, 0, @ptrCast(&probe), &debug);
        win.store(u16, other + 0xdc0, 191);
    }
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.clock = win.load(u32, 0xfb4b6c);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), ct.cadence_prepare_aim_base(task, wrapper, &delta) == 0 and s.fire_task_cursor == 0);
    check(@src(), win.load(usize, task + 0x10) == target and win.load(usize, actor + 0xbdc) == last_target);
    if (clone_dead) _ = gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, null, &debug);
    if (both_alive) {
        win.store(u16, other + 0xdc0, 321);
        _ = gate.apply(other, p.SYNC_ACTOR_PRIMARY_PERCEPTION, p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET, 0, 0, @ptrCast(&probe), &debug);
        win.store(u16, other + 0xdc0, 191);
    }
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, null, &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    if (lab_resume) {
        frame.fire_task_gates[@intFromBool(clone_dead)].payload.character_motion.clock +%= 1;
    } else if (both_alive) {
        frame.fire_task_gates[0].payload.perception.clock +%= 1;
    } else {
        win.store(u8, other + 0xdde, 4);
    }
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), ct.cadence_prepare_aim_base(task, wrapper, &delta) == 1 and fault == 14);
    check(@src(), ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);

    client = false;
    fault = 0;
    token.release += 1;
    win.store(u8, other + 0xdde, 0);
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), ct.cadence_prepare_aim_base(task, wrapper, &delta) == 1 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), ct.cadence_prepare_aim_base(task, wrapper, &delta) == 1 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn droidAimOrder(level: i32) void {
    mode = 58;
    setup();
    frame.level = level;
    win.store(i16, actor + 0xdc0, 333);
    win.store(i16, other + 0xdc0, 321);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    var debug: [4]u32 = @splat(0);
    var corridor_base = std.mem.zeroes(p.SyncAimBaseState);
    var corridor_task = std.mem.zeroes(p.SyncAimTaskState);
    corridor_base.clock = 1837;
    corridor_task.clock = 1837;
    const base_state: ?[*]u8 = if (level == 71) @ptrCast(&corridor_base) else null;
    const task_state: ?[*]u8 = if (level == 71) @ptrCast(&corridor_task) else null;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_AIM_BASE, 0, 0, 3, base_state, &debug);
    _ = gate.apply(actor, p.SYNC_ACTOR_AIM_TASK, 0, 0, 4, task_state, &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 5, base_state, &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 6, task_state, &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, base_state, &debug) == 5);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, task_state, &debug) == 6 and s.fire_task_cursor == 0);
    check(@src(), gate.apply(actor, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, base_state, &debug) == 3);
    check(@src(), gate.apply(actor, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, task_state, &debug) == 4 and s.fire_task_cursor == 4);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, task_state, &debug) == 0 and fault == 14);
    check(@src(), ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);

    if (level != 70) return;
    fault = 0;
    client = false;
    token.release += 1;
    var probe = std.mem.zeroes(p.SyncPrimaryPerceptionState);
    probe.clock = 3587;
    var base = std.mem.zeroes(p.SyncAimBaseState);
    base.clock = probe.clock;
    var aim = std.mem.zeroes(p.SyncAimTaskState);
    aim.clock = probe.clock;
    const stage = p.SYNC_PERCEPTION_SCRIPT_ATTACK_TARGET;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_PRIMARY_PERCEPTION, stage, 0, 0, @ptrCast(&probe), &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, @ptrCast(&base), &debug);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 1, @ptrCast(&aim), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(other, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, @ptrCast(&base), &debug);
    check(@src(), gate.apply(other, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, @ptrCast(&aim), &debug) == 1 and s.fire_task_cursor == 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_PRIMARY_PERCEPTION, stage, 0, 0, @ptrCast(&probe), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);
}

fn hiddenLabAimBeforeMotion(target_is_anakin: bool) void {
    mode = 58;
    setup();
    frame.level = 73;
    win.store(u16, actor + 0xdc0, 321);
    win.store(u16, node + 0xdc0, 321);
    win.store(u16, other + 0xdc0, if (target_is_anakin) 184 else 181);
    win.store(u16, component + 0xdc0, 181);
    put(0xfb4940, if (target_is_anakin) other else 0);
    put(0xfb4944, if (target_is_anakin) component else other);
    defer put(0xfb4940, 0);
    defer put(0xfb4944, 0);
    var motion = std.mem.zeroes(p.SyncCharacterMotionState);
    motion.clock = 1083;
    var base = std.mem.zeroes(p.SyncAimBaseState);
    base.clock = motion.clock;
    base.task_class = 8710492;
    var aim = std.mem.zeroes(p.SyncAimTaskState);
    aim.clock = motion.clock;
    aim.task_class = base.task_class;
    aim.target_slot = 8;
    aim.target_generation = 19;
    var debug: [4]u32 = @splat(0);
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    _ = gate.apply(node, p.SYNC_ACTOR_AIM_BASE, 0, 0, 0, @ptrCast(&base), &debug);
    _ = gate.apply(node, p.SYNC_ACTOR_AIM_TASK, 0, 0, 0, @ptrCast(&aim), &debug);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    _ = gate.apply(node, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    _ = gate.apply(node, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0 and fault == 0);

    token.release += 1;
    frame.fire_task_gates[1].value = 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    _ = gate.apply(actor, p.SYNC_ACTOR_CHARACTER_MOTION, 0, 0, 0, @ptrCast(&motion), &debug);
    check(@src(), fault == 14 and ci.cadence_finish() == 0 and ci.cadence_abort_frame(&lease) != 0);
}

fn geonosisGuestForceScan() void {
    mode = 59;
    setup();
    frame.level = 79;
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    var lease: s.Lease = undefined;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
    check(@src(), cf.cadence_force_target_visibility(actor, other, 1, 1) == 1);
    check(@src(), frame.fire_task_gate_count == 1 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
    check(@src(), cf.cadence_force_target_visibility(other, actor, 1, 1) == 0 and s.fire_task_cursor == 0 and fault == 0);
    check(@src(), cf.cadence_force_target_visibility(actor, other, 1, 0) == 1 and s.fire_task_cursor == 1);
    check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 3076 and @intFromPtr(&image) < 0x420000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0xe50000, 0xe60000, 0xe90000, 0xea0000, 0xf90000, 0xfa0000, 0xfb0000 }) |address| protect(address, 0x10000, 4);
    for (0..24) |i| {
        const address = 0x20000000 + i * 0x10000;
        check(@src(), win.VirtualAlloc(address, if (address == world) 0x3000 else 0x2000, 0x3000, 4) == address);
    }
    defer {
        for (0..24) |i| check(@src(), win.VirtualFree(0x20000000 + i * 0x10000, 0, 0x8000) != 0);
    }
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    defer check(@src(), win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
    const expected = [_]u32{ 2576988165, 3314984051, 391599416, 3879187881, 1362419746, 3153845502, 1567923159, 3873342046, 1812139648, 4287552700, 2616713246, 2685929212, 1612092689, 3331385190, 2166857060, 3464861946, 361354819, 417414197, 1551753055, 1374308542, 70559514, 3195711548, 3724144250, 440383435, 2309546767, 684512167, 1866050002, 235897247, 2616792122, 3760344942, 1388483274, 3522334199, 1349671851, 1898625247, 3401321261, 2674681717, 310091555, 756920242, 3683320467, 3275832274 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        const out = run();
        var legacy = out;
        if (mode == 26) {
            check(@src(), out.gates[0].payload.character_motion.support_material_flags == p.SYNC_SUPPORT_ABSENT);
            legacy.gates[0].payload.character_motion.support_material_flags = 0;
        }
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&legacy)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("cadence runtime mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 0) check(@src(), out.finish != 0 and out.period == 2);
        if (mode == 3) check(@src(), out.finish != 0 and out.gate_count == 1 and out.diagnostics.clonewars_fire_task_gate_debug[1] != 0);
        if (mode == 8) check(@src(), out.finish != 0 and out.result == 1);
        if (mode == 26) check(@src(), out.finish != 0 and out.velocity[0] == 1);
        if (mode == 22) check(@src(), out.finish != 0);
    }
    for (40..49) |i| {
        mode = @intCast(i);
        const out = run();
        check(@src(), out.err == 1234);
        if (i == 40 or i == 45) {
            check(@src(), out.finish != 0 and out.fault == 0 and out.velocity[0] == 1);
            check(@src(), std.mem.readInt(u32, out.body_state[0xec..0xf0], .little) == support + @as(u32, if (i == 45) 0x200 else 0));
            check(@src(), std.mem.readInt(u32, out.body_state[0x110..0x114], .little) == @as(u32, @bitCast(@as(f32, 1))));
            check(@src(), out.diagnostics.clonewars_character_support_debug[6] == 1);
        } else {
            check(@src(), out.finish == 0 and out.fault != 0 and out.velocity[0] == 7);
            check(@src(), std.mem.readInt(u32, out.body_state[0xec..0xf0], .little) == @as(u32, if (i >= 45) support else 0));
            check(@src(), std.mem.readInt(u32, out.body_state[0x110..0x114], .little) == @as(u32, @bitCast(@as(f32, 2))));
        }
    }
    for (49..56) |i| {
        mode = @intCast(i);
        const out = run();
        check(@src(), out.err == 1234);
        const actual_support = std.mem.readInt(u32, out.body_state[0xec..0xf0], .little);
        std.debug.print("support release mode={d} finish={d} fault={d} velocity={d} contact={x}\n", .{ i, out.finish, out.fault, out.velocity[0], actual_support });
        if (i == 49 or i == 51 or i == 54) {
            check(@src(), out.finish != 0 and out.fault == 0 and out.velocity[0] == 1 and actual_support == 0);
            check(@src(), out.gates[0].payload.character_motion.support_material_flags == p.SYNC_SUPPORT_ABSENT);
        } else {
            check(@src(), out.finish == 0 and out.fault != 0 and out.velocity[0] == 7);
            check(@src(), actual_support == support + @as(u32, if (i == 52) 0x200 else 0));
        }
    }
    installedHooks();
    zilloIslandOrder();
    zilloBarcSupport();
    zilloBarcAlignment();
    zilloDishIslandOrder();
    arenaRunRandomChecks();
    arenaRunRandomAbi();
    rylothFighterDeath();
    geonosisVehicleDeath();
    hiddenEnemyForceEligibility();
    blueShadowContactDecisions();
    blueShadowProjectileAction();
    blueShadowPlayerProjectileContact(71, 156, 3432);
    blueShadowPlayerProjectileContact(74, 188, 1268);
    blueShadowVindiSupport(321);
    blueShadowVindiSupport(333);
    blueShadowPadmeSupport();
    forceReleaseCountdown(7);
    forceReleaseCountdown(71);
    forceReleaseCountdown(73);
    forceReleaseCountdown(74);
    geonosisGuestForceScan();
}
fn arenaRunRandomAbi() void {
    const random = @import("arena_run_random.zig");
    const arena_fixture = @import("arena_run_random_fixture.zig");
    const original = random.arena_run_random_original;
    random.arena_run_random_original = @intFromPtr(&arena_fixture.arena_random_probe_native);
    defer random.arena_run_random_original = original;
    for (0..4) |rounding| for (0..3) |kind| {
        mode = 0;
        setup();
        frame.epoch = 20000 + @as(u32, @intCast(rounding * 3 + kind));
        frame.level = 12;
        put(task, win.GetModuleHandleA(null) + 0x6dee68);
        put(task + 0x10, actor);
        put(task + 0x14, other);
        put(task + 0x40, 10);
        put(other, win.GetModuleHandleA(null) + 0x6d83dc);
        put(other + 0x340, task);
        win.store(i16, actor + 0xdc0, 119);
        var token = std.mem.zeroes(Token);
        token.owner = actor;
        token.owner_nonce = 1;
        token.thread = win.GetCurrentThreadId();
        token.release = frame.epoch;
        token.epoch = frame.epoch;
        token.sequence = frame.sequence;
        token.frame = @intFromPtr(frame);
        var lease: s.Lease = undefined;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        if (kind == 1) {
            put(0xe637b4, 5000);
            check(@src(), random.cadence_arena_run_random(task, 0x464b44, 5000) == 5000 and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
            client = true;
            token.release += 1;
            check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        } else if (kind == 2) check(@src(), ci.cadence_abort_frame(&lease) != 0);
        arena_fixture.arena_random_probe_controller = task;
        arena_fixture.arena_random_probe_cw = 0x37f | (@as(u32, @intCast(rounding)) << 10);
        arena_fixture.arena_random_probe_mxcsr = 0x1f80 | (@as(u32, @intCast(rounding)) << 13);
        for (&arena_fixture.arena_random_probe_xmm, 0..) |*byte, i| byte.* = @truncate(i * 13 + rounding * 7);
        arena_fixture.arena_random_probe_entry = @intFromPtr(&arena_fixture.arena_random_probe_original);
        put(0xe637b4, 7000);
        const calls = arena_fixture.arena_random_probe_calls;
        arena_fixture.arena_random_probe();
        var regs = arena_fixture.arena_random_probe_regs;
        const fx = arena_fixture.arena_random_probe_fx;
        const expected_seed: u32 = if (kind == 1) 5000 else win.load(u32, 0xe637b4);
        if (kind == 1) regs[7] = expected_seed;
        arena_fixture.arena_random_probe_entry = 0x464b3f;
        put(0xe637b4, 7000);
        arena_fixture.arena_random_probe();
        check(@src(), arena_fixture.arena_random_probe_calls == calls + 2 and win.GetLastError() == 321 and win.load(u32, 0xe637b4) == expected_seed);
        if (!std.mem.eql(u32, &regs, &arena_fixture.arena_random_probe_regs)) std.debug.print("arena random ABI kind={d} rounding={d} regs={any} actual={any}\n", .{ kind, rounding, regs, arena_fixture.arena_random_probe_regs });
        for (fx, arena_fixture.arena_random_probe_fx, 0..) |a, b, i| if (a != b) {
            std.debug.print("arena random FX kind={d} rounding={d} offset={d} {d}!={d}\n", .{ kind, rounding, i, a, b });
        };
        check(@src(), std.mem.eql(u32, &regs, &arena_fixture.arena_random_probe_regs) and std.mem.eql(u8, &fx, &arena_fixture.arena_random_probe_fx));
        if (kind != 2) check(@src(), ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
    };
}
fn arenaRunRandomChecks() void {
    const random = @import("arena_run_random.zig");
    for (0..18) |mutation| {
        mode = 0;
        setup();
        frame.level = 12;
        put(task, win.GetModuleHandleA(null) + 0x6dee68);
        put(task + 0x10, actor);
        put(task + 0x14, other);
        put(task + 0x40, 10);
        put(other, win.GetModuleHandleA(null) + 0x6d83dc);
        put(other + 0x340, task);
        win.store(i16, actor + 0xdc0, 119);
        var token = std.mem.zeroes(Token);
        token.owner = actor;
        token.owner_nonce = 1;
        token.thread = win.GetCurrentThreadId();
        token.release = frame.epoch;
        token.epoch = frame.epoch;
        token.sequence = frame.sequence;
        token.frame = @intFromPtr(frame);
        var lease: s.Lease = undefined;
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 1) != 0);
        const actor_before = win.load([0x1440]u8, actor);
        const controller_before = win.load([0x84]u8, task);
        put(0xe637b4, 5000);
        check(@src(), random.cadence_arena_run_random(task, 0x464b44, 5000) == 5000);
        put(0xe637b4, 6000);
        check(@src(), random.cadence_arena_run_random(task, 0x464b71, 6000) == 6000 and frame.fire_task_gate_count == 2);
        check(@src(), @import("fire_validation.zig").valid(&frame.fire_task_gates[0]) and ci.cadence_finish() != 0 and ci.cadence_abort_frame(&lease) != 0);
        client = true;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        token.release += 1;
        var caller: usize = 0x464b44;
        var local: u32 = 7000;
        put(0xe637b4, local);
        switch (mutation) {
            1 => caller += 1,
            2 => put(task, win.GetModuleHandleA(null) + 0x6dee70),
            3 => put(other, win.GetModuleHandleA(null) + 0x6d83e0),
            4 => put(other + 0x340, task + 4),
            5 => win.store(i16, actor + 0xdc0, 117),
            6 => put(task + 0x40, 11),
            7 => put(actor + 0x50, 1),
            8 => retained = false,
            9 => put(0xe637b4, 7001),
            10 => {
                local = 65536;
                put(0xe637b4, local);
            },
            11 => frame.fire_task_gates[0].value = 65536,
            12 => frame.fire_task_gates[0].payload.arena_run_random.clock += 1,
            13 => frame.fire_task_gates[0].flags = 1,
            14 => frame.fire_task_gate_count = 0,
            15 => mode = 55,
            16 => frame.fire_task_gates[0].payload.storage[12] = 1,
            17 => frame.fire_task_gates[0].payload.arena_run_random.run_state = 11,
            else => {},
        }
        if (mutation == 11 or mutation == 16 or mutation == 17) check(@src(), !@import("fire_validation.zig").valid(&frame.fire_task_gates[0]));
        check(@src(), ci.cadence_bind_cohort(&token) != 0 and ci.cadence_frame_lease_get(&lease) != 0 and ci.cadence_begin(frame, 0) != 0);
        win.SetLastError(1234);
        const result = random.cadence_arena_run_random(task, caller, local);
        check(@src(), win.GetLastError() == 1234);
        if (mutation == 0) {
            check(@src(), result == 5000 and win.load(u32, 0xe637b4) == 5000);
            put(0xe637b4, 8000);
            check(@src(), random.cadence_arena_run_random(task, 0x464b71, 8000) == 6000 and win.load(u32, 0xe637b4) == 6000);
            check(@src(), std.mem.eql(u8, &actor_before, @as([*]const u8, @ptrFromInt(actor))[0..actor_before.len]) and std.mem.eql(u8, &controller_before, @as([*]const u8, @ptrFromInt(task))[0..controller_before.len]) and ci.cadence_finish() != 0);
        } else {
            check(@src(), ci.cadence_finish() == 0 and win.load(u32, 0xe637b4) == (if (mutation == 9) @as(u32, 7001) else local));
        }
        check(@src(), ci.cadence_abort_frame(&lease) != 0);
    }
    geonosisCompanionMotionOrder();
    blueShadowCompanionMotionOrder(70);
    blueShadowCompanionMotionOrder(73);
    blueShadowCompanionMotionOrder(74);
    blueShadowNativeOpponent(false);
    blueShadowNativeOpponent(true);
    blueShadowDroidMotionOrder(321, false, false);
    blueShadowDroidMotionOrder(333, true, false);
    blueShadowDroidMotionOrder(337, true, false);
    blueShadowDroidMotionOrder(333, false, true);
    blueShadowReleasedAim();
    blueShadowRecordedAim(70, false, false);
    blueShadowRecordedAim(73, false, false);
    blueShadowRecordedAim(74, false, false);
    blueShadowRecordedAim(74, true, false);
    blueShadowRecordedAim(74, true, true);
    blueShadowGuestOnlyAim(false, 0, 321, false);
    blueShadowGuestOnlyAim(false, 0, 321, true);
    blueShadowGuestOnlyAim(true, 0, 321, false);
    blueShadowGuestOnlyAim(false, 1, 321, false);
    blueShadowGuestOnlyAim(false, 1, 333, false);
    blueShadowGuestOnlyAim(true, 3, 333, false);
    hiddenLabAimBeforeMotion(false);
    hiddenLabAimBeforeMotion(true);
    droidAimOrder(29);
    droidAimOrder(70);
    droidAimOrder(71);
}
