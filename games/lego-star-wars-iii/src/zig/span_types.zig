const owner = @import("owner_types.zig");
pub const Control = extern struct { epoch: u32, level: i32, established: u32 };
pub const Lease = extern struct { owner: ?*owner.Scope, owner_nonce: u32, thread: u32, root_serial: u32, release: u32, epoch: u32, level: i32, delegate_esp: usize };
pub const Callbacks = extern struct {
    version: u32,
    user: usize,
    reject_atomic: ?*const fn (u32, usize) callconv(.c) void,
    install_safe: ?*const fn (usize, *const owner.Input, usize) callconv(.c) c_int,
    dependencies_ready: ?*const fn (usize) callconv(.c) c_int,
    main_confirmed: ?*const fn (u32, usize) callconv(.c) c_int,
    control_context: ?*const fn (*Control, usize) callconv(.c) c_int,
    enter: ?*const fn (*owner.Scope, u32, usize, usize, [*]const u32, usize, u32, usize) callconv(.c) u32,
    marker: ?*const fn (*owner.Scope, u32, u32, usize) callconv(.c) void,
    finish: ?*const fn (*owner.Scope, u32, usize) callconv(.c) void,
    end: ?*const fn (*owner.Scope, u32, c_int, u32, usize) callconv(.c) void,
};
pub const Adapter = extern struct {
    installer: @import("span_installer_types.zig").Installer,
    callbacks: Callbacks,
    image760000: usize,
    expected_vt: usize,
    root_global: usize,
    window_thread: u32,
    serial: i32,
    sticky: i32,
    qualified: i32,
    unowned: i32,
    bad_stack: i32,
    invalid_plan: i32,
    duplicates: i32,
    main_count: i32,
    optional_count: i32,
    rejected: i32,
};
