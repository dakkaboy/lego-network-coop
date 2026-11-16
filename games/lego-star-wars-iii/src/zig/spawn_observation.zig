const std = @import("std");
const p = @import("protocol.zig");
const win = @import("win32.zig");
const obs = @import("observation.zig");
const snapshot = @import("combat_snapshot.zig");
const Identity = @import("entity_types.zig").SpawnIdentity;
const Source = p.SyncSpawnSource;
const Machine = @import("machine_environment.zig").Environment;
pub const BirthRecord = extern struct { committed: u32, id: u32, parent: u32, thread: u32, caller: u32, phase: u32, clock: u32, rng_game: u32, rng_engine: u32, arguments: [12]u32, position: [3]f32, position_valid: u32, result: u32, slot: u32, generation: u32, character: u32, clock_after: u32, rng_game_after: u32, rng_engine_after: u32, producer_event: u32, producer_transaction: u32, recipe_name: [64]u8, recipe_name_valid: u32 };
pub const ProducerRecord = extern struct { committed: u32, id: u32, parent: u32, kind: u32, thread: u32, caller: u32, phase: u32, clock: u32, rng_game: u32, rng_engine: u32, producer: u32, type_hash: u32, module_id: u32, script_reference: u32, script_id: u32, generation: u32, vtable: u32, base_recipe_pointer: u32, base_recipe_name: [64]u8, arguments: [3]u32, position: [3]f32, position_valid: u32, before: [4]u32, after: [4]u32, result: u32, clock_after: u32, rng_game_after: u32, rng_engine_after: u32, native_level: u32, native_phase: u32, area_local: u32 };
pub export var clonewars_spawn_observer_enabled: i32 = 0;
pub export var clonewars_spawn_observer_count: u32 = 0;
pub export var clonewars_spawn_observer_installed: i32 = 0;
pub export var clonewars_spawn_observer_install_thread: u32 = 0;
pub export var clonewars_spawn_observer_stride: u32 = @sizeOf(BirthRecord);
pub export var clonewars_spawn_observer: [256]BirthRecord = std.mem.zeroes([256]BirthRecord);
pub export var clonewars_producer_observer_count: u32 = 0;
pub export var clonewars_producer_observer_installed: i32 = 0;
pub export var clonewars_producer_observer_stride: u32 = @sizeOf(ProducerRecord);
pub export var clonewars_producer_observer_capacity: u32 = 4096;
pub export var clonewars_producer_observer: [4096]ProducerRecord = std.mem.zeroes([4096]ProducerRecord);
const State = struct { observation: u32, producer: u32, transaction: u32, child: Source, pair: Source, rider: usize, group: usize, order: Source };
threadlocal var current = std.mem.zeroes(State);
threadlocal var flow_active: i32 = 0;
var order_area: u32 = 0;
var order_epoch: u32 = 0;
var order_serial_base: u32 = 0;
const Kind = enum { birth, produce, child, pair, gun, mount, crew, order_constructor, order_spawn, group };
var originals: [10]usize = @splat(0);
extern fn entities_spawn_source(usize, *u32) Source;
extern fn entities_set_spawn_context(Identity) Identity;
extern fn entities_note_spawn_source(usize, u32, Source) void;
extern fn entities_observed_generation(usize) u32;
extern fn game_sync_epoch() u32;
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
fn registered(producer: u32) u32 {
    var entry: [4]u32 = undefined;
    const address = obs.word(producer +% 0x68);
    if (!obs.read(address, std.mem.asBytes(&entry)) or entry[0] != obs.word(producer +% 8) or entry[1] != obs.word(producer +% 0x6c) or entry[2] != producer or entry[3] != 4) return 0;
    return entry[0];
}
fn producerSource(producer: u32) Source {
    const id = registered(producer);
    var serial: u32 = 0;
    return if (id != 0 and obs.read(producer +% 0x374, std.mem.asBytes(&serial))) .{ .producer = id, .serial = serial } else std.mem.zeroes(Source);
}
fn pairSource(producer: u32) Source {
    var member: u32 = 0;
    if (obs.word(producer) != 0xae3c44 or !obs.read(producer +% 0x98, std.mem.asBytes(&member)) or member >= 4) return std.mem.zeroes(Source);
    const id = registered(producer);
    return if (id != 0) .{ .producer = id, .serial = member } else std.mem.zeroes(Source);
}
fn gunIdentity(owner: usize, socket: u32) Identity {
    var identity = std.mem.zeroes(Identity);
    if (owner == 0 or socket < 9 or socket > 11) return identity;
    const parent = entities_spawn_source(owner, &identity.site);
    if (parent.producer == 0 or identity.site & 0x20000000 != 0 or parent.serial > std.math.maxInt(u32) / 4) return std.mem.zeroes(Identity);
    identity.site |= 0x20000000;
    identity.source = .{ .producer = parent.producer, .serial = parent.serial * 4 + (socket - 9) };
    return identity;
}
fn spawnIdentity(caller: u32, party: u32) Identity {
    var identity = std.mem.zeroes(Identity);
    identity.site = caller -% 0x400000;
    if (caller == 0x4df59a or caller == 0x47e3df) {
        identity.source = entities_spawn_source(current.rider, &identity.site);
        identity.site |= if (caller == 0x4df59a) @as(u32, 0x80000000) else 0x40000000;
    } else if (caller == 0x5501f4 or caller == 0x550729) identity.source = current.order else if (caller == 0x4e63bd or caller == 0x4e644f) identity.source = current.pair else if (caller == 0x4e2788 or caller == 0x4e2a80 or caller == 0x4e2aed or caller == 0x4e2b57) identity.source = current.child else if (party < 8) identity.source = .{ .producer = 1, .serial = party };
    return identity;
}
const counters = [_]u32{ 0x360, 0x374, 0x348, 0x350 };
fn producerBegin(r: *ProducerRecord, producer: u32, kind: u32, caller: u32, args: [3]u32) void {
    r.* = std.mem.zeroes(ProducerRecord);
    r.id = obs.increment(&clonewars_producer_observer_count);
    r.parent = current.producer;
    r.kind = kind;
    r.caller = caller;
    r.thread = win.GetCurrentThreadId();
    r.phase = @intFromBool(flow_active == 0);
    r.clock = obs.word(0xfb4b6c);
    r.rng_game = obs.word(0xe637b4);
    r.rng_engine = obs.word(0xea178c);
    r.area_local = obs.word(0xfb4a20);
    r.native_level = snapshot.level();
    r.native_phase = snapshot.phase();
    r.producer = producer;
    r.vtable = obs.word(producer);
    r.type_hash = obs.word(producer +% 4);
    r.module_id = obs.word(producer +% 8);
    r.script_reference = obs.word(producer +% 0x68);
    r.script_id = obs.word(r.script_reference);
    r.generation = obs.word(producer +% 0x6c);
    r.base_recipe_pointer = obs.word(producer +% 0xb0);
    if (r.base_recipe_pointer != 0) _ = obs.read(r.base_recipe_pointer, &r.base_recipe_name);
    r.arguments = args;
    if (kind == 1) r.position_valid = @intFromBool(obs.read(args[0], std.mem.asBytes(&r.position)));
    for (counters, &r.before) |offset, *value| value.* = obs.word(producer +% offset);
}
fn producerFinish(r: *ProducerRecord, result: u32) void {
    r.result = result;
    r.clock_after = obs.word(0xfb4b6c);
    r.rng_game_after = obs.word(0xe637b4);
    r.rng_engine_after = obs.word(0xea178c);
    for (counters, &r.after) |offset, *value| value.* = obs.word(r.producer +% offset);
    obs.publish(&clonewars_producer_observer[(r.id -% 1) % 4096], r);
}
const Scope = struct { machine: Machine, previous: State, restore_mask: u8, kind: Kind, args: [12]u32, caller: u32, result: u32, tracing: bool, context_bound: bool, previous_context: Identity, identity: Identity, birth: BirthRecord, producer: ProducerRecord };
fn restore(s: *Scope) void {
    if (s.context_bound) {
        _ = entities_set_spawn_context(s.previous_context);
        s.context_bound = false;
    }
    inline for (.{ "observation", "producer", "transaction", "child", "pair", "rider", "group", "order" }, 0..) |field, i| {
        if (s.restore_mask & (@as(u8, 1) << @intCast(i)) != 0) @field(current, field) = @field(s.previous, field);
    }
}
fn abort(address: usize) callconv(.c) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    restore(@ptrFromInt(address));
}
fn noteGroup(group: u32, actor: usize) void {
    const manager = obs.word(group +% 0xcc);
    const bank = obs.word(group +% 0x78);
    const groups = obs.word(manager +% 0x16dc);
    const members = (obs.word(group +% 0xec) >> 24) & 0xff;
    if (manager == 0 or bank == 0 or group < manager +% 0x16e0) return;
    const offset = group -% manager -% 0x16e0;
    if (offset % 0x140 != 0 or offset / 0x140 >= groups) return;
    for (0..members) |member| if (obs.word(bank +% member *% 0x130 +% 0x11c) == actor) {
        entities_note_spawn_source(actor, 0xcb8c1, .{ .producer = offset / 0x140 + 1, .serial = @intCast(member) });
        return;
    };
}
fn invoke(address: usize) callconv(.c) usize {
    const s: *Scope = @ptrFromInt(address);
    const a = &s.args;
    s.machine.restore();
    s.result = switch (s.kind) {
        .birth => @as(*const fn (u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32) callconv(.c) u32, @ptrFromInt(originals[0]))(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]),
        .produce => @as(*const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) u32, @ptrFromInt(originals[1]))(a[0], a[1], a[2]),
        .child => blk: {
            @as(*const fn (usize, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) void, @ptrFromInt(originals[2]))(a[0], a[1], a[2], a[3]);
            break :blk 0;
        },
        .pair => blk: {
            @as(*const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) void, @ptrFromInt(0x4e6330))(a[0], a[1]);
            break :blk 0;
        },
        .gun => @as(*const fn (usize, usize, usize, u32) callconv(.{ .x86_thiscall = .{} }) u32, @ptrFromInt(0x41af10))(a[0], a[1], a[2], a[3]),
        .mount => blk: {
            @as(*const fn (usize) callconv(.c) void, @ptrFromInt(originals[5]))(a[0]);
            break :blk 0;
        },
        .crew => @as(*const fn (usize, usize) callconv(.{ .x86_thiscall = .{} }) u32, @ptrFromInt(originals[6]))(a[0], a[1]),
        .order_constructor => @as(*const fn (usize, u32, u32, u32, u32, u32, u32, u32) callconv(.{ .x86_thiscall = .{} }) u32, @ptrFromInt(originals[7]))(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]),
        .order_spawn => blk: {
            @as(*const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) void, @ptrFromInt(originals[8]))(a[0], a[1], a[2]);
            break :blk 0;
        },
        .group => @as(*const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) u8, @ptrFromInt(originals[9]))(a[0], a[1]),
    };
    s.machine.capture();
    if (s.kind == .birth and s.result != 0 and s.caller == 0x4cb8c1) current.group = s.result;
    if (s.kind == .gun and s.result != 0 and s.identity.source.producer != 0) entities_note_spawn_source(a[2], s.identity.site, s.identity.source);
    if (s.kind == .group and s.result != 0 and current.group != 0) noteGroup(a[0], current.group);
    restore(s);
    if (s.tracing) switch (s.kind) {
        .birth => {
            const r = &s.birth;
            r.result = s.result;
            const pool = obs.word(0xfb2f60);
            const count = obs.word(0xfb2e3c);
            const offset = s.result -% pool;
            r.slot = if (s.result != 0 and pool != 0 and offset % 0x1440 == 0 and offset / 0x1440 < count) offset / 0x1440 else std.math.maxInt(u32);
            r.generation = entities_observed_generation(s.result);
            var character: i16 = -1;
            if (s.result != 0) _ = obs.read(s.result +% 0xdc0, std.mem.asBytes(&character));
            r.character = @bitCast(@as(i32, character));
            r.clock_after = obs.word(0xfb4b6c);
            r.rng_game_after = obs.word(0xe637b4);
            r.rng_engine_after = obs.word(0xea178c);
            obs.publish(&clonewars_spawn_observer[(r.id -% 1) % 256], r);
        },
        .produce, .child => producerFinish(&s.producer, s.result),
        else => {},
    };
    return s.result;
}
fn run(s: *Scope) u32 {
    s.previous = current;
    s.restore_mask = 0;
    s.result = 0;
    s.tracing = clonewars_spawn_observer_enabled != 0;
    s.context_bound = false;
    const a = &s.args;
    switch (s.kind) {
        .birth => {
            if (s.tracing) {
                s.birth = std.mem.zeroes(BirthRecord);
                const r = &s.birth;
                r.id = obs.increment(&clonewars_spawn_observer_count);
                r.parent = current.observation;
                r.thread = win.GetCurrentThreadId();
                r.caller = s.caller;
                r.phase = @intFromBool(flow_active == 0);
                r.producer_event = current.producer;
                r.producer_transaction = current.transaction;
                r.clock = obs.word(0xfb4b6c);
                r.rng_game = obs.word(0xe637b4);
                r.rng_engine = obs.word(0xea178c);
                r.arguments = a.*;
                r.position_valid = @intFromBool(obs.read(a[1], std.mem.asBytes(&r.position)));
                if (a[3] != 0) r.recipe_name_valid = @intFromBool(obs.read(a[3], &r.recipe_name));
                current.observation = r.id;
                s.restore_mask = 1;
            }
            s.previous_context = entities_set_spawn_context(spawnIdentity(s.caller, a[11]));
            s.context_bound = true;
        },
        .produce => if (s.tracing) {
            producerBegin(&s.producer, a[0], 0, s.caller, a[1..4].*);
            current.producer = s.producer.id;
            current.transaction = s.producer.id;
            s.restore_mask = 6;
        },
        .child => {
            if (s.tracing) {
                producerBegin(&s.producer, a[0], 1, s.caller, a[1..4].*);
                current.producer = s.producer.id;
            }
            current.child = producerSource(a[0]);
            s.restore_mask = 10;
        },
        .pair => {
            current.pair = pairSource(a[0]);
            s.restore_mask = 16;
        },
        .gun => {
            s.identity = gunIdentity(obs.word(a[1] +% 0x514), a[3]);
        },
        .mount => {
            current.rider = a[0];
            s.restore_mask = 32;
        },
        .crew => {
            current.rider = a[1];
            s.restore_mask = 32;
        },
        .order_constructor => {
            const area = obs.word(0xfb4a20);
            const epoch = game_sync_epoch();
            if (area != order_area or epoch != order_epoch) {
                order_area = area;
                order_epoch = epoch;
                order_serial_base = obs.word(0xcec39c);
            }
        },
        .order_spawn => {
            const team = obs.word(a[0] +% 0x80);
            const descriptor = if (team != 0) obs.word(team +% 0x1c) else 0;
            var slot: u32 = 0;
            var serial: u32 = 0;
            current.order = std.mem.zeroes(Source);
            if (obs.word(team) == 0xaef0fc and descriptor != 0 and obs.read(descriptor +% 0x30, std.mem.asBytes(&slot)) and slot < p.SYNC_MAX_RTS_TEAMS and obs.read(a[0] +% 0x5e8, std.mem.asBytes(&serial))) current.order = .{ .producer = slot + 1, .serial = serial -% order_serial_base };
            s.restore_mask = 128;
        },
        .group => {
            current.group = 0;
            s.restore_mask = 64;
        },
    }
    _ = constructor_lexical_seh(@intFromPtr(s), invoke, abort);
    s.machine.restore();
    return s.result;
}
fn birthHook(a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32, a6: u32, a7: u32, a8: u32, a9: u32, a10: u32, a11: u32) callconv(.c) u32 {
    var s: Scope = undefined;
    s.machine.capture();
    s.kind = .birth;
    s.args = .{ a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11 };
    s.caller = @truncate(@returnAddress());
    return run(&s);
}
fn make(s: *Scope, kind: Kind, args: []const u32, caller: usize) void {
    s.kind = kind;
    @memset(&s.args, 0);
    @memcpy(s.args[0..args.len], args);
    s.caller = @truncate(caller);
}
fn produceHook(object: usize, _: usize, count: u32, initial: u32) callconv(.{ .x86_fastcall = .{} }) u32 {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .produce, &.{ @truncate(object), count, initial }, @returnAddress());
    return run(&s);
}
fn childHook(object: usize, _: usize, position: u32, yaw: u32, aux: u32) callconv(.{ .x86_fastcall = .{} }) void {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .child, &.{ @truncate(object), position, yaw, aux }, @returnAddress());
    _ = run(&s);
}
fn pairHook(object: usize, _: usize, descriptor: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .pair, &.{ @truncate(object), @truncate(descriptor) }, @returnAddress());
    _ = run(&s);
}
fn gunHook(mount: usize, _: usize, producer: usize, gun: usize, socket: u32) callconv(.{ .x86_fastcall = .{} }) u32 {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .gun, &.{ @truncate(mount), @truncate(producer), @truncate(gun), socket }, @returnAddress());
    return run(&s);
}
fn mountHook(rider: usize) callconv(.c) void {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .mount, &.{@truncate(rider)}, @returnAddress());
    _ = run(&s);
}
fn crewHook(context: usize, _: usize, vehicle: usize) callconv(.{ .x86_fastcall = .{} }) u32 {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .crew, &.{ @truncate(context), @truncate(vehicle) }, @returnAddress());
    return run(&s);
}
fn constructorHook(order: usize, _: usize, a0: u32, a1: u32, a2: u32, a3: u32, a4: u32, a5: u32, a6: u32) callconv(.{ .x86_fastcall = .{} }) u32 {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .order_constructor, &.{ @truncate(order), a0, a1, a2, a3, a4, a5, a6 }, @returnAddress());
    return run(&s);
}
fn orderHook(order: usize, _: usize, recipe: u32, transform: u32) callconv(.{ .x86_fastcall = .{} }) void {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .order_spawn, &.{ @truncate(order), recipe, transform }, @returnAddress());
    _ = run(&s);
}
fn groupHook(group: usize, _: usize, party: u32) callconv(.{ .x86_fastcall = .{} }) u8 {
    var s: Scope = undefined;
    s.machine.capture();
    make(&s, .group, &.{ @truncate(group), party }, @returnAddress());
    return @truncate(run(&s));
}
pub export fn spawn_observer_flow(value: c_int) void {
    flow_active = value;
}
fn installCall(site: usize, expected: []const u8, hook: usize) bool {
    if (!win.accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected)) return false;
    var old: u32 = 0;
    if (win.VirtualProtect(site, 5, 0x40, &old) == 0) return false;
    win.store(u32, site + 1, @truncate(hook -% site -% 5));
    const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), site, 5) != 0;
    var ignored: u32 = 0;
    return win.VirtualProtect(site, 5, old, &ignored) != 0 and flushed;
}
fn producerInstall() bool {
    const addresses = [_]usize{ 0x4fd8f0, 0x4e2730, 0x4cb710, 0x4df470, 0x47e1a0, 0x556d60, 0x550df0 };
    const high = "\x55\x8b\xec\x83\xe4\xf0";
    const prefixes = [_][]const u8{ high, "\x83\xec\x60\xa1\xbc\xd2\xe8\x00", high, "\x56\x8b\x35\x20\x4a\xfb\x00", "\x6a\xff\x68\x5c\xd8\xa9\x00", high, high };
    const hooks = [_]usize{ @intFromPtr(&produceHook), @intFromPtr(&childHook), @intFromPtr(&groupHook), @intFromPtr(&mountHook), @intFromPtr(&crewHook), @intFromPtr(&constructorHook), @intFromPtr(&orderHook) };
    const kinds = [_]Kind{ .produce, .child, .group, .mount, .crew, .order_constructor, .order_spawn };
    const pair = "\xe8\x74\xfd\xff\xff";
    const gun = "\xe8\x9a\x58\xfd\xff";
    if (!win.accessible(0x4e65b7, 5, false) or !win.accessible(0x445671, 5, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(0x4e65b7))[0..5], pair) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(0x445671))[0..5], gun)) return false;
    for (addresses, prefixes) |address, prefix| if (!win.accessible(address, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..prefix.len], prefix)) return false;
    for (addresses, prefixes, hooks, kinds, 0..) |address, prefix, hook, kind, i| {
        originals[@backingInt(kind)] = obs.install(address, prefix, hook) orelse return false;
        if (i < 2) clonewars_producer_observer_installed |= @as(i32, 1) << @intCast(i);
    }
    return installCall(0x4e65b7, pair, @intFromPtr(&pairHook)) and installCall(0x445671, gun, @intFromPtr(&gunHook));
}
pub export fn spawn_observer_install() c_int {
    const entry: usize = 0x9de240;
    const expected = "\x83\xec\x20\x53\x55";
    if (!win.accessible(entry, 5, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(entry))[0..5], expected)) {
        clonewars_spawn_observer_installed = -1;
        return 0;
    }
    const bridge = win.VirtualAlloc(0, 10, 0x3000, 0x40);
    if (bridge == 0) {
        clonewars_spawn_observer_installed = -2;
        return 0;
    }
    win.store([5]u8, bridge, expected[0..5].*);
    win.store(u8, bridge + 5, 0xe9);
    win.store(u32, bridge + 6, @truncate(entry -% bridge -% 5));
    var old: u32 = 0;
    if (win.VirtualProtect(entry, 5, 0x40, &old) == 0) {
        _ = win.VirtualFree(bridge, 0, 0x8000);
        clonewars_spawn_observer_installed = -3;
        return 0;
    }
    originals[0] = bridge;
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, 10);
    win.store(u8, entry, 0xe9);
    win.store(u32, entry + 1, @truncate(@intFromPtr(&birthHook) -% entry -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), entry, 5);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(entry, 5, old, &ignored);
    clonewars_spawn_observer_install_thread = win.GetCurrentThreadId();
    clonewars_spawn_observer_installed = 1;
    return @intFromBool(producerInstall());
}
comptime {
    std.debug.assert(@sizeOf(BirthRecord) == 204 and @sizeOf(ProducerRecord) == 224);
}
