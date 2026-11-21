const std = @import("std");
const Machine = @import("machine_environment.zig").Environment;
const Reader = @import("memory_reader.zig").Reader;
const origins = @import("zillo_support_origin.zig");
const s = @import("cadence_state.zig");
const p = @import("protocol.zig");
const win = s.win;

const Throw = *const fn (usize, u32, u32) callconv(.{ .x86_thiscall = .{} }) usize;
pub extern fn zillo_support_register_thunk() void;
export var zillo_support_native_register: usize = 0x670050;

const Scope = struct { lease: s.Lease, world: usize, origin: origins.Origin };
const DeferredThrow = struct {
    scope: Scope,
    task: usize,
    factory: usize,
    object: usize,
    component: usize,
};
threadlocal var scope: ?Scope = null;
threadlocal var aat_throws: [3]?DeferredThrow = @splat(null);

fn qualify(task: usize, cursor: usize, model: u32, flag: u32) ?Scope {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 112 or flag != 1 or
        (model != 5 and model != 27 and model != 28) or !s.valid(task, 0x3b0)) return null;
    const first = task + 0x3a0;
    if (cursor < first or cursor > first + 8 or (cursor - first) % 4 != 0 or s.read(u32, task + 0x3ac) != 3) return null;
    const actor = s.read(usize, task + 0x20);
    if (!s.valid(actor, 0x1440) or s.read(u16, actor + 0xdc0) != 127) return null;
    var slot: u32 = undefined;
    var generation: u32 = undefined;
    if (s.entities_observed_identity(actor, &slot, &generation) == 0 or slot >= p.SYNC_MAX_ACTORS or generation == 0 or !s.live(&lease)) return null;
    return .{
        .lease = lease,
        .world = s.read(usize, 0xfb4a20),
        .origin = .{
            .clock = s.read(u32, 0xfb4b6c),
            .actor_slot = slot,
            .generation = generation,
            .throw_slot = @intCast((cursor - first) / 4),
            .model = model,
        },
    };
}

export fn zillo_support_throw(factory: usize, task: usize, cursor: usize, model: u32, flag: u32) usize {
    var machine: Machine = undefined;
    machine.capture();
    const previous = scope;
    scope = if (previous == null) qualify(task, cursor, model, flag) else null;
    if (scope != null) origins.clonewars_zillo_support_origin_debug[1] +%= 1;
    machine.restore();
    const original: Throw = @ptrFromInt(0x54c070);
    const result = original(factory, model, flag);
    if (scope) |current| {
        aat_throws[current.origin.throw_slot] = null;
        if (current.origin.model == 27) {
            var after: Machine = undefined;
            after.capture();
            rememberAatThrow(current, task, factory, result);
            after.restore();
        }
    }
    scope = previous;
    return result;
}

fn remember(owner: usize, current: Scope) void {
    if (!s.live(&current.lease) or current.world == 0 or current.world != s.read(usize, 0xfb4a20)) return;
    var read = Reader.init();
    var owner_class: u32 = undefined;
    if (!read.readable(owner, 0x1a4) or !read.imageClass(owner, &owner_class) or owner_class != 0x820f64) return;
    const body = s.read(usize, owner + 0x1a0);
    var body_class: u32 = undefined;
    if (!read.readable(body, 0xa0) or !read.imageClass(body, &body_class) or body_class != 0x869eac or s.read(usize, body + 0x28) != owner) return;
    origins.remember(current.world, owner, body, current.origin);
}

fn nativeName(read: *Reader, name: usize, expected: []const u8) bool {
    return read.nameLength(name) == expected.len + 1 and
        std.ascii.eqlIgnoreCase(@as([*]const u8, @ptrFromInt(name))[0..expected.len], expected);
}

fn aatComponent(read: *Reader, factory: usize, object: usize) ?usize {
    if (!read.readable(object, 0x14c) or s.read(usize, object + 8) != factory or
        s.read(u32, object + 0xc) != 31 or s.read(u32, object + 0x13c) != 0xae98c4 or
        s.read(usize, object + 0x140) != object or s.read(u32, object + 0x148) != 0) return null;
    const component = s.read(usize, object + 0x14);
    if (!read.readable(component, 0x20)) return null;
    const descriptor = s.read(usize, component + 0x18);
    if (!read.readable(descriptor, 0x10)) return null;
    const reference = s.read(usize, descriptor + 0xc);
    if (!read.readable(reference, 0x14) or
        !nativeName(read, s.read(usize, reference + 0x10), "AAT_CHASSIS")) return null;
    return component;
}

fn rememberAatThrow(current: Scope, task: usize, factory: usize, object: usize) void {
    if (!s.live(&current.lease)) return;
    var read = Reader.init();
    const component = aatComponent(&read, factory, object) orelse return;
    aat_throws[current.origin.throw_slot] = .{ .scope = current, .task = task, .factory = factory, .object = object, .component = component };
}

fn deferredAatScope(container: usize, owner: usize, frame: usize) ?Scope {
    const clock = s.read(u32, 0xfb4b6c);
    const world = s.read(usize, 0xfb4a20);
    for (aat_throws) |pending| {
        const entry = pending orelse continue;
        if (entry.scope.origin.clock == clock and entry.scope.world == world and s.live(&entry.scope.lease)) break;
    } else return null;
    var read = Reader.init();

    // AAT builds its rigid parts after the three throw objects have been allocated.
    if (!read.readable(frame, 0xe0) or s.read(u32, frame + 4) != 0x676690 or
        s.read(u32, frame + 0xc) != 0 or s.read(u32, frame + 0x10) != 0 or
        s.read(u32, frame + 0x14) != 0 or s.read(u32, frame + 0x2c) != 0x67650e or
        s.read(u32, frame + 0x5c) != 0x685c1b or s.read(u32, frame + 0x80) != 0x685d7a or
        s.read(u32, frame + 0xbc) != 0x651805) return null;
    const component = s.read(usize, frame + 0xdc);
    var match: ?Scope = null;
    for (aat_throws) |pending| {
        const entry = pending orelse continue;
        if (entry.component != component or entry.scope.world != world or
            entry.scope.origin.clock != clock or !s.live(&entry.scope.lease)) continue;
        if (match != null or !read.readable(entry.task, 0x3f4) or
            s.read(usize, entry.task + 0x3f0) != entry.factory or s.read(u32, entry.task + 0x3ac) != 3 or
            s.read(usize, entry.task + 0x3a0 + 4 * entry.scope.origin.throw_slot) != entry.object or
            aatComponent(&read, entry.factory, entry.object) != component) return null;
        match = entry.scope;
    }
    const result = match orelse return null;
    const model = s.read(usize, frame + 0x78);
    if (s.read(usize, component + 8) != model or !read.readable(model, 0xd8) or
        s.read(u32, model) != 0xc1ed6c) return null;
    const index = s.read(u32, frame + 0x70);
    const count = s.read(u16, model + 0xd6);
    const parts = s.read(usize, model + 0xd0);
    const part = s.read(usize, frame + 0xa0);
    if (index >= count or count > 128 or !read.readable(parts, @as(usize, count) * 4) or
        s.read(usize, parts + index * 4) != part or !read.readable(part, 0x14)) return null;
    if (!read.readable(owner, 0x1a4) or s.read(u8, owner + 6) != 84 or
        !read.readable(container, 0x10) or s.read(u32, container) != 0xc213dc or
        !read.readable(world, 0x22e8)) return null;
    const world_container = s.read(usize, world + 0x22e4);
    const registry = s.read(usize, 0xf9dd10);
    if (!read.readable(world_container, 0x10) or s.read(u32, world_container) != 0xada098 or
        s.read(usize, world_container + 0xc) != world or
        s.read(usize, container + 0xc) != world_container or
        !read.readable(registry, 8 + 85 * 4)) return null;
    const resource = s.read(usize, registry + 8 + 84 * 4);
    if (!read.readable(resource, 0x58) or s.read(usize, resource + 0x54) != world_container or
        s.read(usize, resource + 0x4c) != 0 or
        !nativeName(&read, s.read(usize, resource + 0x34), "ZilloBeast_B_temp.led") or
        !nativeName(&read, s.read(usize, resource + 0x40), "ZilloBeast_B_temp")) return null;
    return result;
}

fn polygonBody(read: *Reader, owner: usize) ?usize {
    if (!read.readable(owner, 0x1a4) or s.read(u32, owner) != 0xc20f64) return null;
    const body = s.read(usize, owner + 0x1a0);
    if (!read.readable(body, 0xa0) or s.read(u32, body) != 0xc69eac or
        s.read(usize, body + 0x28) != owner or s.read(u8, body + 0x19) & 0x60 != 0x40) return null;
    const shape = s.read(usize, body + 0x24);
    if (!read.readable(shape, 0x64) or s.read(u32, shape) != 0xc695d4 or
        !nativeName(read, s.read(usize, body + 0x1c), "polySurface77")) return null;
    const child = s.read(usize, shape + 0x60);
    return if (read.readable(child, 4) and s.read(u32, child) == 0xc697ec) body else null;
}

fn rememberPolygon(container: usize, owner: usize, factory_frame: usize) void {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or lease.cohort.thread != win.GetCurrentThreadId() or s.journal.frame.?.level != 112) return;
    var read = Reader.init();
    if (!read.readable(factory_frame, 0x18) or s.read(u32, factory_frame + 4) != 0x676690) return;
    const mode = s.read(u32, factory_frame + 0xc);
    const kind = s.read(u32, factory_frame + 0x10);
    if (!((mode == 0 and kind == 26) or (mode == 4 and kind == 18)) or s.read(u32, factory_frame + 0x14) != 0) return;
    const body = polygonBody(&read, owner) orelse return;
    const world = s.read(usize, 0xfb4a20);
    const registry = s.read(usize, 0xf9dd10);
    if (!read.readable(world, 0x22e8) or !read.readable(container, 0x10) or
        s.read(u32, container) != 0xc213dc or !read.readable(registry, 8 + 199 * 4)) return;
    const world_container = s.read(usize, world + 0x22e4);
    if (!read.readable(world_container, 0x10) or s.read(u32, world_container) != 0xada098 or
        s.read(usize, container + 0xc) != world_container or s.read(usize, world_container + 0xc) != world) return;
    const slot = s.read(u8, owner + 6);
    if (slot >= 199) return;
    const entry = s.read(usize, registry + 8 + @as(usize, slot) * 4);
    if (!read.readable(entry, 0x58) or s.read(usize, entry + 0x54) != world_container or s.read(usize, entry + 0x4c) != 0 or
        !nativeName(&read, s.read(usize, entry + 0x34), "levels\\ZilloBeast\\ZilloBeast_B\\ZilloBeast_B.led") or
        !nativeName(&read, s.read(usize, entry + 0x40), "ZilloBeast_B")) return;
    const clock = s.read(u32, 0xfb4b6c);
    var root_clock = clock;
    if (mode == 4) {
        const source = s.read(usize, factory_frame + 8);
        const parent_body = polygonBody(&read, source) orelse return;
        const parent = origins.polygon(world, source, parent_body) orelse return;
        if (source == owner or parent.mode != 0 or parent.clock >= clock or s.read(u8, source + 6) != slot) return;
        root_clock = parent.root_clock;
    }
    if (clock != 0 and s.live(&lease)) origins.rememberPolygon(world, owner, body, .{ .root_clock = root_clock, .clock = clock, .mode = mode });
}

export fn zillo_support_register_admission(container: usize, owner: usize, factory_frame: usize) void {
    const error_code = win.GetLastError();
    defer win.SetLastError(error_code);
    if (scope orelse deferredAatScope(container, owner, factory_frame)) |current| remember(owner, current);
    rememberPolygon(container, owner, factory_frame);
}

comptime {
    asm (
        \\.globl _zillo_support_throw_thunk
        \\_zillo_support_throw_thunk:
        \\    pushl 8(%esp)
        \\    pushl 8(%esp)
        \\    pushl %esi
        \\    pushl %edi
        \\    pushl %ecx
        \\    call _zillo_support_throw
        \\    addl $20, %esp
        \\    ret $8
        \\.globl _zillo_support_register_thunk
        \\_zillo_support_register_thunk:
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
        \\    movl 12(%edx),%eax
        \\    subl $4,%esp
        \\    pushl 8(%edx)
        \\    pushl 8(%eax)
        \\    pushl 24(%edx)
        \\    call _zillo_support_register_admission
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_zillo_support_native_register
    );
}
