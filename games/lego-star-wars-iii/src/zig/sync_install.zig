const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const mapping = @import("sync_mapping.zig");
const hooks = @import("hook_transaction.zig");
extern fn sync_actor_ai_normal_hook() void;
fn pause(menu: usize, player: c_int, sound: u32) callconv(.{ .x86_thiscall = .{} }) void {
    if (api.lan_status() != 3) {
        const native: *const fn (usize, c_int, u32) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x8a4780);
        native(menu, player, sound);
    }
}
fn updateMissionMap(map: usize) callconv(.{ .x86_thiscall = .{} }) void {
    // A network level change can retire the map before its last scheduled update.
    if (s.win.load(usize, 0xe906bc) == 0) return;
    const native: *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void = @ptrFromInt(0x4e1430);
    native(map);
}
fn base() bool {
    if (s.base_install_state != 0) return s.base_install_state > 0;
    s.base_install_state = -1;
    const sites = [_]usize{ 0x889fa0, 0x8889ba, 0x58f4c6, 0x58f5e7, 0x5e2a15, 0x634a95, 0x755347, 0x9c53fd, 0x9c33bf, 0x9c53f7, 0x7adc6e, 0x84a06d, 0x4e1a99 };
    const originals = [_]usize{ 0x889640, 0x887ac0, 0x57b340, 0x57b340, 0x57b340, 0x57b340, 0x57b340, 0x9ab020, 0x9ab020, 0x8b0f90, 0x8a4780, 0x7b8630, 0x4e1430 };
    const refresh = @intFromPtr(&@import("sync_input.zig").refresh);
    const prep = @import("sync_prep.zig");
    const dispatch = @import("sync_dispatch.zig");
    const targets = [_]usize{ @intFromPtr(&dispatch.tick), @intFromPtr(&dispatch.world), refresh, refresh, refresh, refresh, refresh, @intFromPtr(&prep.normal), @intFromPtr(&prep.prepareAlternate), @intFromPtr(&sync_actor_ai_normal_hook), @intFromPtr(&pause), @intFromPtr(&api.game_native_scene_entry), @intFromPtr(&updateMissionMap) };
    var expected: [sites.len][5]u8 = undefined;
    var patches: [sites.len]hooks.Patch = undefined;
    for (sites, originals, targets, &expected, &patches) |at, original, target, *bytes, *patch| {
        bytes[0] = 0xe8;
        std.mem.writeInt(u32, bytes[1..5], @truncate(original -% at -% 5), .little);
        patch.* = .{ .address = at, .expected = bytes, .target = target, .opcode = 0xe8 };
    }
    if (!hooks.apply(&patches) or api.native_tick_install() == 0 or api.object_progress_install() == 0) return false;
    @atomicStore(i32, &s.clonewars_input_prep_installed, 7, .seq_cst);
    @import("arena_hint.zig").install();
    s.base_install_state = 1;
    return true;
}
pub fn safe(_: usize, _: *const s.owner.Input, _: usize) callconv(.c) c_int {
    if (s.win.GetCurrentThreadId() != s.window_thread or s.core.owner != null or api.native_owner_current() == null) return 0;
    if (!mapping.install() or api.camera_install_qualified_main() == 0 or !base()) {
        authority.reject(24, 0);
        return 0;
    }
    if (s.tick_thread == 0) return 1;
    if (s.tick_thread != s.window_thread) return 0;
    if (s.dependency_install_state == 0) {
        s.dependency_install_state = -1;
        if (api.tags_configure_coherent(&s.adapter, authority.tagSession) == 0 or api.projectiles_configure_coherent(&s.adapter, authority.projectileSession, authority.projectileReject, 0) == 0) return 0;
        if (api.entities_install() == 0) return 0;
        s.module_install_mask |= (1 << 5) | (1 << 7);
        if (api.tags_install() == 0) return 0;
        @import("tick_actor.zig").gungan_vehicle_handoff = @import("tag_frame.zig").replayGunganVehicleHandoff;
        s.module_install_mask |= 1;
        if (api.projectiles_install() == 0) return 0;
        s.module_install_mask |= 2;
        if (api.spawn_observer_install() == 0 or api.combat_observer_install() == 0 or api.collision_observer_install() == 0 or api.geometry_ready() == 0) return 0;
        s.module_install_mask |= 4;
        if (api.cadence_install() == 0) return 0;
        s.module_install_mask |= 8;
        if (api.reaction_install() == 0) return 0;
        @import("reaction_receipt.zig").lab_saber_damage = @import("projectile_actor_branch.zig").labSaberDamage;
        s.module_install_mask |= 64;
        if (api.rts_spawn_timers_install() == 0) return 0;
        if (api.model_input_install() == 0) return 0;
        s.module_install_mask |= 16;
        if (api.game_sync_coherent_register_actual_modules() == 0) return 0;
        s.dependency_install_state = 1;
        s.hooked = true;
        s.permission_install_owner = api.native_owner_current();
        s.permission_install_nonce = api.native_owner_scope_nonce(s.permission_install_owner);
    }
    return @intFromBool(s.dependency_install_state > 0);
}
pub fn ready(_: usize) callconv(.c) c_int {
    const blockers = authority.game_sync_coherent_blockers();
    const debug = &s.clonewars_coherent_debug;
    debug[0..14].* = .{ blockers, @bitCast(s.adapter.installer.state), @intFromBool(s.adapter.installer.ready != 0 and s.adapter.sticky == 0 and blockers == 0 and s.win.GetCurrentThreadId() == s.window_thread and s.tick_thread == s.window_thread), @bitCast(s.base_install_state), @bitCast(s.dependency_install_state), s.tick_thread, s.window_thread, api.coherent_frame_release(), @atomicLoad(u32, &s.reject_bits, .seq_cst), s.run_count, s.publish_count, s.registered, api.lan_session_serial(), @bitCast(s.fault) };
    debug[17] = if (api.user_mapping_install_ready() != 0) 127 else 0;
    debug[18] = @bitCast(api.user_mapping_session_pending());
    debug[19] = s.module_install_mask;
    return @intFromBool(blockers == 0);
}
