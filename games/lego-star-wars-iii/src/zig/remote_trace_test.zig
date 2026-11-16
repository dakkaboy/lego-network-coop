const std = @import("std");
const trace = @import("remote_input_trace.zig");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const check = @import("native_test_support.zig").check;
pub const remote_input_trace_enabled = true;
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
var generation: u32 = 17;
pub export fn entities_observed_generation(_: usize) u32 {
    return generation;
}
pub export fn entities_observed_identity(_: usize, slot: *u32, value: *u32) c_int {
    slot.* = 9;
    value.* = 13;
    return 1;
}
pub fn main() void {
    check(@src(), @intFromPtr(&owned_image) <= 0xfb0000 and @intFromPtr(&owned_image) + owned_image.len > 0xfbd8f0);
    var actor: [0x2000]u8 align(16) = @splat(0);
    var controller: [0x1000]u8 align(16) = @splat(0);
    const pointer = @intFromPtr(&actor);
    win.store(usize, pointer + 0x6cc, @intFromPtr(&controller));
    win.store(u32, pointer + 0x50, 3);
    win.store(i16, pointer + 0xdc0, 321);
    win.store(u32, pointer + 0x128, 7);
    win.store(u32, @intFromPtr(&controller) + 4, 3);
    win.store(u32, @intFromPtr(&controller) + 8, 1);
    const frame: *p.SyncFrame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(frame) != 0);
    defer _ = win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    frame.epoch = 7;
    frame.sequence = 19;
    frame.inputs[1] = .{ .held = 3, .pressed = 1, .analog_x = 11, .analog_y = 22, .aim_x = 33, .aim_y = 44 };
    const raw = p.SyncInput{ .held = 4, .pressed = 2, .analog_x = 55, .analog_y = 66, .aim_x = 77, .aim_y = 88 };
    var expected = std.mem.zeroes([512]trace.Record);
    check(@src(), trace.clonewars_remote_input_trace_stride == 168 and trace.clonewars_remote_input_trace_disabled == 0);
    for (0..600) |index| {
        const i: u32 = @intCast(index);
        win.store(u32, 0xfb4b6c, i);
        generation = 17;
        const host = i % 2 == 0;
        const input: ?*const p.SyncInput = if (i % 3 != 0) &raw else null;
        trace.remote_input_trace_begin(frame, @intFromBool(host), input, pointer);
        check(@src(), trace.remote_input_trace_before(pointer, 0) == 0 and trace.remote_input_trace_before(pointer, 1) == 1 and trace.remote_input_trace_before(pointer, 1) == 0);
        if (i % 5 == 0) generation += 1;
        trace.remote_input_trace_after(pointer, 1);
        const reset = i % 7 == 0;
        if (reset) trace.remote_input_trace_reset() else trace.remote_input_trace_finish(i, pointer);
        var row = std.mem.zeroes(trace.Record);
        row.committed = i + 1;
        row.id = i + 1;
        row.epoch = 7;
        row.sequence = 19;
        row.clock = i;
        row.raw_known = @intFromBool(host);
        row.raw_held = if (input != null) 4 else 0xffffffff;
        row.raw_pressed = if (input != null) 2 else 0xffffffff;
        row.executed_held = 3;
        row.executed_pressed = 1;
        row.prep_calls = 2;
        row.fault = if (reset) 0xffffffff else i;
        row.owner_before = .{ .slot = 9, .generation = 13, .character = 321 };
        row.owner_after = if (reset) .{ .slot = 0xffffffff, .generation = 0, .character = -1 } else row.owner_before;
        row.before = .{ .valid = 1, .slot = 9, .generation = 13, .local_generation = 17, .character = 321, .mask = 7, .timer = 0, .flags = 0, .held = 3, .pressed = 1 };
        row.after = if (i % 5 != 0) row.before else .{ .valid = 0, .slot = 0xffffffff, .generation = 0, .local_generation = 18, .character = -1, .mask = 0, .timer = 0, .flags = 0, .held = 0, .pressed = 0 };
        row.raw_axes = if (host and input != null) 0x584d4237 else 0xffffffff;
        row.executed_axes = 0x2c21160b;
        expected[i % 512] = row;
        check(@src(), trace.clonewars_remote_input_trace_count == i + 1 and std.mem.eql(u8, std.mem.asBytes(&expected), std.mem.asBytes(&trace.clonewars_remote_input_trace)));
    }
}
