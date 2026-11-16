const std = @import("std");
const win = @import("win32.zig");
const Token = @import("cohort_types.zig").Token;
const Identity = @import("projectile_types.zig").Identity;
const api = if (@hasDecl(@import("root"), "hit_test_api")) @import("root").hit_test_api else struct {
    pub extern fn lan_session_serial() u32;
    pub extern fn coherent_frame_get(*Token, u32) c_int;
    pub extern fn coherent_frame_valid(*const Token, u32) c_int;
    pub extern fn entities_observed_generation(usize) u32;
    pub extern fn entities_allocation_live(usize, u32) c_int;
    pub extern fn entities_observed_identity(usize, *u32, *u32) c_int;
    pub extern fn projectiles_observe_live(usize, *Identity) c_int;
    pub extern fn combat_damage_native_caller() u32;
    pub extern fn combat_hit_bridge_attach(*const Token, usize, *usize) c_int;
    pub fn read(address: usize, output: []u8) bool {
        var got: usize = 0;
        return address != 0 and win.ReadProcessMemory(win.GetCurrentProcess(), address, output.ptr, output.len, &got) != 0 and got == output.len;
    }
};
pub const Actor = extern struct { local: u32, slot: u32, generation: u32, allocation: u32, character: u32, health: u32, model: u32, valid: u32 };
pub const Record = extern struct {
    committed: u32,
    id: u32,
    session: u32,
    epoch: u32,
    sequence: u32,
    clock: u32,
    thread: u32,
    caller: u32,
    qpc: [2]u32,
    cw: u32,
    mxcsr: u32,
    arguments: [6]u32,
    attacker: Actor,
    victim: Actor,
    source_local: u32,
    source_status: u32,
    shot_id: u32,
    shot_owner: u32,
    shot_generation: u32,
    weapon: u32,
    instance_serial: u32,
    creation_count: u32,
};
pub export var clonewars_hit_entry_enabled: i32 = 0;
pub export var clonewars_hit_entry_request: i32 = 0;
pub export var clonewars_hit_entry_installed: i32 = 0;
pub export var clonewars_hit_entry_count: u32 = 0;
pub export var clonewars_hit_entry_version: u32 = 3;
pub export var clonewars_hit_entry_stride: u32 = @sizeOf(Record);
pub export var clonewars_hit_entry_capacity: u32 = 512;
pub export var clonewars_hit_entry_ring: [512]Record = std.mem.zeroes([512]Record);
pub export var hit_entry_original: usize = 0;
var main_thread: u32 = 0;
fn live(token: *const Token, session: u32) bool {
    return session != 0 and api.lan_session_serial() == session and win.GetCurrentThreadId() == main_thread and api.coherent_frame_valid(token, 4) != 0;
}
fn read(address: usize, output: anytype) bool {
    return api.read(address, std.mem.asBytes(output));
}
fn actor(out: *Actor, pointer: u32, token: *const Token, session: u32) bool {
    out.* = std.mem.zeroes(Actor);
    out.local = pointer;
    out.slot = 0xffffffff;
    if (pointer == 0) return true;
    if (!live(token, session)) return false;
    const generation = api.entities_observed_generation(pointer);
    var slot: u32 = 0;
    var remote_generation: u32 = 0;
    if (generation == 0 or api.entities_allocation_live(pointer, generation) == 0 or api.entities_observed_identity(pointer, &slot, &remote_generation) == 0) return false;
    var model: u32 = 0;
    var character: u16 = 0;
    var hp: i8 = 0;
    if (!live(token, session) or !read(pointer + 8, &model) or !live(token, session) or !read(pointer + 0xdc0, &character) or !live(token, session) or !read(pointer + 0xdde, &hp)) return false;
    if (!live(token, session) or api.entities_allocation_live(pointer, generation) == 0 or api.entities_observed_generation(pointer) != generation) return false;
    var slot_after: u32 = 0;
    var generation_after: u32 = 0;
    if (api.entities_observed_identity(pointer, &slot_after, &generation_after) == 0 or slot != slot_after or remote_generation != generation_after) return false;
    out.* = .{ .local = pointer, .slot = slot, .generation = remote_generation, .allocation = generation, .character = character, .health = @bitCast(@as(i32, hp)), .model = model, .valid = 1 };
    return true;
}
pub export fn hit_entry_checkpoint(registers: [*]const u32, fx: [*]const u8) void {
    if (@atomicLoad(i32, &clonewars_hit_entry_enabled, .seq_cst) == 0 or win.GetCurrentThreadId() != main_thread) return;
    const session = api.lan_session_serial();
    var token: Token = undefined;
    if (session == 0 or api.coherent_frame_get(&token, 4) == 0 or !live(&token, session)) return;
    var record = std.mem.zeroes(Record);
    record.session = session;
    record.epoch = token.epoch;
    record.sequence = token.sequence;
    record.thread = win.GetCurrentThreadId();
    record.caller = api.combat_damage_native_caller();
    record.arguments = registers[10..16].*;
    record.cw = std.mem.bytesToValue(u16, fx[0..2]);
    record.mxcsr = std.mem.bytesToValue(u32, fx[24..28]);
    if (!actor(&record.attacker, record.arguments[0], &token, session) or !actor(&record.victim, record.arguments[1], &token, session) or !live(&token, session)) return;
    if (!read(0xfb4b6c, &record.clock) or !live(&token, session)) return;
    var source: u32 = 0;
    if (read(0xfbcb2c, &source) and live(&token, session)) {
        var identity = std.mem.zeroes(Identity);
        _ = api.projectiles_observe_live(source, &identity);
        if (!live(&token, session)) return;
        record.source_local = source;
        record.source_status = identity.status;
        if (identity.status == 1) {
            record.shot_id = identity.id;
            record.shot_owner = @bitCast(identity.owner);
            record.shot_generation = identity.owner_generation;
            record.weapon = @bitCast(identity.weapon);
            record.instance_serial = identity.instance_serial;
            record.creation_count = identity.creation_count;
        }
    }
    @import("observation.zig").timestamp(&record.qpc[0], &record.qpc[1]);
    if (@atomicLoad(i32, &clonewars_hit_entry_enabled, .seq_cst) == 0 or !live(&token, session)) return;
    if (@atomicLoad(u32, &clonewars_hit_entry_count, .seq_cst) >= 0x7ffffffe) return;
    record.id = @atomicRmw(u32, &clonewars_hit_entry_count, .Add, 1, .seq_cst) + 1;
    const output = &clonewars_hit_entry_ring[(record.id - 1) % 512];
    @atomicStore(u32, &output.committed, 0, .seq_cst);
    output.* = record;
    _ = @atomicRmw(u32, &output.committed, .Xchg, 0, .seq_cst);
    if (@atomicLoad(i32, &clonewars_hit_entry_enabled, .seq_cst) != 0 and live(&token, session)) @atomicStore(u32, &output.committed, record.id, .seq_cst);
}
extern fn hit_entry_thunk() void;
pub export fn hit_entry_install(original: ?*const Token) c_int {
    const state = @atomicLoad(i32, &clonewars_hit_entry_installed, .seq_cst);
    if (state != 0) return @intFromBool(state == 1 and main_thread == win.GetCurrentThreadId());
    const session = api.lan_session_serial();
    const token = original orelse return 0;
    if (session == 0 or token.thread != win.GetCurrentThreadId() or api.coherent_frame_valid(token, 4) == 0 or api.lan_session_serial() != session) return 0;
    if (api.combat_hit_bridge_attach(token, @intFromPtr(&hit_entry_thunk), &hit_entry_original) == 0) return 0;
    main_thread = win.GetCurrentThreadId();
    @atomicStore(i32, &clonewars_hit_entry_installed, 1, .seq_cst);
    return 1;
}
pub export fn hit_entry_poll(token: ?*const Token) void {
    if (@atomicLoad(i32, &clonewars_hit_entry_request, .seq_cst) == 1 and @atomicLoad(i32, &clonewars_hit_entry_installed, .seq_cst) == 0) _ = hit_entry_install(token);
}
comptime {
    std.debug.assert(@sizeOf(Record) == 168);
    asm (
        \\.text
        \\.globl _hit_entry_thunk
        \\_hit_entry_thunk:
        \\pushfl
        \\pushal
        \\movl %esp,%eax
        \\subl $544,%esp
        \\andl $-16,%esp
        \\movl %eax,512(%esp)
        \\fxsave (%esp)
        \\fninit
        \\movl $0x1f80,516(%esp)
        \\ldmxcsr 516(%esp)
        \\cld
        \\call _GetLastError@0
        \\movl %eax,524(%esp)
        \\movl %esp,%edx
        \\movl 512(%esp),%eax
        \\subl $8,%esp
        \\pushl %edx
        \\pushl %eax
        \\call _hit_entry_checkpoint
        \\addl $16,%esp
        \\cld
        \\pushl 524(%esp)
        \\call _SetLastError@4
        \\fxrstor (%esp)
        \\movl 512(%esp),%esp
        \\popal
        \\popfl
        \\jmp *_hit_entry_original
    );
}
