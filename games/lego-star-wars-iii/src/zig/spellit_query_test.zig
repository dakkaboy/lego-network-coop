const std = @import("std");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var caller_fx: [512]u8 align(16) = @splat(0);
export var observed_fx: [512]u8 align(16) = @splat(0);
export var actor: [0x40]u8 = @splat(0);
export var model: [0x48]u8 = @splat(0);
export var manager: [0x30]u8 = @splat(0);
export var entry: usize = 0;
export var test_eax: usize = 0;
export var test_esi: usize = 0;
export var observed_regs: [9]u32 = @splat(0);
export var mxcsr_value: u32 = 0x3f80;
export var helper_mxcsr: u32 = 0x5f80;
export var initial_limit: f32 = 0;
export var observed_limit: f32 = 0;
export var candidate: [3]f32 = @splat(0);
export var output: [3]f32 = @splat(0);
export var distance_value: f32 = 0;
export var observed_height_store: u32 = 0;
export var distance_calls: u32 = 0;
export var native_candidate: usize = 0;
export var native_caster: usize = 0;
export var native_output: usize = 0;
export var native_caster_values: [3]f32 = @splat(0);
export var live_fpu: [2]f64 = .{ 1.25, -2.5 };
export var node_stack: [36]u32 = @splat(0);
export var observed_node_stack: [36]u32 = @splat(0);
export var spellit_prepare_resume: usize = 0;
export var spellit_first_heading_resume: usize = 0;
export var spellit_second_heading_resume: usize = 0;
export var spellit_height_resume: usize = 0;
export var spellit_node_resume: usize = 0;
export var spellit_distance_native: usize = 0;
var project = false;
var expected_local: u32 = 0;
var canonical_operand: u32 = 0;
var expected_kind: u32 = 0;
var canonical_limit: f32 = 0;
var canonical_position: [3]f32 = @splat(0);
var prepare_calls: u32 = 0;
var operand_calls: u32 = 0;
var position_calls: u32 = 0;
var node_calls: u32 = 0;
var node_local: [3]f32 = @splat(0);
var node_canonical: [3]f32 = @splat(0);
const query_frame = 0x55555555;
fn bits(value: f32) u32 {
    return @bitCast(value);
}
fn equal(a: anytype, b: anytype) bool {
    return std.mem.eql(u8, std.mem.asBytes(&a), std.mem.asBytes(&b));
}
fn helperEnvironment() void {
    var flags: u32 = 0;
    var mxcsr: u32 = 0;
    var control: u16 = 0;
    var status: u16 = 0;
    asm volatile ("pushfl; popl %[flags]; stmxcsr (%[mx]); fnstcw (%[cw]); fnstsw (%[sw])"
        : [flags] "=&r" (flags),
        : [mx] "r" (&mxcsr),
          [cw] "r" (&control),
          [sw] "r" (&status),
        : .{ .memory = true });
    check(@src(), flags & 0x400 == 0 and mxcsr == 0x1f80 and control == 0x37f and status & 0x3800 == 0);
}
noinline fn clobber() void {
    asm volatile (
        \\fninit
        \\fldz
        \\fld1
        \\ldmxcsr _helper_mxcsr
        \\pcmpeqd %xmm0,%xmm0
        \\pcmpeqd %xmm1,%xmm1
        \\pcmpeqd %xmm2,%xmm2
        \\pcmpeqd %xmm3,%xmm3
        \\pcmpeqd %xmm4,%xmm4
        \\pcmpeqd %xmm5,%xmm5
        \\pcmpeqd %xmm6,%xmm6
        \\pcmpeqd %xmm7,%xmm7
        \\movl $0x12345678,%eax
        \\movl $0x87654321,%ecx
        \\movl $0xabcdef01,%edx
        \\stc
        ::: .{ .eax = true, .ecx = true, .edx = true, .cc = true, .memory = true, .xmm0 = true, .xmm1 = true, .xmm2 = true, .xmm3 = true, .xmm4 = true, .xmm5 = true, .xmm6 = true, .xmm7 = true });
}
export fn cadence_spellit_prepare(object: usize, owner: usize, frame: usize, limit: *f32) void {
    const err = win.GetLastError();
    helperEnvironment();
    check(@src(), object == @intFromPtr(&actor) and owner == @intFromPtr(&manager) and frame == query_frame and bits(limit.*) == bits(initial_limit));
    prepare_calls += 1;
    if (project) limit.* = canonical_limit;
    clobber();
    win.SetLastError(err);
}
export fn cadence_spellit_operand(frame: usize, kind: u32, local: u32) u32 {
    const err = win.GetLastError();
    helperEnvironment();
    check(@src(), frame == query_frame and kind == expected_kind and local == expected_local);
    operand_calls += 1;
    const result = if (project) canonical_operand else local;
    clobber();
    win.SetLastError(err);
    return result;
}
export fn cadence_spellit_position(frame: usize, point: *[3]f32) void {
    const err = win.GetLastError();
    helperEnvironment();
    check(@src(), frame == query_frame and @intFromPtr(point) != @intFromPtr(&actor) + 0x24);
    check(@src(), equal(point.*, @as([3]f32, @bitCast(actor[0x24..][0..12].*))));
    position_calls += 1;
    if (project) point.* = canonical_position;
    clobber();
    win.SetLastError(err);
}
export fn cadence_spellit_node(frame: usize, gizmo: usize, node: usize, point: *[3]f32) void {
    const err = win.GetLastError();
    helperEnvironment();
    check(@src(), frame == query_frame and gizmo == @intFromPtr(&manager) and node == 0x77777777 and equal(point.*, node_local));
    node_calls += 1;
    if (project) point.* = node_canonical;
    clobber();
    win.SetLastError(err);
}
extern fn prepare_cont() void;
extern fn first_heading_cont() void;
extern fn second_heading_cont() void;
extern fn height_cont() void;
extern fn original_prepare() void;
extern fn original_first_heading() void;
extern fn original_second_heading() void;
extern fn original_height() void;
extern fn original_node() void;
extern fn invoke_node() void;
extern fn invoke_operand() void;
extern fn native_distance() void;
extern fn invoke_distance() void;
extern fn spellit_prepare_thunk() void;
extern fn spellit_first_heading_thunk() void;
extern fn spellit_second_heading_thunk() void;
extern fn spellit_height_thunk() void;
extern fn spellit_node_thunk() void;
extern fn spellit_position_thunk() void;
comptime {
    asm (@import("spellit_query_fixture.zig").code);
    for (.{ "spellit_prepare_thunk", "spellit_first_heading_thunk", "spellit_second_heading_thunk", "spellit_height_thunk", "spellit_node_thunk", "spellit_position_thunk" }) |name| asm (@import("cadence_bridge_code.zig").code(name));
}
const Observation = struct { regs: [9]u32, fx: [512]u8, limit: f32, height_store: u32 };
fn observation() Observation {
    return .{ .regs = observed_regs, .fx = observed_fx, .limit = observed_limit, .height_store = observed_height_store };
}
fn sameFx(a: *const [512]u8, b: *const [512]u8) void {
    check(@src(), std.mem.eql(u8, a[0..5], b[0..5]) and std.mem.eql(u8, a[24..32], b[24..32]));
    for (0..8) |i| check(@src(), std.mem.eql(u8, a[32 + 16 * i ..][0..10], b[32 + 16 * i ..][0..10]));
    check(@src(), std.mem.eql(u8, a[160..288], b[160..288]));
}
fn same(expected: *const Observation) void {
    check(@src(), equal(expected.regs, observed_regs));
    sameFx(&expected.fx, &observed_fx);
    check(@src(), bits(expected.limit) == bits(observed_limit) and expected.height_store == observed_height_store and observed_regs[8] & 0x400 != 0);
}
fn heading(value: u16) void {
    win.store(u16, @intFromPtr(&model) + 0x40, value);
}
fn y(value: u32) void {
    win.store(u32, @intFromPtr(&actor) + 0x28, value);
}
fn position(value: [3]f32) void {
    @memcpy(actor[0x24..][0..12], std.mem.asBytes(&value));
}
pub fn main() void {
    spellit_prepare_resume = @intFromPtr(&prepare_cont);
    spellit_first_heading_resume = @intFromPtr(&first_heading_cont);
    spellit_second_heading_resume = @intFromPtr(&second_heading_cont);
    spellit_height_resume = @intFromPtr(&height_cont);
    spellit_node_resume = @intFromPtr(&prepare_cont);
    spellit_distance_native = @intFromPtr(&native_distance);
    const min: f32 = @bitCast(@as(u32, 0x00800000));
    const max: f32 = @bitCast(@as(u32, 0x7f7fffff));
    const limits = [_]f32{ -max, -1, -min, -0.0, 0, min, 0.5, 1, max };
    const headings = [_]u16{ 0, 1, 0x3fff, 0x4000, 0x7fff, 0x8000, 0xffff };
    const heights = [_]f32{ -max, -1, -min, -0.0, 0, min, 1, max };
    model[0x42] = 0xa5;
    model[0x43] = 0x5a;
    for (0..6000) |i| {
        project = i & 1 != 0;
        canonical_limit = limits[(i + 3) % 9];
        const local_limit = limits[i % 9];
        const model_pointer: usize = if (i % 3 != 0) @intFromPtr(&model) else 0;
        win.store(usize, @intFromPtr(&actor) + 8, model_pointer);
        test_esi = @intFromPtr(&actor);
        test_eax = 0x11111111;
        initial_limit = if (project) canonical_limit else local_limit;
        entry = @intFromPtr(&original_prepare);
        invoke_operand();
        var expected = observation();
        initial_limit = local_limit;
        var actor_before = actor;
        var model_before = model;
        entry = @intFromPtr(&spellit_prepare_thunk);
        win.SetLastError(123);
        invoke_operand();
        check(@src(), win.GetLastError() == 123);
        same(&expected);
        check(@src(), observed_regs[7] == model_pointer and (observed_regs[8] & 0x40 != 0) == (model_pointer == 0) and equal(actor_before, actor) and equal(model_before, model));
        expected_kind = 0;
        expected_local = headings[i % 7];
        canonical_operand = headings[(i + 2) % 7];
        for (0..2) |second| {
            test_eax = if (second != 0) 0x11111111 else @intFromPtr(&model);
            test_esi = if (second != 0) @intFromPtr(&model) else 0x66666666;
            heading(@intCast(if (project) canonical_operand else expected_local));
            entry = if (second != 0) @intFromPtr(&original_second_heading) else @intFromPtr(&original_first_heading);
            invoke_operand();
            expected = observation();
            heading(@intCast(expected_local));
            model_before = model;
            entry = if (second != 0) @intFromPtr(&spellit_second_heading_thunk) else @intFromPtr(&spellit_first_heading_thunk);
            win.SetLastError(123);
            invoke_operand();
            check(@src(), win.GetLastError() == 123);
            same(&expected);
            check(@src(), observed_regs[7] == (if (project) canonical_operand else expected_local) and equal(model_before, model));
        }
        expected_kind = 1;
        expected_local = bits(heights[i % 8]);
        canonical_operand = bits(heights[(i + 3) % 8]);
        test_eax = @intFromPtr(&actor);
        test_esi = 0x66666666;
        y(if (project) canonical_operand else expected_local);
        entry = @intFromPtr(&original_height);
        invoke_operand();
        expected = observation();
        y(expected_local);
        actor_before = actor;
        entry = @intFromPtr(&spellit_height_thunk);
        win.SetLastError(123);
        invoke_operand();
        check(@src(), win.GetLastError() == 123);
        same(&expected);
        check(@src(), observed_height_store == 0x22222222 and equal(actor_before, actor));
        var local_position: [3]f32 = undefined;
        for (0..3) |j| {
            local_position[j] = @as(f32, @floatFromInt(@as(i32, @intCast((i * 31 + j * 97) % 173)) - 86)) / 37;
            canonical_position[j] = local_position[j] + @as(f32, @floatFromInt(j + 1)) * 0.03125;
            candidate[j] = @as(f32, @floatFromInt(@as(i32, @intCast((i * 43 + j * 59) % 191)) - 95)) / 19;
        }
        position(if (project) canonical_position else local_position);
        entry = @intFromPtr(&native_distance);
        const before = distance_calls;
        invoke_distance();
        expected = observation();
        const expected_distance = distance_value;
        const expected_output = output;
        position(local_position);
        actor_before = actor;
        model_before = model;
        const candidate_before = candidate;
        entry = @intFromPtr(&spellit_position_thunk);
        win.SetLastError(123);
        invoke_distance();
        check(@src(), win.GetLastError() == 123 and distance_calls == before + 2 and bits(distance_value) == bits(expected_distance) and equal(expected_output, output) and bits(output[1]) == 0);
        const used = if (project) canonical_position else local_position;
        const dx = candidate[0] - used[0];
        const dz = candidate[2] - used[2];
        const squared: f32 = @floatCast(@as(f64, dx) * dx + @as(f64, dz) * dz);
        check(@src(), bits(output[0]) == bits(dx) and bits(output[2]) == bits(dz) and bits(distance_value) == bits(squared));
        check(@src(), native_candidate == @intFromPtr(&candidate) and native_output == @intFromPtr(&output) and native_caster != @intFromPtr(&actor) + 0x24 and equal(native_caster_values, used));
        check(@src(), observed_regs[0] == 0x77777777 and observed_regs[1] == 0x66666666 and observed_regs[2] == query_frame and observed_regs[4] == 0x44444444 and observed_regs[3] == expected.regs[3] and observed_regs[8] & 0x400 != 0);
        sameFx(&expected.fx, &observed_fx);
        check(@src(), equal(actor_before, actor) and equal(model_before, model) and equal(candidate_before, candidate));
        for (&node_stack, 0..) |*value, j| value.* = @intCast(i * 311 + j * 57);
        for (0..3) |j| {
            node_local[j] = heights[(i + j) % 8];
            node_canonical[j] = heights[(i + j + 3) % 8];
        }
        @memcpy(std.mem.sliceAsBytes(node_stack[27..30]), std.mem.asBytes(&(if (project) node_canonical else node_local)));
        entry = @intFromPtr(&original_node);
        invoke_node();
        expected = observation();
        const expected_stack = observed_node_stack;
        @memcpy(std.mem.sliceAsBytes(node_stack[27..30]), std.mem.asBytes(&node_local));
        entry = @intFromPtr(&spellit_node_thunk);
        win.SetLastError(123);
        invoke_node();
        check(@src(), win.GetLastError() == 123);
        same(&expected);
        check(@src(), equal(expected_stack, observed_node_stack) and std.mem.eql(u8, std.mem.sliceAsBytes(node_stack[27..30]), std.mem.asBytes(&node_local)));
    }
    check(@src(), prepare_calls == 6000 and operand_calls == 18000 and position_calls == 6000 and distance_calls == 12000 and node_calls == 6000);
}
