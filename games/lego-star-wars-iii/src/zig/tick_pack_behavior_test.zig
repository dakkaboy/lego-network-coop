const std = @import("std");
const f = @import("tick_journal_fixture.zig");
const b = @import("tick_pack_behavior.zig");
const check = f.check;
var controller: usize = 0;
var creates: u32 = 0;
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
fn call(pack: []u8, expected: usize) void {
    f.win.SetLastError(871);
    check(@src(), b.native_pack_behavior(f.addr(pack)) == expected and f.win.GetLastError() == 871);
}
pub fn main() void {
    f.open();
    defer f.close();
    f.reset(20);
    const pack = f.buffer(0x170);
    const manager = f.buffer(0x110);
    const registry = f.buffer(12);
    const definition = f.buffer(0x20);
    const behavior = f.buffer(8);
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
}
