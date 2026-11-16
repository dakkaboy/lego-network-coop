pub const c = @This();
pub const SYNC_PROFILE_BYTES = 0xb5c0;
pub const SYNC_MAX_PRELOAD_FLOW_REQUESTS = 64;
pub const SYNC_MAX_ACTORS = 4096;
pub const SyncInput = @import("protocol.zig").SyncInput;
pub const InputBuffer = extern struct { latest: SyncInput, pending: u32 };
pub const RemoteInputPulse = extern struct { next_hold: u32 };
pub const SyncEpochCursor = extern struct { epoch: u32, sequence: u32, level: i32, active: c_int };
pub const SyncProfile = @import("protocol.zig").SyncProfile;
pub const ProfileBootstrapContext = extern struct { session: u32, epoch: u32, level: i32 };
pub const ProfileBootstrapHostState = extern struct { context: ProfileBootstrapContext, captured: u32, initial: SyncProfile };
pub const ProfileBootstrapClientState = extern struct { context: ProfileBootstrapContext, applied: u32 };
pub const SyncPreloadInput = @import("protocol.zig").SyncPreloadInput;
pub const SyncPreloadTrack = @import("protocol.zig").SyncPreloadTrack;
pub const SyncPreloadReceipt = @import("protocol.zig").SyncPreloadReceipt;
pub const SyncWorldReady = @import("protocol.zig").SyncWorldReady;
pub const NativePreloadState = extern struct {
    session: u32,
    epoch: u32,
    level: c_int,
    world: usize,
    input: SyncPreloadInput,
    applied: SyncPreloadReceipt,
    completed: c_int,
    sealed_serial: u32,
};

pub extern fn input_buffer_reset(*InputBuffer) void;
pub extern fn input_buffer_sample(*InputBuffer, *const SyncInput) void;
pub extern fn input_buffer_take(*InputBuffer) SyncInput;
pub extern fn remote_input_pulse_reset(*RemoteInputPulse) void;
pub extern fn remote_input_execute(*RemoteInputPulse, *const SyncInput) SyncInput;
pub extern fn sync_epoch_begin(*SyncEpochCursor, c_int) u32;
pub extern fn sync_epoch_loading(*SyncEpochCursor) void;
pub extern fn sync_epoch_classify(*const SyncEpochCursor, c_int, u32, c_int, u32) c_int;
pub extern fn sync_epoch_apply(*SyncEpochCursor, c_int, u32, c_int, u32) c_int;
pub extern fn sync_epoch_unacknowledged(*const SyncEpochCursor, u32, u32) u32;
pub extern fn sync_epoch_profile_ready(*const SyncEpochCursor, u32, u32) c_int;
pub extern fn profile_bootstrap_context_valid(?*const ProfileBootstrapContext) c_int;
pub extern fn profile_bootstrap_profile_valid(?*const SyncProfile, ?*const ProfileBootstrapContext) c_int;
pub extern fn profile_bootstrap_host_reset(?*ProfileBootstrapHostState) void;
pub extern fn profile_bootstrap_host_bind(?*ProfileBootstrapHostState, ?*const ProfileBootstrapContext) c_int;
pub extern fn profile_bootstrap_host_capture(?*ProfileBootstrapHostState, ?*const ProfileBootstrapContext, ?*const anyopaque, usize, u32) c_int;
pub extern fn profile_bootstrap_host_initial(?*const ProfileBootstrapHostState, ?*const ProfileBootstrapContext) ?*const SyncProfile;
pub extern fn profile_bootstrap_client_reset(?*ProfileBootstrapClientState) void;
pub extern fn profile_bootstrap_client_bind(?*ProfileBootstrapClientState, ?*const ProfileBootstrapContext) c_int;
pub extern fn profile_bootstrap_client_should_apply(?*const ProfileBootstrapClientState, ?*const ProfileBootstrapContext, c_int) c_int;
pub extern fn profile_bootstrap_client_is_applied(?*const ProfileBootstrapClientState, ?*const ProfileBootstrapContext) c_int;
pub extern fn profile_bootstrap_client_accepts_packet(?*const ProfileBootstrapClientState, ?*const ProfileBootstrapContext, ?*const SyncProfile, c_int) c_int;
pub extern fn profile_bootstrap_client_mark_applied(?*ProfileBootstrapClientState, ?*const ProfileBootstrapContext) c_int;
pub extern fn preload_input_valid(?*const SyncPreloadInput) c_int;
pub extern fn preload_receipt_valid(?*const SyncPreloadReceipt) c_int;
pub extern fn preload_state_bind(?*NativePreloadState, u32, u32, c_int, usize) void;
pub extern fn preload_state_accept(?*NativePreloadState, ?*const SyncPreloadInput) c_int;
pub extern fn preload_state_finish(?*NativePreloadState, ?*const SyncPreloadReceipt) c_int;
pub extern fn preload_state_seal(?*NativePreloadState, u32) c_int;
pub extern fn preload_initial_seal_ready(?*const NativePreloadState, u32) c_int;
pub extern fn preload_state_peer_receipt(?*const NativePreloadState, ?*const SyncPreloadReceipt) c_int;

pub fn validLevel(level: i32) bool {
    return level >= 0 and level < 4096;
}

pub fn checksum(bytes: []const u8) u32 {
    var value: u32 = 2166136261;
    for (bytes) |byte| value = (value ^ byte) *% 16777619;
    return value;
}
