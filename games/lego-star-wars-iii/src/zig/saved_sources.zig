const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const equal = @import("validation.zig").equal;
const guard = @import("seh_guard.zig");
extern fn game_native_profile_storage_ready() c_int;
pub const Roster = @import("saved_source_types.zig").Roster;
pub const Hub = @import("saved_source_types.zig").Hub;
fn level(read: *Reader, s: anytype) bool {
    s.world = win.load(usize, 0xfb4a20);
    s.profile = win.load(usize, 0xfbd8bc);
    if (!read.readable(s.world, 0x224) or !read.readable(s.profile, 4) or win.load(u32, s.profile) != 0x500 or game_native_profile_storage_ready() == 0) return false;
    s.definition = win.load(usize, s.world + 0x220);
    if (!read.readable(s.definition, 0x1b0)) return false;
    s.level = win.load(i16, s.definition + 0x94);
    const catalog = win.load(usize, 0xfb8404);
    const count = win.load(u32, 0xfb8410);
    return catalog != 0 and count > 0 and count <= 4096 and s.level >= 0 and s.level < count and
        catalog + @as(usize, @intCast(s.level)) * 0x1b0 == s.definition and win.load(u32, s.definition + 0x50) & 0x40000000 == 0;
}
fn rosterSnapshot(address: usize, actor: usize, output: *Roster) bool {
    var read = Reader.init();
    var s = std.mem.zeroes(Roster);
    s.count = win.load(u32, 0xfb4f18);
    if (s.count == 0 or s.count > 8 or address < 0xfb4f48 or (address - 0xfb4f48) % 0x2c != 0 or
        (address - 0xfb4f48) / 0x2c >= s.count or !read.readable(0xfb4f20, s.count * 0x2c)) return false;
    s.ordinal = @intCast((address - 0xfb4f48) / 0x2c);
    s.record = address - 0x28;
    if (win.load(usize, s.record) != actor or !level(&read, &s)) return false;
    s.provider = win.load(usize, 0xe90218);
    if (!read.readable(s.provider, 4)) return false;
    s.provider_class = win.load(usize, s.provider);
    if (!read.readable(s.provider_class, 0x7c)) return false;
    s.record_data = win.load([40]u8, s.record + 4);
    if (s.record_data[0x24] != win.load(u8, s.definition + 0x130)) return false;
    output.* = s;
    return true;
}
fn hubSnapshot(owner: usize, frame: usize, output: *Hub, reason: *u32) bool {
    var read = Reader.init();
    var s = std.mem.zeroes(Hub);
    s.owner = owner;
    s.native_frame = frame;
    reason.* = 1;
    if (!read.readable(owner, 0x214) or !read.readable(frame, 0x18)) return false;
    s.manager = win.load(usize, frame + 8);
    s.ordinal = win.load(u32, frame + 0xc);
    reason.* = 2;
    if (!read.readable(s.manager, 0x6b8) or win.load(usize, s.manager) != 0xae68bc or win.load(u32, frame + 0x14) != 0) return false;
    reason.* = 3;
    if (!level(&read, &s) or !read.readable(s.world, 0x22e8)) return false;
    const container = win.load(usize, s.world + 0x22e4);
    if (!read.readable(container, 0x10) or win.load(usize, container + 0xc) != s.world) return false;
    reason.* = 4;
    s.registry = win.load(usize, 0xe906b0);
    if (!read.readable(s.registry, 8 + 192 * 20)) return false;
    s.registration = win.load(usize, s.manager + 0x68);
    const first = s.registry + 8;
    if (s.registration < first) return false;
    const offset = s.registration - first;
    if (offset >= 192 * 20 or offset % 20 != 0) return false;
    s.registration_data = win.load([20]u8, s.registration);
    s.manager_id = win.load(u32, s.registration);
    s.manager_generation = win.load(u32, s.registration + 4);
    s.manager_type = win.load(u32, s.manager + 4);
    if (s.manager_id == 0 or s.manager_type == 0 or win.load(usize, s.registration + 8) != s.manager or win.load(u32, s.registration + 12) != 4 or
        win.load(u32, s.registration + 16) & 0xff != 0 or win.load(u32, s.manager + 8) != s.manager_id or win.load(u32, s.manager + 0x6c) != s.manager_generation) return false;
    for (0..192) |i| {
        const entry = first + i * 20;
        if (win.load(u32, entry) == s.manager_id and win.load(u32, entry + 4) == s.manager_generation and win.load(u32, entry + 12) == 4 and
            win.load(u32, entry + 16) & 0xff == 0 and win.load(usize, entry + 8) != 0 and win.load(usize, entry + 8) != s.manager) return false;
    }
    reason.* = 5;
    s.owner_id = win.load(u32, owner + 0xb8);
    if (s.owner_id == 0) return false;
    var matches: u32 = 0;
    var ids: u32 = 0;
    var walked: u32 = 0;
    var node = win.load(usize, s.manager + 0x98);
    while (node != 0 and walked < 4096) : (walked += 1) {
        if (!read.readable(node, 0x214)) return false;
        matches += @intFromBool(node == owner);
        ids += @intFromBool(win.load(u32, node + 0xb8) == s.owner_id);
        node = win.load(usize, node + 0x9c);
    }
    if (node != 0 or matches != 1 or ids != 1) return false;
    reason.* = 6;
    const count = win.load(i8, owner + 0x1b4);
    if (count <= 0 or s.ordinal >= count) return false;
    s.count = @intCast(count);
    s.records = win.load(usize, owner + 0xcc);
    if (!read.readable(s.records, s.count * 100)) return false;
    s.record = s.records + s.ordinal * 100;
    s.record_data = win.load([100]u8, s.record);
    s.serial = (@as(u32, @intCast(s.level)) << 7) | s.ordinal;
    output.* = s;
    reason.* = 0;
    return true;
}
fn commonArgs(args: *const [12]u32) bool {
    return args[4] == 0 and args[5] == 1 and args[6] == 0 and args[7] == 0 and args[8] == 0 and args[9] == 0 and args[10] == 0 and args[11] == 0xffffffff;
}
const Request = struct { kind: enum { roster, hub }, address: usize = 0, frame: usize = 0, actor: usize = 0, args: ?*const [12]u32 = null, roster: ?*Roster = null, roster_witness: ?*const Roster = null, hub: ?*Hub = null, hub_witness: ?*const Hub = null, reason: u32 = 1, completed: bool = false };
fn invoke(address: usize) callconv(.c) c_int {
    const request: *Request = @ptrFromInt(address);
    const result = dispatch(request);
    request.completed = true;
    return result;
}
fn dispatch(r: *Request) c_int {
    switch (r.kind) {
        .roster => {
            var first: Roster = undefined;
            var second: Roster = undefined;
            if (r.roster_witness) |s| return @intFromBool(rosterSnapshot(s.record + 0x28, r.actor, &first) and equal(s, &first));
            const out = r.roster orelse return 0;
            const a = r.args orelse return 0;
            if (!rosterSnapshot(r.address, 0, &first) or a[0] != win.load(u16, first.record + 0x24) or a[0] > 0x257 or a[1] != first.record + 4 or
                a[2] != win.load(u32, first.record + 0x10) or a[3] != first.record + 0x14 or !commonArgs(a) or
                !rosterSnapshot(r.address, 0, &second) or !equal(&first, &second)) return 0;
            out.* = first;
            return 1;
        },
        .hub => {
            var first: Hub = undefined;
            var second: Hub = undefined;
            if (r.hub_witness) |s| return @intFromBool(hubSnapshot(s.owner, s.native_frame, &first, &r.reason) and equal(s, &first));
            const out = r.hub orelse return 0;
            const a = r.args orelse return 0;
            if (!hubSnapshot(r.address, r.frame, &first, &r.reason)) return 0;
            r.reason = 7;
            var read = Reader.init();
            if (a[0] > 0x257 or !read.readable(a[1], 12) or a[2] > 0xffff or !read.readable(a[3], 1) or !commonArgs(a) or !hubSnapshot(r.address, r.frame, &second, &r.reason)) return 0;
            r.reason = 8;
            if (!equal(&first, &second)) return 0;
            out.* = first;
            r.reason = 0;
            return 1;
        },
    }
}
fn run(r: *Request) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const result = guard.all(@intFromPtr(r), invoke);
    return result;
}
pub export fn native_roster_source_resolve(address: usize, args: ?*const [12]u32, out: ?*Roster) c_int {
    var r: Request = .{ .kind = .roster, .address = address, .args = args, .roster = out };
    return run(&r);
}
pub export fn native_roster_source_revalidate(source: ?*const Roster, actor: usize) c_int {
    if (source == null) return 0;
    var r: Request = .{ .kind = .roster, .roster_witness = source, .actor = actor };
    return run(&r);
}
pub export fn native_hub_source_resolve(owner: usize, frame: usize, args: ?*const [12]u32, out: ?*Hub, reason: ?*u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var r: Request = .{ .kind = .hub, .address = owner, .frame = frame, .args = args, .hub = out };
    const result = run(&r);
    if (reason) |code| code.* = if (r.completed) r.reason else 9;
    return result;
}
pub export fn native_hub_source_revalidate(source: ?*const Hub) c_int {
    if (source == null) return 0;
    var r: Request = .{ .kind = .hub, .hub_witness = source };
    return run(&r);
}
