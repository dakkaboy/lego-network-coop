const std = @import("std");
const win = @import("win32.zig");
const types = @import("spellit_types.zig");
const Token = @import("cohort_types.zig").Token;
pub const Scope = struct { previous: ?*Scope, token: Token, source: types.Source, gizmo: usize, delta: f32, clock: u32, bound: bool, machine: @import("machine_environment.zig").Environment, inputs_allocation: usize, bindings_allocation: usize };
pub threadlocal var current: ?*Scope = null;
pub export var clonewars_spellit_hop_debug: [4]u32 = @splat(0);
pub export var clonewars_spellit_hop_failure: [12]u32 = @splat(0);
pub export var clonewars_spellit_hop_correction: [12]u32 = @splat(0);
pub export var clonewars_spellit_native_count: u32 = 0;
pub export var clonewars_spellit_native_batch: [256][40]u32 = std.mem.zeroes([256][40]u32);
pub export var clonewars_spellit_completion_debug: [8]u32 = @splat(0);
extern fn coherent_frame_valid(*const Token, u32) c_int;
extern fn game_sync_native_fault(c_int) void;
extern fn native_spellit_piece_resolve(*const types.Source, usize, *types.Piece) c_int;
pub fn live(s: *const Scope) bool {
    return s.bound and coherent_frame_valid(&s.token, 4) != 0 and win.load(u32, 0xfb4b6c) == s.clock;
}
pub fn reject(s: *const Scope, reason: u32, kind: u32) void {
    clonewars_spellit_hop_debug[3] +%= 1;
    if (clonewars_spellit_hop_failure[2] == 0) clonewars_spellit_hop_failure = .{ s.token.epoch, s.token.sequence, reason, kind, s.clock, @truncate(s.gizmo), s.source.key.gizmo_class, s.source.key.gizmo_ordinal, s.source.key.name[0], s.source.key.name[1], s.source.key.name[2], s.source.key.name[3] };
    game_sync_native_fault(15);
}
pub fn snapshot(s: *const Scope) void {
    var row: [40]u32 = @splat(0);
    row[1..4].* = .{ s.token.epoch, s.token.sequence, s.clock };
    @memcpy(std.mem.asBytes(row[4..10]), std.mem.asBytes(&s.source.key));
    row[10] = win.load(u32, s.gizmo + 0x218);
    row[11..14].* = win.load([3]u32, s.gizmo + 0xd0);
    const selected = win.load(usize, s.gizmo + 0x21c);
    row[14] = @truncate(selected);
    if (win.accessible(selected, 0x114, false)) {
        row[15] = win.load(u32, selected + 0x110);
        row[16..19].* = win.load([3]u32, selected + 0xd0);
        row[38] = win.load(u32, selected + 0x88);
        var piece: types.Piece = undefined;
        if (native_spellit_piece_resolve(&s.source, selected, &piece) != 0) {
            row[23] = 1;
            @memcpy(std.mem.asBytes(row[24..36]), std.mem.asBytes(&piece.key));
        }
    }
    row[19] = win.load(u32, s.gizmo + 0x16c);
    row[20] = win.load(u32, 0xea178c);
    row[21] = win.load(u16, 0xe637b4);
    row[22] = @bitCast(s.delta);
    row[36] = @truncate(s.gizmo);
    row[37] = win.load(u32, s.gizmo + 0x150);
    const control = std.mem.bytesToValue(u16, s.machine.fx[0..2]);
    const mxcsr = std.mem.bytesToValue(u32, s.machine.fx[24..28]);
    row[39] = control | (mxcsr << 16);
    clonewars_spellit_native_count +%= 1;
    const serial = clonewars_spellit_native_count;
    const target = &clonewars_spellit_native_batch[(serial -% 1) % 256];
    @atomicStore(u32, &target[0], 0, .seq_cst);
    @memcpy(target[1..40], row[1..40]);
    @atomicStore(u32, &target[0], serial, .seq_cst);
}
