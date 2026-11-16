const std = @import("std");
pub const ws = @import("winsock.zig");
pub const lan = @import("lan.zig");
pub const state = @import("lan_state.zig");
pub const p = @import("protocol.zig");
pub const check = @import("native_test_support.zig").check;
pub const sleep = @import("threading.zig").Sleep;
pub extern "kernel32" fn GetTickCount64() callconv(.winapi) u64;
pub const Header = extern struct { magic: u32 = 0x334e414c, kind: u32, size: u32 };
pub const address = ws.Address{ .port = @byteSwap(@as(u16, 32521)), .address = 0x0100007f };
comptime {
    _ = @import("dll_root.zig");
}
pub fn initialize() void {
    var data: [512]u8 align(4) = undefined;
    check(@src(), ws.WSAStartup(0x202, &data) == 0);
}
pub fn listen() usize {
    const socket = ws.socket(2, 1, 6);
    check(@src(), socket != ws.invalid_socket);
    check(@src(), ws.bind(socket, &address, @sizeOf(ws.Address)) == 0 and ws.listen(socket, 1) == 0);
    return socket;
}
pub fn timeouts(socket: usize) void {
    const timeout: u32 = 3000;
    check(@src(), ws.setsockopt(socket, 0xffff, 0x1006, &timeout, 4) == 0 and ws.setsockopt(socket, 0xffff, 0x1005, &timeout, 4) == 0);
}
pub fn accept(socket: usize) usize {
    var set = ws.Set{};
    set.sockets[0] = socket;
    const timeout = ws.Time{ .seconds = 3, .microseconds = 0 };
    check(@src(), ws.select(0, &set, null, null, &timeout) == 1);
    const peer = ws.accept(socket, 0, 0);
    check(@src(), peer != ws.invalid_socket);
    timeouts(peer);
    return peer;
}
pub fn transfer(socket: usize, bytes: []u8, write: bool) void {
    var position: usize = 0;
    while (position < bytes.len) {
        const length: i32 = @intCast(bytes.len - position);
        const count = if (write) ws.send(socket, bytes.ptr + position, length, 0) else ws.recv(socket, bytes.ptr + position, length, 0);
        check(@src(), count > 0);
        position += @intCast(count);
    }
}
pub fn hello(socket: usize) void {
    var bytes: [40]u8 = undefined;
    transfer(socket, &bytes, false);
    check(@src(), std.mem.eql(u8, bytes[0..7], "LSW3LAN") and bytes[7] == p.SYNC_PROTOCOL_VERSION);
    transfer(socket, &bytes, true);
}
pub fn packet(socket: usize, kind: u32, bytes: []u8) void {
    var header = Header{ .kind = kind, .size = @intCast(bytes.len) };
    transfer(socket, std.mem.asBytes(&header), true);
    transfer(socket, bytes, true);
}
pub fn waitStatus(status: i32) void {
    const deadline = GetTickCount64() + 3000;
    while (state.lan_status() != status and GetTickCount64() < deadline) sleep(1);
    check(@src(), state.lan_status() == status);
}
pub fn readPeer(socket: usize, peer: *state.Peer) void {
    var header: Header = undefined;
    transfer(socket, std.mem.asBytes(&header), false);
    check(@src(), header.magic == 0x334e414c and header.kind == 1 and header.size == @sizeOf(state.Peer));
    transfer(socket, std.mem.asBytes(peer), false);
}
