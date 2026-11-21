const std = @import("std");
const source = @import("breakup_source.zig");
const p = @import("protocol.zig");
const validation = @import("physics_validation.zig");
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
const TeamFixture = struct {
    team: [0x1820]u8 align(4) = @splat(0),
    resource: [0x10]u8 align(4) = @splat(0),
    descriptor: [0x34]u8 align(4) = @splat(0),
    nodes: [2][0x14c]u8 align(4) = @splat(@splat(0)),
    receivers: [2]u32 = @splat(0),
    world: u32 = 0,

    fn init(self: *TeamFixture) void {
        const team = @intFromPtr(&self.team);
        const first = @intFromPtr(&self.nodes[0]);
        const second = @intFromPtr(&self.nodes[1]);
        win.store(usize, team, 0xaef0fc);
        win.store(usize, team + 0x1c, @intFromPtr(&self.descriptor));
        win.store(usize, team + 0x10d0, @intFromPtr(&self.resource));
        win.store(usize, @intFromPtr(&self.resource) + 0xc, @intFromPtr(&self.world));
        win.store(usize, team + 0x1814, first);
        win.store(usize, team + 0x1818, second);
        win.store(usize, team + 0x181c, 2);
        win.store(usize, first + 4, second);
        win.store(usize, second, first);
        for (&self.nodes, &self.receivers) |*node, *receiver| {
            const address = @intFromPtr(node);
            win.store(usize, address + 8, team);
            win.store(usize, address + 0xc, source.team_breakup_type);
            win.store(usize, address + 0x14, @intFromPtr(receiver));
            win.store(usize, address + 0x140, address);
            win.store(usize, address + 0x148, 1);
        }
    }
    fn key(self: *TeamFixture, ordinal: usize, mesh: [2]u32) ?[2]u32 {
        return source.teamBreakupKey(@intFromPtr(&self.world), @intFromPtr(&self.nodes[ordinal]), @intFromPtr(&self.receivers[ordinal]), mesh);
    }
};
fn teamKeys() void {
    var first: TeamFixture = .{};
    var second: TeamFixture = .{};
    first.init();
    second.init();
    const mesh = [2]u32{ 1, 2 };
    const key = first.key(0, mesh) orelse unreachable;
    check(@src(), std.mem.eql(u32, &key, &second.key(0, mesh).?));
    check(@src(), !std.mem.eql(u32, &key, &second.key(1, mesh).?));
    check(@src(), !std.mem.eql(u32, &key, &second.key(0, .{ 3, 2 }).?));
    var launch = std.mem.zeroes(p.SyncPhysicsChoice);
    launch.kind = p.SYNC_PHYSICS_BREAKUP_LAUNCH;
    launch.site = source.team_breakup_site;
    launch.payload.basic = .{
        .model = source.team_breakup_type,
        .flags = 0x40000010,
        .clock = 335,
        .name_hash = key,
        .recipe = .{ 0x3d, 0, 0, 0, 0, 0 },
        .rng = 0,
    };
    var remote = launch;
    remote.payload.basic.name_hash = second.key(0, mesh).?;
    check(@src(), validation.sameSource(&launch, &remote));
    remote.payload.basic.name_hash = second.key(1, mesh).?;
    check(@src(), !validation.sameSource(&launch, &remote) and validation.valid(&remote));
    remote.payload.basic.model += 1;
    check(@src(), !validation.valid(&remote));
    remote = launch;
    remote.site = 0x905f38;
    check(@src(), !validation.sameSource(&launch, &remote) and validation.valid(&remote));
    win.store(usize, @intFromPtr(&second.descriptor) + 0x30, 1);
    check(@src(), !std.mem.eql(u32, &key, &second.key(0, mesh).?));
    check(@src(), source.teamBreakupKey(@intFromPtr(&first.world), @intFromPtr(&second.nodes[0]), @intFromPtr(&second.receivers[0]), mesh) == null);
    check(@src(), source.teamBreakupKey(@intFromPtr(&second.world), @intFromPtr(&second.nodes[0]), @intFromPtr(&second.receivers[1]), mesh) == null);
    win.store(usize, @intFromPtr(&second.nodes[1]), 0);
    check(@src(), second.key(0, mesh) == null);
}
pub fn main() void {
    teamKeys();
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
