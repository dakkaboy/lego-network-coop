const std = @import("std");

const Wire = [40]u8;

const Fields = extern struct {
    context: u64,
    identity: u64,
    session: u64,
    sequence: u32,
    buttons: u16,
    x: i16,
    y: i16,
    version: u8,
    kind: u8,
};

export fn saga_encode_packet(bytes: *Wire, packet: *const Fields) void {
    bytes[0..4].* = "LSCS".*;
    bytes[4] = packet.version;
    bytes[5] = packet.kind;
    std.mem.writeInt(u16, bytes[6..8], packet.buttons, .big);
    std.mem.writeInt(u64, bytes[8..16], packet.context, .big);
    std.mem.writeInt(u64, bytes[16..24], packet.identity, .big);
    std.mem.writeInt(u64, bytes[24..32], packet.session, .big);
    std.mem.writeInt(u32, bytes[32..36], packet.sequence, .big);
    std.mem.writeInt(i16, bytes[36..38], packet.x, .big);
    std.mem.writeInt(i16, bytes[38..40], packet.y, .big);
}

const HostAdmission = extern struct {
    build: u64,
    nonce: u64,
    session: u64,
    generation: u64,
    room: u64,
    last_input: u32,
    version: u8,
    has_peer: bool,
    matching_peer: bool,
};
const HostDecision = enum(u8) { ignore, incompatible, welcome, input };

export fn saga_host_admit(host: *const HostAdmission, packet: *const Fields) HostDecision {
    if (host.build == 0 or host.session == 0) return .ignore;
    switch (packet.kind) {
        1 => {
            if (packet.version != host.version or packet.context != host.build) return .incompatible;
            if (host.has_peer and (!host.matching_peer or host.nonce != packet.identity)) return .ignore;
            return .welcome;
        },
        4 => {
            if (packet.version != host.version or !host.matching_peer or packet.session != host.session or
                host.room == 0 or packet.context != host.generation or packet.sequence <= host.last_input)
            {
                return .ignore;
            }
            return .input;
        },
        else => return .ignore,
    }
}

const ClientAdmission = extern struct {
    build: u64,
    nonce: u64,
    session: u64,
    generation: u64,
    last_sequence: u32,
    version: u8,
    connected: bool,
    scene_ready: bool,
};

export fn saga_client_admit(client: *const ClientAdmission, packet: *const Fields) bool {
    if (!client.connected) {
        return packet.identity == client.nonce and
            (packet.kind == 3 or
                (packet.kind == 2 and packet.context == client.build and packet.version == client.version));
    }
    if (packet.session != client.session or packet.version != client.version) return false;
    return switch (packet.kind) {
        5 => packet.context > client.generation,
        6, 7, 10, 11 => client.scene_ready and packet.context == client.generation and
            packet.sequence > client.last_sequence,
        8, 9 => packet.sequence > client.last_sequence,
        else => false,
    };
}

fn validCoordinate(bits: u32) bool {
    return @abs(@as(f32, @bitCast(bits))) <= 100000.0;
}

export fn saga_decode_packet(bytes: *const Wire, output: *Fields) bool {
    if (!std.mem.eql(u8, bytes[0..4], "LSCS") or bytes[4] == 0) return false;

    const packet: Fields = .{
        .context = std.mem.readInt(u64, bytes[8..16], .big),
        .identity = std.mem.readInt(u64, bytes[16..24], .big),
        .session = std.mem.readInt(u64, bytes[24..32], .big),
        .sequence = std.mem.readInt(u32, bytes[32..36], .big),
        .buttons = std.mem.readInt(u16, bytes[6..8], .big),
        .x = std.mem.readInt(i16, bytes[36..38], .big),
        .y = std.mem.readInt(i16, bytes[38..40], .big),
        .version = bytes[4],
        .kind = bytes[5],
    };
    const empty_input = packet.sequence == 0 and packet.buttons == 0 and packet.x == 0 and packet.y == 0;
    const valid = switch (packet.kind) {
        1, 2, 3 => packet.context != 0 and packet.identity != 0 and empty_input and
            (packet.session != 0) == (packet.kind == 2),
        4, 6 => packet.context != 0 and packet.identity == 0 and packet.session != 0 and packet.sequence != 0,
        5 => packet.context != 0 and packet.session != 0 and empty_input,
        7 => packet.context != 0 and packet.session != 0 and packet.sequence != 0 and
            packet.buttons & 0x8080 == 0 and
            (packet.identity >> 32) + (packet.identity & 0xffffffff) <= 0x7fffffff,
        8 => packet.context != 0 and packet.session != 0 and packet.sequence != 0 and
            (packet.buttons < 6 or packet.buttons == 0xffff) and packet.x == 0 and packet.y == 0 and
            packet.identity >> 32 < 0x48 and packet.identity & 0xffffffff < 0x16d,
        9 => packet.session != 0 and packet.sequence != 0 and packet.x == 0 and packet.y == 0,
        10, 11 => packet.context != 0 and packet.session != 0 and packet.sequence != 0 and
            validCoordinate(@truncate(packet.identity >> 32)) and validCoordinate(@truncate(packet.identity)) and
            validCoordinate((@as(u32, @as(u16, @bitCast(packet.x))) << 16) | @as(u16, @bitCast(packet.y))),
        else => false,
    };
    if (!valid) return false;
    output.* = packet;
    return true;
}

test "input datagram uses protocol byte order" {
    const input: Fields = .{
        .context = 0x0102030405060708,
        .identity = 0,
        .session = 0x1112131415161718,
        .sequence = 0x21222324,
        .buttons = 0x3132,
        .x = -32768,
        .y = 32767,
        .version = 8,
        .kind = 4,
    };
    var bytes: Wire = undefined;
    saga_encode_packet(&bytes, &input);
    try std.testing.expectEqualSlices(u8, &.{
        'L',  'S',  'C',  'S',  8,    4,    0x31, 0x32,
        1,    2,    3,    4,    5,    6,    7,    8,
        0,    0,    0,    0,    0,    0,    0,    0,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x21, 0x22, 0x23, 0x24, 0x80, 0,    0x7f, 0xff,
    }, &bytes);

    var decoded: Fields = undefined;
    try std.testing.expect(saga_decode_packet(&bytes, &decoded));
    try std.testing.expectEqual(input, decoded);
    bytes[23] = 1;
    try std.testing.expect(!saga_decode_packet(&bytes, &decoded));
}

const host_keys = [_]struct { scan: u8, button: u16 }{
    .{ .scan = 0x1e, .button = 0x0004 }, // A
    .{ .scan = 0x20, .button = 0x0008 }, // D
    .{ .scan = 0x11, .button = 0x0001 }, // W
    .{ .scan = 0x1f, .button = 0x0002 }, // S
    .{ .scan = 0x24, .button = 0x8000 }, // J
    .{ .scan = 0x16, .button = 0x4000 }, // U
    .{ .scan = 0x23, .button = 0x2000 }, // H
    .{ .scan = 0x25, .button = 0x0200 }, // K
};

export fn saga_host_buttons(keys: *const [256]u8) u16 {
    var buttons: u16 = 0;
    for (host_keys) |binding| {
        if (keys[binding.scan] & 0x80 != 0) buttons |= binding.button;
    }
    return buttons;
}

test "host input carries attack and tag independently of jump" {
    var keys = [_]u8{0} ** 256;
    keys[0x23] = 0x80;
    keys[0x25] = 0x81;
    keys[0x16] = 0x01;
    try std.testing.expectEqual(@as(u16, 0x2200), saga_host_buttons(&keys));
}

const KeyBinding = struct { button: u16, scan: u8 };
const player_one_common = [_]KeyBinding{.{ .button = 0x8000, .scan = 0x24 }};
const player_one_gameplay = [_]KeyBinding{
    .{ .button = 0x4000, .scan = 0x16 },
    .{ .button = 0x2000, .scan = 0x23 },
    .{ .button = 0x0200, .scan = 0x25 },
};
const player_two_actions = [_]KeyBinding{
    .{ .button = 0x8000, .scan = 0x50 },
    .{ .button = 0x0010, .scan = 0x3c },
    .{ .button = 0x4000, .scan = 0x4f },
    .{ .button = 0x1000, .scan = 0x4c },
    .{ .button = 0x0200, .scan = 0x51 },
};

fn applyBindings(keys: *[256]u8, buttons: u16, bindings: []const KeyBinding) void {
    for (bindings) |binding| {
        if (buttons & binding.button != 0) keys[binding.scan] = 0x80;
    }
}

export fn saga_apply_remote_input(
    keys: *[256]u8,
    buttons: u16,
    x: i16,
    y: i16,
    player_two: bool,
    gameplay: bool,
) void {
    const directions: [4]u8 = if (player_two)
        .{ 0xcb, 0xcd, 0xc8, 0xd0 }
    else
        .{ 0x1e, 0x20, 0x11, 0x1f };
    const threshold = 12000;
    if (x < -threshold or buttons & 0x0004 != 0) keys[directions[0]] = 0x80;
    if (x > threshold or buttons & 0x0008 != 0) keys[directions[1]] = 0x80;
    if (y > threshold or buttons & 0x0001 != 0) keys[directions[2]] = 0x80;
    if (y < -threshold or buttons & 0x0002 != 0) keys[directions[3]] = 0x80;
    if (player_two) {
        applyBindings(keys, buttons, &player_two_actions);
    } else {
        applyBindings(keys, buttons, &player_one_common);
        if (gameplay) applyBindings(keys, buttons, &player_one_gameplay);
    }
}

test "remote jump cannot confirm a story menu" {
    var keys = [_]u8{0} ** 256;
    saga_apply_remote_input(&keys, 0xe204, 0, 13000, false, false);
    try std.testing.expectEqual(@as(u8, 0x80), keys[0x11]);
    try std.testing.expectEqual(@as(u8, 0x80), keys[0x1e]);
    try std.testing.expectEqual(@as(u8, 0x80), keys[0x24]);
    try std.testing.expectEqual(@as(u8, 0), keys[0x16] | keys[0x23] | keys[0x25]);
    saga_apply_remote_input(&keys, 0x6200, 0, 0, false, true);
    try std.testing.expectEqual(@as(u8, 0x80), keys[0x16] & keys[0x23] & keys[0x25]);
}

test "player two input uses its own keys and preserves native keys" {
    var keys = [_]u8{0} ** 256;
    keys[0x16] = 0x81;
    saga_apply_remote_input(&keys, 0xd210, 13000, -14000, true, true);
    for ([_]u8{ 0xcd, 0xd0, 0x3c, 0x4c, 0x4f, 0x50, 0x51 }) |scan| {
        try std.testing.expectEqual(@as(u8, 0x80), keys[scan]);
    }
    try std.testing.expectEqual(@as(u8, 0x81), keys[0x16]);
}

export fn saga_room_key(path: *const [128]u8) u64 {
    if (path[0] == 0) return 0;
    var hash: u64 = 14695981039346656037;
    for (path) |byte| {
        if (byte == 0) return hash;
        if (byte < ' ' or byte > '~') return 0;
        const normalized = if (byte == '\\') '/' else std.ascii.toLower(byte);
        hash = (hash ^ normalized) *% 1099511628211;
    }
    return 0;
}

test "native room identity matches live scene publications" {
    var path = [_]u8{0} ** 128;
    const cantina = "levels\\Map\\Map\\Map";
    @memcpy(path[0..cantina.len], cantina);
    try std.testing.expectEqual(@as(u64, 0xf0f73874e101f85b), saga_room_key(&path));

    const negotiations = "levels\\Episode_I\\Negotiations\\Negotiations_a\\Negotiations_a";
    @memcpy(path[0..negotiations.len], negotiations);
    try std.testing.expectEqual(@as(u64, 0x51f36ceb3fcce161), saga_room_key(&path));

    path[2] = 0x1f;
    try std.testing.expectEqual(@as(u64, 0), saga_room_key(&path));
    @memset(&path, 'A');
    try std.testing.expectEqual(@as(u64, 0), saga_room_key(&path));
    path[0] = 0;
    try std.testing.expectEqual(@as(u64, 0), saga_room_key(&path));
}

export fn saga_living_health_update(current: u8, desired: u8, maximum: u8, actor_flags: u32) u8 {
    if (actor_flags & 0x1001 != 0x1001 or current == 0 or desired == 0 or current == desired or
        current > maximum or desired > maximum) return 0;
    return desired;
}

test "health correction preserves lifecycle boundaries" {
    try std.testing.expectEqual(@as(u8, 2), saga_living_health_update(3, 2, 4, 0x1001));
    try std.testing.expectEqual(@as(u8, 4), saga_living_health_update(2, 4, 4, 0x1001));
    try std.testing.expectEqual(@as(u8, 0), saga_living_health_update(0, 4, 4, 0x1001));
    try std.testing.expectEqual(@as(u8, 0), saga_living_health_update(3, 0, 4, 0x1001));
    try std.testing.expectEqual(@as(u8, 0), saga_living_health_update(3, 5, 4, 0x1001));
    try std.testing.expectEqual(@as(u8, 0), saga_living_health_update(3, 2, 4, 0x1000));
    try std.testing.expectEqual(@as(u8, 0), saga_living_health_update(3, 3, 4, 0x1001));
}

const Campaign = extern struct {
    completed: u64,
    unlocked: u64,
    tail: u16,
};
const CampaignTable = [72 * 12]u8;

export fn saga_read_campaign(table: *const CampaignTable, progress: *Campaign) void {
    progress.* = .{ .completed = 0, .unlocked = 0, .tail = 0 };
    for (0..72) |area| {
        const record = table[area * 12 ..][0..2];
        if (area < 64) {
            const bit = @as(u64, 1) << @as(u6, @intCast(area));
            if (record[0] == 1) progress.unlocked |= bit;
            if (record[1] == 1) progress.completed |= bit;
        } else {
            const bit = @as(u16, 1) << @as(u4, @intCast(area - 64));
            if (record[0] == 1) progress.tail |= bit;
            if (record[1] == 1) progress.tail |= bit << 8;
        }
    }
}

export fn saga_merge_campaign(table: *CampaignTable, progress: *const Campaign) bool {
    var changed = false;
    for (0..72) |area| {
        const unlocked = if (area < 64)
            progress.unlocked >> @as(u6, @intCast(area)) & 1
        else
            progress.tail >> @as(u4, @intCast(area - 64)) & 1;
        const completed = if (area < 64)
            progress.completed >> @as(u6, @intCast(area)) & 1
        else
            progress.tail >> @as(u4, @intCast(area - 56)) & 1;
        const record = table[area * 12 ..][0..2];
        if (unlocked != 0 and record[0] == 0) {
            record[0] = 1;
            changed = true;
        }
        if (completed != 0 and record[1] == 0) {
            record[1] = 1;
            changed = true;
        }
    }
    return changed;
}

test "campaign merges only the chapter flags and preserves local achievements" {
    var host: CampaignTable = @splat(0);
    host[1] = 1;
    host[71 * 12] = 1;
    host[71 * 12 + 1] = 1;
    var packet: Campaign = undefined;
    saga_read_campaign(&host, &packet);
    var peer: CampaignTable = @splat(0);
    peer[12] = 1;
    peer[2] = 13;
    try std.testing.expect(saga_merge_campaign(&peer, &packet));
    try std.testing.expect(!saga_merge_campaign(&peer, &packet));
    try std.testing.expectEqual(@as(u8, 1), peer[12]);
    try std.testing.expectEqual(@as(u8, 13), peer[2]);
    try std.testing.expectEqual(@as(u8, 1), peer[1]);
    try std.testing.expectEqual(@as(u8, 1), peer[71 * 12 + 1]);
}
