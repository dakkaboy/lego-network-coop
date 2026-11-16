const c = @import("abi.zig").c;

export fn input_buffer_reset(buffer: *c.InputBuffer) void {
    buffer.* = .{ .latest = .{ .held = 0, .pressed = 0, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 }, .pending = 0 };
}

export fn input_buffer_sample(buffer: *c.InputBuffer, input: *const c.SyncInput) void {
    buffer.latest = input.*;
    buffer.pending |= input.pressed;
}

export fn input_buffer_take(buffer: *c.InputBuffer) c.SyncInput {
    var input = buffer.latest;
    input.pressed = buffer.pending;
    buffer.pending = 0;
    return input;
}

export fn remote_input_pulse_reset(pulse: *c.RemoteInputPulse) void {
    pulse.next_hold = 0;
}

export fn remote_input_execute(pulse: *c.RemoteInputPulse, incoming: *const c.SyncInput) c.SyncInput {
    var executed = incoming.*;
    executed.held |= incoming.pressed | pulse.next_hold;
    // The game needs the press held for one additional simulation step.
    pulse.next_hold = incoming.pressed;
    return executed;
}
