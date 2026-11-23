const std = @import("std");
const s = @import("sync_state.zig");
const a = @import("sync_core_test_api.zig");
const prepare = @import("sync_prepare.zig");
const finish = @import("sync_finish.zig");
const dispatch = @import("sync_dispatch.zig");
const fence = @import("frame_fence.zig");
const numeric = @import("numeric_input.zig");
const check = @import("native_test_support.zig").check;
pub const sync_test_api = a;
pub const tracy_enabled = true;
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var owned_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
comptime {
    _ = @import("input.zig");
    _ = @import("epoch.zig");
    _ = @import("preload.zig");
    _ = @import("lexical_seh.zig");
}
fn capture(fx: *[512]u8) void {
    asm volatile ("fxsave (%[value])"
        :
        : [value] "r" (fx),
        : .{ .memory = true });
}
fn enter(fx: *[512]u8) u32 {
    var regs: [9]u32 = @splat(0);
    regs[7] = @intFromPtr(&a.framework);
    regs[8] = 0x40;
    return prepare.enter(&a.owner, 3, @intFromPtr(&a.packet), @intFromPtr(&a.engine), &regs, @intFromPtr(fx), 1, 0);
}
fn body(_: usize) callconv(.c) c_int {
    prepare.marker(&a.owner, 3, 1, 0);
    dispatch.world(@intFromPtr(&a.world), 93);
    dispatch.tick(@intFromPtr(&a.root) + 0x1b44, 0);
    return 1;
}
fn close(mask: u32, exceptional: bool) void {
    const token = s.core.token;
    finish.end(&a.owner, 3, @intFromBool(exceptional), @intFromBool(exceptional), 0);
    check(@src(), a.aborted == mask);
    check(@src(), s.core.owner == null and s.outer_depth == 0 and !s.running and s.prep_gate_depth == 0);
    check(@src(), fence.coherent_frame_valid(&token, 0x3e) == 0);
    const profiling = @import("sync_profiling_test.zig").counts();
    check(@src(), profiling[0] == profiling[1] and profiling[2] == s.publish_count);
}
pub fn main() void {
    var window: prepare.FrameWindow = .{};
    check(@src(), window.update(1, 1, 0, 1000) == 3);
    check(@src(), window.update(1, 1, 16, 1500) == 5);
    check(@src(), window.update(1, 1, 46, 2000) == 8);
    check(@src(), window.update(1, 1, 51, 2500) == 3);
    check(@src(), window.update(1, 1, 81, 3000) == 8);
    check(@src(), window.update(1, 2, 0, 3001) == 3);
    check(@src(), @intFromPtr(&owned_image) <= 0x887ac0 and @intFromPtr(&owned_image) + owned_image.len > 0xfbdd30);
    a.initialize();
    defer _ = s.win.VirtualFree(@intFromPtr(a.saved_frame.?), 0, 0x8000);
    var original: [512]u8 align(16) = @splat(0);
    capture(&original);
    defer @import("machine_environment.zig").restoreFx(&original);
    var fx: [512]u8 align(16) = original;
    check(@src(), numeric.apply(&fx, .{ .cw = 0x23f, .mxcsr = 0x1f80 }));
    a.setup(.normal, true);
    check(@src(), enter(&fx) == 1);
    check(@src(), s.live() and s.running and s.core.bound_mask == 255 and s.working.sequence == 2);
    check(@src(), body(0) == 1);
    check(@src(), a.observed[2][0] == 16 and a.observed[2][1] == 32);
    finish.finish(&a.owner, 3, 0);
    check(@src(), s.fault == 0 and a.sent == 1 and s.core.published == 1);
    check(@src(), a.saved_frame.?.actor_count == 3 and a.saved_frame.?.actor_input_count == 1);
    check(@src(), a.saved_frame.?.world_calls == 1 and a.saved_frame.?.tick_calls == 1 and a.saved_frame.?.native_span_calls == 1);
    close(255, false);

    a.setup(.normal, false);
    a.peer_ready = false;
    for (0..3) |i| {
        s.store([3]f32, a.actorAt(i) + 0x24, .{ 99, 99, 99 });
        s.store([3]f32, a.actorAt(i) + 0xe2c, .{ 99, 99, 99 });
    }
    fx = original;
    check(@src(), enter(&fx) == 1);
    check(@src(), numeric.read(&fx).cw == a.saved_frame.?.numeric_cw);
    check(@src(), body(0) == 1);
    check(@src(), a.observed[2][0] == 16 and a.observed[2][1] == 32);
    finish.finish(&a.owner, 3, 0);
    check(@src(), s.fault == 0 and a.acknowledged == 2 and s.core.published == 1);
    check(@src(), s.load(u32, 0xe637b4) == a.saved_frame.?.rng_game_after);
    for (0..3) |i| {
        check(@src(), s.load(f32, a.actorAt(i) + 0x24) == @as(f32, @floatFromInt(i + 1)));
        check(@src(), s.load(f32, a.actorAt(i) + 0xe2c) == @as(f32, @floatFromInt(i + 1)));
    }
    close(255, false);

    a.setup(.normal, true);
    a.peer_ready = false;
    fx = original;
    check(@src(), enter(&fx) == 2 and s.core.opened == 0 and a.sent == 0);
    close(0, false);

    a.setup(.normal, false);
    a.peer_ready = false;
    a.received = true;
    fx = original;
    check(@src(), enter(&fx) == 2 and s.core.opened == 0 and s.expected == 1 and a.acknowledged == 0);
    close(0, false);

    for ([_]a.Mode{ .bind_failure, .tag_cancel, .geometry_failure, .collect_cancel, .projectile_reset, .drain_nested, .drain_stalled, .throw_prep, .send_failure }) |mode| {
        a.setup(mode, true);
        finish.clonewars_dispatch_drain_failure = @splat(0);
        fx = original;
        const result = enter(&fx);
        if (mode == .bind_failure or mode == .tag_cancel) {
            check(@src(), result == 2 and a.sent == 0);
            close(if (mode == .bind_failure) 15 else 255, false);
            continue;
        }
        check(@src(), result == 1);
        const completed = @import("seh_guard.zig").all(0, body);
        if (mode == .throw_prep) {
            check(@src(), completed == 0 and s.win.GetLastError() == 712 and s.prep_gate_depth == 0);
            close(255, true);
            continue;
        }
        check(@src(), completed == 1);
        finish.finish(&a.owner, 3, 0);
        if (mode == .drain_nested) {
            check(@src(), a.sent == 1 and s.core.published == 1 and s.fault == 0);
            check(@src(), a.projectile_completions == 2 and a.tag_completions == 1);
        } else {
            check(@src(), a.sent == 0 and s.core.published == 0);
            if (mode == .geometry_failure) check(@src(), s.fault == 15);
            if (mode == .send_failure) check(@src(), s.fault == 3);
            if (mode == .drain_stalled) {
                check(@src(), s.clonewars_sync_first_reject[0] == 29 and s.reject_bits != 0);
                check(@src(), finish.clonewars_dispatch_drain_failure[0] == 9 and finish.clonewars_dispatch_drain_failure[3] == 0 and finish.clonewars_dispatch_drain_failure[4] == 1 and finish.clonewars_dispatch_drain_failure[5] == 0);
            }
        }
        close(255, false);
    }
}
