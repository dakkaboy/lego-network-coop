comptime {
    @setEvalBranchQuota(100000);
    const b = @import("tick_bridge_code.zig");
    for (b.names) |name| asm (b.code(name));
}
