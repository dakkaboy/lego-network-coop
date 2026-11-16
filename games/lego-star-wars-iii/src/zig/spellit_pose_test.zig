const std = @import("std");
const input = @import("spellit_input.zig");
const state = @import("spellit_hop_state.zig");
const bodies = @import("spellit_bodies.zig");
const types = @import("spellit_types.zig");
const p = @import("protocol.zig");
const Token = @import("cohort_types.zig").Token;
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".fixture") = @splat(0);
export var gizmo: [0x230]u8 = @splat(0);
var piece: [0x120]u8 = @splat(0);
var other_piece: [0x120]u8 = @splat(0);
var receiver: [0x184]u8 = @splat(0);
var alive = true;
var proof = true;
var mode: u32 = 0;
var calls: u32 = 0;
var faults: u32 = 0;
var originals: u32 = 0;
var selections: u32 = 0;
var enabled_calls: u32 = 0;
var expected_seed: u32 = 0;
var bodies_enabled = false;
var body_proof = true;
var body_mode: u32 = 0;
var body_applies: u32 = 0;
var local_body: types.State = std.mem.zeroes(types.State);
var canonical_body: types.State = std.mem.zeroes(types.State);
const authoritative: [3]f32 = .{ 340.76535, 44.27975, 47.423156 };
export fn coherent_frame_valid(token: *const Token, _: u32) c_int {
    return @intFromBool(alive and token.sequence == 44);
}
export fn coherent_frame_get(token: *Token, _: u32) c_int {
    token.* = std.mem.zeroes(Token);
    token.sequence = 44;
    return @intFromBool(alive);
}
export fn game_sync_native_fault(value: c_int) void {
    check(@src(), value == 15);
    faults += 1;
}
export fn constructor_lexical_seh(raw: usize, invoke: *const fn (usize) callconv(.c) usize, _: *const fn (usize) callconv(.c) void) usize {
    return invoke(raw);
}
export fn native_spellit_source_resolve(g: usize, out: *types.Source) c_int {
    out.* = std.mem.zeroes(types.Source);
    out.gizmo = g;
    out.key = .{ .name = .{ 1, 2, 3, 4 }, .gizmo_class = 0x8480ac, .gizmo_ordinal = 3 };
    if (bodies_enabled) {
        out.piece_count = 1;
        out.piece_head = @intFromPtr(&piece);
        out.piece_tail = out.piece_head;
    }
    return @intFromBool(g == @intFromPtr(&gizmo));
}
export fn native_spellit_source_revalidate(_: *const types.Source) c_int {
    return @intFromBool(proof);
}
export fn native_spellit_piece_resolve(_: *const types.Source, value: usize, out: *types.Piece) c_int {
    if (value != @intFromPtr(&piece)) return 0;
    out.* = std.mem.zeroes(types.Piece);
    out.piece = value;
    out.receiver = @intFromPtr(&receiver);
    out.key = .{ .resource = .{ 5, 6, 7, 8 }, .poi_name = .{ 9, 10, 11, 12 }, .poi_ordinal = 265, .poi_count = 672, .receiver_class = 0x820f64, .piece_ordinal = 8 };
    return 1;
}
export fn native_spellit_piece_revalidate(_: *const types.Source, _: *const types.Piece) c_int {
    return @intFromBool(proof);
}
export fn native_spellit_body_resolve(_: *const types.Source, value: usize, out: *types.Body) c_int {
    out.* = std.mem.zeroes(types.Body);
    out.piece = value;
    out.dynamics = @intFromPtr(&local_body);
    out.body_class = 0x869eac;
    out.key[0] = 123;
    return if (body_proof) 1 else -1;
}
export fn native_spellit_body_matches(_: *const types.Source, _: *const types.Body) c_int {
    return @intFromBool(body_proof);
}
export fn native_spellit_body_read(_: *const types.Source, _: *const types.Body, out: *types.State) c_int {
    out.* = local_body;
    return @intFromBool(body_proof);
}
export fn native_spellit_body_apply(_: *const types.Source, _: *const types.Body, value: *const types.State, guard: types.Live, context: usize) c_int {
    var control: u16 = 0;
    asm volatile ("fnstcw (%[cw])"
        :
        : [cw] "r" (&control),
        : .{ .memory = true });
    check(@src(), control == 0x7f and body_proof and guard(context) != 0);
    body_applies += 1;
    local_body = value.*;
    return 1;
}
export fn native_spellit_selection_snapshot(_: *const types.Source, count: *u32, key: *[4]u32) c_int {
    count.* = 0;
    key.* = .{ 1, 2, 3, 4 };
    return @intFromBool(proof);
}
fn selected() void {
    win.store(usize, @intFromPtr(&gizmo) + 0x21c, @intFromPtr(&piece));
}
export fn physics_world_input(choice: *p.SyncPhysicsChoice, _: *const Token) c_int {
    calls += 1;
    check(@src(), @import("physics_validation.zig").valid(choice));
    switch (choice.kind) {
        p.SYNC_PHYSICS_SPELLIT_RECEIVER_FLAGS, p.SYNC_PHYSICS_SPELLIT_ENABLED => {
            choice.payload.world.value = if (choice.kind == p.SYNC_PHYSICS_SPELLIT_ENABLED) 1 else 4;
            switch (mode) {
                1 => win.store(usize, @intFromPtr(&gizmo) + 0x21c, @intFromPtr(&other_piece)),
                2 => {
                    alive = false;
                },
                3 => {
                    proof = false;
                },
                else => {},
            }
            win.SetLastError(999);
            return if (mode == 4) -1 else 1;
        },
        p.SYNC_PHYSICS_SPELLIT_BODY_BASIS, p.SYNC_PHYSICS_SPELLIT_BODY_MOTION => {
            const part: usize = @intFromBool(choice.kind == p.SYNC_PHYSICS_SPELLIT_BODY_MOTION);
            @memcpy(std.mem.asBytes(&choice.payload.spellit_body.values), std.mem.asBytes(&canonical_body)[part * 48 ..][0..48]);
            switch (body_mode) {
                1 => {
                    choice.payload.spellit_body.key[0] += 1;
                },
                2 => {
                    alive = false;
                },
                3 => {
                    body_proof = false;
                },
                4 => {
                    local_body.position[1] += 1;
                },
                5 => {
                    choice.payload.spellit_body.values[0] = std.math.nan(f32);
                },
                else => {},
            }
            return if (body_mode == 6 and part != 0) -1 else 1;
        },
        p.SYNC_PHYSICS_SPELLIT_STEP => {
            const v = &choice.payload.spellit_step;
            v.engine_seed = 12345;
            v.game_seed = 23456;
            v.delta = 0.016;
            v.timer = -0.004;
            return 1;
        },
        p.SYNC_PHYSICS_SPELLIT_SELECTION => {
            choice.payload.spellit_selection.engine_seed = 98765;
            switch (mode) {
                1 => {
                    choice.payload.spellit_selection.eligibility[0] += 1;
                },
                2 => {
                    alive = false;
                },
                3 => {
                    proof = false;
                },
                else => {},
            }
            return if (mode == 4) -1 else 1;
        },
        else => {
            check(@src(), choice.kind == p.SYNC_PHYSICS_SPELLIT_POSE);
            choice.payload.spellit_pose.position = authoritative;
            choice.payload.spellit_pose.last_time = 0.25;
            switch (mode) {
                1 => {
                    choice.payload.spellit_pose.piece_ordinal += 1;
                },
                2 => {
                    alive = false;
                },
                3 => {
                    proof = false;
                },
                4 => win.store(usize, @intFromPtr(&gizmo) + 0x21c, @intFromPtr(&other_piece)),
                5 => {
                    choice.payload.spellit_pose.position[1] = std.math.nan(f32);
                },
                else => {},
            }
            win.SetLastError(999);
            return 1;
        },
    }
}
fn originalHop(value: usize, delta_bits: u32) callconv(.{ .x86_thiscall = .{} }) void {
    check(@src(), value == @intFromPtr(&gizmo));
    originals += 1;
    const delta: f32 = @bitCast(delta_bits);
    var timer = win.load(f32, value + 0x218);
    check(@src(), delta == 0.016 and timer == -0.004 and win.load(u32, 0xea178c) == 12345 and win.load(u16, 0xe637b4) == 23456);
    timer -= delta;
    win.store(f32, value + 0x218, timer);
    input.native_spellit_pose_input(value);
    check(@src(), std.mem.eql(u8, piece[0xd0..][0..12], std.mem.asBytes(&authoritative)));
    win.store(u32, 0xea178c, 54321);
    win.store(u16, 0xe637b4, 34567);
    win.SetLastError(4321);
}
fn originalSelection(value: usize) callconv(.{ .x86_thiscall = .{} }) usize {
    check(@src(), value == @intFromPtr(&gizmo) and win.load(u32, 0xea178c) == expected_seed);
    selections += 1;
    win.store(u32, 0xea178c, expected_seed + 1);
    win.SetLastError(789);
    return @intFromPtr(&piece);
}
fn originalEnabled(value: usize) callconv(.{ .x86_thiscall = .{} }) u32 {
    check(@src(), value == @intFromPtr(&receiver));
    enabled_calls += 1;
    win.SetLastError(321);
    return 0;
}
fn install(site: usize, target: usize) void {
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(site, 6, 0x40, &old) != 0);
    win.store(u8, site, 0xe9);
    win.store(usize, site + 1, target -% site -% 5);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), site, 6) != 0);
}
export var pose_entry: usize = 0;
export var pose_result: usize = 0;
export var pose_retained: f64 = 0;
extern fn invoke_bridge(usize) u32;
extern fn invoke_selection() void;
comptime {
    asm (
        \\.text
        \\_invoke_bridge:
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\movl $0xcafebabe,%eax
        \\movl $0x87654321,%edx
        \\cmpl %eax,%eax
        \\stc
        \\call _native_spellit_pose_bridge
        \\pushfl
        \\cmpl $0xcafebabe,%eax
        \\jne 1f
        \\cmpl 0x21c(%ebx),%ecx
        \\jne 1f
        \\cmpl $0x87654321,%edx
        \\jne 1f
        \\popl %eax
        \\popl %ebx
        \\ret
        \\1: addl $4,%esp
        \\popl %ebx
        \\movl $-1,%eax
        \\ret
        \\_invoke_selection:
        \\pushal
        \\movl $_gizmo,%ecx
        \\xorl %edx,%edx
        \\fld1
        \\call *_pose_entry
        \\movl %eax,_pose_result
        \\fstpl _pose_retained
        \\popal
        \\ret
    );
}
pub fn main() void {
    check(@src(), @intFromPtr(&image) < 0x7da280 and @intFromPtr(&image) + image.len > 0xfc0000);
    win.store(u32, 0xfb4b6c, 100);
    var scope = std.mem.zeroes(state.Scope);
    scope.gizmo = @intFromPtr(&gizmo);
    scope.bound = true;
    scope.clock = 100;
    scope.token.sequence = 44;
    check(@src(), native_spellit_source_resolve(scope.gizmo, &scope.source) != 0);
    state.current = &scope;
    for (0..2) |second| for (0..5) |i| {
        mode = @intCast(i);
        alive = true;
        proof = true;
        selected();
        receiver[0x183] = 0xa0;
        const before = faults;
        win.SetLastError(123);
        check(@src(), input.native_spellit_receiver_flags(@intFromPtr(&receiver), if (second != 0) 0x812df0 else 0x812d7a) == (if (mode != 0) @as(u32, 0) else 4));
        check(@src(), receiver[0x183] == 0xa0 and win.GetLastError() == 123 and faults == before + @intFromBool(mode != 0));
        alive = true;
        proof = true;
        selected();
        const enabled_before = enabled_calls;
        check(@src(), input.query(@intFromPtr(&receiver), originalEnabled, p.SYNC_PHYSICS_SPELLIT_ENABLED, if (second != 0) 0x812e02 else 0x812d8c) == @intFromBool(mode == 0));
        check(@src(), enabled_calls == enabled_before + 1 and win.GetLastError() == 321);
    };
    alive = true;
    proof = true;
    mode = 0;
    bodies_enabled = true;
    check(@src(), native_spellit_source_resolve(scope.gizmo, &scope.source) != 0);
    var helper_control: u16 = 0;
    const native_control: u16 = 0x7f;
    asm volatile ("fnstcw (%[old]); fldcw (%[native])"
        :
        : [old] "r" (&helper_control),
          [native] "r" (&native_control),
        : .{ .memory = true });
    scope.machine.capture();
    asm volatile ("fldcw (%[old])"
        :
        : [old] "r" (&helper_control),
        : .{ .memory = true });
    for (0..7) |i| {
        body_mode = @intCast(i);
        scope.token.release += 1;
        alive = true;
        proof = true;
        body_proof = true;
        local_body = std.mem.zeroes(types.State);
        canonical_body = std.mem.zeroes(types.State);
        canonical_body.basis[0] = 1;
        canonical_body.basis[5] = 1;
        canonical_body.basis[10] = 1;
        canonical_body.position = .{ 340.25, 0, 0, 1 };
        canonical_body.linear[1] = 0.5;
        canonical_body.angular[2] = 0.75;
        const before = body_applies;
        const applied = bodies.apply(&scope);
        check(@src(), applied == (i == 0) and body_applies == before + @intFromBool(i == 0));
        if (i == 0) {
            check(@src(), std.mem.eql(u8, std.mem.asBytes(&local_body), std.mem.asBytes(&canonical_body)));
            const normalized = body_applies;
            check(@src(), bodies.apply(&scope) and body_applies == normalized + 1);
        } else check(@src(), local_body.position[0] == 0);
        var restored: u16 = 0;
        asm volatile ("fnstcw (%[cw])"
            :
            : [cw] "r" (&restored),
            : .{ .memory = true });
        check(@src(), restored == helper_control);
    }
    bodies_enabled = false;
    body_mode = 0;
    body_proof = true;
    alive = true;
    proof = true;
    check(@src(), native_spellit_source_resolve(scope.gizmo, &scope.source) != 0);
    for (0..5) |i| {
        mode = @intCast(i);
        alive = true;
        proof = true;
        win.store(u32, 0xea178c, 111);
        const before = faults;
        input.selectionInput(scope.gizmo, 0x840790);
        check(@src(), win.load(u32, 0xea178c) == (if (mode != 0) @as(u32, 111) else 98765) and faults == before + @intFromBool(mode != 0));
    }
    alive = true;
    proof = true;
    install(0x7da280, @intFromPtr(&originalSelection));
    for ([_]usize{ 0x8406a7, 0x840790, 0x840b93 }) |site| {
        install(site, @intFromPtr(&input.selectionHook));
        win.store(u8, site, 0xe8);
        win.store(u8, site + 5, 0xc3);
        for (0..2) |bound| for (0..2) |i| {
            mode = @intCast(i);
            state.current = if (bound != 0) &scope else null;
            alive = true;
            proof = true;
            win.store(u32, 0xea178c, 222);
            expected_seed = if (bound != 0 and mode == 0) 98765 else 222;
            const before = selections;
            pose_entry = site;
            invoke_selection();
            check(@src(), pose_retained == 1 and pose_result == @intFromPtr(&piece) and selections == before + 1 and win.GetLastError() == 789 and win.load(u32, 0xea178c) == expected_seed + 1);
        };
    }
    state.current = &scope;
    for (0..6) |i| {
        mode = @intCast(i);
        alive = true;
        proof = true;
        selected();
        win.store(f32, @intFromPtr(&piece) + 0xf4, -0.25);
        const local = [_]f32{ 1, 2, 3 };
        @memcpy(piece[0xd0..][0..12], std.mem.asBytes(&local));
        const before = faults;
        win.SetLastError(123);
        input.native_spellit_pose_input(scope.gizmo);
        check(@src(), win.GetLastError() == 123 and win.load(f32, @intFromPtr(&piece) + 0xf4) == (if (mode != 0) @as(f32, -0.25) else 0.25) and faults == before + @intFromBool(mode != 0));
        check(@src(), std.mem.eql(u8, piece[0xd0..][0..12], std.mem.asBytes(&(if (mode != 0) local else authoritative))));
    }
    alive = true;
    proof = true;
    mode = 0;
    state.current = null;
    const before_calls = calls;
    input.native_spellit_pose_input(scope.gizmo);
    check(@src(), calls == before_calls);
    selected();
    var old: u32 = 0;
    check(@src(), win.VirtualProtect(0x8406b8, 1, 0x40, &old) != 0);
    win.store(u8, 0x8406b8, 0xc3);
    check(@src(), win.FlushInstructionCache(win.GetCurrentProcess(), 0x8406b8, 1) != 0);
    for (0..2) |bound| {
        state.current = if (bound != 0) &scope else null;
        const before = calls;
        var retained: f64 = 0;
        var cw_before: u16 = 0;
        var cw_after: u16 = 0;
        var mx_before: u32 = 0;
        var mx_after: u32 = 0;
        win.SetLastError(456);
        asm volatile ("fnstcw (%[cw]); stmxcsr (%[mx]); fld1"
            :
            : [cw] "r" (&cw_before),
              [mx] "r" (&mx_before),
            : .{ .memory = true });
        const flags = invoke_bridge(scope.gizmo);
        asm volatile ("fstpl (%[fp]); fnstcw (%[cw]); stmxcsr (%[mx])"
            :
            : [fp] "r" (&retained),
              [cw] "r" (&cw_after),
              [mx] "r" (&mx_after),
            : .{ .memory = true });
        check(@src(), flags != std.math.maxInt(u32) and flags & 0x41 == 0x41 and retained == 1 and cw_before == cw_after and mx_before == mx_after and win.GetLastError() == 456 and calls == before + bound);
    }
    install(0x840660, @intFromPtr(&originalHop));
    win.store(f32, scope.gizmo + 0x218, 1);
    state.current = null;
    mode = 0;
    alive = true;
    proof = true;
    const old_calls = calls;
    input.hopHook(scope.gizmo, 0, 0.049);
    check(@src(), originals == 1 and calls == old_calls + 2 and state.current == null and win.GetLastError() == 4321 and win.load(u32, 0xea178c) == 54321 and win.load(u16, 0xe637b4) == 34567);
}
