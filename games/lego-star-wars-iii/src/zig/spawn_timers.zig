const std = @import("std");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const equal = @import("validation.zig").equal;
const Machine = @import("machine_environment.zig").Environment;
const Update = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const BodyUpdate = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Choose = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) f32;
var original_order: Update = undefined;
var original_generator: Update = undefined;
var original_set: Update = undefined;
var original_body: BodyUpdate = undefined;
var original_visibility: Update = undefined;
var original_choose: Choose = undefined;
const Frame = struct { frame: ?*p.SyncFrame = null, teams: [p.SYNC_MAX_RTS_TEAMS]usize = @splat(0), applied: u32 = 0, choice_cursor: u32 = 0, host: bool = false, failed: bool = false };
var current: Frame = .{};
const Entry = extern struct { id: u32, generation: u32, object: usize, kind: u32, flags: u32 };
const Local = struct { state: p.SyncSpawnTimer, remaining: usize };
pub export var clonewars_rts_spawn_timer_debug: [8]u32 = @splat(0);
pub export var clonewars_module_spawn_timer_debug: [8]u32 = @splat(0);
export var rts_spawn_ground_query: usize = 0x52a580;
extern fn rts_spawn_ground_query_hook() void;
extern fn coherent_frame_get(*Token, u32) c_int;
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn rts_visibility_input_update(usize, u32, ?Update, u32) void;
extern fn rts_body_input_update(usize, u32, u32, BodyUpdate) void;
extern fn rts_order_input_update(usize, u32, Update) void;
extern fn rts_generator_input_update(usize, u32, Update) void;
extern fn rts_visibility_attack_install() c_int;
extern fn rts_order_input_install() c_int;
fn read(comptime T: type, address: usize) T {
    return win.load(T, address);
}
fn accessible(address: usize, size: usize, write: bool) bool {
    return win.accessible(address, size, write);
}
fn registered(object: usize, address: usize, entry: Entry) bool {
    return accessible(object, 0x70, false) and entry.kind == 4 and entry.id != 0 and entry.object == object and read(u32, object + 8) == entry.id and read(usize, object + 0x68) == address and read(u32, object + 0x6c) == entry.generation;
}
fn teamSlot(team: usize) ?u32 {
    if (!accessible(team, 0x1a34, false) or read(u32, team) != 0xaef0fc) return null;
    const descriptor = read(usize, team + 0x1c);
    if (!accessible(descriptor, 0x34, false)) return null;
    const slot = read(u32, descriptor + 0x30);
    return if (slot < p.SYNC_MAX_RTS_TEAMS) slot else null;
}
fn orderTimers(token: *const Token, order: usize) bool {
    const team = read(usize, order + 0x28);
    const slot = teamSlot(team) orelse return false;
    if (current.teams[slot] != 0) return current.teams[slot] == team;
    const timers = team + 0x1a28;
    if (!accessible(timers, 12, true) or coherent_frame_valid(token, 4) == 0) return false;
    const f = current.frame.?;
    if (current.host) {
        if (f.rts_team_timer_count >= p.SYNC_MAX_RTS_TEAMS) return false;
        const remaining = read([3]f32, timers);
        for (remaining) |value| if (!std.math.isFinite(value)) return false;
        f.rts_team_timers[f.rts_team_timer_count] = .{ .slot = slot, .remaining = remaining };
        f.rts_team_timer_count += 1;
        clonewars_rts_spawn_timer_debug[0] +%= 1;
    } else {
        var found: ?*const p.SyncRtsTeamTimers = null;
        for (f.rts_team_timers[0..f.rts_team_timer_count]) |*entry| if (entry.slot == slot) {
            found = entry;
            break;
        };
        const entry = found orelse return false;
        if (!equal(&read([3]f32, timers), &entry.remaining)) clonewars_rts_spawn_timer_debug[2] +%= 1;
        win.store([3]f32, timers, entry.remaining);
        current.applied += 1;
        clonewars_rts_spawn_timer_debug[1] +%= 1;
    }
    current.teams[slot] = team;
    return true;
}
fn timerChoice(token: *const Token, local_value: p.SyncSpawnTimerChoice, remaining: *f32, debug: *[4]u32, module: bool) bool {
    if (!std.math.isFinite(remaining.*) or coherent_frame_valid(token, 4) == 0) return false;
    const f = current.frame.?;
    if (current.host) {
        if (f.spawn_timer_choice_count >= p.SYNC_MAX_SPAWN_TIMER_CHOICES) return false;
        var local = local_value;
        local.remaining = remaining.*;
        f.spawn_timer_choices[f.spawn_timer_choice_count] = local;
        f.spawn_timer_choice_count += 1;
        debug[0] +%= 1;
    } else {
        if (current.choice_cursor >= f.spawn_timer_choice_count) return false;
        const choice = &f.spawn_timer_choices[current.choice_cursor];
        if (choice.kind != local_value.kind or choice.owner != local_value.owner or choice.selector != local_value.selector or choice.serial != local_value.serial) return false;
        if (!equal(remaining, &choice.remaining)) {
            debug[2] +%= 1;
            if (module) clonewars_module_spawn_timer_debug[4..8].* = .{ token.sequence, local_value.owner, @bitCast(remaining.*), @bitCast(choice.remaining) };
        }
        remaining.* = choice.remaining;
        current.choice_cursor += 1;
        debug[1] +%= 1;
    }
    return true;
}
fn rtsChoice(token: *const Token, team: usize, index: u32) bool {
    if (index >= 3) return false;
    const slot = teamSlot(team) orelse return false;
    const address = team + 0x1a28 + index * 4;
    if (!accessible(address, 4, true)) return false;
    var remaining = read(f32, address);
    if (remaining < 2 or remaining > 4) return false;
    if (!timerChoice(token, .{ .kind = p.SYNC_SPAWN_TIMER_RTS, .owner = slot, .selector = index, .serial = 0, .remaining = 0 }, &remaining, clonewars_rts_spawn_timer_debug[4..8], false)) return false;
    win.store(f32, address, remaining);
    return true;
}
fn moduleChoice(token: *const Token, object: usize, remaining: *f32) bool {
    if (!accessible(object, 0x378, false)) return false;
    const registry = read(usize, 0xe906b0);
    const address = read(usize, object + 0x68);
    if (registry == 0 or address == 0) return false;
    const offset = address -% (registry +% 8);
    if (offset % @sizeOf(Entry) != 0 or offset / @sizeOf(Entry) >= p.SYNC_MAX_SPAWN_TIMERS or !accessible(address, @sizeOf(Entry), false)) return false;
    const entry = read(Entry, address);
    if (!registered(object, address, entry)) return false;
    const kind = read(u32, object + 4);
    const serial = read(u32, object + 0x374);
    return kind != 0 and timerChoice(token, .{ .kind = p.SYNC_SPAWN_TIMER_MODULE, .owner = entry.id, .selector = kind, .serial = serial, .remaining = 0 }, remaining, clonewars_module_spawn_timer_debug[0..4], true);
}
fn chooseHook(object: usize) callconv(.{ .x86_thiscall = .{} }) f32 {
    var token: Token = undefined;
    const synchronized = coherent_frame_get(&token, 4) != 0 and token.frame == @intFromPtr(current.frame);
    var remaining = original_choose(object);
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (synchronized and coherent_frame_valid(&token, 4) != 0 and !current.failed and !moduleChoice(&token, object, &remaining)) {
        current.failed = true;
        clonewars_module_spawn_timer_debug[3] +%= 1;
    }
    return remaining;
}
fn setHook(team: usize, index: u32) callconv(.{ .x86_thiscall = .{} }) void {
    var token: Token = undefined;
    const synchronized = coherent_frame_get(&token, 4) != 0 and token.frame == @intFromPtr(current.frame);
    // Both peers retain the native random draw before the cooldown is reconciled.
    original_set(team, index);
    if (synchronized and coherent_frame_valid(&token, 4) != 0 and !current.failed and !rtsChoice(&token, team, index)) {
        current.failed = true;
        clonewars_rts_spawn_timer_debug[7] +%= 1;
    }
}
fn orderHook(order: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    var token: Token = undefined;
    if (coherent_frame_get(&token, 4) != 0 and token.sequence == 1 and token.frame == @intFromPtr(current.frame)) {
        if (current.failed) {
            machine.restore();
            return;
        }
        if (!orderTimers(&token, order)) {
            current.failed = true;
            clonewars_rts_spawn_timer_debug[3] +%= 1;
            machine.restore();
            return;
        }
    }
    machine.restore();
    rts_order_input_update(order, delta, original_order);
}
fn generatorHook(object: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    rts_generator_input_update(object, delta, original_generator);
}
fn visibilityHook(object: usize, delta: u32) callconv(.{ .x86_thiscall = .{} }) void {
    rts_visibility_input_update(object, delta, original_visibility, 0x5525e0);
}
fn bodyHook(object: usize, state: u32, flag: u32) callconv(.{ .x86_thiscall = .{} }) void {
    rts_body_input_update(object, state, flag, original_body);
}
fn less(_: void, a: Local, b: Local) bool {
    return a.state.id < b.state.id;
}
fn collect(entries: usize, timers: *[p.SYNC_MAX_SPAWN_TIMERS]Local, count: *u32) bool {
    if (entries == 0) return true;
    if (!accessible(entries, @sizeOf(Entry) * p.SYNC_MAX_SPAWN_TIMERS, false)) return false;
    for (0..p.SYNC_MAX_SPAWN_TIMERS) |i| {
        const address = entries + i * @sizeOf(Entry);
        const entry = read(Entry, address);
        if (entry.kind != 4 or entry.id == 0 or entry.object == 0) continue;
        if (!accessible(entry.object, 4, false)) return false;
        const vtable = read(u32, entry.object);
        if (vtable != 0xae60c4 and vtable != 0xae62a4 and vtable != 0xae6a94) continue;
        const remaining = entry.object + 0x348;
        if (!registered(entry.object, address, entry) or !accessible(remaining, 4, true)) return false;
        const kind = read(u32, entry.object + 4);
        const value = read(f32, remaining);
        if (kind == 0 or !std.math.isFinite(value)) return false;
        timers[count.*] = .{ .state = .{ .id = entry.id, .type = kind, .remaining = value }, .remaining = remaining };
        count.* += 1;
    }
    std.mem.sortUnstable(Local, timers[0..count.*], {}, less);
    if (count.* > 1) for (1..count.*) |i| {
        if (timers[i - 1].state.id == timers[i].state.id) return false;
    };
    return true;
}
pub export fn spawn_timers_prepare(token: *const Token, frame: *p.SyncFrame, host: c_int) c_int {
    if (token.frame != @intFromPtr(frame) or coherent_frame_valid(token, 2) == 0) return 0;
    current = .{ .frame = frame, .host = host != 0 };
    if (frame.sequence != 1) return 1;
    const registry = read(usize, 0xe906b0);
    const entries = if (registry != 0) registry + 8 else 0;
    var timers: [p.SYNC_MAX_SPAWN_TIMERS]Local = undefined;
    var count: u32 = 0;
    if (!collect(entries, &timers, &count) or coherent_frame_valid(token, 2) == 0) return 0;
    if (host != 0) {
        for (timers[0..count], 0..) |timer, i| frame.spawn_timers[i] = timer.state;
        frame.spawn_timer_count = count;
        return 1;
    }
    if (count != frame.spawn_timer_count) return 0;
    for (timers[0..count], frame.spawn_timers[0..count]) |local, remote| if (remote.id != local.state.id or remote.type != local.state.type) return 0;
    if (registry != read(usize, 0xe906b0) or coherent_frame_valid(token, 2) == 0) return 0;
    for (timers[0..count], frame.spawn_timers[0..count]) |local, remote| win.store(f32, local.remaining, remote.remaining);
    return 1;
}
pub export fn rts_spawn_timers_finish(frame: *const p.SyncFrame) c_int {
    return @intFromBool(current.frame == frame and !current.failed and (current.host or (current.applied == frame.rts_team_timer_count and current.choice_cursor == frame.spawn_timer_choice_count)));
}
fn installHook(address: usize, prefix: []const u8, hook: anytype, original: anytype) bool {
    if (!accessible(address, prefix.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(address))[0..prefix.len], prefix)) return false;
    const bridge = win.VirtualAlloc(0, prefix.len + 5, 0x3000, 0x40);
    if (bridge == 0) return false;
    var old: u32 = 0;
    if (win.VirtualProtect(address, prefix.len, 0x40, &old) == 0) {
        _ = win.VirtualFree(bridge, 0, 0x8000);
        return false;
    }
    @memcpy(@as([*]u8, @ptrFromInt(bridge))[0..prefix.len], prefix);
    win.store(u8, bridge + prefix.len, 0xe9);
    win.store(u32, bridge + prefix.len + 1, @truncate(address -% bridge -% 5));
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), bridge, prefix.len + 5);
    original.* = @ptrFromInt(bridge);
    win.store(u8, address, 0xe9);
    win.store(u32, address + 1, @truncate(@intFromPtr(hook) -% address -% 5));
    win.store(u8, address + 5, 0x90);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), address, prefix.len);
    var ignored: u32 = 0;
    _ = win.VirtualProtect(address, prefix.len, old, &ignored);
    return true;
}
fn installChoose() bool {
    const site: usize = 0x504a20;
    const expected = "\xe8\x6b\xf0\xf7\xff";
    var old: u32 = 0;
    if (!accessible(site, expected.len, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(site))[0..expected.len], expected) or win.VirtualProtect(site, expected.len, 0x40, &old) == 0) return false;
    original_choose = @ptrFromInt(0x483a90);
    win.store(u32, site + 1, @truncate(@intFromPtr(&chooseHook) -% site -% 5));
    const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), site, expected.len) != 0;
    var ignored: u32 = 0;
    return win.VirtualProtect(site, expected.len, old, &ignored) != 0 and flushed;
}
fn installGround() bool {
    const first: usize = 0x548064;
    const second: usize = 0x5489d3;
    const a = "\x8d\x44\x24\x40\x50\xe8\x12\x25\xfe\xff";
    const b = "\x8d\x84\x24\xa0\x00\x00\x00\x50\xe8\xa0\x1b\xfe\xff";
    const span = second - first + b.len;
    var old: u32 = 0;
    if (!accessible(first, span, false) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(first))[0..a.len], a) or !std.mem.eql(u8, @as([*]const u8, @ptrFromInt(second))[0..b.len], b) or win.VirtualProtect(first, span, 0x40, &old) == 0) return false;
    for ([_]usize{ first + 6, second + 9 }) |relative| win.store(u32, relative, @truncate(@intFromPtr(&rts_spawn_ground_query_hook) -% relative -% 4));
    const flushed = win.FlushInstructionCache(win.GetCurrentProcess(), first, span) != 0;
    var ignored: u32 = 0;
    return win.VirtualProtect(first, span, old, &ignored) != 0 and flushed;
}
pub export fn rts_spawn_timers_install() c_int {
    const order = "\x55\x8b\xec\x83\xe4\xf0";
    return @intFromBool(rts_visibility_attack_install() != 0 and installHook(0x5525e0, "\x8b\x91\x38\x02\x00\x00", &visibilityHook, &original_visibility) and installHook(0x544b10, order, &bodyHook, &original_body) and installHook(0x547d30, order, &generatorHook, &original_generator) and rts_order_input_install() != 0 and installHook(0x55e2c0, order, &orderHook, &original_order) and installHook(0x50afc0, "\xd9\x05\x40\x14\xae\x00", &setHook, &original_set) and installChoose() and installGround());
}
comptime {
    asm (
        \\.text
        \\.globl _rts_spawn_ground_query_hook
        \\_rts_spawn_ground_query_hook:
        \\pushl %edx
        \\movl 0xa8(%esp), %edx
        \\movl %edx, 0xc(%eax)
        \\popl %edx
        \\jmpl *_rts_spawn_ground_query
    );
}
