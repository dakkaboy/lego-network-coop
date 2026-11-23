const s = @import("tick_state.zig");
const load = s.load;
const store = s.store;
const v = s.site;
const win = s.win;
pub var gungan_vehicle_handoff: ?*const fn (u32) bool = null;
pub export fn native_weapon_commands(actor: usize) void {
    if (!s.ready()) return;
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const time = s.clock();
    const at = v.WEAPON_COMMAND_ACTOR;
    if (!s.host and s.frame.?.level == 24 and s.cursor != 0 and s.frame.?.tick_gates[s.cursor - 1].clock == time -% 1) {
        if (gungan_vehicle_handoff) |handoff| {
            if (!handoff(time) or !s.ready()) {
                s.fail(4, at, time, s.firstExpected());
                return;
            }
        }
    }
    var slot = s.entities_slot(actor);
    var generation = s.entities_generation(actor);
    if (!s.host and (slot < 0 or generation == 0) and s.entities_bind_native_actor(s.frame.?, actor) != 0) {
        slot = s.entities_slot(actor);
        generation = s.entities_generation(actor);
    }
    if (slot < 0 or generation == 0) return;
    if (@as(u32, @intCast(slot)) >= s.p.SYNC_MAX_ACTORS or !s.readable(actor, 0x1440)) {
        s.fail(4, at, time, null);
        return;
    }
    const local = @as(u32, load(u8, actor + 0x8ea)) | @as(u32, load(u8, actor + 0x8fa)) << 8 | @as(u32, load(u8, actor + 0x8fb)) << 16 | @as(u32, load(u8, actor + 0x8fc)) << 24;
    const sites = [_]u32{ at, v.WEAPON_COMMAND_GENERATION, v.WEAPON_COMMAND_VALUE };
    const values = [_]u32{ @intCast(slot), generation, local };
    if (s.host) {
        if (!s.capacity(3, at)) return;
    } else if (!s.match(&values, &sites, 2, false)) {
        const expected = s.firstExpected();
        const two = s.expected(2);
        s.clonewars_native_tick_failure[8..16].* = .{ @intCast(slot), generation, if (expected) |e| e.value else 0xffffffff, if (two) |e| e[1].value else 0, actor, local, load(u32, actor + 0x4c), load(u32, actor + 0x50) };
        return;
    }
    var result: [3]u32 = undefined;
    s.run(&values, &sites, &result);
    if (!s.host and s.ready()) {
        if (result[2] != local and s.clonewars_native_weapon_command_correction[0] == 0) s.clonewars_native_weapon_command_correction = .{ s.frame.?.epoch, s.frame.?.sequence, time, @intCast(slot), generation, local, result[2], s.cursor - 3 };
        store(u8, actor + 0x8ea, @truncate(result[2]));
        store(u8, actor + 0x8fa, @truncate(result[2] >> 8));
        store(u8, actor + 0x8fb, @truncate(result[2] >> 16));
        store(u8, actor + 0x8fc, @truncate(result[2] >> 24));
    }
}
pub export fn native_fire_visibility(actor: usize, local: u32) u32 {
    if (!s.ready()) return local;
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const slot = s.entities_slot(actor);
    const generation = s.entities_generation(actor);
    const at = v.FIRE_VISIBILITY;
    if (slot < 0 or @as(u32, @intCast(slot)) >= s.p.SYNC_MAX_ACTORS or generation == 0) {
        s.fail(4, at, s.clock(), null);
        return local;
    }
    if (s.host) {
        if (!s.capacity(2, at)) return local;
    } else {
        const e = s.expected(2);
        if (e == null or e.?[0].site != at or e.?[0].clock != s.clock() or e.?[0].value >> 8 != @as(u32, @intCast(slot)) or e.?[1].site != v.FIRE_VISIBILITY_ACTOR or e.?[1].clock != s.clock() or e.?[1].value != generation) {
            s.fail(2, at, s.clock(), s.firstExpected());
            return local;
        }
    }
    const result = s.decision(at, @as(u32, @intCast(slot)) << 8 | (local & 255));
    _ = s.decision(v.FIRE_VISIBILITY_ACTOR, generation);
    return (local & 0xffffff00) | (result & 255);
}
fn heading(turret: usize, local: u32, at: u32) u32 {
    if (!s.ready()) return local;
    const pilot = load(usize, turret + 0x2fc);
    if (pilot == 0) return local;
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (s.entities_slot(pilot) < 0) _ = s.entities_bind_native_actor(s.frame.?, pilot);
    const slot = s.entities_slot(pilot);
    const generation = s.entities_generation(pilot);
    if (slot < 0 or @as(u32, @intCast(slot)) >= s.p.SYNC_MAX_ACTORS or generation == 0) {
        s.fail(4, at, s.clock(), null);
        return local;
    }
    if (s.host) {
        if (!s.capacity(2, at)) return local;
    } else {
        const e = s.expected(2);
        if (e == null or e.?[0].site != at or e.?[0].clock != s.clock() or e.?[0].value >> 16 != @as(u32, @intCast(slot)) or e.?[1].site != v.RTS_TURRET_PILOT or e.?[1].clock != s.clock() or e.?[1].value != generation) {
            s.fail(2, at, s.clock(), s.firstExpected());
            return local;
        }
    }
    const angle = s.decision(at, @as(u32, @intCast(slot)) << 16 | (local & 65535));
    _ = s.decision(v.RTS_TURRET_PILOT, generation);
    const result = (local & 0xffff0000) | (angle & 65535);
    if (!s.failed) {
        s.clonewars_native_rts_heading_debug[@intFromBool(!s.host)] +%= 1;
        if ((result & 65535) != (local & 65535)) s.clonewars_native_rts_heading_debug[2] +%= 1;
    }
    return result;
}
pub export fn native_rts_turret_heading(turret: usize, local: u32) u32 {
    return heading(turret, local, v.RTS_TURRET_HEADING);
}
pub export fn native_rts_turret_aim(turret: usize) void {
    store(u16, turret + 0x87e, @truncate(heading(turret, load(u16, turret + 0x87e), v.RTS_TURRET_AIM)));
}
pub export fn native_rts_turn_input(turret: usize, local: u32, look: usize) u32 {
    if (!s.ready()) return local;
    const physical = load(usize, turret + 0x2fc);
    if (physical == 0) return local;
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const at = v.RTS_TURN_INPUT;
    if (s.entities_slot(physical) < 0) _ = s.entities_bind_native_actor(s.frame.?, physical);
    const slot = s.entities_slot(physical);
    const generation = s.entities_generation(physical);
    if (slot < 0 or @as(u32, @intCast(slot)) >= s.p.SYNC_MAX_ACTORS or generation == 0 or !s.readable(look, 4)) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    }
    if (s.host and !s.capacity(4, at)) return local;
    var source = [_]u32{ @intCast(slot), generation, local, load(u32, look) };
    const sites = s.consecutive(4, at, 1);
    if (!s.host) {
        if (!s.match(&source, &sites, 2, true)) return local;
        for (&source, s.expected(4).?) |*value, gate| value.* = gate.value;
    }
    for (source[2..4]) |value| {
        const angle: i32 = @bitCast(value);
        if (angle < -32768 or angle > 32768) {
            s.fail(4, at, s.clock(), s.firstExpected());
            return local;
        }
    }
    const before = load(u32, look);
    var ignored: [4]u32 = undefined;
    s.run(&source, &sites, &ignored);
    if (!s.host and s.ready() and s.early_rts_wait == s.cursor) {
        s.early_rts_wait = null;
        _ = s.decision(v.RTS_WAIT_SAMPLE, 0);
        if (s.ready()) s.clonewars_native_rts_wait_reorders +%= 1;
    }
    if (!s.ready()) return local;
    s.clonewars_native_rts_turn_debug[@intFromBool(!s.host)] +%= 1;
    if (source[2] != local) s.clonewars_native_rts_turn_debug[2] +%= 1;
    if (source[3] != before) s.clonewars_native_rts_turn_debug[3] +%= 1;
    if (!s.host) {
        store(u32, look, source[3]);
        return source[2];
    }
    return local;
}
pub export fn native_actor_turn_input(task: usize, local: u32, desired: usize) u32 {
    if (!s.ready()) return local;
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    const at = v.ACTOR_TURN_INPUT;
    const okay = s.readable(task, 0x10);
    const actor = if (okay) load(usize, task + 0xc) else 0;
    const kind = if (okay) load(usize, task) else 0;
    if (actor != 0 and s.entities_slot(actor) < 0) _ = s.entities_bind_native_actor(s.frame.?, actor);
    const slot = if (actor != 0) s.entities_slot(actor) else -1;
    const generation = if (actor != 0) s.entities_generation(actor) else 0;
    if (slot < 0 or @as(u32, @intCast(slot)) >= s.p.SYNC_MAX_ACTORS or generation == 0 or kind <= 0x400000 or kind >= 0xd00000 or !s.readable(desired, 2)) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    }
    if (s.host and !s.capacity(5, at)) return local;
    var source = [_]u32{ @intCast(slot), generation, kind - 0x400000, local & 65535, load(u16, desired) };
    const sites = s.consecutive(5, at, 1);
    if (!s.host) {
        if (!s.match(&source, &sites, 3, true)) return local;
        for (&source, s.expected(5).?) |*value, gate| value.* = gate.value;
    }
    const before = load(u16, desired);
    var ignored: [5]u32 = undefined;
    s.run(&source, &sites, &ignored);
    if (!s.ready()) return local;
    s.clonewars_native_actor_turn_debug[@intFromBool(!s.host)] +%= 1;
    if (source[3] != local & 65535) s.clonewars_native_actor_turn_debug[2] +%= 1;
    if (source[4] != before) s.clonewars_native_actor_turn_debug[3] +%= 1;
    if (!s.host) {
        store(u16, desired, @truncate(source[4]));
        return local & 0xffff0000 | source[3];
    }
    return local;
}
