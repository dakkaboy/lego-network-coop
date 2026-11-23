const win = @import("win32.zig");
const lan = @import("lan_state.zig");
const game = @import("game_api.zig");

const geonosian_arena = 12;
const hint_entry = 0xce47fc;
const padme_tag_key = 0xad2abc;
const padme_tag_id = 0x45;
const player_actors = 0xfb4940;
const actor_character_offset = 0xdc0;
const padme_character = 189;

fn canShow(_: usize) callconv(.c) c_int {
    if (lan.lan_status() != 3) return 1;
    if (game.game_current_level() != geonosian_arena) return 0;
    if (!win.accessible(player_actors, 2 * @sizeOf(usize), false)) return 1;
    const actors = win.load([2]usize, player_actors);
    if (actors[0] == 0 or actors[1] == 0 or actors[0] == actors[1]) return 1;
    for (actors) |actor| {
        if (win.accessible(actor + actor_character_offset, @sizeOf(u16), false) and
            win.load(u16, actor + actor_character_offset) == padme_character) return 0;
    }
    return 1;
}

pub fn install() void {
    // HINT_PAD_TAG has no native availability predicate.
    if (!win.accessible(hint_entry, 16, true) or
        win.load(u32, hint_entry) != padme_tag_key or
        win.load(u32, hint_entry + 4) != 0 or
        win.load(u32, hint_entry + 12) != padme_tag_id) return;
    win.store(usize, hint_entry + 4, @intFromPtr(&canShow));
}
