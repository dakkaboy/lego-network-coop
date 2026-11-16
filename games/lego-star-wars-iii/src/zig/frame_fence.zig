const std = @import("std");
const win = @import("win32.zig");
pub const Token = @import("cohort_types.zig").Token;
extern fn native_owner_scope_valid(usize, c_uint) c_int;
var main_thread: u32 = 0;
var release_serial: u32 = 1;
var disabled: u32 = 0;
var pending_reasons: u32 = 0;
threadlocal var current = std.mem.zeroes(Token);
threadlocal var active: bool = false;
threadlocal var phase: u32 = 0;
threadlocal var next_nonce: u32 = 0;
fn load(value: *const u32) u32 {
    return @atomicLoad(u32, value, .seq_cst);
}
fn mainNow() bool {
    return load(&main_thread) == win.GetCurrentThreadId();
}
pub export fn coherent_frame_release() u32 {
    return load(&release_serial);
}
pub export fn coherent_frame_pending_reasons() u32 {
    return load(&pending_reasons);
}
pub export fn coherent_frame_cancel_atomic(why: u32) void {
    _ = @atomicRmw(u32, &pending_reasons, .Or, why, .seq_cst);
    while (true) {
        const prior = load(&release_serial);
        if (prior == 0xffffffff) {
            @atomicStore(u32, &disabled, 1, .seq_cst);
            return;
        }
        if (load(&disabled) != 0) return;
        if (@cmpxchgWeak(u32, &release_serial, prior, prior + 1, .seq_cst, .seq_cst) == null) return;
    }
}
pub export fn coherent_frame_register_main() c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const thread = win.GetCurrentThreadId();
    const prior = @cmpxchgStrong(u32, &main_thread, 0, thread, .seq_cst, .seq_cst);
    return @intFromBool(prior == null or prior.? == thread);
}
fn metadata(token: ?*const Token, phases: u32) bool {
    const t = token orelse return false;
    if (load(&disabled) != 0 or !mainNow() or !active or t.cohort_nonce == 0 or t.epoch == 0 or t.sequence == 0 or t.frame == 0) return false;
    if (!std.meta.eql(t.*, current) or t.thread != win.GetCurrentThreadId() or coherent_frame_release() != t.release) return false;
    if (phase < 1 or phase > 5 or phases & (@as(u32, 1) << @as(u5, @intCast(phase))) == 0) return false;
    return native_owner_scope_valid(t.owner, t.owner_nonce) != 0 and coherent_frame_release() == t.release and load(&disabled) == 0;
}
fn valid(token: ?*const Token, phases: u32) bool {
    if (!metadata(token, phases)) return false;
    const t = token.?;
    const epoch = win.load(u32, t.frame);
    const sequence = win.load(u32, t.frame + 4);
    return epoch == t.epoch and sequence == t.sequence and metadata(t, phases);
}
pub export fn coherent_frame_valid(token: ?*const Token, phases: u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    return @intFromBool(valid(token, phases));
}
pub export fn coherent_frame_open(out: ?*Token, owner: usize, nonce: u32, frame: usize, epoch: u32, sequence: u32, release: u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (out == null or load(&disabled) != 0 or !mainNow() or active or frame == 0 or epoch == 0 or sequence == 0 or nonce == 0 or
        coherent_frame_release() != release or native_owner_scope_valid(owner, nonce) == 0) return 0;
    next_nonce +%= 1;
    if (next_nonce == 0) {
        @atomicStore(u32, &disabled, 1, .seq_cst);
        return 0;
    }
    const t: Token = .{ .owner = owner, .owner_nonce = nonce, .cohort_nonce = next_nonce, .thread = win.GetCurrentThreadId(), .release = release, .epoch = epoch, .sequence = sequence, .frame = frame };
    current = t;
    phase = 1;
    active = true;
    if (!valid(&t, 2)) {
        active = false;
        return 0;
    }
    out.?.* = t;
    return 1;
}
pub export fn coherent_frame_get(out: ?*Token, phases: u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (out != null and mainNow() and active) {
        const token = current;
        if (valid(&token, phases)) {
            out.?.* = token;
            return @intFromBool(valid(&token, phases));
        }
    }
    return 0;
}
pub export fn coherent_frame_set_phase(token: ?*const Token, value: c_int) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    if (value < 1 or value > 5 or @as(u32, @intCast(value)) < phase or !valid(token, 0x3e)) return 0;
    phase = @intCast(value);
    return @intFromBool(valid(token, @as(u32, 1) << @as(u5, @intCast(value))));
}
pub export fn coherent_frame_close(token: ?*const Token) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    // Closing after unwind must not dereference an expired owner or frame.
    if (!mainNow() or !active or token == null or !std.meta.eql(token.?.*, current)) return 0;
    active = false;
    phase = 0;
    return 1;
}
