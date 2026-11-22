pub const invalid_socket: usize = @import("std").math.maxInt(usize);
pub const Set = extern struct { count: u32 = 1, sockets: [64]usize = @splat(0) };
pub const Time = extern struct { seconds: i32, microseconds: i32 };
pub const Address = extern struct { family: u16 = 2, port: u16 = 0, address: u32 = 0, padding: [8]u8 = @splat(0) };
const TcpInfo = extern struct {
    state: u32,
    mss: u32,
    connection_time_ms: u64,
    timestamps_enabled: u8,
    rtt_us: u32,
    min_rtt_us: u32,
    bytes_in_flight: u32,
    cwnd: u32,
    send_window: u32,
    receive_window: u32,
    receive_buffer: u32,
    bytes_out: u64,
    bytes_in: u64,
    bytes_reordered: u32,
    bytes_retransmitted: u32,
    fast_retransmits: u32,
    duplicate_acks: u32,
    timeout_episodes: u32,
    syn_retransmits: u8,
};
const sio_tcp_info = 0xd8000027;
extern "ws2_32" fn WSAIoctl(usize, u32, *const u32, u32, *TcpInfo, u32, *u32, usize, usize) callconv(.winapi) i32;

pub fn roundTripUs(connection: usize) u32 {
    const version: u32 = 0;
    var info: TcpInfo = undefined;
    var returned: u32 = 0;
    if (WSAIoctl(connection, sio_tcp_info, &version, @sizeOf(u32), &info, @sizeOf(TcpInfo), &returned, 0, 0) != 0 or
        returned < @offsetOf(TcpInfo, "rtt_us") + @sizeOf(u32)) return 0;
    return info.rtt_us;
}

pub extern "ws2_32" fn WSAStartup(u16, *anyopaque) callconv(.winapi) i32;
pub extern "ws2_32" fn WSACleanup() callconv(.winapi) i32;
pub extern "ws2_32" fn WSAGetLastError() callconv(.winapi) i32;
pub extern "ws2_32" fn WSASetLastError(i32) callconv(.winapi) void;
pub extern "ws2_32" fn socket(i32, i32, i32) callconv(.winapi) usize;
pub extern "ws2_32" fn bind(usize, *const Address, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn listen(usize, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn accept(usize, usize, usize) callconv(.winapi) usize;
pub extern "ws2_32" fn connect(usize, *const Address, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn closesocket(usize) callconv(.winapi) i32;
pub extern "ws2_32" fn select(i32, ?*Set, ?*Set, ?*Set, *const Time) callconv(.winapi) i32;
pub extern "ws2_32" fn send(usize, [*]const u8, i32, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn recv(usize, [*]u8, i32, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn ioctlsocket(usize, i32, *u32) callconv(.winapi) i32;
pub extern "ws2_32" fn getsockopt(usize, i32, i32, *anyopaque, *i32) callconv(.winapi) i32;
pub extern "ws2_32" fn setsockopt(usize, i32, i32, *const anyopaque, i32) callconv(.winapi) i32;
pub extern "ws2_32" fn inet_pton(i32, [*:0]const u8, *u32) callconv(.winapi) i32;
