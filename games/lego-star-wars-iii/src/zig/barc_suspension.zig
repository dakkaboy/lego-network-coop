const std = @import("std");
const s = @import("cadence_state.zig");
const p = @import("protocol.zig");
const vehicles = @import("vehicle_body_source.zig");
const read = s.read;

pub extern fn barc_suspension_thunk() void;
export var barc_suspension_resume: usize = 0x99a3a1;
pub export var clonewars_barc_suspension_debug: [4]u32 = @splat(0);
pub export var clonewars_barc_suspension_first: [9]u32 = @splat(0);

const Source = struct {
    identity: vehicles.Identity,
    body: usize,
    config: usize,
    serial: u16,
    counter: u32,
    flags: u8,
    cache_index: u8,

    fn phase(self: Source) u32 {
        return (self.serial ^ self.counter) & 1;
    }
};

fn source(component: usize, actor: usize, character: u16) ?Source {
    var access: s.win.AccessCache = .{};
    if (!access.accessible(component, 0x166c, false) or read(u8, component + 0x1664) & 0x20 != 0) return null;
    const driver = read(usize, component + 0x294);
    if (!access.accessible(driver, 0x264, false) or read(u32, driver) != 0xc5fff4) return null;
    const body = read(usize, driver + 0x260);
    if (!access.accessible(body, 0xa0, false)) return null;
    const dynamics = read(usize, body + 0x98);
    if (dynamics == 0 or dynamics != read(usize, driver + 0x240)) return null;
    const flags = read(u8, body + 0x19);
    const identify = @import("barc_alignment.zig").controllerIdentity;
    const identity = switch (character) {
        417 => identify(component, body, actor, flags, vehicles.alignmentBody),
        429 => if (read(u32, component + 0x60) == 4) identify(component, body, actor, flags, vehicles.rxSuspensionBody) else null,
        else => null,
    } orelse return null;
    const config = read(usize, component + 0x298);
    if (!access.accessible(config, 0x26c, false)) return null;
    return .{ .identity = identity, .body = body, .config = config, .serial = read(u16, component + 0x936), .counter = read(u32, config + 0x268), .flags = flags, .cache_index = (read(u8, component + 0x1667) >> 1) & 1 };
}

fn fail(lease: *const s.Lease, actor: usize) void {
    if (!s.live(lease) or s.journal.failed != 0) return;
    clonewars_barc_suspension_debug[3] +%= 1;
    s.journal.failed = 25;
    s.failed(lease, actor, null, 25);
}

pub export fn barc_suspension_input(component: usize, native_phase: u32) u32 {
    const last_error = s.win.GetLastError();
    defer s.win.SetLastError(last_error);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or lease.cohort.thread != s.win.GetCurrentThreadId() or
        s.journal.frame.?.level != 112 or !s.valid(component, 0x2a0)) return native_phase;
    const actor = read(usize, component + 0x29c);
    if (!s.valid(actor, 0x1440)) return native_phase;
    const character = read(u16, actor + 0xdc0);
    if (character != 417 and character != 429) return native_phase;
    const local = source(component, actor, character) orelse {
        fail(&lease, actor);
        return native_phase;
    };
    if (local.phase() != native_phase & 1) {
        fail(&lease, actor);
        return native_phase;
    }

    const clock = read(u32, 0xfb4b6c);
    var context: p.SyncBarcSuspensionState = .{ .clock = clock, .body_flags = local.flags, .cache_index = local.cache_index };
    const phase = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_BARC_SUSPENSION, 0, 0, @intCast(local.phase()), @ptrCast(&context), &clonewars_barc_suspension_debug);
    if (!s.live(&lease) or s.journal.failed != 0 or s.journal.host != 0) return native_phase;
    const current = source(component, actor, character) orelse {
        fail(&lease, actor);
        return native_phase;
    };
    if (!std.meta.eql(local, current) or !s.live(&lease) or read(u32, 0xfb4b6c) != clock or
        context.clock != clock or context.body_flags != local.flags or context.cache_index != local.cache_index or
        phase < 0 or phase > 1)
    {
        fail(&lease, actor);
        return native_phase;
    }
    const canonical: u32 = @intCast(phase);
    if (canonical != local.phase() and clonewars_barc_suspension_first[0] == 0) {
        const frame = s.journal.frame.?;
        clonewars_barc_suspension_first = .{ frame.epoch, frame.sequence, clock, local.identity.slot, local.identity.generation, local.serial, local.counter, local.phase(), canonical };
    }
    // The stock branch still selects and executes the native floor query or uses its own cached value.
    return (native_phase & ~@as(u32, 1)) | canonical;
}

comptime {
    asm (
        \\.text
        \\.globl _barc_suspension_thunk
        \\_barc_suspension_thunk:
        \\xorl 0x268(%edx),%ecx
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\subl $8,%esp
        \\pushl 24(%edx)
        \\pushl 16(%edx)
        \\call _barc_suspension_input
        \\addl $16,%esp
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\movl %eax,24(%esp)
        \\popal
        \\popfl
        \\jmp *_barc_suspension_resume
    );
}
