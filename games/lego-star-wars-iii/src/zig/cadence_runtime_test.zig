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
    return if (a == actor) 7 else 8;
}
export fn entities_observed_generation(_: usize) u32 {
    return 19;
}
export fn entities_observed_identity(a: usize, slot: *u32, generation: *u32) c_int {
    slot.* = if (a == actor) 7 else 8;
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
export fn entities_actor(slot: u32, _: u32) usize {
    return if (slot == 7) actor else other;
}
export fn entities_resolve_reference(state: *const p.SyncActor) usize {
    resolves += 1;
    if (client and mode == 39) valid = false;
    if (client and mode == 25) put(poi + 0xd4, 0);
    if (client and (mode == 12 or (mode == 33 and state.slot == 8))) return 0;
    return if (state.slot == 7) actor else other;
}
export fn physics_effect_body_source(object: usize, out: *[2]u32) c_int {
    check(@src(), object == support);
    out.* = .{ 13, if (client and mode == 28) 18 else 17 };
    return 1;
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
            cb.cadence_apply_attack_support(actor, &out.result);
        },
        5 => out.result = cb.cadence_apply_breakup_visibility(actor, @intFromBool(!client)),
        6 => cb.cadence_apply_death_breakup(actor, &out.argument),
        7 => out.result = cb.cadence_apply_fall_visibility(actor, @intFromBool(!client)),
        8...10 => {
            if (mode == 9 and client) float(task + 0x14, 4);
            if (mode != 10) ct.cadence_prepare_aim_task(actor, task);
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
            ct.cadence_prepare_aim_base(task, wrapper, &out.delta);
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
        26...30 => {
            if (mode == 26) put(body + 0xec, 0);
            if (mode == 29) out.velocity[0] = std.math.nan(f32);
            if (mode == 30) put(model + 0x38, 0);
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
fn installedHooks() void {
    const patches = @import("cadence_install.zig").patches();
    check(@src(), patches.len == 24);
    for (patches) |patch| {
        check(@src(), patch.expected.len <= 32);
        protect(patch.address & ~@as(usize, 0xffff), 0x10000, 0x40);
        @memcpy(@as([*]u8, @ptrFromInt(patch.address))[0..patch.expected.len], patch.expected);
    }
    win.store(u8, 0x96d954, 0xc3);
    win.store(u8, 0x8789f7, 0xc3);
    win.store(u8, 0x9ddc1f, 0xc3);
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
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 3076 and @intFromPtr(&image) < 0x420000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0xe60000, 0xe90000, 0xea0000, 0xfb0000 }) |address| protect(address, 0x10000, 4);
    for (0..24) |i| {
        const address = 0x20000000 + i * 0x10000;
        check(@src(), win.VirtualAlloc(address, 0x2000, 0x3000, 4) == address);
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
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("cadence runtime mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 0) check(@src(), out.finish != 0 and out.period == 2);
        if (mode == 3) check(@src(), out.finish != 0 and out.gate_count == 1 and out.diagnostics.clonewars_fire_task_gate_debug[1] != 0);
        if (mode == 8) check(@src(), out.finish != 0 and out.result == 1);
        if (mode == 26) check(@src(), out.finish != 0 and out.velocity[0] == 1);
        if (mode == 22) check(@src(), out.finish != 0);
    }
    installedHooks();
}
