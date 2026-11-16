const std = @import("std");
const win = @import("win32.zig");
const Reader = @import("memory_reader.zig").Reader;
const guard = @import("seh_guard.zig");
pub fn Snapshot(comptime T: type, comptime Input: type, comptime capture: fn (*Reader, Input, *T) bool, comptime inputOf: fn (*const T) Input) type {
    return struct {
        const Request = struct { input: Input, output: ?*T = null, witness: ?*const T = null };
        fn invoke(address: usize) callconv(.c) c_int {
            const request: *Request = @ptrFromInt(address);
            var reader = Reader.init();
            var first: T = undefined;
            var second: T = undefined;
            const expected = if (request.witness) |w| w.* else null;
            const input = if (expected) |*value| inputOf(value) else request.input;
            if (!capture(&reader, input, &first) or !capture(&reader, input, &second) or
                !std.mem.eql(u8, std.mem.asBytes(&first), std.mem.asBytes(&second))) return 0;
            if (expected) |*value| {
                if (!std.mem.eql(u8, std.mem.asBytes(value), std.mem.asBytes(&first))) return 0;
            } else (request.output orelse return 0).* = first;
            return 1;
        }
        fn run(request: *Request) c_int {
            const saved = win.GetLastError();
            defer win.SetLastError(saved);
            return guard.all(@intFromPtr(request), invoke);
        }
        pub fn resolve(input: Input, output: ?*T) c_int {
            if (output == null) return 0;
            var request: Request = .{ .input = input, .output = output };
            return run(&request);
        }
        pub fn revalidate(witness: ?*const T) c_int {
            if (witness == null) return 0;
            var request: Request = .{ .input = undefined, .witness = witness };
            return run(&request);
        }
    };
}
