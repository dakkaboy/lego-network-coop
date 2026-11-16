const std = @import("std");
const win = @import("win32.zig");
const o = @import("owner.zig");
const fence = @import("frame_fence.zig");
const m = @import("mapping_types.zig");
const mapping = @import("mapping_observer.zig");
const base = @import("mapping_test_fixture.zig");
const check = @import("native_test_support.zig").check;
pub const panic = @import("safety.zig").panic;
pub const mapping_test_api = true;
export var clonewars_zig_safety_address: usize = 0;
export var clonewars_zig_safety_message: [256]u8 = @splat(0);
export var native_in_fx: [512]u8 align(16) = @splat(0);
export var final_fx: [512]u8 align(16) = @splat(0);
export var expected_out_fx: [512]u8 align(16) = @splat(0);
export var native_in_regs: [9]u32 = @splat(0);
export var final_regs: [9]u32 = @splat(0);
export var native_in_error: u32 = 0;
export var final_error: u32 = 0;
export var return_value: u32 = 0;
export var test_actor: u32 = 0;
export var expected_return_esp: u32 = 0;
export var expected_out_regs: [9]u32 = @splat(0);
export var expected_arg0: u32 = 0;
export var expected_arg1: u32 = 0;
export var test_entry: usize = 0;
export const default_mxcsr: u32 = 0x1f80;
export const in_mxcsr: u32 = 0x3f80;
export const out_mxcsr: u32 = 0x5f80;
export const in_cw: u16 = 0x77f;
export const out_cw: u16 = 0xb7f;
export const xmm_values: [32]u32 align(16) = blk: {
    var values: [32]u32 = undefined;
    for (&values, 1..) |*word, i| word.* = i;
    break :blk values;
};
var bridge_calls: u32 = 0;
extern fn native_a() void;
extern fn invoke_record() void;
pub export fn native_effect() void {
    bridge_calls += 1;
    check(@src(), win.load(u32, native_in_regs[3] + 8) == expected_arg0 and win.load(u32, native_in_regs[3] + 12) == expected_arg1);
    check(@src(), native_in_error == 0x12345678 and std.mem.readInt(u16, native_in_fx[0..2], .little) == in_cw and std.mem.readInt(u32, native_in_fx[24..28], .little) == in_mxcsr and native_in_fx[4] == 255);
    for (0..8) |i| check(@src(), std.mem.eql(u8, native_in_fx[160 + i * 16 ..][0..16], std.mem.sliceAsBytes(xmm_values[28 - i * 4 ..][0..4])));
    const expected = [_]u32{ 0x10101010, 0x20202020, 0x30303030, 0, 0x40404040, 0x50505050, 0x60606060, 0x70707070 };
    for (0..8) |i| if (i != 3) check(@src(), native_in_regs[i] == expected[i]);
    check(@src(), native_in_regs[8] & 0xcd5 == 0xed7 & 0xcd5);
    win.SetLastError(0xbad);
    asm volatile ("fninit; fldpi; pxor %%xmm0,%%xmm0" ::: .{ .xmm0 = true });
}
fn contextRoot(_: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), fence.coherent_frame_set_phase(&base.token, 2) != 0);
    const entries = [_]usize{ @intFromPtr(&base.user_mapping_mapper_entry), @intFromPtr(&base.user_mapping_setter_entry), @intFromPtr(&base.user_mapping_reset_all_entry), @intFromPtr(&base.user_mapping_reset_01_entry), @intFromPtr(&base.user_mapping_initializer_entry), @intFromPtr(&base.user_mapping_user0_a_entry), @intFromPtr(&base.user_mapping_user0_b_entry), @intFromPtr(&base.user_mapping_poller_entry) };
    for (0..100) |n| {
        const site = n % 8;
        test_entry = entries[site];
        expected_arg0 = @intFromBool(site == 0 or site == 1 or site == 3);
        expected_arg1 = if (site < 2) 13 else 0;
        return_value = switch (n % 3) {
            0 => 0,
            1 => 1,
            else => 0x89abcdef,
        };
        invoke_record();
        asm volatile ("cld" ::: .{ .cc = true });
        const expected = [_]u32{ 0x11111111, 0x22222222, 0x33333333, 0, 0x44444444, 0x55555555, 0x66666666, return_value };
        for (0..8) |i| if (i != 3) check(@src(), final_regs[i] == expected[i]);
        check(@src(), final_regs[8] & 0xcd5 == 0xed7 & 0xcd5 and final_regs[3] == expected_return_esp - 4);
        for (0..8) |i| check(@src(), std.mem.eql(u8, final_fx[32 + 16 * i ..][0..10], expected_out_fx[32 + 16 * i ..][0..10]));
        check(@src(), final_error == 0x76543210 and std.mem.readInt(u16, final_fx[0..2], .little) == out_cw and std.mem.readInt(u32, final_fx[24..28], .little) == out_mxcsr and final_fx[4] == 255);
        for (0..8) |i| check(@src(), std.mem.eql(u8, final_fx[160 + i * 16 ..][0..16], std.mem.sliceAsBytes(xmm_values[4 * i ..][0..4])));
        for (1..8) |i| check(@src(), std.mem.eql(u8, native_in_fx[32..42], native_in_fx[32 + 16 * i ..][0..10]));
    }
    return 1;
}
pub export fn run_mapping_fixture(_: u32) i32 {
    base.table = @ptrFromInt(base.allocate(4096));
    const c: m.Config = .{ .version = 2, .main_thread = win.GetCurrentThreadId(), .native_table = @intFromPtr(base.table), .native_owners = @intFromPtr(&base.owners), .original_source_valid = base.sourceValid, .targets = @splat(@intFromPtr(&native_a)) };
    check(@src(), mapping.user_mapping_configure(&c) != 0 and mapping.user_mapping_binding_ready(127) != 0 and mapping.user_mapping_enable() != 0 and fence.coherent_frame_register_main() != 0);
    const cb: o.Callbacks = .{ .version = 1, .begin = base.begin, .end = base.end, .reject = base.reject };
    check(@src(), o.native_owner_configure(@intFromPtr(&contextRoot), &cb) != 0 and base.native_owner_entry(0) == 1);
    check(@src(), bridge_calls == 100 and o.native_owner_current() == null);
    return 0;
}
comptime {
    _ = @import("mapping_fixture_runtime.zig");
    _ = @import("mapping_fixture_stubs.zig");
}

comptime {
    asm (
        \\.text
        \\.globl _native_a
        \\_native_a:
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
        \\ pushfl
        \\ pushal
        \\ fxsave _expected_out_fx
        \\ movl %esp,%esi
        \\ movl $_expected_out_regs,%edi
        \\ movl $9,%ecx
        \\ cld
        \\ rep movsl
        \\ popal
        \\ popfl
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
        \\ pushl $13
        \\ pushl $1
        \\ pushl $0xED7
        \\ popfl
        \\ movl %esp,_expected_return_esp
        \\ call *_test_entry
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
        \\ addl $44,%esp
        \\ popal
        \\ popfl
        \\ ret
        \\
    );
}
