const s = @import("reaction_state.zig");
const hooks = @import("hook_transaction.zig");
pub export var reaction_resume: usize = 0x96a1c4;
pub export var reaction_damage_draw_resume: usize = 0x96b2e9;
pub export var reaction_arena_skip_timer: usize = 0x410d10;
extern fn reaction_choice_thunk() void;
extern fn reaction_damage_draw_thunk() void;
extern fn reaction_arena_contact_thunk() void;
extern fn native_action_trace_thunk() void;
extern fn reaction_item_range_hook(usize, usize, f32) c_int;
pub fn install() c_int {
    if (s.clonewars_reaction_installed == 1) return 1;
    const patches = [_]hooks.Patch{
        .{ .address = 0x89e430, .expected = "\x56\x8b\x74\x24\x08\x85\xf6", .target = @intFromPtr(&native_action_trace_thunk) },
        .{ .address = 0x96a1bd, .expected = "\x8b\x7c\x24\x50\x83\xff\xff", .target = @intFromPtr(&reaction_choice_thunk) },
        .{ .address = 0x96b2e1, .expected = "\x89\x44\x24\x44\xdb\x44\x24\x44", .target = @intFromPtr(&reaction_damage_draw_thunk) },
        .{ .address = 0x410cf3, .expected = "\xe8\xc8\x97\x55\x00", .target = @intFromPtr(&reaction_arena_contact_thunk), .opcode = 0xe8 },
        .{ .address = 0x87ffb7, .expected = "\xe8\xf4\x2d\xf1\xff", .target = @intFromPtr(&reaction_item_range_hook), .opcode = 0xe8 },
    };
    const ok = hooks.apply(&patches);
    s.clonewars_reaction_installed = if (ok) 1 else -1;
    return @intFromBool(ok);
}
comptime {
    _ = @import("native_action_trace.zig");
    _ = @import("reaction_bridges.zig");
}
