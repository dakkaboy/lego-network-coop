const std = @import("std");
const win = @import("win32.zig");
const types = @import("cohort_types.zig");
const equal = @import("validation.zig").equal;
const Token = types.Token;
const Lease = types.Lease;
extern fn coherent_frame_valid(*const Token, u32) c_int;
pub const Binding = struct {
    lease: Lease = std.mem.zeroes(Lease),
    serial: u32 = 0,
    initialized: u32 = 0,
    bound: bool = false,
    retired_valid: bool = false,
    retired: Token = std.mem.zeroes(Token),
    pub fn same(self: *const Binding, lease: ?*const Lease) bool {
        const l = lease orelse return false;
        return self.bound and self.lease.serial == l.serial and equal(&self.lease.cohort, &l.cohort);
    }
    pub fn get(self: *const Binding, output: ?*Lease) bool {
        const saved = win.GetLastError();
        defer win.SetLastError(saved);
        if (output == null or !self.bound or self.lease.cohort.thread != win.GetCurrentThreadId()) return false;
        output.?.* = self.lease;
        return true;
    }
    pub fn live(self: *const Binding, lease: ?*const Lease) bool {
        return self.same(lease) and coherent_frame_valid(&lease.?.cohort, 14) != 0;
    }
    pub fn cancelled(self: *const Binding, lease: ?*const Lease) bool {
        return !self.same(lease) or coherent_frame_valid(&lease.?.cohort, 0x3e) == 0;
    }
    pub fn bind(self: *Binding, original: ?*const Token) bool {
        const token = original orelse return false;
        if (self.bound or self.serial == std.math.maxInt(u32) or (self.retired_valid and equal(token, &self.retired)) or coherent_frame_valid(token, 2) == 0) return false;
        self.serial += 1;
        self.lease = .{ .serial = self.serial, .cohort = token.* };
        self.initialized = 0;
        self.bound = true;
        return true;
    }
    pub fn begin(self: *Binding, frame: usize) bool {
        if (!self.bound or self.initialized == self.lease.serial or self.lease.cohort.frame != frame or coherent_frame_valid(&self.lease.cohort, 2) == 0) return false;
        self.initialized = self.lease.serial;
        return self.live(&self.lease);
    }
    pub fn detach(self: *Binding, lease: ?*const Lease) bool {
        const saved = win.GetLastError();
        defer win.SetLastError(saved);
        if (lease == null or lease.?.cohort.thread != win.GetCurrentThreadId() or !self.same(lease)) return false;
        self.retired = self.lease.cohort;
        self.retired_valid = true;
        self.bound = false;
        return true;
    }
};
