const com = @import("com.zig");
const layout = @import("art_layout.zig");

pub const State = struct {
    hovered: i32,
    pressed: i32,
    focused: i32,
    camera: i32,
    lan: i32,
    hub: bool,
    address_invalid: bool,
    fault: bool,
    view: u32,
    weights: [4]f32,
    opening: f32,
    sound_enabled: bool,
    keypad: ?i32 = null,
    gamepad: bool,
};

const Vertex = extern struct { x: f32, y: f32, z: f32 = 0, rhw: f32 = 1, color: u32 };

fn obj(device: usize, index: usize, value: usize) i32 {
    return com.method(*const fn (usize, usize) callconv(.winapi) i32, device, index)(device, value);
}

fn rs(device: usize, key: u32, value: u32) void {
    _ = com.method(*const fn (usize, u32, u32) callconv(.winapi) i32, device, 57)(device, key, value);
}

fn configure(device: usize, blend: bool) bool {
    _ = obj(device, 92, 0);
    _ = obj(device, 107, 0);
    if (com.method(*const fn (usize, u32) callconv(.winapi) i32, device, 89)(device, 0x44) < 0) return false;
    for ([_][2]u32{ .{ 7, 0 }, .{ 14, 0 }, .{ 15, 0 }, .{ 22, 1 }, .{ 27, @intFromBool(blend) }, .{ 19, 5 }, .{ 20, 6 }, .{ 28, 0 }, .{ 137, 0 }, .{ 168, 15 }, .{ 174, 0 }, .{ 194, 0 }, .{ 206, 0 } }) |setting| rs(device, setting[0], setting[1]);
    const stage = com.method(*const fn (usize, u32, u32, u32) callconv(.winapi) i32, device, 67);
    _ = stage(device, 0, 1, 2);
    _ = stage(device, 0, 2, 0);
    _ = stage(device, 0, 4, 2);
    _ = stage(device, 0, 5, 0);
    _ = stage(device, 1, 1, 1);
    return true;
}

fn color(rgb: u32, alpha: f32) u32 {
    const a: u32 = @intFromFloat(@max(0, @min(1, alpha)) * 255);
    return (a << 24) | rgb;
}

const Canvas = struct {
    device: usize,
    scale: f32,
    x: f32,
    y: f32,

    fn quad(self: Canvas, r: [4]f32, top: u32, bottom: u32) void {
        const x = self.x + r[0] * self.scale - 0.5;
        const y = self.y + r[1] * self.scale - 0.5;
        const right = x + r[2] * self.scale;
        const base = y + r[3] * self.scale;
        const vertices = [4]Vertex{
            .{ .x = x, .y = y, .color = top },
            .{ .x = right, .y = y, .color = top },
            .{ .x = x, .y = base, .color = bottom },
            .{ .x = right, .y = base, .color = bottom },
        };
        _ = com.method(*const fn (usize, u32, u32, *const [4]Vertex, u32) callconv(.winapi) i32, self.device, 83)(self.device, 5, 2, &vertices, @sizeOf(Vertex));
    }

    fn box(self: Canvas, r: [4]f32, rgb: u32, alpha: f32) void {
        const tint = color(rgb, alpha);
        self.quad(r, tint, tint);
    }

    fn panel(self: Canvas, rect: [4]f32, shift: f32, alpha: f32) void {
        self.box(.{ rect[0] + shift, rect[1], rect[2], rect[3] }, 0x41536e, alpha);
        self.box(.{ rect[0] + shift + 1, rect[1] + 1, rect[2] - 2, rect[3] - 2 }, 0x131e2e, alpha);
    }

    fn control(self: Canvas, state: State, id: i32, pane: u32, weight: f32) void {
        var r = layout.controlBounds(id, pane, state.keypad != null);
        const fixed = id == 6 or id == 7 or id == 11;
        if (!fixed) r[0] += layout.contentShift(pane, state.view, weight);
        if (state.pressed == id and state.hovered == id) r[1] += 2;
        const emphasized = id == 1 or id == 2 or (id >= 3 and id <= 5 and state.camera == id - 4) or (id == 10 and state.sound_enabled);
        const selected_key = id >= layout.keypad_first and state.focused == id;
        const edge: u32 = if (id == 0 and state.address_invalid) 0xf5787e else if (state.focused == id or state.hovered == id) 0x9ce2fc else if (emphasized) 0x3dbac7 else 0x41536e;
        const top: u32 = if (id == 0) 0x101a29 else if (selected_key) 0x1e536b else if (state.pressed == id) 0x203647 else if (emphasized) 0x1a5668 else 0x24334a;
        const bottom: u32 = if (id == 0) 0x101a29 else if (selected_key or emphasized) 0x163b52 else 0x192638;
        const alpha = state.opening * weight;
        if (selected_key) {
            self.box(.{ r[0] - 4, r[1] - 4, r[2] + 8, r[3] + 8 }, 0x48cadd, alpha * 0.18);
            self.box(.{ r[0] - 2, r[1] - 2, r[2] + 4, r[3] + 4 }, 0x5bd7e9, alpha * 0.32);
        }
        self.box(r, edge, alpha);
        self.quad(.{ r[0] + 2, r[1] + 2, r[2] - 4, r[3] - 4 }, color(top, alpha), color(bottom, alpha));
    }
};

pub fn draw(device: usize, width: u32, height: u32, scale: f32, x: f32, y: f32, state: State) void {
    var block: usize = 0;
    if (com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, device, 59)(device, 1, &block) < 0 or block == 0) return;
    defer com.release(block);
    defer _ = com.method(*const fn (usize) callconv(.winapi) i32, block, 5)(block);
    if (!configure(device, true)) return;
    const c = Canvas{ .device = device, .scale = scale, .x = x, .y = y };
    const a = state.opening;
    c.box(.{ -x / scale, -y / scale, @as(f32, @floatFromInt(width)) / scale, @as(f32, @floatFromInt(height)) / scale }, 0x080f19, a * 0.64);
    c.box(.{ 148, 94, 984, 552 }, 0x41536e, a);
    c.quad(.{ 150, 96, 980, 548 }, color(0x1c2a3e, a), color(0x101a29, a));
    c.box(.{ 150, 96, 980, 4 }, 0x55cbd5, a);
    c.box(.{ 166, 178, 948, 2 }, 0x41536e, a);
    c.box(.{ 166, 508, 948, 2 }, 0x41536e, a);
    c.box(.{ 166, 582, 948, 2 }, 0x41536e, a);
    if (state.gamepad) {
        const keypad = state.keypad != null;
        const palette = if (keypad) [4]u32{ 0x586983, 0x20764f, 0x245e91, 0x98454e } else [4]u32{ 0x586983, 0x20764f, 0x98454e, 0 };
        for (0..@as(usize, if (keypad) 4 else 3)) |index| {
            const r = layout.padHintIcon(index, keypad);
            const px: f32 = @floatFromInt(r[0]);
            const py: f32 = @floatFromInt(r[1]);
            if (index == 0) {
                c.box(.{ px + 8, py + 2, 8, 20 }, palette[index], a);
                c.box(.{ px + 2, py + 8, 20, 8 }, palette[index], a);
            } else {
                c.box(.{ px + 2, py, 20, 24 }, palette[index], a);
                c.box(.{ px, py + 2, 24, 20 }, palette[index], a);
            }
        }
    }
    for ([_]i32{ 6, 7, 11 }) |id| c.control(state, id, 0, 1);
    for (state.weights, 0..) |weight, index| {
        if (weight * a < 0.005) continue;
        const pane: u32 = @intCast(index);
        switch (pane) {
            0 => for ([_]i32{ 1, 2 }) |id| c.control(state, id, pane, weight),
            1 => {
                c.control(state, 0, pane, weight);
                c.control(state, 2, pane, weight);
                c.control(state, 8, pane, weight);
                if (state.keypad) |selected| {
                    c.box(.{ 598 + layout.contentShift(pane, state.view, weight), 198, 2, 294 }, 0x41536e, a * weight);
                    var keypad_state = state;
                    keypad_state.focused = selected;
                    for (0..layout.keypad_count) |key_index| {
                        c.control(keypad_state, layout.keypad_first + @as(i32, @intCast(key_index)), pane, weight);
                    }
                }
            },
            2 => {
                const status: u32 = if (state.fault) 0xf5787e else if (state.lan == 3) 0x67dcb2 else 0xe9bc67;
                const shift = layout.contentShift(pane, state.view, weight);
                c.panel(layout.session_panel, shift, a * weight);
                c.box(.{ 615 + shift, 268, 50, 4 }, status, weight * a);
                c.control(state, 1, pane, weight);
            },
            3 => {
                const shift = layout.contentShift(pane, state.view, weight);
                c.panel(layout.settings_panel, shift, a * weight);
                c.box(.{ 332 + shift, 355, 616, 1 }, 0x41536e, a * weight);
                for ([_]i32{ 3, 4, 5, 8, 10 }) |id| c.control(state, id, pane, weight);
                if (state.hub) c.control(state, 9, pane, weight);
            },
            else => unreachable,
        }
    }
}
pub export var clonewars_overlay_pointer_debug: [8]u32 = @splat(0);
pub fn drawPointer(device: usize, position: [2]f32, scale: f32) void {
    const PointerVertex = extern struct { x: f32, y: f32, z: f32 = 0, rhw: f32 = 1, color: u32 };
    clonewars_overlay_pointer_debug[1] +%= 1;
    clonewars_overlay_pointer_debug[2] = @bitCast(position[0]);
    clonewars_overlay_pointer_debug[3] = @bitCast(position[1]);
    var block: usize = 0;
    const block_result = com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, device, 59)(device, 1, &block);
    clonewars_overlay_pointer_debug[4] = @bitCast(block_result);
    if (block_result < 0 or block == 0) return;
    defer com.release(block);
    defer _ = com.method(*const fn (usize) callconv(.winapi) i32, block, 5)(block);
    _ = obj(device, 92, 0);
    _ = obj(device, 107, 0);
    const fvf_result = com.method(*const fn (usize, u32) callconv(.winapi) i32, device, 89)(device, 0x44);
    clonewars_overlay_pointer_debug[5] = @bitCast(fvf_result);
    if (fvf_result < 0) return;
    for ([_][2]u32{ .{ 7, 0 }, .{ 14, 0 }, .{ 15, 0 }, .{ 22, 1 }, .{ 27, 0 }, .{ 28, 0 }, .{ 168, 15 }, .{ 174, 0 } }) |r| rs(device, r[0], r[1]);
    const stage = com.method(*const fn (usize, u32, u32, u32) callconv(.winapi) i32, device, 67);
    _ = stage(device, 0, 1, 2); // Select diffuse vertex color.
    _ = stage(device, 0, 2, 0);
    _ = stage(device, 1, 1, 1);
    const outline = [_][2]f32{ .{ 0, 0 }, .{ 0, 25 }, .{ 7, 18 }, .{ 18, 18 } };
    const fill = [_][2]f32{ .{ 2, 5 }, .{ 2, 20 }, .{ 6, 16 }, .{ 13, 16 } };
    const size = @max(0.75, scale);
    const draw_strip = com.method(*const fn (usize, u32, u32, *const [4]PointerVertex, u32) callconv(.winapi) i32, device, 83);
    for ([_][4][2]f32{ outline, fill }, [_]u32{ 0xff0a1420, 0xfffff4d4 }, 0..) |points, tint, i| {
        var vertices: [4]PointerVertex = undefined;
        for (&vertices, points) |*vertex, point| vertex.* = .{
            .x = position[0] + point[0] * size - 0.5,
            .y = position[1] + point[1] * size - 0.5,
            .color = tint,
        };
        clonewars_overlay_pointer_debug[6 + i] = @bitCast(draw_strip(device, 5, 2, &vertices, @sizeOf(PointerVertex)));
    }
}
