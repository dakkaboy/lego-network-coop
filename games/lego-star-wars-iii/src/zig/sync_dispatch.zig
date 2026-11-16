const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const input = @import("sync_input.zig");
const authority = @import("sync_authority.zig");
extern fn constructor_lexical_seh(usize, *const fn (usize) callconv(.c) usize, *const fn (usize) callconv(.c) void) usize;
const Context = struct { first: usize, second: usize, bound: bool, tick: bool, token: s.Token, machine: s.Machine };
fn abort(raw: usize) callconv(.c) void {
    var machine: s.Machine = undefined;
    machine.capture();
    defer machine.restore();
    const context: *Context = @ptrFromInt(raw);
    if (context.bound and api.coherent_frame_close(&context.token) != 0) {
        api.coherent_frame_cancel_atomic(0x10000000);
        @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
    }
}
fn worldInput(area: usize) void {
    if (!s.running or !s.live()) return;
    s.global_step.worlds +%= 1;
    const first = s.global_step.input_taken == 0;
    s.global_step.input_taken = 1;
    if (api.game_native_scene_input_capability(s.working.level, area) == 2) {
        for (0..2) |slot| {
            if (s.changed_actor[slot] != 0 or s.changed_controller[slot] != 0) input.releaseAssignment(slot);
            s.working.inputs[slot] = .{ .held = 0, .pressed = 0, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
            s.latched_input[slot] = s.working.inputs[slot];
            s.pending_actor_pressed[slot] = 0;
        }
        s.latched_ready = false;
        return;
    }
    var remote_raw = std.mem.zeroes(s.p.SyncInput);
    if (first and api.lan_is_host() != 0) {
        s.working.inputs[0] = if (s.sampled_for_flow) api.input_buffer_take(&s.local_buffer) else input.read();
        remote_raw = api.lan_consume_input();
        s.working.inputs[1] = api.remote_input_execute(&s.remote_pulse, &remote_raw);
    } else if (first and !s.sampled_for_flow) {
        s.local_input = input.read();
        api.lan_publish_input(&s.local_input);
    }
    if (!s.live()) return;
    if (first) api.remote_input_trace_begin(&s.working, api.lan_is_host(), if (api.lan_is_host() != 0) &remote_raw else null, s.player(1));
    for (0..2) |slot| {
        s.latched_input[slot] = s.working.inputs[slot];
        if (first) s.pending_actor_pressed[slot] |= s.working.inputs[slot].pressed;
    }
    var step_input = s.working.inputs;
    if (!first) {
        step_input[0].pressed = 0;
        step_input[1].pressed = 0;
    }
    s.latched_ready = true;
    if ((input.write(0, &step_input[0]) == 0 or input.write(1, &step_input[1]) == 0) and s.live()) s.fault = 2;
}
fn worldImpl(context: *Context) void {
    const area = context.first;
    worldInput(area);
    context.machine.restore();
    const native: *const fn (usize, usize) callconv(.winapi) void = @ptrFromInt(0x887ac0);
    native(area, context.second);
    context.machine.capture();
    authority.noteWorldComplete();
    if (context.bound and api.coherent_frame_valid(&context.token, 4) == 0) return;
    if (context.bound and api.object_progress_world_complete(area, &context.token) == 0) return;
    const root = s.load(usize, 0xfb2e60);
    if (s.valid(root, 0x1b7c) and (s.load(i32, root + 0x1b78) == 0xd or s.load(i32, root + 0x1b78) == 0xe)) authority.noteInitializedLevel(api.game_current_level());
}
fn tickImpl(context: *Context) void {
    const native: *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x889640);
    if (s.win.GetCurrentThreadId() != s.window_thread) {
        api.coherent_frame_cancel_atomic(0x10000000);
        context.machine.restore();
        native(context.first);
        context.machine.capture();
        return;
    }
    if (s.tick_thread == 0) {
        s.tick_thread = s.win.GetCurrentThreadId();
        _ = api.coherent_frame_register_main();
        api.tags_observe_controller_handoffs(input.assignmentVersion, input.assignmentRemap);
    }
    if (!@import("sync_preload.zig").tick(context.first)) return;
    if (s.running) s.global_step.ticks +%= 1;
    api.spawn_observer_flow(1);
    api.combat_observer_flow(1);
    context.machine.restore();
    native(context.first);
    context.machine.capture();
    api.combat_observer_flow(0);
    api.spawn_observer_flow(0);
}
fn invoke(raw: usize) callconv(.c) usize {
    const context: *Context = @ptrFromInt(raw);
    if (context.tick) tickImpl(context) else worldImpl(context);
    return 0;
}
fn run(first: usize, second: usize, is_tick: bool) void {
    var context: Context = undefined;
    context.machine.capture();
    context.first = first;
    context.second = second;
    context.tick = is_tick;
    context.bound = s.captureDispatch(&context.token);
    _ = constructor_lexical_seh(@intFromPtr(&context), invoke, abort);
    context.machine.restore();
}
pub fn world(area: usize, output: usize) callconv(.winapi) void {
    run(area, output, false);
}
pub fn tick(flow: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) void {
    run(flow, 0, true);
}
