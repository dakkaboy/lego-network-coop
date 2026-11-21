const s = @import("tick_state.zig");
const hooks = @import("hook_transaction.zig");

const identity_fields = 6;
extern fn arena_rope_basis() void;
extern fn arena_rope_birth() void;
extern fn arena_rope_step() void;
export var arena_rope_basis_resume: usize = 0x8143e4;
export var arena_rope_birth_resume: usize = 0x814509;
export var arena_rope_step_resume: usize = 0x814f10;
pub export var clonewars_arena_rope_inputs: [6]u32 = @splat(0);

pub fn patches() [3]hooks.Patch {
    return .{
        .{ .address = s.site.ARENA_ROPE_BASIS, .expected = "\xd9\x84\x24\xb4\x00\x00\x00", .target = @intFromPtr(&arena_rope_basis) },
        .{ .address = s.site.ARENA_ROPE_BIRTH, .expected = "\xd9\x84\x24\x74\x01\x00\x00", .target = @intFromPtr(&arena_rope_birth) },
        .{ .address = s.site.ARENA_ROPE_STEP, .expected = "\x8b\x4e\x10\x6a\x00", .target = @intFromPtr(&arena_rope_step) },
    };
}

extern fn entities_observed_identity(usize, *u32, *u32) c_int;

fn synchronize(comptime count: usize, site: u32, identity: [identity_fields]u32, data: usize) bool {
    const sites = s.consecutive(identity_fields + count, site, 1);
    const local = s.load([count]u32, data);
    const values = identity ++ local;
    for (sites, values) |at, value| {
        if (!s.valid.gateValid(.{ .site = at, .clock = s.clock(), .value = value })) {
            s.fail(2, site, s.clock(), s.firstExpected());
            return false;
        }
    }
    if (s.host) {
        if (!s.capacity(values.len, site)) return false;
        var published: [values.len]u32 = undefined;
        s.run(&values, &sites, &published);
        return !s.failed;
    }
    if (!s.match(&values, &sites, identity_fields, true)) return false;
    var resolved: [values.len]u32 = undefined;
    s.run(&values, &sites, &resolved);
    if (s.failed) return false;
    s.store([count]u32, data, resolved[identity_fields..].*);
    return true;
}

export fn arena_rope_sync(site: u32, rope: usize, stack: usize) void {
    const saved = s.win.GetLastError();
    defer s.win.SetLastError(saved);
    if (!s.ready() or s.frame.?.level != 12) return;
    if (!s.readable(rope, 0xb0) or s.load(u32, rope) != 0xc46990 or s.load(u32, rope + 0x18) != 10 or
        s.load(u32, rope + 0x98) != 4 or s.load(u32, rope + 0xa4) != 3) return;
    const marker = s.load(usize, rope + 0x9c);
    const actor = s.load(usize, rope + 0xa8);
    if (!s.readable(marker, 4) or s.load(u32, marker) != 0xc43ce4 or !s.readable(actor, 0x1440)) return;
    var slot: u32 = undefined;
    var generation: u32 = undefined;
    if (entities_observed_identity(actor, &slot, &generation) == 0) {
        s.fail(2, site, s.clock(), s.firstExpected());
        return;
    }
    const tag = s.load(u32, rope + 0xac);
    if (tag > 0xffff) {
        s.fail(2, site, s.clock(), s.firstExpected());
        return;
    }
    // These stack copies feed rope length, particle birth, and anchor velocity.
    const index: usize, const fixed: usize, const data: usize = switch (site) {
        s.site.ARENA_ROPE_BASIS => .{ 0, stack + 0xb4, stack + 0x104 },
        s.site.ARENA_ROPE_BIRTH => .{ 2, stack + 0x174, stack + 0xf4 },
        s.site.ARENA_ROPE_STEP => .{ 4, stack + 0x80, stack + 0xc0 },
        else => unreachable,
    };
    const point = s.load([3]u32, fixed);
    const identity = [identity_fields]u32{ slot, generation, (tag << 16) | @as(u32, s.load(u16, actor + 0xdc0)), point[0], point[1], point[2] };
    const accepted = if (site == s.site.ARENA_ROPE_BASIS) synchronize(15, site, identity, data) else synchronize(3, site, identity, data);
    if (!accepted) return;
    clonewars_arena_rope_inputs[index + @as(usize, @intFromBool(!s.host))] +%= 1;
}

comptime {
    asm (
        \\.text
        \\.macro arena_rope_sync_tap site, rope
        \\pushfl
        \\pushal
        \\movl %esp,%edx
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %edx,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\movl 12(%edx),%eax
        \\addl $4,%eax
        \\pushl %eax
        \\pushl \rope(%edx)
        \\pushl $\site
        \\call _arena_rope_sync
        \\addl $12,%esp
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\.endm
        \\.globl _arena_rope_basis
        \\_arena_rope_basis:
        \\arena_rope_sync_tap 0x8143dd,0
        \\flds 0xb4(%esp)
        \\jmp *_arena_rope_basis_resume
        \\.globl _arena_rope_birth
        \\_arena_rope_birth:
        \\arena_rope_sync_tap 0x814502,0
        \\flds 0x174(%esp)
        \\jmp *_arena_rope_birth_resume
        \\.globl _arena_rope_step
        \\_arena_rope_step:
        \\arena_rope_sync_tap 0x814f0b,4
        \\movl 0x10(%esi),%ecx
        \\pushl $0
        \\jmp *_arena_rope_step_resume
    );
}
