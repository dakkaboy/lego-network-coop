const std = @import("std");
const root = @import("root");
const win = @import("win32.zig");
const p = @import("protocol.zig");
const state = @import("lan_state.zig");
const ws = @import("winsock.zig");
const threads = @import("threading.zig");
const port: u16 = if (@hasDecl(root, "lan_port")) root.lan_port else 32510;
pub const hello = [_]u8{ 'L', 'S', 'W', '3', 'L', 'A', 'N', p.SYNC_PROTOCOL_VERSION, 0x71, 0x6f, 0x83, 0x6d, 0xa4, 0x89, 0x82, 0x30, 0x46, 0x4e, 0x72, 0xe7, 0x6f, 0x59, 0x35, 0xc7, 0x38, 0xb3, 0xbd, 0x35, 0x17, 0x7a, 0x91, 0x02, 0x0e, 0x3b, 0x08, 0xfe, 0x34, 0x61, 0xa9, 0xe0 };
const Request = struct { host: bool, loopback_only: bool, generation: u32, address: [64]u8 };
const Header = extern struct { magic: u32 = 0x334e414c, kind: u32, size: u32 };
extern "kernel32" fn GetProcessHeap() callconv(.winapi) usize;
extern "kernel32" fn HeapAlloc(usize, u32, usize) callconv(.winapi) usize;
extern "kernel32" fn HeapFree(usize, u32, usize) callconv(.winapi) i32;
extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
extern "kernel32" fn CreateThread(usize, usize, *const fn (usize) callconv(.winapi) u32, usize, u32, usize) callconv(.winapi) usize;
extern fn sync_frame_encode(*const p.SyncFrame, [*]u8, u32) u32;
extern fn sync_frame_decode(*p.SyncFrame, [*]const u8, u32) c_int;
extern fn sync_profile_valid(*const p.SyncProfile) c_int;
extern fn preload_input_valid(*const p.SyncPreloadInput) c_int;
extern fn preload_receipt_valid(*const p.SyncPreloadReceipt) c_int;
extern fn preload_world_ready_valid(*const p.SyncWorldReady) c_int;
fn allocate(comptime T: type, zero: bool) ?*T {
    const address = HeapAlloc(GetProcessHeap(), if (zero) 8 else 0, @sizeOf(T));
    return if (address != 0) @ptrFromInt(address) else null;
}
fn free(value: anytype) void {
    _ = HeapFree(GetProcessHeap(), 0, @intFromPtr(value));
}
fn fail(code: i32) bool {
    ws.WSASetLastError(code);
    return false;
}
fn ready(socket: usize, write: bool, ticket: u32, attempts: u32) bool {
    var remaining = attempts;
    while (state.active(ticket) and remaining > 0) : (remaining -= 1) {
        var set: ws.Set = .{};
        set.sockets[0] = socket;
        const timeout: ws.Time = .{ .seconds = 0, .microseconds = 200000 };
        const result = ws.select(0, if (write) null else &set, if (write) &set else null, null, &timeout);
        if (result != 0) return result > 0;
    }
    return fail(10060);
}
fn transfer(socket: usize, data: []u8, write: bool, ticket: u32) bool {
    var position: usize = 0;
    while (position < data.len and state.active(ticket)) {
        if (!ready(socket, write, ticket, 25)) return false;
        const remaining: i32 = @intCast(data.len - position);
        const count = if (write) ws.send(socket, data.ptr + position, remaining, 0) else ws.recv(socket, data.ptr + position, remaining, 0);
        if (count <= 0) {
            if (count == 0) ws.WSASetLastError(10054);
            return false;
        }
        position += @intCast(count);
    }
    return position == data.len;
}
fn packet(socket: usize, kind: u32, payload: []u8, ticket: u32) bool {
    var header: Header = .{ .kind = kind, .size = @intCast(payload.len) };
    return transfer(socket, std.mem.asBytes(&header), true, ticket) and transfer(socket, payload, true, ticket);
}
fn validPeer(peer: *const state.Peer) bool {
    return peer.level >= -1 and peer.level < 4096 and peer.native_entry <= p.SYNC_TRANSITION_NATIVE_CYCLE and (peer.ready == 0 or peer.ready == 1) and
        peer.loading.level >= -1 and peer.loading.level < 4096 and peer.loading.ready <= 1 and peer.loading.skip <= 1 and peer.loading.active <= 1 and peer.auto_skip <= 1 and
        std.math.isFinite(peer.loading.elapsed) and peer.loading.elapsed >= 0 and peer.loading.elapsed <= 86400 and
        preload_input_valid(&peer.preload) != 0 and preload_receipt_valid(&peer.preload_receipt) != 0 and preload_world_ready_valid(&peer.world_ready) != 0 and
        (peer.world_ready.epoch == 0 or (peer.world_ready.epoch == peer.epoch and peer.world_ready.level == peer.level)) and
        (peer.preload_seal == 0 or peer.preload_seal == peer.preload_receipt.serial) and (peer.preload.epoch == 0 or (peer.preload.epoch == peer.epoch and peer.preload.level == peer.level));
}
fn exchange(socket: usize, ticket: u32, host: bool) bool {
    const frame = allocate(p.SyncFrame, true) orelse return fail(10055);
    const wire = allocate([@sizeOf(p.SyncFrame)]u8, false) orelse {
        free(frame);
        return fail(10055);
    };
    const profile = allocate(p.SyncProfile, true) orelse {
        free(wire);
        free(frame);
        return fail(10055);
    };
    defer {
        const error_code = ws.WSAGetLastError();
        free(frame);
        free(profile);
        free(wire);
        ws.WSASetLastError(error_code);
    }
    var sent = GetTickCount() -% 20;
    var received = GetTickCount();
    var sent_epoch: u32 = 0;
    var sent_ack: u32 = 0;
    while (state.active(ticket)) {
        if (GetTickCount() -% received > 10000) return fail(10060);
        var own: state.Peer = undefined;
        const publish = state.publicationSnapshot(ticket, &own, GetTickCount() -% sent >= 20, sent_epoch, sent_ack);
        if (publish < 0) break;
        if (publish != 0) {
            if (!packet(socket, 1, std.mem.asBytes(&own), ticket)) return false;
            sent = GetTickCount();
            sent_epoch = own.epoch;
            sent_ack = own.ack;
        }
        if (state.takeProfile(ticket, profile) and !packet(socket, 3, std.mem.asBytes(profile), ticket)) return false;
        if (state.takeFrame(ticket, frame)) {
            const length = sync_frame_encode(frame, wire, wire.len);
            if (length == 0) return fail(10022);
            if (!packet(socket, 2, wire[0..length], ticket)) return false;
        }
        var set: ws.Set = .{};
        set.sockets[0] = socket;
        const timeout: ws.Time = .{ .seconds = 0, .microseconds = 1000 };
        const available = ws.select(0, &set, null, null, &timeout);
        if (available < 0) return false;
        if (available == 0) continue;
        var header: Header = undefined;
        if (!transfer(socket, std.mem.asBytes(&header), false, ticket)) return false;
        if (header.magic != 0x334e414c or (header.kind != 1 and header.kind != 2 and header.kind != 3) or
            (header.kind == 1 and header.size != @sizeOf(state.Peer)) or (header.kind == 3 and header.size != @sizeOf(p.SyncProfile)) or
            (header.kind == 2 and (header.size < @offsetOf(p.SyncFrame, "actors") or header.size > @sizeOf(p.SyncFrame)))) return fail(10043);
        switch (header.kind) {
            1 => {
                var peer: state.Peer = undefined;
                if (!transfer(socket, std.mem.asBytes(&peer), false, ticket)) return false;
                if (!validPeer(&peer)) return fail(10022);
                if (!state.sessionPeer(ticket, &peer)) break;
            },
            3 => {
                if (!transfer(socket, std.mem.asBytes(profile), false, ticket)) return false;
                if (host or sync_profile_valid(profile) == 0) return fail(10022);
                state.acceptProfile(ticket, profile);
            },
            else => {
                if (!transfer(socket, wire[0..header.size], false, ticket)) return false;
                if (host or sync_frame_decode(frame, wire, header.size) == 0) return fail(10022);
                const accepted = state.sessionInbound(ticket, frame);
                if (accepted == 0) break;
                if (accepted < 0) return fail(10055);
            },
        }
        received = GetTickCount();
    }
    return true;
}
fn workerEnter(ticket: u32) bool {
    while (state.active(ticket)) {
        if (threads.TryEnterCriticalSection(&state.worker_lock) != 0) {
            if (state.active(ticket)) return true;
            threads.LeaveCriticalSection(&state.worker_lock);
            return false;
        }
        threads.Sleep(10);
    }
    return false;
}
fn connectPeer(request: *const Request, listener: *usize, connection: *usize) i32 {
    var endpoint: ws.Address = .{ .port = @byteSwap(port) };
    if (request.host) {
        if (request.loopback_only and ws.inet_pton(2, "127.0.0.1", &endpoint.address) != 1) return 10022;
        listener.* = ws.socket(2, 1, 6);
        if (listener.* == ws.invalid_socket or ws.bind(listener.*, &endpoint, @sizeOf(ws.Address)) != 0 or ws.listen(listener.*, 1) != 0) return ws.WSAGetLastError();
        while (state.active(request.generation)) {
            if (!ready(listener.*, false, request.generation, 1)) continue;
            connection.* = ws.accept(listener.*, 0, 0);
            break;
        }
        if (!state.active(request.generation)) return 0;
    } else {
        if (ws.inet_pton(2, @ptrCast(&request.address), &endpoint.address) != 1) return 10022;
        connection.* = ws.socket(2, 1, 6);
        if (connection.* == ws.invalid_socket) return ws.WSAGetLastError();
        var nonblocking: u32 = 1;
        _ = ws.ioctlsocket(connection.*, @bitCast(@as(u32, 0x8004667e)), &nonblocking);
        if (ws.connect(connection.*, &endpoint, @sizeOf(ws.Address)) != 0 and ws.WSAGetLastError() != 10035) return ws.WSAGetLastError();
        if (!ready(connection.*, true, request.generation, 25)) return ws.WSAGetLastError();
        var failure: i32 = 0;
        var length: i32 = 4;
        _ = ws.getsockopt(connection.*, 0xffff, 0x1007, &failure, &length);
        if (failure != 0) return failure;
        nonblocking = 0;
        _ = ws.ioctlsocket(connection.*, @bitCast(@as(u32, 0x8004667e)), &nonblocking);
    }
    if (connection.* == ws.invalid_socket) return ws.WSAGetLastError();
    const timeout: u32 = 5000;
    if (ws.setsockopt(connection.*, 0xffff, 0x1005, &timeout, 4) != 0) return ws.WSAGetLastError();
    const no_delay: i32 = 1;
    _ = ws.setsockopt(connection.*, 6, 1, &no_delay, 4);
    var peer: [hello.len]u8 = undefined;
    var own = hello;
    if (!transfer(connection.*, &own, true, request.generation) or !transfer(connection.*, &peer, false, request.generation)) return ws.WSAGetLastError();
    if (!std.mem.eql(u8, &peer, &hello)) return 10043;
    if (!state.sessionStatus(request.generation, 3, 0)) return 0;
    if (!exchange(connection.*, request.generation, request.host)) return ws.WSAGetLastError();
    return 0;
}
fn runSession(parameter: usize) callconv(.winapi) u32 {
    const pointer: *Request = @ptrFromInt(parameter);
    const request = pointer.*;
    free(pointer);
    if (!workerEnter(request.generation)) return 0;
    defer threads.LeaveCriticalSection(&state.worker_lock);
    var data: [512]u8 align(8) = undefined;
    var failure = ws.WSAStartup(0x202, &data);
    if (failure == 0) {
        var listener = ws.invalid_socket;
        var connection = ws.invalid_socket;
        failure = connectPeer(&request, &listener, &connection);
        if (connection != ws.invalid_socket) _ = ws.closesocket(connection);
        if (listener != ws.invalid_socket) _ = ws.closesocket(listener);
        _ = ws.WSACleanup();
    }
    _ = state.sessionStatus(request.generation, if (failure != 0) 4 else 0, failure);
    return 0;
}
pub export fn lan_start(host: c_int, address: [*:0]const u8) void {
    start(host != 0, false, address);
}

pub fn startLoopback(host: bool) void {
    start(host, true, "127.0.0.1");
}

fn start(host: bool, loopback_only: bool, address: [*:0]const u8) void {
    state.lock();
    const ticket = state.advanceGeneration();
    if (ticket == 0) {
        @atomicStore(i32, &state.status, 4, .seq_cst);
        state.unlock();
        return;
    }
    state.reset(host);
    state.publishSession(ticket);
    state.unlock();
    const request = allocate(Request, true) orelse {
        _ = state.sessionStatus(ticket, 4, 8);
        return;
    };
    request.host = host;
    request.loopback_only = loopback_only;
    request.generation = ticket;
    for (0..request.address.len - 1) |i| {
        const value = address[i];
        request.address[i] = value;
        if (value == 0) break;
    }
    const worker = CreateThread(0, 0, runSession, @intFromPtr(request), 0, 0);
    if (worker != 0) _ = win.CloseHandle(worker) else {
        const failure = win.GetLastError();
        free(request);
        _ = state.sessionStatus(ticket, 4, @bitCast(failure));
    }
}
