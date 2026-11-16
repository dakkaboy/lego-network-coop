const s = @import("tick_state.zig");
const Reader = @import("memory_reader.zig").Reader;
pub export var clonewars_pack_behavior_debug: [4]u32 = @splat(0);
pub fn identity(pack: usize) ?[2]u32 {
    var read = Reader.init();
    if (!read.readable(pack, 0x170) or s.load(u32, pack) != 0xadcef0) return null;
    const manager = s.load(usize, pack + 0xb8);
    const definition = s.load(usize, pack + 0xb4);
    if (!read.readable(manager, 0x110) or s.load(u32, manager) != 0xaded84 or !read.readable(definition, 0x20)) return null;
    const registry = s.load(usize, manager + 0x10c);
    if (!read.readable(registry, 0xc)) return null;
    const count = s.load(u32, registry + 8);
    if (count > 65535) return null;
    var node = s.load(usize, registry);
    for (0..count) |index| {
        if (!read.readable(node, 0x18) or s.load(u32, node) != 0xadcef0) return null;
        if (node == pack) {
            var witness: u32 = 2166136261;
            for ([_]u32{ s.load(u32, pack + 0x13c), s.load(u32, pack + 0x140), s.load(u32, definition + 0x1c), s.load(u32, pack + 0xf8), s.load(u32, pack + 0xfc) }) |value| witness = (witness ^ value) *% 16777619;
            return .{ @intCast(index), witness };
        }
        node = s.load(usize, node + 0x14);
    }
    return null;
}
pub export fn native_pack_behavior(pack: usize) usize {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local = s.load(usize, pack + 0x150);
    if (!s.ready()) return local;
    const at = s.site.PACK_BEHAVIOR;
    const key = identity(pack) orelse {
        s.fail(7, at, s.clock(), s.firstExpected());
        return 0;
    };
    if (local != 0 and !s.readable(local, 8)) {
        s.fail(7, at, s.clock(), s.firstExpected());
        return 0;
    }
    const kind = if (local == 0) 0 else s.load(u32, local);
    if (kind == 0xadcc94 and s.load(usize, local + 4) != pack) {
        s.fail(7, at, s.clock(), s.firstExpected());
        return 0;
    }
    const values = key ++ [_]u32{kind};
    const sites = s.consecutive(3, at, 1);
    if (s.host) {
        if (!s.capacity(3, at)) return 0;
    } else if (!s.match(&values, &sites, 2, true)) return 0;
    var source: [3]u32 = undefined;
    s.run(&values, &sites, &source);
    if (!s.ready()) return 0;
    clonewars_pack_behavior_debug[@intFromBool(!s.host)] +%= 1;
    if (source[2] == kind) return local;
    if (source[2] == 0) {
        clonewars_pack_behavior_debug[2] +%= 1;
        return 0;
    }
    if (source[2] != 0xadcc94) {
        s.fail(7, at, s.clock(), s.firstExpected());
        return 0;
    }
    const Create = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
    @as(Create, @ptrFromInt(0x461d20))(pack);
    const controller = s.load(usize, pack + 0x150);
    if (!s.ready() or !s.readable(controller, 8) or s.load(u32, controller) != 0xadcc94 or s.load(usize, controller + 4) != pack) {
        s.fail(7, at, s.clock(), s.firstExpected());
        return 0;
    }
    clonewars_pack_behavior_debug[3] +%= 1;
    return controller;
}
pub export var pack_behavior_continue: usize = 0x46247c;
comptime {
    asm (
        \\.text
        \\.globl _native_pack_behavior_bridge
        \\_native_pack_behavior_bridge:
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\subl $12,%esp
        \\pushl 4(%edx)
        \\cld
        \\call _native_pack_behavior
        \\addl $16,%esp
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\movl %eax,24(%esp)
        \\popal
        \\popfl
        \\jmp *_pack_behavior_continue
    );
}
