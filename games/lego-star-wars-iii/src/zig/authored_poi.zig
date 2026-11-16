const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
pub const Source = @import("identity_types.zig").AuthoredPoi;
fn snapshot(read: *Reader, value: usize, output: *Source) bool {
    var s = std.mem.zeroes(Source);
    s.model = value;
    var model = value;
    for (&s.chain, 0..) |*link, depth| {
        if (!read.readable(model, 0x5c)) return false;
        link.model = model;
        link.receiver = win.load(usize, model + 0x3c);
        if (!read.readable(link.receiver, 0x34) or !read.imageClass(link.receiver, &link.receiver_class)) return false;
        for (s.chain[0..depth]) |previous| if (previous.model == model or previous.receiver == link.receiver) return false;
        link.parent = win.load(usize, model + 0x48);
        link.model_flags = win.load(u16, model + 0x5a);
        link.receiver_model = win.load(usize, link.receiver + 0x18);
        link.resource = win.load(usize, link.receiver + 0x2c);
        link.poi = win.load(usize, link.receiver + 0x30);
        if (depth == 0) s.receiver = link.receiver;
        s.chain_count = @intCast(depth + 1);
        if (read.readable(link.resource, 0x738)) {
            link.runtime = win.load(usize, link.resource + 0x6f8);
            if (read.readable(link.runtime, 0x70)) {
                link.readable_fields |= 1;
                link.array = win.load(usize, link.runtime + 0x6c);
                link.poi_count = win.load(u32, link.runtime + 0x68);
            }
        }
        if (read.readable(link.poi, 0xe0)) {
            link.readable_fields |= 2;
            link.poi_receiver = win.load(usize, link.poi + 0xd4);
        }
        if (link.readable_fields == 3 and link.poi_count > 0 and link.poi_count <= 65536 and link.array != 0 and link.poi >= link.array and
            @as(u64, link.poi - link.array) < @as(u64, link.poi_count) * 0xe0 and (link.poi - link.array) % 0xe0 == 0 and link.poi_receiver == link.receiver)
        {
            s.authored_model = model;
            s.authored_receiver = link.receiver;
            s.resource = link.resource;
            s.runtime = link.runtime;
            s.array = link.array;
            s.poi = link.poi;
            s.poi_count = link.poi_count;
            s.poi_ordinal = @intCast((link.poi - link.array) / 0xe0);
            s.receiver_class = link.receiver_class;
            output.* = s;
            return true;
        }
        // Runtime clones share the authored POI; its D4 backlink belongs to the original receiver.
        if (link.model_flags & 1 == 0 or link.receiver_model != model or link.parent == 0) return false;
        model = link.parent;
    }
    return false;
}
fn inputOf(source: *const Source) usize {
    return source.model;
}
const Capture = @import("snapshot.zig").Snapshot(Source, usize, snapshot, inputOf);
pub export fn native_authored_poi_resolve(model: usize, output: ?*Source) c_int {
    return Capture.resolve(model, output);
}
pub export fn native_authored_poi_revalidate(witness: ?*const Source) c_int {
    return Capture.revalidate(witness);
}
