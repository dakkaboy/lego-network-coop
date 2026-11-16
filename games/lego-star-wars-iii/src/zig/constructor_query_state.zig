const std = @import("std");
pub const win = @import("win32.zig");
pub const t = @import("constructor_query_types.zig");
pub const c = @import("constructor_types.zig");
pub const Token = @import("cohort_types.zig").Token;
pub const Control = @import("projectile_types.zig").ControlLease;
pub const api = if (@hasDecl(@import("root"), "constructor_query_test_api")) @import("root").constructor_query_test_api else struct {
    pub const readable = win.accessible;
    pub fn address(value: usize) usize {
        return value;
    }
    pub extern fn projectiles_constructor_cohort_valid(*const c.Lease, *const Token) c_int;
    pub extern fn projectiles_constructor_control_valid(*const c.Lease, *const Control, *const @import("projectile_types.zig").Session, u64) c_int;
    pub extern fn projectiles_frame_lease_get(*@import("cohort_types.zig").Lease) c_int;
    pub extern fn projectiles_constructor_hooks_ready() c_int;
    pub extern fn entities_observed_generation(usize) u32;
    pub extern fn entities_allocation_live(usize, u32) c_int;
    pub extern fn entities_observed_identity(usize, *u32, *u32) c_int;
};
pub export var clonewars_constructor_query_enabled: i32 = 0;
pub export var clonewars_constructor_query_count: u32 = 0;
pub export var clonewars_constructor_query_active_scopes: u32 = 0;
pub export var clonewars_constructor_query_version: u32 = 3;
pub export var clonewars_constructor_query_stride: u32 = @sizeOf(t.Record);
pub export var clonewars_constructor_query_capacity: u32 = 2048;
pub export var clonewars_constructor_query_installed: u32 = 0;
pub export var clonewars_constructor_query_debug: [8]u32 = @splat(0);
pub export var clonewars_constructor_query_records: [2048]t.Record = std.mem.zeroes([2048]t.Record);
pub threadlocal var active: ?*t.Scope = null;
pub threadlocal var depth: u32 = 0;
var scope_serial: u32 = 0;
threadlocal var cleanup_cohort = std.mem.zeroes(Token);
threadlocal var cleanup_control = std.mem.zeroes(Control);
threadlocal var cleanup_generation: u64 = 0;
threadlocal var cleanup_kind: u32 = c.none;
threadlocal var cleanup_valid = false;
pub threadlocal var cleanup_stamp: u32 = 1;
threadlocal var cleanup_disabled = false;
pub const equal = @import("validation.zig").equal;
pub fn readable(pointer: usize, size: usize) bool {
    return api.readable(pointer, size, false);
}
pub const address = api.address;
pub fn clock() u32 {
    const pointer = address(0xfb4b6c);
    return if (readable(pointer, 4)) win.load(u32, pointer) else 0;
}
pub fn stamp(value: *[2]u32) void {
    @import("observation.zig").timestamp(&value[0], &value[1]);
}
pub fn note(index: usize) void {
    _ = @atomicRmw(u32, &clonewars_constructor_query_debug[index], .Add, 1, .seq_cst);
}
fn advance() void {
    if (cleanup_stamp == 0xffffffff) cleanup_disabled = true else cleanup_stamp += 1;
}
fn detach() void {
    active = null;
    if (depth != 0) _ = @atomicRmw(u32, &clonewars_constructor_query_active_scopes, .Sub, depth, .seq_cst);
    depth = 0;
    cleanup_valid = false;
    advance();
}
pub export fn constructor_query_abort_cohort(captured: ?*const Token) c_int {
    const token = captured orelse return 0;
    if (token.thread != win.GetCurrentThreadId() or !cleanup_valid or cleanup_kind != c.frame or !equal(token, &cleanup_cohort)) return 0;
    detach();
    return 1;
}
pub export fn constructor_query_abort_control(captured: ?*const Control, generation: u64) c_int {
    const control = captured orelse return 0;
    if (control.thread != win.GetCurrentThreadId() or !cleanup_valid or cleanup_kind != c.control or cleanup_generation != generation or !equal(control, &cleanup_control)) return 0;
    detach();
    return 1;
}
pub fn contextValid(scope: *const t.Scope) bool {
    if (scope.capability == c.rejected) return false;
    return if (scope.capability == c.control) api.projectiles_constructor_control_valid(&scope.input.lease, &scope.control, &scope.control_session, scope.reset_generation) != 0 else api.projectiles_constructor_cohort_valid(&scope.input.lease, &scope.cohort) != 0;
}
pub fn live(optional: ?*const t.Scope) bool {
    const scope = optional orelse return false;
    if (scope.ready == 0 or scope.thread != win.GetCurrentThreadId() or !contextValid(scope)) return false;
    if (scope.owner_valid != 0) {
        const owner = scope.input.owner_local;
        var slot: u32 = 0;
        var generation: u32 = 0;
        if (api.entities_allocation_live(owner, scope.owner_local_generation) == 0 or api.entities_observed_identity(owner, &slot, &generation) == 0 or slot != scope.owner_slot or generation != scope.owner_generation or !readable(owner, 0x1440) or win.load(u16, owner + 0xdc0) != @as(u16, @truncate(scope.owner_character))) return false;
    }
    return contextValid(scope);
}
pub export fn cq_scope_begin_impl(scope: *t.Scope, source: ?*const c.Scope) void {
    scope.ready = 0;
    scope.linked = 0;
    if (clonewars_constructor_query_enabled == 0 and active == null) return;
    var association = std.mem.zeroes(Token);
    var control = std.mem.zeroes(Control);
    var generation: u64 = 0;
    var kind: u32 = c.none;
    if (source != null and source.?.capability == c.control) {
        control = source.?.control;
        generation = source.?.reset_generation;
        kind = c.control;
    } else if (source != null and source.?.cohort.cohort_nonce != 0) {
        association = source.?.cohort;
        kind = c.frame;
    } else if (active != null and cleanup_valid) {
        association = cleanup_cohort;
        control = cleanup_control;
        generation = cleanup_generation;
        kind = cleanup_kind;
    } else {
        var lease: @import("cohort_types.zig").Lease = undefined;
        if (api.projectiles_frame_lease_get(&lease) != 0) {
            association = lease.cohort;
            kind = c.frame;
        }
    }
    const same = kind == cleanup_kind and (if (kind == c.frame) equal(&association, &cleanup_cohort) else if (kind == c.control) generation == cleanup_generation and equal(&control, &cleanup_control) else true);
    if (active != null and kind != c.none and (!cleanup_valid or !same)) detach();
    if (active == null) {
        advance();
        cleanup_cohort = association;
        cleanup_control = control;
        cleanup_generation = generation;
        cleanup_kind = kind;
        cleanup_valid = kind != c.none;
    }
    scope.* = std.mem.zeroes(t.Scope);
    scope.cleanup_stamp = cleanup_stamp;
    scope.previous = active;
    scope.linked = 1;
    scope.thread = win.GetCurrentThreadId();
    active = scope;
    depth += 1;
    _ = @atomicRmw(u32, &clonewars_constructor_query_active_scopes, .Add, 1, .seq_cst);
    if (cleanup_disabled or clonewars_constructor_query_enabled == 0 or clonewars_constructor_query_installed != 3) return;
    if (depth > 32) {
        note(1);
        return;
    }
    const original = source orelse {
        note(7);
        return;
    };
    if (original.ready == 0 or original.record.thread != win.GetCurrentThreadId()) {
        note(7);
        return;
    }
    if (original.capability == c.rejected or (if (original.capability == c.control) api.projectiles_constructor_control_valid(&original.record.input.lease, &original.control, &original.control_session, original.reset_generation) == 0 else api.projectiles_constructor_cohort_valid(&original.record.input.lease, &original.cohort) == 0)) {
        note(2);
        return;
    }
    scope.cohort = original.cohort;
    scope.control = original.control;
    scope.control_session = original.control_session;
    scope.reset_generation = original.reset_generation;
    scope.capability = original.capability;
    scope.input = original.record.input;
    scope.owner_valid = @intFromBool(original.record.valid & 1 != 0);
    scope.owner_slot = original.record.owner_slot;
    scope.owner_generation = original.record.owner_generation;
    scope.owner_local_generation = original.record.owner_local_generation;
    scope.owner_character = original.record.owner_character;
    if (scope.input.birth_known != 0 and scope.input.birth.owner >= 0 and scope.owner_valid == 0) return;
    scope.ready = 1;
    if (!live(scope)) {
        scope.ready = 0;
        note(2);
        return;
    }
    scope.id = @import("observation.zig").increment(&scope_serial);
    if (scope.id == 0) scope.id = @import("observation.zig").increment(&scope_serial);
    scope.parent = if (live(scope.previous)) scope.previous.?.id else 0;
}
pub export fn cq_scope_end_impl(scope: *t.Scope, _: usize) void {
    if (scope.linked == 0) return;
    if (scope.cleanup_stamp != cleanup_stamp) {
        scope.ready = 0;
        scope.linked = 0;
        return;
    }
    if (active != scope) {
        note(3);
        return;
    }
    active = scope.previous;
    scope.ready = 0;
    scope.linked = 0;
    depth -= 1;
    _ = @atomicRmw(u32, &clonewars_constructor_query_active_scopes, .Sub, 1, .seq_cst);
    if (depth == 0) cleanup_valid = false;
}
pub extern fn constructor_query_scope_begin(*t.Scope, ?*const c.Scope) void;
pub extern fn constructor_query_scope_end(*t.Scope, usize) void;
pub const Binding = struct { scope: u32, ordinal: u32, thread: u32, lease: c.Lease, cohort: Token, control: Control, control_session: @import("projectile_types.zig").Session, reset_generation: u64, capability: u32 };
pub fn bindingLive(binding: *const Binding) bool {
    const scope = active orelse return false;
    return scope.id == binding.scope and scope.ordinal == binding.ordinal and scope.thread == binding.thread and equal(&scope.input.lease, &binding.lease) and equal(&scope.cohort, &binding.cohort) and equal(&scope.control_session, &binding.control_session) and scope.capability == binding.capability and scope.reset_generation == binding.reset_generation and equal(&scope.control, &binding.control) and live(scope);
}
pub fn acquire(binding: *Binding, record: *t.Record) bool {
    const scope = active orelse {
        note(4);
        return false;
    };
    if (!live(scope)) {
        note(4);
        return false;
    }
    scope.ordinal +%= 1;
    if (scope.ordinal == 0) {
        note(5);
        return false;
    }
    binding.* = .{ .scope = scope.id, .ordinal = scope.ordinal, .thread = scope.thread, .lease = scope.input.lease, .cohort = scope.cohort, .control = scope.control, .control_session = scope.control_session, .reset_generation = scope.reset_generation, .capability = scope.capability };
    record.thread = scope.thread;
    record.constructor_scope = scope.id;
    record.constructor_parent_scope = scope.parent;
    record.query_ordinal = scope.ordinal;
    inline for (.{ "serial", "nonce", "frame_local", "epoch", "sequence", "frame_valid" }) |field| {
        @field(record, if (std.mem.eql(u8, field, "serial")) "lease_serial" else if (std.mem.eql(u8, field, "nonce")) "lease_nonce" else field) = @field(scope.input.lease, field);
    }
    record.constructor_kind = scope.input.kind;
    record.constructor_caller = scope.input.caller;
    record.birth_known = scope.input.birth_known;
    record.shot_id = if (scope.input.birth_known != 0) scope.input.birth.id else 0;
    record.shot_phase = if (scope.input.birth_known != 0) scope.input.birth.phase else 0;
    record.owner_slot = scope.owner_slot;
    record.owner_generation = scope.owner_generation;
    record.owner_local_generation = scope.owner_local_generation;
    record.owner_character = scope.owner_character;
    record.owner_local = scope.input.owner_local;
    record.input_flags = scope.input.flags;
    record.input_weapon = scope.input.weapon;
    if (scope.owner_valid != 0) record.valid_mask |= t.CQ_OWNER;
    return bindingLive(binding);
}
pub fn span(binding: *const Binding, pointer: usize, size: usize) bool {
    return bindingLive(binding) and readable(pointer, size) and bindingLive(binding);
}
pub fn word(binding: *const Binding, pointer: usize, out: *u32) bool {
    if (!span(binding, pointer, 4)) return false;
    out.* = win.load(u32, pointer);
    return bindingLive(binding);
}
comptime {
    asm (@import("observer_bridge_code.zig").code("constructor_query_scope_begin", "cq_scope_begin_impl") ++ @import("observer_bridge_code.zig").code("constructor_query_scope_end", "cq_scope_end_impl"));
}
