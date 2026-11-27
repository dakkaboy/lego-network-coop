const std = @import("std");
const p = @import("protocol.zig");
const s = @import("reaction_state.zig");
const r = @import("reaction_input.zig");
const choice = @import("reaction_choice.zig");
const receipt = @import("reaction_receipt.zig");
const arena = @import("reaction_arena.zig");
const item = @import("reaction_item_range.zig");
const Token = @import("cohort_types.zig").Token;
const win = s.win;
const support = @import("native_test_support.zig");
const check = support.check;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
comptime {
    _ = @import("reaction.zig");
    _ = @import("lexical_seh.zig");
}
const actor: usize = 0x20000000;
const target: usize = 0x20010000;
const resource: usize = 0x20020000;
const frame: *p.SyncFrame = @ptrFromInt(0x21000000);
var mode: u32 = 0;
var client = false;
var valid = true;
var retained = true;
var clip_available = true;
var available_calls: u32 = 0;
var source: u32 = 23;
var damage_caller: u32 = 0;
var updates: u32 = 0;
var describes: u32 = 0;
var resolves: u32 = 0;
var range_calls: u32 = 0;
var hit_calls: u32 = 0;
var fault: c_int = 0;
var selected_clip: u32 = 0;
export var reaction_fixture_actor: usize = actor;
export var reaction_fixture_clip: u32 = 0;
export var reaction_fixture_draw: u32 = 0;
extern fn invoke_choice() void;
extern fn invoke_draw() void;
comptime {
    asm (
        \\.text
        \\_invoke_choice:
        \\pushl %esi
        \\pushl %edi
        \\subl $84,%esp
        \\movl _reaction_fixture_actor,%esi
        \\movl _reaction_fixture_clip,%eax
        \\movl %eax,76(%esp)
        \\call _reaction_choice_thunk
        \\movl %edi,_reaction_fixture_clip
        \\addl $84,%esp
        \\popl %edi
        \\popl %esi
        \\ret
        \\_invoke_draw:
        \\pushl %esi
        \\subl $84,%esp
        \\movl _reaction_fixture_actor,%esi
        \\movl _reaction_fixture_draw,%eax
        \\call _reaction_damage_draw_thunk
        \\fstp %st(0)
        \\movl 64(%esp),%eax
        \\movl %eax,_reaction_fixture_draw
        \\addl $84,%esp
        \\popl %esi
        \\ret
    );
}
export fn coherent_frame_valid(_: *const Token, _: u32) c_int {
    return @intFromBool(valid);
}
export fn game_sync_native_fault(value: c_int) void {
    fault = value;
}
export fn combat_damage_source_id() u32 {
    return source;
}
export fn combat_damage_native_caller() u32 {
    return damage_caller;
}
export fn combat_damage_source_ready() c_int {
    return 1;
}
export fn entities_update() void {
    updates += 1;
}
export fn entities_observed_generation(_: usize) u32 {
    return 19;
}
export fn entities_allocation_retained(_: usize, _: u32) c_int {
    return @intFromBool(retained);
}
export fn entities_observed_identity(a: usize, slot: *u32, generation: *u32) c_int {
    slot.* = if (a == actor) 7 else 8;
    generation.* = if (client and mode == 15 and a == target) 20 else 19;
    return @intFromBool(a != 0);
}
export fn entities_slot(a: usize) c_int {
    return if (a == actor) 7 else 8;
}
export fn entities_describe(out: *p.SyncActor, a: usize) void {
    describes += 1;
    out.* = std.mem.zeroes(p.SyncActor);
    out.generation = 19;
    out.spawn_tag = 29;
    out.spawn_source = .{ .producer = 31, .serial = 37 };
    out.spawn_position[0] = if (a == actor) 1 else 2;
}
export fn entities_resolve_reference(_: *const p.SyncActor) usize {
    resolves += 1;
    return if (client and mode == 5) 0 else actor;
}
export fn entities_actor(slot: u32, _: u32) usize {
    return if (client and mode == 26 and slot == 7) 0 else if (slot == 7) actor else target;
}
fn available(value: usize, clip: c_int) callconv(.c) u8 {
    check(@src(), value == resource and clip >= 0);
    available_calls += 1;
    return @intFromBool(clip_available);
}
fn nativeRange(a: usize, b: usize, reach: f32) callconv(.c) c_int {
    range_calls += 1;
    if (b == 0) return 0;
    check(@src(), win.load(usize, a + 0x2bc) == b);
    return @intFromBool(@abs(win.load(f32, a + 0x24) - win.load(f32, b + 0x24)) <= reach + win.load(f32, a + 0x1088) + win.load(f32, b + 0x1088));
}
fn nativeHit(a: usize, b: usize, one: u32, flags: u32, zero: u32, last: u32) callconv(.c) u32 {
    check(@src(), a == target and b == actor and one == 1 and flags == (if (mode == 53) @as(u32, 0x100010a) else 0x400000) and zero == 0 and last == 1);
    hit_calls += 1;
    if (mode >= 50 and mode <= 52) {
        check(@src(), win.load(i16, actor + 0x2f4) == 65);
        win.store(i16, actor + 0x2f4, -1);
        selected_clip = if (client) 74 else 73;
        choice.reaction_apply_choice(actor, &selected_clip);
        win.store(i16, actor + 0x2f4, 20);
        win.store(i8, actor + 0xdde, if (client and mode == 51) 1 else 2);
        win.store(f32, actor + 0xd3c, 0.4);
    }
    if (mode == 27) win.RaiseException(0xe1459876, 0, 0, null);
    if (mode == 25 or mode == 53) {
        selected_clip = if (client) 9 else 7;
        choice.reaction_apply_choice(actor, &selected_clip);
    }
    return 13;
}
fn put(address: usize, value: u32) void {
    win.store(u32, address, value);
}
fn bytes(address: usize, length: usize) []u8 {
    return @as([*]u8, @ptrFromInt(address))[0..length];
}
fn jump(address: usize, value: usize) void {
    win.store(u8, address, 0xe9);
    put(address + 1, value -% address -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), address, 5) != 0);
}
fn setup() void {
    valid = true;
    retained = true;
    clip_available = true;
    available_calls = 0;
    client = false;
    source = 23;
    damage_caller = 0;
    updates = 0;
    describes = 0;
    resolves = 0;
    range_calls = 0;
    hit_calls = 0;
    fault = 0;
    selected_clip = 0;
    @memset(std.mem.asBytes(frame), 0);
    @memset(bytes(actor, 0x2000), 0);
    @memset(bytes(target, 0x2000), 0);
    put(actor + 0x50, 3);
    win.store(i16, actor + 0xdc0, 12);
    win.store(i16, actor + 0x2f4, 2);
    put(actor + 0xf04, resource);
    win.store(i8, actor + 0xdde, 5);
    win.store(f32, actor + 0xd3c, 1);
    put(actor + 0x2bc, target);
    win.store(f32, actor + 0x24, 1);
    win.store(f32, target + 0x24, 3);
    win.store(f32, actor + 0x1088, 0.25);
    win.store(f32, target + 0x1088, 0.5);
    put(0xe637b4, 71);
    put(0xea178c, 73);
    frame.epoch = 100 + mode;
    frame.sequence = 83;
    frame.level = 12;
}
const Snapshot = extern struct {
    finish: c_int,
    drain: c_int,
    duplicate: c_int,
    result: c_int,
    fault: c_int,
    clip: u32,
    draw: u32,
    updates: u32,
    describes: u32,
    resolves: u32,
    range_calls: u32,
    hit_calls: u32,
    timer: u32,
    count: u32,
    debug: [20]u32,
    draw_debug: [8]u32,
    range_debug: [8]u32,
    range_mask: u32,
    failure: [14]u32,
    correction: [12]u32,
    receipt_debug: [10]u32,
    entries: [2]p.SyncReactionChoice,
    range_failure: [2]p.SyncReactionChoice,
    actual: p.SyncReactionHitOutcome,
    expected: p.SyncReactionHitOutcome,
    receipt: s.Receipt,
};
fn snapshot(out: *Snapshot) void {
    out.fault = fault;
    out.clip = selected_clip;
    out.updates = updates;
    out.describes = describes;
    out.resolves = resolves;
    out.range_calls = range_calls;
    out.hit_calls = hit_calls;
    out.timer = win.load(u32, actor + 0xd3c);
    out.count = frame.reaction_count;
    out.entries = frame.reactions[0..2].*;
    out.debug = s.clonewars_reaction_debug;
    out.draw_debug = s.clonewars_damage_draw_debug;
    out.range_debug = s.clonewars_item_range_debug;
    out.failure = s.clonewars_reaction_failure;
    out.correction = s.clonewars_reaction_first_correction;
    out.receipt_debug = s.clonewars_reaction_receipt_debug;
    out.range_failure = s.clonewars_item_range_failure;
    out.range_mask = s.clonewars_item_range_failure_mask;
    out.actual = s.clonewars_reaction_hit_actual;
    out.expected = s.clonewars_reaction_hit_expected;
}
fn clearDebug() void {
    s.clonewars_reaction_debug = @splat(0);
    s.clonewars_damage_draw_debug = @splat(0);
    s.clonewars_item_range_debug = @splat(0);
    s.clonewars_reaction_receipt_debug = @splat(0);
    s.clonewars_reaction_hit_actual = std.mem.zeroes(p.SyncReactionHitOutcome);
    s.clonewars_reaction_hit_expected = std.mem.zeroes(p.SyncReactionHitOutcome);
}
fn hitReceipt(out: *Snapshot, skip: bool) void {
    receipt.reaction_damage_begin(&out.receipt, actor, source);
    if (!skip) {
        selected_clip = 0xffffffff;
        choice.reaction_apply_choice(actor, &selected_clip);
    }
    win.store(i8, actor + 0xdde, if (client and mode == 21) 3 else 4);
    win.store(f32, actor + 0xd3c, 2.5);
    if (mode == 22) retained = false;
    receipt.reaction_damage_complete(&out.receipt);
}
fn tokenFor() Token {
    var token = std.mem.zeroes(Token);
    token.owner = actor;
    token.owner_nonce = 1;
    token.thread = win.GetCurrentThreadId();
    token.release = frame.epoch;
    token.epoch = frame.epoch;
    token.sequence = frame.sequence;
    token.frame = @intFromPtr(frame);
    return token;
}
fn begin(token: *const Token, lease: *s.Lease, host: c_int) void {
    check(@src(), r.reaction_bind_cohort(token) != 0 and r.reaction_frame_lease_get(lease) != 0 and r.reaction_begin(frame, host) != 0);
}
fn run() Snapshot {
    setup();
    clearDebug();
    var out: Snapshot = undefined;
    @memset(std.mem.asBytes(&out), 0);
    var token = tokenFor();
    var lease: s.Lease = undefined;
    begin(&token, &lease, 1);
    if (mode == 1 or mode == 20 or mode == 21 or mode == 22) hitReceipt(&out, false) else if (mode >= 9 and mode <= 12) {
        if (mode == 10) source = 0;
        out.draw = choice.reaction_damage_draw(actor, if (mode == 11) 65536 else 17);
    } else if (mode >= 13 and mode <= 19) {
        out.result = item.reaction_item_range_hook(actor, if (mode == 16) 0 else target, 1.5);
    } else if (mode >= 24 and mode <= 26) {
        source = 0;
        out.result = arena.reaction_arena_contact_hit(target, actor);
    } else {
        selected_clip = if (mode == 2) 0xffffffff else 7;
        if (mode == 2) source = 0;
        choice.reaction_apply_choice(actor, &selected_clip);
    }
    out.finish = r.reaction_finish();
    check(@src(), r.reaction_abort_frame(&lease) != 0);
    if (mode >= 3 and mode != 11) {
        client = true;
        retained = true;
        frame.sequence += 1;
        token.release += 1;
        token.sequence = frame.sequence;
        begin(&token, &lease, 0);
        if (mode == 4) clip_available = false;
        if (mode == 6 or mode == 12) source = 24;
        if (mode == 7) win.store(i16, actor + 0x2f4, 3);
        if (mode == 8 or mode == 19) frame.reaction_count = 0;
        if (mode >= 9 and mode <= 12) {
            out.draw = choice.reaction_damage_draw(actor, 23);
        } else if (mode >= 13 and mode <= 19) {
            if (mode == 13 or mode == 14) win.store(f32, actor + 0x24, 100);
            if (mode == 14) {
                win.store(u16, actor + 0x6c, 31);
                put(actor + 0x2fc, 128);
            }
            if (mode == 17) put(actor + 0x2bc, 0);
            out.result = item.reaction_item_range_hook(actor, if (mode == 16) 0 else target, if (mode == 18) std.math.nan(f32) else 1.5);
        } else if (mode >= 20 and mode <= 22) {
            win.store(i8, actor + 0xdde, 5);
            win.store(f32, actor + 0xd3c, 1);
            hitReceipt(&out, mode == 20);
        } else if (mode >= 24 and mode <= 26) {
            out.drain = arena.reaction_drain_contact_hits();
        } else {
            selected_clip = 9;
            choice.reaction_apply_choice(actor, &selected_clip);
            if (mode == 23) out.duplicate = choice.reaction_client_duplicate_projectile(actor, source);
        }
        out.finish = r.reaction_finish();
        check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
    snapshot(&out);
    if (out.receipt.lease.cohort.thread != 0) {
        check(@src(), out.receipt.lease.cohort.thread == win.GetCurrentThreadId());
        out.receipt.lease.cohort.thread = 0;
    }
    return out;
}
fn invokeArena(_: usize) callconv(.c) c_int {
    return arena.reaction_arena_contact_hit(target, actor);
}
fn protect(address: usize, protection: u32) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(address, 0x10000, protection, &old) != 0);
}
fn installedHooks() void {
    const sites = [_]usize{ 0x96a1bd, 0x96b2e1, 0x410cf3, 0x87ffb7, 0x89e430, 0x96b95e, 0x96ad96, 0x87acd0 };
    const sizes = [_]usize{ 7, 8, 5, 5, 7, 7, 10, 5 };
    const prefixes = [_][]const u8{ "\x8b\x7c\x24\x50\x83\xff\xff", "\x89\x44\x24\x44\xdb\x44\x24\x44", "\xe8\xc8\x97\x55\x00", "\xe8\xf4\x2d\xf1\xff", "\x56\x8b\x74\x24\x08\x85\xf6", "\x0f\xbe\xbe\xde\x0d\x00\x00", "\xf7\x86\x80\x0c\x00\x00\x00\x10\x00\x00", "\xe8\xeb\xf7\x0e\x00" };
    for ([_]usize{ 0x410000, 0x870000, 0x890000, 0x960000 }) |a| protect(a, 0x40);
    for (sites, sizes, prefixes) |site, size, prefix| @memcpy(bytes(site, size), prefix[0..size]);
    win.store(u8, 0x96a1c4, 0xc3);
    win.store(u8, 0x96b2e9, 0xc3);
    for (sites, prefixes) |site, prefix| {
        win.store(u8, site, 0xcc);
        check(@src(), r.reaction_install() == 0);
        win.store(u8, site, prefix[0]);
        for (sites, sizes, prefixes) |a, size, expected| check(@src(), std.mem.eql(u8, bytes(a, size), expected[0..size]));
    }
    for ([_]usize{ 0x410000, 0x870000, 0x890000, 0x960000 }) |a| protect(a, 0x20);
    check(@src(), r.reaction_install() != 0 and r.reaction_install() != 0 and r.reaction_ready() != 0);
    for (sites) |a| {
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(a, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
    const range: *const fn (usize, usize, f32) callconv(.c) c_int = @ptrFromInt(sites[3] +% 5 +% win.load(u32, sites[3] + 1));
    const contact: *const fn (usize, usize) callconv(.c) c_int = @ptrFromInt(sites[2] +% 5 +% win.load(u32, sites[2] + 1));
    mode = 0;
    setup();
    var token = tokenFor();
    token.release = 1000;
    token.epoch = 1000;
    frame.epoch = 1000;
    var lease: s.Lease = undefined;
    begin(&token, &lease, 1);
    reaction_fixture_clip = 7;
    invoke_choice();
    check(@src(), reaction_fixture_clip == 7 and frame.reaction_count == 1);
    reaction_fixture_draw = 17;
    invoke_draw();
    check(@src(), reaction_fixture_draw == 17 and frame.reaction_count == 2);
    check(@src(), range(actor, target, 1.5) != 0 and frame.reaction_count == 3);
    source = 0;
    check(@src(), contact(target, actor) != 0 and frame.reaction_count == 4 and r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);
    client = true;
    frame.sequence += 1;
    token.release += 1;
    token.sequence = frame.sequence;
    begin(&token, &lease, 0);
    source = 23;
    reaction_fixture_clip = 9;
    invoke_choice();
    check(@src(), reaction_fixture_clip == 7);
    reaction_fixture_draw = 23;
    invoke_draw();
    check(@src(), reaction_fixture_draw == 17);
    check(@src(), range(actor, target, 1.5) != 0);
    source = 0;
    check(@src(), arena.reaction_drain_contact_hits() != 0 and r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);
    mode = 27;
    setup();
    frame.epoch = 2000;
    token.epoch = 2000;
    token.release = 2000;
    token.sequence = frame.sequence;
    begin(&token, &lease, 1);
    check(@src(), support.exceptionCode(0, invokeArena) == 0xe1459876);
    source = 0;
    selected_clip = 0xffffffff;
    choice.reaction_apply_choice(actor, &selected_clip);
    check(@src(), frame.reaction_count == 0 and r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);
}
fn unchangedNativeChoice() void {
    for (0..6) |invalid| {
        mode = 40 + @as(u32, @intCast(invalid));
        setup();
        clearDebug();
        clip_available = false;
        var token = tokenFor();
        var lease: s.Lease = undefined;
        begin(&token, &lease, 1);
        reaction_fixture_clip = 523;
        invoke_choice();
        check(@src(), reaction_fixture_clip == 523 and frame.reaction_count == 1 and r.reaction_finish() != 0);
        check(@src(), r.reaction_abort_frame(&lease) != 0);
        client = true;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        token.release += 1;
        switch (invalid) {
            0, 1 => {},
            2 => frame.reactions[0].old_action += 1,
            3 => frame.reactions[0].payload.clip.source_id += 1,
            4 => frame.reactions[0].generation = 0,
            5 => frame.reaction_count = 0,
            else => unreachable,
        }
        begin(&token, &lease, 0);
        reaction_fixture_clip = if (invalid == 1) 522 else 523;
        invoke_choice();
        if (invalid == 0) {
            check(@src(), reaction_fixture_clip == 523 and available_calls == 0 and fault == 0 and s.journal.cursor == 1 and r.reaction_finish() != 0);
        } else {
            check(@src(), reaction_fixture_clip == (if (invalid == 1) @as(u32, 522) else 523) and fault == 17 and s.journal.cursor == 0 and r.reaction_finish() == 0);
            check(@src(), available_calls == @intFromBool(invalid == 1));
        }
        check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
}
fn idleWalkReactionClip() void {
    for (0..7) |variant| {
        mode = 60 + @as(u32, @intCast(variant));
        setup();
        clearDebug();
        const projectile = variant >= 3;
        const blue_shadow = variant >= 5;
        source = if (projectile) 3063 else 0;
        frame.level = if (blue_shadow) 73 else if (projectile) 6 else if (variant == 2) 63 else 64;
        damage_caller = if (projectile) 0x81f27f else if (variant == 1) 0 else 0x871848;
        if (blue_shadow) win.store(u16, actor + 0xdc0, 184);
        win.store(i16, actor + 0x2f4, -1);
        var token = tokenFor();
        var lease: s.Lease = undefined;
        begin(&token, &lease, 1);
        const host_clip: u32 = if (blue_shadow) 73 else 522;
        reaction_fixture_clip = host_clip;
        invoke_choice();
        check(@src(), frame.reaction_count == 1 and r.reaction_finish() != 0);
        check(@src(), r.reaction_abort_frame(&lease) != 0);
        client = true;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        token.release += 1;
        begin(&token, &lease, 0);
        const guest_action: i16 = if (blue_shadow) 11 else 1;
        win.store(i16, actor + 0x2f4, guest_action);
        const selected: u32 = if (variant == 3 or variant == 6) 522 else 73;
        reaction_fixture_clip = selected;
        invoke_choice();
        check(@src(), win.load(i16, actor + 0x2f4) == guest_action);
        if (variant == 0 or variant == 3 or variant == 5) {
            check(@src(), reaction_fixture_clip == host_clip and fault == 0 and r.reaction_finish() != 0);
        } else {
            check(@src(), reaction_fixture_clip == selected and fault == 17 and r.reaction_finish() == 0);
        }
        check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
}
fn vindiLandingReactionClip() void {
    for ([_]u16{ 201, 201, 333 }, [_]u32{ 973, 975, 973 }, [_]u32{ 975, 973, 975 }) |character, host_clip, guest_clip| {
        mode = 67;
        setup();
        clearDebug();
        frame.level = 73;
        source = 0;
        win.store(u16, actor + 0xdc0, character);
        win.store(i16, actor + 0x2f4, 92);
        var token = tokenFor();
        var lease: s.Lease = undefined;
        begin(&token, &lease, 1);
        reaction_fixture_clip = host_clip;
        invoke_choice();
        check(@src(), frame.reaction_count == 1 and r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);

        client = true;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        token.release += 1;
        begin(&token, &lease, 0);
        win.store(i16, actor + 0x2f4, -1);
        reaction_fixture_clip = guest_clip;
        invoke_choice();
        check(@src(), win.load(i16, actor + 0x2f4) == -1);
        if (character == 201) {
            check(@src(), reaction_fixture_clip == host_clip and fault == 0 and r.reaction_finish() != 0);
        } else {
            check(@src(), reaction_fixture_clip == guest_clip and fault == 17 and r.reaction_finish() == 0);
        }
        check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
}
fn geonosisProjectileCooldown(damage: i8, local_timer: f32) void {
    mode = 20;
    setup();
    clearDebug();
    frame.level = 79;
    var token = tokenFor();
    var lease: s.Lease = undefined;
    var hit: s.Receipt = undefined;
    begin(&token, &lease, 1);
    win.store(f32, actor + 0xd3c, -0.01);
    receipt.reaction_damage_begin(&hit, actor, source);
    selected_clip = 0xffffffff;
    choice.reaction_apply_choice(actor, &selected_clip);
    win.store(i8, actor + 0xdde, 5 - damage);
    win.store(f32, actor + 0xd3c, 2.5);
    receipt.reaction_damage_complete(&hit);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    begin(&token, &lease, 0);
    win.store(i8, actor + 0xdde, 5);
    win.store(f32, actor + 0xd3c, local_timer);
    receipt.reaction_damage_begin(&hit, actor, source);
    check(@src(), win.load(f32, actor + 0xd3c) == -0.01 and hit.hit.timer_before == -0.01);
    damage_caller = 0x81f27f;
    check(@src(), receipt.reaction_projectile_damage_amount(actor, 0) == damage);
    check(@src(), receipt.reaction_projectile_damage_amount(actor, 2) == 2 and s.journal.cursor == 0);
    win.store(i8, actor + 0xdde, 5 - damage);
    win.store(f32, actor + 0xd3c, 2.5);
    receipt.reaction_damage_complete(&hit);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0 and fault == 0);
}
fn geonosisBlockedProjectile(health: i8, host_timer: f32, client_timer: f32) void {
    mode = 20;
    setup();
    clearDebug();
    frame.level = 79;
    damage_caller = 0x81f27f;
    var token = tokenFor();
    var lease: s.Lease = undefined;
    var hit: s.Receipt = undefined;
    begin(&token, &lease, 1);
    win.store(i8, actor + 0xdde, health);
    win.store(f32, actor + 0xd3c, host_timer);
    receipt.reaction_damage_begin(&hit, actor, source);
    receipt.reaction_damage_complete(&hit);
    check(@src(), frame.reaction_count == 1 and frame.reactions[0].payload.clip.hit.health_after == health);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    begin(&token, &lease, 0);
    win.store(f32, actor + 0xd3c, client_timer);
    receipt.reaction_damage_begin(&hit, actor, source + 1);
    check(@src(), hit.hit.timer_before == client_timer and win.load(f32, actor + 0xd3c) == client_timer and s.journal.cursor == 0);
    receipt.reaction_damage_begin(&hit, actor, source);
    check(@src(), hit.hit.timer_before == host_timer and win.load(f32, actor + 0xd3c) == host_timer);
    if (health == 1) check(@src(), receipt.reaction_projectile_damage_amount(actor, 2) == 0);
    receipt.reaction_damage_complete(&hit);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0 and fault == 0);
}
fn blueShadowLepProjectileContact() void {
    mode = 20;
    setup();
    clearDebug();
    frame.level = 74;
    damage_caller = 0x81f27f;
    source = 489;
    win.store(i16, actor + 0xdc0, 354);
    win.store(i16, actor + 0x2f4, -1);
    win.store(u32, actor + 0xc80, 0x1000);
    var token = tokenFor();
    var lease: s.Lease = undefined;
    begin(&token, &lease, 1);
    selected_clip = 72;
    choice.reaction_apply_choice(actor, &selected_clip);
    check(@src(), frame.reaction_count == 1 and receipt.reaction_lep_projectile_contact(actor) == 0);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);

    client = true;
    token.release += 1;
    begin(&token, &lease, 0);
    check(@src(), receipt.reaction_lep_projectile_contact(actor) != 0 and s.journal.cursor == 0);
    source += 1;
    check(@src(), receipt.reaction_lep_projectile_contact(actor) == 0);
    source -= 1;
    choice.reaction_apply_choice(actor, &selected_clip);
    check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0 and fault == 0);
}
pub fn main() void {
    check(@src(), @sizeOf(Snapshot) == 904 and @intFromPtr(&image) < 0x410000 and @intFromPtr(&image) + image.len > 0xfc0000);
    for ([_]usize{ 0x790000, 0x8a0000, 0x960000, 0xe60000, 0xea0000 }) |a| protect(a, 0x40);
    for (0..3) |i| {
        const a = actor + i * 0x10000;
        check(@src(), win.VirtualAlloc(a, if (i < 2) 0x2000 else 0x1000, 0x3000, 4) == a);
    }
    check(@src(), win.VirtualAlloc(@intFromPtr(frame), @sizeOf(p.SyncFrame), 0x3000, 4) == @intFromPtr(frame));
    defer {
        for (0..3) |i| check(@src(), win.VirtualFree(actor + i * 0x10000, 0, 0x8000) != 0);
        check(@src(), win.VirtualFree(@intFromPtr(frame), 0, 0x8000) != 0);
    }
    jump(0x8a8e70, @intFromPtr(&available));
    jump(0x792db0, @intFromPtr(&nativeRange));
    jump(0x96a4c0, @intFromPtr(&nativeHit));
    const expected = [_]u32{ 3760438584, 3148583974, 1282296125, 1295963535, 2311636707, 640359377, 2363978295, 1368051231, 893719385, 1794677709, 1730478152, 3273947925, 1365588634, 978031227, 978031227, 2625607644, 2509404437, 2210369185, 45445887, 2724897212, 146159781, 2223610887, 1894754850, 771549818, 2920201034, 145074882, 1389708499 };
    for (expected, 0..) |hash, i| {
        mode = @intCast(i);
        var out = run();
        if (mode >= 24 and mode <= 26) {
            check(@src(), @import("reaction_validation.zig").hitValid(&out.entries[0].payload.clip.hit));
            out.entries[0].payload.clip.hit = std.mem.zeroes(p.SyncReactionHitOutcome);
        }
        var checksum: u32 = 2166136261;
        for (std.mem.asBytes(&out)) |byte| checksum = (checksum ^ byte) *% 16777619;
        if (checksum != hash) std.debug.print("reaction mode={d} hash={d} expected={d}\n", .{ mode, checksum, hash });
        check(@src(), checksum == hash);
        if (mode == 3) check(@src(), out.finish != 0 and out.clip == 7 and out.debug[2] != 0);
        if (mode == 20) check(@src(), out.finish != 0 and out.receipt_debug[2] != 0);
        if (mode == 13) check(@src(), out.finish != 0 and out.range_debug[2] != 0 and out.result != 0);
        if (mode == 24 or mode == 25) check(@src(), out.finish != 0 and out.drain != 0 and out.hit_calls == 2);
    }
    installedHooks();
    unchangedNativeChoice();
    idleWalkReactionClip();
    vindiLandingReactionClip();
    arenaBeforeHit();
    blueShadowLiftContact();
    actionTraceChecks();
}

fn blueShadowLiftContact() void {
    for ([_]bool{ false, true }) |local_contact| {
        mode = 53;
        setup();
        clearDebug();
        source = 0;
        frame.level = 74;
        frame.sequence = 33535;
        win.store(i16, target + 0xdc0, 184);
        win.store(i16, actor + 0xdc0, 321);
        win.store(f32, target + 0x24, 39);
        win.store(f32, actor + 0x24, 40);
        var token = tokenFor();
        var lease: s.Lease = undefined;
        begin(&token, &lease, 1);
        check(@src(), arena.liftContact(target, actor, 1, 0x100010a, 0, 1) == 13);
        check(@src(), frame.reaction_count == 1 and r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0);

        client = true;
        token.release += 1;
        begin(&token, &lease, 0);
        if (local_contact) check(@src(), arena.liftContact(target, actor, 1, 0x100010a, 0, 1) == 13);
        check(@src(), arena.reaction_drain_contact_hits() != 0);
        check(@src(), hit_calls == 2 and selected_clip == 7 and win.load(f32, actor + 0xd3c) != 2.5);
        check(@src(), arena.liftContact(target, actor, 1, 0x100010a, 0, 1) == 0 and hit_calls == 2);
        check(@src(), r.reaction_finish() != 0 and r.reaction_abort_frame(&lease) != 0 and fault == 0);
    }
}
fn actionTraceChecks() void {
    const trace = @import("native_action_trace.zig");
    const fixture = @import("native_action_trace_fixture.zig");
    const saved_resume = trace.native_action_trace_resume;
    trace.native_action_trace_resume = @intFromPtr(&fixture.native_action_probe_resume);
    defer trace.native_action_trace_resume = saved_resume;
    for (0..8) |variant| {
        mode = 0;
        client = false;
        valid = true;
        frame.epoch = 9000 + @as(u32, @intCast(variant));
        frame.level = if (variant == 4) 1 else 12;
        var token = tokenFor();
        var lease: s.Lease = undefined;
        begin(&token, &lease, 1);
        win.store(u16, actor + 0xdc0, if (variant == 5) 183 else if (variant == 6) 189 else 119);
        const state = if (variant == 3) 0 else actor + 0x260;
        const next: u32 = if (variant == 2) 8 else if (variant == 1) 116 else 65535;
        if (variant == 7) check(@src(), r.reaction_abort_frame(&lease) != 0);
        const before = win.load([0x1440]u8, actor);
        const count = trace.clonewars_native_action_trace_debug[0];
        fixture.native_action_probe(@intFromPtr(&fixture.native_action_probe_original), state, next);
        const regs = fixture.native_action_probe_regs;
        const fx = fixture.native_action_probe_fx;
        win.SetLastError(0x98765432);
        fixture.native_action_probe(@intFromPtr(&native_action_trace_thunk), state, next);
        check(@src(), win.GetLastError() == 0x98765432 and std.mem.eql(u32, &regs, &fixture.native_action_probe_regs) and std.mem.eql(u8, &fx, &fixture.native_action_probe_fx));
        check(@src(), std.mem.eql(u8, &before, bytes(actor, 0x1440)));
        const recorded = variant == 0 or variant == 1 or variant == 6;
        check(@src(), trace.clonewars_native_action_trace_debug[0] == count + @intFromBool(recorded));
        if (recorded) {
            const e = trace.clonewars_native_action_trace_entries[count % 2048];
            check(@src(), e[0] == count and e[1] == token.epoch and e[2] == token.sequence and e[5] == actor and e[6] == win.load(u16, actor + 0xdc0) and e[7] == win.load(u16, actor + 0x2f4) and e[8] == next);
        }
        if (variant != 7) check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
}
extern fn native_action_trace_thunk() void;

fn arenaBeforeHit() void {
    for (0..12) |mutation| {
        mode = if (mutation == 10) 51 else 50;
        setup();
        clearDebug();
        source = 0;
        frame.epoch = 3000 + @as(u32, @intCast(mutation));
        var token = tokenFor();
        var lease: s.Lease = undefined;
        win.store(i16, actor + 0x2f4, 65);
        win.store(i8, actor + 0xdde, 3);
        win.store(f32, actor + 0xd3c, 0);
        begin(&token, &lease, 1);
        check(@src(), arena.reaction_arena_contact_hit(target, actor) != 0 and frame.reaction_count == 1 and r.reaction_finish() != 0);
        const e = &frame.reactions[0];
        check(@src(), e.old_action == -1 and e.payload.clip.hit.action_before == 65 and e.payload.clip.hit.action_after == 20 and e.payload.clip.hit.health_before == 3 and e.payload.clip.hit.health_after == 2);
        check(@src(), r.reaction_abort_frame(&lease) != 0);
        client = true;
        frame.sequence += 1;
        token.sequence = frame.sequence;
        token.release += 1;
        win.store(i16, actor + 0x2f4, 65);
        win.store(i8, actor + 0xdde, 3);
        win.store(f32, actor + 0xd3c, 0);
        switch (mutation) {
            1 => win.store(i16, actor + 0x2f4, -1),
            2 => win.store(i8, actor + 0xdde, 4),
            3 => win.store(f32, actor + 0xd3c, 1),
            4 => e.payload.clip.hit.timer_before = std.math.nan(f32),
            5 => e.payload.clip.hit.completed = 2,
            6 => e.payload.clip.hit.life_before = 4,
            7 => e.payload.clip.hit.action_before = 32768,
            8 => e.payload.clip.hit.health_before = 128,
            9 => e.payload.clip.hit.action_after = -1,
            11 => retained = false,
            else => {},
        }
        const before = win.load([0x1440]u8, actor);
        const calls = hit_calls;
        begin(&token, &lease, 0);
        const result = arena.reaction_drain_contact_hits();
        if (mutation == 0) {
            check(@src(), result != 0 and hit_calls == calls + 1 and selected_clip == 73 and win.load(i8, actor + 0xdde) == 2 and win.load(i16, actor + 0x2f4) == 20 and win.load(f32, actor + 0xd3c) == 2.5 and r.reaction_finish() != 0);
        } else {
            check(@src(), result == 0 and r.reaction_finish() == 0);
            if (mutation != 9 and mutation != 10) check(@src(), hit_calls == calls and std.mem.eql(u8, &before, bytes(actor, 0x1440)));
            if (mutation == 9 or mutation == 10) check(@src(), win.load(f32, actor + 0xd3c) == 0.4);
        }
        check(@src(), r.reaction_abort_frame(&lease) != 0);
    }
    geonosisProjectileCooldown(1, 0.75);
    geonosisProjectileCooldown(2, -0.01);
    blueShadowLepProjectileContact();
    geonosisBlockedProjectile(1, -0.01, -0.01);
    geonosisBlockedProjectile(1, 0.9, 0.4984956);
    geonosisBlockedProjectile(2, 0.95, -0.09);
}
