const std = @import("std");
const s = @import("tick_state.zig");
const Object = @import("rts_types.zig").Object;

extern fn native_rts_object_source(usize, *Object) c_int;
pub extern fn native_zillo_ground_render_bridge() void;
pub export var native_zillo_ground_render_resume: usize = s.site.ZILLO_GROUND_RENDER + 7;
pub export var clonewars_zillo_ground_render_debug: [4]u32 = @splat(0);

const Source = struct { object: Object, resource: usize, active_slots: u32 };

fn resolve(component: usize, config: usize) ?Source {
    var object: Object = undefined;
    if (!s.readable(component, 0x648) or s.load(u32, component) != 0xaeea9c or
        !s.readable(config, 0x282) or s.load(u32, config) != 0xaee174 or
        s.load(usize, component + 0x24) != config or native_rts_object_source(component, &object) == 0 or
        object.pad != config or !s.readable(object.team, 0x1164)) return null;
    const resource = s.load(usize, object.team + 0x10d0);
    if (!s.readable(resource, 0x464) or s.load(u32, resource) != 0xada098 or
        s.load(usize, resource + 0xc) != object.world or s.load(usize, resource + 0x460) != object.team) return null;
    const first: u32 = @intFromBool(s.load(usize, object.team + 0x115c) == component);
    const second: u32 = @intFromBool(s.load(usize, object.team + 0x1160) == component);
    const active_slots = first | (second << 1);
    if (active_slots == 0) return null;
    return .{ .object = object, .resource = resource, .active_slots = active_slots };
}

pub export fn native_zillo_ground_render_input(component: usize, config: usize, caller: usize, local: u32) callconv(.c) u32 {
    const error_code = s.win.GetLastError();
    defer s.win.SetLastError(error_code);
    if (caller != 0x562696 or !s.ready() or s.frame.?.level != 112) return local;
    const at = s.site.ZILLO_GROUND_RENDER;
    const input = resolve(component, config) orelse {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    };
    if (local > 1 or s.load(u8, config + 0x27d) != local) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    }
    const values = input.object.key ++ [_]u32{ input.active_slots, local };
    const sites = s.consecutive(values.len, at, 1);
    if (s.host) {
        if (!s.capacity(values.len, at)) return local;
    } else if (!s.match(&values, &sites, values.len - 1, true)) return local;

    const current = resolve(component, config) orelse {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    };
    if (!s.ready() or !std.meta.eql(input, current) or s.load(u8, config + 0x27d) != local) {
        s.fail(4, at, s.clock(), s.firstExpected());
        return local;
    }
    var result: [values.len]u32 = undefined;
    s.run(&values, &sites, &result);
    if (!s.ready()) return local;

    const visible = result[values.len - 1];
    clonewars_zillo_ground_render_debug[@intFromBool(!s.host)] +%= 1;
    if (visible != local) {
        clonewars_zillo_ground_render_debug[2] +%= 1;
        clonewars_zillo_ground_render_debug[3] = s.clock();
    }
    // Only the simulation's comparison uses this value. The renderer keeps its local visibility.
    return visible;
}

comptime {
    asm (
        \\.text
        \\.globl _native_zillo_ground_render_bridge
        \\_native_zillo_ground_render_bridge:
        \\    leal -4(%esp),%esp
        \\    pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    movl 4(%edx),%esi
        \\    movzbl 0x27d(%esi),%eax
        \\    pushl %eax
        \\    movl 8(%edx),%eax
        \\    pushl 4(%eax)
        \\    pushl %esi
        \\    pushl (%edx)
        \\    call _native_zillo_ground_render_input
        \\    addl $16,%esp
        \\    movl 512(%esp),%edx
        \\    movl %eax,36(%edx)
        \\    fxrstor (%esp)
        \\    movl %edx,%esp
        \\    popal
        \\    popfl
        \\    cmpb $0,(%esp)
        \\    leal 4(%esp),%esp
        \\    jmp *_native_zillo_ground_render_resume
    );
}
