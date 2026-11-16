const root = @import("root");
const override = if (@hasDecl(root, "sync_test_platform")) root.sync_test_platform else struct {};
const real = struct {
    extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
    extern "kernel32" fn Sleep(u32) callconv(.winapi) void;
    extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
};
pub const now = if (@hasDecl(override, "now")) override.now else real.GetTickCount64;
pub const sleep = if (@hasDecl(override, "sleep")) override.sleep else real.Sleep;
pub const environment = if (@hasDecl(override, "environment")) override.environment else real.GetEnvironmentVariableA;
