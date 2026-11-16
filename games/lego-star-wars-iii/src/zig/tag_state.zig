const std = @import("std");
pub const p = @import("protocol.zig");
pub const win = @import("win32.zig");
pub const Token = @import("cohort_types.zig").Token;
pub const Adapter = @import("span_types.zig").Adapter;
pub const ControlLease = @import("span_types.zig").Lease;
pub const Machine = @import("machine_environment.zig").Environment;
pub const Session = extern struct { epoch: u32, level: i32, classification: u32, session: u32 };
pub const SessionProvider = *const fn (*Session) callconv(.c) c_int;
pub const FrameBinding = extern struct { token: Token, binding_serial: u64 };
pub const Provenance = extern struct { epoch: u32, release: u32, session: u32, level: i32, generation: u64, committed: u32 };
pub const Guard = extern struct { kind: u32, frame: Token, control: ControlLease, serial: u64, binding: u64, pending_generation: u64, epoch: u32, session: u32 };
pub const AssignmentVersion = *const fn () callconv(.c) u64;
pub const AssignmentRemap = *const fn (u64) callconv(.c) void;
pub const ControllerScope = struct { previous: ?*ControllerScope, actors: [2]usize, controllers: [2]usize, generations: [2]u32, serial: u64, registration: u64, assignment_version: u64, valid: bool, authority: Guard };
pub const Outcome = struct { machine: Machine, seen: bool };
pub const ActorUpdate = struct { previous: ?*ActorUpdate, actor: usize, update: *const fn (usize) callconv(.c) void, guard: Guard, outcome: Outcome };
pub const Transfer = *const fn (usize, usize, i32, i32, i32, i32, i32, i32) callconv(.c) c_int;
pub var original: Transfer = @ptrFromInt(0x8ae680);
pub export var clonewars_tag_debug: [12]u32 = @splat(0);
pub export var clonewars_tag_identity_debug: [18]u32 = @splat(0);
pub var current: ?*p.SyncFrame = null;
pub var pending = std.mem.zeroes([p.SYNC_MAX_TAGS]p.SyncTag);
pub var pending_count: usize = 0;
pub var epoch: u32 = 0;
pub var next_id: u32 = 0;
pub var last_applied: u32 = 0;
pub var replay_cursor: u32 = 0;
pub var active_event: u32 = 0;
pub var consumed: [p.SYNC_MAX_TAGS]u8 = @splat(0);
pub var host = false;
pub var active = false;
pub var failed: u32 = 0;
pub var frame_complete = false;
pub var initial_control_available = true;
pub var last_authorized_session: u32 = 0;
pub var last_authorized_epoch: u32 = 0;
pub var active_session: u32 = 0;
pub var scope_serial: u64 = 0;
pub var dispatch_revision: u64 = 0;
pub var scope_was_cancelled = false;
pub var replay_completed: u32 = 0;
pub var replay_corrected: u32 = 0;
pub var adapter: ?*Adapter = null;
pub var session_provider: ?SessionProvider = null;
pub var cohort = std.mem.zeroes(Token);
pub var cohort_bound = false;
pub var cohort_cancelled = false;
pub var bound_session: u32 = 0;
pub var binding_serial: u64 = 0;
pub var pending_generation: u64 = 1;
pub var provenance = std.mem.zeroes([p.SYNC_MAX_TAGS]Provenance);
pub threadlocal var actor_update: ?*ActorUpdate = null;
pub threadlocal var controller: ?*ControllerScope = null;
pub var assignment_version: ?AssignmentVersion = null;
pub var assignment_remap: ?AssignmentRemap = null;
pub var assignment_thread: u32 = 0;
pub var assignment_registration: u64 = 0;
pub const Clock = extern struct { clock: u32, rng_game: u32, rng_engine: u32, delta: f32 };
const clock_api = if (@hasDecl(@import("root"), "tag_test_api")) @import("root").tag_test_api else struct {
    pub fn readClock() Clock {
        return .{ .clock = win.load(u32, 0xfb4b6c), .rng_game = win.load(u32, 0xe637b4), .rng_engine = win.load(u32, 0xea178c), .delta = win.load(f32, 0xfb4b74) };
    }
    pub fn writeClock(value: Clock) void {
        win.store(u32, 0xfb4b6c, value.clock);
        win.store(u32, 0xe637b4, value.rng_game);
        win.store(u32, 0xea178c, value.rng_engine);
        win.store(f32, 0xfb4b74, value.delta);
    }
};
pub const readClock = clock_api.readClock;
pub const writeClock = clock_api.writeClock;
pub extern fn coherent_frame_valid(*const Token, u32) c_int;
pub extern fn coherent_frame_release() u32;
pub extern fn coherent_frame_cancel_atomic(u32) void;
pub extern fn span_engine_control_get(*Adapter, *ControlLease) c_int;
pub extern fn span_engine_control_valid(*Adapter, *const ControlLease) c_int;
pub extern fn lan_is_host() c_int;
pub extern fn entities_update() void;
pub extern fn entities_slot(usize) c_int;
pub extern fn entities_local_generation(usize) u32;
pub extern fn entities_allocation_live(usize, u32) c_int;
pub extern fn entities_describe(*p.SyncActor, usize) void;
pub extern fn entities_resolve_reference(*const p.SyncActor) usize;
pub extern fn entities_bind_tick(*const p.SyncFrame) c_int;
pub extern fn entities_party_matches(*const p.SyncFrame) c_int;
pub fn reject(reason: u32) void {
    coherent_frame_cancel_atomic(@as(u32, 1) << @intCast(reason % 31));
}
pub fn progress() bool {
    if (dispatch_revision == std.math.maxInt(u64)) {
        failed = 4;
        reject(22);
        return false;
    }
    dispatch_revision += 1;
    return true;
}
