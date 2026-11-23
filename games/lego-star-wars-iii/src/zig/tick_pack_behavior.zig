const s = @import("tick_state.zig");
const Reader = @import("memory_reader.zig").Reader;
const formation_class = s.site.pack_behavior_formation_class;
const turn_class = s.site.pack_behavior_turn_class;
const march_class = s.site.pack_behavior_march_class;
pub export var clonewars_pack_behavior_debug: [4]u32 = @splat(0);
fn fail(pack: usize, local: usize, stage: u32) void {
    if (s.clonewars_native_tick_failure[0] == 0) {
        const readable = s.readable(pack, 0x144);
        s.clonewars_native_tick_failure[8..16].* = .{
            stage,                                           pack,                                                               local,
            if (readable) s.load(usize, pack + 0xb8) else 0, if (readable) s.load(usize, pack + 0xb4) else 0,                    if (readable) s.load(u32, pack + 0x13c) else 0,
            if (readable) s.load(u32, pack + 0x140) else 0,  if (local != 0 and s.readable(local, 4)) s.load(u32, local) else 0,
        };
    }
    s.fail(7, s.site.PACK_BEHAVIOR, s.clock(), s.firstExpected());
}
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
fn replayMarch(pack: usize, local: usize, kind: u32) usize {
    const sites = &s.site.pack_behavior_march_sites;
    const same_class = kind == march_class;
    var values: [sites.len]u32 = @splat(0);
    if (same_class) {
        if (!s.readable(local, 0x29)) {
            fail(pack, local, 2);
            return 0;
        }
        values[0..4].* = s.load([4]u32, local + 0x10);
        values[4] = s.load(u32, local + 0x24);
        values[5] = s.load(u8, local + 0x28);
        const clock = s.clock();
        for (values, sites) |value, at| if (!s.valid.gateValid(.{ .site = at, .clock = clock, .value = value })) {
            fail(pack, local, 6);
            return 0;
        };
    }
    if (!s.host and !s.match(&values, sites, 0, true)) return 0;
    var canonical: [sites.len]u32 = undefined;
    s.run(&values, sites, &canonical);
    if (!s.ready()) return 0;
    if (s.host or (same_class and @import("std").meta.eql(values, canonical))) return local;

    const SetMarch = *const fn (usize, *const [4]u32, f32) callconv(.{ .x86_thiscall = .{} }) void;
    const speed: f32 = @bitCast(canonical[4]);
    if (same_class) {
        @as(SetMarch, @ptrFromInt(0x40a560))(local, canonical[0..4], speed);
    } else {
        @as(SetMarch, @ptrFromInt(0x437b20))(pack, canonical[0..4], speed);
    }
    const controller = s.load(usize, pack + 0x150);
    if (!s.ready() or !s.readable(controller, 0x29) or s.load(u32, controller) != march_class or s.load(usize, controller + 4) != pack) {
        fail(pack, controller, 5);
        return 0;
    }
    if (s.load(u8, controller + 0x28) != canonical[5]) s.win.store(u8, controller + 0x28, @intCast(canonical[5]));
    clonewars_pack_behavior_debug[3] +%= 1;
    return controller;
}
pub export fn native_pack_behavior(pack: usize) usize {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local = s.load(usize, pack + 0x150);
    if (!s.ready()) return local;
    const at = s.site.PACK_BEHAVIOR;
    const key = identity(pack) orelse {
        fail(pack, local, 1);
        return 0;
    };
    if (local != 0 and !s.readable(local, 8)) {
        fail(pack, local, 2);
        return 0;
    }
    const kind = if (local == 0) 0 else s.load(u32, local);
    const target_class = s.site.pack_behavior_target_class;
    if ((kind == 0xadcc94 or kind == target_class or kind == formation_class or kind == turn_class or kind == march_class) and s.load(usize, local + 4) != pack) {
        fail(pack, local, 3);
        return 0;
    }
    var target: [4]u32 = @splat(0);
    if (kind == target_class) {
        if (!s.readable(local, 0x20)) {
            fail(pack, local, 2);
            return 0;
        }
        target = s.load([4]u32, local + 0x10);
        for (target) |word| if (word & 0x7fffffff >= 0x7f800000) {
            fail(pack, local, 6);
            return 0;
        };
    }
    const values = key ++ [_]u32{kind};
    const sites = s.consecutive(3, at, 1);
    if (s.host) {
        const parameters: u32 = switch (kind) {
            target_class => 4,
            formation_class => 1,
            turn_class => 2,
            march_class => s.site.pack_behavior_march_sites.len,
            else => 0,
        };
        if (!s.capacity(3 + parameters, at)) return 0;
    } else if (!s.match(&values, &sites, 2, true)) return 0;
    var source: [3]u32 = undefined;
    s.run(&values, &sites, &source);
    if (!s.ready()) return 0;
    clonewars_pack_behavior_debug[@intFromBool(!s.host)] +%= 1;
    if (source[2] == march_class) return replayMarch(pack, local, kind);
    if (source[2] == target_class) {
        const target_sites = &s.site.pack_behavior_target_sites;
        if (!s.host and !s.match(&target, target_sites, 0, true)) return 0;
        var canonical: [4]u32 = undefined;
        s.run(&target, target_sites, &canonical);
        if (!s.ready()) return 0;
        if (s.host or (kind == target_class and @import("std").meta.eql(target, canonical))) return local;

        // The native constructor owns the previous controller and copies four scalar parameters.
        const CreateTarget = *const fn (usize, *const [4]u32) callconv(.{ .x86_thiscall = .{} }) void;
        @as(CreateTarget, @ptrFromInt(0x437940))(pack, &canonical);
        const controller = s.load(usize, pack + 0x150);
        if (!s.ready() or !s.readable(controller, 0x20) or s.load(u32, controller) != target_class or s.load(usize, controller + 4) != pack) {
            fail(pack, controller, 5);
            return 0;
        }
        clonewars_pack_behavior_debug[3] +%= 1;
        return controller;
    }
    if (source[2] == formation_class or source[2] == turn_class) {
        const turning = source[2] == turn_class;
        const same_class = kind == source[2];
        const size: usize = if (turning) 11 else 10;
        if (same_class and !s.readable(local, size)) {
            fail(pack, local, 2);
            return 0;
        }
        const parameter = if (same_class) s.load(u16, local + 8) else 0;
        const side = if (same_class and turning) s.load(u8, local + 0xa) else 0;
        if (side > 1) {
            fail(pack, local, 6);
            return 0;
        }
        const canonical = s.decision(if (turning) s.site.PACK_BEHAVIOR_TURN else s.site.PACK_BEHAVIOR_FORMATION, parameter);
        const canonical_side = if (turning) s.decision(s.site.PACK_BEHAVIOR_TURN + 1, side) else 0;
        if (!s.ready()) return 0;
        var controller = local;
        if (!same_class or parameter != canonical) {
            const Create = *const fn (usize, u16) callconv(.{ .x86_thiscall = .{} }) void;
            @as(Create, @ptrFromInt(if (turning) @as(usize, 0x438220) else 0x4380d0))(pack, @intCast(canonical));
            controller = s.load(usize, pack + 0x150);
        }
        if (!s.ready() or !s.readable(controller, size) or s.load(u32, controller) != source[2] or s.load(usize, controller + 4) != pack) {
            fail(pack, controller, 5);
            return 0;
        }
        if (turning and s.load(u8, controller + 0xa) != canonical_side) s.win.store(u8, controller + 0xa, @intCast(canonical_side));
        if (!same_class or parameter != canonical or side != canonical_side) clonewars_pack_behavior_debug[3] +%= 1;
        return controller;
    }
    if (source[2] == kind) return local;
    if (source[2] == 0) {
        clonewars_pack_behavior_debug[2] +%= 1;
        return 0;
    }
    if (source[2] != 0xadcc94) {
        fail(pack, local, 4);
        return 0;
    }
    const Create = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
    @as(Create, @ptrFromInt(0x461d20))(pack);
    const controller = s.load(usize, pack + 0x150);
    if (!s.ready() or !s.readable(controller, 8) or s.load(u32, controller) != 0xadcc94 or s.load(usize, controller + 4) != pack) {
        fail(pack, controller, 5);
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
