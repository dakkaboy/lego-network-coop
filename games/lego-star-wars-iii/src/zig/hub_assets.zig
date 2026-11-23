const win = @import("win32.zig");
const Receipt = @import("protocol.zig").SyncPreloadReceipt;

const Resolve = *const fn (usize, u32, *const u8, u32) callconv(.{ .x86_thiscall = .{} }) usize;
const Request = *const fn (usize, u32, usize) callconv(.{ .x86_thiscall = .{} }) u8;
const Update = *const fn (usize, u32) callconv(.{ .x86_thiscall = .{} }) void;
const Poll = *const fn (usize) callconv(.{ .x86_thiscall = .{} }) u8;

pub fn startupSettled(clock: u32) bool {
    // Resolute's ambient party requests its first model after the player actors spawn.
    if (clock < 12) return false;
    const hub = win.load(usize, 0xe90520);
    if (!win.accessible(hub, 0x21a4, false)) return false;
    const scheduler = hub + 0x1428;
    if (win.load(i32, scheduler) >= 0) return false;
    for (0..50) |slot| {
        const state = win.load(u32, scheduler + 0x3c + 0x44 * slot);
        if (state == 1 or state == 2) return false;
    }
    return true;
}

pub fn ready(receipt: *const Receipt) bool {
    if (receipt.hub_count == 0) return true;
    const characters = win.load(usize, 0xe90188);
    const hub = win.load(usize, 0xe90520);
    const world = win.load(usize, 0xfb4a20);
    if (!win.accessible(characters, 0x50, false) or !win.accessible(hub, 0x21a4, true) or
        !win.accessible(world, 0x238, false)) return false;
    const scheduler = hub + 0x1428;
    const flags: u8 = 3;
    const resolve: Resolve = @ptrFromInt(0x7b6ab0);
    var missing = false;
    for (receipt.hub_choices[0..receipt.hub_count]) |choice| {
        if (resolve(characters, choice.character, &flags, 0) != 0) continue;
        const table = win.load(usize, characters + 0x4c);
        if (!win.accessible(table + 4 * choice.character, 4, false)) return false;
        const info = win.load(usize, table + 4 * choice.character);
        if (!win.accessible(info, 0x20, false)) return false;
        const name = win.load(usize, info + 0x1c);
        if (!win.accessible(name, 0x20, false)) return false;
        const request: Request = @ptrFromInt(0x42d9a0);
        _ = request(scheduler, choice.character, name);
        missing = true;
    }
    if (!missing) return true;
    // Process asset readiness without advancing the synchronized world.
    const poll: Poll = @ptrFromInt(0x4a0e10);
    const update: Update = @ptrFromInt(0x4a0ea0);
    _ = poll(scheduler);
    const delta = win.load(u32, 0xfb4b74);
    win.store(u32, 0xfb4b74, 0);
    defer win.store(u32, 0xfb4b74, delta);
    update(scheduler, 1);
    return false;
}
