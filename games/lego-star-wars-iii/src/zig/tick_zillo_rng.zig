const s = @import("tick_state.zig");
const p = @import("protocol.zig");
const Reader = @import("memory_reader.zig").Reader;
const Machine = @import("machine_environment.zig").Environment;
const win = @import("win32.zig");
const Throw = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
const Release = *const fn (usize, usize, usize) callconv(.{ .x86_thiscall = .{} }) void;

pub export var clonewars_zillo_throw_seed_debug: [4]u32 = @splat(0);
pub export var clonewars_zillo_throw_seed_correction: [8]u32 = @splat(0);
pub export var clonewars_zillo_release_seed_debug: [4]u32 = @splat(0);
pub export var clonewars_zillo_release_seed_correction: [10]u32 = @splat(0);
pub export var clonewars_zillo_spread_seed_debug: [4]u32 = @splat(0);
pub export var clonewars_zillo_orientation_seed_debug: [4]u32 = @splat(0);
pub export var clonewars_zillo_throw_countdown_seed_debug: [4]u32 = @splat(0);
pub extern fn native_zillo_spread_seed() callconv(.c) void;
pub extern fn native_zillo_orientation_seed() callconv(.c) void;
pub extern fn native_zillo_throw_countdown_seed() callconv(.c) void;

fn identity(task: usize) ?[3]u32 {
    var read = Reader.init();
    var task_class: u32 = undefined;
    if (!s.readable(task, 0x24) or !read.imageClass(task, &task_class)) return null;
    const actor = s.load(usize, task + 0x20);
    if (!s.readable(actor, 0x1440) or s.load(u16, actor + 0xdc0) != 127) return null;
    const slot = s.entities_slot(actor);
    const generation = s.entities_generation(actor);
    if (!s.ready() or slot < 0 or slot >= p.SYNC_MAX_ACTORS or generation == 0) return null;
    return .{ @intCast(slot), generation, task_class };
}

fn replaySeed(comptime count: usize, sites: [count]u32, inputs: [count]u32, debug: *[4]u32, address: usize) ?u32 {
    if (s.host) {
        if (!s.capacity(count, sites[0])) return null;
    } else if (!s.match(&inputs, &sites, count - 1, true)) return null;
    var output: [count]u32 = undefined;
    s.run(&inputs, &sites, &output);
    if (!s.ready()) return null;
    debug[@intFromBool(!s.host)] +%= 1;
    if (s.host or inputs[count - 1] == output[count - 1]) return null;
    s.store(u32, address, output[count - 1]);
    debug[2] +%= 1;
    return output[count - 1];
}

pub fn apply(task: usize) void {
    if (!s.ready() or s.frame.?.level != 112) return;
    const sites = s.consecutive(4, s.site.ZILLO_THROW, 1);
    const actor = identity(task) orelse {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    };
    const seed = s.load(u32, 0xea178c);
    const canonical = replaySeed(4, sites, actor ++ .{seed}, &clonewars_zillo_throw_seed_debug, 0xea178c) orelse return;
    if (clonewars_zillo_throw_seed_correction[0] == 0) {
        clonewars_zillo_throw_seed_correction = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), actor[0], actor[1], actor[2], seed, canonical };
    }
}

pub export fn native_zillo_throw_countdown_seed_apply(task: usize) callconv(.c) void {
    const saved_error = win.GetLastError();
    defer win.SetLastError(saved_error);
    if (!s.ready() or s.frame.?.level != 112) return;
    const sites = s.consecutive(4, s.site.ZILLO_THROW_COUNTDOWN, 1);
    const actor = identity(task) orelse {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    };
    if (!s.readable(task, 0x340) or s.load(u32, task + 0x33c) != 1) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    _ = replaySeed(4, sites, actor ++ .{s.load(u32, 0xea178c)}, &clonewars_zillo_throw_countdown_seed_debug, 0xea178c);
}

fn throwObjectIdentity(task: usize, object: usize, initialized_slots: usize) ?[5]u32 {
    const actor = identity(task) orelse return null;
    if (!s.readable(task, 0x3ac) or !s.readable(object, 0x14c) or s.load(u32, object + 0x148) != 0) return null;
    const model = s.load(u32, object + 0xc);
    if (model != 6 and model != 31 and model != 33) return null;
    var slot: ?u32 = null;
    for (0..initialized_slots) |index| {
        if (s.load(usize, task + 0x3a0 + index * 4) != object) continue;
        if (slot != null) return null;
        slot = @intCast(index);
    }
    return actor ++ .{ slot orelse return null, model };
}

pub fn applyRelease(task: usize, object: usize) void {
    if (!s.ready() or s.frame.?.level != 112) return;
    const sites = s.consecutive(6, s.site.ZILLO_RELEASE, 1);
    const object_id = throwObjectIdentity(task, object, 3) orelse {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    };
    const seed = s.load(u32, 0xea178c);
    const canonical = replaySeed(6, sites, object_id ++ .{seed}, &clonewars_zillo_release_seed_debug, 0xea178c) orelse return;
    if (clonewars_zillo_release_seed_correction[0] == 0) {
        clonewars_zillo_release_seed_correction = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), object_id[0], object_id[1], object_id[2], object_id[3], object_id[4], seed, canonical };
    }
}

pub export fn native_zillo_spread_seed_apply(task: usize, slot: u32) callconv(.c) void {
    const saved_error = win.GetLastError();
    defer win.SetLastError(saved_error);
    if (!s.ready() or s.frame.?.level != 112) return;
    const sites = s.consecutive(6, s.site.ZILLO_SPREAD, 1);
    if (slot < 1 or slot > 2 or !s.readable(task, 0x3ac)) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    const object = s.load(usize, task + 0x3a0 + slot * 4);
    const object_id = throwObjectIdentity(task, object, 3) orelse {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    };
    if (object_id[3] != slot) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    _ = replaySeed(6, sites, object_id ++ .{s.load(u32, 0xea178c)}, &clonewars_zillo_spread_seed_debug, 0xea178c);
}

pub export fn native_zillo_orientation_seed_apply(task: usize, cursor: usize) callconv(.c) void {
    const saved_error = win.GetLastError();
    defer win.SetLastError(saved_error);
    if (!s.ready() or s.frame.?.level != 112) return;
    const sites = s.consecutive(6, s.site.ZILLO_ORIENTATION, 1);
    if (!s.readable(task, 0x3ac) or cursor < task + 0x3a0 or cursor > task + 0x3a8 or cursor & 3 != 0) {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    }
    // The factory fills the slots in order. Following slots can still refer to objects from the previous batch.
    const initialized_slots = (cursor - (task + 0x3a0)) / @sizeOf(usize) + 1;
    const object_id = throwObjectIdentity(task, s.load(usize, cursor), initialized_slots) orelse {
        s.fail(4, sites[0], s.clock(), s.firstExpected());
        return;
    };
    _ = replaySeed(6, sites, object_id ++ .{s.load(u32, 0xe637b4)}, &clonewars_zillo_orientation_seed_debug, 0xe637b4);
}

comptime {
    asm (
        \\.text
        \\.globl _native_zillo_spread_seed
        \\_native_zillo_spread_seed:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $8,%esp
        \\    pushl 116(%eax)
        \\    pushl 16(%eax)
        \\    call _native_zillo_spread_seed_apply
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    pushl $0x6d60d0
        \\    ret
        \\.globl _native_zillo_orientation_seed
        \\_native_zillo_orientation_seed:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $8,%esp
        \\    pushl 4(%eax)
        \\    pushl 0(%eax)
        \\    call _native_zillo_orientation_seed_apply
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    pushl $0x890600
        \\    ret
        \\.globl _native_zillo_throw_countdown_seed
        \\_native_zillo_throw_countdown_seed:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $12,%esp
        \\    pushl 4(%eax)
        \\    call _native_zillo_throw_countdown_seed_apply
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    pushl $0x6d60d0
        \\    ret
    );
}

pub fn prepareAndThrow(task: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    apply(task);
    machine.restore();
    const original: Throw = @ptrFromInt(0x4492b0);
    original(task);
}

pub fn prepareAndRelease(task: usize, _: usize, object: usize, target: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    applyRelease(task, object);
    machine.restore();
    const original: Release = @ptrFromInt(0x41cfa0);
    original(task, object, target);
}
