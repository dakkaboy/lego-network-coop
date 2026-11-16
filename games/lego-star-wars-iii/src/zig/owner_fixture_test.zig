const std = @import("std");
const win = @import("win32.zig");
const o = @import("owner.zig");
const support = @import("native_test_support.zig");
const check = support.check;
pub const owner_test_api = true;
pub const panic = @import("safety.zig").panic;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var native_in_fx: [512]u8 align(16) = @splat(0);
export var final_fx: [512]u8 align(16) = @splat(0);
var expected_fx: [512]u8 align(16) = @splat(0);
export var native_in_regs: [9]u32 = @splat(0);
export var final_regs: [9]u32 = @splat(0);
var expected_regs: [9]u32 = @splat(0);
export var native_in_error: u32 = 0;
export var final_error: u32 = 0;
export var observed_target: u32 = 0;
var expected_esp: u32 = 0;
export var return_value: u32 = 0;
export const default_mxcsr: u32 = 0x1f80;
export const in_mxcsr: u32 = 0x3f80;
export const out_mxcsr: u32 = 0x5f80;
export const in_cw: u16 = 0x77f;
export const out_cw: u16 = 0xb7f;
export const xmm_values: [32]u32 align(16) = blk: {
    var v: [32]u32 = undefined;
    for (&v, 1..) |*word, i| word.* = i;
    break :blk v;
};
var begins: i32 = 0;
var ends: i32 = 0;
var calls: i32 = 0;
var rejections: i32 = 0;
var direct_rejected: i32 = 0;
var nested: u32 = 0;
var fault_mode = false;
var cancel_mode: u32 = 0;
var begin_fault = false;
var deep_mode = false;
var scenario: u32 = 0;
var target_id: u32 = 0;
var link_raise_mode = false;
var a_ready: usize = 0;
var b_ready: usize = 0;
var a_done: usize = 0;
var test_key: u32 = 0;
var stale: ?*o.Scope = null;
var inaccessible: ?*o.Scope = null;
var stale_nonce: u32 = 0;
var exception_end_error: u32 = 0;
var observed_handler_error: u32 = 0;
threadlocal var worker_id: u32 = 0;
var worker_scopes: [3]?*o.Scope = @splat(null);
extern fn invoke_record() void;
extern fn native_a() void;
extern fn native_b() void;
extern fn direct_probe() void;
extern fn native_owner_test_fail_set(u32) void;
extern fn native_owner_test_fail_get(u32) void;
extern fn native_owner_test_nonce(u32) void;
extern fn native_owner_test_raise_after_set(u32) void;
extern "kernel32" fn GetEnvironmentVariableA([*:0]const u8, [*]u8, u32) callconv(.winapi) u32;
extern "kernel32" fn CreateEventA(usize, i32, i32, ?[*:0]const u8) callconv(.winapi) usize;
extern "kernel32" fn SetEvent(usize) callconv(.winapi) i32;
extern "kernel32" fn WaitForSingleObject(usize, u32) callconv(.winapi) u32;
extern "kernel32" fn WaitForMultipleObjects(u32, [*]const usize, i32, u32) callconv(.winapi) u32;
extern "kernel32" fn CreateThread(usize, usize, *const fn (usize) callconv(.winapi) u32, usize, u32, ?*u32) callconv(.winapi) usize;
extern "kernel32" fn GetExitCodeThread(usize, *u32) callconv(.winapi) i32;
extern "kernel32" fn TlsFree(u32) callconv(.winapi) i32;
fn increment(value: *i32) void {
    _ = @atomicRmw(i32, value, .Add, 1, .seq_cst);
}
fn fxEqual(a: *const [512]u8, b: *const [512]u8) bool {
    if (!std.mem.eql(u8, a[0..8], b[0..8]) or !std.mem.eql(u8, a[24..28], b[24..28]) or !std.mem.eql(u8, a[160..288], b[160..288])) return false;
    for (0..8) |i| if (!std.mem.eql(u8, a[32 + 16 * i ..][0..10], b[32 + 16 * i ..][0..10])) return false;
    return true;
}
fn clobber() void {
    win.SetLastError(0xbad);
    asm volatile ("fninit; fldz; fldz; fldz; fldz; fldz; fldz; fldz; fldz; pxor %%xmm0,%%xmm0; pxor %%xmm7,%%xmm7; cld" ::: .{ .xmm0 = true, .xmm7 = true, .cc = true });
}
fn begin(s: *o.Scope, input: *const o.Input, storage: ?*anyopaque) callconv(.c) void {
    const b: *[64]u8 = @ptrCast(storage.?);
    for (b) |byte| check(@src(), byte == 0);
    b[0] = 0x43;
    b[63] = @intCast(worker_id);
    increment(&begins);
    check(@src(), o.native_owner_current() == s);
    check(@src(), o.native_owner_scope_nonce(inaccessible) == 0 and o.native_owner_scope_usable(inaccessible) == 0 and o.native_owner_scope_valid(inaccessible, 1) == 0 and o.native_owner_scope_delegate_esp(inaccessible, 1) == 0);
    check(@src(), input.fx == &s.in_fx and input.regs == &s.in_regs and o.native_owner_scope_nonce(s) == s.nonce);
    check(@src(), s.delegate_active == 0 and o.native_owner_scope_delegate_esp(s, s.nonce) == 0);
    if (s.parent) |parent| check(@src(), o.native_owner_scope_valid(parent, o.native_owner_scope_nonce(parent)) == 0 and o.native_owner_scope_delegate_esp(parent, parent.nonce) == 0);
    check(@src(), o.native_owner_scope_usable(s) == @intFromBool(s.depth <= 8) and o.native_owner_scope_valid(s, s.nonce) == @intFromBool(s.depth <= 8));
    if (worker_id != 0) {
        worker_scopes[worker_id] = s;
        check(@src(), win.TlsGetValue(test_key) == worker_id);
        if (worker_id == 1) {
            check(@src(), SetEvent(a_ready) != 0);
            check(@src(), WaitForSingleObject(b_ready, 5000) == 0);
        } else {
            check(@src(), SetEvent(b_ready) != 0);
            check(@src(), WaitForSingleObject(a_done, 5000) == 0);
        }
        check(@src(), o.native_owner_current() == s and o.native_owner_scope_valid(s, s.nonce) != 0);
        const other = worker_scopes[if (worker_id == 1) @as(usize, 2) else 1];
        check(@src(), other != null and other != s and o.native_owner_scope_nonce(other) == 0 and o.native_owner_scope_usable(other) == 0 and o.native_owner_scope_valid(other, 1) == 0 and o.native_owner_scope_delegate_esp(other, 1) == 0);
    }
    if (begin_fault) win.RaiseException(0xe0011234, 0, 0, null);
    if (scenario == 7) {
        const before_reject = rejections;
        native_owner_test_fail_get(1);
        win.SetLastError(0x73737373);
        check(@src(), o.native_owner_current() == null and win.GetLastError() == 0x73737373 and rejections == before_reject);
    }
    clobber();
}
fn end(s: *o.Scope, exit: i32, storage: ?*anyopaque) callconv(.c) void {
    var helper_fx: [512]u8 align(16) = undefined;
    asm volatile ("fxsave (%[out])"
        :
        : [out] "r" (&helper_fx),
        : .{ .memory = true });
    check(@src(), helper_fx[0] == 0x7f and helper_fx[1] == 3 and helper_fx[4] == 0 and std.mem.readInt(u32, helper_fx[24..28], .little) == 0x1f80);
    const b: *[64]u8 = @ptrCast(storage.?);
    check(@src(), b[0] == 0x43 and b[1] == 0 and b[63] == worker_id);
    b[1] = 1;
    check(@src(), s.delegate_active == 0 and o.native_owner_scope_delegate_esp(s, s.nonce) == 0 and (o.native_owner_current() == s or scenario != 0));
    if (exit == 0) {
        expected_fx = s.out_fx;
        expected_regs = s.out_regs;
        expected_esp = s.entry_esp;
    } else exception_end_error = win.GetLastError();
    stale = s;
    stale_nonce = s.nonce;
    increment(&ends);
    clobber();
}
fn reject(s: ?*o.Scope, parent: ?*o.Scope, why: i32, storage: ?*anyopaque) callconv(.c) void {
    increment(&rejections);
    if (s == null) {
        check(@src(), parent == null and storage == null and why == 1 and o.native_owner_current() == null);
        clobber();
        return;
    }
    check(@src(), o.native_owner_scope_valid(s, s.?.nonce) == 0 and o.native_owner_scope_delegate_esp(s, s.?.nonce) == 0);
    if (parent) |p| check(@src(), o.native_owner_scope_valid(p, p.nonce) == 0);
    if (why == 0) check(@src(), o.native_owner_current() == s and o.native_owner_scope_usable(s) == 0) else check(@src(), o.native_owner_current() == null);
    clobber();
}
pub export fn direct_stack_check(actual_entry: u32) void {
    const s = o.native_owner_current();
    check(@src(), s != null and s.?.usable != 0);
    const anchor = o.native_owner_scope_delegate_esp(s, s.?.nonce);
    check(@src(), anchor != 0 and anchor != actual_entry);
    increment(&direct_rejected);
}
pub export fn native_effect() void {
    increment(&calls);
    const s = o.native_owner_current();
    if (s) |scope| {
        check(@src(), fxEqual(&scope.in_fx, &native_in_fx));
        for (0..9) |i| if (i != 3) check(@src(), scope.in_regs[i] == native_in_regs[i]);
        check(@src(), native_in_error == scope.in_error);
        const actual_entry = native_in_regs[3] + 4;
        check(@src(), scope.delegate_active != 0 and scope.delegate_esp == actual_entry and actual_entry != scope.entry_esp);
        win.SetLastError(0x64646464);
        check(@src(), o.native_owner_scope_delegate_esp(scope, scope.nonce) == (if (scope.usable != 0) actual_entry else 0) and win.GetLastError() == 0x64646464);
        if (scenario == 0 and scope.usable != 0) direct_probe();
    } else {
        check(@src(), scenario != 0);
        if (scenario == 7) check(@src(), rejections > 0);
    }
    check(@src(), observed_target == target_id);
    if (link_raise_mode and s != null and s.?.depth == 1) {
        native_owner_test_raise_after_set(1);
        invoke_record();
    }
    if (s != null and s.?.depth == 1 and scenario >= 4) {
        const before_reject = rejections;
        const before_begin = begins;
        native_owner_test_fail_get(1);
        if (scenario != 5) {
            win.SetLastError(0x71717171);
            check(@src(), o.native_owner_current() == null and win.GetLastError() == 0x71717171);
            check(@src(), o.native_owner_scope_valid(s, s.?.nonce) == 0 and rejections == before_reject);
        }
        if (scenario == 6) {
            win.SetLastError(0x72727272);
            check(@src(), o.native_owner_poll_fault() == 1 and win.GetLastError() == 0x72727272);
            check(@src(), rejections == before_reject + 1 and o.native_owner_poll_fault() == 0);
        } else invoke_record();
        check(@src(), begins == before_begin and o.native_owner_current() == null);
    }
    if (deep_mode and s != null and s.?.depth < 10) invoke_record();
    if (nested != 0 and s != null and s.?.depth == 1) {
        const parent_entry = s.?.delegate_esp;
        nested = 0;
        invoke_record();
        check(@src(), o.native_owner_scope_delegate_esp(s, s.?.nonce) == (if (scenario != 0) @as(u32, 0) else parent_entry));
    }
    if (cancel_mode != 0 and s != null) s.?.storage[2] = 1;
    if (fault_mode) win.RaiseException(0xe0011234, 0, 0, null);
}
fn checkFinal(value: u32) void {
    check(@src(), fxEqual(&expected_fx, &final_fx));
    for (0..8) |i| if (i != 3) check(@src(), final_regs[i] == expected_regs[i]);
    check(@src(), final_regs[8] & 0xcd5 == expected_regs[8] & 0xcd5);
    check(@src(), final_regs[7] == value and final_error == 0x76543210 and final_regs[3] == expected_esp);
}
fn normal(nesting: u32, cancel: u32, value: u32) void {
    const b = begins;
    const e = ends;
    const c = calls;
    return_value = value;
    nested = nesting;
    cancel_mode = cancel;
    invoke_record();
    check(@src(), begins - b == 1 + nesting and ends - e == 1 + nesting and calls - c == 1 + nesting and o.native_owner_current() == null);
    checkFinal(value);
    check(@src(), o.native_owner_scope_valid(stale, stale_nonce) == 0 and o.native_owner_scope_nonce(stale) == 0 and o.native_owner_scope_usable(stale) == 0 and o.native_owner_scope_delegate_esp(stale, stale_nonce) == 0);
}
fn worker(arg: usize) callconv(.winapi) u32 {
    worker_id = @intCast(arg);
    check(@src(), win.TlsSetValue(test_key, arg) != 0);
    invoke_record();
    checkFinal(return_value);
    check(@src(), o.native_owner_current() == null);
    if (worker_id == 1) check(@src(), SetEvent(a_done) != 0);
    return 0;
}
fn throwing(_: usize) callconv(.c) i32 {
    invoke_record();
    return 0;
}
fn exceptionProbe() bool {
    const result = support.exceptionResult(0, throwing);
    observed_handler_error = result.last_error;
    return result.code == 0xe0011234;
}
pub export fn run_fixture() i32 {
    var value: [16]u8 = @splat(0);
    _ = GetEnvironmentVariableA("OWNER_TARGET", &value, value.len);
    target_id = if (value[0] == 'B') 2 else 1;
    @memset(&value, 0);
    const length = GetEnvironmentVariableA("OWNER_SCENARIO", &value, value.len);
    check(@src(), length < value.len);
    scenario = std.fmt.parseInt(u32, value[0..length], 10) catch 0;
    const cb: o.Callbacks = .{ .version = 1, .begin = begin, .end = end, .reject = reject };
    check(@src(), @intFromPtr(&native_a) != @intFromPtr(&native_b));
    check(@src(), o.native_owner_configure(if (target_id == 1) @intFromPtr(&native_a) else @intFromPtr(&native_b), &cb) != 0);
    check(@src(), o.native_owner_configure(@intFromPtr(&native_a), &cb) == 0);
    const bad = win.VirtualAlloc(0, 4096, 0x2000, 1);
    check(@src(), bad != 0);
    inaccessible = @ptrFromInt(bad);
    defer {
        check(@src(), win.VirtualFree(bad, 0, 0x8000) != 0);
        inaccessible = null;
    }
    check(@src(), o.native_owner_scope_nonce(inaccessible) == 0 and o.native_owner_scope_usable(inaccessible) == 0 and o.native_owner_scope_valid(inaccessible, 1) == 0 and o.native_owner_scope_delegate_esp(inaccessible, 1) == 0);
    if (scenario != 0) {
        return_value = 0x81234567;
        switch (scenario) {
            1 => {
                native_owner_test_fail_set(3);
                nested = 1;
            },
            2 => {
                native_owner_test_fail_set(2);
                nested = 1;
            },
            3 => native_owner_test_nonce(0xffffffff),
            else => {},
        }
        const expected: i32 = if (scenario == 3 or scenario == 6 or scenario == 7) 1 else 2;
        invoke_record();
        check(@src(), o.native_owner_current() == null and calls == expected and rejections >= 1);
        const r = rejections;
        invoke_record();
        check(@src(), o.native_owner_current() == null and calls == expected + 1 and rejections > r);
        return 0;
    }
    for (0..100) |_| {
        normal(0, 0, 0);
        normal(0, 0, 1);
        normal(0, 0, 0x8badf00d);
        normal(1, 0, 0x81234567);
        normal(0, 1, 0x456789ab);
    }
    cancel_mode = 0;
    fault_mode = true;
    var c = calls;
    check(@src(), exceptionProbe());
    fault_mode = false;
    check(@src(), calls == c + 1 and o.native_owner_current() == null and observed_handler_error == exception_end_error);
    nested = 1;
    fault_mode = true;
    c = calls;
    check(@src(), exceptionProbe());
    fault_mode = false;
    check(@src(), calls == c + 2 and o.native_owner_current() == null and observed_handler_error == exception_end_error);
    begin_fault = true;
    c = calls;
    check(@src(), exceptionProbe());
    begin_fault = false;
    check(@src(), calls == c and o.native_owner_current() == null and observed_handler_error == exception_end_error);
    var before_link_begin = begins;
    var before_link_end = ends;
    c = calls;
    native_owner_test_raise_after_set(1);
    check(@src(), exceptionProbe());
    check(@src(), calls == c and begins == before_link_begin and ends == before_link_end and o.native_owner_current() == null);
    link_raise_mode = true;
    c = calls;
    before_link_begin = begins;
    before_link_end = ends;
    check(@src(), exceptionProbe());
    link_raise_mode = false;
    check(@src(), calls == c + 1 and begins == before_link_begin + 1 and ends == before_link_end + 1 and o.native_owner_current() == null);
    deep_mode = true;
    c = calls;
    invoke_record();
    deep_mode = false;
    check(@src(), calls == c + 10 and rejections == 2 and o.native_owner_current() == null);
    test_key = win.TlsAlloc();
    check(@src(), test_key != 0xffffffff);
    a_ready = CreateEventA(0, 1, 0, null);
    b_ready = CreateEventA(0, 1, 0, null);
    a_done = CreateEventA(0, 1, 0, null);
    check(@src(), a_ready != 0 and b_ready != 0 and a_done != 0);
    return_value = 0x813579bd;
    const threads = [_]usize{ CreateThread(0, 0, worker, 1, 0, null), CreateThread(0, 0, worker, 2, 0, null) };
    check(@src(), threads[0] != 0 and threads[1] != 0 and WaitForMultipleObjects(2, &threads, 1, 10000) == 0);
    for (threads) |thread| {
        var exit: u32 = 0;
        check(@src(), GetExitCodeThread(thread, &exit) != 0 and exit == 0);
        check(@src(), win.CloseHandle(thread) != 0);
    }
    check(@src(), win.CloseHandle(a_ready) != 0 and win.CloseHandle(b_ready) != 0 and win.CloseHandle(a_done) != 0 and TlsFree(test_key) != 0);
    check(@src(), o.native_owner_current() == null and begins == ends and direct_rejected > 0);
    return 0;
}
var external_calls: i32 = 0;
var external_begins: i32 = 0;
var external_ends: i32 = 0;
pub export fn expected_exception_error() u32 {
    return exception_end_error;
}
pub export fn raise_external() i32 {
    external_calls = calls;
    external_begins = begins;
    external_ends = ends;
    fault_mode = true;
    nested = 1;
    begin_fault = false;
    cancel_mode = 0;
    invoke_record();
    return -1;
}
pub export fn verify_external() i32 {
    fault_mode = false;
    check(@src(), calls == external_calls + 2 and begins == external_begins + 2 and ends == external_ends + 2 and o.native_owner_current() == null);
    normal(0, 0, 0x1234);
    return 0;
}
comptime {
    _ = @import("owner_bridge.zig");
    _ = @import("seh_owner.zig");
}

comptime {
    asm (
        \\.text
        \\.globl _direct_probe
        \\_direct_probe:
        \\ pushfl
        \\ pushal
        \\ leal 36(%esp),%eax
        \\ pushl %eax
        \\ call _direct_stack_check
        \\ addl $4,%esp
        \\ popal
        \\ popfl
        \\ ret
        \\.globl _native_a
        \\_native_a:
        \\ movl $1,_observed_target
        \\ jmp _native_body
        \\.globl _native_b
        \\_native_b:
        \\ movl $2,_observed_target
        \\ jmp _native_body
        \\.globl _native_body
        \\_native_body:
        \\ pushfl
        \\ pushal
        \\ movl %esp,%esi
        \\ movl $_native_in_regs,%edi
        \\ movl $9,%ecx
        \\ fxsave _native_in_fx
        \\ cld
        \\ rep movsl
        \\ movl %fs:52,%eax
        \\ movl %eax,_native_in_error
        \\ fninit
        \\ ldmxcsr _default_mxcsr
        \\ call _native_effect
        \\ popal
        \\ popfl
        \\ fninit
        \\ fld1
        \\ fldpi
        \\ fldl2e
        \\ fldl2t
        \\ fldlg2
        \\ fldln2
        \\ fldz
        \\ fld1
        \\ fldcw _out_cw
        \\ ldmxcsr _out_mxcsr
        \\ movdqa _xmm_values,%xmm0
        \\ movdqa _xmm_values+16,%xmm1
        \\ movdqa _xmm_values+32,%xmm2
        \\ movdqa _xmm_values+48,%xmm3
        \\ movdqa _xmm_values+64,%xmm4
        \\ movdqa _xmm_values+80,%xmm5
        \\ movdqa _xmm_values+96,%xmm6
        \\ movdqa _xmm_values+112,%xmm7
        \\ movl $0x76543210,%fs:52
        \\ pushl $0xED7
        \\ popfl
        \\ movl $0x11111111,%edi
        \\ movl $0x22222222,%esi
        \\ movl $0x33333333,%ebp
        \\ movl $0x44444444,%ebx
        \\ movl $0x55555555,%edx
        \\ movl $0x66666666,%ecx
        \\ movl _return_value,%eax
        \\ ret
        \\
        \\.globl _invoke_record
        \\_invoke_record:
        \\ pushfl
        \\ pushal
        \\
        \\ fninit
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fld1
        \\ fldcw _in_cw
        \\ ldmxcsr _in_mxcsr
        \\ movdqa _xmm_values+112,%xmm0
        \\ movdqa _xmm_values+96,%xmm1
        \\ movdqa _xmm_values+80,%xmm2
        \\ movdqa _xmm_values+64,%xmm3
        \\ movdqa _xmm_values+48,%xmm4
        \\ movdqa _xmm_values+32,%xmm5
        \\ movdqa _xmm_values+16,%xmm6
        \\ movdqa _xmm_values,%xmm7
        \\ movl $0x12345678,%fs:52
        \\ movl $0x10101010,%edi
        \\ movl $0x20202020,%esi
        \\ movl $0x30303030,%ebp
        \\ movl $0x40404040,%ebx
        \\ movl $0x50505050,%edx
        \\ movl $0x60606060,%ecx
        \\ movl $0x70707070,%eax
        \\ pushl $0xED7
        \\ popfl
        \\ call _native_owner_entry
        \\ pushfl
        \\ pushal
        \\ fxsave _final_fx
        \\ movl %esp,%esi
        \\ movl $_final_regs,%edi
        \\ movl $9,%ecx
        \\ cld
        \\ rep movsl
        \\ movl %fs:52,%eax
        \\ movl %eax,_final_error
        \\ fninit
        \\ ldmxcsr _default_mxcsr
        \\ addl $36,%esp
        \\ popal
        \\ popfl
        \\ ret
        \\
    );
}
