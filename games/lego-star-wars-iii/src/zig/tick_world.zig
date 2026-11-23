const std = @import("std");
const s = @import("tick_state.zig");
const load = s.load;
const store = s.store;
const v = s.site;
const Gizmo = @import("gizmo_types.zig").Source;
extern fn native_gizmo_manager_source_resolve(usize, *Gizmo) bool;
extern fn native_gizmo_source_find(usize, usize, *Gizmo) bool;
extern fn native_gizmo_source_revalidate(*const Gizmo) bool;
extern fn native_rts_object_source(usize, *@import("rts_types.zig").Object) c_int;
const RenderCohort = @import("render_cohort.zig").RenderCohort;
var render_cohorts: [4096]RenderCohort = @splat(.{});
pub export var clonewars_native_rts_dispatch_debug: [257]u32 = @splat(0);
pub export fn native_rts_dispatch_observe(battlefield: usize, descriptor: usize, event: usize) void {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (!s.ready() or !s.readable(descriptor, 0x10) or !s.readable(event, 4)) return;
    const index = clonewars_native_rts_dispatch_debug[0];
    const record = clonewars_native_rts_dispatch_debug[1 + (index % 32) * 8 ..][0..8];
    record.* = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), battlefield, descriptor, load(u32, descriptor + 0xc), load(u32, event), load(u32, 0xfb2e6c) };
    clonewars_native_rts_dispatch_debug[0] +%= 1;
}
pub export fn native_pickup_render_primary(manager: usize, local: u32) u32 {
    if (s.lan_status() != 3 or s.game_sync_status() != 2 or local == 0) return local;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    var source: Gizmo = std.mem.zeroes(Gizmo);
    if (!native_gizmo_manager_source_resolve(manager, &source)) {
        s.clonewars_native_pickup_render_debug[2] +%= 1;
        return local;
    }
    const result = render_cohorts[source.manager_index].primary(&source, s.game_sync_epoch(), s.clock(), local);
    s.clonewars_native_pickup_render_debug[@intFromBool(result == 0)] +%= 1;
    return result;
}
pub export fn native_gizmo_turret_input(gizmo: usize) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const at = v.GIZMO_TURRET_SOURCE;
    var source: Gizmo = undefined;
    if (!s.readable(gizmo, 0x158) or !native_gizmo_source_find(gizmo, 0x838260, &source)) {
        s.fail(4, at, s.clock(), null);
        s.clonewars_native_tick_failure[8..16].* = .{ gizmo, if (s.readable(gizmo, 4)) load(usize, gizmo) else 0, load(u32, 0xfb4a20), load(u32, 0xe90184), 0, 0, 0, 0 };
        return;
    }
    const local = source.key ++ [_]u32{ load(u16, 0xe637b4), load(u32, 0xea178c), load(u32, gizmo + 0x154) };
    const sites = s.consecutive(7, at, 1);
    const expected = s.firstExpected();
    var okay = @import("tick_clock.zig").finite(local[6]);
    if (s.host) okay = okay and s.frame.?.tick_gate_count <= s.p.SYNC_MAX_TICK_GATES - 7 else {
        const e = s.expected(7);
        okay = okay and e != null;
        if (okay) for (e.?, sites, local, 0..) |gate, site, value, i| {
            if (gate.site != site or gate.clock != s.clock() or !s.valid.gateValid(gate) or (i < 4 and gate.value != value)) {
                okay = false;
                break;
            }
        };
    }
    if (!okay) {
        s.fail(2, at, s.clock(), expected);
        return;
    }
    var result: [7]u32 = undefined;
    s.run(&local, &sites, &result);
    if (!s.host and s.ready()) {
        if (!native_gizmo_source_revalidate(&source)) s.fail(4, at, s.clock(), expected) else {
            store(u16, 0xe637b4, @truncate(result[4]));
            store(u32, 0xea178c, result[5]);
            store(u32, gizmo + 0x154, result[6]);
        }
    }
}
pub export fn native_flow_request(flow: usize) void {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (s.readable(flow, 0x64)) store(u32, flow + 0x60, s.game_sync_preload_flow_input(flow, load(u32, flow + 0x60)));
    if (!s.ready()) return;
    const root = load(usize, 0xfb2e60);
    if (root == 0 or flow != root + 0x1b44 or !s.readable(flow, 0x64)) {
        s.fail(4, 0x889edc, 0, null);
        return;
    }
    const local = load(u32, flow + 0x60);
    const gate = s.p.SyncTickGate{ .site = 0x889edc, .clock = s.clock(), .value = local };
    if (!s.valid.gateValid(gate)) {
        s.fail(4, gate.site, gate.clock, null);
        return;
    }
    const result = s.decision(gate.site, local);
    if (!s.host and s.ready()) store(u32, flow + 0x60, result);
}
pub export fn native_tick_gate(at: u32) u32 {
    return s.decision(at, load(u8, 0xfbc161));
}
fn rtsRng(battlefield: usize, registry: usize, game_site: u32, engine_site: u32) void {
    const resource = if (s.readable(battlefield, 0x10d4)) load(usize, battlefield + 0x10d0) else 0;
    if (!s.readable(resource, 0x10) or load(usize, battlefield) != 0xaef0fc or !s.readable(registry, 4) or load(usize, registry) != battlefield or load(usize, battlefield + 0xbc) != registry or load(usize, resource + 0xc) == 0 or load(usize, resource + 0xc) != load(usize, 0xfb4a20) or load(u32, 0xe637b4) > 65535) {
        s.fail(7, game_site, s.clock(), null);
        return;
    }
    const game = s.decision(game_site, load(u32, 0xe637b4));
    const engine = s.decision(engine_site, load(u32, 0xea178c));
    if (!s.host and s.ready()) {
        store(u32, 0xe637b4, game);
        store(u32, 0xea178c, engine);
    }
}
pub export fn native_rts_registry_rng(registry: usize) void {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (s.ready()) rtsRng(if (s.readable(registry, 4)) load(usize, registry) else 0, registry, v.RTS_GAME_RNG, v.RTS_ENGINE_RNG);
}
pub export fn native_rts_producer_rng(battlefield: usize) void {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (s.ready()) rtsRng(battlefield, if (s.readable(battlefield, 0xc0)) load(usize, battlefield + 0xbc) else 0, v.RTS_PRODUCER_GAME_RNG, v.RTS_PRODUCER_ENGINE_RNG);
}
pub export fn native_rts_wait_sample(local: u32) u32 {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    // Geonosis can sample an inactive wait just before the turret turns.
    if (local == 0 and s.ready() and !s.host and s.frame.?.level == 79 and s.early_rts_wait == null) {
        if (s.expected(5)) |gates| {
            const clock = s.clock();
            for (gates[0..4], s.consecutive(4, v.RTS_TURN_INPUT, 1)) |gate, site| {
                if (gate.site != site or gate.clock != clock or !s.valid.gateValid(gate)) break;
            } else {
                if (gates[4].site == v.RTS_WAIT_SAMPLE and gates[4].clock == clock and gates[4].value == 0) {
                    s.early_rts_wait = s.cursor + 4;
                    return 0;
                }
            }
        }
    }
    return s.decision(v.RTS_WAIT_SAMPLE, @intFromBool(local != 0));
}
pub export fn native_rts_wait_seed(object: usize) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const at = v.RTS_WAIT_RNG;
    var source: @import("rts_types.zig").Object = std.mem.zeroes(@import("rts_types.zig").Object);
    if (native_rts_object_source(object, &source) == 0) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return;
    }
    if (s.host) {
        if (!s.capacity(5, at)) return;
    } else if (!s.match(&(source.key ++ [_]u32{0}), &s.consecutive(5, at, 1), 4, false)) return;
    for (source.key, 0..) |value, i| _ = s.decision(at + @as(u32, @intCast(i)), value);
    const local = load(u32, 0xea178c);
    const canonical = s.decision(at + 4, local);
    if (s.ready()) {
        s.clonewars_native_rts_wait_rng_debug[@intFromBool(!s.host)] +%= 1;
        if (local != canonical) s.clonewars_native_rts_wait_rng_debug[2] +%= 1;
        if (!s.host) store(u32, 0xea178c, canonical);
    }
}
pub export fn native_rts_pack_admission(producer: usize, count: i32, limit: i32, blocked: u32) u32 {
    const local: u32 = @intFromBool(count < limit and blocked & 255 == 0);
    if (!s.ready()) return local;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const at = v.RTS_PACK_ADMISSION;
    if (!s.readable(producer, 0x258)) {
        s.fail(7, at, s.clock(), null);
        return local;
    }
    const index = load(u32, producer + 0x250);
    const side = load(u32, producer + 0x254);
    const battlefield = load(usize, producer + 0x28);
    const resource = if (s.readable(battlefield, 0x10d4)) load(usize, battlefield + 0x10d0) else 0;
    if (index >= 8 or side >= 2 or !s.readable(resource, 0x10) or load(usize, battlefield) != 0xaef0fc or load(usize, resource + 0xc) != load(usize, 0xfb4a20)) {
        s.fail(7, at, s.clock(), null);
        return local;
    }
    const key = (side * 8 + index) * 2;
    const expected = s.firstExpected();
    if (!s.host and (expected == null or expected.?.site != at or expected.?.value & 0xfffffffe != key)) {
        s.fail(7, at, s.clock(), expected);
        return local;
    }
    return s.decision(at, key | local) & 1;
}
pub export fn native_perception_sweep(completed: u32) u32 {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    var publish: u32 = @intFromBool(completed != 0);
    if (s.ready()) {
        const next = load(u32, 0xfbea24);
        if (publish == 0 and next > s.p.SYNC_MAX_ACTORS) s.fail(4, 0x9dda14, s.clock(), null) else {
            const decision = s.decision(0x9dda14, if (publish != 0) 1 else next * 2);
            publish = decision & 1;
            if (!s.host and s.ready() and publish == 0) store(u32, 0xfbea24, decision / 2);
        }
    }
    return publish;
}
pub export fn reset_native_visibility_cache(manager: usize) void {
    const reset: *const fn (usize) callconv(.c) void = @ptrFromInt(0x8a6560);
    reset(manager);
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (s.lan_status() != 3 or !s.readable(manager, 0x218) or load(usize, manager) != 0xc4f730 or load(usize, manager + 8) != load(usize, 0xfb2f60)) return;
    @memset(@as([*]u8, @ptrFromInt(manager + 0x10))[0..0x208], 0);
}
