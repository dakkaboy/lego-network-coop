const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Machine = @import("machine_environment.zig").Environment;
const Destroy = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) void;
var original: Destroy = undefined;
var installed = false;
pub export var clonewars_support_retirement_debug: [6]u32 = @splat(0);

pub fn detach(retired: usize, pool: usize, count: u32) u32 {
    if (retired == 0 or pool == 0 or count > 4096) return 0;
    var read = Reader.init();
    var detached: u32 = 0;
    for (0..count) |i| {
        const offset = i * 0x1440;
        if (pool > @import("std").math.maxInt(usize) - offset) break;
        const actor = pool + offset;
        if (!read.readable(actor, 0x54) or win.load(u32, actor + 0x50) & 3 != 3) continue;
        const model = win.load(usize, actor + 8);
        if (!read.readable(model, 0x3c)) continue;
        const body = win.load(usize, model + 0x38);
        var class: u32 = 0;
        if (body == retired or !read.readable(body, 0xf0) or !read.imageClass(body, &class) or class != 0x869f1c or win.load(usize, body + 0xec) != retired) continue;
        if (!win.accessible(body + 0xec, 4, true) or win.load(usize, actor + 8) != model or win.load(usize, model + 0x38) != body or win.load(usize, body + 0xec) != retired) continue;
        // The ground contact is borrowed; the base destructor does not revoke it.
        win.store(usize, body + 0xec, 0);
        detached += 1;
        if (clonewars_support_retirement_debug[0] == 0) clonewars_support_retirement_debug[1..5].* = .{ @truncate(retired), @truncate(actor), @truncate(body), win.load(u32, read.native(0xfb4b6c)) };
        clonewars_support_retirement_debug[0] +%= 1;
    }
    return detached;
}

fn destroy(body: usize, _: usize) callconv(.{ .x86_fastcall = .{} }) void {
    var machine: Machine = undefined;
    machine.capture();
    var read = Reader.init();
    const pool_address = read.native(0xfb2f60);
    const count_address = read.native(0xfb2e3c);
    if (read.readable(pool_address, 4) and read.readable(count_address, 4)) _ = detach(body, win.load(usize, pool_address), win.load(u32, count_address));
    clonewars_support_retirement_debug[5] +%= 1;
    machine.restore();
    original(body);
}

pub fn install() bool {
    if (installed) return true;
    const bridge = @import("observation.zig").install(0xa29390, "\x6a\xff\x68\x5c\x44\xab\x00", @intFromPtr(&destroy)) orelse return false;
    original = @ptrFromInt(bridge);
    installed = true;
    return true;
}
