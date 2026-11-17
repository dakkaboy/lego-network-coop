const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const Hash = @import("fingerprint.zig").Hash;
const types = @import("identity_types.zig");
const equal = @import("validation.zig").equal;
extern fn native_authored_poi_resolve(usize, *types.AuthoredPoi) c_int;
extern fn native_resource_identity_resolve(usize, usize, *types.ResourceIdentity) c_int;
pub const SourceKey = @import("spellit_types.zig").SourceKey;
pub const PieceKey = @import("spellit_types.zig").PieceKey;
pub const Source = @import("spellit_types.zig").Source;
pub const Piece = @import("spellit_types.zig").Piece;
pub const Body = @import("spellit_types.zig").Body;
pub const State = @import("spellit_types.zig").State;
fn ptr(address: usize, offset: usize) usize {
    return win.load(usize, address + offset);
}
fn bytes(address: usize, length: usize) []const u8 {
    return @as([*]const u8, @ptrFromInt(address))[0..length];
}
fn hashText(read: *Reader, hash: *Hash, address: usize, capacity: usize) bool {
    if (address == 0) return false;
    var length: usize = 0;
    while (length < capacity) : (length += 1) {
        if (!read.readable(address + length, 1)) return false;
        const c = win.load(u8, address + length);
        if (c == 0) break;
        if (c < 32 or c > 126) return false;
    }
    if (length == 0 or length == capacity) return false;
    hash.number(@intCast(length));
    hash.bytes(bytes(address, length));
    return true;
}
fn countedName(read: *Reader, hash: *Hash, address: usize) bool {
    if (address == 0) {
        hash.number(0);
        return true;
    }
    if (!read.readable(address, 1)) return false;
    const stored = win.load(u8, address);
    if (stored < 2 or !read.readable(address, stored)) return false;
    const length: usize = stored - 2;
    if (win.load(u8, address + length + 1) != 0) return false;
    for (bytes(address + 1, length)) |c| if (c < 32 or c > 126) return false;
    hash.number(@intCast(length + 1));
    hash.bytes(bytes(address + 1, length));
    return true;
}
fn sourceSnapshot(read: *Reader, object: usize, output: *Source) bool {
    var s = std.mem.zeroes(Source);
    if (!read.readable(object, 0x230) or !read.imageClass(object, &s.key.gizmo_class) or s.key.gizmo_class != 0x8480ac) return false;
    s.gizmo = object;
    for ([_]usize{ 0xfb4a20, 0xe90220, 0xe90184 }) |address| if (!read.readable(read.native(address), 4)) return false;
    s.world = ptr(read.native(0xfb4a20), 0);
    s.provider = ptr(read.native(0xe90220), 0);
    s.manager_registry = ptr(read.native(0xe90184), 0);
    if (!read.readable(s.world, 0x22e8) or !read.readable(s.provider, 0x3c) or !read.readable(s.manager_registry, 0x2c)) return false;
    s.container = ptr(s.world, 0x22e4);
    s.handle = ptr(s.world, 0x400);
    if (!read.readable(s.container, 0x10) or ptr(s.container, 0xc) != s.world or !read.readable(s.handle, 4)) return false;
    s.manager_index = win.load(u32, s.provider + 0x38);
    s.manager_count = win.load(u32, s.manager_registry + 0x28);
    s.table = ptr(s.handle, 0);
    if (s.manager_count == 0 or s.manager_count > 4096 or s.manager_index >= s.manager_count or !read.readable(s.table, s.manager_count * 4)) return false;
    s.manager = ptr(s.table, s.manager_index * 4);
    if (!read.readable(s.manager, 0x28) or !read.imageClass(s.manager, &s.manager_class)) return false;
    var current = ptr(s.manager, 0x24);
    var seen: u32 = 0;
    var ordinal: u32 = 0;
    while (current != 0 and ordinal < 65536) {
        if (!read.readable(current, 0x28)) return false;
        if (current == object) {
            seen += 1;
            if (seen != 1) return false;
            s.key.gizmo_ordinal = ordinal;
        }
        current = ptr(current, 0x24);
        ordinal += 1;
        if (ordinal >= 65536 and current != 0) return false;
    }
    if (seen != 1) return false;
    const table = ptr(object, 0);
    if (!read.readable(table, 0x140) or ptr(table, 0xf4) != read.native(0x823340) or ptr(table, 0x13c) != read.native(0x823350)) return false;
    s.scene = ptr(object, 0xb4);
    s.piece_head = ptr(object, 0xa8);
    s.piece_tail = ptr(object, 0xac);
    s.piece_count = win.load(u32, object + 0xb0);
    s.adapter = ptr(object, 0x84);
    s.adapter_count = win.load(u32, object + 0x88);
    s.counted_name = ptr(object, 0xc);
    if (!read.readable(s.scene, 0x30) or s.piece_count > 65536 or s.adapter_count != s.piece_count or (s.adapter_count != 0 and !read.readable(s.adapter, s.adapter_count * 8))) return false;
    var hash: Hash = .{};
    if (!hashText(read, &hash, s.world + 0x81, 1024) or !hashText(read, &hash, object + 0x30, 32) or !countedName(read, &hash, s.counted_name)) return false;
    hash.number(s.manager_class);
    hash.number(s.key.gizmo_class);
    hash.number(s.key.gizmo_ordinal);
    s.key.name = hash.words;
    output.* = s;
    return true;
}
fn pieceSnapshot(s: *const Source, value: usize, output: *Piece) bool {
    var read = Reader.init();
    var p = std.mem.zeroes(Piece);
    var current = s.piece_head;
    var previous: usize = 0;
    var index: u32 = 0;
    var matches: u32 = 0;
    while (current != 0 and index < s.piece_count) : (index += 1) {
        if (!read.readable(current, 0x120) or ptr(current, 0) != previous or ptr(current, 0xfc) != s.gizmo) return false;
        if (current == value) {
            matches += 1;
            p.key.piece_ordinal = index;
            p.previous = previous;
            p.next = ptr(current, 4);
        }
        previous = current;
        current = ptr(current, 4);
    }
    if (current != 0 or index != s.piece_count or previous != s.piece_tail or matches != 1) return false;
    p.piece = value;
    p.source_entity = ptr(value, 0xf0);
    p.model = ptr(value, 0x100);
    p.live_record = ptr(value, 8);
    if (!read.readable(p.model, 0x5c) or !read.readable(p.source_entity, 0x1c) or ptr(p.source_entity, 8) != p.model) return false;
    var entity = ptr(s.scene, 0x2c);
    var found: u32 = 0;
    var n: u32 = 0;
    while (entity != 0 and n < 65536) : (n += 1) {
        if (!read.readable(entity, 0x1c)) return false;
        found += @intFromBool(entity == p.source_entity);
        entity = ptr(entity, 4);
    }
    if (entity != 0 or found != 1 or s.adapter == 0 or p.key.piece_ordinal >= s.adapter_count) return false;
    const pair = s.adapter + p.key.piece_ordinal * 8;
    if (ptr(pair, 0) != p.live_record or ptr(pair, 4) != p.model or !read.readable(p.live_record, 0x18) or ptr(p.live_record, 8) != p.model or native_authored_poi_resolve(p.model, &p.authored) == 0) return false;
    p.receiver = p.authored.receiver;
    p.key.receiver_class = p.authored.chain[0].receiver_class;
    p.poi = p.authored.poi;
    p.array = p.authored.array;
    p.key.poi_count = p.authored.poi_count;
    p.key.poi_ordinal = p.authored.poi_ordinal;
    p.authored_receiver_class = p.authored.receiver_class;
    p.chain_count = p.authored.chain_count;
    p.poi_name = ptr(p.poi, 0xb4);
    for (p.authored.chain[0..p.chain_count], 0..) |link, i| {
        p.models[i] = link.model;
        p.receivers[i] = link.receiver;
        p.chain_resources[i] = link.resource;
        p.chain_pois[i] = link.poi;
    }
    var name: Hash = .{};
    if (!hashText(&read, &name, p.poi_name, 1024) or native_resource_identity_resolve(s.world, p.authored.resource, &p.resource_identity) == 0) return false;
    const identity = &p.resource_identity;
    if (identity.runtime != p.authored.runtime or identity.array != p.authored.array) return false;
    p.resource = identity.actual_resource;
    p.root_resource = identity.root_resource;
    p.runtime = identity.runtime;
    p.registry = identity.registry;
    p.entry = identity.entry;
    p.container = identity.container;
    p.source_world = identity.source_world;
    p.filename = identity.filename;
    p.logical_name = identity.name;
    p.key.resource = identity.key;
    p.key.poi_name = name.words;
    output.* = p;
    return true;
}
fn inputOf(s: *const Source) usize {
    return s.gizmo;
}
const Capture = @import("snapshot.zig").Snapshot(Source, usize, sourceSnapshot, inputOf);
pub export fn native_spellit_source_resolve(object: usize, out: ?*Source) c_int {
    return Capture.resolve(object, out);
}
pub export fn native_spellit_source_revalidate(source: ?*const Source) c_int {
    return Capture.revalidate(source);
}
pub export fn native_spellit_piece_resolve(source: ?*const Source, piece: usize, output: ?*Piece) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = source orelse return 0;
    const out = output orelse return 0;
    if (native_spellit_source_revalidate(s) == 0) return 0;
    var first: Piece = undefined;
    var second: Piece = undefined;
    if (!pieceSnapshot(s, piece, &first) or !pieceSnapshot(s, piece, &second) or !equal(&first, &second) or native_spellit_source_revalidate(s) == 0) return 0;
    out.* = first;
    return 1;
}
pub export fn native_spellit_piece_revalidate(source: ?*const Source, piece: ?*const Piece) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const p = piece orelse return 0;
    var now: Piece = undefined;
    return @intFromBool(native_spellit_piece_resolve(source, p.piece, &now) != 0 and equal(p, &now));
}
pub export fn native_spellit_selection_snapshot(source: ?*const Source, count: ?*u32, eligibility: ?*[4]u32) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = source orelse return 0;
    const output = count orelse return 0;
    const key = eligibility orelse return 0;
    if (native_spellit_source_revalidate(s) == 0) return 0;
    var read = Reader.init();
    var hash: Hash = .{};
    var node = s.piece_head;
    var previous: usize = 0;
    var index: u32 = 0;
    var candidates: u32 = 0;
    while (node != 0 and index < s.piece_count) : (index += 1) {
        if (!read.readable(node, 0x114) or ptr(node, 0) != previous or ptr(node, 0xfc) != s.gizmo) return 0;
        const eligible: u32 = @intFromBool(win.load(u32, node + 0x110) != 3);
        hash.number(index);
        hash.number(eligible);
        candidates += eligible;
        previous = node;
        node = ptr(node, 4);
    }
    if (node != 0 or index != s.piece_count or previous != s.piece_tail or native_spellit_source_revalidate(s) == 0) return 0;
    output.* = candidates;
    key.* = hash.words;
    return 1;
}
pub export fn native_spellit_body_resolve(source: ?*const Source, value: usize, output: ?*Body) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = source orelse return -1;
    const out = output orelse return -1;
    var p: Piece = undefined;
    if (native_spellit_piece_resolve(s, value, &p) == 0) return -1;
    var read = Reader.init();
    var b = std.mem.zeroes(Body);
    b.piece = value;
    b.model = p.model;
    b.piece_ordinal = p.key.piece_ordinal;
    if (win.load(u16, b.model + 0x5a) & 0x200 == 0) {
        out.* = b;
        return 0;
    }
    b.receiver = ptr(b.model, 0x3c);
    if (!read.readable(b.receiver, 0x1a4)) return -1;
    b.body = ptr(b.receiver, 0x1a0);
    if (b.body == 0 or b.body == std.math.maxInt(usize)) {
        b.body = 0;
        out.* = b;
        return 0;
    }
    if (!read.readable(b.body, 0xa0) or !read.imageClass(b.body, &b.body_class)) return -1;
    b.dynamics = ptr(b.body, 0x98);
    b.name = ptr(b.body, 0x1c);
    if (b.dynamics == 0) {
        out.* = b;
        return 0;
    }
    if (!read.readable(b.dynamics, 0x50)) return -1;
    var name: Hash = .{};
    if (!hashText(&read, &name, b.name, 128)) return -1;
    b.name_key = name.words;
    var hash: Hash = .{};
    hash.bytes(std.mem.asBytes(&s.key));
    hash.bytes(std.mem.asBytes(&p.key));
    hash.bytes(std.mem.asBytes(&b.name_key));
    hash.number(b.body_class);
    b.key = hash.words;
    out.* = b;
    return 1;
}
pub export fn native_spellit_body_matches(source: ?*const Source, body: ?*const Body) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = source orelse return 0;
    const b = body orelse return 0;
    var read = Reader.init();
    if (!read.readable(b.piece, 0x104) or ptr(b.piece, 0xfc) != s.gizmo or ptr(b.piece, 0x100) != b.model or !read.readable(b.model, 0x5c)) return 0;
    if (win.load(u16, b.model + 0x5a) & 0x200 == 0) return @intFromBool(b.receiver == 0 and b.body == 0 and b.dynamics == 0);
    if (ptr(b.model, 0x3c) != b.receiver or !read.readable(b.receiver, 0x1a4)) return 0;
    const current = ptr(b.receiver, 0x1a0);
    if (current == 0 or current == std.math.maxInt(usize)) return @intFromBool(b.body == 0 and b.dynamics == 0);
    var class: u32 = undefined;
    if (current != b.body or !read.readable(current, 0xa0) or !read.imageClass(current, &class) or class != b.body_class or ptr(current, 0x98) != b.dynamics or ptr(current, 0x1c) != b.name) return 0;
    if (b.dynamics == 0) return 1;
    var name: Hash = .{};
    return @intFromBool(read.readable(b.dynamics, 0x50) and hashText(&read, &name, b.name, 128) and equal(&name.words, &b.name_key));
}
pub export fn native_spellit_body_read(source: ?*const Source, body: ?*const Body, output: ?*State) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const b = body orelse return 0;
    const out = output orelse return 0;
    if (b.dynamics == 0 or native_spellit_body_matches(source, b) == 0) return 0;
    out.* = .{ .basis = win.load([12]f32, b.body + 0x40), .position = win.load([4]f32, b.body + 0x70), .linear = win.load([4]f32, b.dynamics + 0x20), .angular = win.load([4]f32, b.dynamics + 0x30) };
    return 1;
}
pub const Live = @import("spellit_types.zig").Live;
fn restore(machine: *const [512]u8) void {
    @import("machine_environment.zig").restoreFx(machine);
}
pub export fn native_spellit_body_apply(source: ?*const Source, body: ?*const Body, state: ?*const State, live: ?Live, context: usize) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    const s = state orelse return 0;
    const check = live orelse return 0;
    if (check(context) == 0) return 0;
    const b = body orelse return 0;
    const finite = @import("validation.zig").finite;
    if (b.dynamics == 0 or native_spellit_body_matches(source, b) == 0 or
        !finite(s.basis) or !finite(s.position) or !finite(s.linear[0..3].*) or !finite(s.angular[0..3].*)) return 0;
    var machine: [512]u8 align(16) = undefined;
    asm volatile ("fxsave (%[buffer])"
        :
        : [buffer] "r" (&machine),
        : .{ .memory = true });
    defer restore(&machine);
    const Apply = *const fn (usize, [*]const f32) callconv(.{ .x86_thiscall = .{} }) void;
    var read = Reader.init();
    var matrix: [16]f32 = undefined;
    @memcpy(matrix[0..12], &s.basis);
    @memcpy(matrix[12..16], &s.position);
    restore(&machine);
    @as(Apply, @ptrFromInt(read.native(0xa29570)))(b.body, &matrix);
    if (check(context) == 0 or native_spellit_body_matches(source, b) == 0) return 0;
    restore(&machine);
    @as(Apply, @ptrFromInt(read.native(0x8b5cd0)))(b.model, &s.linear);
    if (check(context) == 0 or native_spellit_body_matches(source, b) == 0) return 0;
    restore(&machine);
    @as(Apply, @ptrFromInt(read.native(0x8b5e00)))(b.model, &s.angular);
    return @intFromBool(check(context) != 0 and native_spellit_body_matches(source, b) != 0);
}
