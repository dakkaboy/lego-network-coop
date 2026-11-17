const std = @import("std");
const s = @import("tick_state.zig");
const load = s.load;
const store = s.store;
const v = s.site;
const identity = @import("tick_pack_identity.zig");
pub export fn native_pack_cell_admission(member: usize, flags: u32) u32 {
    const local = flags & 0x60;
    if (!s.ready()) return local;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const id = identity.resolve(member, false) orelse return local;
    const values = [_]u32{ id.key(), local };
    const sites = [_]u32{ v.PACK_CELL_MEMBER, v.PACK_CELL_FLAGS };
    if (s.host) {
        if (!s.capacity(2, sites[0])) return local;
    } else if (!s.match(&values, &sites, 1, false) or !s.valid.gateValid(s.expected(2).?[1])) {
        if (!s.failed) s.fail(2, sites[0], s.clock(), s.firstExpected());
        return local;
    }
    _ = s.decision(sites[0], values[0]);
    const result = s.decision(sites[1], local);
    if (!s.host and result != local and !s.failed and s.clonewars_native_pack_cell_correction[0] == 0) s.clonewars_native_pack_cell_correction = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), id.index, local, result, id.witness, 0 };
    return result;
}
pub export fn native_pack_attack(member: usize, local: u32) u32 {
    if (!s.ready()) return local;
    const at = v.PACK_ATTACK;
    const expected = s.firstExpected();
    const has_attack = !s.host and expected != null and expected.?.site == at;
    if (local != 2 and !has_attack) return local;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const id = identity.resolve(member, true) orelse {
        s.fail(4, at, s.clock(), expected);
        return local;
    };
    if (s.host) {
        if (s.capacity(2, at)) {
            _ = s.decision(at, id.index);
            _ = s.decision(v.PACK_ATTACK_WITNESS, id.witness);
        }
    } else if (has_attack and expected.?.value == id.index) {
        const e = s.expected(2);
        if (e == null or e.?[0].clock != s.clock() or e.?[1].site != v.PACK_ATTACK_WITNESS or e.?[1].clock != s.clock() or e.?[1].value != id.witness) s.fail(2, at, s.clock(), expected) else {
            _ = s.decision(at, id.index);
            _ = s.decision(v.PACK_ATTACK_WITNESS, id.witness);
            return 2;
        }
    } else if (local == 2) return 1;
    return local;
}
fn seed(member: usize, at: u32, seed_site: u32, with_target: bool, require_identity: bool, correction: ?*[8]u32) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const id = identity.resolve(member, with_target) orelse {
        if (require_identity) s.fail(4, at, s.clock(), s.firstExpected());
        return;
    };
    const local = load(u32, 0xea178c);
    const values = [_]u32{ id.key(), local };
    const sites = [_]u32{ at, seed_site };
    if (at == v.PACK_HIT_DEBRIS) {
        const expected = s.firstExpected();
        const pack = load(usize, member + 0x68);
        s.clonewars_native_pack_seed_context = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), at, @truncate(member), id.index, id.witness, values[0], local, if (expected) |e| e.value else 0, if (expected) |e| e.site else 0, if (expected) |e| e.clock else 0, load(u32, member + 0x6c), load(u32, member + 0x70), load(u32, pack + 0xac), @import("tick_pack_mutation.zig").clonewars_pack_membership_revision };
    }
    if (s.host) {
        if (!s.capacity(2, at)) return;
    } else if (!s.match(&values, &sites, 1, false)) return;
    _ = s.decision(at, values[0]);
    const source = s.decision(seed_site, local);
    if (at == v.PACK_HIT_AVOIDANCE and s.ready()) {
        s.clonewars_native_pack_avoidance_debug[@intFromBool(!s.host)] +%= 1;
        if (local != source) s.clonewars_native_pack_avoidance_debug[2] +%= 1;
    }
    if ((at == v.PACK_MODE10_DURATION or at == v.PACK_MODE10_CLIP_PHASE) and s.ready()) {
        s.clonewars_native_pack_mode10_rng_debug[@intFromBool(!s.host)] +%= 1;
        if (local != source) s.clonewars_native_pack_mode10_rng_debug[2] +%= 1;
    }
    if (!s.host and s.ready()) {
        if (correction) |out| if (out[0] == 0 and local != source) {
            out.* = .{ s.frame.?.epoch, s.frame.?.sequence, at, s.clock(), id.index, local, source, id.witness };
        };
        store(u32, 0xea178c, source);
    }
}
pub export fn native_pack_attack_seed(member: usize) void {
    seed(member, v.PACK_TIMER_MEMBER, v.PACK_TIMER_SEED, true, true, null);
}
pub export fn native_pack_hit_seed(member: usize, at: u32) void {
    const sites = [_]u32{ v.PACK_HIT_REACTION, v.PACK_HIT_AVOIDANCE, v.PACK_HIT_DEBRIS, v.PACK_HIT_SHOCK, v.PACK_HIT_HEADING, v.PACK_IMPULSE_TIMER, v.PACK_IMPULSE_SPEED, v.PACK_IMPULSE_HEADING, v.PACK_DEATH_CLIP, v.PACK_MODE10_DURATION, v.PACK_MODE10_CLIP_PHASE };
    for (sites) |known| if (known == at) {
        seed(member, at, at + 5, false, false, &s.clonewars_native_pack_hit_correction);
        return;
    };
}
pub export fn native_pack_hit_seed_bridge(member: usize, at: u32, native_stack: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (s.ready() and at == v.PACK_HIT_DEBRIS and s.readable(native_stack, 36) and load(u32, native_stack) == at + 5) {
        s.clonewars_native_pack_hit_caller = .{ s.frame.?.epoch, s.frame.?.sequence, s.clock(), @truncate(member), load(u32, native_stack), load(u32, native_stack + 28), load(u32, native_stack + 32), @truncate(native_stack) };
        @import("pack_hit_query_observer.zig").observe(member, native_stack);
    }
    native_pack_hit_seed(member, at);
}
pub export fn native_pack_rearm_seed(member: usize) void {
    seed(member, v.PACK_REARM_MEMBER, v.PACK_REARM_SEED, true, true, null);
}
pub export fn native_pack_move_timer_seed(member: usize) void {
    seed(member, v.PACK_MOVE_TIMER, v.PACK_MOVE_TIMER_SEED, false, true, null);
}
pub export fn native_pack_move_heading_seed(member: usize) void {
    seed(member, v.PACK_MOVE_HEADING, v.PACK_MOVE_HEADING_SEED, false, true, null);
}
pub export fn native_pack_move_choice_seed(member: usize) void {
    seed(member, v.PACK_MOVE_CHOICE, v.PACK_MOVE_CHOICE_SEED, false, true, null);
}
pub export fn native_pack_formation(member: usize, leave: u32) u32 {
    if (!s.ready()) return leave;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const id = identity.resolve(member, false) orelse return leave;
    const values = [_]u32{ id.key(), leave };
    const sites = [_]u32{ v.PACK_FORMATION_MEMBER, v.PACK_FORMATION_LEAVE };
    if (s.host) {
        if (!s.capacity(2, sites[0])) return leave;
    } else if (!s.match(&values, &sites, 1, false) or !s.valid.gateValid(s.expected(2).?[1])) {
        if (!s.failed) s.fail(2, sites[0], s.clock(), s.firstExpected());
        return leave;
    }
    _ = s.decision(sites[0], values[0]);
    return s.decision(sites[1], leave);
}
pub export fn native_pack_mode(member: usize, entry: usize) void {
    if (!s.ready()) return;
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    const pack = load(usize, member + 0x68);
    if (!s.readable(pack, 4) or load(usize, pack) != 0xadcef0) return;
    const at = v.PACK_MODE_MEMBER;
    const expected = s.firstExpected();
    const local = @as(u32, load(u8, member + 0x60)) | @as(u32, load(u8, entry) & 1) << 8 | @as(u32, load(u8, member + 0x63) & 0x10) << 5;
    const id = identity.resolve(member, false) orelse return;
    const three = s.expected(3);
    const mode = if (s.host) local else if (three) |e| e[2].value else local;
    const dying = mode & 255 == 9;
    const death_sites = [_]u32{ v.PACK_DEATH_VERTICAL, v.PACK_DEATH_SPEED, v.PACK_DEATH_FLAGS };
    var death_local: [3]u32 = @splat(0);
    var death_source: [3]u32 = @splat(0);
    if (dying) {
        if (!s.readable(member, 0x92)) {
            s.fail(4, at, s.clock(), expected);
            return;
        }
        death_local = .{ load(u32, member + 0x88), load(u32, member + 0x8c), @as(u32, load(u8, member + 0x90)) | @as(u32, load(u8, member + 0x91)) << 8 };
        for (death_local, death_sites, &death_source) |value, death_site, *out| {
            if (!s.valid.gateValid(.{ .site = death_site, .clock = s.clock(), .value = value })) {
                s.fail(4, death_site, s.clock(), expected);
                return;
            }
            out.* = value;
        }
        if (!s.host) {
            const e = s.expected(6) orelse {
                s.fail(2, at, s.clock(), expected);
                return;
            };
            for (e[3..6], death_sites, &death_source) |gate, death_site, *out| {
                if (gate.site != death_site or gate.clock != s.clock() or !s.valid.gateValid(gate)) {
                    s.fail(2, death_site, s.clock(), expected);
                    return;
                }
                out.* = gate.value;
            }
        }
    }
    if (s.host) {
        if (!s.capacity(if (dying) 6 else if (mode & 255 == 18) 3 + s.site.PACK_FIRE_FIELDS else 3, at)) return;
    } else if (three == null or three.?[0].site != at or three.?[0].clock != s.clock() or three.?[0].value != id.index or three.?[1].site != v.PACK_MODE_WITNESS or three.?[1].clock != s.clock() or three.?[1].value != id.witness or three.?[2].site != v.PACK_MODE_VALUE or three.?[2].clock != s.clock() or !s.valid.gateValid(three.?[2])) {
        if (s.clonewars_native_tick_failure[0] == 0) s.clonewars_native_tick_failure[8..16].* = .{ id.index, id.witness, if (expected) |e| e.value else 0xffffffff, if (s.expected(2)) |e| e[1].value else 0, load(u32, member + 0x6c), load(u32, member + 0x70), load(u32, pack + 0xf8), load(u32, pack + 0xfc) };
        s.fail(2, at, s.clock(), expected);
        return;
    }
    _ = s.decision(at, id.index);
    _ = s.decision(v.PACK_MODE_WITNESS, id.witness);
    const source = s.decision(v.PACK_MODE_VALUE, local);
    if (mode & 255 == 18 and !@import("tick_pack_fire_target.zig").apply(member)) return;
    if (!s.host and !s.failed and source != local) {
        store(u8, member + 0x60, @truncate(source));
        store(u8, entry, @truncate(source >> 8 & 1));
        store(u8, member + 0x63, load(u8, member + 0x63) & 0xef | @as(u8, @truncate(source >> 5 & 0x10)));
    }
    if (dying and !s.failed) {
        var ignored: [3]u32 = undefined;
        s.run(&death_local, &death_sites, &ignored);
        if (s.ready()) {
            s.clonewars_native_pack_death_input_debug[@intFromBool(!s.host)] +%= 1;
            if (!s.host) {
                if (!std.mem.eql(u32, &death_local, &death_source)) s.clonewars_native_pack_death_input_debug[2] +%= 1;
                store([2]u32, member + 0x88, death_source[0..2].*);
                store(u8, member + 0x90, @truncate(death_source[2]));
                store(u8, member + 0x91, @truncate(death_source[2] >> 8));
            }
        }
    }
}
pub export fn native_pack_mode_checked(member: usize, entry: usize) u32 {
    native_pack_mode(member, entry);
    return @intFromBool(!s.active or !s.failed);
}
