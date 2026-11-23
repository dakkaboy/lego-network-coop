const std = @import("std");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const types = @import("spellit_types.zig");
const state = @import("spellit_hop_state.zig");
const bodies = @import("spellit_bodies.zig");
const Scope = state.Scope;
const Token = @import("cohort_types.zig").Token;
const Machine = @import("machine_environment.zig").Environment;
const equal = @import("validation.zig").equal;
const physics = @import("physics_validation.zig");
const Query = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) u32;
var installed = false;
var trace_native = false;
pub export var clonewars_resolute_hologram_skips: u32 = 0;
export var spellit_target_resume: usize = 0x8406b8;
export var spellit_timeout_flags_resume: usize = 0x812d81;
export var spellit_finish_flags_resume: usize = 0x812df7;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn native_spellit_source_resolve(usize, *types.Source) c_int;
extern fn native_spellit_source_revalidate(*const types.Source) c_int;
extern fn native_spellit_piece_resolve(*const types.Source, usize, *types.Piece) c_int;
extern fn native_spellit_piece_revalidate(*const types.Source, *const types.Piece) c_int;
extern fn native_spellit_selection_snapshot(*const types.Source, *u32, *[4]u32) c_int;
extern fn physics_world_input(*p.SyncPhysicsChoice, *const Token) c_int;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern fn native_spellit_pose_bridge() void;
extern fn native_spellit_timeout_flags_bridge() void;
extern fn native_spellit_finish_flags_bridge() void;
fn choice(s: *const Scope, kind: u32, value: u32, piece: ?*const types.Piece) p.SyncPhysicsChoice {
    var result = std.mem.zeroes(p.SyncPhysicsChoice);
    result.kind = kind;
    result.site = if (kind == p.SYNC_PHYSICS_SPELLIT_SEED) 0x86101e else if (kind == p.SYNC_PHYSICS_SPELLIT_ENTITY) 0x8407d4 else 0x84085b;
    const v = &result.payload.world;
    v.clock = s.clock;
    v.value = value;
    v.source_name = s.source.key.name;
    v.gizmo_class = s.source.key.gizmo_class;
    v.gizmo_ordinal = s.source.key.gizmo_ordinal;
    if (piece) |body| {
        v.resource_name = body.key.resource;
        v.poi_name = body.key.poi_name;
        v.poi_ordinal = body.key.poi_ordinal;
        v.poi_count = body.key.poi_count;
        v.receiver_class = body.key.receiver_class;
        v.piece_ordinal = body.key.piece_ordinal;
    }
    return result;
}
fn resolveInput(s: *const Scope, input: *p.SyncPhysicsChoice, piece: ?*const types.Piece) bool {
    const local = input.payload.world.value;
    if (!state.live(s) or native_spellit_source_revalidate(&s.source) == 0 or (piece != null and native_spellit_piece_revalidate(&s.source, piece.?) == 0)) {
        state.reject(s, 3, input.kind);
        return false;
    }
    if (physics_world_input(input, &s.token) != 1) {
        state.reject(s, 4, input.kind);
        return false;
    }
    if (!state.live(s) or native_spellit_source_revalidate(&s.source) == 0 or (piece != null and native_spellit_piece_revalidate(&s.source, piece.?) == 0)) {
        state.reject(s, 5, input.kind);
        return false;
    }
    if (piece) |body| if (win.load(usize, s.gizmo + 0x21c) != body.piece) {
        state.reject(s, 5, input.kind);
        return false;
    };
    state.clonewars_spellit_hop_debug[1] +%= 1;
    if (input.payload.world.value != local) {
        state.clonewars_spellit_hop_debug[2] +%= 1;
        if (state.clonewars_spellit_hop_correction[0] == 0) state.clonewars_spellit_hop_correction = .{ s.token.epoch, s.token.sequence, s.clock, input.kind, local, input.payload.world.value, s.source.key.gizmo_class, s.source.key.gizmo_ordinal, if (piece) |body| body.key.piece_ordinal else 0, if (piece) |body| body.key.poi_ordinal else 0, if (piece) |body| body.key.receiver_class else 0, input.site };
    }
    return true;
}
fn invokeHop(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    if (s.bound) {
        if (!state.live(s) or !std.math.isFinite(s.delta) or s.delta < 0 or s.delta > 0.1 or native_spellit_source_resolve(s.gizmo, &s.source) == 0) {
            state.reject(s, 1, 0);
            return 0;
        }
        if (trace_native) state.snapshot(s);
        var input = std.mem.zeroes(p.SyncPhysicsChoice);
        input.kind = p.SYNC_PHYSICS_SPELLIT_STEP;
        input.site = 0x86101e;
        const v = &input.payload.spellit_step;
        v.clock = s.clock;
        v.delta = s.delta;
        v.engine_seed = win.load(u32, 0xea178c);
        v.game_seed = win.load(u16, 0xe637b4);
        v.timer = win.load(f32, s.gizmo + 0x218);
        v.source_name = s.source.key.name;
        v.gizmo_class = s.source.key.gizmo_class;
        v.gizmo_ordinal = s.source.key.gizmo_ordinal;
        if (comptime @hasDecl(@import("root"), "native_title")) {
            if (s.source.counted_name == 0 and std.mem.eql(u8, &win.load([5]u8, s.gizmo + 0x30), "HOLO\x00") and
                @import("physics_state.zig").skipResoluteHologramStep(&input, &s.token))
            {
                clonewars_resolute_hologram_skips +%= 1;
                return 0;
            }
        }
        const before = input;
        if (physics_world_input(&input, &s.token) != 1) {
            state.reject(s, 4, input.kind);
            return 0;
        }
        if (!state.live(s) or native_spellit_source_revalidate(&s.source) == 0 or !physics.sameSource(&before, &input) or !equal(&win.load(f32, s.gizmo + 0x218), &before.payload.spellit_step.timer) or win.load(u32, 0xea178c) != before.payload.spellit_step.engine_seed or win.load(u16, 0xe637b4) != before.payload.spellit_step.game_seed) {
            state.reject(s, 5, input.kind);
            return 0;
        }
        win.store(u32, 0xea178c, v.engine_seed);
        win.store(u16, 0xe637b4, @truncate(v.game_seed));
        win.store(f32, s.gizmo + 0x218, v.timer);
        s.delta = v.delta;
        state.clonewars_spellit_hop_debug[1] +%= 1;
        if (before.payload.spellit_step.engine_seed != v.engine_seed or before.payload.spellit_step.game_seed != v.game_seed or !std.mem.eql(u8, std.mem.asBytes(&before.payload)[8..16], std.mem.asBytes(&input.payload)[8..16])) state.clonewars_spellit_hop_debug[2] +%= 1;
        state.clonewars_spellit_hop_debug[0] +%= 1;
        if (!bodies.apply(s)) return 0;
    }
    const hop: *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x840660);
    s.machine.restore();
    hop(s.gizmo, @bitCast(s.delta));
    s.machine.capture();
    return 0;
}
fn abortHop(address: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    const s: *Scope = @ptrFromInt(address);
    bodies.cleanup(s);
    state.current = s.previous;
}
pub fn hopHook(gizmo: usize, _: usize, delta: f32) callconv(.{ .x86_fastcall = .{} }) void {
    var s: Scope = undefined;
    s.machine.capture();
    s.source = std.mem.zeroes(types.Source);
    s.token = std.mem.zeroes(Token);
    s.previous = state.current;
    s.gizmo = gizmo;
    s.delta = delta;
    s.inputs_allocation = 0;
    s.bindings_allocation = 0;
    s.bound = coherent_frame_get(&s.token, 4) != 0;
    s.clock = win.load(u32, 0xfb4b6c);
    state.current = &s;
    _ = constructor_lexical_seh(@intFromPtr(&s), invokeHop, abortHop);
    state.current = s.previous;
    s.machine.restore();
}
pub export fn native_spellit_pose_input(gizmo: usize) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = state.current orelse return;
    if (!s.bound) return;
    if (s.gizmo != gizmo or !state.live(s) or native_spellit_source_revalidate(&s.source) == 0) {
        state.reject(s, 9, p.SYNC_PHYSICS_SPELLIT_POSE);
        return;
    }
    const selected = win.load(usize, gizmo + 0x21c);
    var piece: types.Piece = undefined;
    if (native_spellit_piece_resolve(&s.source, selected, &piece) == 0) {
        state.reject(s, 10, p.SYNC_PHYSICS_SPELLIT_POSE);
        return;
    }
    var input = std.mem.zeroes(p.SyncPhysicsChoice);
    input.kind = p.SYNC_PHYSICS_SPELLIT_POSE;
    input.site = 0x8406b2;
    const v = &input.payload.spellit_pose;
    v.clock = s.clock;
    v.position = win.load([3]f32, selected + 0xd0);
    v.last_time = win.load(f32, selected + 0xf4);
    v.source_name = s.source.key.name;
    v.gizmo_class = s.source.key.gizmo_class;
    v.gizmo_ordinal = s.source.key.gizmo_ordinal;
    v.resource_name = piece.key.resource;
    v.poi_name = piece.key.poi_name;
    v.poi_ordinal = @truncate(piece.key.poi_ordinal);
    v.piece_ordinal = @truncate(piece.key.piece_ordinal);
    const before = input;
    if (physics_world_input(&input, &s.token) != 1) {
        state.reject(s, 11, input.kind);
        return;
    }
    if (!state.live(s)) {
        state.reject(s, 12, input.kind);
        return;
    }
    if (win.load(usize, gizmo + 0x21c) != selected or native_spellit_source_revalidate(&s.source) == 0 or native_spellit_piece_revalidate(&s.source, &piece) == 0 or !physics.sameSource(&before, &input) or !equal(&before.payload.spellit_pose.position, &win.load([3]f32, selected + 0xd0)) or !equal(&before.payload.spellit_pose.last_time, &win.load(f32, selected + 0xf4))) {
        state.reject(s, 12, input.kind);
        return;
    }
    state.clonewars_spellit_hop_debug[1] +%= 1;
    if (!equal(&v.position, &before.payload.spellit_pose.position)) state.clonewars_spellit_hop_debug[2] +%= 1;
    win.store([3]f32, selected + 0xd0, v.position);
    win.store(f32, selected + 0xf4, v.last_time);
}
pub fn query(target: usize, original: Query, kind: u32, site: u32) u32 {
    var machine: Machine = undefined;
    machine.capture();
    const scope = state.current;
    var piece: types.Piece = undefined;
    const bound = scope != null and scope.?.bound;
    if (bound) {
        const s = scope.?;
        if (!state.live(s) or native_spellit_source_revalidate(&s.source) == 0) {
            state.reject(s, 6, kind);
            machine.restore();
            return 0;
        }
        const selected = win.load(usize, s.gizmo + 0x21c);
        if (native_spellit_piece_resolve(&s.source, selected, &piece) == 0 or target != (if (kind == p.SYNC_PHYSICS_SPELLIT_ENTITY) piece.live_record else piece.receiver)) {
            state.reject(s, 7, kind);
            machine.restore();
            return 0;
        }
    }
    machine.restore();
    var result = original(target);
    machine.capture();
    if (bound) {
        const s = scope.?;
        var selected: usize = 0;
        if (state.live(s) and native_spellit_source_revalidate(&s.source) != 0) selected = win.load(usize, s.gizmo + 0x21c);
        if (selected != piece.piece) {
            state.reject(s, 8, kind);
            machine.restore();
            return result;
        }
        var input = choice(s, kind, @intFromBool(result != 0), &piece);
        if (site != 0) input.site = site;
        if (resolveInput(s, &input, &piece)) result = input.payload.world.value;
    }
    machine.restore();
    return result;
}
fn entityHook(record: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) u32 {
    return query(record, @ptrFromInt(0x7ab040), p.SYNC_PHYSICS_SPELLIT_ENTITY, 0);
}
pub fn selectionInput(gizmo: usize, site: u32) void {
    const s = state.current orelse return;
    if (!s.bound) return;
    var input = std.mem.zeroes(p.SyncPhysicsChoice);
    input.kind = p.SYNC_PHYSICS_SPELLIT_SELECTION;
    input.site = site;
    const v = &input.payload.spellit_selection;
    if (s.gizmo != gizmo or !state.live(s) or native_spellit_selection_snapshot(&s.source, &v.candidate_count, &v.eligibility) == 0) {
        state.reject(s, 13, input.kind);
        return;
    }
    v.clock = s.clock;
    v.engine_seed = win.load(u32, 0xea178c);
    v.source_name = s.source.key.name;
    v.gizmo_class = s.source.key.gizmo_class;
    v.gizmo_ordinal = s.source.key.gizmo_ordinal;
    v.piece_count = s.source.piece_count;
    const before = input;
    if (physics_world_input(&input, &s.token) != 1) {
        state.reject(s, 14, input.kind);
        return;
    }
    var candidates: u32 = 0;
    var eligibility: [4]u32 = undefined;
    if (!state.live(s) or native_spellit_selection_snapshot(&s.source, &candidates, &eligibility) == 0 or candidates != before.payload.spellit_selection.candidate_count or !equal(&eligibility, &before.payload.spellit_selection.eligibility) or !physics.sameSource(&before, &input) or win.load(u32, 0xea178c) != before.payload.spellit_selection.engine_seed) {
        state.reject(s, 15, input.kind);
        return;
    }
    win.store(u32, 0xea178c, v.engine_seed);
    state.clonewars_spellit_hop_debug[1] +%= 1;
    if (v.engine_seed != before.payload.spellit_selection.engine_seed) state.clonewars_spellit_hop_debug[2] +%= 1;
}
pub fn selectionHook(gizmo: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) usize {
    var machine: Machine = undefined;
    machine.capture();
    selectionInput(gizmo, @truncate(@returnAddress() -% 5));
    machine.restore();
    const select: *const fn (usize) callconv(.{ .x86_thiscall = .{} }) usize = @ptrFromInt(0x7da280);
    const result = select(gizmo);
    machine.capture();
    machine.restore();
    return result;
}
fn enabledHook(receiver: usize, table: usize) callconv(.{ .x86_fastcall = .{} }) u32 {
    const original = win.load(Query, table + 0x1c);
    const site: u32 = @truncate(@returnAddress());
    if (state.current) |s| if (s.bound and (site == 0x812d8c or site == 0x812e02)) {
        state.clonewars_spellit_completion_debug[if (site == 0x812d8c) 2 else 3] +%= 1;
    };
    return query(receiver, original, p.SYNC_PHYSICS_SPELLIT_ENABLED, site);
}
pub export fn native_spellit_receiver_flags(receiver: usize, site: u32) u32 {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const local: u32 = win.load(u8, receiver + 0x183) & 4;
    var result = local;
    if (state.current) |s| if (s.bound) {
        var piece: types.Piece = undefined;
        var selected: usize = 0;
        if (state.live(s) and native_spellit_source_revalidate(&s.source) != 0) selected = win.load(usize, s.gizmo + 0x21c);
        if (selected == 0 or native_spellit_piece_resolve(&s.source, selected, &piece) == 0 or piece.receiver != receiver) state.reject(s, 21, p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS) else {
            var input = choice(s, p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS, local, &piece);
            input.site = site;
            state.clonewars_spellit_completion_debug[if (site == 0x812d7a) 0 else 1] +%= 1;
            if (resolveInput(s, &input, &piece)) {
                result = input.payload.world.value;
                if (result != local) state.clonewars_spellit_completion_debug[4] +%= 1;
            }
        }
    };
    return result;
}
pub export fn spellit_input_install() c_int {
    if (installed) return 1;
    var trace: [8]u8 = undefined;
    trace_native = GetEnvironmentVariableA("CLONEWARS_SPELLIT_SOURCE_TRACE", &trace, trace.len) > 0;
    const sites = [_]usize{ 0x861019, 0x8407cf, 0x840856, 0x812d87, 0x812dfd, 0x812d7a, 0x812df0, 0x8406b2, 0x8406a7, 0x840790, 0x840b93 };
    const enabled = "\x8b\x42\x1c\xff\xd0";
    const flags = "\xf6\x81\x83\x01\x00\x00\x04";
    const prefixes = [_][]const u8{ "\xe8\x42\xf6\xfd\xff", "\xe8\x6c\xa8\xf6\xff", enabled, enabled, enabled, flags, flags, "\x8b\x8b\x1c\x02\x00\x00", "\xe8\xd4\x9b\xf9\xff", "\xe8\xeb\x9a\xf9\xff", "\xe8\xe8\x96\xf9\xff" };
    const hooks = [_]usize{ @intFromPtr(&hopHook), @intFromPtr(&entityHook), @intFromPtr(&enabledHook), @intFromPtr(&enabledHook), @intFromPtr(&enabledHook), @intFromPtr(&native_spellit_timeout_flags_bridge), @intFromPtr(&native_spellit_finish_flags_bridge), @intFromPtr(&native_spellit_pose_bridge), @intFromPtr(&selectionHook), @intFromPtr(&selectionHook), @intFromPtr(&selectionHook) };
    for (sites, prefixes) |site, prefix| if (!win.accessible(site, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..prefix.len], prefix)) return 0;
    var protections: [11]u32 = undefined;
    var acquired: usize = 0;
    while (acquired < sites.len) : (acquired += 1) {
        if (win.VirtualProtect(sites[acquired], prefixes[acquired].len, 0x40, &protections[acquired]) == 0) break;
    }
    if (acquired != sites.len) {
        while (acquired != 0) {
            acquired -= 1;
            var ignored: u32 = 0;
            _ = win.VirtualProtect(sites[acquired], prefixes[acquired].len, protections[acquired], &ignored);
        }
        return 0;
    }
    for (sites, prefixes, hooks) |site, prefix, hook| {
        win.store(u8, site, if (site == 0x8406b2 or site == 0x812d7a or site == 0x812df0) 0xe9 else 0xe8);
        win.store(u32, site + 1, @truncate(hook -% site -% 5));
        for (5..prefix.len) |i| win.store(u8, site + i, 0x90);
        _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, prefix.len);
    }
    // Several patches share a page; unwind protection changes in acquisition order reversed.
    while (acquired != 0) {
        acquired -= 1;
        var ignored: u32 = 0;
        _ = win.VirtualProtect(sites[acquired], prefixes[acquired].len, protections[acquired], &ignored);
    }
    installed = true;
    return 1;
}
comptime {
    _ = @import("spellit_bridges.zig");
}
