const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const equal = @import("validation.zig").equal;
const guard = @import("seh_guard.zig");
const types = @import("script_shoot_types.zig");
pub const Input = types.Input;
pub const Source = types.Source;
pub const Dispatch = types.Dispatch;
fn hashByte(hash: *[4]u32, value: u8) void {
    inline for (.{ 16777619, 2246822519, 3266489917, 668265263 }, 0..) |prime, i| hash[i] = (hash[i] ^ value) *% prime;
}
fn hashWord(hash: *[4]u32, value: u32) void {
    inline for (0..4) |i| hashByte(hash, @truncate(value >> (i * 8)));
}
fn argumentHash(read: *Reader, address: usize, count: u32, hash: *[4]u32) bool {
    hash.* = .{ 2166136261, 0x9e3779b9, 0x85ebca6b, 0xc2b2ae35 };
    hashWord(hash, count);
    if (count == 0) return true;
    if (count > 256 or !read.readable(address, count * 4)) return false;
    for (0..count) |i| {
        const text = win.load(usize, address + i * 4);
        var length: usize = 0;
        while (length < 4096) : (length += 1) {
            if (!read.readable(text + length, 1)) return false;
            if (win.load(u8, text + length) == 0) break;
        }
        if (length == 4096) return false;
        hashWord(hash, @intCast(length));
        for (0..length) |j| hashByte(hash, win.load(u8, text + j));
    }
    return true;
}
fn world(read: *Reader, s: anytype) bool {
    for ([_]usize{ 0xfb4a20, 0xfb2f60, 0xfb2e3c, 0xfb4b6c }) |address| if (!read.readable(address, 4)) return false;
    s.world = win.load(usize, 0xfb4a20);
    if (!read.readable(s.world, 0x224)) return false;
    s.definition = win.load(usize, s.world + 0x220);
    if (!read.readable(s.definition, 0x96)) return false;
    s.actor_pool = win.load(usize, 0xfb2f60);
    s.actor_count = win.load(u32, 0xfb2e3c);
    return true;
}
fn actorInput(read: *Reader, s: anytype, caller: u32) bool {
    if (s.actor_pool == 0 or s.actor_count == 0 or s.actor_count > 4096 or s.actor < s.actor_pool or (s.actor - s.actor_pool) % 0x1440 != 0) return false;
    s.actor_ordinal = @intCast((s.actor - s.actor_pool) / 0x1440);
    if (s.actor_ordinal >= s.actor_count or !read.readable(s.actor, 0x1440) or !read.readable(s.model, 0x44) or !read.readable(s.state, 0xa8)) return false;
    s.brain = win.load(usize, s.model + 0x34);
    if (!read.readable(s.brain, 0x19c) or !read.imageClass(s.model, &s.input.model_class) or !read.imageClass(s.brain, &s.input.brain_class) or
        !read.imageClass(s.state, &s.input.state_class) or !read.imageAddress(caller, &s.input.caller_rva, true)) return false;
    s.brain_admission_raw = win.load(u32, s.brain + 0x198);
    if (s.brain_admission_raw == 0) return false;
    s.input.brain_admission = 1;
    s.input.clock = win.load(u32, 0xfb4b6c);
    return true;
}
fn snapshot(actor: usize, state: usize, model: usize, frame: usize, output: *Source) bool {
    var read = Reader.init();
    var s = std.mem.zeroes(Source);
    if (!world(&read, &s) or !read.readable(frame, @sizeOf(@TypeOf(s.frame_words)))) return false;
    s.actor = actor;
    s.state = state;
    s.model = model;
    s.native_frame = frame;
    s.frame_words = win.load([8]u32, frame);
    s.wrapper = s.frame_words[4];
    s.arguments = s.frame_words[5];
    s.command = s.frame_words[2];
    if (s.frame_words[3] != state or !read.readable(s.wrapper, 8) or win.load(usize, s.wrapper + 4) != actor or
        !read.readable(actor, 12) or win.load(usize, actor + 8) != model or !actorInput(&read, &s, s.frame_words[1])) return false;
    s.input.state_flags = win.load(u16, state + 0xa6);
    s.input.argument_count = s.frame_words[6];
    s.input.initialize = @intFromBool(s.frame_words[7] != 0);
    if (s.input.argument_count > 256 or !argumentHash(&read, s.arguments, s.input.argument_count, &s.input.argument_hash)) return false;
    output.* = s;
    return true;
}
fn dispatch(descriptor: usize, stack: usize, output: *Dispatch, callback: bool) bool {
    var read = Reader.init();
    var s = std.mem.zeroes(Dispatch);
    if (!read.readable(stack, @sizeOf(@TypeOf(s.stack_words))) or !read.readable(descriptor, 0x14)) return false;
    s.stack_words = win.load([8]u32, stack);
    s.descriptor = descriptor;
    s.native_stack = stack;
    s.command = s.stack_words[1];
    s.state = s.stack_words[2];
    s.wrapper = s.stack_words[3];
    s.arguments = s.stack_words[4];
    if (!read.readable(s.state, 0xa8) or win.load(usize, s.state + 4) != 0 or win.load(usize, s.state + 0x14) != descriptor or
        win.load(usize, descriptor + 8) != s.arguments or win.load(u32, descriptor + 0xc) != s.stack_words[5] or !read.readable(s.wrapper, 8)) return false;
    s.handler = win.load(usize, descriptor + 0x10);
    if (!read.readable(s.handler, 8) or win.load(usize, s.handler + 4) != 0x963520) return false;
    s.actor = win.load(usize, s.wrapper + 4);
    if (!world(&read, &s) or !read.readable(s.actor, 12)) return false;
    s.model = win.load(usize, s.actor + 8);
    if (!actorInput(&read, &s, s.stack_words[0])) return false;
    s.state_flags_raw = win.load(u16, s.state + 0xa6);
    s.input.initialize = @intFromBool(s.stack_words[6] != 0);
    s.input.state_flags = if (s.input.initialize != 0) 0 else s.state_flags_raw;
    s.input.argument_count = s.stack_words[5];
    if (s.input.argument_count > 256 or !argumentHash(&read, s.arguments, s.input.argument_count, &s.input.argument_hash)) return false;
    if (callback) {
        s.state_flags_raw = output.state_flags_raw;
        s.input.state_flags = output.input.state_flags;
    }
    output.* = s;
    return true;
}
const Operation = enum { resolve, revalidate, dispatch_resolve, dispatch_revalidate, matches, admission };
const Request = struct {
    operation: Operation,
    actor: usize = 0,
    state: usize = 0,
    model: usize = 0,
    frame: usize = 0,
    descriptor: usize = 0,
    output: ?*Source = null,
    witness: ?*const Source = null,
    dispatch_output: ?*Dispatch = null,
    dispatch_witness: ?*const Dispatch = null,
};
fn invoke(address: usize) callconv(.c) c_int {
    const r: *Request = @ptrFromInt(address);
    var fresh: Source = undefined;
    var now: Dispatch = undefined;
    return switch (r.operation) {
        .resolve => if (r.output) |out| @intFromBool(snapshot(r.actor, r.state, r.model, r.frame, out)) else 0,
        .revalidate => if (r.witness) |s| @intFromBool(snapshot(s.actor, s.state, s.model, s.native_frame, &fresh) and equal(s, &fresh)) else 0,
        .dispatch_resolve => if (r.dispatch_output) |out| @intFromBool(dispatch(r.descriptor, r.frame, out, false)) else 0,
        .dispatch_revalidate => if (r.dispatch_witness) |s| @intFromBool(dispatch(s.descriptor, s.native_stack, &now, false) and equal(s, &now)) else 0,
        .matches => blk: {
            const s = r.dispatch_witness orelse break :blk 0;
            var read = Reader.init();
            if (s.actor != r.actor or s.state != r.state or s.model != r.model or !read.readable(r.frame, 36)) break :blk 0;
            const words = win.load([9]u32, r.frame);
            if (words[1] != 0x6f407f or !std.mem.eql(u32, words[2..9], s.stack_words[1..8])) break :blk 0;
            now = std.mem.zeroes(Dispatch);
            now.state_flags_raw = s.state_flags_raw;
            now.input.state_flags = s.input.state_flags;
            break :blk @intFromBool(dispatch(s.descriptor, s.native_stack, &now, true) and equal(s, &now));
        },
        .admission => admission(r.frame) + 2,
    };
}
fn admission(stack: usize) c_int {
    var read = Reader.init();
    if (!read.readable(stack, 16)) return -1;
    const state = win.load(usize, stack + 8);
    const wrapper = win.load(usize, stack + 12);
    if (wrapper == 0) return 0;
    if (!read.readable(wrapper, 8)) return -1;
    const actor = win.load(usize, wrapper + 4);
    if (actor == 0 or state == 0) return 0;
    if (!read.readable(actor, 12)) return -1;
    const model = win.load(usize, actor + 8);
    if (model == 0) return 0;
    if (!read.readable(model, 0x38)) return -1;
    const brain = win.load(usize, model + 0x34);
    if (brain == 0) return 0;
    if (!read.readable(brain, 0x19c)) return -1;
    return @intFromBool(win.load(u32, brain + 0x198) != 0);
}
fn run(request: Request) c_int {
    const saved = win.GetLastError();
    defer win.SetLastError(saved);
    var r = request;
    const result = guard.all(@intFromPtr(&r), invoke);
    return if (r.operation == .admission) (if (result == 0) -1 else result - 2) else result;
}
pub export fn native_script_shoot_source_resolve(actor: usize, state: usize, model: usize, frame: usize, out: ?*Source) c_int {
    return run(.{ .operation = .resolve, .actor = actor, .state = state, .model = model, .frame = frame, .output = out });
}
pub export fn native_script_shoot_source_revalidate(source: ?*const Source) c_int {
    return run(.{ .operation = .revalidate, .witness = source });
}
pub export fn native_script_shoot_dispatch_source_resolve(descriptor: usize, stack: usize, out: ?*Dispatch) c_int {
    return run(.{ .operation = .dispatch_resolve, .descriptor = descriptor, .frame = stack, .dispatch_output = out });
}
pub export fn native_script_shoot_dispatch_source_revalidate(source: ?*const Dispatch) c_int {
    return run(.{ .operation = .dispatch_revalidate, .dispatch_witness = source });
}
pub export fn native_script_shoot_dispatch_initial_admission(stack: usize) c_int {
    return run(.{ .operation = .admission, .frame = stack });
}
pub export fn native_script_shoot_dispatch_frame_matches(source: ?*const Dispatch, actor: usize, state: usize, model: usize, frame: usize) c_int {
    return run(.{ .operation = .matches, .actor = actor, .state = state, .model = model, .frame = frame, .dispatch_witness = source });
}
