const std = @import("std");
const s = @import("constructor_query_state.zig");
const t = s.t;
const win = s.win;
const obs = @import("observation.zig");
pub export var constructor_query_success: usize = 0x8c89e2;
pub export var constructor_query_miss: usize = 0x8c8a8b;
var patched = false;
fn copy(out: anytype, pointer: usize) void {
    @memcpy(std.mem.asBytes(out), @as([*]const u8, @ptrFromInt(pointer))[0..@sizeOf(@TypeOf(out.*))]);
}
pub export fn constructor_query_checkpoint(saved: [*]const u32, fx: [*]const u8) void {
    if (s.clonewars_constructor_query_enabled == 0) return;
    var record = std.mem.zeroes(t.Record);
    record.version = 3;
    var binding: s.Binding = undefined;
    if (!s.acquire(&binding, &record)) return;
    s.stamp(&record.qpc_before);
    record.clock_before = s.clock();
    record.native_ebp = saved[2];
    record.native_esp = @intFromPtr(saved) + 36;
    record.native_esi = saved[1];
    record.native_eax = saved[7];
    record.native_control_word = std.mem.bytesToValue(u16, fx[0..2]);
    record.native_mxcsr = std.mem.bytesToValue(u32, fx[24..28]);
    const caller_esi = @intFromPtr(saved) + 40;
    if (s.readable(caller_esi, 4)) {
        record.caller_esi_raw = win.load(u32, caller_esi);
        record.valid_mask |= t.CQ_CALLER_ESI;
    }
    const frame = record.native_ebp;
    if (s.readable(frame, 0x28)) {
        record.query_caller = win.load(u32, frame + 4);
        copy(&record.native_arguments, frame + 8);
        record.valid_mask |= t.CQ_FRAME_ARGS;
        if (record.query_caller == 0x81e26e) {
            record.parent_ebp = win.load(u32, frame);
            const parent = record.parent_ebp;
            if (s.readable(parent, 8)) {
                record.parent_caller = win.load(u32, parent + 4);
                if (record.parent_caller == 0x85aef8 or record.parent_caller == 0x85b029) record.valid_mask |= t.CQ_PARENT;
            }
        }
        const start = record.native_arguments[0];
        const displacement = record.native_arguments[1];
        if (s.readable(start, 12)) {
            copy(&record.start_raw, start);
            record.valid_mask |= t.CQ_START;
        }
        if (s.readable(displacement, 12)) {
            copy(&record.displacement_raw, displacement);
            record.valid_mask |= t.CQ_DISPLACEMENT;
        }
    }
    const query = @intFromPtr(saved) + 36 + 0x30;
    if (s.readable(query, 52)) {
        copy(&record.query_s30_raw, query);
        record.valid_mask |= t.CQ_QUERY;
    }
    const global = s.address(0xfb9770);
    if (s.readable(global, 0xb0)) {
        inline for (.{ .{ 0, "result_vtable" }, .{ 0x10, "fraction_raw" }, .{ 0x60, "candidate_context_local" }, .{ 0x78, "selected_descriptor_local" }, .{ 0x7c, "reported_shape_raw" } }) |field| {
            @field(record, field[1]) = win.load(u32, global + field[0]);
        }
        record.category_raw = win.load(u8, global + 0x80);
        record.subtype_raw = win.load(u8, global + 0x81);
        record.mask_word_raw = win.load(u16, global + 0x82);
        copy(&record.point_raw, global + 0x90);
        copy(&record.normal_raw, global + 0xa0);
        record.valid_mask |= t.CQ_GLOBAL;
    }
    if (record.native_eax & 255 != 0 and record.valid_mask & t.CQ_GLOBAL != 0 and s.bindingLive(&binding)) {
        const descriptor = record.selected_descriptor_local;
        if (s.readable(descriptor, 128)) {
            copy(&record.selected_descriptor_raw, descriptor);
            record.valid_mask |= t.CQ_DESCRIPTOR;
            record.root_shape_local = win.load(u32, descriptor + 0x24);
            const shape = record.root_shape_local;
            if (s.readable(shape, 64)) {
                copy(&record.root_shape_header_raw, shape);
                record.root_shape_vtable = win.load(u32, shape);
                record.valid_mask |= t.CQ_ROOT;
                const vtable = record.root_shape_vtable;
                if (s.readable(vtable + 0x34, 12)) {
                    record.root_radius_target_local = win.load(u32, vtable + 0x34);
                    record.root_ray_target_local = win.load(u32, vtable + 0x3c);
                    record.valid_mask |= t.CQ_ROOT_VTABLE;
                }
            }
        }
    }
    @import("constructor_query_identity.zig").capture(&binding, &record);
    @import("constructor_query_source.zig").capture(&binding, &record);
    record.clock_after = s.clock();
    s.stamp(&record.qpc_after);
    if (record.collider_identity.status != 0 and record.clock_after != record.collider_identity.clock_after) {
        record.collider_identity.status = 0;
        record.collider_identity.valid_mask &= 0x7f;
        record.collider_identity.reason = t.CCI_CHANGED;
    }
    if (record.source_witness.status != 0 and record.clock_after != record.source_witness.clock_after) {
        record.source_witness.status = 0;
        record.source_witness.valid_mask &= ~@as(u32, 8192);
        record.source_witness.reason = t.CQS_CLOCK_CHANGED;
    }
    if (s.clonewars_constructor_query_enabled == 0 or !s.bindingLive(&binding)) {
        s.note(6);
        return;
    }
    record.id = obs.increment(&s.clonewars_constructor_query_count);
    obs.publish(&s.clonewars_constructor_query_records[(record.id - 1) % 2048], &record);
}
pub extern fn constructor_query_post() void;
pub export fn constructor_query_install() c_int {
    if (s.api.projectiles_constructor_hooks_ready() == 0) {
        s.clonewars_constructor_query_installed = 0;
        return 0;
    }
    const site = s.address(0x8c89da);
    if (!patched) {
        const patch = @import("hook_transaction.zig").Patch{ .address = site, .expected = "\x84\xc0\x0f\x84\xa9\x00\x00\x00", .target = @intFromPtr(&constructor_query_post) };
        if (!@import("hook_transaction.zig").apply(&.{patch})) return 0;
        patched = true;
    }
    if (!s.readable(site, 8) or win.load(u8, site) != 0xe9 or site +% 5 +% win.load(u32, site + 1) != @intFromPtr(&constructor_query_post) or win.load(u8, site + 5) != 0x90 or win.load(u8, site + 6) != 0x90 or win.load(u8, site + 7) != 0x90) {
        s.clonewars_constructor_query_installed = 0;
        return 0;
    }
    s.clonewars_constructor_query_installed = 3;
    return 1;
}
comptime {
    asm (
        \\.text
        \\.globl _constructor_query_post
        \\_constructor_query_post:
        \\pushfl
        \\cmpl $0,_clonewars_constructor_query_enabled
        \\je 1f
        \\cmpl $0,_clonewars_constructor_query_active_scopes
        \\je 2f
        \\popfl
        \\pushfl
        \\pushal
        \\movl %esp,%eax
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %eax,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\call _GetLastError@0
        \\movl %eax,524(%esp)
        \\movl %esp,%ecx
        \\movl 512(%esp),%edx
        \\subl $8,%esp
        \\pushl %ecx
        \\pushl %edx
        \\call _constructor_query_checkpoint
        \\addl $16,%esp
        \\cld
        \\pushl 524(%esp)
        \\call _SetLastError@4
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\jmp 3f
        \\2: lock incl _clonewars_constructor_query_debug
        \\1: popfl
        \\3: testb %al,%al
        \\jz 4f
        \\jmp *_constructor_query_success
        \\4: jmp *_constructor_query_miss
    );
}
