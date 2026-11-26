const std = @import("std");
const s = @import("sync_state.zig");
const api = s.api;
const authority = @import("sync_authority.zig");
const prep = @import("sync_prep.zig");
const actors = @import("sync_actors.zig");
const equal = @import("validation.zig").equal;
pub export var clonewars_dispatch_drain_failure: [12]u32 = @splat(0);
fn drainFailure(reason: u32, iteration: usize, projectile: c_int, tag: c_int, revisions: [4]u64) bool {
    if (s.live() and clonewars_dispatch_drain_failure[0] == 0) clonewars_dispatch_drain_failure = .{ reason, s.working.epoch, s.working.sequence, @intCast(iteration), @bitCast(projectile), @bitCast(tag), @truncate(revisions[0]), @truncate(revisions[1]), @truncate(revisions[2]), @truncate(revisions[3]), s.core.token.release, s.core.bound_mask };
    return false;
}
fn fault(code: c_int) void {
    if (s.fault == 0) s.fault = code;
}
pub fn drain() bool {
    for (0..s.p.SYNC_MAX_SHOTS + s.p.SYNC_MAX_TAGS + 1) |iteration| {
        if (!s.live() or api.coherent_frame_valid(&s.core.token, 4) == 0) return false;
        var projectile_before: u64 = 0;
        var tag_before: u64 = 0;
        var projectile_after: u64 = 0;
        var tag_after: u64 = 0;
        if (api.projectiles_dispatch_revision(&s.core.token, &projectile_before) == 0) return drainFailure(1, iteration, -99, -99, .{ projectile_before, tag_before, 0, 0 });
        if (api.tags_dispatch_revision(&s.core.token, &tag_before) == 0) return drainFailure(2, iteration, -99, -99, .{ projectile_before, tag_before, 0, 0 });
        var projectile_pending = api.projectiles_dispatch_pending();
        var tag_pending = api.tags_dispatch_pending();
        if (projectile_pending < 0 or tag_pending < 0) return drainFailure(3, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, 0, 0 });
        if (projectile_pending == 0 and tag_pending == 0) return true;
        if (projectile_pending != 0 and api.projectiles_dispatch_complete() == 0) return drainFailure(4, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, 0, 0 });
        if (!s.live()) return false;
        tag_pending = api.tags_dispatch_pending();
        if (tag_pending < 0) return drainFailure(5, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, 0, 0 });
        if (tag_pending != 0 and api.tags_dispatch_complete() != 1) return drainFailure(6, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, 0, 0 });
        if (!s.live()) return false;
        projectile_pending = api.projectiles_dispatch_pending();
        tag_pending = api.tags_dispatch_pending();
        if (projectile_pending < 0 or tag_pending < 0) return drainFailure(7, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, 0, 0 });
        if (projectile_pending == 0 and tag_pending == 0) return true;
        if (api.projectiles_dispatch_revision(&s.core.token, &projectile_after) == 0 or api.tags_dispatch_revision(&s.core.token, &tag_after) == 0) return drainFailure(8, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, projectile_after, tag_after });
        if (projectile_before == projectile_after and tag_before == tag_after) return drainFailure(9, iteration, projectile_pending, tag_pending, .{ projectile_before, tag_before, projectile_after, tag_after });
    }
    return false;
}
fn finishInputs() bool {
    if (s.prep_gate_depth != 0) {
        prep.fail(4, s.prep_gates[s.prep_gate_depth - 1].actor, 0);
        s.prep_gate_depth = 0;
    }
    inline for (.{ .{ api.reaction_finish, 17 }, .{ api.geometry_finish, 15 }, .{ api.model_input_finish, 20 }, .{ api.cadence_finish, 14 } }) |entry| {
        const result = entry[0]();
        if (!s.live()) return false;
        if (result == 0) fault(entry[1]);
        if (!s.live()) return false;
    }
    const npc = api.npc_input_finish(&s.npc_inputs);
    if (!s.live()) return false;
    if (npc == 0) {
        s.clonewars_npc_input_debug[13] +%= 1;
        fault(13);
    }
    s.clonewars_npc_input_debug[12] +%= 1;
    return true;
}
pub fn finish(owner: *s.owner.Scope, nonce: u32, _: usize) callconv(.c) void {
    if (owner != s.core.owner or nonce != s.core.owner_nonce or !s.live()) return;
    @import("sync_trace.zig").point(.finish, s.working.epoch, s.working.sequence, s.global_step.worlds, s.global_step.ticks, s.core.bound_mask);
    s.running = false;
    if (api.native_tick_finish() == 0) {
        if (s.live()) fault(22);
        return;
    }
    if (!drain()) {
        authority.reject(29, 0);
        return;
    }
    if (api.rts_spawn_timers_finish(&s.working) == 0) {
        fault(21);
        return;
    }
    if (s.core.host == 0) {
        if ((s.working.level == 12 or s.working.level == 74) and api.reaction_drain_contact_hits() == 0) {
            fault(17);
            return;
        }
        if (!s.live()) return;
        const actors_ok = actors.correct(&s.working);
        if (!s.live()) return;
        if (!actors_ok) {
            fault(5);
            return;
        }
        s.clonewars_coherent_debug[16] |= 0x80000000;
        if (api.projectiles_dispatch_pending() != 0 or api.tags_dispatch_pending() != 0) {
            authority.reject(29, 0);
            return;
        }
    }
    if (api.coherent_frame_set_phase(&s.core.token, 3) == 0 or !s.live()) return;
    const actual_calls: @TypeOf(s.working.native_span_calls) = @as(u32, @intFromBool(s.core.main_calls != 0)) | @as(u32, @intFromBool(s.core.optional_calls != 0)) * 2;
    if (s.core.main_calls > 1 or s.core.optional_calls > 1) {
        s.fault = 11;
        return;
    }
    if (s.core.host != 0) s.working.native_span_calls = actual_calls else if (actual_calls != s.core.expected_calls) {
        s.fault = 11;
        return;
    }
    if (!finishInputs()) return;
    if (s.core.host != 0) {
        s.working.world_calls = s.global_step.worlds;
        s.working.tick_calls = s.global_step.ticks;
    } else if ((s.global_step.worlds != s.working.world_calls or s.global_step.ticks != s.working.tick_calls) and s.fault == 0) s.fault = 10;
    if (!s.live()) return;
    const tags = api.tags_finish();
    if (tags == -1 or !s.live() or api.model_input_cancelled() != 0) return;
    if (s.core.host != 0) {
        if (tags != 1) fault(9);
        if (api.model_input_cancelled() != 0) return;
    }
    if (!s.live()) return;
    const projectile_serial = api.projectiles_lifecycle_serial();
    const projectiles = api.projectiles_finish();
    if (api.projectiles_lifecycle_serial() != projectile_serial or !s.live() or api.model_input_cancelled() != 0) return;
    if (projectiles == 0) fault(8);
    if (s.core.host != 0) {
        if (!s.live()) return;
        s.working.rng_game_after = s.load(u32, 0xe637b4);
        s.working.rng_engine_after = s.load(u32, 0xea178c);
        if (!s.live()) return;
        if (api.coherent_frame_set_phase(&s.core.token, 4) == 0 or !s.live()) return;
        if (!actors.collect(&s.working) and s.live()) fault(3);
        if (!s.live()) return;
        api.remote_input_trace_finish(@bitCast(s.fault), s.player(1));
        if (api.coherent_frame_set_phase(&s.core.token, 5) == 0 or !s.live()) return;
        if (s.fault == 0 and s.live() and api.model_input_cancelled() == 0) {
            const sent = api.lan_send_frame(&s.working);
            if (!s.live()) return;
            if (sent == 0) s.fault = 3 else {
                s.last_published_sequence = s.working.sequence;
                s.core.published = 1;
                s.publish_count +%= 1;
                @import("sync_trace.zig").point(.publish, s.working.epoch, s.working.sequence, s.core.host, s.working.actor_count, s.core.main_calls);
                api.combat_observer_frame_queued(s.working.epoch, s.working.sequence);
            }
        }
    } else {
        if (tags != 1) fault(9);
        if (!s.live()) return;
        api.remote_input_trace_finish(@bitCast(s.fault), s.player(1));
        if (api.coherent_frame_set_phase(&s.core.token, 5) == 0 or !s.live()) return;
        if (s.fault == 0 and s.live() and api.model_input_cancelled() == 0) {
            s.store(u32, 0xe637b4, s.working.rng_game_after);
            s.store(u32, 0xea178c, s.working.rng_engine_after);
        }
        if (s.fault == 0 and s.live() and api.model_input_cancelled() == 0) {
            api.lan_publish_ack(s.expected);
            if (s.live()) {
                s.core.published = 1;
                s.publish_count +%= 1;
                @import("sync_trace.zig").point(.publish, s.working.epoch, s.working.sequence, s.core.host, s.working.actor_count, s.core.main_calls);
            }
        }
    }
    if (!s.live()) return;
    api.camera_select(if (s.core.host != 0) 0 else 1);
}
pub fn end(owner: *s.owner.Scope, nonce: u32, why: c_int, aborted: u32, _: usize) callconv(.c) void {
    if (owner != s.core.owner or nonce != s.core.owner_nonce) return;
    @import("sync_trace.zig").point(.end, s.interval.epoch, s.working.sequence, s.core.published, @bitCast(why), aborted);
    const published = s.core.published != 0;
    defer @import("sync_profiling.zig").end(published);
    s.main_boundary_active = false;
    s.running = false;
    if (s.core.preload != 0) {
        const root = s.load(usize, 0xfb2e60);
        if (aborted != 0 or why == 1 or s.core.release != api.coherent_frame_release() or s.core.session != api.lan_session_serial() or s.core.preload_epoch != s.interval.epoch or s.core.preload_world != s.load(usize, 0xfb4a20) or !s.valid(root, 0x1b7c) or api.game_network_world_valid(s.preload.level, s.core.preload_world) == 0) {
            s.clonewars_preload_debug[7] +%= 1;
            authority.reject(31, 0);
        } else {
            var receipt = s.core.preload_flow;
            receipt.serial = s.preload.input.serial;
            receipt.world_calls = s.core.preload_world_calls;
            receipt.end_phase = s.load(u32, root + 0x1b78);
            if (api.preload_state_finish(&s.preload, &receipt) == 0 or api.lan_publish_preload_receipt(s.interval.epoch, s.interval.level, &receipt) == 0) {
                s.clonewars_preload_debug[7] +%= 1;
                authority.reject(31, 0);
            } else {
                s.clonewars_preload_debug[if (api.lan_is_host() != 0) @as(usize, 0) else 1] +%= 1;
                s.clonewars_preload_debug[9..12].* = .{ receipt.serial, receipt.world_calls, receipt.end_phase };
                s.clonewars_preload_seed_debug[3..6].* = .{ s.load(u32, 0xe637b4), s.load(u32, 0xea178c), s.load(u32, 0xe5f498) };
            }
        }
    }
    if (s.core.opened != 0) {
        while (s.prep_gate_depth != 0) {
            const gate = &s.prep_gates[s.prep_gate_depth - 1];
            if (!equal(&gate.cohort, &s.core.token)) break;
            s.prep_gate_depth -= 1;
        }
        if (s.core.published == 0 and s.core.session == api.lan_session_serial() and s.core.token.epoch == s.interval.epoch) {
            _ = @atomicRmw(u32, &s.reject_bits, .Or, 0x40000000, .seq_cst);
            @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
            api.coherent_frame_cancel_atomic(0x40000000);
        }
        if (aborted != 0 or why == 1 or s.core.token.release != api.coherent_frame_release() or s.releaseChanged(s.core.release) or @atomicLoad(u32, &s.reject_bits, .seq_cst) != 0) {
            api.coherent_frame_cancel_atomic(1);
            @atomicStore(u32, &s.deferred_assignment_restore, 1, .seq_cst);
        }
        api.native_tick_cancel(&s.core.token);
        for (s.bindings, 0..) |binding, i| if (s.core.bound_mask & (@as(u32, 1) << @as(u5, @intCast(i))) != 0) binding.abort_metadata.?(&s.core.token);
        _ = api.coherent_frame_close(&s.core.token);
    }
    if (s.core.depth_accounted != 0 and s.outer_depth != 0) s.outer_depth -= 1;
    s.core = std.mem.zeroes(s.Core);
}
