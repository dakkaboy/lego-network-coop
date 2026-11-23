const std = @import("std");
const p = @import("protocol.zig");
const s = @import("physics_state.zig");
const win = @import("win32.zig");
const validate = @import("physics_validation.zig").valid;
const pool = 0xfb3358;
const pool_cursor = 0xfb30b0;
pub const register_site = 0x825cb0;
const update_site = 0x8860ce;
const count = 8;
const Raw = [16]u32;
const Mark = struct { position: [3]u32, seed: u16 };
var marks: [count]?Mark = @splat(null);
var epoch: u32 = 0;
var release: u32 = 0;
var sequence: u32 = 0;
var update: u32 = 0;
pub export var clonewars_blue_shadow_blast_debug: [4]u32 = @splat(0);

extern fn blue_shadow_blast_register_thunk() void;
extern fn blue_shadow_blast_update_thunk() void;
extern fn entities_actor(u32, u32) usize;
export const blue_shadow_blast_native: usize = register_site + register_prefix.len;
export const blue_shadow_blast_continue: usize = 0x8860dc;
pub const register_prefix = "\x55\x8b\xec\x83\xe4\xf0";
pub const update_prefix = "\x8b\x5c\x24\x10\xbe\x78\x33\xfb\x00\xbf\x08\x00\x00\x00";
pub fn install() bool {
    return @import("hook_transaction.zig").apply(&.{
        .{ .address = register_site, .expected = register_prefix, .target = @intFromPtr(&blue_shadow_blast_register_thunk) },
        .{ .address = update_site, .expected = update_prefix, .target = @intFromPtr(&blue_shadow_blast_update_thunk) },
    });
}
fn ready() bool {
    if (!s.live() or s.failed or s.frame.?.level != 73) return false;
    const key = &s.lease.cohort;
    if (epoch != key.epoch or release != key.release) {
        marks = @splat(null);
        sequence = 0;
        epoch = key.epoch;
        release = key.release;
    }
    if (sequence != key.sequence) {
        sequence = key.sequence;
        update = 0;
    }
    return true;
}
fn address(slot: usize) usize {
    return pool + slot * @sizeOf(Raw);
}
fn mark(words: *const Raw) Mark {
    return .{ .position = words[4..7].*, .seed = @truncate(words[12]) };
}
fn active(words: *const Raw) bool {
    return @as(f32, @bitCast(words[8])) < @as(f32, @bitCast(words[9]));
}
fn matches(slot: usize, words: *const Raw) bool {
    const known = marks[slot] orelse return false;
    const candidate = mark(words);
    return words[10] == 0x4025 and known.seed == candidate.seed and std.mem.eql(u32, &known.position, &candidate.position);
}
fn guestMask(words: *const Raw) [2]u32 {
    const source: u64 = @bitCast(words[0..2].*);
    var mask: [2]u32 = @splat(0);
    if (source == 0) return mask;
    const frame = s.frame.?;
    // Native blast bits identify the actor's local pool slot.
    for (frame.actors[0..frame.actor_count]) |*actor| {
        if (actor.slot >= 64 or source & (@as(u64, 1) << @as(u6, @intCast(actor.slot))) == 0) continue;
        const local = entities_actor(actor.slot, actor.generation);
        if (local == 0 or !win.accessible(local + 0x1090, 8, false)) continue;
        const bits = win.load([2]u32, local + 0x1090);
        mask[0] |= bits[0];
        mask[1] |= bits[1];
    }
    return mask;
}
export fn blue_shadow_blast_register(stack: usize, source: usize) void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const slot = win.load(u32, pool_cursor);
    if (slot >= count) {
        if (ready()) _ = s.fail(30, null, null);
        return;
    }
    marks[slot] = null;
    if (!ready()) return;
    if (!win.accessible(stack, 36, false) or win.load(u32, stack) != 0x86507b or !win.accessible(source, 0x40, false)) return;
    const args = win.load([9]u32, stack);
    if (args[2] != 0x3ecccccc or args[3] != 0x3f000000 or args[4] != 0 or args[5] != 0xce99e0 or
        args[6] != 0x4025 or args[8] != 0 or win.load(u32, source) != 0xad953c or !win.accessible(args[1], 12, false)) return;
    const name = win.load([11]u8, source + 0x30);
    if (!std.mem.startsWith(u8, &name, "iVindi_Can_")) return;
    const seed = win.load(u32, 0xe637b4) *% 0x24cd +% 1;
    marks[slot] = .{ .position = win.load([3]u32, args[1]), .seed = @truncate(seed) };
    clonewars_blue_shadow_blast_debug[0] +%= 1;
}
export fn blue_shadow_blast_update() void {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (!ready()) return;
    update += 1;
    const clock = win.load(u32, 0xfb4b6c);
    for (0..count) |slot| {
        const words = win.load(Raw, address(slot));
        if (!active(&words) or !matches(slot, &words)) marks[slot] = null;
    }
    if (s.host) {
        for (0..count) |slot| {
            const words = win.load(Raw, address(slot));
            if (!active(&words) or !matches(slot, &words)) continue;
            var choice = std.mem.zeroes(p.SyncPhysicsChoice);
            choice.kind = p.SYNC_PHYSICS_BLUE_SHADOW_BLAST;
            choice.site = update_site;
            choice.payload.blast = .{ .clock = clock, .update = update, .slot = @intCast(slot), .words = words };
            if (!validate(&choice) or !s.record(choice)) {
                _ = s.fail(30, &choice, null);
                return;
            }
            clonewars_blue_shadow_blast_debug[1] +%= 1;
        }
        return;
    }
    var received: std.StaticBitSet(count) = .empty;
    while (s.expectedEntry()) |entry| {
        if (entry.kind != p.SYNC_PHYSICS_BLUE_SHADOW_BLAST) break;
        const blast = &entry.payload.blast;
        if (blast.update > update) break;
        if (!validate(entry) or blast.clock != clock or blast.update != update or received.isSet(blast.slot)) {
            _ = s.fail(30, null, entry);
            return;
        }
        const local = win.load(Raw, address(blast.slot));
        if (active(&local) and !matches(blast.slot, &local)) {
            _ = s.fail(30, null, entry);
            return;
        }
        var words = blast.words;
        words[0..2].* = guestMask(&blast.words);
        if (!s.live()) return;
        win.store(Raw, address(blast.slot), words);
        marks[blast.slot] = mark(&blast.words);
        received.set(blast.slot);
        s.consume(1);
        clonewars_blue_shadow_blast_debug[2] +%= 1;
    }
    for (0..count) |slot| {
        if (received.isSet(slot)) continue;
        const words = win.load(Raw, address(slot));
        if (!active(&words) or !matches(slot, &words)) continue;
        win.store(u32, address(slot) + 0x20, words[9]);
        marks[slot] = null;
        clonewars_blue_shadow_blast_debug[3] +%= 1;
    }
}

const preserve =
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
    \\
;
const restore =
    \\    fxrstor (%esp)
    \\    movl 512(%esp),%esp
    \\    popal
    \\    popfl
    \\
;
comptime {
    asm (
        \\.text
        \\.globl _blue_shadow_blast_register_thunk
        \\_blue_shadow_blast_register_thunk:
        \\
        ++ preserve ++
        \\    subl $8,%esp
        \\    pushl 4(%edx)
        \\    leal 36(%edx),%eax
        \\    pushl %eax
        \\    call _blue_shadow_blast_register
        \\    addl $16,%esp
        \\
        ++ restore ++
        \\    pushl %ebp
        \\    movl %esp,%ebp
        \\    andl $-16,%esp
        \\    jmp *_blue_shadow_blast_native
        \\.globl _blue_shadow_blast_update_thunk
        \\_blue_shadow_blast_update_thunk:
        \\
        ++ preserve ++
        \\    call _blue_shadow_blast_update
        \\
        ++ restore ++
        \\    movl 16(%esp),%ebx
        \\    movl $0xfb3378,%esi
        \\    movl $8,%edi
        \\    jmp *_blue_shadow_blast_continue
    );
}
