const s = @import("tick_state.zig");

pub extern fn swamp_droid_model_thunk() void;
export const swamp_droid_model_continue: usize = 0x9bf49e;
export const swamp_droid_model_stationary: usize = 0x9bf494;

export fn swamp_droid_model_branch(actor: usize) u32 {
    const local: u32 = @intFromBool(s.load(u16, actor + 0x2f4) == 22 and s.load(u32, actor + 0xc84) & 0x100000 == 0);
    if (!s.ready() or s.frame.?.level != 70 or s.load(u16, actor + 0xdc0) != 321) return local;
    const slot = s.entities_slot(actor);
    const generation = s.entities_generation(actor);
    const site = s.site.SWAMP_DROID_MODEL_BRANCH;
    if (slot < 0 or slot >= s.p.SYNC_MAX_ACTORS or generation == 0) {
        s.fail(4, site, s.clock(), s.firstExpected());
        return local;
    }
    const sites = [_]u32{ site, site + 1, site + 2 };
    const values = [_]u32{ @intCast(slot), generation, local };
    if (s.host) {
        if (!s.capacity(3, site)) return local;
    } else if (!s.match(&values, &sites, 2, true)) return local;
    var result: [3]u32 = undefined;
    s.run(&values, &sites, &result);
    return result[2];
}

comptime {
    asm (
        \\.text
        \\.globl _swamp_droid_model_thunk
        \\_swamp_droid_model_thunk:
        \\    pushfl
        \\    pushal
        \\    movl %esp,%eax
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %eax,512(%esp)
        \\    fxsave (%esp)
        \\    fninit
        \\    movl $0x1f80,516(%esp)
        \\    ldmxcsr 516(%esp)
        \\    cld
        \\    subl $12,%esp
        \\    pushl %ebx
        \\    call _swamp_droid_model_branch
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%esp
        \\    testl %eax,%eax
        \\    jnz 1f
        \\    popal
        \\    popfl
        \\    movzwl 0x2f4(%ebx),%eax
        \\    jmp *_swamp_droid_model_continue
        \\1:
        \\    popal
        \\    popfl
        \\    movzwl 0x2f4(%ebx),%eax
        \\    jmp *_swamp_droid_model_stationary
    );
}
