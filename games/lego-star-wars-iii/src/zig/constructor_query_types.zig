const constructor = @import("constructor_types.zig");
const projectile = @import("projectile_types.zig");
const Token = @import("cohort_types.zig").Token;
pub const SourceLinks = extern struct {
    descriptor_vtable: u32,
    descriptor_type_word18: u32,
    descriptor_name1c_raw: u32,
    descriptor_receiver28_raw: u32,
    descriptor_wrapper30_raw: u32,
    receiver_vtable: u32,
    receiver_descriptor1a0_raw: u32,
    receiver_name1a4_raw: u32,
    receiver_resource2c_raw: u32,
    receiver_poi30_raw: u32,
    resource_runtime6f8_raw: u32,
    runtime_count68_raw: u32,
    runtime_array6c_raw: u32,
    record_bindingd4_raw: u32,
    record_nameb4_raw: u32,
};
pub const Source = extern struct {
    status: u32,
    valid_mask: u32,
    reason: u32,
    count_cap: u32,
    poi_ordinal: u32,
    clock_before: u32,
    clock_after: u32,
    sample_release_serial: u32,
    association_kind: u32,
    name_size: u32,
    name_flags: u32,
    receiver14_local_raw: u32,
    receiver198_byte_raw: u32,
    component_vtable_local_raw: u32,
    first: SourceLinks,
    second: SourceLinks,
    name_raw: [64]u8,
};
pub const Collider = extern struct {
    status: u32,
    valid_mask: u32,
    reason: u32,
    descriptor_local: u32,
    wrapper_local: u32,
    wrapper_vtable_local: u32,
    wrapper_class_method_local: u32,
    nuanim_local: u32,
    api_local: u32,
    userdata_local: u32,
    actor_local: u32,
    actor_local_generation: u32,
    actor_network_slot: u32,
    actor_network_generation: u32,
    actor_character: u32,
    actor_model_local: u32,
    allocation_live_before: u32,
    allocation_live_after: u32,
    clock_before: u32,
    clock_after: u32,
    association_kind: u32,
    sample_release_serial: u32,
    reserved0: u32,
    reserved1: u32,
};
pub const Record = extern struct {
    committed: u32,
    id: u32,
    version: u32,
    thread: u32,
    qpc_before: [2]u32,
    qpc_after: [2]u32,
    clock_before: u32,
    clock_after: u32,
    constructor_scope: u32,
    constructor_parent_scope: u32,
    query_ordinal: u32,
    query_caller: u32,
    valid_mask: u32,
    lease_serial: u32,
    lease_nonce: u32,
    frame_local: u32,
    epoch: u32,
    sequence: u32,
    frame_valid: u32,
    constructor_kind: u32,
    constructor_caller: u32,
    birth_known: u32,
    shot_id: u32,
    shot_phase: u32,
    owner_slot: u32,
    owner_generation: u32,
    owner_local_generation: u32,
    owner_character: u32,
    owner_local: u32,
    input_flags: u32,
    input_weapon: u32,
    native_ebp: u32,
    native_esp: u32,
    native_esi: u32,
    native_eax: u32,
    parent_ebp: u32,
    parent_caller: u32,
    native_arguments: [8]u32,
    query_s30_raw: [13]u32,
    start_raw: [3]u32,
    displacement_raw: [3]u32,
    result_vtable: u32,
    fraction_raw: u32,
    candidate_context_local: u32,
    selected_descriptor_local: u32,
    reported_shape_raw: u32,
    category_raw: u32,
    subtype_raw: u32,
    mask_word_raw: u32,
    point_raw: [4]u32,
    normal_raw: [4]u32,
    selected_descriptor_raw: [32]u32,
    root_shape_local: u32,
    root_shape_vtable: u32,
    root_ray_target_local: u32,
    root_radius_target_local: u32,
    root_shape_header_raw: [16]u32,
    native_control_word: u32,
    native_mxcsr: u32,
    caller_esi_raw: u32,
    collider_identity: Collider,
    source_witness: Source,
};
pub const Scope = extern struct {
    previous: ?*Scope,
    ready: u32,
    linked: u32,
    thread: u32,
    id: u32,
    parent: u32,
    ordinal: u32,
    owner_valid: u32,
    input: constructor.Input,
    owner_slot: u32,
    owner_generation: u32,
    owner_local_generation: u32,
    owner_character: u32,
    cohort: Token,
    control: projectile.ControlLease,
    control_session: projectile.Session,
    reset_generation: u64,
    capability: u32,
    cleanup_stamp: u32,
};
pub const CQS_NONE = 0;
pub const CQS_NOT_ACCEPTED = 1;
pub const CQS_UNSUPPORTED_BODY = 2;
pub const CQS_NO_RECEIVER = 3;
pub const CQS_UNREADABLE_RECEIVER = 4;
pub const CQS_UNSUPPORTED_RECEIVER = 5;
pub const CQS_REVERSE_PAIR_MISMATCH = 6;
pub const CQS_NO_HANDLE = 7;
pub const CQS_UNREADABLE_RESOURCE = 8;
pub const CQS_NO_RUNTIME = 9;
pub const CQS_UNREADABLE_RUNTIME = 10;
pub const CQS_INVALID_COUNT = 11;
pub const CQS_COUNT_CAP = 12;
pub const CQS_TABLE_OVERFLOW = 13;
pub const CQS_NO_ARRAY = 14;
pub const CQS_RECORD_OUT_OF_RANGE = 15;
pub const CQS_RECORD_MISALIGNED = 16;
pub const CQS_UNREADABLE_RECORD = 17;
pub const CQS_D4_NOT_SELF_BOUND = 18;
pub const CQS_CHANGED = 19;
pub const CQS_CANCELLED = 20;
pub const CQS_CLOCK_CHANGED = 21;
pub const CQS_UNREADABLE_DESCRIPTOR = 22;
pub const CQS_EMPTY_TABLE = 23;
pub const CQS_NAME_PREFIX = 1;
pub const CQS_NAME_NUL = 2;
pub const CQS_NAME_TRUNCATED = 4;
pub const CQS_NAME_UNREADABLE = 8;
pub const CQS_NAME_CHANGED = 16;
pub const CQS_NAME_NULL = 32;
pub const CCI_NONE = 0;
pub const CCI_NOT_ACCEPTED = 1;
pub const CCI_UNSUPPORTED_BODY = 2;
pub const CCI_NO_WRAPPER = 3;
pub const CCI_UNSUPPORTED_WRAPPER = 4;
pub const CCI_UNREADABLE = 5;
pub const CCI_BAD_USERDATA = 6;
pub const CCI_UNOBSERVED_ACTOR = 7;
pub const CCI_ALLOCATION_NOT_LIVE = 8;
pub const CCI_API_MISMATCH = 9;
pub const CCI_UNMAPPED = 10;
pub const CCI_CHANGED = 11;
pub const CCI_CANCELLED = 12;
pub const CQ_FRAME_ARGS = 1;
pub const CQ_QUERY = 2;
pub const CQ_START = 4;
pub const CQ_DISPLACEMENT = 8;
pub const CQ_GLOBAL = 16;
pub const CQ_DESCRIPTOR = 32;
pub const CQ_ROOT = 64;
pub const CQ_ROOT_VTABLE = 128;
pub const CQ_PARENT = 256;
pub const CQ_OWNER = 512;
pub const CQ_CALLER_ESI = 1024;
comptime {
    const std = @import("std");
    std.debug.assert(@sizeOf(Collider) == 96);
    std.debug.assert(@sizeOf(SourceLinks) == 60);
    std.debug.assert(@sizeOf(Source) == 240);
    std.debug.assert(@sizeOf(Record) == 884);
    std.debug.assert(@offsetOf(Record, "source_witness") == 644);
    std.debug.assert(@offsetOf(Record, "collider_identity") == 548);
    std.debug.assert(@offsetOf(Record, "query_s30_raw") == 188);
    std.debug.assert(@offsetOf(Record, "selected_descriptor_raw") == 328);
    std.debug.assert(@offsetOf(Record, "root_shape_header_raw") == 472);
    std.debug.assert(@offsetOf(Record, "native_control_word") == 536);
    std.debug.assert(@offsetOf(Record, "caller_esi_raw") == 544);
}
