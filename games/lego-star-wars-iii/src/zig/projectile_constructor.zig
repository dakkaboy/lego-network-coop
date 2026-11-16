const std = @import("std");
const s = @import("projectile_state.zig");
const control = @import("projectile_control.zig");
const c = @import("constructor_types.zig");
const query = @import("constructor_query_state.zig");
const observer = @import("constructor_observer.zig");
const Token = @import("cohort_types.zig").Token;
const equal = @import("validation.zig").equal;
const root = @import("root");
pub const enabled = @hasDecl(root, "constructor_query_enabled") and root.constructor_query_enabled;
var nonce: u32 = 0;
var opened = false;
var thread: u32 = 0;
pub fn close() void {
    if (!enabled) return;
    nonce +%= 1;
    if (nonce == 0) nonce +%= 1;
    opened = false;
}
pub fn begin() void {
    if (!enabled) return;
    thread = s.win.GetCurrentThreadId();
    opened = true;
}
pub fn abort(token: *const Token) void {
    if (enabled) _ = query.constructor_query_abort_cohort(token);
}
pub export fn projectiles_constructor_cohort_valid(optional: ?*const c.Lease, captured: ?*const Token) c_int {
    const lease = optional orelse return 0;
    const token = captured orelse return 0;
    if (lease.frame_valid == 0) return @intFromBool(token.cohort_nonce == 0 and !s.frame_associated and !opened and s.current == null and lease.serial == s.lifecycle_serial and lease.nonce == nonce and lease.frame_local == 0);
    if (!control.frameContextLive() or s.coherent_frame_valid(token, 14) == 0) return 0;
    if (!s.frame_bound or !equal(token, &s.frame_lease.cohort) or s.binding_cancelled or s.frame_lifecycle != s.lifecycle_serial or lease.serial != s.lifecycle_serial or lease.nonce != nonce or lease.frame_local != @intFromPtr(s.current) or token.frame != @intFromPtr(s.current) or !opened or thread != s.win.GetCurrentThreadId()) return 0;
    return @intFromBool(lease.epoch == token.epoch and lease.sequence == token.sequence and s.current.?.epoch == token.epoch and s.current.?.sequence == token.sequence and s.coherent_frame_valid(token, 14) != 0);
}
pub export fn projectiles_constructor_lease_valid(lease: ?*const c.Lease) c_int {
    const value = lease orelse return 0;
    const token = std.mem.zeroes(Token);
    return @intFromBool(value.frame_valid == 0 and projectiles_constructor_cohort_valid(value, &token) != 0);
}
pub export fn projectiles_constructor_control_valid(optional: ?*const c.Lease, captured: ?*const s.t.ControlLease, session: ?*const s.t.Session, generation: u64) c_int {
    const lease = optional orelse return 0;
    const span = captured orelse return 0;
    const previous = session orelse return 0;
    if (lease.frame_valid != 0 or lease.frame_local != 0 or lease.epoch != 0 or lease.sequence != 0 or !control.threadOwned() or lease.serial != s.lifecycle_serial or lease.nonce != nonce or s.frame_bound or s.current != null or generation != s.reset_generation) return 0;
    if (previous.classification != s.t.established or previous.epoch != span.epoch or previous.level != span.level) return 0;
    return @intFromBool(control.controlValid(span, previous, generation));
}
pub export fn projectiles_constructor_hooks_ready() c_int {
    if (@atomicLoad(i32, &s.hooks_installed, .seq_cst) != 1 or !s.valid(0x44e4c0, 5) or s.read(u8, 0x44e4c0) != 0xe8) return 0;
    return @intFromBool(0x44e4c5 +% s.read(u32, 0x44e4c1) == @intFromPtr(&projectile_create_hook));
}
extern fn projectile_create_hook() void;
const Context = struct { call: c.Call, observation: *c.Scope, query_scope: *query.t.Scope };
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
fn invoke(raw: usize) callconv(.c) usize {
    const context: *Context = @ptrFromInt(raw);
    const call = &context.call;
    const native: s.t.Create = @ptrFromInt(0x869060);
    return native(call.manager, call.owner, call.origin, call.transform, call.weapon, call.flags, call.target);
}
fn unwind(raw: usize) callconv(.c) void {
    var machine: @import("machine_environment.zig").Environment = undefined;
    machine.capture();
    defer machine.restore();
    const context: *Context = @ptrFromInt(raw);
    query.constructor_query_scope_end(context.query_scope, 0);
    context.observation.ready = 0;
}
pub fn create(op: *const s.t.Operation, manager: usize, owner: usize, origin: usize, transform: usize, weapon: usize, flags: u32, target: usize, birth: ?*const @import("protocol.zig").SyncShot, kind: u32, caller: u32) usize {
    var observation = std.mem.zeroes(c.Scope);
    observation.control_session = op.session;
    observation.reset_generation = op.reset_generation;
    observation.capability = switch (op.kind) {
        s.t.keyed => c.frame,
        s.t.control => c.control,
        s.t.unkeyed => c.none,
        else => c.rejected,
    };
    if (observation.capability == c.frame) observation.cohort = op.frame.cohort;
    if (observation.capability == c.control) observation.control = op.control;
    var lease = std.mem.zeroes(c.Lease);
    lease.serial = op.serial;
    lease.nonce = nonce;
    if (op.kind == s.t.keyed) {
        lease.frame_local = op.frame.cohort.frame;
        if (control.live(op)) {
            lease.epoch = op.frame.cohort.epoch;
            lease.sequence = op.frame.cohort.sequence;
            lease.frame_valid = 1;
        }
    }
    const observing = control.threadOwned() and observer.clonewars_constructor_observer_enabled != 0;
    var scope = std.mem.zeroes(query.t.Scope);
    var context = Context{ .observation = &observation, .query_scope = &scope, .call = .{ .lease = lease, .birth = if (op.kind == s.t.control) 0 else @intFromPtr(birth), .manager = manager, .owner = owner, .origin = origin, .transform = transform, .weapon = weapon, .flags = flags, .target = target, .kind = kind, .caller = caller, .cohort = observation.cohort, .control = observation.control, .control_session = observation.control_session, .reset_generation = op.reset_generation, .capability = observation.capability } };
    const serial = s.lifecycle_serial;
    if (observing) observer.constructor_observer_begin(&observation, &context.call);
    query.constructor_query_scope_begin(&scope, &observation);
    const object = constructor_lexical_seh(@intFromPtr(&context), invoke, unwind);
    query.constructor_query_scope_end(&scope, object);
    if (observing and serial == s.lifecycle_serial) observer.constructor_observer_end(&observation, object);
    return object;
}
