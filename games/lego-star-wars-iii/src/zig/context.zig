const p = @import("protocol.zig");
const v = @import("validation.zig");
const model = @import("model.zig");
pub export fn model_context_canonicalize(authoritative: ?*const p.SyncModelInput, raw: ?*const p.SyncModelInputContext, output: ?*p.SyncModelInputContext, fields: ?*u32) c_int {
    if (authoritative == null or raw == null or output == null or fields == null or !v.finite(authoritative.?.input_x) or !v.finite(authoritative.?.input_z) or raw.?.actor_4c_mask > 1) return 0;
    var result = raw.?.*;
    var mask: u32 = 0;
    if (result.actor_4c_mask == 1) {
        inline for (.{ "c7c_1000", "cf4_raw", "model_42", "actor_309_mask", "global_e63e14_raw", "global_fbcb88_raw" }) |name| @field(result, name) = 0;
        mask = 0x0fc00000;
    }
    output.?.* = result;
    fields.?.* = mask;
    return 1;
}
pub export fn model_context_relevant_equal(authoritative: ?*const p.SyncModelInput, host: ?*const p.SyncModelInputContext, local: ?*const p.SyncModelInputContext) c_int {
    if (authoritative == null or host == null or local == null or host.?.actor_4c_mask != local.?.actor_4c_mask) return 0;
    var h = authoritative.?.*;
    var l = h;
    var hm: u32 = undefined;
    var lm: u32 = undefined;
    if (model_context_canonicalize(authoritative, host, &h.context, &hm) == 0 or model_context_canonicalize(authoritative, local, &l.context, &lm) == 0) return 0;
    return @intFromBool(hm == lm and model.valid(&h) and model.valid(&l) and v.equal(&h.context, &l.context));
}
