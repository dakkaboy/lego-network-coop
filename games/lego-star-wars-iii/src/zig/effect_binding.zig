const std = @import("std");
pub const Binding = struct { node: usize = 0, receiver: usize = 0, body: usize = 0, resource: usize = 0, epoch: u32 = 0, sequence: u32 = 0, event: u32 = 0, release: u32 = 0 };
pub fn resolve(bindings: []Binding, body: usize, epoch: u32, release: u32, context: anytype, comptime validate: anytype, source: *[2]u32, revoked: *u32) i32 {
    revoked.* = 0;
    var found: ?*const Binding = null;
    for (bindings, 0..) |*binding, i| {
        if (binding.epoch != epoch or binding.release != release or binding.body != body) continue;
        if (!validate(binding, i, context)) {
            binding.* = std.mem.zeroes(Binding);
            revoked.* += 1;
            continue;
        }
        if (found != null) return -1;
        found = binding;
    }
    const binding = found orelse return 0;
    source.* = .{ binding.sequence, binding.event };
    return 1;
}
pub fn bodyForSource(bindings: []Binding, source: [2]u32, epoch: u32, release: u32, context: anytype, comptime validate: anytype, body: *usize, revoked: *u32) i32 {
    revoked.* = 0;
    if (source[0] == 0 or source[1] == 0) return 0;
    var found: ?*const Binding = null;
    for (bindings, 0..) |*binding, i| {
        if (binding.epoch != epoch or binding.release != release or binding.sequence != source[0] or binding.event != source[1]) continue;
        if (binding.body == 0 or !validate(binding, i, context)) {
            binding.* = std.mem.zeroes(Binding);
            revoked.* += 1;
            continue;
        }
        if (found != null) return -1;
        found = binding;
    }
    body.* = (found orelse return 0).body;
    return 1;
}
