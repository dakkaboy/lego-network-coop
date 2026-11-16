pub const Patch = extern struct { address: usize, length: u32, original: [8]u8, replacement: [8]u8 };
pub const Ops = extern struct {
    context: usize,
    protect: ?*const fn (usize, usize, usize, u32, *u32) callconv(.c) c_int,
    flush: ?*const fn (usize, usize, usize) callconv(.c) c_int,
    write: ?*const fn (usize, usize, usize, usize) callconv(.c) c_int,
    equal: ?*const fn (usize, usize, usize, usize) callconv(.c) c_int,
};
pub const Installer = extern struct {
    busy: i32,
    state: i32,
    ready: i32,
    slot: usize,
    original_target: usize,
    owner_target: usize,
    code_page: usize,
    code_size: usize,
    forbidden: usize,
    forbidden_size: usize,
    sites: [4]Patch,
    ops: Ops,
    main_thread: u32,
    generation: u32,
    terminal: i32,
    failure_phase: u32,
    rollback_verified: u32,
};
pub const Qualification = extern struct { generation: u32, thread: u32, caller_verified: u32, quiescent: u32, owner_configured: u32, main_confirmed: u32 };
