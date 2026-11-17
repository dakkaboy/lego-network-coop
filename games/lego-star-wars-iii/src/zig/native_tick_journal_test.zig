const std = @import("std");
const f = @import("tick_journal_fixture.zig");
const p = f.p;
const win = f.win;
const check = f.check;
const input = f.input;
const state = f.state;
const clock = f.clock;
const world = f.world;
const actor = f.actor;
const pack = f.pack;
const pose = f.pose;
const sites = f.sites;
const frame = f.frame;
const begin = f.begin;
const next = f.next;
const finish = f.finish;
const stream = f.stream;
const put = f.put;
const addr = f.addr;
const word = f.word;
const shortPut = f.shortPut;
const copy = f.copy;
const equal = f.equal;
const buffer = f.buffer;
const probe = @import("native_probe_fixture.zig");
pub export var pack_probe_member: usize = 0;
pub const probe_registers =
    \\movl _pack_probe_member,%esi
    \\movl $1,12(%esp)
;
extern fn native_pack_mode_input() void;
extern fn pack_mode_native_exit() void;
extern fn pack_mode_success_exit() void;
extern fn pack_mode_abort_exit() void;
comptime {
    asm (
        \\.text
        \\_pack_mode_native_exit:
        \\movl _projected,%eax
        \\cmpl $0x1d,%eax
        \\_pack_mode_success_exit:
        \\movl $1,_branch
        \\ret
        \\_pack_mode_abort_exit:
        \\movl $2,_branch
        \\ret
    );
}
fn decisions() void {
    begin(true);
    check(@src(), state.native_tick_decision(0x888889, 0) == 0 and state.native_tick_decision(0x8888cd, 1) == 1 and finish());
    check(@src(), frame.tick_gate_count == 2 and frame.tick_gates[0].site == 0x888889);
    begin(false);
    win.SetLastError(123);
    check(@src(), state.native_tick_decision(0x888889, 1) == 0 and win.GetLastError() == 123);
    check(@src(), state.native_tick_decision(0x8888cd, 0) == 1 and finish() and f.faults == 0);
    check(@src(), state.clonewars_native_tick_correction[2] == 0x888889 and state.clonewars_native_tick_correction[4] == 1 and state.clonewars_native_tick_correction[5] == 0);
    begin(false);
    _ = state.native_tick_decision(0x8888cd, 0);
    check(@src(), f.faults == 1 and !finish() and state.clonewars_native_tick_failure[3] == 2);
    frame.epoch += 1;
    f.bound.epoch += 1;
    begin(false);
    put(0xfb4b6c, 0, 101);
    _ = state.native_tick_decision(0x888889, 1);
    check(@src(), f.faults == 2 and !finish());
    put(0xfb4b6c, 0, 100);
    frame.epoch += 1;
    f.bound.epoch += 1;
    begin(false);
    check(@src(), !finish() and f.faults == 3 and state.clonewars_native_tick_failure[3] == 3);
    next(true);
    frame.tick_gate_count = p.SYNC_MAX_TICK_GATES;
    _ = state.native_tick_decision(0x888889, 1);
    check(@src(), f.faults == 4 and !finish() and state.clonewars_native_tick_failure[3] == 1);
    begin(false);
    f.alive = false;
    check(@src(), state.native_tick_decision(0x888889, 1) == 1 and f.faults == 4 and !finish());
    f.alive = true;
    f.cancel();
    check(@src(), state.native_tick_decision(0x888889, 1) == 1 and f.faults == 4);
    const root = buffer(0x1c00);
    const flow = root[0x1b44..];
    put(0xfb2e60, 0, root);
    put(flow, 0x34, 14);
    next(true);
    put(flow, 0x60, 11);
    world.native_flow_request(addr(flow));
    check(@src(), finish() and frame.tick_gate_count == 1 and frame.tick_gates[0].site == 0x889edc);
    begin(false);
    put(flow, 0x60, 0xffffffff);
    win.SetLastError(456);
    world.native_flow_request(addr(flow));
    check(@src(), word(flow, 0x60) == 11 and word(flow, 0x34) == 14 and win.GetLastError() == 456 and finish());
    next(true);
    put(flow, 0x60, 0xffffffff);
    world.native_flow_request(addr(flow));
    check(@src(), finish());
    begin(false);
    put(flow, 0x60, 11);
    world.native_flow_request(addr(flow));
    check(@src(), word(flow, 0x60) == 0xffffffff and word(flow, 0x34) == 14 and finish());
    next(true);
    put(flow, 0x60, 11);
    world.native_flow_request(addr(root));
    check(@src(), !finish() and f.faults == 5 and word(flow, 0x60) == 11);
    f.cancel();
    world.native_flow_request(0);
    const witness = [_]u32{ 0x12345678, 0x87654321 };
    next(true);
    check(@src(), clock.native_tick_clock_input(&witness, 0x3c23d70a) == 0x3c23d70a and frame.tick_gate_count == 3 and stream(0, 3) and finish());
    begin(false);
    check(@src(), clock.native_tick_clock_input(&witness, 0x3ca40698) == 0x3c23d70a and finish());
    for (0..6) |mutation| {
        next(true);
        _ = clock.native_tick_clock_input(&witness, 0x3c23d70a);
        check(@src(), finish());
        switch (mutation) {
            0 => frame.tick_gates[0].value += 1,
            1 => frame.tick_gates[1].value += 1,
            2 => frame.tick_gates[2].value = 0x7fc00000,
            3 => frame.tick_gates[2].clock += 1,
            4 => frame.tick_gate_count = 2,
            5 => frame.tick_gates[1].site = 0x7b8b08,
            else => unreachable,
        }
        const old = f.faults;
        begin(false);
        check(@src(), clock.native_tick_clock_input(&witness, 0x3ca40698) == 0x3ca40698 and f.faults == old + 1 and !finish());
    }
    for ([_]u32{ 0, 0x80000000, 0xbf800000, 0x7f7fffff, 0xbf000000, 0xc0000000 }) |sample| check(@src(), clock.finite(sample));
    for ([_]u32{ 0x7f800000, 0xff800000, 0x7fc00000 }) |sample| check(@src(), !clock.finite(sample));
    next(true);
    frame.tick_gate_count = p.SYNC_MAX_TICK_GATES - 2;
    const full = f.faults;
    _ = clock.native_tick_clock_input(&witness, 0x3c23d70a);
    check(@src(), f.faults == full + 1 and frame.tick_gate_count == p.SYNC_MAX_TICK_GATES - 2 and !finish());
}
fn initWorld() []u8 {
    const value = buffer(0x224);
    const definition = buffer(0x96);
    shortPut(definition, 0x94, 6);
    put(value, 0x220, definition);
    put(0xfb4a20, 0, value);
    return value;
}
fn invokeTrack(track: usize, sample: u32) u32 {
    f.getter_sample = sample;
    const calls = f.getter_calls;
    var before: u16 = 0;
    var after: u16 = 0;
    var mx0: u32 = 0;
    var mx1: u32 = 0;
    asm volatile ("fnstcw (%[cw]); stmxcsr (%[mx])"
        :
        : [cw] "r" (&before),
          [mx] "r" (&mx0),
        : .{ .memory = true });
    win.SetLastError(789);
    const value = clock.native_track_clock(track);
    check(@src(), win.GetLastError() == 789 and f.getter_calls == calls + 1);
    asm volatile ("fnstcw (%[cw]); stmxcsr (%[mx])"
        :
        : [cw] "r" (&after),
          [mx] "r" (&mx1),
        : .{ .memory = true });
    check(@src(), before == after and mx0 & ~@as(u32, 63) == mx1 & ~@as(u32, 63));
    return @bitCast(value);
}
fn tracks() void {
    const value = initWorld();
    const definition = win.load(usize, addr(value) + 0x220);
    const manager = buffer(0x90);
    const instance = buffer(0x14);
    const request = buffer(0x18);
    const provider = buffer(12);
    const first = buffer(0xc0);
    const second = buffer(0xc0);
    const tracks_list = buffer(0x34);
    const track = buffer(12);
    const components = buffer(0x24);
    const handle = buffer(4);
    put(0xe901f4, 0, manager);
    put(0xfa1c98, 0, tracks_list);
    put(manager, 0x28, first);
    put(manager, 0x30, 2);
    put(first, 4, second);
    put(manager, 0x84, second);
    put(manager, 0x88, instance);
    put(instance, 0xc, request);
    put(request, 8, second);
    put(request, 0x14, provider);
    put(provider, 0, first);
    put(tracks_list, 0x28, track);
    put(first, 0xa0, components);
    put(second, 0xa0, components);
    put(components, 0x20, handle);
    put(track, 4, handle);
    put(first, 8, "SceneA");
    put(second, 8, "SceneB");
    for ([_][]u8{ first, second }) |descriptor| {
        put(descriptor, 0xc, "Mission");
        shortPut(descriptor, 0x10, 6);
    }
    shortPut(second, 0x16, 1);
    var stub = [_]u8{ 0xff, 0x05, 0, 0, 0, 0, 0xd9, 0x05, 0, 0, 0, 0, 0xc3 };
    put(&stub, 2, &f.getter_calls);
    put(&stub, 8, &f.getter_sample);
    f.patch(0x6c11d0, &stub);
    next(true);
    const initial = f.faults;
    check(@src(), invokeTrack(addr(track), 0x3c23d70a) == 0x3c23d70a and finish() and f.faults == initial);
    const a = frame.tick_gates[0].value;
    const b = frame.tick_gates[1].value;
    begin(false);
    check(@src(), invokeTrack(addr(track), 0x3ca40698) == 0x3c23d70a and finish() and f.faults == initial);
    put(provider, 0, second);
    begin(false);
    check(@src(), invokeTrack(addr(track), 0x3ca40698) == 0x3ca40698 and !finish() and f.faults == initial + 1);
    put(provider, 0, first);
    next(true);
    put(track, 4, 0);
    const wrong_track = f.faults;
    _ = invokeTrack(addr(track), 0x3c23d70a);
    check(@src(), f.faults == wrong_track + 1 and !finish());
    put(track, 4, handle);
    next(true);
    put(first, 4, first);
    const cyclic = f.faults;
    _ = invokeTrack(addr(track), 0x3c23d70a);
    check(@src(), f.faults == cyclic + 1 and !finish());
    put(first, 4, second);
    next(true);
    shortPut(definition, 0x94, 7);
    const wrong_world = f.faults;
    _ = invokeTrack(addr(track), 0x3c23d70a);
    check(@src(), f.faults == wrong_world + 1 and !finish());
    shortPut(definition, 0x94, 6);
    next(true);
    check(@src(), invokeTrack(addr(track), 0xbf800000) == 0xbf800000 and finish() and frame.tick_gates[0].value == a and frame.tick_gates[1].value == b);
    win.store(f32, 0xad76dc, -1);
    next(true);
    check(@src(), invokeTrack(addr(track), 0x42308f61) == 0x42308f61 and finish());
    put(tracks_list, 0x28, 0);
    begin(false);
    const before_missing = f.getter_calls;
    win.SetLastError(789);
    check(@src(), clock.native_track_clock(0) > 44 and win.GetLastError() == 789 and f.getter_calls == before_missing and finish());
    next(true);
    check(@src(), clock.native_track_clock(0) == -1 and finish());
    put(tracks_list, 0x28, track);
    begin(false);
    check(@src(), invokeTrack(addr(track), 0x42308f61) == 0xbf800000 and finish());
    const wrong_lookup = f.faults;
    begin(false);
    check(@src(), clock.native_track_clock(0) == -1 and !finish() and f.faults == wrong_lookup + 1);
    f.cancel();
    const offline = f.faults;
    check(@src(), invokeTrack(addr(track), 0x3ca40698) == 0x3ca40698 and f.faults == offline);
    next(true);
    put(0xfbea24, 0, 17);
    check(@src(), world.native_perception_sweep(0) == 0 and finish() and frame.tick_gate_count == 1 and frame.tick_gates[0].site == 0x9dda14 and frame.tick_gates[0].value == 34);
    begin(false);
    put(0xfbea24, 0, 0);
    win.SetLastError(456);
    check(@src(), world.native_perception_sweep(1) == 0 and word(0xfbea24, 0) == 17 and win.GetLastError() == 456 and finish());
    next(true);
    check(@src(), world.native_perception_sweep(1) != 0 and finish());
    begin(false);
    put(0xfbea24, 0, 11);
    check(@src(), world.native_perception_sweep(0) != 0 and word(0xfbea24, 0) == 11 and finish());
    next(true);
    put(0xfbea24, 0, p.SYNC_MAX_ACTORS + 1);
    const invalid = f.faults;
    check(@src(), world.native_perception_sweep(0) == 0 and !finish() and f.faults == invalid + 1);
    f.cancel();
    check(@src(), world.native_perception_sweep(1) != 0 and word(0xfbea24, 0) == p.SYNC_MAX_ACTORS + 1);
    const actor_manager = buffer(0x220);
    @memset(actor_manager, 0x5a);
    put(actor_manager, 0, 0xc4f730);
    put(actor_manager, 8, handle);
    put(0xfb2f60, 0, handle);
    var resets: u32 = 0;
    var reset_stub = [_]u8{ 0xff, 0x05, 0, 0, 0, 0, 0xc3 };
    put(&reset_stub, 2, &resets);
    f.patch(0x8a6560, &reset_stub);
    world.reset_native_visibility_cache(addr(actor_manager));
    check(@src(), resets == 1 and actor_manager[0x10] == 0x5a and actor_manager[0x214] == 0x5a);
    f.lan_state = 3;
    win.SetLastError(321);
    world.reset_native_visibility_cache(addr(actor_manager));
    check(@src(), resets == 2 and win.GetLastError() == 321);
    for (actor_manager[0x10..0x218]) |byte| check(@src(), byte == 0);
    check(@src(), actor_manager[0xf] == 0x5a and actor_manager[0x218] == 0x5a);
}
extern fn native_fire_visibility_input(usize) callconv(.{ .x86_thiscall = .{} }) u32;
fn rts() void {
    const value = initWorld();
    const registry = buffer(4);
    const battlefield = buffer(0x10d4);
    const resource = buffer(0x10);
    put(registry, 0, battlefield);
    put(battlefield, 0, 0xaef0fc);
    put(battlefield, 0xbc, registry);
    put(battlefield, 0x10d0, resource);
    put(resource, 0xc, value);
    next(true);
    put(0xe637b4, 0, 0xabcd);
    put(0xea178c, 0, 0x91234567);
    world.native_rts_registry_rng(addr(registry));
    check(@src(), finish() and frame.tick_gate_count == 2 and stream(0, 2) and !stream(0, 1) and !stream(1, 1));
    begin(false);
    put(0xe637b4, 0, 1);
    put(0xea178c, 0, 2);
    win.SetLastError(654);
    world.native_rts_registry_rng(addr(registry));
    check(@src(), win.GetLastError() == 654 and word(0xe637b4, 0) == 0xabcd and word(0xea178c, 0) == 0x91234567 and finish());
    begin(false);
    put(0xe637b4, 0, 1);
    put(0xea178c, 0, 2);
    put(battlefield, 0xbc, 0);
    const wrong = f.faults;
    world.native_rts_registry_rng(addr(registry));
    check(@src(), !finish() and f.faults == wrong + 1 and word(0xe637b4, 0) == 1 and word(0xea178c, 0) == 2);
    put(battlefield, 0xbc, registry);
    next(true);
    put(0xe637b4, 0, 3);
    put(0xea178c, 0, 4);
    world.native_rts_producer_rng(addr(battlefield));
    put(0xe637b4, 0, 5);
    put(0xea178c, 0, 6);
    world.native_rts_registry_rng(addr(registry));
    check(@src(), finish() and stream(0, 4));
    begin(false);
    put(0xe637b4, 0, 1);
    put(0xea178c, 0, 2);
    world.native_rts_producer_rng(addr(battlefield));
    check(@src(), word(0xe637b4, 0) == 3 and word(0xea178c, 0) == 4);
    world.native_rts_registry_rng(addr(registry));
    check(@src(), word(0xe637b4, 0) == 5 and word(0xea178c, 0) == 6 and finish());
    const producer = buffer(0x258);
    put(producer, 0x28, battlefield);
    put(producer, 0x250, 3);
    put(producer, 0x254, 1);
    next(true);
    check(@src(), world.native_rts_pack_admission(addr(producer), 0, 1, 0) != 0 and finish() and frame.tick_gate_count == 1 and frame.tick_gates[0].value == 23 and stream(0, 1));
    begin(false);
    check(@src(), world.native_rts_pack_admission(addr(producer), 1, 1, 0) != 0 and finish());
    next(true);
    check(@src(), world.native_rts_pack_admission(addr(producer), 0, 1, 1) == 0 and finish());
    begin(false);
    check(@src(), world.native_rts_pack_admission(addr(producer), 0, 1, 0) == 0 and finish());
    begin(false);
    put(producer, 0x250, 4);
    const wrong_producer = f.faults;
    check(@src(), world.native_rts_pack_admission(addr(producer), 0, 1, 0) != 0 and !finish() and f.faults == wrong_producer + 1);
    const turret = buffer(0x900);
    const pilot = buffer(0x10);
    f.turret_pilot = addr(pilot);
    next(true);
    check(@src(), actor.native_fire_visibility(f.turret_pilot, 0xabcd0000) == 0xabcd0000 and finish() and frame.tick_gate_count == 2 and stream(0, 2) and !stream(0, 1) and !stream(1, 1));
    begin(false);
    win.SetLastError(543);
    check(@src(), actor.native_fire_visibility(f.turret_pilot, 0x12340001) == 0x12340000 and win.GetLastError() == 543 and finish());
    f.turret_pilot_generation += 1;
    begin(false);
    const stale_visibility = f.faults;
    check(@src(), actor.native_fire_visibility(f.turret_pilot, 1) == 1 and !finish() and f.faults == stale_visibility + 1);
    const model = buffer(0x44);
    put(pilot, 8, model);
    model[0x42] = 5;
    next(true);
    check(@src(), native_fire_visibility_input(addr(pilot)) & 255 == 5 and finish());
    model[0x42] = 0;
    begin(false);
    check(@src(), native_fire_visibility_input(addr(pilot)) & 255 == 5 and model[0x42] == 0 and finish());
    f.cancel();
    check(@src(), native_fire_visibility_input(addr(pilot)) & 255 == 0);
    put(turret, 0x2fc, f.turret_pilot);
    put(0xfb4940, 4, f.turret_pilot);
    next(true);
    win.store(u16, addr(turret) + 0x87e, 0xd001);
    actor.native_rts_turret_aim(addr(turret));
    check(@src(), win.load(u16, addr(turret) + 0x87e) == 0xd001 and finish() and stream(0, 2));
    begin(false);
    win.store(u16, addr(turret) + 0x87e, 0xcbdb);
    win.SetLastError(456);
    actor.native_rts_turret_aim(addr(turret));
    check(@src(), win.load(u16, addr(turret) + 0x87e) == 0xd001 and win.GetLastError() == 456 and finish());
    begin(false);
    const wrong_heading = f.faults;
    _ = actor.native_rts_turret_heading(addr(turret), 0xcbdb);
    check(@src(), !finish() and f.faults == wrong_heading + 1);
    next(true);
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0x1234d001) == 0x1234d001 and finish() and frame.tick_gate_count == 2 and stream(0, 2) and !stream(0, 1) and !stream(1, 1));
    begin(false);
    win.SetLastError(567);
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0x5678cbdb) == 0x5678d001 and win.GetLastError() == 567 and finish());
    f.turret_pilot_generation += 1;
    begin(false);
    const stale_pilot = f.faults;
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0xcbdb) == 0xcbdb and !finish() and f.faults == stale_pilot + 1);
    put(0xfb4940, 4, 0);
    var look: u32 = 1000;
    const minus500: u32 = @bitCast(@as(i32, -500));
    const minus570: u32 = @bitCast(@as(i32, -570));
    for (0..7) |mutation| {
        next(true);
        look = 1000;
        win.SetLastError(741);
        check(@src(), actor.native_rts_turn_input(addr(turret), minus500, addr(&look)) == minus500 and finish() and win.GetLastError() == 741 and frame.tick_gate_count == 4 and stream(0, 4) and !stream(0, 3) and !stream(1, 3));
        switch (mutation) {
            0 => {},
            1 => frame.tick_gates[0].value += 1,
            2 => frame.tick_gates[1].value += 1,
            3 => frame.tick_gates[2].clock += 1,
            4 => frame.tick_gate_count = 3,
            5 => frame.tick_gates[3].site += 1,
            6 => frame.tick_gates[3].value = 0x80000000,
            else => unreachable,
        }
        begin(false);
        look = 1100;
        const before = f.faults;
        win.SetLastError(742);
        const actual = actor.native_rts_turn_input(addr(turret), minus570, addr(&look));
        if (mutation == 0) check(@src(), actual == minus500 and look == 1000 and finish()) else check(@src(), actual == minus570 and look == 1100 and !finish() and f.faults == before + 1);
        check(@src(), win.GetLastError() == 742);
    }
    var vtable: [0x164 / 4]u32 = @splat(0);
    vtable[0x160 / 4] = 0x12344321;
    put(turret, 0, &vtable);
    f.patch(0x546c21, "\xc3");
    next(true);
    look = 1000;
    win.SetLastError(743);
    var numeric: f.Numeric = .{};
    numeric.push();
    const turn = f.machine.invoke_turn(addr(turret), minus500, &look);
    numeric.pop();
    check(@src(), turn == minus500 and finish() and win.GetLastError() == 743);
    numeric.verify();
    const observed = f.machine.rts_turn_bridge_observed;
    check(@src(), observed[0] == addr(&vtable) and observed[1] == 0x12344321 and observed[2] == 0x1234babe and observed[3] & 0x41 == 0x41);
    begin(false);
    look = 1100;
    check(@src(), f.machine.invoke_turn(addr(turret), minus570, &look) == minus500 and look == 1000 and finish());
    const task = buffer(0x10);
    put(task, 0, 0xaddb5c);
    put(task, 0xc, f.turret_pilot);
    var desired: u16 = 16468;
    for (0..9) |mutation| {
        next(true);
        desired = 16468;
        win.SetLastError(751);
        check(@src(), actor.native_actor_turn_input(addr(task), 16382, addr(&desired)) == 16382 and desired == 16468 and finish() and win.GetLastError() == 751 and frame.tick_gate_count == 5 and stream(0, 5) and !stream(0, 4) and !stream(1, 4));
        switch (mutation) {
            0 => {},
            1 => frame.tick_gates[0].value += 1,
            2 => frame.tick_gates[1].value += 1,
            3 => frame.tick_gates[2].value += 1,
            4 => frame.tick_gates[4].clock += 1,
            5 => frame.tick_gate_count = 4,
            6 => frame.tick_gates[3].site += 1,
            7 => frame.tick_gates[3].value = 65536,
            8 => frame.tick_gates[4].value = 65536,
            else => unreachable,
        }
        begin(false);
        desired = 16497;
        const before = f.faults;
        win.SetLastError(752);
        const actual = actor.native_actor_turn_input(addr(task), 0xabcd3ffc, addr(&desired));
        if (mutation == 0) check(@src(), actual == 0xabcd3ffe and desired == 16468 and @as(i16, @bitCast(@as(u16, @truncate(actual -% desired)))) == -86 and finish()) else check(@src(), actual == 0xabcd3ffc and desired == 16497 and !finish() and f.faults == before + 1);
        check(@src(), win.GetLastError() == 752);
    }
    next(true);
    frame.tick_gate_count = p.SYNC_MAX_TICK_GATES - 4;
    const full_turn = f.faults;
    desired = 16468;
    check(@src(), actor.native_actor_turn_input(addr(task), 16382, addr(&desired)) == 16382 and desired == 16468 and !finish() and f.faults == full_turn + 1 and frame.tick_gate_count == p.SYNC_MAX_TICK_GATES - 4);
    next(true);
    const absent = f.faults;
    check(@src(), actor.native_actor_turn_input(0, 16382, addr(&desired)) == 16382 and !finish() and f.faults == absent + 1);
    f.patch(0x46b0d2, "\xc3");
    next(true);
    desired = 16468;
    win.SetLastError(753);
    numeric = .{};
    numeric.push();
    const turned = f.machine.invoke_actor_turn(addr(task), 0x11113ffe, &desired);
    numeric.pop();
    check(@src(), turned == 16382 and finish() and win.GetLastError() == 753);
    numeric.verify();
    const actor_observed = f.machine.actor_turn_bridge_observed;
    check(@src(), actor_observed[0] == 0x11113ffe and actor_observed[1] == 0x1234ffaa and actor_observed[2] == 0x87654321 and actor_observed[3] & 0xc1 == 0x81);
    begin(false);
    desired = 16497;
    check(@src(), f.machine.invoke_actor_turn(addr(task), 0xabcd3ffc, &desired) == 16382 and desired == 16468 and finish());
    f.cancel();
    check(@src(), actor.native_actor_turn_input(0, 123, 0) == 123);
    next(true);
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0xcbdb) == 0xcbdb and finish() and frame.tick_gate_count == 2);
    begin(false);
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0xd001) == 0xcbdb and finish());
    next(true);
    win.store(u16, addr(turret) + 0x87e, 0x4b6b);
    actor.native_rts_turret_aim(addr(turret));
    check(@src(), finish());
    begin(false);
    win.store(u16, addr(turret) + 0x87e, 0x4ae5);
    actor.native_rts_turret_aim(addr(turret));
    check(@src(), win.load(u16, addr(turret) + 0x87e) == 0x4b6b and finish());
    put(turret, 0x2fc, 0);
    next(true);
    check(@src(), actor.native_rts_turret_heading(addr(turret), 0xcbdb) == 0xcbdb and finish() and frame.tick_gate_count == 0);
}
const PackScene = struct {
    manager_list: []u8,
    manager: []u8,
    pack: []u8,
    definition: []u8,
    first: []u8,
    second: []u8,
    fn init() @This() {
        _ = initWorld();
        const scene: @This() = .{ .manager_list = buffer(4), .manager = buffer(0x200), .pack = buffer(0x148), .definition = buffer(0x34), .first = buffer(0xa0), .second = buffer(0xa0) };
        put(scene.manager, 0, 0xaded84);
        put(scene.manager, 0x10c, scene.manager_list);
        put(scene.manager_list, 0, scene.pack);
        put(scene.pack, 0, 0xadcef0);
        put(scene.pack, 0xb8, scene.manager);
        put(scene.pack, 0xb4, scene.definition);
        put(scene.pack, 0xa0, scene.first);
        put(scene.first, 0x7c, scene.second);
        put(scene.first, 0x68, scene.pack);
        put(scene.second, 0x68, scene.pack);
        return scene;
    }
};
const host_pose = [_]u32{ 3257444079, 1056341087, 1085206242 };
const peer_pose = [_]u32{ 3257448332, 1056341087, 1085118358 };
fn resetGoal(member: []u8, goal: []u8, peer: bool, heading_valid: bool) void {
    @memset(goal, 0xcd);
    copy(member[0x20..], if (peer) &peer_pose else &host_pose, 12);
    put(member, 0x2c, if (peer) @as(u32, 0x7fc00000) else 0xffffffff);
    member[0x63] = if (peer) 20 else 22;
    win.store(u16, addr(member) + 0x48, if (peer) 0x4321 else 15469);
    var point: [3]f32 = @bitCast(host_pose);
    point[2] += 1.999;
    if (peer) point[0] -= 0.5;
    copy(goal, &point, 12);
    put(goal, 0xc, if (peer) @as(u32, 0x7fc00000) else 0xffffffff);
    win.store(u16, addr(goal) + 0x10, if (peer) 1234 else 54321);
    goal[0x1c] = (if (peer) @as(u8, 0xb0) else 0xa0) | @as(u8, @intFromBool(heading_valid));
}
fn distance(member: []u8, goal: []const u8) f32 {
    const position = win.load([3]f32, addr(member) + 0x20);
    const target = win.load([3]f32, addr(goal));
    const x = target[0] - position[0];
    const z = target[2] - position[2];
    return x * x + z * z;
}
fn goals(scene: PackScene) void {
    var original: [0xa0]u8 = undefined;
    copy(&original, scene.first, original.len);
    const goal = buffer(0x20);
    for ([_]u32{ sites.PACK_GOAL_MOVE, sites.PACK_GOAL_ACTIVE }) |site| {
        for ([_]bool{ false, true }) |heading_valid| for (0..11) |mutation| {
            resetGoal(scene.first, goal, false, heading_valid);
            next(true);
            win.SetLastError(901);
            pose.native_pack_goal_input(addr(scene.first), addr(goal), site);
            check(@src(), finish() and win.GetLastError() == 901 and frame.tick_gate_count == 10 and stream(0, 10) and frame.tick_gates[8].value == (if (heading_valid) @as(u32, 54321) else 0));
            for (1..10) |n| check(@src(), !stream(0, n));
            check(@src(), !stream(1, 9));
            var canonical: [0x20]u8 = undefined;
            copy(&canonical, goal, goal.len);
            switch (mutation) {
                0, 10 => {},
                1 => frame.tick_gates[0].value += 1,
                2 => frame.tick_gates[9].clock += 1,
                3 => frame.tick_gates[3].site += 1,
                4 => frame.tick_gate_count = 9,
                5 => frame.tick_gates[5].value = 0x7fc00000,
                6 => frame.tick_gates[4].value = 65536,
                7 => frame.tick_gates[9].value = 16,
                8 => {
                    frame.tick_gates[9].value = 0;
                    frame.tick_gates[8].value = 7;
                },
                9 => {
                    const a = frame.tick_gates[1];
                    frame.tick_gates[1] = frame.tick_gates[2];
                    frame.tick_gates[2] = a;
                },
                else => unreachable,
            }
            resetGoal(scene.first, goal, true, heading_valid);
            var before_member: [0xa0]u8 = undefined;
            var before_goal: [0x20]u8 = undefined;
            copy(&before_member, scene.first, before_member.len);
            copy(&before_goal, goal, before_goal.len);
            check(@src(), distance(scene.first, &canonical) > 4);
            begin(false);
            const before = f.faults;
            win.SetLastError(902);
            pose.native_pack_goal_input(addr(if (mutation == 10) scene.second else scene.first), addr(goal), site);
            if (mutation == 0) {
                check(@src(), finish() and equal(scene.first[0x20..], &host_pose, 12) and distance(scene.first, goal) < 4 and equal(goal, &canonical, 12));
                check(@src(), scene.first[0x48] == @as(u8, @truncate(@as(u16, 15469))) and scene.first[0x49] == 15469 >> 8 and scene.first[0x63] == 20 and word(scene.first, 0x2c) == 0x7fc00000 and word(goal, 0xc) == 0x7fc00000);
                check(@src(), goal[0x1c] & 0xf0 == 0xb0 and goal[0x1c] & 15 == @intFromBool(heading_valid) and win.load(u16, addr(goal) + 0x10) == (if (heading_valid) @as(u16, 54321) else 1234) and equal(goal[0x14..], before_goal[0x14..], 8));
            } else check(@src(), !finish() and f.faults == before + 1 and equal(scene.first, &before_member, before_member.len) and equal(goal, &before_goal, before_goal.len));
            check(@src(), win.GetLastError() == 902);
        };
        for ([_]u32{ 1, 2, 3, 5, 6, 7 }) |field| {
            resetGoal(scene.first, goal, false, true);
            next(true);
            put(if (field < 4) scene.first else goal, if (field < 4) 0x20 + (field - 1) * 4 else (field - 5) * 4, 0x7fc00000);
            const before = f.faults;
            pose.native_pack_goal_input(addr(scene.first), addr(goal), site);
            check(@src(), !finish() and f.faults == before + 1);
        }
        resetGoal(scene.first, goal, false, true);
        next(true);
        frame.tick_gate_count = p.SYNC_MAX_TICK_GATES - 9;
        const full = f.faults;
        pose.native_pack_goal_input(addr(scene.first), addr(goal), site);
        check(@src(), !finish() and f.faults == full + 1 and frame.tick_gate_count == p.SYNC_MAX_TICK_GATES - 9);
    }
    for (0..2) |which| {
        const site = if (which != 0) sites.PACK_GOAL_ACTIVE else sites.PACK_GOAL_MOVE;
        const continuation: usize = if (which != 0) 0x45fdf3 else 0x431685;
        f.patch(continuation, "\xc3");
        const invoke: *const fn (usize, usize) callconv(.c) f32 = if (which != 0) f.machine.invoke_goal_active else f.machine.invoke_goal_move;
        resetGoal(scene.first, goal, false, true);
        next(true);
        win.SetLastError(903);
        var numeric: f.Numeric = .{};
        numeric.push();
        var result = invoke(addr(scene.first), addr(goal));
        numeric.pop();
        check(@src(), finish() and frame.tick_gates[0].site == site and result == 0 and win.GetLastError() == 903);
        numeric.verify();
        const observed = f.machine.goal_bridge_observed;
        check(@src(), observed[0] == 0x12345678 and observed[1] == 0x87654321 and observed[2] == 0xcafebabe and observed[3] & 1 != 0);
        resetGoal(scene.first, goal, true, true);
        begin(false);
        win.SetLastError(904);
        result = invoke(addr(scene.first), addr(goal));
        check(@src(), result == 0 and finish() and win.GetLastError() == 904 and distance(scene.first, goal) < 4);
    }
    resetGoal(scene.first, goal, true, true);
    f.cancel();
    var unchanged: [0x20]u8 = undefined;
    copy(&unchanged, goal, goal.len);
    pose.native_pack_goal_input(addr(scene.first), addr(goal), sites.PACK_GOAL_MOVE);
    check(@src(), equal(&unchanged, goal, goal.len));
    copy(scene.first, &original, original.len);
}
fn globalPacks(scene: PackScene) void {
    const constructor = @as([*]u8, @ptrFromInt(0x47699b))[0..3];
    const code = [_]u8{ 0x83, 0xfe, 3 };
    copy(constructor, &code, 3);
    const pool = buffer(0x24);
    put(scene.manager_list, 0, 0);
    put(scene.manager, 0x20, pool);
    put(scene.manager, 0x28, 1);
    put(pool, 8, scene.manager);
    put(scene.pack, 0xb0, pool);
    put(scene.definition, 0, 0xad7f74);
    put(scene.definition, 4, pool);
    put(scene.definition, 0x10, scene.pack);
    put(scene.definition, 0x18, 1);
    put(scene.definition, 0x1c, 10);
    put(scene.definition, 0x30, scene.manager);
    put(scene.manager, 0x184, scene.definition);
    put(scene.pack, 0x13c, 10);
    put(scene.pack, 0x140, 1);
    const global_pack = @import("global_pack.zig");
    var global: global_pack.Source = undefined;
    check(@src(), global_pack.native_global_pack_source(addr(scene.pack), &global) != 0 and global.faction == 1);
    const extra = buffer(0x24);
    put(extra, 8, scene.manager);
    put(extra, 4, pool);
    put(pool, 0, extra);
    put(scene.manager, 0x20, extra);
    put(scene.manager, 0x24, pool);
    put(scene.manager, 0x28, 2);
    check(@src(), global_pack.native_global_pack_source(addr(scene.pack), &global) != 0);
    put(pool, 0, 0);
    put(pool, 4, extra);
    put(extra, 0, pool);
    put(extra, 4, 0);
    put(scene.manager, 0x20, pool);
    put(scene.manager, 0x24, extra);
    check(@src(), global_pack.native_global_pack_source(addr(scene.pack), &global) != 0);
    put(pool, 4, 0);
    put(scene.manager, 0x24, pool);
    put(scene.manager, 0x28, 1);
    for (0..8) |mutation| {
        const manager_index = word(scene.manager, 0x184);
        const owner = word(pool, 8);
        const backlink = word(scene.definition, 0x10);
        switch (mutation) {
            0 => put(scene.manager, 0x184, 0),
            1 => put(pool, 8, 0),
            2 => put(scene.definition, 0x10, 0),
            3 => put(scene.definition, 0x18, 3),
            4 => constructor[1] = 0xff,
            5 => constructor[2] = 0,
            6 => put(scene.pack, 0x140, 0),
            7 => put(pool, 4, pool),
            else => unreachable,
        }
        check(@src(), global_pack.native_global_pack_source(addr(scene.pack), &global) == 0);
        put(scene.manager, 0x184, manager_index);
        put(pool, 8, owner);
        put(scene.definition, 0x10, backlink);
        put(scene.definition, 0x18, 1);
        copy(constructor, &code, 3);
        put(scene.pack, 0x140, 1);
        put(pool, 4, 0);
    }
    put(scene.first, 0x20, 0x3f800000);
    next(true);
    pose.native_pack_pose(addr(scene.first), sites.PACK_POSE_QUERY);
    check(@src(), finish() and frame.tick_gate_count == 5 and stream(0, 5));
    begin(false);
    put(scene.first, 0x20, 0);
    pose.native_pack_pose(addr(scene.first), sites.PACK_POSE_QUERY);
    check(@src(), finish() and word(scene.first, 0x20) == 0x3f800000);
    begin(false);
    const wrong = f.faults;
    pose.native_pack_pose(addr(scene.second), sites.PACK_POSE_QUERY);
    check(@src(), !finish() and f.faults == wrong + 1);
    scene.first[0x60] = 9;
    var entered: u8 = 0;
    put(scene.first, 0x88, 0x3f800000);
    put(scene.first, 0x8c, 0x40000000);
    next(true);
    pack.native_pack_mode(addr(scene.first), addr(&entered));
    check(@src(), finish() and frame.tick_gates[0].value == 0xfffe0000 and stream(0, 6));
    begin(false);
    put(scene.first, 0x88, 0);
    put(scene.first, 0x8c, 0);
    pack.native_pack_mode(addr(scene.first), addr(&entered));
    check(@src(), finish() and word(scene.first, 0x88) == 0x3f800000 and word(scene.first, 0x8c) == 0x40000000);
    const before_rng = state.clonewars_native_pack_mode10_rng_debug[0..3].*;
    next(true);
    put(0xea178c, 0, 0x9f29a3b1);
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_MODE10_DURATION);
    put(0xea178c, 0, 0x7d013ba7);
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_MODE10_CLIP_PHASE);
    check(@src(), finish() and frame.tick_gate_count == 4 and stream(0, 4) and frame.tick_gates[0].value == frame.tick_gates[2].value);
    begin(false);
    put(0xea178c, 0, 0x19d2d8e7);
    win.SetLastError(913);
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_MODE10_DURATION);
    check(@src(), word(0xea178c, 0) == 0x9f29a3b1 and win.GetLastError() == 913);
    put(0xea178c, 0, 0xb4cf38d9);
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_MODE10_CLIP_PHASE);
    check(@src(), word(0xea178c, 0) == 0x7d013ba7 and finish());
    for (before_rng, 0..) |count, i| check(@src(), state.clonewars_native_pack_mode10_rng_debug[i] == count + 2);
    begin(false);
    put(0xea178c, 0, 0x19d2d8e7);
    const swapped = f.faults;
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_MODE10_CLIP_PHASE);
    check(@src(), word(0xea178c, 0) == 0x19d2d8e7 and !finish() and f.faults == swapped + 1);
    put(scene.manager_list, 0, scene.pack);
    put(scene.pack, 0x13c, 0);
    put(scene.pack, 0x140, 0);
    put(scene.definition, 0x1c, 0);
}
fn packs() void {
    const scene = PackScene.init();
    const clips = buffer(80);
    put(scene.first, 0x80, clips);
    put(scene.second, 0x80, clips);
    scene.first[0x61] = 1;
    scene.first[0x62] = 9;
    scene.first[0x63] = 6;
    put(scene.first, 0x84, 0x3e000000);
    var arguments = [_]u32{ 1, 0x3d4ccccd };
    next(true);
    pose.native_pack_animation(addr(scene.first), &arguments);
    check(@src(), finish() and frame.tick_gate_count == 5 and stream(0, 5));
    for (1..5) |count| check(@src(), !stream(0, count));
    begin(false);
    scene.first[0x61] = 2;
    scene.first[0x62] = 7;
    scene.first[0x63] = 22;
    put(scene.first, 0x84, 0x3f400000);
    arguments = .{ 2, 0x3dcccccd };
    win.SetLastError(345);
    pose.native_pack_animation(addr(scene.first), &arguments);
    check(@src(), finish() and win.GetLastError() == 345 and arguments[0] == 1 and arguments[1] == 0x3d4ccccd and scene.first[0x61] == 1 and scene.first[0x62] == 9 and scene.first[0x63] == 6);
    check(@src(), word(scene.first, 0x84) == 0x3e000000 and word(scene.first, 0x10) == addr(clips[20..]));
    begin(false);
    const wrong_animation = f.faults;
    pose.native_pack_animation(addr(scene.second), &arguments);
    check(@src(), !finish() and f.faults == wrong_animation + 1);
    next(true);
    arguments[0] = 2;
    put(scene.first, 0x84, 0x7fc00000);
    pose.native_pack_animation(addr(scene.first), &arguments);
    check(@src(), finish() and frame.tick_gates[3].value == 0);
    clips[40 + 0x12] = 1;
    put(scene.first, 0x84, 0x3f000000);
    next(true);
    pose.native_pack_animation(addr(scene.first), &arguments);
    check(@src(), finish() and frame.tick_gates[3].value == 0x3f000000 and stream(0, 5));
    begin(false);
    put(scene.first, 0x84, 0x3e000000);
    pose.native_pack_animation(addr(scene.first), &arguments);
    check(@src(), finish() and word(scene.first, 0x84) == 0x3f000000);
    clips[40 + 0x12] = 0;
    for ([_]u32{ sites.PACK_POSE_QUERY, sites.PACK_POSE_COMMIT }) |site| {
        const position = [_]u32{ 0x3f800000, 0x40000000, 0x40400000 };
        copy(scene.first[0x20..], &position, 12);
        scene.first[0x48] = 0x34;
        scene.first[0x49] = 0x12;
        put(scene.first, 0x2c, 0xffffffff);
        next(true);
        pose.native_pack_pose(addr(scene.first), site);
        check(@src(), finish() and frame.tick_gate_count == 5 and stream(0, 5) and word(scene.first, 0x2c) == 0xffffffff);
        for (1..5) |count| check(@src(), !stream(0, count));
        check(@src(), !stream(1, 4));
        begin(false);
        @memset(scene.first[0x20..0x30], 0);
        scene.first[0x48] = 0;
        scene.first[0x49] = 0;
        put(scene.first, 0x2c, 0xbf800000);
        scene.first[0x4a] = 0x56;
        scene.first[0x4b] = 0x78;
        win.SetLastError(654);
        pose.native_pack_pose(addr(scene.first), site);
        check(@src(), finish() and win.GetLastError() == 654 and equal(scene.first[0x20..], &position, 12) and word(scene.first, 0x2c) == 0xbf800000 and scene.first[0x48] == 0x34 and scene.first[0x49] == 0x12 and scene.first[0x4a] == 0x56 and scene.first[0x4b] == 0x78);
        begin(false);
        const wrong_member = f.faults;
        pose.native_pack_pose(addr(scene.second), site);
        check(@src(), !finish() and f.faults == wrong_member + 1);
        begin(false);
        const wrong_site = f.faults;
        pose.native_pack_pose(addr(scene.first), if (site == sites.PACK_POSE_QUERY) sites.PACK_POSE_COMMIT else sites.PACK_POSE_QUERY);
        check(@src(), !finish() and f.faults == wrong_site + 1);
        frame.tick_gates[1].value = 0x7fc00000;
        check(@src(), !stream(0, 5));
        put(scene.first, 0x20, 0x7fc00000);
        next(true);
        const invalid = f.faults;
        pose.native_pack_pose(addr(scene.first), site);
        check(@src(), !finish() and f.faults == invalid + 1);
    }
    goals(scene);
    globalPacks(scene);
    next(true);
    check(@src(), pack.native_pack_cell_admission(addr(scene.first), 0xe0) == 0x60 and finish() and stream(0, 2) and !stream(1, 1));
    begin(false);
    const unchanged = scene.first[0x63];
    win.SetLastError(321);
    check(@src(), pack.native_pack_cell_admission(addr(scene.first), 0) == 0x60 and finish() and win.GetLastError() == 321 and scene.first[0x63] == unchanged);
    begin(false);
    const wrong_cell = f.faults;
    check(@src(), pack.native_pack_cell_admission(addr(scene.second), 0) == 0 and !finish() and f.faults == wrong_cell + 1);
    next(true);
    check(@src(), pack.native_pack_attack(addr(scene.first), 0) == 0 and pack.native_pack_attack(addr(scene.second), 2) == 2 and finish() and frame.tick_gate_count == 2 and stream(0, 2) and !stream(1, 1));
    begin(false);
    win.SetLastError(678);
    check(@src(), pack.native_pack_attack(addr(scene.first), 2) == 1 and pack.native_pack_attack(addr(scene.second), 0) == 2 and win.GetLastError() == 678 and finish());
    begin(false);
    put(scene.second, 0x6c, 1);
    const wrong_member = f.faults;
    check(@src(), pack.native_pack_attack(addr(scene.second), 0) == 0 and !finish() and f.faults == wrong_member + 1);
    next(true);
    check(@src(), pack.native_pack_attack(addr(scene.first), 1) == 1 and finish() and frame.tick_gate_count == 0);
    begin(false);
    check(@src(), pack.native_pack_attack(addr(scene.first), 2) == 1 and finish());
    next(true);
    put(0xea178c, 0, 0x8b66ea71);
    pack.native_pack_attack_seed(addr(scene.first));
    check(@src(), finish() and stream(0, 2));
    begin(false);
    put(0xea178c, 0, 0xb06c913d);
    win.SetLastError(789);
    pack.native_pack_attack_seed(addr(scene.first));
    check(@src(), word(0xea178c, 0) == 0x8b66ea71 and win.GetLastError() == 789 and finish());
    begin(false);
    put(0xea178c, 0, 0xb06c913d);
    const wrong_seed = f.faults;
    pack.native_pack_attack_seed(addr(scene.second));
    check(@src(), word(0xea178c, 0) == 0xb06c913d and !finish() and f.faults == wrong_seed + 1);
    next(true);
    put(0xea178c, 0, 0x12345678);
    pack.native_pack_rearm_seed(addr(scene.first));
    check(@src(), finish() and stream(0, 2));
    begin(false);
    put(0xea178c, 0, 0x87654321);
    pack.native_pack_rearm_seed(addr(scene.first));
    check(@src(), word(0xea178c, 0) == 0x12345678 and finish());
    begin(false);
    put(0xea178c, 0, 0x87654321);
    const wrong_draw = f.faults;
    pack.native_pack_attack_seed(addr(scene.first));
    check(@src(), word(0xea178c, 0) == 0x87654321 and !finish() and f.faults == wrong_draw + 1);
    for ([_]*const fn (usize) callconv(.c) void{ pack.native_pack_move_timer_seed, pack.native_pack_move_heading_seed, pack.native_pack_move_choice_seed }) |draw| {
        next(true);
        put(0xea178c, 0, 0x1234abcd);
        draw(addr(scene.first));
        check(@src(), finish() and stream(0, 2) and !stream(0, 1) and !stream(1, 1));
        begin(false);
        put(0xea178c, 0, 0xabcd1234);
        win.SetLastError(765);
        draw(addr(scene.first));
        check(@src(), word(0xea178c, 0) == 0x1234abcd and win.GetLastError() == 765 and finish());
        begin(false);
        put(0xea178c, 0, 0xabcd1234);
        const before = f.faults;
        draw(addr(scene.second));
        check(@src(), word(0xea178c, 0) == 0xabcd1234 and !finish() and f.faults == before + 1);
    }
    for ([_]u32{ sites.PACK_HIT_REACTION, sites.PACK_HIT_AVOIDANCE, sites.PACK_HIT_DEBRIS, sites.PACK_HIT_SHOCK, sites.PACK_HIT_HEADING, sites.PACK_IMPULSE_TIMER, sites.PACK_IMPULSE_SPEED, sites.PACK_IMPULSE_HEADING, sites.PACK_DEATH_CLIP, sites.PACK_MODE10_DURATION, sites.PACK_MODE10_CLIP_PHASE }) |site| {
        next(true);
        put(0xea178c, 0, 0x1234abcd);
        pack.native_pack_hit_seed(addr(scene.first), site);
        check(@src(), finish() and stream(0, 2) and !stream(0, 1) and !stream(1, 1));
        begin(false);
        put(0xea178c, 0, 0xabcd1234);
        win.SetLastError(765);
        pack.native_pack_hit_seed(addr(scene.first), site);
        check(@src(), word(0xea178c, 0) == 0x1234abcd and win.GetLastError() == 765 and finish());
        begin(false);
        put(0xea178c, 0, 0xabcd1234);
        const before = f.faults;
        pack.native_pack_hit_seed(addr(scene.second), site);
        check(@src(), word(0xea178c, 0) == 0xabcd1234 and !finish() and f.faults == before + 1);
        if (site == sites.PACK_HIT_DEBRIS) {
            check(@src(), state.clonewars_native_pack_seed_context[4] == addr(scene.second));
            check(@src(), state.clonewars_native_pack_seed_context[7] != state.clonewars_native_pack_seed_context[9]);
            check(@src(), state.clonewars_native_pack_seed_context[10] == site);
            check(@src(), state.clonewars_native_tick_failure_stack[0] > 0);
        }
    }
    const native_stack = buffer(36);
    put(native_stack, 0, sites.PACK_HIT_DEBRIS + 5);
    put(native_stack, 28, 0x408700);
    put(native_stack, 32, 0x12345678);
    const stack_before = win.load([36]u8, addr(native_stack));
    const member_before = win.load([0xa0]u8, addr(scene.first));
    next(true);
    win.SetLastError(765);
    pack.native_pack_hit_seed_bridge(addr(scene.first), sites.PACK_HIT_DEBRIS, addr(native_stack));
    check(@src(), win.GetLastError() == 765 and finish() and stream(0, 2));
    check(@src(), state.clonewars_native_pack_hit_caller[3] == addr(scene.first) and state.clonewars_native_pack_hit_caller[5] == 0x408700 and state.clonewars_native_pack_hit_caller[6] == 0x12345678);
    check(@src(), std.mem.eql(u8, &stack_before, native_stack) and std.mem.eql(u8, &member_before, scene.first));
    const captured_caller = state.clonewars_native_pack_hit_caller;
    pack.native_pack_hit_seed_bridge(1, sites.PACK_HIT_DEBRIS, 1);
    check(@src(), std.mem.eql(u32, &captured_caller, &state.clonewars_native_pack_hit_caller));
    const observation = @import("pack_hit_query_observer.zig");
    const event_stack = buffer(0x860);
    const event_query = buffer(0x4c);
    const event_value = buffer(12);
    const event_owner = buffer(0x1440);
    put(event_query, 0x20, 1);
    put(event_value, 0, 3);
    put(event_value, 8, event_owner);
    put(event_stack, 0, 0x45f5a2);
    put(event_stack, 12, 2);
    put(event_stack, 28, 0x7a9379);
    put(event_stack, 32, event_value);
    put(event_stack, 40, 0x408729);
    put(event_stack, 48, 0x6f097c);
    put(event_stack, 68, scene.first);
    put(event_stack, 72, scene.second);
    put(event_stack, 0x844, 0x6fc9da);
    put(event_stack, 0x848, event_query);
    put(event_stack, 0x84c, event_value);
    put(event_stack, 0x85c, 0x88abcd);
    const observation_stack = win.load([0x860]u8, addr(event_stack));
    const observation_owner = win.load([0x1440]u8, addr(event_owner));
    const observation_query = win.load([0x4c]u8, addr(event_query));
    next(true);
    win.SetLastError(765);
    pack.native_pack_hit_seed_bridge(addr(scene.first), sites.PACK_HIT_DEBRIS, addr(event_stack));
    check(@src(), win.GetLastError() == 765 and finish() and stream(0, 2));
    check(@src(), observation.clonewars_pack_hit_queries_cursor == 1);
    const observed = observation.clonewars_pack_hit_queries[0];
    check(@src(), observed[0] == frame.epoch and observed[1] == frame.sequence and observed[3] == addr(scene.first));
    check(@src(), observed[9] == 2 and observed[10] == 0 and observed[14] == 2 and observed[15] == state.clonewars_native_pack_seed_context[7]);
    check(@src(), observed[40] == addr(scene.first) and observed[52] == addr(scene.second) and observed[51] >> 8 == 1 and observed[63] >> 8 == 2);
    begin(false);
    pack.native_pack_hit_seed_bridge(addr(scene.first), sites.PACK_HIT_DEBRIS, addr(event_stack));
    check(@src(), finish() and observation.clonewars_pack_hit_queries_cursor == 2 and observation.clonewars_pack_hit_queries[1][33] == observed[15]);
    check(@src(), std.mem.eql(u8, &observation_stack, event_stack) and std.mem.eql(u8, &observation_owner, event_owner) and std.mem.eql(u8, &observation_query, event_query));
    check(@src(), std.mem.eql(u8, &member_before, scene.first));
    next(true);
    for ([_]usize{ 0, 12, 28, 32, 40, 48, 68, 0x844, 0x848, 0x84c }) |offset| {
        const original = word(event_stack, offset);
        put(event_stack, offset, 0);
        observation.observe(addr(scene.first), addr(event_stack));
        check(@src(), observation.clonewars_pack_hit_queries_cursor == 0 and frame.tick_gate_count == 0);
        put(event_stack, offset, original);
    }
    next(true);
    check(@src(), pack.native_pack_formation(addr(scene.first), 0) == 0 and finish() and stream(0, 2));
    begin(false);
    check(@src(), pack.native_pack_formation(addr(scene.first), 1) == 0 and finish());
    begin(false);
    const wrong_formation = f.faults;
    check(@src(), pack.native_pack_formation(addr(scene.second), 1) == 1 and !finish() and f.faults == wrong_formation + 1);
    next(true);
    scene.first[0x60] = 5;
    var entry: u8 = 1;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), finish() and frame.tick_gate_count == 3 and stream(0, 3) and !stream(0, 2) and !stream(1, 2));
    begin(false);
    scene.first[0x60] = 2;
    scene.first[0x63] = 0x96;
    entry = 0;
    win.SetLastError(890);
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), scene.first[0x60] == 5 and entry == 1 and win.GetLastError() == 890 and finish() and scene.first[0x63] == 0x86);
    begin(false);
    scene.second[0x60] = 2;
    entry = 0;
    const wrong_mode = f.faults;
    pack.native_pack_mode(addr(scene.second), addr(&entry));
    check(@src(), scene.second[0x60] == 2 and entry == 0 and !finish() and f.faults == wrong_mode + 1);
    next(true);
    scene.first[0x60] = 9;
    entry = 0;
    put(scene.first, 0x88, 0xbf000000);
    put(scene.first, 0x8c, 0x3f800000);
    scene.first[0x90] = 1;
    scene.first[0x91] = 0;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), finish() and frame.tick_gate_count == 6 and stream(0, 6) and !stream(0, 5) and !stream(3, 3));
    begin(false);
    put(scene.first, 0x88, 0x3e000000);
    put(scene.first, 0x8c, 0x3f000000);
    scene.first[0x90] = 0;
    scene.first[0x91] = 1;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), finish() and word(scene.first, 0x88) == 0xbf000000 and word(scene.first, 0x8c) == 0x3f800000 and scene.first[0x90] == 1 and scene.first[0x91] == 0);
    next(true);
    scene.first[0x60] = 9;
    entry = 1;
    scene.first[0x90] = 12;
    scene.first[0x91] = 255;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), finish() and stream(0, 6));
    begin(false);
    scene.first[0x90] = 0;
    scene.first[0x91] = 0;
    entry = 0;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), finish() and scene.first[0x90] == 12 and scene.first[0x91] == 255 and entry == 1);
    for (0..65536) |bits| check(@src(), @import("tick_validation.zig").gateValid(.{ .site = sites.PACK_DEATH_FLAGS, .clock = word(0xfb4b6c, 0), .value = @intCast(bits) }));
    check(@src(), !@import("tick_validation.zig").gateValid(.{ .site = sites.PACK_DEATH_FLAGS, .clock = word(0xfb4b6c, 0), .value = 0x10000 }));
    begin(false);
    put(scene.second, 0x88, 0x3e000000);
    put(scene.second, 0x8c, 0x3f000000);
    const wrong_death = f.faults;
    pack.native_pack_mode(addr(scene.second), addr(&entry));
    check(@src(), !finish() and f.faults == wrong_death + 1 and word(scene.second, 0x88) == 0x3e000000);
    begin(false);
    frame.tick_gate_count = 5;
    put(scene.first, 0x88, 0x3e000000);
    const incomplete = f.faults;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), !finish() and f.faults == incomplete + 1 and word(scene.first, 0x88) == 0x3e000000);
    next(true);
    scene.first[0x60] = 0xff;
    entry = 1;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    pack.native_pack_mode(addr(scene.second), addr(&entry));
    check(@src(), finish() and frame.tick_gate_count == 6 and stream(0, 6));
    begin(false);
    scene.first[0x60] = 5;
    entry = 0;
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), scene.first[0x60] == 0xff and entry == 1);
    pack.native_pack_mode(addr(scene.second), addr(&entry));
    check(@src(), finish());
    scene.first[0x60] = 5;
    entry = 0;
    next(true);
    put(scene.manager_list, 0, 0);
    const local_only = f.faults;
    put(0xea178c, 0, 0x9876abcd);
    pack.native_pack_hit_seed(addr(scene.first), sites.PACK_HIT_REACTION);
    check(@src(), word(0xea178c, 0) == 0x9876abcd and f.faults == local_only);
    pack.native_pack_mode(addr(scene.first), addr(&entry));
    check(@src(), scene.first[0x60] == 5 and entry == 0 and finish() and frame.tick_gate_count == 0);
    ordinalMemo();
    packFireTargets();
    packSpawnChecks();
}
fn spawnRandom(seed: *u32) f32 {
    seed.* = seed.* *% 0x19660d +% 0x3c6ef35f;
    const width: f32 = @floatCast(0.25 + 0.10000000149011612);
    const value: f32 = @floatCast(@as(f64, @floatFromInt(seed.* & 0x7fffff)) / 8388608.0 * @as(f64, width) - 0.125);
    return @min(0.125, @max(-0.125, value));
}
fn spawnPair(source: []u8, pool: []u8, stack: []u8, position: []u8) void {
    const spawn = @import("tick_pack_spawn.zig");
    var seed = word(0xea178c, 0);
    put(stack, 0, sites.PACK_SPAWN_X + 5);
    spawn.native_pack_spawn_input(addr(source), addr(pool), addr(stack), sites.PACK_SPAWN_X);
    seed = word(0xea178c, 0);
    const x = spawnRandom(&seed);
    put(0xea178c, 0, seed);
    put(stack, 0, sites.PACK_SPAWN_Z + 5);
    spawn.native_pack_spawn_input(addr(source), addr(pool), addr(stack), sites.PACK_SPAWN_Z);
    seed = word(0xea178c, 0);
    const z = spawnRandom(&seed);
    put(0xea178c, 0, seed);
    put(position, 0, @as(u32, @bitCast(win.load(f32, addr(source) + 0x60) + x)));
    put(position, 4, word(source, 0x64));
    put(position, 8, @as(u32, @bitCast(win.load(f32, addr(source) + 0x68) + z)));
    put(position, 12, @as(u32, @bitCast(@as(f32, 1))));
    put(stack, 0, sites.PACK_SPAWN_BIRTH + 5);
    put(stack, 4, word(source, 0xc8));
    put(stack, 8, position);
    put(stack, 12, 123);
    spawn.native_pack_spawn_input(addr(source), addr(pool), addr(stack), sites.PACK_SPAWN_BIRTH);
}
fn packSpawnChecks() void {
    const spawn = @import("tick_pack_spawn.zig");
    const scene = PackScene.init();
    put(scene.pack, 0xa0, 0);
    const source = buffer(0xcc);
    const pool = buffer(0x24);
    const stack = buffer(16);
    const position = buffer(16);
    put(pool, 8, scene.manager);
    const base = [_]f32{ 12.840703010559082, -0.05330193042755127, -6.237250328063965, 1, 0.25 };
    var old_seed: u32 = 1462045;
    const old_position = [_]f32{ base[0] + spawnRandom(&old_seed), base[1], base[2] + spawnRandom(&old_seed) };
    check(@src(), old_position[0] == 12.965703010559082 and old_position[2] == -6.1412858963012695);
    for (0..25) |mutation| {
        @memset(source, 0);
        for (base, 0..) |value, i| put(source, 0x60 + i * 4, @as(u32, @bitCast(value)));
        put(source, 0x80, 1);
        put(source, 0xac, scene.pack);
        put(source, 0xb0, 39);
        put(scene.pack, 0xb0, pool);
        put(pool, 8, scene.manager);
        put(stack, 4, @as(u32, @bitCast(@as(f32, -0.125))));
        put(stack, 8, @as(u32, @bitCast(@as(f32, 0.125))));
        next(true);
        put(0xea178c, 0, 5430013);
        spawnPair(source, pool, stack, position);
        const canonical = win.load([4]u32, addr(position));
        const final_seed = word(0xea178c, 0);
        check(@src(), finish() and frame.tick_gate_count == 16 and stream(0, 16));
        for (1..16) |count| check(@src(), !stream(0, count));
        check(@src(), @as(f32, @bitCast(canonical[0])) == 12.786457061767578 and @as(f32, @bitCast(canonical[2])) == -6.324928283691406);
        check(@src(), spawn.clonewars_pack_spawn_births_cursor == 1 and std.mem.eql(u32, spawn.clonewars_pack_spawn_births[0][13..17], &canonical));
        put(stack, 0, sites.PACK_SPAWN_X + 5);
        put(stack, 4, @as(u32, @bitCast(@as(f32, -0.125))));
        put(stack, 8, @as(u32, @bitCast(@as(f32, 0.125))));
        var at: u32 = sites.PACK_SPAWN_X;
        switch (mutation) {
            1...7 => frame.tick_gates[mutation - 1].value +%= 1,
            8 => frame.tick_gates[0].clock += 1,
            9 => frame.tick_gates[0].site = sites.PACK_SPAWN_Z,
            10 => frame.tick_gate_count = 7,
            11 => put(source, 0xac, 1),
            12 => put(scene.pack, 0xb0, scene.first),
            13 => put(pool, 8, 1),
            14 => put(source, 0x80, 0),
            15 => put(source, 0x60, 0x7fc00000),
            16 => put(stack, 4, 0x7fc00000),
            17 => put(stack, 4, @as(u32, @bitCast(@as(f32, 100)))),
            18 => put(stack, 0, sites.PACK_SPAWN_X + 6),
            19 => put(source, 0xb4, 1),
            20 => put(source, 0xb0, 40),
            21 => put(source, 0xc8, 1),
            24 => { at = sites.PACK_SPAWN_Z; put(stack, 0, at + 5); },
            else => {},
        }
        begin(false);
        if (mutation == 22) f.alive = false;
        if (mutation == 23) f.bound.epoch += 1;
        put(0xea178c, 0, 1462045);
        const source_before = win.load([0xcc]u8, addr(source));
        const pool_before = win.load([0x24]u8, addr(pool));
        const stack_before = win.load([16]u8, addr(stack));
        win.SetLastError(1234);
        if (mutation == 0) {
            spawnPair(source, pool, stack, position);
            check(@src(), finish() and std.mem.eql(u32, &canonical, &win.load([4]u32, addr(position))) and word(0xea178c, 0) == final_seed);
            check(@src(), spawn.clonewars_pack_spawn_debug[2] == 1 and spawn.clonewars_pack_spawn_births_cursor == 2);
        } else {
            spawn.native_pack_spawn_input(addr(source), addr(pool), addr(stack), at);
            check(@src(), !finish() and word(0xea178c, 0) == 1462045);
            check(@src(), std.mem.eql(u8, &stack_before, stack));
        }
        check(@src(), win.GetLastError() == 1234 and std.mem.eql(u8, &source_before, source) and std.mem.eql(u8, &pool_before, pool));
        f.alive = true;
        f.bound.epoch = frame.epoch;
    }
    packSpawnAbi(scene, source, pool, stack, position);
}
extern fn native_pack_spawn_rng_input() void;
extern fn native_pack_spawn_birth_input() void;
fn packSpawnAbi(scene: PackScene, source: []u8, pool: []u8, stack: []u8, position: []u8) void {
    const spawn = @import("tick_pack_spawn.zig");
    const abi = @import("pack_spawn_probe.zig");
    const original_random = spawn.pack_spawn_random;
    const original_allocate = spawn.pack_spawn_allocate;
    spawn.pack_spawn_random = @intFromPtr(&abi.pack_spawn_probe_random);
    spawn.pack_spawn_allocate = @intFromPtr(&abi.pack_spawn_probe_allocate);
    defer { spawn.pack_spawn_random = original_random; spawn.pack_spawn_allocate = original_allocate; }
    abi.original();
    abi.pack_spawn_probe_source = addr(source);
    abi.pack_spawn_probe_pool = addr(pool);
    abi.pack_spawn_probe_position = addr(position);
    const calls = [_]u32{ sites.PACK_SPAWN_X, sites.PACK_SPAWN_Z, sites.PACK_SPAWN_BIRTH };
    for (0..4) |rounding| for (0..4) |behavior| {
        put(source, 0x60, @as(u32, @bitCast(@as(f32, 12.840703010559082))));
        put(source, 0x80, 1);
        put(source, 0xac, scene.pack);
        put(source, 0xb0, 39);
        put(source, 0xb4, 0);
        put(source, 0xc8, 0);
        put(scene.pack, 0xb0, pool);
        put(pool, 8, scene.manager);
        put(stack, 4, @as(u32, @bitCast(@as(f32, -0.125))));
        put(stack, 8, @as(u32, @bitCast(@as(f32, 0.125))));
        next(true);
        put(0xea178c, 0, 5430013);
        spawnPair(source, pool, stack, position);
        check(@src(), finish() and stream(0, 16));
        f.cancel();
        abi.pack_spawn_probe_cw = 0x37f | @as(u32, @intCast(rounding)) << 10;
        abi.pack_spawn_probe_mxcsr = 0x1f80 | @as(u32, @intCast(rounding)) << 13;
        for (&abi.pack_spawn_probe_xmm, 0..) |*byte, i| byte.* = @truncate(i * 17 + rounding * 3);
        var registers: [3][9]u32 = undefined;
        var floating: [3][512]u8 = undefined;
        var seeds: [3]u32 = undefined;
        const source_before = win.load([0xcc]u8, addr(source));
        const pool_before = win.load([0x24]u8, addr(pool));
        const count_before = abi.pack_spawn_probe_calls;
        put(0xea178c, 0, if (behavior < 2) @as(u32, 5430013) else @as(u32, 1462045));
        for (calls, 0..) |at, phase| {
            const target = if (phase < 2) @intFromPtr(&abi.pack_spawn_probe_random) else @intFromPtr(&abi.pack_spawn_probe_allocate);
            put(at, 0, 0xe8);
            win.store(u8, at, 0xe8);
            put(at, 1, target -% at -% 5);
            win.store(u8, at + 5, 0xe9);
            put(at, 6, @intFromPtr(&abi.pack_spawn_probe_after) -% at -% 10);
            abi.pack_spawn_probe_site = at;
            abi.pack_spawn_probe_kind = @intFromBool(phase == 2);
            win.SetLastError(321);
            abi.pack_spawn_probe();
            registers[phase] = abi.pack_spawn_probe_regs;
            floating[phase] = abi.pack_spawn_probe_fx;
            seeds[phase] = word(0xea178c, 0);
            check(@src(), win.GetLastError() == 321);
        }
        if (behavior != 2) begin(behavior == 0);
        if (behavior == 3) frame.tick_gates[0].value += 1;
        put(0xea178c, 0, if (behavior == 0) @as(u32, 5430013) else @as(u32, 1462045));
        for (calls, 0..) |at, phase| {
            const target = if (phase < 2) @intFromPtr(&native_pack_spawn_rng_input) else @intFromPtr(&native_pack_spawn_birth_input);
            put(at, 1, target -% at -% 5);
            abi.pack_spawn_probe_site = at;
            abi.pack_spawn_probe_kind = @intFromBool(phase == 2);
            win.SetLastError(321);
            abi.pack_spawn_probe();
            check(@src(), win.GetLastError() == 321 and word(0xea178c, 0) == seeds[phase]);
            if (!std.mem.eql(u32, &registers[phase], &abi.pack_spawn_probe_regs) or !std.mem.eql(u8, &floating[phase], &abi.pack_spawn_probe_fx))
                std.debug.print("spawn ABI rounding={d} behavior={d} phase={d}\n", .{ rounding, behavior, phase });
            check(@src(), std.mem.eql(u32, &registers[phase], &abi.pack_spawn_probe_regs) and std.mem.eql(u8, &floating[phase], &abi.pack_spawn_probe_fx));
        }
        check(@src(), abi.pack_spawn_probe_calls == count_before + 6);
        check(@src(), std.mem.eql(u8, &source_before, source) and std.mem.eql(u8, &pool_before, pool));
        if (behavior != 2) check(@src(), finish() == (behavior != 3));
    };
}
fn packFireTargets() void {
    const scene = PackScene.init();
    const target = buffer(0x1440);
    @memset(target, 0xa5);
    f.turret_pilot = addr(target);
    defer f.turret_pilot = 0;
    const timers = [_]u32{ 0x3e4ccccd, 0x3f000000, 0x3fc00000, 0x3f400000 };
    const previous_pool = win.load(u32, 0xfb2f60);
    const previous_count = win.load(u32, 0xfb2e3c);
    defer {
        win.store(u32, 0xfb2f60, previous_pool);
        win.store(u32, 0xfb2e3c, previous_count);
    }
    put(0xfb2f60, 0, addr(target));
    put(0xfb2e3c, 0, 1);
    for (0..20) |mutation| {
        f.turret_pilot_generation = 17;
        f.pack_target_mutation = 0;
        f.retained_target_bound = false;
        put(target, 0x50, if (mutation == 14) @as(u32, 0x8001) else 3);
        shortPut(target, 0xdc0, 183);
        next(true);
        scene.first[0x60] = 18;
        scene.first[0x63] = 0x10;
        put(scene.first, 0x88, if (mutation == 1) 0 else addr(target));
        copy(scene.first[0x8c..], &timers, 16);
        scene.first[0x9c] = 0xa5;
        var entry: u8 = 0;
        pack.native_pack_mode(addr(scene.first), addr(&entry));
        check(@src(), finish() and frame.tick_gate_count == 14 and stream(0, 14) and !stream(3, 11));
        for (0..14) |length| check(@src(), !stream(0, @intCast(length)) or length == 0);
        switch (mutation) {
            2 => f.turret_pilot_generation += 1,
            3 => frame.tick_gates[5].value += 1,
            4 => frame.tick_gates[3].value = p.SYNC_MAX_ACTORS + 1,
            5 => frame.tick_gates[4].value = 0,
            6 => frame.tick_gates[6].value = 0x7fc00000,
            7 => frame.tick_gates[10].value = 2,
            8 => frame.tick_gate_count = 10,
            9 => f.pack_target_mutation = 1,
            11 => put(target, 0x50, 0),
            12 => frame.tick_gates[3].value = 0,
            13 => frame.tick_gates[6].clock += 1,
            15 => put(target, 0x50, 0x8001),
            16 => f.pack_target_mutation = 2,
            17 => {
                f.pack_target_mutation = 3;
                put(target, 0x50, 0x8001);
            },
            18 => frame.tick_gates[12].value += 1,
            19 => frame.tick_gates[11].value += 1,
            else => {},
        }
        scene.first[0x60] = 9;
        scene.first[0x63] = 0x96;
        entry = 1;
        put(scene.first, 0x88, 0x3eb5d7bf);
        put(scene.first, 0x8c, 0x3d40fcb5);
        scene.first[0x9c] = 0xee;
        const before = win.load([0xa0]u8, addr(scene.first));
        const before_actor = win.load([0x1440]u8, addr(target));
        var old: u32 = 0;
        if (mutation == 10) check(@src(), win.VirtualProtect(addr(scene.first), scene.first.len, 2, &old) != 0);
        begin(false);
        win.SetLastError(890);
        pack.native_pack_mode(addr(scene.first), addr(&entry));
        const error_code = win.GetLastError();
        if (mutation == 10) {
            var ignored: u32 = 0;
            check(@src(), win.VirtualProtect(addr(scene.first), scene.first.len, old, &ignored) != 0);
        }
        check(@src(), error_code == 890);
        if (mutation <= 1 or mutation == 14 or mutation == 15 or mutation == 17) {
            check(@src(), finish() and scene.first[0x60] == 18 and entry == 0 and scene.first[0x63] == 0x96);
            check(@src(), word(scene.first, 0x88) == (if (mutation == 1) @as(usize, 0) else addr(target)) and equal(scene.first[0x8c..], &timers, 16) and scene.first[0x9c] == 0xef);
            check(@src(), word(target, 0x50) == (if (mutation == 14 or mutation == 15 or mutation == 17) @as(u32, 0x8001) else 3) and win.load(i16, addr(target) + 0xdc0) == 183);
            check(@src(), equal(target, &before_actor, before_actor.len));
        } else check(@src(), !finish() and equal(scene.first, &before, before.len) and entry == 1);
    }
    const retirement = @import("target_retirement.zig");
    for (0..4) |case| {
        f.pack_target_mutation = 0;
        next(true);
        retirement.invalidate(addr(target));
        put(target, 0x50, 0);
        put(target, 8, 0);
        if (case != 1) retirement.note_retired_target(addr(target));
        if (case == 2) retirement.invalidate(addr(target));
        if (case == 3) put(target, 8, 0x1234);
        scene.first[0x60] = 18;
        put(scene.first, 0x88, addr(target));
        copy(scene.first[0x8c..], &timers, 16);
        const actor_before = win.load([0x1440]u8, addr(target));
        var entered: u8 = 0;
        pack.native_pack_mode(addr(scene.first), addr(&entered));
        check(@src(), equal(target, &actor_before, actor_before.len));
        if (case == 0) check(@src(), finish() and word(scene.first, 0x88) == 0) else check(@src(), !finish());
    }
    retirement.invalidate(addr(target));
    f.pack_target_mutation = 0;
    f.turret_pilot_generation = 17;
    const resumes = @import("tick_resume.zig");
    const original_resume = resumes.pack_mode_resume;
    const abort = resumes.pack_mode_abort;
    resumes.pack_mode_resume = @intFromPtr(&pack_mode_success_exit);
    resumes.pack_mode_abort = @intFromPtr(&pack_mode_abort_exit);
    defer {
        resumes.pack_mode_resume = original_resume;
        resumes.pack_mode_abort = abort;
    }
    pack_probe_member = addr(scene.first);
    put(target, 0x50, 3);
    for (0..2000) |i| {
        next(true);
        scene.first[0x60] = 18;
        put(scene.first, 0x88, addr(target));
        copy(scene.first[0x8c..], &timers, 16);
        scene.first[0x9c] = 1;
        var entered: u8 = 0;
        pack.native_pack_mode(addr(scene.first), addr(&entered));
        check(@src(), finish());
        begin(false);
        scene.first[0x60] = 9;
        put(scene.first, 0x88, 0x3eb5d7bf);
        if (i % 3 == 1) frame.tick_gates[4].value = 0;
        if (i % 3 == 2) {
            state.active = false;
            state.failed = true;
        }
        probe.projected = if (i % 3 == 2) 9 else 18;
        probe.entry = if (i % 3 == 1) @intFromPtr(&pack_mode_abort_exit) else @intFromPtr(&pack_mode_native_exit);
        probe.invoke_thunk();
        const fx = probe.observed_fx;
        const regs = probe.observed_regs;
        const branch = probe.branch;
        probe.entry = @intFromPtr(&native_pack_mode_input);
        win.SetLastError(1234);
        probe.invoke_thunk();
        check(@src(), win.GetLastError() == 1234 and probe.branch == branch);
        probe.expectSame(@src(), &fx, &regs);
        if (i % 3 != 2) check(@src(), finish() == (i % 3 == 0));
    }
    for (0..4) |invalid| {
        next(true);
        scene.first[0x60] = 18;
        put(scene.first, 0x88, if (invalid == 0) 0x3eb5d7bf else addr(target));
        copy(scene.first[0x8c..], &timers, 16);
        if (invalid == 1) put(scene.first, 0x90, 0x7fc00000);
        if (invalid == 2) f.pack_target_mutation = 2;
        if (invalid == 3) put(target, 0x50, 0);
        const before = win.load([0xa0]u8, addr(scene.first));
        var entered: u8 = 1;
        check(@src(), pack.native_pack_mode_checked(addr(scene.first), addr(&entered)) == 0 and !finish() and entered == 1 and equal(scene.first, &before, before.len));
    }
    f.pack_target_mutation = 0;
}
fn ordinalMemo() void {
    const identity = @import("tick_pack_identity.zig");
    const membership = @import("tick_pack_mutation.zig");
    const resumes = [_]*usize{ &membership.pack_remove_resume, &membership.pack_construct_resume, &membership.pack_destroy_resume };
    const original_resumes = [_]usize{ membership.pack_remove_resume, membership.pack_construct_resume, membership.pack_destroy_resume };
    const fixture_resumes = [_]usize{ @intFromPtr(&f.machine.pack_remove_fixture_resume), @intFromPtr(&f.machine.pack_construct_fixture_resume), @intFromPtr(&f.machine.pack_destroy_fixture_resume) };
    for (resumes, fixture_resumes, 0..) |continuation, target, i| {
        continuation.* = target;
        const revision = membership.clonewars_pack_membership_revision;
        win.SetLastError(812);
        f.machine.invoke_pack_observer(@intCast(i));
        const observed = f.machine.pack_observer_fixture_observed;
        check(@src(), membership.clonewars_pack_membership_revision == revision +% 1 and win.GetLastError() == 812);
        check(@src(), std.mem.eql(u8, &f.machine.pack_observer_fpu_before, &f.machine.pack_observer_fpu_after));
        check(@src(), observed[0] == 0x12345678 and observed[1] == 0x87654321 and observed[2] == 0x13579bdf and observed[3] == (if (i == 0) @as(u32, 0x1badb002) else 0x2468ace0));
        check(@src(), observed[4] == 0x11223344 and observed[5] == 0x55667788 and observed[6] == 0x19283746 and observed[8] & 1 == 1);
        if (i != 0) check(@src(), observed[10] == (if (i == 1) @as(u32, 0xa9ce96) else 0xa9ced6) and observed[11] == 0xffffffff);
        continuation.* = original_resumes[i];
    }
    const scene = PackScene.init();
    const nodes = buffer(512 * 0x80);
    for (0..512) |i| {
        put(nodes[i * 0x80 ..], 0x68, scene.pack);
        put(nodes[i * 0x80 ..], 0x7c, if (i + 1 < 512) addr(nodes) + (i + 1) * 0x80 else 0);
    }
    put(scene.pack, 0xa0, nodes);
    put(scene.pack, 0xac, 512);
    const member = addr(nodes) + 511 * 0x80;
    next(true);
    membership.clonewars_pack_membership_observer_active = 1;
    defer membership.clonewars_pack_membership_observer_active = 0;
    membership.changed();
    const before = identity.clonewars_pack_memory_debug[4];
    check(@src(), identity.resolve(member, false).?.index == 511);
    const traversed = identity.clonewars_pack_memory_debug[4];
    check(@src(), traversed -% before == 511);
    const original = identity.resolve(member, false).?;
    check(@src(), original.index == 511 and identity.clonewars_pack_memory_debug[4] == traversed);
    put(member, 0x6c, 71);
    check(@src(), identity.resolve(member, false).?.witness != original.witness and identity.clonewars_pack_memory_debug[4] == traversed);
    membership.changed();
    put(nodes[0x80..], 0x7c, nodes[3 * 0x80 ..]);
    check(@src(), identity.resolve(member, false).?.index == 510);
    const removed = identity.clonewars_pack_memory_debug[4];
    check(@src(), removed -% traversed == 510);
    check(@src(), identity.resolve(member, false).?.index == 510 and identity.clonewars_pack_memory_debug[4] == removed);
    put(0xfb4b6c, 0, word(0xfb4b6c, 0) + 1);
    check(@src(), identity.resolve(member, false).?.index == 510 and identity.clonewars_pack_memory_debug[4] -% removed == 510);
    membership.changed();
    put(nodes[10 * 0x80 ..], 0x68, 0);
    check(@src(), identity.resolve(member, false) == null);
    put(nodes[10 * 0x80 ..], 0x68, scene.pack);
    check(@src(), identity.resolve(member, false).?.index == 510);
    put(member, 0x68, 0);
    check(@src(), identity.resolve(member, false) == null);
    put(member, 0x68, scene.pack);
    check(@src(), identity.resolve(member, false).?.index == 510);
    var old: u32 = 0;
    const page = member & ~@as(usize, 0xfff);
    check(@src(), win.VirtualProtect(page, 0x1000, 1, &old) != 0);
    check(@src(), identity.resolve(member, false) == null);
    check(@src(), win.VirtualProtect(page, 0x1000, old, &old) != 0);
    membership.changed();
    check(@src(), identity.resolve(member, false).?.index == 510);
}
fn gizmos() void {
    const weapon_actor = buffer(0x1440);
    f.turret_pilot = addr(weapon_actor);
    weapon_actor[0x8ea] = 3;
    weapon_actor[0x8fa] = 41;
    weapon_actor[0x8fb] = 254;
    weapon_actor[0x8fc] = 255;
    weapon_actor[0x8f9] = 0xa5;
    weapon_actor[0x8fd] = 0x5a;
    next(true);
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), finish() and frame.tick_gate_count == 3 and stream(0, 3) and !stream(0, 2) and !stream(1, 2));
    begin(false);
    weapon_actor[0x8fa] = 254;
    win.SetLastError(987);
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), finish() and weapon_actor[0x8ea] == 3 and weapon_actor[0x8fa] == 41 and weapon_actor[0x8fb] == 254 and weapon_actor[0x8fc] == 255 and weapon_actor[0x8f9] == 0xa5 and weapon_actor[0x8fd] == 0x5a and win.GetLastError() == 987);
    for (0..5) |mutation| {
        next(true);
        actor.native_weapon_commands(addr(weapon_actor));
        check(@src(), finish());
        switch (mutation) {
            0 => frame.tick_gates[0].value += 1,
            1 => frame.tick_gates[1].value += 1,
            2 => frame.tick_gates[2].clock += 1,
            3 => frame.tick_gate_count = 2,
            4 => frame.tick_gates[2].site = sites.FIRE_VISIBILITY,
            else => unreachable,
        }
        begin(false);
        weapon_actor[0x8fa] = 254;
        const before = f.faults;
        actor.native_weapon_commands(addr(weapon_actor));
        check(@src(), !finish() and f.faults == before + 1 and weapon_actor[0x8fa] == 254);
    }
    next(true);
    weapon_actor[0x8fa] = 254;
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), finish());
    begin(false);
    weapon_actor[0x8fa] = 41;
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), finish() and weapon_actor[0x8fa] == 254);
    f.cancel();
    weapon_actor[0x8fa] = 41;
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), weapon_actor[0x8fa] == 41);
    next(true);
    f.turret_pilot = 0;
    win.SetLastError(765);
    actor.native_weapon_commands(addr(weapon_actor));
    check(@src(), finish() and frame.tick_gate_count == 0 and weapon_actor[0x8fa] == 41 and win.GetLastError() == 765);
    f.turret_pilot = addr(weapon_actor);
    f.patch(0x45a930, "\xc3");
    for ([_]u8{ 0xff, 0xfe, 41 }) |command| {
        next(true);
        weapon_actor[0x8fb] = command;
        win.SetLastError(654);
        var numeric: f.Numeric = .{};
        numeric.push();
        const flags = f.machine.invoke_weapon_commands(addr(weapon_actor));
        numeric.pop();
        check(@src(), flags != 0xffffffff and finish() and win.GetLastError() == 654);
        numeric.verify();
        check(@src(), (flags & 0x40 != 0) == (command == 0xff));
        check(@src(), ((flags & 0x40 != 0) or ((flags & 0x80 != 0) != (flags & 0x800 != 0))) == (@as(i8, @bitCast(command)) <= -1));
    }
    const value = buffer(0x22e8);
    const container = buffer(16);
    const registry = buffer(0x2c);
    const manager = buffer(0x28);
    const gizmo = buffer(0x280);
    const table = [_]usize{addr(manager)};
    var handle: usize = addr(&table);
    put(0xfb4a20, 0, value);
    put(0xe90184, 0, registry);
    put(value, 0x22e4, container);
    put(container, 12, value);
    put(value, 0x400, &handle);
    copy(value[0x81..], "EngineWorld", 12);
    put(registry, 0x28, 1);
    put(manager, 0, 0xc4c1cc);
    put(0xc4c1cc, 0x40, 0x838260);
    put(manager, 0x24, gizmo);
    put(gizmo, 0, 0xc47e9c);
    copy(gizmo[0x30..], "AuthoredTurret", 15);
    f.patch(0x806379, "\xc3");
    const prior_lan = f.lan_state;
    f.lan_state = 3;
    win.store(u8, 0xfb0b1d, 1);
    win.SetLastError(456);
    var numeric: f.Numeric = .{};
    numeric.push();
    const rendered = f.machine.invoke_pickup_render(addr(manager));
    numeric.pop();
    check(@src(), rendered == 0x1234ba01 and win.GetLastError() == 456);
    numeric.verify();
    check(@src(), f.machine.invoke_pickup_render(addr(manager)) == 0x1234ba00);
    put(0xfb4b6c, 0, word(0xfb4b6c, 0) + 1);
    check(@src(), f.machine.invoke_pickup_render(addr(manager)) == 0x1234ba01);
    f.alive = false;
    check(@src(), f.machine.invoke_pickup_render(addr(manager)) == 0x1234ba01);
    f.alive = true;
    f.lan_state = 0;
    check(@src(), f.machine.invoke_pickup_render(addr(manager)) == 0x1234ba01);
    f.lan_state = prior_lan;
    for (0..8) |mutation| {
        next(true);
        win.store(u16, 0xe637b4, 123);
        put(0xea178c, 0, 456);
        put(gizmo, 0x154, 0x3e800000);
        win.SetLastError(432);
        world.native_gizmo_turret_input(addr(gizmo));
        check(@src(), finish() and frame.tick_gate_count == 7 and stream(0, 7) and win.GetLastError() == 432);
        switch (mutation) {
            0 => {},
            1 => frame.tick_gates[0].value += 1,
            2 => frame.tick_gates[4].clock += 1,
            3 => frame.tick_gate_count = 6,
            4 => frame.tick_gates[4].value = 0x10000,
            5 => frame.tick_gates[6].value = 0x7fc00000,
            6 => frame.tick_gates[2].site += 1,
            7 => gizmo[0x30] = 'X',
            else => unreachable,
        }
        begin(false);
        win.store(u16, 0xe637b4, 321);
        put(0xea178c, 0, 654);
        put(gizmo, 0x154, 0x3f000000);
        const previous = f.faults;
        win.SetLastError(432);
        world.native_gizmo_turret_input(addr(gizmo));
        if (mutation == 0) check(@src(), finish() and f.faults == previous and win.load(u16, 0xe637b4) == 123 and word(0xea178c, 0) == 456 and word(gizmo, 0x154) == 0x3e800000) else check(@src(), !finish() and f.faults == previous + 1 and win.load(u16, 0xe637b4) == 321 and word(0xea178c, 0) == 654 and word(gizmo, 0x154) == 0x3f000000);
        check(@src(), win.GetLastError() == 432);
        gizmo[0x30] = 'A';
    }
    f.patch(0x838281, "\xc3");
    gizmo[0x1ba] = 0x34;
    gizmo[0x1bb] = 0x12;
    next(true);
    win.SetLastError(876);
    numeric = .{};
    numeric.push();
    const gizmo_flags = f.machine.invoke_gizmo_turret(addr(gizmo));
    numeric.pop();
    check(@src(), gizmo_flags != 0xffffffff and gizmo_flags & 0x41 == 0x41 and finish() and win.GetLastError() == 876);
    numeric.verify();
    const wait_object = buffer(0x940);
    const wait_team = buffer(0x10d4);
    const wait_resource = buffer(0x10);
    const wait_descriptor = buffer(0x34);
    put(wait_object, 0, 0xaee6dc);
    put(wait_object, 0x24, gizmo);
    put(wait_object, 0x28, wait_team);
    put(gizmo, 0x28, manager);
    put(wait_team, 0, 0xaef0fc);
    put(wait_team, 0x1c, wait_descriptor);
    put(wait_team, 0x10d0, wait_resource);
    put(wait_resource, 0xc, value);
    put(wait_object, 0x874, 0x3f400000);
    for (0..7) |mutation| {
        next(true);
        put(0xea178c, 0, 1289609241);
        win.SetLastError(831);
        world.native_rts_wait_seed(addr(wait_object));
        check(@src(), finish() and frame.tick_gate_count == 5 and stream(0, 5) and win.GetLastError() == 831 and !stream(0, 4) and !stream(1, 4));
        switch (mutation) {
            0 => {},
            1 => frame.tick_gates[2].value += 1,
            2 => frame.tick_gates[4].clock += 1,
            3 => frame.tick_gate_count = 4,
            4 => frame.tick_gates[2].site += 1,
            5 => gizmo[0x30] = 'X',
            6 => put(wait_resource, 0xc, 0),
            else => unreachable,
        }
        begin(false);
        put(0xea178c, 0, 2976555279);
        const before = f.faults;
        win.SetLastError(832);
        world.native_rts_wait_seed(addr(wait_object));
        if (mutation == 0) check(@src(), finish() and word(0xea178c, 0) == 1289609241 and f.faults == before) else check(@src(), !finish() and word(0xea178c, 0) == 2976555279 and f.faults == before + 1);
        check(@src(), win.GetLastError() == 832 and word(wait_object, 0x874) == 0x3f400000);
        gizmo[0x30] = 'A';
        put(wait_resource, 0xc, value);
    }
    var jump = [_]u8{ 0xe9, 0, 0, 0, 0 };
    put(&jump, 1, addr(&f.waitOriginal) -% 0x573105);
    f.patch(0x573100, &jump);
    next(true);
    put(0xea178c, 0, 91);
    win.SetLastError(833);
    numeric = .{};
    numeric.push();
    const wait_result = f.machine.invoke_wait(addr(wait_object));
    numeric.pop();
    check(@src(), f.wait_draws == 1 and wait_result == 0.25);
    numeric.verify();
    check(@src(), finish() and win.GetLastError() == 833);
    begin(false);
    put(0xea178c, 0, 92);
    check(@src(), f.machine.invoke_wait(addr(wait_object)) == 0.25 and f.wait_draws == 2 and word(0xea178c, 0) == 91 and finish());
    f.cancel();
    put(0xea178c, 0, 93);
    world.native_rts_wait_seed(addr(wait_object));
    check(@src(), word(0xea178c, 0) == 93);
}
const coefficients = [_]usize{ 0xfb0fc4, 0xfb0fa8, 0xfb0fb4, 0xfb102c, 0xfb0fb0, 0xfb0fac, 0xfb1028, 0xfb0fa0, 0xfb1014, 0xfb0fc0, 0xfb1070, 0xfb1018, 0xfb101c, 0xfb0fb8, 0xfb0fa4, 0xfb0fbc, 0xfb0fc8 };
fn setClocks(values: *const [17]u32) void {
    for (coefficients, values) |address, bits| put(address, 0, bits);
}
fn clocksEqual(values: *const [17]u32) bool {
    for (coefficients, values) |address, bits| if (word(address, 0) != bits) return false;
    return true;
}
fn smooth(value: *u32, coefficient: u32) void {
    const call: *const fn (*u32, f32, f32) callconv(.c) void = @ptrFromInt(0x764d40);
    call(value, @bitCast(@as(u32, 1036920420)), @bitCast(coefficient));
}
fn elapsed() void {
    const stock = [_]u8{ 0x8b, 0x44, 0x24, 0x04, 0xd9, 0x44, 0x24, 0x08, 0xd8, 0x20, 0xd9, 0x5c, 0x24, 0x08, 0xd9, 0x44, 0x24, 0x08, 0xd8, 0x4c, 0x24, 0x0c, 0xd8, 0x00, 0xd9, 0x18, 0xc3 };
    f.patch(0x764d40, &stock);
    var host_turn: u32 = 1028531812;
    var peer_turn = host_turn;
    smooth(&host_turn, 1050015258);
    smooth(&peer_turn, 1042662704);
    check(@src(), host_turn == 1032143828 and peer_turn == 1030718918);
    const host_clock = [_]u32{ 1064859521, 1061258580, 1057064875, 1052772632, 1050157484, 1042645436, 1038292912, 1034734560, 1032548832, 1024321328, 1016014720, 1010790080, 1007667328, 1004945920, 1002438272, 1000645376, 999299584 };
    const peer_clock = [_]u32{ 1065336832, 1064304640, 1061158912, 1058695173, 1056964608, 1042645436, 1045643308, 1042476044, 1040485988, 1032398328, 1024165472, 1018895072, 1015856064, 1013026944, 1010577344, 1008824128, 1007507456 };
    check(@src(), host_clock[5] == peer_clock[5]);
    host_turn = 1028531812;
    peer_turn = host_turn;
    smooth(&host_turn, host_clock[2]);
    smooth(&peer_turn, peer_clock[2]);
    check(@src(), host_turn != peer_turn);
    next(true);
    put(0xfb4ad4, 0, 0x3f800000);
    setClocks(&host_clock);
    win.SetLastError(321);
    check(@src(), clock.native_tick_elapsed_input() != 0 and win.GetLastError() == 321 and finish());
    check(@src(), frame.tick_gate_count == 18 and frame.tick_gates[0].site == sites.GAME_TIME and frame.tick_gates[6].site == sites.TURN_SMOOTHING and stream(0, 18));
    for (0..18) |n| check(@src(), !stream(0, n) or n == 0);
    check(@src(), !stream(1, 17));
    begin(false);
    put(0xfb4ad4, 0, 0x40000000);
    setClocks(&peer_clock);
    win.SetLastError(654);
    check(@src(), clock.native_tick_elapsed_input() != 0 and word(0xfb4ad4, 0) == 0x3f800000 and clocksEqual(&host_clock) and win.GetLastError() == 654 and finish());
    peer_turn = 1028531812;
    smooth(&peer_turn, word(coefficients[2], 0));
    check(@src(), peer_turn == host_turn);
    f.cancel();
    put(0xfb4ad4, 0, 0x40400000);
    setClocks(&peer_clock);
    check(@src(), clock.native_tick_elapsed_input() == 0 and word(0xfb4ad4, 0) == 0x40400000 and clocksEqual(&peer_clock));
    frame.epoch += 1;
    f.bound.epoch += 1;
    frame.tick_gates[0].clock += 1;
    begin(false);
    put(0xfb4ad4, 0, 0x40800000);
    check(@src(), clock.native_tick_elapsed_input() == 0 and word(0xfb4ad4, 0) == 0x40800000 and clocksEqual(&peer_clock) and !finish());
    for (0..7) |mutation| {
        next(true);
        put(0xfb4ad4, 0, 0x3f800000);
        setClocks(&host_clock);
        check(@src(), clock.native_tick_elapsed_input() != 0 and finish());
        switch (mutation) {
            0 => frame.tick_gates[1].clock += 1,
            1 => frame.tick_gates[9].site += 1,
            2 => frame.tick_gate_count = 17,
            3 => frame.tick_gates[17].value = 0x7fc00000,
            4 => frame.tick_gates[6].value = 0x3f800001,
            5 => frame.tick_gates[1].value = 0xbf000000,
            6 => {
                const first = frame.tick_gates[1];
                frame.tick_gates[1] = frame.tick_gates[2];
                frame.tick_gates[2] = first;
            },
            else => unreachable,
        }
        check(@src(), !stream(0, frame.tick_gate_count));
        begin(false);
        put(0xfb4ad4, 0, 0x40000000);
        setClocks(&peer_clock);
        check(@src(), clock.native_tick_elapsed_input() == 0 and word(0xfb4ad4, 0) == 0x40000000 and clocksEqual(&peer_clock) and !finish());
    }
    for ([_]u32{ 0x7fc00000, 0x7f800000, 0xbf000000, 0x3f800001 }) |bad| for ([_]usize{ 0, 5, 16 }) |index| {
        var invalid = host_clock;
        invalid[index] = bad;
        next(true);
        put(0xfb4ad4, 0, 0x3f800000);
        setClocks(&invalid);
        check(@src(), clock.native_tick_elapsed_input() == 0 and word(0xfb4ad4, 0) == 0x3f800000 and clocksEqual(&invalid) and !finish());
    };
    next(true);
    put(0xfb4ad4, 0, 0x7fc00000);
    setClocks(&host_clock);
    check(@src(), clock.native_tick_elapsed_input() == 0 and !finish());
}
pub fn main(init: std.process.Init) !void {
    f.open();
    defer f.close();
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const groups = [_]*const fn () void{ decisions, tracks, rts, packs, gizmos, elapsed };
    if (args.len > 1) {
        const selected = try std.fmt.parseInt(u32, args[1], 10);
        check(@src(), selected < groups.len);
        f.reset(selected);
        groups[selected]();
    } else {
        for (groups, 0..) |group, index| {
            f.reset(@intCast(index));
            group();
        }
    }
}
