const std = @import("std");
const t = @import("lan_test_support.zig");
const win = @import("win32.zig");
const check = t.check;
pub const panic = @import("safety.zig").panic;
pub const lan_port: u16 = 32521;
extern fn sync_frame_encode(*const t.p.SyncFrame, [*]u8, u32) u32;
pub fn main() void {
    t.initialize();
    defer _ = t.ws.WSACleanup();
    const listener = t.listen();
    t.lan.lan_start(0, "127.0.0.1");
    defer t.state.lan_stop();
    const peer = t.accept(listener);
    t.hello(peer);
    t.waitStatus(3);
    t.state.lan_publish_transition(5, 3, 1);
    t.state.lan_publish_ready(1);
    const local = t.p.SyncInput{ .held = 1, .pressed = 1, .analog_x = 17, .analog_y = 28, .aim_x = 39, .aim_y = 40 };
    t.state.lan_publish_input(&local);
    var own: t.state.Peer = undefined;
    var deadline = t.GetTickCount64() + 3000;
    while (true) {
        t.readPeer(peer, &own);
        if (own.epoch == 5 and own.ready != 0 and own.input.pressed == 1) break;
        check(@src(), t.GetTickCount64() < deadline);
    }
    check(@src(), own.level == 3 and own.native_entry == 1 and own.input.analog_x == 17);
    t.readPeer(peer, &own);
    check(@src(), own.input.pressed == 0);
    var remote = t.state.Peer{};
    remote.epoch = 5;
    remote.level = 3;
    remote.ready = 1;
    remote.input = .{ .held = 1, .pressed = 1, .analog_x = 128, .analog_y = 128, .aim_x = 128, .aim_y = 128 };
    remote.ack = 41;
    t.packet(peer, 1, std.mem.asBytes(&remote));
    remote.input.held = 2;
    remote.input.pressed = 2;
    remote.ack = 42;
    t.packet(peer, 1, std.mem.asBytes(&remote));
    deadline = t.GetTickCount64() + 3000;
    while (t.state.lan_peer_ack() != 42 and t.GetTickCount64() < deadline) t.sleep(1);
    check(@src(), t.state.lan_peer_ack() == 42 and t.state.lan_peer_ready() != 0);
    const consumed = t.state.lan_consume_input();
    check(@src(), consumed.held == 2 and consumed.pressed == 3 and t.state.lan_consume_input().pressed == 0);
    const frame: *t.p.SyncFrame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(t.p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(frame) != 0);
    defer _ = win.VirtualFree(@intFromPtr(frame), 0, 0x8000);
    const received: *t.p.SyncFrame = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(t.p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(received) != 0);
    defer _ = win.VirtualFree(@intFromPtr(received), 0, 0x8000);
    const wire: [*]u8 = @ptrFromInt(win.VirtualAlloc(0, @sizeOf(t.p.SyncFrame), 0x3000, 4));
    check(@src(), @intFromPtr(wire) != 0);
    defer _ = win.VirtualFree(@intFromPtr(wire), 0, 0x8000);
    frame.epoch = 5;
    frame.sequence = 1;
    frame.level = 3;
    frame.delta = 0.016;
    frame.tick_gate_count = t.p.SYNC_MAX_TICK_GATES;
    for (&frame.tick_gates, 0..) |*gate, index| gate.* = .{ .site = 0x888889, .clock = 0, .value = @intCast(index & 1) };
    const size = sync_frame_encode(frame, wire, @sizeOf(t.p.SyncFrame));
    check(@src(), size != 0);
    t.packet(peer, 2, wire[0..size]);
    deadline = t.GetTickCount64() + 3000;
    var found = false;
    while (t.GetTickCount64() < deadline) {
        if (t.state.lan_receive_frame(received) != 0) {
            found = true;
            break;
        }
        t.sleep(1);
    }
    check(@src(), found and received.epoch == 5 and received.sequence == 1 and received.level == 3);
    check(@src(), received.tick_gate_count == t.p.SYNC_MAX_TICK_GATES and std.mem.eql(u8, std.mem.sliceAsBytes(&received.tick_gates), std.mem.sliceAsBytes(&frame.tick_gates)));
    t.state.lan_publish_transition(6, 3, t.p.SYNC_TRANSITION_NATIVE_CYCLE);
    deadline = t.GetTickCount64() + 3000;
    while (true) {
        t.readPeer(peer, &own);
        if (own.epoch == 6) break;
        check(@src(), t.GetTickCount64() < deadline);
    }
    check(@src(), own.level == 3 and own.native_entry == t.p.SYNC_TRANSITION_NATIVE_CYCLE);
    remote.epoch = 6;
    remote.native_entry = t.p.SYNC_TRANSITION_NATIVE_CYCLE;
    remote.ack = 43;
    t.packet(peer, 1, std.mem.asBytes(&remote));
    deadline = t.GetTickCount64() + 3000;
    while (t.state.lan_peer_ack() != 43 and t.GetTickCount64() < deadline) t.sleep(1);
    check(@src(), t.state.lan_peer_ack() == 43 and t.state.lan_remote_transition().native_entry == t.p.SYNC_TRANSITION_NATIVE_CYCLE);
    deadline = t.GetTickCount64() + 3000;
    while (t.state.lan_ping_us() == 0 and t.GetTickCount64() < deadline) t.sleep(1);
    check(@src(), t.state.lan_ping_us() != 0);
    const serial = t.state.lan_session_serial();
    t.state.lan_stop();
    check(@src(), t.state.lan_session_serial() > serial and t.state.lan_status() == 0);
    _ = t.ws.closesocket(peer);
    _ = t.ws.closesocket(listener);
    t.lan.lan_start(1, "");
    var client = t.ws.invalid_socket;
    deadline = t.GetTickCount64() + 3000;
    while (t.GetTickCount64() < deadline) {
        client = t.ws.socket(2, 1, 6);
        check(@src(), client != t.ws.invalid_socket);
        if (t.ws.connect(client, &t.address, @sizeOf(t.ws.Address)) == 0) break;
        _ = t.ws.closesocket(client);
        client = t.ws.invalid_socket;
        t.sleep(10);
    }
    check(@src(), client != t.ws.invalid_socket);
    defer _ = t.ws.closesocket(client);
    t.timeouts(client);
    t.hello(client);
    t.waitStatus(3);
    var invalid = t.Header{ .kind = 9, .size = 0 };
    t.transfer(client, std.mem.asBytes(&invalid), true);
    t.waitStatus(4);
    check(@src(), t.state.lan_error() == 10043);
}
