const win = @import("win32.zig");
const obs = @import("observation.zig");
const Machine = @import("machine_environment.zig").Environment;
const Resolve = *const fn (usize) callconv(.c) usize;
var original: Resolve = undefined;
var installed = false;
pub export var clonewars_collision_owner_debug: [3]u32 = @splat(0);
pub export var clonewars_collision_owner_rejected: [4]u32 = @splat(0);

fn available(body: usize, witness: *[4]u32) bool {
    witness.* = .{ @truncate(body), 0, 0, 0 };
    if (body == 0) return true;
    if (!win.accessible(body, 0x34, false)) return false;
    const owner = win.load(usize, body + 0x30);
    witness[1] = @truncate(owner);
    if (owner == 0) return true;
    if (!win.accessible(owner, 4, false)) return false;
    const table = win.load(usize, owner);
    witness[2] = @truncate(table);
    if (table == 0 or !win.accessible(table, 0x30, false)) return false;
    witness[3] = win.load(u32, table + 0x2c);
    return witness[3] != 0;
}

fn resolve(body: usize) callconv(.c) usize {
    var machine: Machine = undefined;
    machine.capture();
    // A ray result can retain a body whose owner has already lost its native vtable.
    // The native resolver handles an absent owner, but dereferences this retired one.
    var witness: [4]u32 = undefined;
    if (!available(body, &witness)) {
        clonewars_collision_owner_debug[1] +%= 1;
        clonewars_collision_owner_rejected = witness;
        machine.restore();
        return 0;
    }
    clonewars_collision_owner_debug[0] +%= 1;
    machine.restore();
    return original(body);
}

pub fn install() bool {
    if (installed) return true;
    const bridge = obs.install(0x42bee0, "\x8b\x44\x24\x04\x56\x85\xc0", @intFromPtr(&resolve)) orelse return false;
    original = @ptrFromInt(bridge);
    installed = true;
    clonewars_collision_owner_debug[2] = 1;
    return true;
}
