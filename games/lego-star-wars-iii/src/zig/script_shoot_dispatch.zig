const std = @import("std");
const win = @import("win32.zig");
const Source = @import("script_shoot_types.zig").Dispatch;
const guard = @import("seh_guard.zig");
const Binding = extern struct { words: [32]usize };
extern fn cadence_script_shoot_dispatch_active() c_int;
extern fn cadence_script_shoot_dispatch_begin(?*const Source, u32, *u32, *Binding) c_int;
extern fn cadence_script_shoot_dispatch_validate(*const Source, *const Binding) c_int;
extern fn cadence_script_shoot_dispatch_invalid(?*const Source, ?*const Binding, u32) void;
extern fn native_script_shoot_dispatch_initial_admission(usize) c_int;
extern fn native_script_shoot_dispatch_source_resolve(usize, usize, *Source) c_int;
extern fn native_script_shoot_dispatch_source_revalidate(*const Source) c_int;
extern fn native_script_shoot_dispatch_frame_matches(*const Source, usize, usize, usize, usize) c_int;
pub export var script_shoot_dispatch_original: usize = 0;
pub const Machine = extern struct { fx: [512]u8 align(16), last_error: u32, registers: *[9]u32 };
const Scope = struct {
    previous: ?*Scope,
    source: Source,
    binding: Binding,
    canonical: u32 = 0,
    bound: c_int = 0,
    consumed: bool = false,
    machine: *Machine,
    stack: usize,
    descriptor: usize,
    active: bool,
    admission: c_int,
};
threadlocal var current: ?*Scope = null;
var installed = false;
fn clearDirection() void {
    asm volatile ("cld" ::: .{ .cc = true });
}
const Identify = struct { stack: usize, descriptor: usize, identified: bool = false };
fn identify(address: usize) callconv(.c) c_int {
    const r: *Identify = @ptrFromInt(address);
    const handler = win.load(usize, r.descriptor + 0x10);
    if (handler == 0 or win.load(usize, handler + 4) != 0x963520) return 1;
    r.identified = true;
    const state = win.load(usize, r.stack + 8);
    return 1 + @as(c_int, @intFromBool(state == 0 or win.load(usize, state + 4) == 0));
}
extern fn script_shoot_dispatch_call_original(*Machine) void;
extern fn script_shoot_dispatch_scope(*Scope) void;
export fn script_shoot_dispatch_enter(_: *Scope) void {}
export fn script_shoot_dispatch_leave(s: *Scope, _: c_int) void {
    current = s.previous;
}
export fn script_shoot_dispatch_inner(s: *Scope) void {
    if (!s.active) s.bound = 0 else if (s.admission < 0 or native_script_shoot_dispatch_source_resolve(s.descriptor, s.stack, &s.source) == 0) {
        s.bound = -1;
        cadence_script_shoot_dispatch_invalid(null, null, 1);
    } else {
        const local: u32 = @intFromBool(win.load(u8, s.source.model + 0x42) != 0);
        s.canonical = local;
        s.bound = cadence_script_shoot_dispatch_begin(&s.source, local, &s.canonical, &s.binding);
        clearDirection();
        if (s.bound == 1) {
            const live = cadence_script_shoot_dispatch_validate(&s.source, &s.binding);
            clearDirection();
            if (live < 0 or (live > 0 and (native_script_shoot_dispatch_source_revalidate(&s.source) == 0 or s.canonical > 1))) {
                cadence_script_shoot_dispatch_invalid(&s.source, &s.binding, 2);
                s.bound = -1;
            }
        }
    }
    script_shoot_dispatch_call_original(s.machine);
}
export fn script_shoot_dispatch_run(machine: *Machine) void {
    const stack = @intFromPtr(machine.registers) + 36;
    const descriptor = machine.registers[6];
    var request: Identify = .{ .stack = stack, .descriptor = descriptor };
    const value = guard.all(@intFromPtr(&request), identify);
    const identified = if (value != 0) value - 1 else if (request.identified) @as(c_int, -1) else 0;
    if (identified == 0) {
        script_shoot_dispatch_call_original(machine);
        return;
    }
    const active = cadence_script_shoot_dispatch_active() != 0;
    clearDirection();
    const admission = if (active) (if (identified < 0) -1 else native_script_shoot_dispatch_initial_admission(stack)) else 1;
    if (admission == 0) {
        script_shoot_dispatch_call_original(machine);
        return;
    }
    var scope: Scope = .{ .previous = current, .source = std.mem.zeroes(Source), .binding = std.mem.zeroes(Binding), .machine = machine, .stack = stack, .descriptor = descriptor, .active = active, .admission = admission };
    current = &scope;
    script_shoot_dispatch_scope(&scope);
}
pub export fn native_script_shoot_dispatch_consume(actor: usize, state: usize, model: usize, frame: usize, local: u32) u32 {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var result: u32 = @intFromBool(local != 0);
    const scope = current;
    if (scope == null or scope.?.bound == 0) {
        const active = cadence_script_shoot_dispatch_active();
        clearDirection();
        if (active != 0) {
            var probe = std.mem.zeroes(Binding);
            var ignored = result;
            _ = cadence_script_shoot_dispatch_begin(null, result, &ignored, &probe);
            clearDirection();
            result = 0;
        }
        return result;
    }
    const s = scope.?;
    if (s.bound < 0) return 0;
    if (s.bound == 1) {
        const live = cadence_script_shoot_dispatch_validate(&s.source, &s.binding);
        clearDirection();
        result = 0;
        if (live > 0) {
            if (s.consumed or native_script_shoot_dispatch_frame_matches(&s.source, actor, state, model, frame) == 0) cadence_script_shoot_dispatch_invalid(&s.source, &s.binding, 4) else {
                s.consumed = true;
                result = s.canonical;
            }
        } else if (live < 0) cadence_script_shoot_dispatch_invalid(&s.source, &s.binding, 5);
    }
    return result;
}
extern fn native_script_shoot_dispatch_entry() void;
pub export fn native_script_shoot_dispatch_install() c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const expected = [_]u8{ 0x8b, 0xc1, 0x8b, 0x4c, 0x24, 0x08 };
    const entry: *[6]u8 = @ptrFromInt(0x6f3fe0);
    if (installed) return 1;
    if (!std.mem.eql(u8, entry, &expected)) return 0;
    const code = win.VirtualAlloc(0, 16, 0x3000, 4);
    if (code == 0) return 0;
    @memcpy(@as([*]u8, @ptrFromInt(code))[0..6], &expected);
    win.store(u8, code + 6, 0xe9);
    win.store(u32, code + 7, 0x6f3fe6 -% (code + 11));
    var prior: u32 = 0;
    var ignored: u32 = 0;
    if (win.VirtualProtect(code, 16, 0x20, &ignored) == 0 or !std.mem.eql(u8, entry, &expected) or win.VirtualProtect(@intFromPtr(entry), 6, 0x40, &prior) == 0) {
        _ = win.VirtualFree(code, 0, 0x8000);
        return 0;
    }
    script_shoot_dispatch_original = code;
    entry[0] = 0xe9;
    win.store(u32, @intFromPtr(entry) + 1, @intFromPtr(&native_script_shoot_dispatch_entry) -% 0x6f3fe5);
    entry[5] = 0x90;
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), code, 16);
    _ = win.FlushInstructionCache(win.GetCurrentProcess(), @intFromPtr(entry), 6);
    _ = win.VirtualProtect(@intFromPtr(entry), 6, prior, &ignored);
    installed = true;
    return 1;
}
comptime {
    asm (@import("seh_finally.zig").code("script_shoot_dispatch_scope", "script_shoot_dispatch_enter", "script_shoot_dispatch_inner", "script_shoot_dispatch_leave"));
    _ = @import("script_shoot_dispatch_asm.zig");
}
