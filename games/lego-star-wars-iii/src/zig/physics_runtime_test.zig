const std = @import("std");
const p = @import("protocol.zig");
const s = @import("physics_state.zig");
const e = @import("physics_effects.zig");
const types = @import("cohort_types.zig");
const win = @import("win32.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("lexical_seh.zig");
}
const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
const descriptor: usize = 0x20000000;
const handle: usize = 0x20010000;
const resource: usize = 0x20020000;
const pool: usize = 0x20030000;
const receiver: usize = 0x20040000;
const body: usize = 0x20050000;
const matrix: *[16]f32 = @ptrFromInt(0x20060000);
const scale: *[3]f32 = @ptrFromInt(0x20070000);
const probe = @import("native_probe_fixture.zig");
pub const probe_registers =
    \\movl $0x20030000,%ebx
    \\movl _argument,%eax
;
extern fn physics_effect_rest_thunk() void;
extern fn effect_rest_native_exit() void;
extern fn effect_rest_exit() void;
extern fn effect_moving_exit() void;
export var expected_rest_mask: u32 = 0;
comptime {
    asm (
        \\.text
        \\_effect_rest_native_exit:
        \\pushl %eax
        \\movl _expected_rest_mask,%eax
        \\testb $0x41,%al
        \\popl %eax
        \\jnz _effect_moving_exit
        \\_effect_rest_exit:
        \\movl $1,_branch
        \\ret
        \\_effect_moving_exit:
        \\movl $2,_branch
        \\ret
    );
}
const name: usize = 0x20080000;
const Spin = *const fn (usize) callconv(.c) u32;
var spins: [2]usize = undefined;
var current = std.mem.zeroes(types.Lease);
var mode: u32 = 0;
var fault: c_int = 0;
var valid = true;
var cancelled = false;
var native_calls: u32 = 0;
var update_delta: f32 = 0;
fn nativeUpdate(delta: f32) callconv(.c) void {
    check(@src(), win.GetLastError() == 1234);
    update_delta = delta;
    native_calls += 1;
    win.SetLastError(321);
}
export fn geometry_frame_lease_get(out: *types.Lease) c_int {
    out.* = current;
    return 1;
}
export fn geometry_frame_cancelled(_: *const types.Lease) c_int {
    return @intFromBool(cancelled);
}
export fn coherent_frame_valid(_: *const types.Token, phases: u32) c_int {
    check(@src(), phases == 2 or phases == 4 or phases == 14);
    return @intFromBool(valid);
}
export fn game_sync_native_fault(reason: c_int) void {
    fault = reason;
}
export fn entities_bind_native_reference(_: *const p.SyncActor, _: usize) c_int {
    return @intFromBool(mode != 20);
}
export fn entities_observed_identity(_: usize, slot: *u32, generation: *u32) c_int {
    slot.* = 2;
    generation.* = 7;
    return 1;
}
export fn entities_actor(slot: u32, generation: u32) usize {
    return if (mode == 405 and slot == 22 and generation == 45) 0xfb2000 else 0;
}
export fn spellit_input_install() c_int {
    return 1;
}
export fn module_rng_input_install() c_int {
    return 1;
}
export fn vehicle_rng_input_install() c_int {
    return 1;
}
const Snapshot = extern struct {
    result: c_int,
    finish: c_int,
    fault: c_int,
    body_result: c_int,
    exception: c_int,
    source: [2]u32,
    count: u32,
    rng: u32,
    err: u32,
    effect_rng: u32,
    calls: u32,
    debug: [8]u32,
    failure: [12]u32,
    launch: [4]u32,
    correction: [8]u32,
    motion: [14]u32,
    geometry: [8]u32,
    local: [19]u32,
    host: [19]u32,
    birth: [8]u32,
    choices: [5]p.SyncPhysicsChoice,
    input: p.SyncPhysicsChoice,
    descriptor: [48]u8,
    matrix: [16]f32,
    scale: [3]f32,
};
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn nativeSpin(effect: usize) callconv(.c) u32 {
    check(@src(), effect == pool);
    native_calls += 1;
    put(0xe5f498, win.load(u32, 0xe5f498) + 1);
    if (mode == 31) win.RaiseException(0xe1459876, 0, 0, null);
    if (mode == 32) current.serial += 1;
    win.SetLastError(321);
    return 71;
}
var spin_result: u32 = 0;
fn spinCall(_: usize) callconv(.c) c_int {
    spin_result = @as(Spin, @ptrFromInt(0x700000))(pool);
    return 1;
}
fn invokeSpin() c_int {
    const code = support.exceptionCode(0, spinCall);
    check(@src(), code == 0 or code == 0xe1459876);
    return @intFromBool(code != 0);
}
fn setup() void {
    @memset(std.mem.asBytes(frame), 0);
    frame.epoch = 100 + mode;
    frame.sequence = 8;
    current = std.mem.zeroes(types.Lease);
    current.serial = 9;
    current.cohort.frame = @intFromPtr(frame);
    current.cohort.epoch = frame.epoch;
    current.cohort.sequence = 8;
    current.cohort.release = 4;
    valid = true;
    cancelled = false;
    fault = 0;
    native_calls = 0;
    @memset(bytes(descriptor, 48), 0);
    win.store(u8, descriptor + 0x2c, 1);
    put(descriptor + 4, 13);
    put(handle + 4, resource);
    put(resource + 0xb4, name);
    for (matrix, 0..) |*v, i| v.* = @floatFromInt(i);
    for (scale, 0..) |*v, i| v.* = @floatFromInt(i + 1);
    @memset(bytes(pool, 0x1000), 0);
    put(0xfa3d38, pool);
    put(0xe5f480, 2);
    put(0xfb4b6c, 31);
    put(0xe637b4, 91);
    put(pool + 0x11c, 0x40100080);
    put(pool + 0x15c, 1);
    put(pool + 0x1f8, receiver);
    put(receiver + 0x1a0, body);
    put(pool + 0x164, resource);
    win.store(u16, pool + 0x156, 13);
    put(0xe5f498, 51);
    s.clonewars_physics_input_debug = @splat(0);
    s.clonewars_physics_input_failure = @splat(0);
    s.clonewars_breakup_launch_correction = @splat(0);
    e.clonewars_breakup_launch_debug = @splat(0);
    e.clonewars_breakup_launch_motion_debug = @splat(0);
    e.clonewars_breakup_geometry_debug = @splat(0);
    e.clonewars_breakup_geometry_local = @splat(0);
    e.clonewars_breakup_geometry_host = @splat(0);
    e.clonewars_effect_birth_debug = @splat(0);
}
fn client() void {
    check(@src(), s.physics_input_finish() != 0);
    check(@src(), s.physics_input_begin(frame, 0) != 0);
}
fn sourceChoice(index: u32) p.SyncPhysicsChoice {
    var input = std.mem.zeroes(p.SyncPhysicsChoice);
    if (index < 4) {
        const kinds = [_]u32{ p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION, p.SYNC_PHYSICS_RTS_BODY_BASIS, p.SYNC_PHYSICS_RTS_BODY_MOTION };
        input.kind = kinds[index];
        input.site = if (index < 2) 0x840660 else 0x544b10;
        input.payload.spellit_body.clock = 31;
        input.payload.spellit_body.body_class = 0x869eac;
        input.payload.spellit_body.key[0] = 99;
        input.payload.spellit_body.values[0] = 3;
    } else switch (index) {
        4 => {
            input.kind = p.SYNC_PHYSICS_SPELLIT_STEP;
            input.site = 0x86101e;
            const v = &input.payload.spellit_step;
            v.clock = 31;
            v.engine_seed = 73;
            v.delta = 0.01;
            v.timer = 3;
            v.game_seed = 79;
            v.gizmo_class = 0x1234;
            v.source_name[0] = 99;
        },
        5 => {
            input.kind = p.SYNC_PHYSICS_SPELLIT_POSE;
            input.site = 0x8406b2;
            const v = &input.payload.spellit_pose;
            v.clock = 31;
            v.gizmo_class = 0x1234;
            v.source_name[0] = 99;
            v.resource_name[0] = 98;
            v.poi_name[0] = 97;
            v.last_time = 3;
            v.position[0] = 4;
        },
        6 => {
            input.kind = p.SYNC_PHYSICS_SPELLIT_SELECTION;
            input.site = 0x8406a7;
            const v = &input.payload.spellit_selection;
            v.clock = 31;
            v.engine_seed = 71;
            v.gizmo_class = 0x1234;
            v.source_name[0] = 99;
            v.eligibility[0] = 97;
        },
        7 => {
            input.kind = p.SYNC_PHYSICS_RTS_GENERATOR;
            input.site = 0x547d30;
            const v = &input.payload.rts_generator;
            v.clock = 31;
            v.object_class = 0xaed18c;
            v.delta = 0.01;
            v.elapsed = 2;
            v.rng_game = 71;
        },
        8 => {
            input.kind = p.SYNC_PHYSICS_RTS_ORDER;
            input.site = 0x55e2c0;
            const v = &input.payload.rts_order;
            v.clock = 31;
            v.order_class = 0xaed18c;
            v.source_key[0] = 99;
            v.state = 3;
            v.elapsed = 2;
        },
        9 => {
            input.kind = p.SYNC_PHYSICS_MODULE_SEED;
            input.site = 0x4da6d0;
            const v = &input.payload.module;
            v.clock = 31;
            v.value = 71;
            v.module_id = 1;
            v.module_type = 2;
            v.module_class = 0x6e6b3c;
            v.burst_max = 3;
        },
        10 => {
            input.kind = p.SYNC_PHYSICS_GUN_JAM_SEED;
            input.site = 0x4acb53;
            const v = &input.payload.gun_jam;
            v.clock = 31;
            v.value = 71;
            v.module_id = 1;
            v.module_type = 2;
            v.maximum = 3;
        },
        else => {
            input.kind = switch (index) {
                11 => p.SYNC_PHYSICS_RTS_VISIBILITY,
                12 => p.SYNC_PHYSICS_SPELLIT_ENTITY,
                13 => p.SYNC_PHYSICS_SPELLIT_ENABLED,
                else => p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS,
            };
            input.site = switch (index) {
                11 => 0x5525e0,
                12 => 0x8407d4,
                13 => 0x84085b,
                else => 0x812d7a,
            };
            const v = &input.payload.world;
            v.clock = 31;
            v.gizmo_class = 0x8480ac;
            v.source_name[0] = 99;
            if (index != 11) {
                v.receiver_class = 0x1234;
                v.resource_name[0] = 98;
                v.poi_name[0] = 97;
                v.poi_count = 1;
            }
        },
    }
    return input;
}
fn run() Snapshot {
    setup();
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    var input = std.mem.zeroes(p.SyncPhysicsChoice);
    input.kind = p.SYNC_PHYSICS_SPELLIT_SEED;
    input.site = 0x86101e;
    input.payload.world.clock = 31;
    input.payload.world.value = 19;
    input.payload.world.gizmo_class = 0x1234;
    input.payload.world.source_name[0] = 99;
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    if (mode < 10) {
        if (mode == 1) input.payload.world.gizmo_class = 0;
        if (mode == 2) input.kind = 0;
        if (mode == 3) frame.physics_choice_count = p.SYNC_MAX_PHYSICS_CHOICES;
        if (mode == 4) valid = false;
        if (mode == 5) cancelled = true;
        if (mode == 6) current.serial += 1;
        out.result = s.physics_world_input(&input, &current.cohort);
        if (mode >= 7) {
            client();
            input.payload.world.value = 71;
            if (mode == 8) input.payload.world.clock += 1;
            if (mode == 9) frame.physics_choice_count = 0;
            out.result = s.physics_world_input(&input, &current.cohort);
        }
    } else if (mode < 18) {
        _ = e.physics_apply_breakup_launch(descriptor, handle, @intFromPtr(matrix), @intFromPtr(scale), 0, 0);
        if (mode != 10) {
            client();
            put(0xe637b4, 999);
            win.store(f32, descriptor + 0x10, 7);
            matrix[4] = 55;
            scale[1] = 19;
            if (mode == 12) frame.physics_choices[0].payload.basic.clock += 1;
            if (mode == 13) frame.physics_choice_count = 1;
            if (mode == 14) frame.physics_choices[2].payload.basic.clock += 1;
            if (mode == 15) frame.physics_choices[1].payload.breakup_basis.matrix[0] = std.math.nan(f32);
            if (mode == 16) win.store(u8, descriptor + 0x2c, 0);
            if (mode == 17) cancelled = true;
            _ = e.physics_apply_breakup_launch(descriptor, handle, @intFromPtr(matrix), @intFromPtr(scale), 0, 0);
        }
    } else if (mode < 23) {
        input = std.mem.zeroes(p.SyncPhysicsChoice);
        input.kind = p.SYNC_PHYSICS_VEHICLE_RNG;
        input.site = 0x997f03;
        input.payload.vehicle_rng.clock = 31;
        input.payload.vehicle_rng.slot = 2;
        input.payload.vehicle_rng.generation = 7;
        input.payload.vehicle_rng.vehicle_type = 4;
        input.payload.vehicle_rng.value = 29;
        check(@src(), s.physics_vehicle_rng_input(&input, body, &current.cohort) == 1);
        client();
        input.payload.vehicle_rng.value = 99;
        if (mode == 21) frame.physics_choices[0].payload.vehicle_rng.generation += 1;
        if (mode == 22) frame.physics_choices[0].site += 1;
        out.result = s.physics_vehicle_rng_input(&input, body, &current.cohort);
    } else if (mode < 28) {
        e.physics_effect_birth(pool);
        if (mode == 24) {
            client();
            e.physics_effect_birth(pool);
        }
        if (mode == 25) put(pool + 0x15c, 0);
        if (mode == 26) {
            @memcpy(bytes(pool + 0x228, 0x228), bytes(pool, 0x228));
            e.physics_effect_birth(pool + 0x228);
        }
        if (mode == 27) current.cohort.release += 1;
        out.body_result = e.physics_effect_body_source(body, &out.source);
    } else if (mode < 33) {
        const caller = [_]u8{ 0xff, 0x74, 0x24, 4, 0xe8, 0, 0, 0, 0, 0x83, 0xc4, 4, 0xc3 };
        @memcpy(bytes(0x700000, caller.len), &caller);
        put(0x700005, spins[@intFromBool(mode == 29)] -% 0x700009);
        check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x700000, caller.len) != 0);
        spin_result = 0;
        const saved_mode = mode;
        if (mode == 31 or mode == 32) mode = 28;
        check(@src(), invokeSpin() == 0 and spin_result == 71);
        mode = saved_mode;
        client();
        put(0xe5f498, 999);
        win.SetLastError(1234);
        out.exception = invokeSpin();
        out.result = @bitCast(spin_result);
    } else {
        const index = mode - 33;
        input = sourceChoice(index);
        check(@src(), @import("physics_validation.zig").valid(&input));
        const source: *const fn (?*p.SyncPhysicsChoice, ?*const types.Token) callconv(.c) c_int = if (index == 9 or index == 10) s.physics_module_input else s.physics_world_input;
        check(@src(), source(&input, &current.cohort) == 1);
        client();
        if (index < 4) {
            input.payload.spellit_body.values[0] = 19;
        } else switch (index) {
            4 => {
                input.payload.spellit_step.engine_seed = 99;
                input.payload.spellit_step.game_seed = 91;
                input.payload.spellit_step.delta = 0.03;
                input.payload.spellit_step.timer = 13;
            },
            5 => {
                input.payload.spellit_pose.position[0] = 19;
                input.payload.spellit_pose.last_time = 18;
            },
            7 => {
                input.payload.rts_generator.delta = 0.03;
                input.payload.rts_generator.elapsed = 19;
                input.payload.rts_generator.rng_game = 91;
            },
            8 => {
                input.payload.rts_order.state = 19;
                input.payload.rts_order.elapsed = 18;
            },
            else => input.payload.world.value = if (index == 14) 4 else 1,
        }
        out.result = source(&input, &current.cohort);
    }
    out.err = win.GetLastError();
    out.finish = s.physics_input_finish();
    out.fault = fault;
    out.count = frame.physics_choice_count;
    out.input = input;
    out.rng = win.load(u32, 0xe637b4);
    out.effect_rng = win.load(u32, 0xe5f498);
    out.calls = native_calls;
    out.debug = s.clonewars_physics_input_debug;
    out.failure = s.clonewars_physics_input_failure;
    out.launch = e.clonewars_breakup_launch_debug;
    out.correction = s.clonewars_breakup_launch_correction;
    out.motion = e.clonewars_breakup_launch_motion_debug;
    out.geometry = e.clonewars_breakup_geometry_debug;
    out.local = e.clonewars_breakup_geometry_local;
    out.host = e.clonewars_breakup_geometry_host;
    out.birth = e.clonewars_effect_birth_debug;
    out.choices = frame.physics_choices[0..5].*;
    out.descriptor = bytes(descriptor, 48)[0..48].*;
    out.matrix = matrix.*;
    out.scale = scale.*;
    s.physics_input_cancel();
    return out;
}
fn protect(address: usize, length: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, length, 0x40, &old) != 0);
}
fn install() void {
    for ([_]usize{ 0x743bb0, 0x743ca8 }) |a| protect(a, 16);
    @memcpy(bytes(0x743bb0, 6), &[_]u8{ 0x55, 0x8b, 0xec, 0x83, 0xe4, 0xf0 });
    @memcpy(bytes(0x743bb6, 13), &[_]u8{ 0xff, 0x75, 8, 0xe8, 0, 0, 0, 0, 0x83, 0xc4, 4, 0xc9, 0xc3 });
    put(0x743bba, @intFromPtr(&nativeUpdate) -% 0x743bbe);
    @memcpy(bytes(0x743ca8, 9), &[_]u8{ 0xf6, 0xc4, 0x41, 0x0f, 0x85, 0xfc, 8, 0, 0 });
    const blast = @import("blue_shadow_blast.zig");
    for ([_]usize{ 0x700000, 0x71ab90, 0x71ac10, 0x742051, 0x7427d8, blast.register_site, 0x8860ce, 0x905f33 }) |a| protect(a, 64);
    @memcpy(bytes(blast.register_site, blast.register_prefix.len), blast.register_prefix);
    @memcpy(bytes(0x8860ce, blast.update_prefix.len), blast.update_prefix);
    @memcpy(bytes(0x71ab90, 6), &[_]u8{ 0x56, 0x57, 0x8b, 0x7c, 0x24, 0x0c });
    @memcpy(bytes(0x71ac10, 6), &[_]u8{ 0x56, 0x68, 0x98, 0xf4, 0xe5, 0 });
    @memcpy(bytes(0x71ab96, 12), &[_]u8{ 0x57, 0xe8, 0, 0, 0, 0, 0x83, 0xc4, 4, 0x5f, 0x5e, 0xc3 });
    @memcpy(bytes(0x71ac16, 14), &[_]u8{ 0xff, 0x74, 0x24, 0x0c, 0xe8, 0, 0, 0, 0, 0x83, 0xc4, 8, 0x5e, 0xc3 });
    put(0x71ab98, @intFromPtr(&nativeSpin) -% 0x71ab9c);
    put(0x71ac1b, @intFromPtr(&nativeSpin) -% 0x71ac1f);
    @memcpy(bytes(0x7427d8, 7), &[_]u8{ 0x8b, 0x8c, 0x24, 8, 2, 0, 0 });
    @memcpy(bytes(0x905f33, 5), &[_]u8{ 0xe8, 0xb8, 0x0b, 6, 0 });
    @memcpy(bytes(0x742051, 12), &[_]u8{ 0xf7, 0x80, 0x1c, 1, 0, 0, 0, 2, 0, 0, 0x75, 7 });
    check(@src(), e.physics_input_install() != 0);
    spins = .{ 0x71ab95 +% win.load(u32, 0x71ab91), 0x71ac15 +% win.load(u32, 0x71ac11) };
}
extern fn blue_shadow_blast_register(usize, usize) void;
extern fn blue_shadow_blast_update() void;
fn labBlast() void {
    mode = 405;
    setup();
    frame.level = 73;
    const blast_pool = 0xfb3358;
    const native_slot = blast_pool + 3 * 64;
    @memset(bytes(blast_pool, 512), 0);
    put(0xfb30b0, 3);
    put(descriptor, 0xad953c);
    @memcpy(bytes(descriptor + 0x30, 16), "iVindi_Can_01_Bl");
    const position = [3]u32{ 0x3f800000, 0x3f000000, 0x42200000 };
    win.store([3]u32, descriptor + 0x60, position);
    const arguments = [9]u32{ 0x86507b, descriptor + 0x60, 0x3ecccccc, 0x3f000000, 0, 0xce99e0, 0x4025, 0xffffffff, 0 };
    const seed = (91 * 0x24cd + 1) & 0xffff;
    const canonical = [16]u32{ 0, 0, 0, 0, position[0], position[1], position[2], 0x3ecccccc, 0, 0x3f000000, 0x4025, 0, 0xfffe0000 | seed, 0xff010000, 0xff, 0 };
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    blue_shadow_blast_register(@intFromPtr(&arguments), descriptor);
    win.store([16]u32, native_slot, canonical);
    blue_shadow_blast_update();
    check(@src(), frame.physics_choice_count == 1 and s.physics_input_finish() != 0);

    const captured = frame.physics_choices[0];
    var lower_approach = captured;
    lower_approach.payload.blast.words[4..7].* = .{ 0xc1102966, 0xc0c37a0e, 0x41db5993 };
    check(@src(), @import("physics_validation.zig").valid(&lower_approach));
    current.cohort.release += 1;
    put(0xfb4b6c, 30);
    frame.physics_choice_count = 0;
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    var early = canonical;
    early[4] = 0x40000000;
    put(descriptor + 0x60, early[4]);
    blue_shadow_blast_register(@intFromPtr(&arguments), descriptor);
    win.store([16]u32, native_slot, early);
    blue_shadow_blast_update();
    check(@src(), win.load(u32, native_slot + 0x10) == early[4] and win.load(u32, native_slot + 0x20) == early[9] and s.physics_input_finish() != 0);

    current.cohort.sequence += 1;
    frame.sequence += 1;
    put(0xfb4b6c, 31);
    frame.physics_choices[0] = captured;
    frame.physics_choice_count = 1;
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    blue_shadow_blast_update();
    const after_early = win.load([16]u32, native_slot);
    check(@src(), std.mem.eql(u32, &canonical, &after_early) and s.physics_input_finish() != 0);

    current.cohort.sequence += 1;
    frame.sequence += 1;
    frame.physics_choice_count = 0;
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    win.store(u8, descriptor + 0x30, 'x');
    blue_shadow_blast_register(@intFromPtr(&arguments), descriptor);
    win.store([16]u32, native_slot, canonical);
    blue_shadow_blast_update();
    check(@src(), win.load(u32, native_slot + 0x20) == 0 and s.physics_input_finish() != 0);

    current.cohort.release += 1;
    win.store(u8, descriptor + 0x30, 'i');
    frame.physics_choice_count = 1;
    frame.physics_choices[0].payload.blast.update = 2;
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    put(descriptor + 0x60, position[0]);
    blue_shadow_blast_register(@intFromPtr(&arguments), descriptor);
    win.store([16]u32, native_slot, canonical);
    var other_caller = arguments;
    other_caller[0] = 0x434125;
    blue_shadow_blast_register(@intFromPtr(&other_caller), descriptor);
    blue_shadow_blast_update();
    check(@src(), win.load(u32, native_slot + 0x20) == 0);
    blue_shadow_blast_update();
    check(@src(), win.load(u32, native_slot + 0x20) == 0 and s.physics_input_finish() == 0);

    frame.physics_choices[0] = captured;
    for ([_]usize{ 2, 3, 11 }) |index| {
        var pointer_payload = captured;
        pointer_payload.payload.blast.words[index] = descriptor;
        check(@src(), !@import("physics_validation.zig").valid(&pointer_payload));
    }
    for (0..2) |conflict| {
        current.cohort.release += 1;
        @memset(bytes(native_slot, 64), 0);
        if (conflict != 0) {
            put(native_slot + 0x24, 0x3f000000);
            put(native_slot + 0x28, 0x8025);
        }
        check(@src(), s.physics_input_begin(frame, 0) != 0);
        blue_shadow_blast_update();
        if (conflict == 0) {
            const actual = win.load([16]u32, native_slot);
            check(@src(), std.mem.eql(u32, &canonical, &actual) and s.physics_input_finish() != 0);
        } else {
            check(@src(), win.load(u32, native_slot + 0x28) == 0x8025 and s.physics_input_finish() == 0);
        }
    }

    current.cohort.release += 1;
    @memset(bytes(native_slot, 64), 0);
    frame.actor_count = 1;
    frame.actors[0].slot = 22;
    frame.actors[0].generation = 45;
    frame.physics_choices[0].payload.blast.words[0] = 1 << 22;
    put(0xfb3090, 1 << 24);
    put(0xfb3094, 0);
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    blue_shadow_blast_update();
    check(@src(), win.load(u32, native_slot) == 1 << 24 and s.physics_input_finish() != 0);
    s.physics_input_cancel();
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 1100 and @intFromPtr(&image) < 0x700000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0xe50000, 0xe60000, 0xfa0000, 0xfb0000 }) |address| protect(address, 0x10000);
    for (0..9) |i| check(@src(), win.VirtualAlloc(0x20000000 + i * 0x10000, 0x1000, 0x3000, 4) == 0x20000000 + i * 0x10000);
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    defer {
        for (0..9) |i| check(@src(), win.VirtualFree(0x20000000 + i * 0x10000, 0, 0x8000) != 0);
        check(@src(), win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
    }
    @memcpy(bytes(name, 8), "fixture\x00");
    install();
    labBlast();
    setup();
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    var a = std.mem.zeroes(p.SyncPhysicsChoice);
    a.kind = 25;
    a.site = 0x743ca8;
    a.payload.basic.model = 65535;
    a.payload.basic.flags = 0x40000091;
    a.payload.basic.clock = 31;
    a.payload.basic.name_hash = .{ 30, 11 };
    a.payload.basic.recipe[1] = 0x904e80;
    check(@src(), s.record(a));
    var b = a;
    b.payload.basic.name_hash[1] = 21;
    check(@src(), s.record(b));
    check(@src(), s.physics_input_finish() != 0);
    check(@src(), s.physics_input_begin(frame, 0) != 0);
    check(@src(), s.rest(&b) != null);
    check(@src(), s.rest(&a) != null);
    check(@src(), s.rest(&a) == null);
    const expected = [_]u32{ 3255168280, 820360545, 93849299, 939128762, 1684352293, 1684352293, 1684352293, 211029469, 511556764, 1019008844, 1200700400, 3941375046, 2072622169, 128131964, 2533642944, 1425027163, 955023322, 615411145, 891692157, 891692157, 2618817770, 405665744, 1321967428, 1157476766, 1568028513, 1727321701, 932744458, 1826515475, 1901364189, 2913567590, 1901364189, 2385731960, 3217548714, 3450301753, 2699055425, 1014186201, 196587201, 758378509, 3998285289, 4126610937, 4022640397, 1892785117, 2264509913, 2586875573, 2638644973, 4011894809, 1104482629, 886382853 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        win.SetLastError(1234);
        const out = run();
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("physics mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
    }
    for (0..7) |i| {
        mode = @intCast(100 + i);
        setup();
        check(@src(), s.physics_input_begin(frame, 1) != 0);
        e.physics_effect_birth(pool);
        const sequence = frame.sequence;
        const event = frame.physics_choice_count;
        var ordering_source: [2]u32 = @splat(0);
        check(@src(), e.physics_effect_ordering_source(body, &ordering_source) == 1 and
            std.meta.eql(ordering_source, [2]u32{ sequence, event }));
        check(@src(), e.physics_effect_body_resolve(sequence, event) == body);
        switch (i) {
            0 => check(@src(), e.physics_effect_body_resolve(sequence, event + 1) == 0),
            1 => current.cohort.release += 1,
            2 => put(pool + 0x15c, 0),
            3 => put(pool + 0x164, resource + 4),
            4 => put(receiver + 0x1a0, body + 4),
            5 => put(pool + 0x1f8, receiver + 4),
            6 => frame.epoch += 1,
            else => unreachable,
        }
        if (i != 0) {
            check(@src(), e.physics_effect_ordering_source(body, &ordering_source) == 0);
            check(@src(), e.physics_effect_body_resolve(sequence, event) == 0);
        }
    }
    mode = 107;
    setup();
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    e.physics_effect_birth(pool);
    const original_key = [2]u32{ frame.sequence, frame.physics_choice_count };
    @memcpy(bytes(pool + 0x228, 0x228), bytes(pool, 0x228));
    e.physics_effect_birth(pool + 0x228);
    check(@src(), frame.physics_choice_count == 2);
    var ambiguous_source: [2]u32 = @splat(0);
    check(@src(), e.physics_effect_ordering_source(body, &ambiguous_source) == 0 and
        std.meta.eql(ambiguous_source, [2]u32{ 0, 0 }) and fault == 0);
    put(pool + 0x228 + 0x15c, 0);
    check(@src(), e.physics_effect_ordering_source(body, &ambiguous_source) == 1 and
        std.meta.eql(ambiguous_source, original_key));
    for (0..5) |mutation| {
        mode = 200 + @as(u32, @intCast(mutation));
        setup();
        e.clonewars_effect_lifetime_debug = @splat(0);
        check(@src(), s.physics_input_begin(frame, 1) != 0);
        win.store(f32, pool + 0xf8, 0.4);
        win.store(f32, pool + 0x100, 2.5);
        win.store(f32, pool + 0x104, 2.5);
        e.physics_effect_birth(pool);
        client();
        win.store(f32, pool + 0xf8, 0.2);
        win.store(f32, pool + 0x100, 1.9);
        win.store(f32, pool + 0x104, 1.9);
        switch (mutation) {
            1 => frame.physics_choices[0].payload.basic.recipe[0] = @bitCast(std.math.nan(f32)),
            2 => cancelled = true,
            3 => win.store(f32, pool + 0x100, std.math.nan(f32)),
            4 => frame.physics_choices[0].payload.basic.name_hash[0] +%= 1,
            else => {},
        }
        win.SetLastError(1234);
        e.physics_effect_birth(pool);
        check(@src(), win.GetLastError() == 1234);
        if (mutation == 0) {
            check(@src(), win.load(f32, pool + 0xf8) == 0.4 and win.load(f32, pool + 0x100) == 2.5 and win.load(f32, pool + 0x104) == 2.5);
            check(@src(), e.clonewars_effect_lifetime_debug[0] == 1 and s.physics_input_finish() != 0);
        } else {
            check(@src(), win.load(f32, pool + 0xf8) == 0.2 and win.load(f32, pool + 0x104) == 1.9 and e.clonewars_effect_lifetime_debug[0] == 0);
            check(@src(), s.physics_input_finish() == 0);
        }
        s.physics_input_cancel();
    }
    mode = 108;
    setup();
    const native_frame = [4]usize{ 0, 0x54ef4d, 0, descriptor };
    put(descriptor + 4, 0x1d76ce00);
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    _ = e.physics_apply_breakup_launch(descriptor, handle, @intFromPtr(matrix), @intFromPtr(scale), 0, @intFromPtr(&native_frame));
    check(@src(), frame.physics_choice_count == 3 and frame.physics_choices[0].site == 0x54ef4d);
    client();
    put(descriptor + 4, 0x1da3ee00);
    _ = e.physics_apply_breakup_launch(descriptor, handle, @intFromPtr(matrix), @intFromPtr(scale), 0, @intFromPtr(&native_frame));
    check(@src(), s.physics_input_finish() != 0 and win.load(u32, descriptor + 4) == 0x1da3ee00);
    s.physics_input_cancel();
    setup();
    put(0xfb8438, 79);
    put(pool + 0x11c, 0x40000091);
    put(pool + 0x198, 0x904e80);
    const eviction_probe: usize = 0x700020;
    @memcpy(bytes(eviction_probe, 9), &[_]u8{ 0x8b, 0x44, 0x24, 4, 0xe9, 0, 0, 0, 0 });
    put(eviction_probe + 5, 0x742051 - (eviction_probe + 9));
    @memcpy(bytes(0x74205d, 6), &[_]u8{ 0xb8, 1, 0, 0, 0, 0xc3 });
    @memcpy(bytes(0x742064, 3), &[_]u8{ 0x31, 0xc0, 0xc3 });
    const evictionCandidate: *const fn (usize) callconv(.c) u32 = @ptrFromInt(eviction_probe);
    check(@src(), evictionCandidate(pool) == 1);
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    check(@src(), evictionCandidate(pool) == 0);
    put(pool + 0x198, 0);
    check(@src(), evictionCandidate(pool) == 1);
    put(pool + 0x198, 0x904e80);
    put(0xfb8438, 12);
    check(@src(), evictionCandidate(pool) == 1);
    put(pool + 0x11c, 0x200);
    check(@src(), evictionCandidate(pool) == 0);
    s.physics_input_cancel();
    effectRestTests();
    geonosisBreakupTests();
}

fn geonosisBreakup() c_int {
    const native_frame = [5]usize{ 0, 0x54ef4d, 0, descriptor, 0 };
    return e.physics_apply_breakup_launch(descriptor, handle, @intFromPtr(matrix), @intFromPtr(scale), 0, @intFromPtr(&native_frame));
}
fn prepareGeonosisDebris(index: usize, mesh_name: *const [8]u8) void {
    const runtime = resource + 0x780;
    const mesh = body + index * 0xe0;
    @memcpy(bytes(name, mesh_name.len), mesh_name);
    put(handle, resource);
    put(handle + 4, mesh);
    put(resource + 0x6f8, runtime);
    put(runtime + 0x68, 17);
    put(runtime + 0x6c, body);
    put(mesh + 0xb4, name);
    put(descriptor, 1);
    win.store(u8, descriptor + 0x2d, 1);
}
fn geonosisBreakupTests() void {
    mode = 313;
    setup();
    frame.level = 79;
    prepareGeonosisDebris(12, "tt41_31\x00");
    e.clonewars_geonosis_breakup_suppressed = @splat(0);
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    client();
    win.SetLastError(1234);
    check(@src(), geonosisBreakup() == 1);
    prepareGeonosisDebris(11, "tt41_32\x00");
    check(@src(), geonosisBreakup() == 1 and fault == 0 and s.cursor == 0 and s.physics_input_finish() != 0);
    check(@src(), win.GetLastError() == 1234 and e.clonewars_geonosis_breakup_suppressed[3] == 2);
    s.physics_input_cancel();

    check(@src(), s.physics_input_begin(frame, 1) != 0);
    check(@src(), geonosisBreakup() == 0 and frame.physics_choice_count == 3);
    client();
    check(@src(), geonosisBreakup() == 0 and fault == 0 and s.physics_input_finish() != 0);
    s.physics_input_cancel();

    for (0..4) |variant| {
        setup();
        frame.level = if (variant == 1) 78 else 79;
        prepareGeonosisDebris(if (variant == 3) 10 else 11, if (variant == 2) "fixture\x00" else "tt41_32\x00");
        check(@src(), s.physics_input_begin(frame, 1) != 0);
        if (variant == 0) {
            win.SetLastError(1234);
            check(@src(), geonosisBreakup() == 0 and frame.physics_choice_count == 3);
            const choices = frame.physics_choices[0..3].*;
            frame.physics_choices[1..4].* = choices;
            frame.physics_choices[0] = sourceChoice(0);
            frame.physics_choice_count = 4;
        }
        client();
        win.SetLastError(1234);
        check(@src(), geonosisBreakup() == 0 and fault == 15 and s.physics_input_finish() == 0);
        check(@src(), e.clonewars_geonosis_breakup_suppressed[3] == 2);
        s.physics_input_cancel();
    }
}

fn effectRestTests() void {
    const update: *const fn (f32) callconv(.c) void = @ptrFromInt(0x743bb0);
    mode = 299;
    setup();
    check(@src(), s.physics_input_begin(frame, 1) != 0);
    win.SetLastError(1234);
    update(0.075);
    check(@src(), native_calls == 1 and update_delta == 0.075 and win.GetLastError() == 321);
    client();
    win.SetLastError(1234);
    update(0.05);
    check(@src(), native_calls == 2 and update_delta == 0.075 and win.GetLastError() == 321 and s.physics_input_finish() != 0);
    s.physics_input_cancel();
    win.SetLastError(1234);
    update(0.02);
    check(@src(), native_calls == 3 and update_delta == 0.02 and win.GetLastError() == 321);
    for (0..12) |mutation| {
        mode = 300 + @as(u32, @intCast(mutation));
        setup();
        check(@src(), s.physics_input_begin(frame, 1) != 0);
        e.physics_effect_birth(pool);
        const host_delta = e.effectStep(0.075);
        const host_mask = e.physics_effect_rest(pool, 0x40);
        check(@src(), host_delta == 0.075 and host_mask == 0x40 and frame.physics_choice_count == 3);
        client();
        e.physics_effect_birth(pool);
        switch (mutation) {
            1 => frame.physics_choices[1].payload.basic.recipe[0] = @bitCast(std.math.nan(f32)),
            2 => frame.physics_choices[2].payload.basic.name_hash[1] += 1,
            3 => frame.physics_choices[2].payload.basic.recipe[0] = 2,
            4 => frame.physics_choices[2].payload.basic.recipe[1] = 0x904e80,
            5 => put(pool + 0x164, resource + 4),
            6 => put(receiver + 0x1a0, body + 4),
            7 => put(pool + 0x1f8, receiver + 4),
            8 => put(pool + 0x15c, 3),
            9 => cancelled = true,
            10 => frame.physics_choices[1].payload.basic.recipe[0] = @bitCast(@as(f32, -0.01)),
            11 => frame.physics_choices[2].payload.basic.recipe[2] = 1,
            else => {},
        }
        const before = win.load([0x228]u8, pool);
        win.SetLastError(1234);
        const delta = e.effectStep(0.05);
        const mask = e.physics_effect_rest(pool, 0);
        check(@src(), win.GetLastError() == 1234 and std.mem.eql(u8, &before, bytes(pool, 0x228)));
        if (mutation == 0) {
            check(@src(), delta == 0.075 and mask == 0x40 and s.physics_input_finish() != 0);
        } else {
            check(@src(), mask == 0 and s.physics_input_finish() == 0);
        }
        s.physics_input_cancel();
    }
    e.effect_rest_resume = @intFromPtr(&effect_rest_exit);
    e.effect_moving_resume = @intFromPtr(&effect_moving_exit);
    for (0..2000) |i| {
        mode = 400;
        setup();
        check(@src(), s.physics_input_begin(frame, 1) != 0);
        e.physics_effect_birth(pool);
        const host_mask: u32 = if (i % 2 == 0) 0 else 0x40;
        check(@src(), e.physics_effect_rest(pool, host_mask) == host_mask);
        client();
        e.physics_effect_birth(pool);
        probe.argument = 0x12340078 | (if (i % 3 == 0) @as(u32, 0x4100) else 0);
        expected_rest_mask = host_mask;
        probe.entry = @intFromPtr(&effect_rest_native_exit);
        probe.invoke_thunk();
        const fx = probe.observed_fx;
        const regs = probe.observed_regs;
        const branch = probe.branch;
        probe.entry = @intFromPtr(&physics_effect_rest_thunk);
        win.SetLastError(1234);
        probe.invoke_thunk();
        check(@src(), win.GetLastError() == 1234 and probe.branch == branch and s.physics_input_finish() != 0);
        probe.expectSame(@src(), &fx, &regs);
        s.physics_input_cancel();
    }
}
