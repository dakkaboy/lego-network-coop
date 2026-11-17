const std = @import("std");
const source = @import("breakup_source.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
const Fixture = struct {
    model: [0xa00]u8 align(16),
    resource: [0x740]u8 align(16),
    runtime: [0x100]u8 align(16),
    definition: [0x20]u8 align(16),
    asset: [0x48]u8 align(16),
    meshes: [0x1c0]u8 align(16),
    handle: [2]usize,
    filename: [128]u8,
    name: [128]u8,
    fn init(self: *Fixture) void {
        self.* = std.mem.zeroes(Fixture);
        self.handle = .{ @intFromPtr(&self.resource), @intFromPtr(&self.meshes) };
        self.pointer(&self.model, 0x18, &self.definition);
        self.pointer(&self.definition, 0x1c, &self.asset);
        self.pointer(&self.asset, 0x44, &self.resource);
        win.store(u32, @intFromPtr(&self.asset) + 0x18, 2);
        self.pointer(&self.asset, 0x34, &self.filename);
        self.pointer(&self.resource, 0x6f8, &self.runtime);
        self.pointer(&self.runtime, 0x6c, &self.meshes);
        win.store(u32, @intFromPtr(&self.runtime) + 0x68, 2);
        self.pointer(&self.meshes, 0xb4, &self.name);
        self.pointer(&self.meshes, 0xe0 + 0xb4, &self.name);
        const path = "chars\\Vehicles\\Starhawk_Speederbike\\STARHAWK_SPEEDERBIKE_nxg.ghg";
        @memcpy(self.filename[0..path.len], path);
    }
    fn pointer(_: *Fixture, target: anytype, offset: usize, value: anytype) void {
        win.store(usize, @intFromPtr(target) + offset, @intFromPtr(value));
    }
    fn register(self: *Fixture, epoch: u32) bool {
        return source.register(@intFromPtr(&self.handle), @intFromPtr(&self.model), epoch);
    }
    fn resolve(self: *Fixture, epoch: u32, out: *[2]u32) bool {
        return source.resolve(@intFromPtr(&self.handle), epoch, out);
    }
};
var host: Fixture = undefined;
var peer: Fixture = undefined;
pub fn main() void {
    host.init();
    peer.init();
    var first: [2]u32 = undefined;
    var second: [2]u32 = undefined;
    check(@src(), !host.resolve(1, &first));
    check(@src(), host.register(1) and peer.register(1));
    check(@src(), host.resolve(1, &first) and peer.resolve(1, &second));
    check(@src(), std.mem.eql(u32, &first, &second) and (first[0] != 0 or first[1] != 0));
    host.handle[1] += 0xe0;
    check(@src(), host.resolve(1, &second) and !std.mem.eql(u32, &first, &second));
    host.handle[1] += 1;
    check(@src(), !host.resolve(1, &second));
    host.handle[1] = @intFromPtr(&host.meshes) + 2 * 0xe0;
    check(@src(), !host.resolve(1, &second));
    host.handle[1] = @intFromPtr(&host.meshes);
    peer.filename[0] = 'x';
    check(@src(), peer.register(1) and peer.resolve(1, &second) and !std.mem.eql(u32, &first, &second));
    check(@src(), !host.resolve(2, &second));
    check(@src(), host.register(2) and host.resolve(2, &second) and std.mem.eql(u32, &first, &second));
    win.store(usize, @intFromPtr(&host.resource) + 0x6f8, @intFromPtr(&peer.runtime));
    check(@src(), !host.resolve(2, &second));
    host.init();
    @memset(&host.name, 'a');
    check(@src(), !host.register(3) and !host.resolve(3, &second));
    host.name[7] = 0;
    check(@src(), host.resolve(3, &first));
    peer.name[0..8].* = host.name[0..8].*;
    check(@src(), peer.resolve(3, &second) and std.mem.eql(u32, &first, &second));
    host.init();
    win.store(u32, @intFromPtr(&host.asset) + 0x18, 3);
    check(@src(), !host.register(4) and !host.resolve(4, &second));
    check(@src(), !source.register(0, 0, 4) and !source.resolve(0, 4, &second));
}
