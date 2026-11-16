const p = @import("protocol.zig");
const abi = @import("abi.zig");
const v = @import("validation.zig");
pub const Journal = @import("journal.zig").Journal("model_inputs", "model_input_count");

fn finiteBits(bits: u32) bool {
    return v.finite(@as(f32, @bitCast(bits)));
}
pub fn valid(entry: ?*const p.SyncModelInput) bool {
    const e = entry orelse return false;
    if (e.slot >= p.SYNC_MAX_ACTORS or e.generation == 0 or !abi.validLevel(e.character) or
        e.period == 0 or e.period > 255 or e.phase > 255 or !v.finite(e.*) or e.elapsed < 0) return false;
    const c = &e.context;
    if (c.actor_4c_mask == 1 and (c.c7c_1000 != 0 or c.cf4_raw != 0 or c.model_42 != 0 or c.actor_309_mask != 0 or c.global_e63e14_raw != 0 or c.global_fbcb88_raw != 0)) return false;
    if (c.role_mask & ~@as(u32, 0xa00) != 0 or c.role_mask & 0x200 != 0 or c.life_54 != 0 or c.axis_1dd != 255 or
        c.provider_190_bit != 0 or c.action > 65535 or c.substate_2fa > 255 or c.c7c_block != 0 or c.byte_110a > 255 or
        c.byte_110a == 1 or c.c84_mask & ~@as(u32, 0x104000) != 0 or c.c84_mask & 0x4000 != 0 or
        (c.action == 0x16 and c.c84_mask & 0x100000 == 0) or c.c00_present > 1 or c.actor_76 > 65535 or
        c.actor_1c8_mask > 1 or c.motion_alternate > 1 or c.resource_d8_bit > 1) return false;
    if (c.c00_present != 0 or c.global_fc0e80 != 0 or c.actor_4c_mask > 1 or c.c7c_1000 > 1 or c.model_42 > 255 or
        c.actor_309_mask > 1 or c.numeric_cw & ~@as(u32, 0x1f3f) != 0 or c.numeric_mxcsr & ~@as(u32, 0xffc0) != 0) return false;
    if (!finiteBits(c.cf4_raw) or !finiteBits(c.global_e63e14_raw) or !finiteBits(c.global_fbcb88_raw) or !finiteBits(c.override_c44) or !finiteBits(c.override_c48)) return false;
    for (c.resource_speed) |bits| if (!finiteBits(bits)) return false;
    return true;
}
pub export fn model_input_entry_valid(entry: ?*const p.SyncModelInput) c_int {
    return @intFromBool(valid(entry));
}
pub export fn model_input_journal_begin(j: *Journal, frame: *p.SyncFrame, host: c_int) void {
    j.begin(frame, host);
    if (host != 0) frame.model_input_reserved = 0;
}
pub export fn model_input_journal_record(j: *Journal, entry: ?*const p.SyncModelInput) c_int {
    return j.record(entry, valid, 4);
}
pub export fn model_input_journal_peek(j: *const Journal) ?*const p.SyncModelInput {
    return j.peek();
}
pub export fn model_input_journal_finish(j: *const Journal) c_int {
    return j.finish();
}
pub export fn model_input_journal_validate(j: *Journal, entry: ?*const p.SyncModelInput, owner_matches: c_int, local: ?*const p.SyncModelInput) c_int {
    if (j.failed != 0) return 0;
    if (entry == null or entry != j.peek()) return j.fail(3);
    if (owner_matches == 0) return j.fail(1);
    if (!valid(entry) or !valid(local)) return j.fail(4);
    const a = entry.?;
    const b = local.?;
    if (a.native_clock != b.native_clock or a.period != b.period or a.phase != b.phase or !v.equal(&a.elapsed, &b.elapsed)) return j.fail(6);
    if (!v.equal(&a.context, &b.context)) return j.fail(9);
    j.cursor += 1;
    return 1;
}
