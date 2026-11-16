const std = @import("std");
const s = @import("tag_state.zig");
const p = s.p;
const win = s.win;
const seh = @import("seh_guard.zig");
pub const panic = @import("safety.zig").panic;
pub const std_options: std.Options = .{ .enable_segfault_handler = false };
pub const tag_test_api = @import("tag_fixture_root.zig").tag_test_api;
pub export var tag_test_clock = std.mem.zeroes(s.Clock);
pub export var tag_test_gameplay: c_int = 1;
pub export var tag_runtime_image: [0x1200000]u8 linksection(".fixture") = @splat(0);
const Metadata = extern struct {
    scope_serial: u64,
    pending_generation: u64,
    binding_serial: u64,
    dispatch_revision: u64,
    epoch: u32,
    next_id: u32,
    last_applied: u32,
    replay_cursor: u32,
    active_event: u32,
    pending_count: u32,
    active_session: u32,
    failed: u32,
    current: u32,
    active: u32,
    frame_complete: u32,
    cohort_bound: u32,
    cohort_cancelled: u32,
    scope_cancelled: u32,
    controller: u32,
    actor_update: u32,
    initial_control_available: u32,
    reserved: u32,
};
const Native = struct {
    extern fn tag_fixture_setup() void;
    extern fn tag_fixture_entry() usize;
    extern fn tag_fixture_pending() [*]p.SyncTag;
    extern fn tag_fixture_metadata(*Metadata) void;
    extern fn tags_configure_coherent(?*s.Adapter, ?s.SessionProvider) c_int;
    extern fn tags_bind_cohort(?*const s.Token) c_int;
    extern fn tags_frame_binding_get(?*s.FrameBinding) c_int;
    extern fn tags_abort_frame(?*const s.FrameBinding) c_int;
    extern fn tags_begin(*p.SyncFrame, c_int) c_int;
    extern fn tags_finish() c_int;
    extern fn tags_reset() void;
    extern fn tags_cancel() void;
    extern fn tags_dispatch_pending() c_int;
    extern fn tags_dispatch_complete() c_int;
    extern fn tags_observe_controller_handoffs(?s.AssignmentVersion, ?s.AssignmentRemap) void;
    extern fn tags_resolve_controller_owner(usize, u32, usize, ?*usize, ?*u32) c_int;
    extern fn tags_actor_update(usize, *const fn (usize) callconv(.c) void) void;
    extern var clonewars_tag_debug: [12]u32;
    extern var clonewars_tag_identity_debug: [18]u32;
};
const api = Native;
var actors: [3][0x2000]u8 align(16) = undefined;
var controllers: [3][0x1000]u8 align(16) = undefined;
var generations: [3]u32 = undefined;
var frame: p.SyncFrame = undefined;
var adapter: s.Adapter = undefined;
var token: s.Token = undefined;
var session: s.Session = undefined;
var control: s.ControlLease = undefined;
var phase: u5 = 1;
var release: u32 = 3;
var mode: u32 = 0;
var host = false;
var cancel_mask: u32 = 0;
var session_reads: u32 = 0;
var calls: u32 = 0;
var remaps: [8]u64 = undefined;
var remap_count: u32 = 0;
var version: u64 = 0;
var original_inputs: [4][14]u32 = undefined;
var owner_results: [4][4]u32 = undefined;
var transfer_result: c_int = 0;
extern "kernel32" fn RaiseException(u32, u32, u32, ?[*]const usize) callconv(.winapi) void;
extern "kernel32" fn GetStdHandle(u32) callconv(.winapi) usize;
extern "kernel32" fn WriteFile(usize, [*]const u8, u32, *u32, usize) callconv(.winapi) c_int;

fn check(comptime location: std.builtin.SourceLocation, value: bool) void {
    if (!value) {
        var buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        writer.print("tag assertion line={d}\n", .{location.line}) catch unreachable;
        var written: u32 = 0;
        _ = WriteFile(GetStdHandle(@bitCast(@as(i32, -12))), buffer[0..writer.end].ptr, @intCast(writer.end), &written, 0);
        @panic("tag regression assertion");
    }
}
fn actor(index: usize) usize {
    return @intFromPtr(&actors[index]);
}
fn indexOf(value: usize) ?usize {
    for (0..3) |i| if (actor(i) == value) return i;
    return null;
}
fn identity(index: usize) p.SyncTagIdentity {
    return .{ .character = @intCast(10 + index), .spawn_tag = @intCast(31 + index), .spawn_source = .{ .producer = 42, .serial = @intCast(100 + index) } };
}
fn provider(out: *s.Session) callconv(.c) c_int {
    session_reads += 1;
    out.* = session;
    return 1;
}
export fn coherent_frame_valid(value: *const s.Token, phases: u32) c_int {
    return @intFromBool(std.mem.eql(u8, std.mem.asBytes(value), std.mem.asBytes(&token)) and value.release == release and phases & (@as(u32, 1) << phase) != 0);
}
export fn coherent_frame_release() u32 {
    return release;
}
export fn coherent_frame_cancel_atomic(mask: u32) void {
    cancel_mask |= mask;
}
export fn span_engine_control_get(_: *s.Adapter, out: *s.ControlLease) c_int {
    out.* = control;
    return 1;
}
export fn span_engine_control_valid(_: *s.Adapter, value: *const s.ControlLease) c_int {
    return @intFromBool(value.release == release and value.epoch == control.epoch and value.level == control.level and value.thread == win.GetCurrentThreadId());
}
export fn lan_is_host() c_int {
    return @intFromBool(host);
}
export fn entities_update() void {
    if (mode == 30) api.tags_cancel();
}
export fn entities_slot(value: usize) c_int {
    const i = indexOf(value) orelse return -1;
    return if (mode == 7 and i == 0) -1 else @intCast(i);
}
export fn entities_local_generation(value: usize) u32 {
    return if (indexOf(value)) |i| generations[i] else 0;
}
export fn entities_allocation_live(value: usize, generation: u32) c_int {
    const i = indexOf(value) orelse return 0;
    return @intFromBool(generations[i] == generation and generation != 0 and !(mode == 5 and i == 0));
}
export fn tag_lease_test_live(value: usize, generation: u32) c_int {
    return entities_allocation_live(value, generation);
}
export fn entities_describe(out: *p.SyncActor, value: usize) void {
    const i = indexOf(value) orelse {
        out.* = std.mem.zeroes(p.SyncActor);
        return;
    };
    out.* = std.mem.zeroes(p.SyncActor);
    out.slot = @intCast(i);
    out.generation = generations[i];
    const id = identity(i);
    out.character = id.character;
    out.spawn_tag = id.spawn_tag;
    out.spawn_source = id.spawn_source;
}
export fn entities_resolve_reference(value: *const p.SyncActor) usize {
    if (value.slot >= 3 or (mode == 16 and value.slot == 1)) return 0;
    const i = value.slot;
    const id = identity(i);
    return if (entities_allocation_live(actor(i), value.generation) != 0 and value.character == id.character and value.spawn_tag == id.spawn_tag and std.mem.eql(u8, std.mem.asBytes(&value.spawn_source), std.mem.asBytes(&id.spawn_source))) actor(i) else 0;
}
export fn entities_bind_tick(_: *const p.SyncFrame) c_int {
    return 1;
}
export fn entities_party_matches(_: *const p.SyncFrame) c_int {
    return @intFromBool(mode != 17);
}
fn assignmentVersion() callconv(.c) u64 {
    return version;
}
fn remap(value: u64) callconv(.c) void {
    if (remap_count < remaps.len) remaps[remap_count] = value;
    remap_count += 1;
    version += 1;
    win.SetLastError(777);
}
fn probe(from: usize, to: usize, result: *[4]u32, offset: usize) void {
    const i = indexOf(from) orelse return;
    var owner: usize = 0;
    var generation: u32 = 0;
    const okay = api.tags_resolve_controller_owner(from, 19 + @as(u32, @intCast(i)), @intFromPtr(&controllers[i]), &owner, &generation);
    result[offset] = @intCast(okay);
    result[offset + 1] = if (indexOf(owner)) |n| @as(u32, @intCast(n + 1)) else 0;
    _ = to;
}
export fn tag_test_original(from: usize, to: usize, a: i32, b: i32, c: i32, d: i32, e: i32, f: i32) c_int {
    const n = calls;
    calls += 1;
    if (n < original_inputs.len) {
        original_inputs[n] = .{ @intCast((indexOf(from) orelse 8) + 1), @intCast((indexOf(to) orelse 8) + 1), @bitCast(a), @bitCast(b), @bitCast(c), @bitCast(d), @bitCast(e), @bitCast(f), tag_test_clock.clock, tag_test_clock.rng_game, tag_test_clock.rng_engine, @bitCast(tag_test_clock.delta), win.GetLastError(), 0 };
        probe(from, to, &owner_results[n], 0);
    }
    if (mode == 32) RaiseException(0xe1234567, 0, 0, null);
    tag_test_clock.clock +%= 1;
    tag_test_clock.rng_game +%= 3;
    tag_test_clock.rng_engine +%= 5;
    if (indexOf(from) != null and indexOf(to) != null) {
        const first = win.load(usize, from + 0x6cc);
        win.store(usize, from + 0x6cc, win.load(usize, to + 0x6cc));
        win.store(usize, to + 0x6cc, first);
    }
    if (mode == 28) release += 1;
    if (mode == 29) session.session += 1;
    if (mode == 31) api.tags_reset();
    if (mode == 35) api.tags_observe_controller_handoffs(assignmentVersion, remap);
    if (mode == 36 and from != 0) win.store(usize, from + 0x6cc, @intFromPtr(&controllers[2]));
    if (mode == 37) generations[0] += 1;
    if (mode == 38) win.SetLastError(888);
    if ((mode == 3 or mode == 4 or mode == 34) and n == 0) {
        const entry: s.Transfer = @ptrFromInt(api.tag_fixture_entry());
        _ = entry(actor(1), actor(2), 2, 7, 7, 7, 7, 7);
    }
    if (n < owner_results.len) probe(from, to, &owner_results[n], 2);
    win.SetLastError(444);
    return if (mode == 1 or (mode == 4 and n != 0)) 0 else if (mode == 2) 2 else 1;
}
fn invoke(_: usize) callconv(.c) c_int {
    const entry: s.Transfer = @ptrFromInt(api.tag_fixture_entry());
    const from = if (mode == 9) 0 else actor(if (mode == 19) 2 else 0);
    const to = actor(if (mode == 8) 0 else if (mode == 18) 2 else 1);
    transfer_result = entry(from, to, 1, 2, 3, 4, 5, 6);
    return 1;
}
fn stockUpdate(_: usize) callconv(.c) void {
    if (mode == 33) RaiseException(0xe1234568, 0, 0, null);
    if (!(mode == 15 and !host)) _ = invoke(0);
    win.SetLastError(555);
}
fn invokeUpdate(_: usize) callconv(.c) c_int {
    api.tags_actor_update(actor(0), stockUpdate);
    return 1;
}
const Snapshot = extern struct {
    results: [10]i32,
    calls: u32,
    cancel_mask: u32,
    session_reads: u32,
    remap_count: u32,
    remaps: [8]u64,
    inputs: [4][14]u32,
    owners: [4][4]u32,
    clock: s.Clock,
    controllers: [3]u32,
    generations: [3]u32,
    debug: [12]u32,
    identities: [18]u32,
    tags: [4]p.SyncTag,
    pending: [4]p.SyncTag,
    metadata: Metadata,
    tag_count: u32,
    last_error: u32,
};
fn recordedTag(from: usize, to: usize) p.SyncTag {
    var out = std.mem.zeroes(p.SyncTag);
    out.id = 1;
    out.from = @intCast(from);
    out.to = @intCast(to);
    out.from_generation = @intCast(19 + from);
    out.to_generation = @intCast(19 + to);
    out.from_identity = identity(from);
    out.to_identity = identity(to);
    out.arguments = .{ 1, 2, 3, 4, 5, 6 };
    out.clock = 43;
    out.rng_game = 47;
    out.rng_engine = 53;
    out.delta = 0.1;
    return out;
}
noinline fn run(scenario: u32, host_role: bool) Snapshot {
    mode = scenario;
    host = host_role;
    @memset(std.mem.asBytes(&actors), 0);
    @memset(std.mem.asBytes(&controllers), 0);
    generations = .{ 19, 20, 21 };
    for (0..3) |i| {
        win.store(usize, actor(i) + 0x6cc, @intFromPtr(&controllers[i]));
        win.store(i16, actor(i) + 0xdc0, if (mode == 6 and i == 0) 5000 else @intCast(10 + i));
    }
    frame = std.mem.zeroes(p.SyncFrame);
    frame.epoch = 7;
    frame.sequence = 2;
    frame.level = 6;
    token = .{ .owner = 123, .owner_nonce = 4, .cohort_nonce = 5, .thread = win.GetCurrentThreadId(), .release = 3, .epoch = 7, .sequence = 2, .frame = @intFromPtr(&frame) };
    control = std.mem.zeroes(s.ControlLease);
    control.thread = token.thread;
    control.release = 3;
    control.epoch = 7;
    control.level = 6;
    session = .{ .epoch = 7, .level = 6, .classification = 4, .session = 17 };
    adapter = std.mem.zeroes(s.Adapter);
    adapter.window_thread = token.thread;
    phase = 1;
    release = 3;
    cancel_mask = 0;
    session_reads = 0;
    calls = 0;
    remaps = @splat(0);
    remap_count = 0;
    version = (@as(u64, 1) << 40) | 3;
    original_inputs = std.mem.zeroes(@TypeOf(original_inputs));
    owner_results = std.mem.zeroes(@TypeOf(owner_results));
    transfer_result = -99;
    tag_test_clock = .{ .clock = 43, .rng_game = 47, .rng_engine = 53, .delta = 0.1 };
    api.tag_fixture_setup();
    check(@src(), api.tags_configure_coherent(&adapter, provider) == 1);
    api.tags_observe_controller_handoffs(assignmentVersion, remap);
    if (!host) {
        frame.tag_count = 1;
        frame.tags[0] = recordedTag(0, if (mode == 8) 0 else 1);
        if (mode == 9) frame.tags[0].from_generation = 0;
        if (mode == 6) frame.tags[0].from_identity.character = 5000;
        if (mode == 12) frame.tags[0].parent = 9;
        if (mode == 13) frame.tags[0].id = 2;
        if (mode == 14 or mode == 15 or mode == 33) frame.tags[0].source = p.SYNC_TAG_ACTOR_UPDATE;
        if (mode == 20 or mode == 39) frame.tags[0].phase = 1;
        if (mode == 3 or mode == 4 or mode == 11 or mode == 34) {
            frame.tag_count = 2;
            frame.tags[1] = recordedTag(1, 2);
            frame.tags[1].id = 2;
            frame.tags[1].parent = 1;
            frame.tags[1].arguments = .{ 2, 7, 7, 7, 7, 7 };
            frame.tags[1].clock = 44;
            frame.tags[1].rng_game = 50;
            frame.tags[1].rng_engine = 58;
        }
    }
    var out = std.mem.zeroes(Snapshot);
    var binding = std.mem.zeroes(s.FrameBinding);
    win.SetLastError(333);
    if (mode >= 21 and mode <= 25) {
        session.classification = if (mode <= 24) mode - 20 else 4;
        if (mode == 24) session.classification = 0;
        if (mode == 25) control.epoch += 1;
        out.results[0] = seh.all(0, invoke);
    } else {
        if (mode == 20 or mode == 39) {
            out.results[0] = seh.all(0, invoke);
            if (mode == 39) {
                release += 1;
                token.release = release;
                control.release = release;
            }
        }
        out.results[1] = api.tags_bind_cohort(&token);
        out.results[2] = api.tags_frame_binding_get(&binding);
        out.results[3] = api.tags_begin(&frame, @intFromBool(host));
        if (mode == 27) {
            var stale = binding;
            stale.binding_serial -%= 1;
            out.results[4] = api.tags_abort_frame(&stale);
        }
        phase = 2;
        if (mode == 26) session.session += 1;
        if (mode != 10 and mode != 20 and mode != 39) {
            win.SetLastError(333);
            out.results[5] = seh.all(0, if (mode == 14 or mode == 15 or mode == 33) invokeUpdate else invoke);
        }
        out.results[6] = api.tags_dispatch_pending();
        out.results[7] = if (out.results[5] != 0 or mode == 10 or mode == 20 or mode == 39) api.tags_dispatch_complete() else -99;
        phase = 3;
        out.results[8] = api.tags_finish();
        out.results[9] = api.tags_abort_frame(&binding);
    }
    out.results[4] += transfer_result * 10;
    out.last_error = win.GetLastError();
    out.calls = calls;
    out.cancel_mask = cancel_mask;
    out.session_reads = session_reads;
    out.remap_count = remap_count;
    out.remaps = remaps;
    out.inputs = original_inputs;
    out.owners = owner_results;
    out.clock = tag_test_clock;
    out.generations = generations;
    for (0..3) |i| {
        const value = win.load(usize, actor(i) + 0x6cc);
        for (0..3) |j| if (value == @intFromPtr(&controllers[j])) {
            out.controllers[i] = @intCast(j + 1);
        };
    }
    out.debug = Native.clonewars_tag_debug;
    out.identities = Native.clonewars_tag_identity_debug;
    out.tags = frame.tags[0..4].*;
    out.pending = api.tag_fixture_pending()[0..4].*;
    api.tag_fixture_metadata(&out.metadata);
    out.tag_count = frame.tag_count;
    check(@src(), out.metadata.controller == 0 and out.metadata.actor_update == 0);
    return out;
}
fn installerTest() void {
    _ = run(0, true);
    phase = 1;
    api.tag_fixture_setup();
    check(@src(), api.tags_configure_coherent(&adapter, provider) == 1);
    const site: usize = 0x8ae680;
    const image = @intFromPtr(&tag_runtime_image);
    check(@src(), image <= site and site + 32 <= image + tag_runtime_image.len);
    var protection: u32 = 0;
    check(@src(), win.VirtualProtect(site, 32, 0x40, &protection) != 0);
    const prefix = "\x83\xec\x28\x56\x8b\x74\x24\x30";
    const bytes: [*]u8 = @ptrFromInt(site);
    @memcpy(bytes[0..8], prefix);
    @memcpy(bytes[8..13], "\x5e\x83\xc4\x28\xe9");
    win.store(u32, site + 13, @truncate(@intFromPtr(&tag_test_original) -% site -% 17));
    var unused: u32 = 0;
    check(@src(), win.VirtualProtect(site, 32, 0x20, &unused) != 0);
    const install = @import("tag_input.zig").tags_install;
    for (0..8) |i| {
        check(@src(), win.VirtualProtect(site, 8, 0x40, &unused) != 0);
        bytes[i] ^= 0x01;
        check(@src(), win.VirtualProtect(site, 8, 0x20, &unused) != 0);
        check(@src(), install() == 0);
        check(@src(), bytes[i] == prefix[i] ^ 0x01);
        check(@src(), win.VirtualProtect(site, 8, 0x40, &unused) != 0);
        bytes[i] ^= 0x01;
        check(@src(), win.VirtualProtect(site, 8, 0x20, &unused) != 0);
    }
    check(@src(), install() == 1 and bytes[0] == 0xe9);
    var info: win.MemoryInfo = undefined;
    check(@src(), win.VirtualQuery(site, &info, @sizeOf(win.MemoryInfo)) != 0 and info.protection == 0x20);
    check(@src(), install() == 0);
    check(@src(), api.tags_bind_cohort(&token) == 1);
    check(@src(), api.tags_begin(&frame, 1) == 1);
    phase = 2;
    const installed: s.Transfer = @ptrFromInt(site);
    calls = 0;
    check(@src(), installed(actor(0), actor(1), 1, 2, 3, 4, 5, 6) == 1);
    check(@src(), calls == 1 and frame.tag_count == 1 and frame.tags[0].id == 1);
    check(@src(), api.tags_dispatch_complete() == 1);
    phase = 3;
    check(@src(), api.tags_finish() == 1);
    var binding: s.FrameBinding = undefined;
    check(@src(), api.tags_frame_binding_get(&binding) == 1 and api.tags_abort_frame(&binding) == 1);
}
pub fn main() void {
    const expected = [_]u32{ 3286726807, 611763333, 2651076322, 755591980, 1468594346, 3128100626, 114920627, 662609694, 720053393, 899311955, 3650510574, 3400237334, 1436052697, 1190138704, 1662470011, 2145384779, 1486907065, 3429251285, 108438739, 2453651392, 670993899, 1583902743, 4246545365, 3385452339, 1693504817, 1342309449, 859073123, 1381852151, 2518395343, 2431326499, 4154659231, 3933872199, 3386354728, 2189087173, 3560171750, 64045539, 4283886630, 4281490423, 1204453476, 1418630423, 1639783820, 3751328564, 1579070747, 2136906552, 4062181707, 1254595204, 3403785099, 3250611648, 289783501, 2303741364, 4002199812, 358186008, 2114291241, 2518576185, 310468415, 289630677, 2282834028, 1064587389, 491436677, 1901528910, 1967708107, 3222032500, 516812752, 1351194383, 3786690708, 914430109, 147139037, 3788630088, 1642230559, 46009412, 4139720643, 1888732163, 3886719537, 2936507973, 4098462983, 3423618395, 729522683, 1668398695, 4004475148, 3711099304 };
    check(@src(), @sizeOf(Snapshot) == 1512);
    for (0..40) |scenario| for (0..2) |role| {
        const actual = run(@intCast(scenario), role == 1);
        var hash: u32 = 2166136261;
        for (std.mem.asBytes(&actual)) |byte| hash = (hash ^ byte) *% 16777619;
        const frozen = expected[scenario * 2 + role];
        if (hash != frozen) std.debug.print("tag scenario={d} host={d} hash={d} expected={d}\n", .{ scenario, role, hash, frozen });
        check(@src(), hash == frozen);
        if (scenario == 0) {
            check(@src(), actual.calls == 1 and actual.tag_count == 1 and actual.results[8] == 1);
            check(@src(), actual.controllers[0] == 2 and actual.controllers[1] == 1);
            check(@src(), actual.owners[0][0] == 1 and actual.owners[0][1] == 1 and actual.owners[0][2] == 1 and actual.owners[0][3] == 2);
        }
    };
    installerTest();
}
comptime {
    _ = @import("tag_fixture_root.zig");
}
