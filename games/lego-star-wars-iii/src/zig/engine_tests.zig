const std = @import("std");
const win = @import("win32.zig");
const fence = @import("frame_fence.zig");
const rigid = @import("rigid_body.zig");
const match = @import("entity_match.zig");
const context = @import("context.zig");
const p = @import("protocol.zig");
var owner_live = true;
export fn native_owner_scope_valid(owner: usize, nonce: c_uint) c_int {
    win.SetLastError(0xdeadbeef);
    return @intFromBool(owner_live and owner == 9 and nonce == 4);
}

test "frame fence: preserve LastError, reject stale leases and close after frame destruction" {
    owner_live = true;
    defer owner_live = true;
    win.SetLastError(0x12345678);
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_register_main());
    try std.testing.expectEqual(@as(u32, 0x12345678), win.GetLastError());
    const allocation = win.VirtualAlloc(0, 0x1000, 0x3000, 4);
    try std.testing.expect(allocation != 0);
    var freed = false;
    defer if (!freed) {
        _ = win.VirtualFree(allocation, 0, 0x8000);
    };
    win.store(u32, allocation, 3);
    win.store(u32, allocation + 4, 7);
    var token: fence.Token = undefined;
    win.SetLastError(0x76543210);
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_open(&token, 9, 4, allocation, 3, 7, fence.coherent_frame_release()));
    try std.testing.expectEqual(@as(u32, 0x76543210), win.GetLastError());
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_valid(&token, 2));
    var other = token;
    other.sequence = 8;
    try std.testing.expectEqual(@as(c_int, 0), fence.coherent_frame_valid(&other, 0x3e));
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_set_phase(&token, 3));
    try std.testing.expectEqual(@as(c_int, 0), fence.coherent_frame_set_phase(&token, 2));
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_valid(&token, 8));
    try std.testing.expect(win.VirtualFree(allocation, 0, 0x8000) != 0);
    freed = true;
    owner_live = false;
    fence.coherent_frame_cancel_atomic(0x40);
    win.SetLastError(0xabcdef01);
    try std.testing.expectEqual(@as(c_int, 0), fence.coherent_frame_valid(&token, 0x3e));
    try std.testing.expectEqual(@as(c_int, 1), fence.coherent_frame_close(&token));
    try std.testing.expectEqual(@as(c_int, 0), fence.coherent_frame_close(&token));
    try std.testing.expectEqual(@as(u32, 0xabcdef01), win.GetLastError());
    try std.testing.expect(fence.coherent_frame_pending_reasons() & 0x40 != 0);
}

var fixture_base: usize = 0;
var lookup_calls: u32 = 0;
var transform_calls: u32 = 0;
fn lookup(manager: usize, actor: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    std.debug.assert(manager == fixture_base + 0x2000 and actor == fixture_base);
    lookup_calls += 1;
    return fixture_base + 0x2400;
}
fn transform(body: usize, matrix: [*]const f32) callconv(.{ .x86_thiscall = .{} }) void {
    std.debug.assert(body == fixture_base + 0x2c00);
    transform_calls += 1;
    win.store([16]f32, body + 0x40, matrix[0..16].*);
}
test "rigid body: follow native ownership links and reject reused dynamics" {
    fixture_base = win.VirtualAlloc(0, 0x4000, 0x3000, 4);
    try std.testing.expect(fixture_base != 0);
    defer _ = win.VirtualFree(fixture_base, 0, 0x8000);
    lookup_calls = 0;
    transform_calls = 0;
    const b = fixture_base;
    win.store(u32, b + 0x215c, 1);
    win.store(usize, b + 0x2160, b + 0x2400);
    win.store(usize, b + 0x269c, b);
    win.store(usize, b + 0x2694, b + 0x2800);
    win.store(usize, b + 0x2a60, b + 0x2c00);
    const source: rigid.Source = .{ .manager = b + 0x2000, .lookup = lookup, .transform = transform };
    var binding: rigid.Binding = undefined;
    try std.testing.expect(source.resolve(b, &binding));
    try std.testing.expectEqual(b + 0x2c00, binding.body);
    try std.testing.expect(source.matches(b, &binding));
    win.store(usize, b + 0x2c98, b + 0x3000);
    try std.testing.expect(!source.matches(b, &binding));
    try std.testing.expect(source.resolve(b, &binding));
    try std.testing.expectEqual(b + 0x3000, binding.dynamics);
    win.store(usize, b + 0x2c98, 1);
    try std.testing.expect(!source.resolve(b, &binding));
    try std.testing.expectEqual(@as(usize, 0), binding.body);
    win.store(usize, b + 0x2c98, 0);
    try std.testing.expect(source.resolve(b, &binding));
    const matrix = [_]f32{ 0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, 0, 12, 3, -5, 1 };
    source.transform(binding.body, &matrix);
    try std.testing.expectEqual(@as(u32, 1), transform_calls);
    try std.testing.expectEqualDeep(matrix, win.load([16]f32, b + 0x2c40));
    win.store(u32, b + 0x215c, 4097);
    const before = lookup_calls;
    try std.testing.expect(!source.resolve(b, &binding));
    try std.testing.expectEqual(before, lookup_calls);
}

test "entity matching: require unique authored identity across local generations" {
    const wanted: match.Key = .{ .generation = 99, .spawn_tag = 7, .character = 466, .spawn_source = .{ .producer = 17, .serial = 3 } };
    var candidates = [_]match.Key{ wanted, wanted };
    candidates[0].generation = 2;
    var claimed = [_]u8{ 0, 1 };
    try std.testing.expectEqual(@as(c_int, 0), match.entity_match_unique(&wanted, &candidates, &claimed, 2));
    claimed[1] = 0;
    try std.testing.expectEqual(@as(c_int, -2), match.entity_match_unique(&wanted, &candidates, &claimed, 2));
    candidates[1].spawn_source.serial = 4;
    try std.testing.expectEqual(@as(c_int, 0), match.entity_match_unique(&wanted, &candidates, &claimed, 2));
    candidates[0].generation = 0;
    try std.testing.expectEqual(@as(c_int, -1), match.entity_match_unique(&wanted, &candidates, &claimed, 2));
}

test "model context: discard only the inactive derived fields" {
    var authoritative = std.mem.zeroes(p.SyncModelInput);
    authoritative.generation = 1;
    authoritative.period = 1;
    authoritative.context.axis_1dd = 255;
    authoritative.context.actor_4c_mask = 1;
    var local = authoritative.context;
    local.cf4_raw = 0x7fc00001;
    local.c7c_1000 = 55;
    try std.testing.expectEqual(@as(c_int, 1), context.model_context_relevant_equal(&authoritative, &authoritative.context, &local));
    local.numeric_cw = 0x100;
    try std.testing.expectEqual(@as(c_int, 0), context.model_context_relevant_equal(&authoritative, &authoritative.context, &local));
}

test "trace capture: discover a loaded x86 module and copy committed events" {
    const path = try std.unicode.utf8ToUtf16LeAllocZ(std.testing.allocator, @import("test_options").trace_fixture);
    defer std.testing.allocator.free(path);
    const module = win.LoadLibraryW(path);
    try std.testing.expect(module != 0);
    defer _ = win.FreeLibrary(module);
    var snapshot: [@sizeOf(@import("trace.zig").Ring(512))]u8 = undefined;
    try @import("trace_capture.zig").capture(win.GetCurrentProcessId(), &snapshot);
    var text: [1024]u8 = undefined;
    var output = std.Io.Writer.fixed(&text);
    try @import("trace_file.zig").decode(&snapshot, 0, &output);
    try std.testing.expect(std.mem.indexOf(u8, output.buffered(), "\"epoch\":5,\"sequence\":7,\"domain\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.buffered(), "\"local\":3,\"remote\":4,\"detail\":9") != null);
}
