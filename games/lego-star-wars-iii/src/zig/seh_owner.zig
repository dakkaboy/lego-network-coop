comptime {
    asm (@import("seh_finally.zig").code("owner_c", "owner_enter", "inner_bridge", "owner_leave"));
}
