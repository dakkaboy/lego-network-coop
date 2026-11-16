const Machine = @import("machine_environment.zig").Environment;
pub const Kind = enum(u32) { prepare = 1, dispatch = 2, finish = 3, publish = 4, reject = 5, end = 6, fault = 7 };
extern fn clonewars_zig_trace_event(u32, u32, u32, u32, u32, u32, u32) void;
pub fn point(kind: Kind, epoch: u32, sequence: u32, local: u32, remote: u32, detail: u32) void {
    var machine: Machine = undefined;
    machine.capture();
    defer machine.restore();
    clonewars_zig_trace_event(4, epoch, sequence, @backingInt(kind), local, remote, detail);
}
