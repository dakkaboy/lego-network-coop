const std = @import("std");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const snapshot = @import("collision_snapshot.zig");
const t = @import("contact_types.zig");
const Machine = @import("machine_environment.zig").Environment;
const Contact = *const fn (usize, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) u8;
var original: Contact = undefined;
const Scope = struct { machine: Machine, record: t.Entry, previous: ?*Scope, result: u8 };
threadlocal var active: ?*Scope = null;
threadlocal var last_epoch: u32 = 0;
threadlocal var last_sequence: u32 = 0;
threadlocal var frame_ordinal: u32 = 0;
pub export var clonewars_world_contact_enabled: i32 = 0;
pub export var clonewars_world_contact_installed: i32 = 0;
pub export var clonewars_world_contact_entry_count: u32 = 0;
pub export var clonewars_world_contact_query_count: u32 = 0;
pub export var clonewars_world_contact_version: u32 = 1;
pub export var clonewars_world_contact_entry_stride: u32 = @sizeOf(t.Entry);
pub export var clonewars_world_contact_query_stride: u32 = @sizeOf(t.Query);
pub export var clonewars_world_contact_entry_capacity: u32 = 128;
pub export var clonewars_world_contact_query_capacity: u32 = 1024;
pub export var clonewars_world_contact_object_stride: u32 = @sizeOf(t.Object);
pub export var clonewars_world_contact_max_candidates: u32 = 64;
pub export var clonewars_world_contact_entries: [128]t.Entry = std.mem.zeroes([128]t.Entry);
pub export var clonewars_world_contact_queries: [1024]t.Query = std.mem.zeroes([1024]t.Query);
export var world_contact_query_resume: usize = 0x81f7c4;
extern fn game_sync_epoch() u32;
extern fn game_sync_sequence() u32;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
extern fn world_contact_query_thunk() void;
fn headerBefore(h: *t.Header, id: u32, parent: u32, caller: u32, manager: u32, ordinal: u32, args: [6]u32) void {
    h.id = id;
    h.parent = parent;
    h.thread = win.GetCurrentThreadId();
    h.caller = caller;
    h.epoch = game_sync_epoch();
    h.sequence = game_sync_sequence();
    h.ordinal = ordinal;
    h.manager_local = manager;
    h.arguments = args;
    h.clock = obs.word(0xfb4b6c);
    h.rng_game = obs.word(0xe637b4);
    h.rng_engine = obs.word(0xea178c);
    obs.timestamp(&h.qpc_before_low, &h.qpc_before_high);
}
fn headerAfter(h: *t.Header, result: u32) void {
    h.result = result;
    h.clock_after = obs.word(0xfb4b6c);
    h.rng_game_after = obs.word(0xe637b4);
    h.rng_engine_after = obs.word(0xea178c);
    obs.timestamp(&h.qpc_after_low, &h.qpc_after_high);
}
fn objectSnapshot(out: *t.Object, node: u32, object: u32) void {
    out.* = std.mem.zeroes(t.Object);
    out.node_local = node;
    out.pointer_local = object;
    out.raw_valid = @intFromBool(obs.read(object, std.mem.asBytes(&out.raw)));
}
fn candidates(r: *t.Entry) void {
    var node: u32 = 0;
    if (!obs.read(r.header.manager_local +% 0x34, std.mem.asBytes(&node))) {
        r.candidate_status = 2;
        return;
    }
    r.candidate_head = node;
    r.candidate_status = 1;
    while (node != 0) {
        for (r.candidates[0..r.candidate_count]) |candidate| if (candidate.node_local == node) {
            r.candidate_status = 3;
            return;
        };
        if (r.candidate_count == 64) {
            r.candidate_status = 4;
            return;
        }
        var links: [3]u32 = undefined;
        if (!obs.read(node, std.mem.asBytes(&links))) {
            r.candidate_status = 2;
            return;
        }
        const candidate = &r.candidates[r.candidate_count];
        r.candidate_count += 1;
        objectSnapshot(candidate, node, links[2]);
        if (candidate.raw_valid == 0) {
            r.candidate_status = 2;
            return;
        }
        node = links[0];
    }
}
fn publish(target: anytype, r: anytype) void {
    @atomicStore(u32, &target.header.committed, 0, .seq_cst);
    target.* = r.*;
    @atomicStore(u32, &target.header.committed, r.header.id, .seq_cst);
}
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    const r = &s.record;
    const a = &r.header.arguments;
    active = s;
    s.machine.restore();
    s.result = original(r.header.manager_local, a[0], a[1], a[2], a[3], a[4], a[5]);
    s.machine.capture();
    active = s.previous;
    snapshot.shot(&r.source_after, a[0], true);
    headerAfter(&r.header, s.result);
    publish(&clonewars_world_contact_entries[(r.header.id -% 1) % 128], r);
    return s.result;
}
fn abort(address: usize) callconv(.c) void {
    const s: *Scope = @ptrFromInt(address);
    active = s.previous;
}
fn hook(manager: usize, _: usize, a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32) callconv(.{ .x86_fastcall = .{} }) u8 {
    if (clonewars_world_contact_enabled == 0) return original(manager, a0, a1, a2, a3, a4, a5);
    var s: Scope = undefined;
    s.machine.capture();
    s.record = std.mem.zeroes(t.Entry);
    s.previous = active;
    s.result = 0;
    const r = &s.record;
    const epoch = game_sync_epoch();
    const sequence = game_sync_sequence();
    if (last_epoch != epoch or last_sequence != sequence) {
        last_epoch = epoch;
        last_sequence = sequence;
        frame_ordinal = 0;
    }
    frame_ordinal +%= 1;
    headerBefore(&r.header, obs.increment(&clonewars_world_contact_entry_count), if (active) |parent| parent.record.header.id else 0, @truncate(@returnAddress()), @truncate(manager), frame_ordinal, .{ a0, a1, a2, a3, a4, a5 });
    snapshot.shot(&r.source_before, a0, true);
    r.points_valid = @intFromBool(obs.read(a1, std.mem.asBytes(&r.points)));
    r.bounds_valid = @as(u32, @intFromBool(obs.read(a2, std.mem.asBytes(r.bounds[0..3])))) | (@as(u32, @intFromBool(obs.read(a3, std.mem.asBytes(r.bounds[3..6])))) << 1);
    candidates(r);
    _ = constructor_lexical_seh(@intFromPtr(&s), invoke, abort);
    s.machine.restore();
    return s.result;
}
pub export fn world_contact_query_checkpoint(native_stack: usize, result: u32, caller: u32, context: usize) void {
    if (clonewars_world_contact_enabled == 0) return;
    const s = active orelse return;
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var r = std.mem.zeroes(t.Query);
    var args: [6]u32 = @splat(0);
    var regs: [8]u32 = @splat(0);
    r.arguments_valid = @intFromBool(obs.read(native_stack, std.mem.asBytes(&args)));
    r.context_valid = @intFromBool(obs.read(context, std.mem.asBytes(&regs)));
    const parent = &s.record;
    headerBefore(&r.header, obs.increment(&clonewars_world_contact_query_count), parent.header.id, caller, parent.header.manager_local, parent.header.ordinal, args);
    snapshot.shot(&r.source, parent.header.arguments[0], true);
    objectSnapshot(&r.object, 0, if (r.context_valid != 0) regs[1] else 0);
    for (parent.candidates[0..parent.candidate_count]) |candidate| if (r.object.pointer_local != 0 and candidate.pointer_local == r.object.pointer_local) {
        r.object.node_local = candidate.node_local;
        break;
    };
    r.sample_index = if (r.context_valid != 0) regs[5] else std.math.maxInt(u32);
    r.point_local = if (r.context_valid != 0) regs[2] else 0;
    r.center_valid = @intFromBool(obs.read(args[0], std.mem.asBytes(&r.center)));
    r.point_valid = @intFromBool(obs.read(args[3], std.mem.asBytes(&r.point)));
    headerAfter(&r.header, result);
    publish(&clonewars_world_contact_queries[(r.header.id -% 1) % 1024], &r);
}
pub export fn world_contact_observer_install() c_int {
    const entry: usize = 0x81f6c0;
    const site: usize = 0x81f7bf;
    const prefix = "\x51\x8b\x41\x34\x53\x55\x56\x57";
    const query = "\x83\xc4\x18\x85\xc0";
    if (!win.accessible(entry, prefix.len, false) or !win.accessible(site - 5, 10, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(entry))[0..prefix.len], prefix) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..query.len], query) or win.load(u8, site - 5) != 0xe8 or site +% win.load(u32, site - 4) != 0x78e650) {
        clonewars_world_contact_installed = -1;
        return 0;
    }
    const bridge = obs.install(entry, prefix, @intFromPtr(&hook)) orelse {
        clonewars_world_contact_installed = -1;
        return 0;
    };
    original = @ptrFromInt(bridge);
    var old: u32 = 0;
    if (win.VirtualProtect(site, 5, 0x40, &old) == 0) {
        clonewars_world_contact_installed = -1;
        return 0;
    }
    win.store(u8, site, 0xe9);
    win.store(u32, site + 1, @truncate(@intFromPtr(&world_contact_query_thunk) -% site -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), site, 5);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(site, 5, old, &ignored);
    clonewars_world_contact_installed = 3;
    return 1;
}
comptime {
    _ = @import("world_contact_bridge.zig");
}
