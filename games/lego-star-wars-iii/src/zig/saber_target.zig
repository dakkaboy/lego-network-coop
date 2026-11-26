const std = @import("std");
const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

const Row = [40]u8;
const row_count = 10;

pub extern fn saber_target_queue_thunk() void;
export const saber_target_queue_active: usize = 0x8cd57d;
export const saber_target_queue_idle: usize = 0x8cdb3b;
pub export var clonewars_saber_target_debug: [4]u32 = @splat(0);

fn field(row: *const Row, offset: usize) u32 {
    return std.mem.readInt(u32, row[offset..][0..4], .little);
}

fn snapshot(weapon: usize, rows: *[row_count]Row, queue: *p.SyncSaberQueue, lease: *const s.Lease) bool {
    queue.* = std.mem.zeroes(p.SyncSaberQueue);
    queue.clock = s.read(u32, 0xfb4b6c);
    queue.mode = s.read(u8, weapon + 0x25d);
    if (queue.mode == 0) return true;
    queue.count = s.read(u8, weapon + 0x25c);
    queue.cursor = s.read(u8, weapon + 0x25e);
    if (queue.count > row_count or queue.cursor > row_count) return false;
    for (rows[0..queue.count], 0..) |*row, i| {
        row.* = s.read(Row, weapon + 4 + i * @sizeOf(Row));
        if (i < queue.cursor or row[16] != 0) {
            queue.slots[i] = p.SABER_QUEUE_INACTIVE;
            continue;
        }

        const kind: u16 = row[36] & 0xf;
        const fixed: u16 = if (row[19] == 0) 0 else p.SABER_QUEUE_FIXED_POINT;
        if (kind != 2) {
            queue.slots[i] = p.SABER_QUEUE_SCENE | kind | fixed;
            continue;
        }
        var slot: u32 = undefined;
        var generation: u32 = undefined;
        const actor = field(row, 32);
        if (!s.valid(actor, 0x1440) or s.entities_observed_identity(actor, &slot, &generation) == 0 or slot >= p.SYNC_MAX_ACTORS) {
            // A guest may have a local row for an actor it cannot bind. The
            // authoritative queue can discard it or replace it by identity.
            if (s.journal.host != 0) return false;
            queue.slots[i] = p.SABER_QUEUE_SCENE | kind | fixed;
        } else {
            queue.slots[i] = @as(u16, @intCast(slot)) | fixed;
            queue.generations[i] = generation;
        }
        if (!s.live(lease)) return false;
    }
    return s.live(lease);
}

fn restore(weapon: usize, rows: *const [row_count]Row, local: *const p.SyncSaberQueue, expected: *const p.SyncSaberQueue, lease: *const s.Lease) bool {
    var output: [row_count]Row = @splat(@splat(0));
    var used: std.StaticBitSet(row_count) = .empty;
    for (output[0..expected.count], 0..) |*row, i| {
        const descriptor = expected.slots[i];
        const generation = expected.generations[i];
        if (descriptor == p.SABER_QUEUE_INACTIVE) {
            row[16] = 1;
            continue;
        }

        for (rows[0..local.count], 0..) |*candidate, source| {
            if (used.isSet(source) or local.slots[source] != descriptor or local.generations[source] != generation) continue;
            row.* = candidate.*;
            used.set(source);
            break;
        } else {
            if (descriptor & (p.SABER_QUEUE_SCENE | p.SABER_QUEUE_FIXED_POINT) != 0) return false;
            const actor = s.entities_actor(descriptor, generation);
            if (!s.live(lease) or !s.valid(actor, 0x1440)) return false;
            std.mem.writeInt(u32, row[32..36], @intCast(actor), .little);
            row[36] = 2;
        }
    }
    if (!s.live(lease)) return false;
    for (output[0..expected.count], 0..) |row, i| {
        s.win.store(Row, weapon + 4 + i * @sizeOf(Row), row);
    }
    s.win.store(u8, weapon + 0x25c, expected.count);
    s.win.store(u8, weapon + 0x25e, expected.cursor);
    return true;
}

export fn saber_target_queue(weapon: usize) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (!s.valid(weapon, 0x264)) return 0;
    const active: c_int = @intFromBool(s.read(u8, weapon + 0x25d) != 0);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease)) return active;
    const level = s.journal.frame.?.level;
    if (level != 70 and level != 73) return active;
    const attacker = s.read(usize, weapon + 0x238);
    const character: u16 = if (level == 70) 191 else 184;
    if (!s.valid(attacker, 0x1440) or s.read(u16, attacker + 0xdc0) != character) return active;

    var rows: [row_count]Row = undefined;
    var expected: p.SyncSaberQueue = undefined;
    if (!snapshot(weapon, &rows, &expected, &lease)) {
        reject(attacker, &lease);
        return active;
    }
    const local = expected;
    _ = @import("cadence_gate.zig").apply(attacker, p.SYNC_ACTOR_SABER_TARGET, 0, 0, 0, @ptrCast(&expected), &clonewars_saber_target_debug);
    if (!s.live(&lease) or s.journal.host != 0 or s.journal.failed != 0 or std.meta.eql(local, expected)) return active;
    if (expected.mode == 0) {
        clonewars_saber_target_debug[2] +%= 1;
        return 0;
    }
    if (!restore(weapon, &rows, &local, &expected, &lease)) {
        reject(attacker, &lease);
        return active;
    }
    clonewars_saber_target_debug[2] +%= 1;
    return active;
}

fn reject(attacker: usize, lease: *const s.Lease) void {
    if (!s.live(lease)) return;
    s.journal.failed = 28;
    clonewars_saber_target_debug[3] +%= 1;
    s.failed(lease, attacker, null, 28);
}

comptime {
    asm (
        \\.text
        \\.globl _saber_target_queue_thunk
        \\_saber_target_queue_thunk:
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
        \\    subl $12,%esp
        \\    pushl 16(%edx)
        \\    call _saber_target_queue
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
        \\    jmp *_saber_target_queue_active
        \\1: popal
        \\    popfl
        \\    jmp *_saber_target_queue_idle
    );
}
