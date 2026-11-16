const profiler = @import("profiler.zig");
const Machine = @import("machine_environment.zig").Environment;
const root = @import("root");
const enabled = @hasDecl(root, "tracy_enabled") and root.tracy_enabled;
var active: ?profiler.Zone = null;
pub fn begin() void {
    if (!enabled) return;
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    if (active) |previous| previous.end();
    active = profiler.zone(@src(), "coherent.frame");
}
pub fn end(published: bool) void {
    if (!enabled) return;
    const zone = active orelse return;
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    active = null;
    zone.end();
    if (published) profiler.frame();
}
