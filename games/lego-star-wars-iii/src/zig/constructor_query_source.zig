const std = @import("std");
const s = @import("constructor_query_state.zig");
const t = s.t;
fn links(binding: *const s.Binding, record: *const t.Record, out: *t.SourceLinks, mask: *u32, ordinal: *u32) u32 {
    const descriptor = record.selected_descriptor_local;
    inline for (.{ .{ 0, "descriptor_vtable" }, .{ 0x18, "descriptor_type_word18" }, .{ 0x1c, "descriptor_name1c_raw" }, .{ 0x28, "descriptor_receiver28_raw" }, .{ 0x30, "descriptor_wrapper30_raw" } }) |field| {
        if (!s.word(binding, descriptor + field[0], &@field(out, field[1]))) return t.CQS_UNREADABLE_DESCRIPTOR;
    }
    if (out.descriptor_vtable != record.selected_descriptor_raw[0] or out.descriptor_type_word18 != record.selected_descriptor_raw[6] or out.descriptor_name1c_raw != record.selected_descriptor_raw[7] or out.descriptor_receiver28_raw != record.selected_descriptor_raw[10] or out.descriptor_wrapper30_raw != record.selected_descriptor_raw[12]) return t.CQS_CHANGED;
    if (out.descriptor_vtable != 0xc69eac or out.descriptor_type_word18 & 255 != 1) return t.CQS_UNSUPPORTED_BODY;
    mask.* |= 2;
    const receiver = out.descriptor_receiver28_raw;
    if (receiver == 0) return t.CQS_NO_RECEIVER;
    mask.* |= 4;
    if (!s.span(binding, receiver, 0x1a8)) return t.CQS_UNREADABLE_RECEIVER;
    mask.* |= 8;
    if (!s.word(binding, receiver, &out.receiver_vtable)) return t.CQS_UNREADABLE_RECEIVER;
    if (out.receiver_vtable != 0xc20b1c and out.receiver_vtable != 0xc20f64) return t.CQS_UNSUPPORTED_RECEIVER;
    mask.* |= 16;
    if (!s.word(binding, receiver + 0x1a0, &out.receiver_descriptor1a0_raw) or !s.word(binding, receiver + 0x1a4, &out.receiver_name1a4_raw)) return t.CQS_UNREADABLE_RECEIVER;
    if (out.receiver_descriptor1a0_raw != descriptor or out.receiver_name1a4_raw != out.descriptor_name1c_raw) return t.CQS_REVERSE_PAIR_MISMATCH;
    mask.* |= 32;
    if (!s.word(binding, receiver + 0x2c, &out.receiver_resource2c_raw) or !s.word(binding, receiver + 0x30, &out.receiver_poi30_raw)) return t.CQS_UNREADABLE_RECEIVER;
    if (out.receiver_resource2c_raw == 0 or out.receiver_poi30_raw == 0) return t.CQS_NO_HANDLE;
    mask.* |= 64;
    const resource = out.receiver_resource2c_raw;
    if (!s.span(binding, resource, 0x6fc) or !s.word(binding, resource + 0x6f8, &out.resource_runtime6f8_raw)) return t.CQS_UNREADABLE_RESOURCE;
    mask.* |= 128;
    const runtime = out.resource_runtime6f8_raw;
    if (runtime == 0) return t.CQS_NO_RUNTIME;
    if (!s.span(binding, runtime, 0x70) or !s.word(binding, runtime + 0x68, &out.runtime_count68_raw) or !s.word(binding, runtime + 0x6c, &out.runtime_array6c_raw)) return t.CQS_UNREADABLE_RUNTIME;
    mask.* |= 256;
    const count = out.runtime_count68_raw;
    if (@as(i32, @bitCast(count)) < 0) return t.CQS_INVALID_COUNT;
    if (count == 0) return t.CQS_EMPTY_TABLE;
    if (count > 65536) return t.CQS_COUNT_CAP;
    if (out.runtime_array6c_raw == 0) return t.CQS_NO_ARRAY;
    const end = @as(u64, out.runtime_array6c_raw) + @as(u64, count) * 0xe0;
    if (end > 0xffffffff) return t.CQS_TABLE_OVERFLOW;
    mask.* |= 512;
    const poi = out.receiver_poi30_raw;
    if (poi < out.runtime_array6c_raw or @as(u64, poi) + 0xe0 > end) return t.CQS_RECORD_OUT_OF_RANGE;
    const offset = poi - out.runtime_array6c_raw;
    if (offset % 0xe0 != 0) return t.CQS_RECORD_MISALIGNED;
    if (!s.span(binding, poi, 0xe0)) return t.CQS_UNREADABLE_RECORD;
    mask.* |= 1024;
    ordinal.* = offset / 0xe0;
    if (!s.word(binding, poi + 0xd4, &out.record_bindingd4_raw) or !s.word(binding, poi + 0xb4, &out.record_nameb4_raw)) return t.CQS_UNREADABLE_RECORD;
    if (out.record_bindingd4_raw != receiver) return t.CQS_D4_NOT_SELF_BOUND;
    mask.* |= 2048;
    return t.CQS_NONE;
}
fn name(binding: *const s.Binding, out: *t.Source) void {
    const pointer = out.first.record_nameb4_raw;
    if (pointer == 0) {
        out.name_flags = t.CQS_NAME_NULL;
        return;
    }
    for (0..out.name_raw.len) |i| {
        if (pointer > std.math.maxInt(usize) - i or !s.span(binding, pointer + i, 1)) {
            out.name_flags |= t.CQS_NAME_UNREADABLE;
            return;
        }
        const value = s.win.load(u8, pointer + i);
        out.name_flags |= t.CQS_NAME_PREFIX;
        if (value == 0) {
            out.name_flags |= t.CQS_NAME_NUL;
            return;
        }
        out.name_raw[i] = value;
        out.name_size = @intCast(i + 1);
    }
    out.name_flags |= t.CQS_NAME_TRUNCATED;
}
fn optional(binding: *const s.Binding, out: *t.Source) void {
    if (out.valid_mask & 16 == 0) return;
    const receiver = out.first.descriptor_receiver28_raw;
    if (s.word(binding, receiver + 0x14, &out.receiver14_local_raw)) out.valid_mask |= 1 << 14;
    if (s.span(binding, receiver + 0x198, 1)) {
        out.receiver198_byte_raw = s.win.load(u8, receiver + 0x198);
        out.valid_mask |= 1 << 15;
    }
    if (out.valid_mask & (1 << 14) != 0 and out.receiver14_local_raw != 0 and s.word(binding, out.receiver14_local_raw, &out.component_vtable_local_raw)) out.valid_mask |= 1 << 16;
}
pub fn capture(binding: *const s.Binding, record: *t.Record) void {
    const out = &record.source_witness;
    out.* = std.mem.zeroes(t.Source);
    out.count_cap = 65536;
    out.poi_ordinal = 0xffffffff;
    out.sample_release_serial = binding.lease.serial;
    out.clock_before = s.clock();
    if (record.native_eax & 255 == 0 or record.valid_mask & t.CQ_DESCRIPTOR == 0) {
        out.reason = t.CQS_NOT_ACCEPTED;
        out.clock_after = s.clock();
        return;
    }
    out.valid_mask = 1;
    const first_reason = links(binding, record, &out.first, &out.valid_mask, &out.poi_ordinal);
    optional(binding, out);
    if (first_reason != t.CQS_NONE and first_reason != t.CQS_D4_NOT_SELF_BOUND) {
        out.reason = first_reason;
        out.clock_after = s.clock();
        return;
    }
    name(binding, out);
    var second_mask: u32 = 1;
    var second_ordinal: u32 = 0xffffffff;
    const second_reason = links(binding, record, &out.second, &second_mask, &second_ordinal);
    out.clock_after = s.clock();
    if (first_reason != second_reason or out.poi_ordinal != second_ordinal or !s.equal(&out.first, &out.second)) {
        out.reason = t.CQS_CHANGED;
        if (out.first.record_nameb4_raw != out.second.record_nameb4_raw) out.name_flags |= t.CQS_NAME_CHANGED;
        return;
    }
    out.valid_mask |= 4096;
    if (!s.bindingLive(binding)) {
        out.reason = t.CQS_CANCELLED;
        return;
    }
    if (out.clock_before != out.clock_after or record.clock_before != out.clock_before) {
        out.reason = t.CQS_CLOCK_CHANGED;
        return;
    }
    out.valid_mask |= 8192;
    out.association_kind = 1;
    out.reason = first_reason;
    if (first_reason == 0 and out.valid_mask & 0x3fff == 0x3fff) out.status = 1;
}
