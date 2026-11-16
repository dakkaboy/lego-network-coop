const fixture = @import("register_test_fixture.zig");
pub const fixture_receiver_in_eax = true;
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var rts_order_ready_resume: usize = 0;
var canonical: u32 = 0;
pub export fn native_rts_order_ready(object: usize, local: u32) u32 {
    check(@src(), object == 0x66666666 and local == fixture.receiver[0x62]);
    fixture.clobber();
    return (local & ~@as(u32, 2)) | canonical;
}
extern fn original() void;
extern fn native_rts_order_ready_bridge() void;
comptime {
    _ = @import("rts_order_bridge.zig");
    asm (
        \\.text
        \\_original:
        \\movb 0x62(%eax),%cl
        \\shrb %cl
        \\jmp *_rts_order_ready_resume
    );
}
pub fn main() void {
    rts_order_ready_resume = @intFromPtr(&fixture.continuation);
    for (0..256) |local| for (0..2) |bit| {
        canonical = @intCast(bit * 2);
        fixture.receiver[0x62] = @intCast((local & ~@as(usize, 2)) | canonical);
        fixture.entry = @intFromPtr(&original);
        fixture.invoke();
        const expected = fixture.regs;
        fixture.receiver[0x62] = @intCast(local);
        fixture.entry = @intFromPtr(&native_rts_order_ready_bridge);
        win.SetLastError(123);
        fixture.invoke();
        check(@src(), win.GetLastError() == 123 and fixture.receiver[0x62] == local);
        for (0..8) |i| if (i != 3) check(@src(), fixture.regs[i] == expected[i]);
        check(@src(), fixture.regs[8] & 0xcc5 == expected[8] & 0xcc5);
        fixture.preservedFx();
    };
}
