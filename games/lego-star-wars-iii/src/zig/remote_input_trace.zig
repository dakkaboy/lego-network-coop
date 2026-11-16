const std = @import("std");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const root = @import("root");
const enabled = if (@hasDecl(root, "remote_input_trace_enabled")) root.remote_input_trace_enabled else false;
const Owner = extern struct { slot: u32 = 0xffffffff, generation: u32 = 0, character: i32 = -1 };
const Tracker = extern struct {
    valid: u32 = 0,
    slot: u32 = 0xffffffff,
    generation: u32 = 0,
    local_generation: u32 = 0,
    character: i32 = -1,
    mask: u32 = 0,
    timer: u32 = 0,
    flags: u32 = 0,
    held: u32 = 0,
    pressed: u32 = 0,
};
pub const Record = extern struct {
    committed: u32,
    id: u32,
    epoch: u32,
    sequence: u32,
    clock: u32,
    raw_known: u32,
    raw_held: u32,
    raw_pressed: u32,
    executed_held: u32,
    executed_pressed: u32,
    prep_calls: u32,
    tag_mode: u32,
    tag_callback: u32,
    fault: u32,
    owner_before: Owner,
    owner_after: Owner,
    before: Tracker,
    after: Tracker,
    raw_axes: u32,
    executed_axes: u32,
};
pub export var clonewars_remote_input_trace_count: u32 = 0;
pub export var clonewars_remote_input_trace_version: u32 = 2;
pub export var clonewars_remote_input_trace_stride: u32 = @sizeOf(Record);
pub export var clonewars_remote_input_trace_capacity: u32 = 512;
pub export var clonewars_remote_input_trace_disabled: u32 = @intFromBool(!enabled);
pub export var clonewars_remote_input_trace: [512]Record = @splat(std.mem.zeroes(Record));
var current = std.mem.zeroes(Record);
var active = false;
extern fn entities_observed_identity(usize, *u32, *u32) void;
extern fn entities_observed_generation(usize) u32;
fn word(address: usize) u32 {
    return win.load(u32, address);
}
fn owner(actor: usize) Owner {
    var value: Owner = .{};
    if (win.accessible(actor, 0x1440, false)) {
        entities_observed_identity(actor, &value.slot, &value.generation);
        value.character = win.load(i16, actor + 0xdc0);
    }
    return value;
}
fn tracker(value: *Tracker, actor: usize, expected_generation: u32) void {
    value.* = .{};
    if (!win.accessible(actor, 0x1440, false) or word(actor + 0x50) & 3 != 3) return;
    value.local_generation = entities_observed_generation(actor);
    if (expected_generation != 0 and value.local_generation != expected_generation) return;
    const controller = win.load(usize, actor + 0x6cc);
    if (!win.accessible(controller, 12, false)) return;
    value.valid = 1;
    entities_observed_identity(actor, &value.slot, &value.generation);
    value.character = win.load(i16, actor + 0xdc0);
    value.mask = word(actor + 0x128);
    value.timer = word(actor + 0x130);
    value.flags = win.load(u8, actor + 0x134);
    value.held = word(controller + 4);
    value.pressed = word(controller + 8);
}
fn axes(input: *const p.SyncInput) u32 {
    return @as(u32, input.analog_x) | (@as(u32, input.analog_y) << 8) | (@as(u32, input.aim_x) << 16) | (@as(u32, input.aim_y) << 24);
}
pub export fn remote_input_trace_reset() void {
    if (comptime enabled) {
        if (active) remote_input_trace_finish(0xffffffff, 0);
    }
}
pub export fn remote_input_trace_begin(frame: *const p.SyncFrame, host: c_int, raw: ?*const p.SyncInput, actor: usize) void {
    if (comptime !enabled) return;
    current = std.mem.zeroes(Record);
    current.id = @atomicRmw(u32, &clonewars_remote_input_trace_count, .Add, 1, .seq_cst) +% 1;
    current.epoch = frame.epoch;
    current.sequence = frame.sequence;
    current.clock = word(0xfb4b6c);
    current.raw_known = @intFromBool(host != 0);
    current.raw_held = if (raw) |r| r.held else 0xffffffff;
    current.raw_pressed = if (raw) |r| r.pressed else 0xffffffff;
    current.executed_held = frame.inputs[1].held;
    current.executed_pressed = frame.inputs[1].pressed;
    current.raw_axes = if (host != 0 and raw != null) axes(raw.?) else 0xffffffff;
    current.executed_axes = axes(&frame.inputs[1]);
    current.tag_mode = word(0xfbd8ec);
    current.tag_callback = word(0xfb50b4);
    current.owner_before = owner(actor);
    active = true;
}
pub export fn remote_input_trace_before(actor: usize, remote_hero: c_int) c_int {
    if (comptime !enabled) return 0;
    if (!active or remote_hero == 0) return 0;
    const prior = current.prep_calls;
    current.prep_calls +%= 1;
    if (prior != 0) return 0;
    tracker(&current.before, actor, 0);
    return 1;
}
pub export fn remote_input_trace_after(actor: usize, sampled: c_int) void {
    if (comptime enabled) {
        if (active and sampled != 0 and current.before.valid != 0) tracker(&current.after, actor, current.before.local_generation);
    }
}
pub export fn remote_input_trace_finish(fault: u32, actor: usize) void {
    if (comptime !enabled) return;
    if (!active) return;
    active = false;
    current.fault = fault;
    current.owner_after = owner(actor);
    const row = &clonewars_remote_input_trace[(current.id -% 1) % clonewars_remote_input_trace.len];
    @atomicStore(u32, &row.committed, 0, .seq_cst);
    row.* = current;
    @atomicStore(u32, &row.committed, current.id, .seq_cst);
}
comptime {
    std.debug.assert(@sizeOf(Record) == 168);
}
