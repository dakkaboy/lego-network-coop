const p = @import("protocol.zig");
const s = @import("cadence_state.zig");

pub extern fn tube_entry_thunk() void;
pub extern fn tube_hold_thunk() void;
pub extern fn tube_search_thunk() void;
pub extern fn tube_candidate_thunk() void;
pub extern fn tube_update_trace_thunk() void;
export var tube_entry_continue: usize = 0x804b8a;
export var tube_entry_skip: usize = 0x804b7f;
export var tube_hold_continue: usize = 0x804cda;
export var tube_hold_skip: usize = 0x804aad;
export var tube_search_continue: usize = 0x804b2d;
export var tube_search_skip: usize = 0x804cd9;
export var tube_candidate_continue: usize = 0x804b5c;
export var tube_candidate_skip: usize = 0x804b7f;
pub export var clonewars_tube_contact_debug: [4][4]u32 = @splat(@splat(0));
export var tube_update_native: usize = 0x804a20;
pub export var clonewars_tube_update_history: [385]u32 = @splat(0);

fn trace(actor: usize, marker: usize, first: usize, second: usize) void {
    const count = clonewars_tube_update_history[0];
    const row = clonewars_tube_update_history[1 + (count % 32) * 12 ..][0..12];
    row.* = .{
        s.journal.frame.?.epoch, s.journal.frame.?.sequence, @truncate(actor),           s.read(u16, actor + 0xdc0),
        @truncate(marker),       s.read(u16, actor + 0x2f4), s.read(u32, actor + 0xc8c), @truncate(first),
        @truncate(second),       s.read(u32, actor + 0x24),  s.read(u32, actor + 0x28),  s.read(u32, actor + 0x2c),
    };
    clonewars_tube_update_history[0] = count +% 1;
}

export fn tube_update_trace(actor: usize, caller: usize, area: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or !s.valid(actor, 0x1440) or s.read(u32, actor + 0x50) & 0x200 == 0) return;
    trace(actor, caller, area, s.read(usize, actor + 0x2cc));
}

const Stage = enum(u16) { entry, hold, search, candidate };
pub fn contact(actor: usize, tube: usize, stage: Stage, local: bool) bool {
    var lease: s.Lease = undefined;
    if (!s.ready(&lease) or s.journal.frame.?.level != 64 or s.read(u32, actor + 0x50) & 0x200 == 0 or (stage != .search and !s.valid(tube, 0x5c))) return local;
    const index = @backingInt(stage);
    trace(actor, index + 1, tube, @intFromBool(local));
    // Use the authored tube position to verify we are replaying the same contact.
    var position = if (stage == .search) [3]f32{ 0, 0, 0 } else s.read([3]f32, tube + 0x50);
    return @import("cadence_gate.zig").apply(actor, p.SYNC_ACTOR_TUBE_CONTACT, index, 0, @intFromBool(local), @ptrCast(&position), &clonewars_tube_contact_debug[index]) != 0;
}

export fn tube_entry(actor: usize, tube: usize, native_contact: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local = native_contact != 0 or (s.read(u32, actor + 0x2d4) == 5 and s.read(u32, actor + 0x2dc) != 0);
    return @intFromBool(contact(actor, tube, .entry, local));
}

export fn tube_hold(actor: usize, _: usize, native_contact: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return @intFromBool(contact(actor, s.read(usize, actor + 0x2cc), .hold, native_contact != 0));
}

export fn tube_search(actor: usize, _: usize, native_result: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    return @intFromBool(contact(actor, 0, .search, native_result & 255 != 0));
}

export fn tube_candidate(actor: usize, tube: usize, _: u32) c_int {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    const local = s.read(u16, tube + 0x62) & 3 == 3 and s.read(u8, tube + 0x73) == 0 and s.read(u8, tube + 0xa0) & 1 == 0;
    return @intFromBool(contact(actor, tube, .candidate, local));
}

fn bridge(comptime label: []const u8) []const u8 {
    return ".text\n.globl _" ++ label ++ "_thunk\n_" ++ label ++ "_thunk:\n" ++
        \\    pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $4,%esp
        \\    pushl 28(%edx)
        \\    pushl 0(%edx)
        \\    pushl 4(%edx)
    ++ "\n    call _" ++ label ++ "\n" ++
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jz 1f
        \\    popal
        \\    popfl
    ++ "\n    jmp *_" ++ label ++ "_continue\n" ++
        \\1:  popal
        \\    popfl
    ++ "\n    jmp *_" ++ label ++ "_skip\n";
}

comptime {
    asm (bridge("tube_entry"));
    asm (bridge("tube_hold"));
    asm (bridge("tube_search"));
    asm (bridge("tube_candidate"));
    asm (
        \\.text
        \\.globl _tube_update_trace_thunk
        \\_tube_update_trace_thunk:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $4,%esp
        \\    pushl 44(%edx)
        \\    pushl 36(%edx)
        \\    pushl 40(%edx)
        \\    call _tube_update_trace
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    popal
        \\    popfl
        \\    jmp *_tube_update_native
    );
}
