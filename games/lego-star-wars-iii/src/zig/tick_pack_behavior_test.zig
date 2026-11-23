const std = @import("std");
const f = @import("tick_journal_fixture.zig");
const b = @import("tick_pack_behavior.zig");
const check = f.check;
var controller: usize = 0;
var creates: u32 = 0;
var march_updates: u32 = 0;
pub export var behavior_observed: [8]u32 = @splat(0);
extern fn invoke_behavior(usize, u32) void;
extern fn behavior_test_return() void;
comptime {
    asm (
        \\.text
        \\_behavior_test_return: ret
        \\_invoke_behavior:
        \\pushfl
        \\pushal
        \\movl 40(%esp),%esi
        \\movl $0x11111111,%eax
        \\movl $0x22222222,%ebx
        \\movl $0x33333333,%ecx
        \\movl $0x44444444,%edx
        \\movl $0x55555555,%edi
        \\movl $0x66666666,%ebp
        \\pushl 44(%esp)
        \\popfl
        \\call _native_pack_behavior_bridge
        \\movl %eax,_behavior_observed
        \\movl %ebx,_behavior_observed+4
        \\movl %ecx,_behavior_observed+8
        \\movl %edx,_behavior_observed+12
        \\movl %edi,_behavior_observed+16
        \\movl %ebp,_behavior_observed+20
        \\movl %esi,_behavior_observed+24
        \\pushfl
        \\popl _behavior_observed+28
        \\popal
        \\popfl
        \\ret
    );
}
fn create(pack: usize) callconv(.{ .x86_thiscall = .{} }) void {
    creates += 1;
    f.put(pack, 0x150, controller);
    f.win.SetLastError(999);
}
fn createTarget(pack: usize, target: *const [4]u32) callconv(.{ .x86_thiscall = .{} }) void {
    creates += 1;
    f.put(pack, 0x150, controller);
    f.put(controller, 0, f.sites.pack_behavior_target_class);
    f.put(controller, 4, pack);
    for (target, 0..) |value, i| f.put(controller, 0x10 + i * 4, value);
}
fn call(pack: []u8, expected: usize) void {
    f.win.SetLastError(871);
    check(@src(), b.native_pack_behavior(f.addr(pack)) == expected and f.win.GetLastError() == 871);
}
fn createFormation(pack: usize, parameter: u16) callconv(.{ .x86_thiscall = .{} }) void {
    creates += 1;
    f.put(pack, 0x150, controller);
    f.put(controller, 0, f.sites.pack_behavior_formation_class);
    f.put(controller, 4, pack);
    f.put(controller, 8, @as(u32, parameter));
}
fn createTurn(pack: usize, parameter: u16) callconv(.{ .x86_thiscall = .{} }) void {
    creates += 1;
    f.put(pack, 0x150, controller);
    f.put(controller, 0, f.sites.pack_behavior_turn_class);
    f.put(controller, 4, pack);
    f.put(controller, 8, @as(u32, parameter));
}
fn updateMarch(march: usize, target: *const [4]u32, speed: f32) callconv(.{ .x86_thiscall = .{} }) void {
    march_updates += 1;
    for (target, 0..) |value, i| f.put(march, 0x10 + i * 4, value);
    f.put(march, 0x24, @as(u32, @bitCast(speed)));
}
fn createMarch(pack: usize, target: *const [4]u32, speed: f32) callconv(.{ .x86_thiscall = .{} }) void {
    creates += 1;
    f.put(pack, 0x150, controller);
    f.put(controller, 0, f.sites.pack_behavior_march_class);
    f.put(controller, 4, pack);
    f.put(controller, 0x28, 0);
    updateMarch(controller, target, speed);
}
pub fn main() void {
    f.open();
    defer f.close();
    f.reset(20);
    const pack = f.buffer(0x170);
    const manager = f.buffer(0x110);
    const registry = f.buffer(12);
    const definition = f.buffer(0x20);
    const behavior = f.buffer(0x30);
    controller = f.addr(behavior);
    f.put(pack, 0, 0xadcef0);
    f.put(pack, 0xb8, manager);
    f.put(pack, 0xb4, definition);
    f.put(manager, 0, 0xaded84);
    f.put(manager, 0x10c, registry);
    f.put(registry, 0, pack);
    f.put(registry, 4, pack);
    f.put(registry, 8, 1);
    f.put(behavior, 0, 0xadcc94);
    f.put(behavior, 4, pack);
    var jump = [_]u8{ 0xe9, 0, 0, 0, 0 };
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&create) -% 0x461d25, .little);
    f.patch(0x461d20, &jump);
    f.put(pack, 0x150, behavior);
    f.begin(true);
    call(pack, controller);
    check(@src(), f.finish() and f.frame.tick_gate_count == 3 and f.stream(0, 3));
    check(@src(), f.frame.tick_gates[0].site == 0x462476 and f.frame.tick_gates[0].value == 0 and f.frame.tick_gates[2].value == 0xadcc94);
    f.put(pack, 0x150, 0);
    f.begin(false);
    call(pack, controller);
    check(@src(), creates == 1 and f.finish() and f.word(pack, 0x150) == controller);
    f.begin(false);
    call(pack, controller);
    check(@src(), creates == 1 and f.finish());
    f.next(true);
    f.put(pack, 0x150, 0);
    call(pack, 0);
    check(@src(), f.finish());
    f.put(pack, 0x150, behavior);
    f.begin(false);
    call(pack, 0);
    check(@src(), f.finish() and f.word(pack, 0x150) == controller and creates == 1);
    for (0..5) |fault| {
        f.next(true);
        call(pack, controller);
        check(@src(), f.finish());
        switch (fault) {
            0 => f.frame.tick_gates[0].value = 1,
            1 => f.frame.tick_gates[1].value ^= 1,
            2 => f.frame.tick_gates[2].clock += 1,
            3 => f.frame.tick_gates[2].value = 1,
            4 => f.frame.tick_gate_count = 2,
            else => unreachable,
        }
        f.begin(false);
        call(pack, 0);
        check(@src(), !f.finish() and creates == 1);
    }
    f.cancel();
    call(pack, controller);
    check(@src(), creates == 1);
    b.pack_behavior_continue = @intFromPtr(&behavior_test_return);
    for (0..128) |bits| {
        var flags: u32 = 0x202;
        for ([_]u32{ 1, 4, 16, 64, 128, 1024, 2048 }, 0..) |mask, bit| if (bits & (@as(usize, 1) << @intCast(bit)) != 0) {
            flags |= mask;
        };
        var numeric: f.Numeric = .{};
        numeric.push();
        f.win.SetLastError(891);
        invoke_behavior(f.addr(pack), flags);
        check(@src(), f.win.GetLastError() == 891);
        numeric.pop();
        numeric.verify();
        const expected = [_]u32{ 0x11111111, 0x22222222, controller, 0x44444444, 0x55555555, 0x66666666, f.addr(pack) };
        check(@src(), std.mem.eql(u32, behavior_observed[0..7], &expected) and behavior_observed[7] & 0xcd5 == flags & 0xcd5);
    }
    const target = [4]u32{ @bitCast(@as(f32, -31.05448)), @bitCast(@as(f32, 0)), @bitCast(@as(f32, -32.99379)), @bitCast(@as(f32, 1.5)) };
    f.put(behavior, 0, f.sites.pack_behavior_target_class);
    for (target, 0..) |value, i| f.put(behavior, 0x10 + i * 4, value);
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&createTarget) -% 0x437945, .little);
    f.patch(0x437940, &jump);
    f.next(true);
    call(pack, controller);
    check(@src(), f.finish() and f.frame.tick_gate_count == 7 and f.stream(0, 7));
    check(@src(), !f.stream(0, 3) and !f.stream(3, 4));
    f.put(behavior, 0, 0xad7a34);
    @memset(behavior[0x10..0x20], 0);
    f.begin(false);
    call(pack, controller);
    check(@src(), f.finish() and creates == 2 and f.word(behavior, 0) == f.sites.pack_behavior_target_class);
    for (target, 0..) |value, i| check(@src(), f.word(behavior, 0x10 + i * 4) == value);
    f.put(behavior, 0, f.sites.pack_behavior_formation_class);
    f.put(behavior, 8, 0x40ac);
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&createFormation) -% 0x4380d5, .little);
    f.patch(0x4380d0, &jump);
    f.next(true);
    call(pack, controller);
    check(@src(), f.finish() and f.frame.tick_gate_count == 4 and f.stream(0, 4));
    check(@src(), !f.stream(0, 3) and !f.stream(3, 1));
    f.put(behavior, 8, 7);
    f.begin(false);
    call(pack, controller);
    check(@src(), f.finish() and creates == 3 and f.word(behavior, 8) == 0x40ac);
    f.put(behavior, 0, f.sites.pack_behavior_turn_class);
    f.put(behavior, 8, 0x000140ac);
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&createTurn) -% 0x438225, .little);
    f.patch(0x438220, &jump);
    f.next(true);
    call(pack, controller);
    check(@src(), f.finish() and f.frame.tick_gate_count == 5 and f.stream(0, 5));
    check(@src(), !f.stream(0, 4) and !f.stream(3, 2));
    f.put(behavior, 0, f.sites.pack_behavior_formation_class);
    f.put(behavior, 8, 0x2000);
    f.begin(false);
    call(pack, controller);
    check(@src(), f.finish() and creates == 4 and f.word(behavior, 0) == f.sites.pack_behavior_turn_class and f.word(behavior, 8) == 0x000140ac);

    const speed: u32 = @bitCast(@as(f32, 1.75));
    f.put(behavior, 0, f.sites.pack_behavior_march_class);
    for (target, 0..) |value, i| f.put(behavior, 0x10 + i * 4, value);
    f.put(behavior, 0x24, speed);
    f.put(behavior, 0x28, 1);
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&createMarch) -% 0x437b25, .little);
    f.patch(0x437b20, &jump);
    std.mem.writeInt(u32, jump[1..5], @intFromPtr(&updateMarch) -% 0x40a565, .little);
    f.patch(0x40a560, &jump);
    f.next(true);
    call(pack, controller);
    check(@src(), f.finish() and f.frame.tick_gate_count == 9 and f.stream(0, 9));
    check(@src(), !f.stream(0, 8) and !f.stream(3, 6));
    f.frame.tick_gates[8].value = 2;
    check(@src(), !f.stream(0, 9));
    f.frame.tick_gates[8].value = 1;

    f.put(behavior, 0, f.sites.pack_behavior_formation_class);
    @memset(behavior[0x10..0x29], 0);
    f.begin(false);
    call(pack, controller);
    check(@src(), f.finish() and creates == 5 and march_updates == 1 and f.word(behavior, 0) == f.sites.pack_behavior_march_class);
    for (target, 0..) |value, i| check(@src(), f.word(behavior, 0x10 + i * 4) == value);
    check(@src(), f.word(behavior, 0x24) == speed and f.word(behavior, 0x28) == 1);

    f.put(behavior, 0x10, 0);
    f.put(behavior, 0x24, 0);
    f.put(behavior, 0x28, 0);
    f.begin(false);
    call(pack, controller);
    check(@src(), f.finish() and creates == 5 and march_updates == 2 and f.word(behavior, 0x10) == target[0] and f.word(behavior, 0x24) == speed and f.word(behavior, 0x28) == 1);
}
