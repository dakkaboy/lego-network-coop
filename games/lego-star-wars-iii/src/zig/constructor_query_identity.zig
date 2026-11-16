const std = @import("std");
const s = @import("constructor_query_state.zig");
const t = s.t;
fn chain(binding: *const s.Binding, value: *t.Collider) u32 {
    var word: u32 = 0;
    const descriptor = value.descriptor_local;
    if (!s.word(binding, descriptor, &word)) return t.CCI_UNREADABLE;
    if (word != 0xc69eac or !s.word(binding, descriptor + 0x18, &word) or word & 255 != 1) return t.CCI_UNSUPPORTED_BODY;
    value.valid_mask |= 2;
    if (!s.word(binding, descriptor + 0x30, &value.wrapper_local)) return t.CCI_UNREADABLE;
    if (value.wrapper_local == 0) return t.CCI_NO_WRAPPER;
    if (!s.word(binding, value.wrapper_local, &value.wrapper_vtable_local)) return t.CCI_UNREADABLE;
    if (value.wrapper_vtable_local != 0xc1ed6c) return t.CCI_UNSUPPORTED_WRAPPER;
    if (!s.word(binding, s.address(value.wrapper_vtable_local + 0x2c), &value.wrapper_class_method_local)) return t.CCI_UNREADABLE;
    if (value.wrapper_class_method_local != 0xa32dc0) return t.CCI_UNSUPPORTED_WRAPPER;
    value.valid_mask |= 4;
    if (!s.word(binding, value.wrapper_local + 0x10, &value.nuanim_local) or value.nuanim_local == 0) return t.CCI_UNREADABLE;
    value.valid_mask |= 8;
    if (!s.word(binding, value.nuanim_local + 0x122c, &value.api_local) or value.api_local == 0) return t.CCI_UNREADABLE;
    value.valid_mask |= 16;
    if (!s.word(binding, value.api_local + 0x30, &value.userdata_local) or value.userdata_local == 0) return t.CCI_UNREADABLE;
    if (!s.word(binding, value.userdata_local, &word)) return t.CCI_UNREADABLE;
    if (word & 255 != 0) return t.CCI_BAD_USERDATA;
    if (!s.word(binding, value.userdata_local + 4, &value.actor_local) or value.actor_local == 0) return t.CCI_UNREADABLE;
    value.valid_mask |= 32;
    if (!s.bindingLive(binding)) return t.CCI_CANCELLED;
    value.actor_local_generation = s.api.entities_observed_generation(value.actor_local);
    if (value.actor_local_generation == 0) return t.CCI_UNOBSERVED_ACTOR;
    if (!s.bindingLive(binding) or s.api.entities_allocation_live(value.actor_local, value.actor_local_generation) == 0) return t.CCI_ALLOCATION_NOT_LIVE;
    if (!s.word(binding, value.actor_local + 8, &value.actor_model_local)) return t.CCI_UNREADABLE;
    if (value.actor_model_local != value.api_local) return t.CCI_API_MISMATCH;
    if (!s.span(binding, value.actor_local + 0xdc0, 2)) return t.CCI_UNREADABLE;
    value.actor_character = s.win.load(u16, value.actor_local + 0xdc0);
    if (s.api.entities_observed_identity(value.actor_local, &value.actor_network_slot, &value.actor_network_generation) == 0 or value.actor_network_generation == 0 or value.actor_network_slot >= @import("protocol.zig").SYNC_MAX_ACTORS) return t.CCI_UNMAPPED;
    return if (s.bindingLive(binding)) t.CCI_NONE else t.CCI_CANCELLED;
}
pub fn capture(binding: *const s.Binding, record: *t.Record) void {
    const value = &record.collider_identity;
    value.* = std.mem.zeroes(t.Collider);
    value.actor_network_slot = 0xffffffff;
    value.clock_before = s.clock();
    value.sample_release_serial = binding.lease.serial;
    if (record.native_eax & 255 == 0 or record.valid_mask & t.CQ_DESCRIPTOR == 0) {
        value.reason = t.CCI_NOT_ACCEPTED;
        return;
    }
    value.valid_mask = 1;
    value.descriptor_local = record.selected_descriptor_local;
    value.reason = chain(binding, value);
    if (value.reason != 0) return;
    if (record.selected_descriptor_raw[0] != 0xc69eac or record.selected_descriptor_raw[6] & 255 != 1 or record.selected_descriptor_raw[12] != value.wrapper_local) {
        value.reason = t.CCI_CHANGED;
        return;
    }
    value.allocation_live_before = 1;
    value.valid_mask |= 64;
    var again = std.mem.zeroes(t.Collider);
    again.descriptor_local = value.descriptor_local;
    again.valid_mask = 1;
    const reason = chain(binding, &again);
    value.clock_after = s.clock();
    if (reason != 0) {
        value.reason = reason;
        return;
    }
    const first = std.mem.asBytes(value);
    const second = std.mem.asBytes(&again);
    const start = @offsetOf(t.Collider, "descriptor_local");
    if (!std.mem.eql(u8, first[start..][0 .. 13 * 4], second[start..][0 .. 13 * 4]) or value.clock_before != value.clock_after or record.clock_before != value.clock_before) {
        value.reason = t.CCI_CHANGED;
        return;
    }
    if (!s.bindingLive(binding) or s.api.entities_allocation_live(value.actor_local, value.actor_local_generation) == 0 or s.api.entities_observed_generation(value.actor_local) != value.actor_local_generation) {
        value.reason = t.CCI_ALLOCATION_NOT_LIVE;
        return;
    }
    value.allocation_live_after = 1;
    value.association_kind = 1;
    value.valid_mask = 0x1ff;
    value.status = 1;
}
