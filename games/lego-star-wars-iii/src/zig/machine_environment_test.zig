const std = @import("std");
const Environment = @import("machine_environment.zig").Environment;
const Vec = @Vector(4, f32);
noinline fn restoredComputation(input: Vec, output: *[4]f32) void {
    var machine: Environment = undefined;
    machine.capture();
    const increment: Vec = .{ 5, 7, 11, 13 };
    const calculated = asm volatile ("addps %[increment], %[result]"
        : [result] "=x" (-> Vec),
        : [input] "0" (input),
          [increment] "x" (increment),
        : .{ .memory = true });
    @memset(machine.fx[160..288], 0xff);
    machine.restore();
    output.* = calculated;
}
pub fn main() void {
    var original: Environment = undefined;
    original.capture();
    defer original.restore();
    var output: [4]f32 = undefined;
    restoredComputation(.{ 2, 3, 4, 5 }, &output);
    std.debug.assert(std.mem.eql(f32, &output, &.{ 7, 10, 15, 18 }));
}
