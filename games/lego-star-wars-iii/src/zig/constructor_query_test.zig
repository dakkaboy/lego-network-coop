const std = @import("std");
const s = @import("constructor_query_state.zig");
const query = @import("constructor_query.zig");
const t = s.t;
const win = s.win;
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
var alive = true;
var generation: u32 = 13;
var read_count: u32 = 0;
var cancel_at: u32 = 0;
var clock: u32 = 43;
var global: [0xb0]u8 align(16) = @splat(0);
var descriptor: [0x80]u8 align(16) = @splat(0);
var receiver: [0x1a8]u8 align(16) = @splat(0);
var wrapper: [0x20]u8 align(16) = @splat(0);
var method: u32 = 0xa32dc0;
var nuanim: [0x1230]u8 align(16) = @splat(0);
var api: [0x34]u8 align(16) = @splat(0);
var user: [8]u8 align(16) = @splat(0);
var actor: [0x1440]u8 align(16) = @splat(0);
var resource: [0x6fc]u8 align(16) = @splat(0);
var runtime: [0x70]u8 align(16) = @splat(0);
var table: [0x1c0]u8 align(16) = @splat(0);
var name: [6]u8 = .{ 't', 'h', 'i', 'n', 'g', 0 };
var site: usize = 0;
pub const constructor_query_test_api = struct {
    pub fn readable(location: usize, bytes: usize, write: bool) bool {
        read_count += 1;
        if (read_count == cancel_at) alive = false;
        return win.accessible(location, bytes, write);
    }
    pub fn address(raw: usize) usize {
        return switch (raw) {
            0xfb4b6c => @intFromPtr(&clock),
            0xfb9770 => @intFromPtr(&global),
            0xc1ed98 => @intFromPtr(&method),
            0x8c89da => site,
            else => raw,
        };
    }
    pub fn projectiles_constructor_cohort_valid(_: *const s.c.Lease, _: *const s.Token) c_int {
        return @intFromBool(alive);
    }
    pub fn projectiles_constructor_control_valid(_: *const s.c.Lease, _: *const s.Control, _: *const @import("projectile_types.zig").Session, _: u64) c_int {
        return @intFromBool(alive);
    }
    pub fn projectiles_frame_lease_get(_: *@import("cohort_types.zig").Lease) c_int {
        return 0;
    }
    pub fn projectiles_constructor_hooks_ready() c_int {
        return 1;
    }
    pub fn entities_observed_generation(_: usize) u32 {
        return generation;
    }
    pub fn entities_allocation_live(_: usize, value: u32) c_int {
        return @intFromBool(generation == 13 and value == 13);
    }
    pub fn entities_observed_identity(_: usize, slot: *u32, out: *u32) c_int {
        slot.* = 7;
        out.* = 11;
        return 1;
    }
};
fn pointer(bytes: anytype, offset: usize, value: anytype) void {
    win.store(usize, @intFromPtr(bytes) + offset, @intFromPtr(value));
}
fn source() s.c.Scope {
    var result = std.mem.zeroes(s.c.Scope);
    result.ready = 1;
    result.capability = s.c.frame;
    result.record.thread = win.GetCurrentThreadId();
    result.cohort.thread = win.GetCurrentThreadId();
    result.cohort.cohort_nonce = 1;
    result.cohort.epoch = 7;
    result.cohort.sequence = 2;
    result.record.input.lease.serial = 19;
    result.record.input.birth_known = 1;
    result.record.input.birth.owner = -1;
    return result;
}
fn snapshot() void {
    var saved: [64]u32 = @splat(0);
    var frame: [10]u32 = @splat(0);
    var start: [3]u32 = .{ 1, 2, 3 };
    var delta: [3]u32 = .{ 4, 5, 6 };
    frame[1] = 0x81e26e;
    frame[2] = @intFromPtr(&start);
    frame[3] = @intFromPtr(&delta);
    saved[2] = @intFromPtr(&frame);
    saved[7] = 1;
    var fx: [512]u8 align(16) = @splat(0);
    win.store(u16, @intFromPtr(&fx), 0x27f);
    win.store(u32, @intFromPtr(&fx) + 24, 0x1f80);
    query.constructor_query_checkpoint(&saved, &fx);
}
fn record() *const t.Record {
    return &s.clonewars_constructor_query_records[(s.clonewars_constructor_query_count - 1) % 2048];
}
fn begin(scope: *t.Scope, original: *const s.c.Scope) void {
    s.constructor_query_scope_begin(scope, original);
    check(@src(), scope.ready == 1);
}
fn end(scope: *t.Scope) void {
    s.constructor_query_scope_end(scope, 0);
}
pub fn main() void {
    pointer(&global, 0x78, &descriptor);
    win.store(u32, @intFromPtr(&descriptor), 0xc69eac);
    win.store(u32, @intFromPtr(&descriptor) + 0x18, 1);
    pointer(&descriptor, 0x28, &receiver);
    pointer(&descriptor, 0x30, &wrapper);
    win.store(u32, @intFromPtr(&wrapper), 0xc1ed6c);
    pointer(&wrapper, 0x10, &nuanim);
    pointer(&nuanim, 0x122c, &api);
    pointer(&api, 0x30, &user);
    pointer(&user, 4, &actor);
    pointer(&actor, 8, &api);
    win.store(u16, @intFromPtr(&actor) + 0xdc0, 23);
    win.store(u32, @intFromPtr(&receiver), 0xc20b1c);
    pointer(&receiver, 0x1a0, &descriptor);
    pointer(&receiver, 0x2c, &resource);
    pointer(&receiver, 0x30, &table);
    pointer(&resource, 0x6f8, &runtime);
    win.store(u32, @intFromPtr(&runtime) + 0x68, 2);
    pointer(&runtime, 0x6c, &table);
    pointer(&table, 0xd4, &receiver);
    pointer(&table, 0xb4, &name);
    site = win.VirtualAlloc(0, 4096, 0x3000, 4);
    check(@src(), site != 0);
    defer _ = win.VirtualFree(site, 0, 0x8000);
    const prefix = "\x84\xc0\x0f\x84\xa9\x00\x00\x00";
    for (0..prefix.len) |i| {
        var old: u32 = 0;
        check(@src(), win.VirtualProtect(site, 8, 4, &old) != 0);
        @memcpy(@as([*]u8, @ptrFromInt(site))[0..8], prefix);
        win.store(u8, site + i, prefix[i] ^ 1);
        check(@src(), win.VirtualProtect(site, 8, 0x20, &old) != 0);
        check(@src(), query.constructor_query_install() == 0 and win.load(u8, site + i) == prefix[i] ^ 1);
        var info: win.MemoryInfo = undefined;
        check(@src(), win.VirtualQuery(site, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    }
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(site, 8, 4, &old) != 0);
    @memcpy(@as([*]u8, @ptrFromInt(site))[0..8], prefix);
    check(@src(), win.VirtualProtect(site, 8, 0x20, &old) != 0);
    check(@src(), query.constructor_query_install() == 1 and query.constructor_query_install() == 1);
    s.clonewars_constructor_query_enabled = 1;
    var original = source();
    var outer = std.mem.zeroes(t.Scope);
    begin(&outer, &original);
    read_count = 0;
    snapshot();
    check(@src(), s.clonewars_constructor_query_count == 1 and record().committed == 1 and record().collider_identity.status == 1 and record().source_witness.status == 1);
    check(@src(), record().source_witness.poi_ordinal == 0 and record().source_witness.name_size == 5 and record().source_witness.name_flags == 3 and record().collider_identity.actor_network_slot == 7);
    check(@src(), record().native_control_word == 0x27f and record().start_raw[0] == 1 and record().displacement_raw[2] == 6);
    const total_reads = read_count;
    var nested = std.mem.zeroes(t.Scope);
    begin(&nested, &original);
    check(@src(), nested.parent == outer.id);
    end(&nested);
    var rejected = source();
    rejected.capability = s.c.rejected;
    s.constructor_query_scope_begin(&nested, &rejected);
    check(@src(), nested.linked == 1 and nested.ready == 0);
    const count = s.clonewars_constructor_query_count;
    snapshot();
    check(@src(), s.clonewars_constructor_query_count == count);
    end(&nested);
    for (1..total_reads + 1) |position| {
        alive = true;
        read_count = 0;
        cancel_at = @intCast(position);
        snapshot();
        check(@src(), s.clonewars_constructor_query_count == count);
    }
    cancel_at = 0;
    alive = true;
    method = 0;
    snapshot();
    check(@src(), record().collider_identity.reason == t.CCI_UNSUPPORTED_WRAPPER and record().source_witness.status == 1);
    method = 0xa32dc0;
    win.store(u32, @intFromPtr(&runtime) + 0x68, 0xffffffff);
    snapshot();
    check(@src(), record().source_witness.reason == t.CQS_INVALID_COUNT);
    win.store(u32, @intFromPtr(&runtime) + 0x68, 65537);
    snapshot();
    check(@src(), record().source_witness.reason == t.CQS_COUNT_CAP);
    win.store(u32, @intFromPtr(&runtime) + 0x68, 0);
    snapshot();
    check(@src(), record().source_witness.reason == t.CQS_EMPTY_TABLE);
    win.store(u32, @intFromPtr(&runtime) + 0x68, 2);
    win.store(u32, @intFromPtr(&table) + 0xd4, 0);
    snapshot();
    check(@src(), record().source_witness.reason == t.CQS_D4_NOT_SELF_BOUND and record().source_witness.status == 0 and record().source_witness.name_size == 5);
    pointer(&table, 0xd4, &receiver);
    generation = 14;
    snapshot();
    check(@src(), record().collider_identity.reason == t.CCI_ALLOCATION_NOT_LIVE);
    generation = 13;
    var wrong = original.cohort;
    wrong.cohort_nonce += 1;
    check(@src(), s.constructor_query_abort_cohort(&wrong) == 0 and s.active == &outer);
    check(@src(), s.constructor_query_abort_cohort(&original.cohort) == 1 and s.active == null and s.depth == 0 and s.clonewars_constructor_query_active_scopes == 0);
    end(&outer);
    original.capability = s.c.control;
    original.control.thread = win.GetCurrentThreadId();
    original.reset_generation = 29;
    begin(&outer, &original);
    begin(&nested, &original);
    check(@src(), s.constructor_query_abort_control(&original.control, 28) == 0 and s.constructor_query_abort_control(&original.control, 29) == 1);
    end(&nested);
    end(&outer);
    check(@src(), s.active == null and s.depth == 0 and s.clonewars_constructor_query_active_scopes == 0);
}
