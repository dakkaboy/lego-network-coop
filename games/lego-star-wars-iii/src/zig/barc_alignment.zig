const std = @import("std");
const s = @import("cadence_state.zig");
const p = @import("protocol.zig");
const vehicles = @import("vehicle_body_source.zig");
const valid = @import("fire_validation.zig").barcBasis;
const read = s.read;

pub extern fn barc_alignment_thunk() void;
export var barc_alignment_native: usize = 0x98c290;
pub export var clonewars_barc_alignment_debug: [4]u32 = @splat(0);
pub export var clonewars_barc_alignment_first: [23]u32 = @splat(0);

pub fn controllerIdentity(component: usize, body: usize, actor: usize, flags: u8, comptime resolveBody: @TypeOf(vehicles.alignmentBody)) ?vehicles.Identity {
    var access: s.win.AccessCache = .{};
    if (!access.accessible(component, 0x166c, false) or read(usize, component + 0x29c) != actor or
        read(u8, component + 0x166b) & 4 == 0) return null;
    const driver = read(usize, component + 0x294);
    if (!access.accessible(driver, 0x264, false) or read(u32, driver) != 0xc5fff4 or
        read(usize, driver + 0x260) != body) return null;
    const identity = resolveBody(&access, body, flags) orelse return null;
    return if (identity.actor == actor) identity else null;
}

const lanes = [_]usize{ 0, 1, 2, 4, 5, 6, 8, 9, 10 };

fn basisAt(matrix: usize) [9]f32 {
    var basis: [9]f32 = undefined;
    for (&basis, lanes) |*value, lane| value.* = read(f32, matrix + 4 * lane);
    return basis;
}

fn fail(lease: *const s.Lease, actor: usize) void {
    if (!s.live(lease) or s.journal.failed != 0) return;
    clonewars_barc_alignment_debug[3] +%= 1;
    s.journal.failed = 24;
    s.failed(lease, actor, null, 24);
}

pub export fn barc_alignment_input(component: usize, entry: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or lease.cohort.thread != s.win.GetCurrentThreadId() or
        s.journal.frame.?.level != 112 or !s.valid(component, 0x2a0)) return;
    const actor = read(usize, component + 0x29c);
    if (!s.valid(actor, 0x1440) or read(u16, actor + 0xdc0) != 417) return;

    const original = entry + 0x38;
    if (!s.valid(entry, 0x38) or read(usize, entry) != 0x9977ce or read(usize, entry + 8) != original or
        read(u32, entry + 16) != 1 or read(u32, entry + 20) != 0 or !s.win.accessible(original, 64, true))
    {
        fail(&lease, actor);
        return;
    }
    const body = read(usize, entry + 4);
    const body_flags = if (s.valid(body, 0x1a)) read(u8, body + 0x19) else 0;
    const identity = controllerIdentity(component, body, actor, body_flags, vehicles.alignmentBody) orelse {
        fail(&lease, actor);
        return;
    };
    const clock = read(u32, 0xfb4b6c);
    const local = basisAt(original);
    if (!valid(&local)) {
        fail(&lease, actor);
        return;
    }
    var gate: p.SyncBarcAlignmentState = .{ .clock = clock, .body_flags = body_flags, .basis = local };
    _ = @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_BARC_ALIGNMENT, 0, 0, 0, @ptrCast(&gate), &clonewars_barc_alignment_debug);
    if (!s.live(&lease) or s.journal.failed != 0 or s.journal.host != 0) return;
    const current = controllerIdentity(component, body, actor, body_flags, vehicles.alignmentBody) orelse {
        fail(&lease, actor);
        return;
    };
    if (!std.meta.eql(current, identity) or !s.live(&lease) or gate.clock != clock or gate.body_flags != body_flags or read(u32, 0xfb4b6c) != clock or
        read(usize, entry + 4) != body or read(usize, entry + 8) != original or !s.win.accessible(original, 64, true) or
        !std.mem.eql(u32, &@as([9]u32, @bitCast(local)), &@as([9]u32, @bitCast(basisAt(original)))) or !valid(&gate.basis))
    {
        fail(&lease, actor);
        return;
    }
    if (!std.mem.eql(u32, &@as([9]u32, @bitCast(local)), &@as([9]u32, @bitCast(gate.basis)))) {
        clonewars_barc_alignment_debug[2] +%= 1;
        if (clonewars_barc_alignment_first[0] == 0) {
            const frame = s.journal.frame.?;
            clonewars_barc_alignment_first[0..5].* = .{ frame.epoch, frame.sequence, clock, identity.slot, identity.generation };
            clonewars_barc_alignment_first[5..14].* = @bitCast(local);
            clonewars_barc_alignment_first[14..23].* = @bitCast(gate.basis);
        }
        // The caller's temporary rotation feeds stock physics. Render caches and translation stay local.
        for (gate.basis, lanes) |value, lane| s.win.store(f32, original + lane * 4, value);
    }
}

comptime {
    asm (
        \\.globl _barc_alignment_thunk
        \\_barc_alignment_thunk:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    movl 12(%edx),%eax
        \\    addl $4,%eax
        \\    subl $8,%esp
        \\    pushl %eax
        \\    pushl 16(%edx)
        \\    call _barc_alignment_input
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_barc_alignment_native
    );
}
