pub const Stamp = extern struct { assignment: u32, epoch: u32, level: u32, release: u32, owner_nonce: u32, root_serial: u32 };
pub const Provenance = extern struct { assignment: u32, epoch: u32, level: u32, release: u32, owner_nonce: u32, root_serial: u32, proof_bytes: u32, proof: [64]u8 };
pub const Request = extern struct { user: i32, requested: i32, saved_negative: i32, source: Provenance };
pub const Key = extern struct { slot: u32, id: u32 };
pub const Ticket = extern struct { key: Key, source: Stamp, user: i32, requested: i32, saved_negative: i32, actual: i32, generation: u32, reset_generation: u32, flags: u32 };
pub const Observation = extern struct { ticket: Ticket, generation: u32, committed_generation: u32, reset_generation: u32, setter_depth: u32, writer_depth: u32, poller_depth: u32, disabled: u32, quality: u32, current_actual: i32 };
pub const SourceValid = *const fn (usize, u32) callconv(.c) c_int;
pub const Config = extern struct { version: u32, main_thread: u32, targets: [8]usize, native_table: usize, native_owners: usize, original_source_valid: ?SourceValid };
pub const InstallConfig = extern struct { main_thread: u32, original_source_valid: ?SourceValid, install_allowed: ?*const fn (usize) callconv(.c) c_int, user: usize };
pub const Bridge = extern struct {
    in_fx: [512]u8 align(16),
    out_fx: [512]u8,
    in_regs: [9]u32,
    out_regs: [9]u32,
    in_error: u32,
    out_error: u32,
    entry_esp: u32,
    saved_esp: u32,
    target: usize,
    reserved: u32,
    helper_fx: [512]u8,
    reserved_metadata: [120]u8,
    site: u32,
    args: [2]i32,
    storage: [1024]u8,
};
pub const Marker = extern struct { previous: ?*Marker, previous_physical: ?*Marker, request: Request, key: Key, entered: u32, linked: u32, admitted: u32, claimed: u32 };
pub const SessionConfig = extern struct { version: u32, main_thread: u32, safe_main_valid: ?*const fn (usize, u32, usize) callconv(.c) c_int, current_session: ?*const fn (usize) callconv(.c) u32, user: usize };
pub const Acquire = extern struct { row: usize, session_serial: u32, entered: u32, sent: u32, key: Key };
pub const Drain = extern struct { row: usize, locked: u32, consumed: u32, returned: u32, boundary_bytes: u32, observed: u32, negative: i32, boundary: [64]u8 };
