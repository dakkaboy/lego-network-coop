const std = @import("std");
const Gizmo = @import("gizmo_types.zig").Source;
pub const RenderCohort = struct {
    source: Gizmo = std.mem.zeroes(Gizmo),
    epoch: u32 = 0,
    clock: u32 = 0,
    valid: bool = false,
    pub fn primary(self: *RenderCohort, next: *const Gizmo, epoch: u32, clock: u32, flag: u32) u32 {
        if (flag == 0) return flag;
        const old = &self.source;
        if (self.valid and self.epoch == epoch and self.clock == clock and old.world == next.world and old.container == next.container and old.registry == next.registry and old.handle == next.handle and old.table == next.table and old.manager == next.manager and old.manager_class == next.manager_class and old.manager_index == next.manager_index and std.mem.eql(u32, &old.key, &next.key)) return 0;
        self.source = next.*;
        self.epoch = epoch;
        self.clock = clock;
        self.valid = true;
        return flag;
    }
};
