comptime {
    @setEvalBranchQuota(100000);
    const bridges = @import("cadence_bridge_code.zig");
    for (bridges.names) |name| asm (bridges.code(name));
}
