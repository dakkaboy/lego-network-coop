const t = @import("lan_test_support.zig");
pub const panic = @import("safety.zig").panic;
pub const lan_port: u16 = 32521;
pub fn main() void {
    t.initialize();
    defer _ = t.ws.WSACleanup();
    const listener = t.listen();
    defer _ = t.ws.closesocket(listener);
    t.lan.lan_start(0, "127.0.0.1");
    defer t.state.lan_stop();
    const peer = t.accept(listener);
    defer _ = t.ws.closesocket(peer);
    var hello: [40]u8 = undefined;
    t.transfer(peer, &hello, false);
    t.check(@src(), hello[7] == t.p.SYNC_PROTOCOL_VERSION);
    hello[7] -= 1;
    t.transfer(peer, &hello, true);
    t.waitStatus(4);
    t.check(@src(), t.state.lan_error() == 10043);
}
