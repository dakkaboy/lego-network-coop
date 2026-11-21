const std = @import("std");
const com = @import("com.zig");
const art = @import("art_parts.zig");
const Connection = @import("connection_motion.zig").Model;
var connection: Connection = .{};
pub const State = struct { hovered: i32, pressed: i32, focused: i32, camera: i32, lan: i32, is_host: bool, hub: bool, address_focus: bool, address_invalid: bool, fault: bool = false, view: u32 = 0, weights: [4]f32 = .{ 1, 0, 0, 0 }, opening: f32 = 1, reduced: bool = false, sound_enabled: bool = true };
const api = struct {
    extern "kernel32" fn GetModuleHandleW(?[*:0]const u16) callconv(.winapi) usize;
    extern "kernel32" fn GetProcAddress(usize, [*:0]const u8) callconv(.winapi) usize;
    extern "kernel32" fn GetTickCount() callconv(.winapi) u32;
};
const Vertex = extern struct { x: f32, y: f32, z: f32 = 0, rhw: f32 = 1, color: u32 = 0xffffffff, u: f32, v: f32 };
var textures: [art.parts.len][2]usize = @splat(.{ 0, 0 });
var shader: usize = 0;
var shadow_shader: usize = 0;
var waiting_shader: usize = 0;
var base_shader: usize = 0;
var declaration: usize = 0;
var last_tick: u32 = 0;
var sound_amount: f32 = 1;
var camera_amount: [3]f32 = .{ 1, 0, 0 };
pub fn selection(id: i32) f32 {
    return camera_amount[@intCast(id - 3)];
}
var hover_amount: [12]f32 = @splat(0);
var press_amount: [12]f32 = @splat(0);
pub fn pressOffset(id: i32) f32 {
    return if (id >= 0 and id < 12) press_amount[@intCast(id)] * 8 - hover_amount[@intCast(id)] * 3 else 0;
}
var owner: usize = 0;
var failed: usize = 0;
var started: u32 = 0;
var mouse: [2]f32 = .{ 0.45, 0.25 };
pub var diagnostics: struct { vertices: usize = 0, draws: u32 = 0, shader_error: i32 = 0, message: [512]u8 = @splat(0), peer_x: f32 = 850, confirmation: f32 = 0 } = .{};
const source =
    \\sampler2D colorMap:register(s0);
    \\sampler2D normalMap:register(s1);
    \\float4 light:register(c0);
    \\float4 rect:register(c1);
    \\float4 effect:register(c2);
    \\float4 lamp:register(c3);
    \\float4 material:register(c4);
    \\float4 main(float2 uv:TEXCOORD0):COLOR0 {
    \\ float4 c=tex2D(colorMap,uv);
    \\ float3 n=tex2D(normalMap,uv).xyz*2-1; n.y=-n.y;
    \\ float2 p=rect.xy+uv*rect.zw;
    \\ float3 h=normalize(float3((light.xy-p)*0.6,1));
    \\ float s=saturate(dot(n,h));s*=s;s*=s;s*=s;s*=s;s*=s;
    \\ float lift=material.x*(1-material.y);
    \\ float bevel=dot(n,float3(-0.45,-0.65,0.1));
    \\ float sheen=saturate(1-abs(uv.x-(-0.3+material.w*1.8))*5);
    \\ c.rgb=c.rgb*0.98+s*0.055;
    \\ c.rgb*=1+bevel*lift*0.40;
    \\ c.rgb+=float3(1,0.91,0.65)*sheen*lift*0.22;
    \\ c.rgb*=1-material.y*0.16;
    \\ c.rgb*=effect.y;
    \\ c.rgb*=float3(1,1-effect.w*0.6,1-effect.w*0.6);
    \\ float luminous=saturate((c.b-c.r)*4+0.2)*step(0.18,c.b);
    \\ c.rgb=lerp(c.rgb,float3(c.b*0.22,c.b,c.b*0.45),lamp.x*luminous);
    \\ float pulse=saturate(1-abs(p.x-lamp.y)*1280/12)*saturate(1-abs(p.y-300.0/720)*720/18);
    \\ c.rgb+=float3(0.08,0.35,0.55)*pulse*luminous*lamp.z;
    \\ c.a*=effect.z; return c;
    \\}
;
fn obj(device: usize, index: usize, value: usize) i32 {
    return com.method(*const fn (usize, usize) callconv(.winapi) i32, device, index)(device, value);
}
fn rs(device: usize, key: u32, value: u32) void {
    _ = com.method(*const fn (usize, u32, u32) callconv(.winapi) i32, device, 57)(device, key, value);
}
fn constants(device: usize, index: u32, value: *const [4]f32) void {
    _ = com.method(*const fn (usize, u32, *const [4]f32, u32) callconv(.winapi) i32, device, 109)(device, index, value, 1);
}
pub fn pointer(x: f32, y: f32) void {
    mouse = .{ x / 1280, y / 720 };
    clonewars_overlay_pointer_debug[0] +%= 1;
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
    for ([_][4][2]f32{ outline, fill }, [_]u32{ 0xff0a1420, 0xfffff4d4 }, 0..) |points, color, i| {
        var vertices: [4]PointerVertex = undefined;
        for (&vertices, points) |*vertex, point| vertex.* = .{
            .x = position[0] + point[0] * size - 0.5,
            .y = position[1] + point[1] * size - 0.5,
            .color = color,
        };
        clonewars_overlay_pointer_debug[6 + i] = @bitCast(draw_strip(device, 5, 2, &vertices, @sizeOf(PointerVertex)));
    }
}
pub fn release() void {
    for (&textures) |*pair| {
        for (pair.*) |v| com.release(v);
        pair.* = .{ 0, 0 };
    }
    com.release(shadow_shader);
    shadow_shader = 0;
    com.release(waiting_shader);
    waiting_shader = 0;
    com.release(base_shader);
    base_shader = 0;
    com.release(declaration);
    declaration = 0;
    com.release(shader);
    shader = 0;
    owner = 0;
    failed = 0;
}
pub fn lost() void {
    release();
}
pub fn reset() void {}
const shadow_source =
    \\sampler2D image:register(s0);float4 shadow:register(c5);float4 effect:register(c2);
    \\float4 main(float2 uv:TEXCOORD0):COLOR0{
    \\ float2 p=uv-shadow.xy;
    \\ float a=tex2D(image,p).a*0.4;
    \\ a+=(tex2D(image,p+shadow.zw).a+tex2D(image,p-shadow.zw).a)*0.3;
    \\ return float4(0.005,0.009,0.015,a*0.55*effect.z);
    \\}
;
const waiting_source =
    \\sampler2D image:register(s0);sampler2D normals:register(s1);float4 wait:register(c6);
    \\float4 main(float2 uv:TEXCOORD0):COLOR0{
    \\ float2 atlas=float2((uv.x+wait.x)/24,uv.y);
    \\ float4 c=tex2D(image,atlas);float3 n=tex2D(normals,atlas).xyz*2-1;
    \\ float shine=saturate(dot(n,float3(-0.35,-0.65,0.67)));
    \\ c.rgb*=0.90+shine*0.16;c.a*=wait.y;return c;
    \\}
;
const base_source =
    \\sampler2D image:register(s0);float4 effect:register(c2);
    \\float4 main(float2 uv:TEXCOORD0):COLOR0{
    \\ float4 c=tex2D(image,uv);
    \\ float2 q=abs((uv-0.5)*float2(1280,720))-float2(612,332);
    \\ float distance=length(max(q,0))+min(max(q.x,q.y),0)-28;
    \\ float coverage=saturate(-distance/16);
    \\ coverage=coverage*coverage*(3-2*coverage);
    \\ c.rgb*=0.98;c.a*=coverage*effect.z;return c;
    \\}
;
fn compileEffect(device: usize, compiler: usize, program: []const u8) usize {
    const Compile = *const fn ([*]const u8, u32, usize, usize, [*:0]const u8, [*:0]const u8, u32, *usize, *usize, usize) callconv(.winapi) i32;
    var code: usize = 0;
    var errors: usize = 0;
    defer com.release(code);
    defer com.release(errors);
    const result = @as(Compile, @ptrFromInt(compiler))(program.ptr, @intCast(program.len), 0, 0, "main", "ps_2_0", 0, &code, &errors, 0);
    if (result < 0 or code == 0) {
        diagnostics.shader_error = result;
        return 0;
    }
    const bytes = com.method(*const fn (usize) callconv(.winapi) usize, code, 3)(code);
    var object: usize = 0;
    if (com.method(*const fn (usize, usize, *usize) callconv(.winapi) i32, device, 106)(device, bytes, &object) < 0) return 0;
    return object;
}
fn initialize(device: usize) bool {
    if (owner != device) {
        release();
        owner = device;
    }
    if (shader != 0) return true;
    if (failed == device) return false;
    failed = device;
    const library = api.GetModuleHandleW(std.unicode.utf8ToUtf16LeStringLiteral("d3dx9_41.dll"));
    if (library == 0) return false;
    const compiler = api.GetProcAddress(library, "D3DXCompileShader");
    const loader = api.GetProcAddress(library, "D3DXCreateTextureFromFileInMemoryEx");
    if (compiler == 0 or loader == 0) return false;
    const Compile = *const fn ([*]const u8, u32, usize, usize, [*:0]const u8, [*:0]const u8, u32, *usize, *usize, usize) callconv(.winapi) i32;
    var code: usize = 0;
    var errors: usize = 0;
    defer com.release(code);
    defer com.release(errors);
    const result = @as(Compile, @ptrFromInt(compiler))(source.ptr, source.len, 0, 0, "main", "ps_2_0", 0, &code, &errors, 0);
    diagnostics.shader_error = result;
    if (errors != 0) {
        const data = com.method(*const fn (usize) callconv(.winapi) usize, errors, 3)(errors);
        const size = com.method(*const fn (usize) callconv(.winapi) u32, errors, 4)(errors);
        const count = @min(size, diagnostics.message.len - 1);
        @memcpy(diagnostics.message[0..count], @as([*]const u8, @ptrFromInt(data))[0..count]);
        diagnostics.message[count] = 0;
    }
    if (result < 0 or code == 0) return false;
    const data = com.method(*const fn (usize) callconv(.winapi) usize, code, 3)(code);
    var compiled: usize = 0;
    if (com.method(*const fn (usize, usize, *usize) callconv(.winapi) i32, device, 106)(device, data, &compiled) < 0) return false;
    const Load = *const fn (usize, [*]const u8, u32, u32, u32, u32, u32, u32, u32, u32, u32, u32, usize, usize, *usize) callconv(.winapi) i32;
    for (art.parts, 0..) |part, i| {
        for ([_][]const u8{ part.color, part.normal }, 0..) |bytes, j| {
            if (@as(Load, @ptrFromInt(loader))(device, bytes.ptr, @intCast(bytes.len), 0xfffffffe, 0xfffffffe, 1, 0, 21, 1, 1, 1, 0, 0, 0, &textures[i][j]) < 0) {
                com.release(compiled);
                return false;
            }
        }
    }
    const Element = extern struct { stream: u16, offset: u16, kind: u8, method: u8, usage: u8, index: u8 };
    // A non-FVF texture element keeps D3D9 from retaining a cached FVF after an empty input layout is restored.
    const elements = [_]Element{
        .{ .stream = 0, .offset = 0, .kind = 3, .method = 0, .usage = 9, .index = 0 },
        .{ .stream = 0, .offset = 16, .kind = 4, .method = 0, .usage = 5, .index = 1 },
        .{ .stream = 0, .offset = 20, .kind = 1, .method = 0, .usage = 5, .index = 0 },
        .{ .stream = 255, .offset = 0, .kind = 17, .method = 0, .usage = 0, .index = 0 },
    };
    if (com.method(*const fn (usize, [*]const Element, *usize) callconv(.winapi) i32, device, 86)(device, &elements, &declaration) < 0) {
        com.release(compiled);
        return false;
    }
    shadow_shader = compileEffect(device, compiler, shadow_source);
    waiting_shader = compileEffect(device, compiler, waiting_source);
    base_shader = compileEffect(device, compiler, base_source);
    if (shadow_shader == 0 or waiting_shader == 0 or base_shader == 0) {
        com.release(compiled);
        return false;
    }
    shader = compiled;
    started = api.GetTickCount();
    failed = 0;
    return true;
}
pub fn draw(device: usize, width: u32, height: u32, scale: f32, offset_x: f32, offset_y: f32, state: State) bool {
    if (width == 0 or height == 0 or !initialize(device)) return false;
    var block: usize = 0;
    if (com.method(*const fn (usize, u32, *usize) callconv(.winapi) i32, device, 59)(device, 1, &block) < 0 or block == 0) return false;
    defer com.release(block);
    defer _ = com.method(*const fn (usize) callconv(.winapi) i32, block, 5)(block);
    _ = obj(device, 92, 0);
    _ = obj(device, 107, shader);
    _ = obj(device, 87, declaration);
    for ([_][2]u32{ .{ 7, 0 }, .{ 14, 0 }, .{ 22, 1 }, .{ 27, 1 }, .{ 19, 5 }, .{ 20, 6 }, .{ 28, 0 }, .{ 15, 0 }, .{ 168, 15 }, .{ 174, 0 }, .{ 194, 0 } }) |r| rs(device, r[0], r[1]);
    for (0..2) |sampler| for ([_][2]u32{ .{ 1, 3 }, .{ 2, 3 }, .{ 5, 2 }, .{ 6, 2 }, .{ 7, 0 }, .{ 11, 0 } }) |s| {
        _ = com.method(*const fn (usize, u32, u32, u32) callconv(.winapi) i32, device, 69)(device, @intCast(sampler), s[0], s[1]);
    };
    const light = [4]f32{ mouse[0], mouse[1], @as(f32, @floatFromInt(api.GetTickCount() -% started)) / 1000, 0 };
    constants(device, 0, &light);
    const now = api.GetTickCount();
    const dt = if (last_tick == 0) @as(f32, 1.0 / 60.0) else @min(0.1, @as(f32, @floatFromInt(now -% last_tick)) / 1000);
    last_tick = now;
    for (0..12) |i| {
        const id: i32 = @intCast(i);
        const h: f32 = if (state.hovered == id) 1 else 0;
        hover_amount[i] = if (state.reduced) h else h + (hover_amount[i] - h) * @exp(-dt / 0.12);
        if (state.pressed == id and state.hovered == id) press_amount[i] = 1 else press_amount[i] = if (state.reduced) 0 else press_amount[i] * @exp(-dt / 0.055);
    }
    for (&camera_amount, 0..) |*v, i| {
        const goal: f32 = if (@as(i32, @intCast(i)) - 1 == state.camera) 1 else 0;
        v.* = if (state.reduced) goal else goal + (v.* - goal) * @exp(-dt / 0.045);
    }
    const sound_target: f32 = if (state.sound_enabled) 1 else 0;
    sound_amount = if (state.reduced) sound_target else sound_target + (sound_amount - sound_target) * @exp(-dt / 0.045);
    connection.advance(if(state.fault)4 else state.lan, dt, state.reduced);
    diagnostics.peer_x = connection.peerX();
    diagnostics.confirmation = connection.confirmation;
    var drawn: usize = 0;
    const waiting = !state.fault and (state.lan == 1 or state.lan == 2);
    var waiting_texture: usize = 0;
    for (art.parts, 0..) |part, index| if (part.control == 104) { waiting_texture = index; };
    var hourglass_texture: usize = 0;
    for (art.parts, 0..) |part, index| if (part.control == 200) { hourglass_texture = index; };
    for (art.parts, 0..) |part, i| {
        const id = part.control;
        if (id == 104 or id == 200) continue;
        if (id >= 3 and id <= 5 and part.selected and camera_amount[@intCast(id - 3)] < 0.005) continue;
        if (id == 9 and !state.hub) continue;
        if (id == 10 and part.selected and sound_amount < 0.005) continue;
        const panes: [3]i32 = switch (id) {
            -1, 6, 7, 11 => .{ -1, -2, -2 },
            0 => .{ 1, -2, -2 },
            1 => .{ 0, 2, -2 },
            2 => .{ 0, 1, -2 },
            3, 4, 5, 9, 10, 103 => .{ 3, -2, -2 },
            8 => .{ 1, 3, -2 },
            100 => .{ 0, 2, -2 },
            101, 102 => .{ -1, -2, -2 },
            else => .{ -2, -2, -2 },
        };
        for (panes) |pane| {
            if (pane == -2) continue;
            const weight = if (id == 101 or id == 102) state.weights[0] + state.weights[2] + state.weights[3] else if (pane < 0) @as(f32, 1) else state.weights[@intCast(pane)];
            const alpha = weight * state.opening * (if (id >= 3 and id <= 5 and part.selected) camera_amount[@intCast(id - 3)] else if (id == 10 and part.selected) sound_amount else @as(f32, 1));
            if (alpha < 0.005) continue;
            const shift = if (pane < 0) @as(f32, 0) else (1 - weight) * (if (pane < @as(i32, @intCast(state.view))) @as(f32, -22) else 22);
            var rect = part.rect;
            if (id == 8) rect[0] -= 96;
            if (id == 1 and pane == 2) rect[0] += 240;
            if (id == 2 and pane == 1) rect[0] -= 240;
            if (id == 100) {
                const factor: f32 = if (pane == 2) 0.82 else 1;
                const center_x: f32 = if (pane == 2) (594 + connection.peerX()) / 2 else 640;
                rect[0] = center_x + (rect[0] - 640) * factor;
                rect[1] = 324 + (rect[1] - 324) * factor - (if (pane == 2) @as(f32, 24) else 0);
                rect[2] *= factor;
                rect[3] *= factor;
            }
            var avatar_strength: f32 = 0;
            var avatar_center: [2]f32 = .{ 0, 0 };
            var avatar_scale: f32 = 1;
            if (id == 101 or id == 102) {
                const player: usize = @intCast(id - 100);
                const visible = state.weights[0] + state.weights[2] + state.weights[3];
                const w0 = state.weights[0] / visible;
                const w2 = state.weights[2] / visible;
                const w3 = state.weights[3] / visible;
                const local_strength: f32 = if (state.is_host == (id == 101)) 1 else 0;
                avatar_strength = camera_amount[player];
                if (state.camera == -1) avatar_strength += w2 * local_strength;
                const cx: f32 = if (id == 101) 640 else 808;
                const home_x: f32 = if (id == 101) 568 else 712;
                const session_x: f32 = if (id == 101) 594 else connection.peerX();
                const target_x = w0 * home_x + w2 * session_x + w3 * cx;
                const target_y = w0 * 324 + w2 * (if (id == 101) @as(f32, 300) else connection.peerY(state.reduced)) + w3 * 300;
                const hover = hover_amount[player + 3];
                const factor = (w0 * 1.5 + w2 * 1.23 + w3) * (1 + w3 * (avatar_strength * 0.06 + hover * 0.04));
                avatar_center = .{ target_x, target_y };
                avatar_scale = factor;
                rect[0] = target_x + (rect[0] - cx) * factor;
                rect[1] = target_y + (rect[1] - 300) * factor;
                rect[2] *= factor;
                rect[3] *= factor;
            }
            const press = if (id >= 0 and id < 12) press_amount[@intCast(id)] else 0;
            const pointer_hover = if (id >= 0 and id < 12) hover_amount[@intCast(id)] else 0;
            if (id >= 1 and id <= 11) {
                const f = 1 + pointer_hover * 0.012 - press * 0.018;
                rect[0] -= rect[2] * (f - 1) / 2;
                rect[1] -= rect[3] * (f - 1) / 2;
                rect[2] *= f;
                rect[3] *= f;
            }
            rect[0] += shift;
            rect[1] += press * 8 - pointer_hover * 3;
            const x = offset_x + rect[0] * scale - 0.5;
            const y = offset_y + rect[1] * scale - 0.5;
            const w = rect[2] * scale;
            const h = rect[3] * scale;
            const quad = [4]Vertex{ .{ .x = x, .y = y, .u = 0, .v = 0 }, .{ .x = x + w, .y = y, .u = 1, .v = 0 }, .{ .x = x, .y = y + h, .u = 0, .v = 1 }, .{ .x = x + w, .y = y + h, .u = 1, .v = 1 } };
            for (0..2) |j| {
                _ = com.method(*const fn (usize, u32, usize) callconv(.winapi) i32, device, 65)(device, @intCast(j), textures[if (id == 102 and waiting and state.weights[2] > 0.01) waiting_texture else i][j]);
            }
            const region = [4]f32{ rect[0] / 1280, rect[1] / 720, rect[2] / 1280, rect[3] / 720 };
            constants(device, 1, &region);
            const hover = if (id >= 0 and id < 12) hover_amount[@intCast(id)] else 0;
            const presence: f32 = if (id == 102) 1 - state.weights[2] * (1 - connection.confirmation) * 0.28 else 1;
            const effect = [4]f32{ 0, (1 + hover * 0.06 + avatar_strength * 0.12) * presence, alpha, @floatFromInt(@intFromBool(id == 0 and state.address_invalid)) };
            constants(device, 2, &effect);
            const link = [4]f32{ if (id == 100 and pane == 2) connection.confirmation else 0, connection.pulseX(), if (id == 100 and pane == 2 and !state.reduced and (state.lan == 1 or state.lan == 2)) 0.9 else 0, 0 };
            constants(device, 3, &link);
            const focus: f32 = if (state.focused == id) 0.4 else 0;
            const active = @max(hover, focus);
            const material = [4]f32{ if (id >= 1 and id <= 11) active else 0, press, (mouse[0] - region[0]) / region[2] - 0.5, hover };
            constants(device, 4, &material);
            if (id >= 1 and id <= 11 and active > 0.01 and !part.selected) {
                const depth = (1 - press) * active;
                const shadow = [4]f32{ 2 * depth / rect[2], (3 + 7 * depth) / rect[3], 2 / rect[2], 2 / rect[3] };
                constants(device, 5, &shadow);
                _ = obj(device, 107, shadow_shader);
                _ = com.method(*const fn (usize, u32, u32, *const [4]Vertex, u32) callconv(.winapi) i32, device, 83)(device, 5, 2, &quad, @sizeOf(Vertex));
                _ = obj(device, 107, shader);
            }
            if (id == -1) _ = obj(device, 107, base_shader);
            if (com.method(*const fn (usize, u32, u32, *const [4]Vertex, u32) callconv(.winapi) i32, device, 83)(device, 5, 2, &quad, @sizeOf(Vertex)) < 0) return false;
            if (id == -1) _ = obj(device, 107, shader);
            if (id == 102 and waiting and state.weights[2] > 0.01) {
                const angle: f32 = 0;
                const c = @cos(angle);
                const s = @sin(angle);
                const radius = 22 * avatar_scale * scale;
                const center_x = offset_x + avatar_center[0] * scale - 0.5;
                const center_y = offset_y + avatar_center[1] * scale - 0.5;
                var icon: [4]Vertex = undefined;
                for ([_][2]f32{ .{ -1, -1 }, .{ 1, -1 }, .{ -1, 1 }, .{ 1, 1 } }, 0..) |p, k| {
                    icon[k] = .{ .x = center_x + (p[0] * c - p[1] * s) * radius * (96.0 / 112.0), .y = center_y + (p[0] * s + p[1] * c) * radius, .u = (p[0] + 1) / 2, .v = (p[1] + 1) / 2 };
                }
                const frame: f32 = if (state.reduced) 0 else @mod(@floor(connection.elapsed * 12), 24);
                const wait = [4]f32{ frame, state.weights[2] * alpha, 0, 0 };
                for (0..2) |j| {
                    _ = com.method(*const fn (usize, u32, usize) callconv(.winapi) i32, device, 65)(device, @intCast(j), textures[hourglass_texture][j]);
                }
                constants(device, 6, &wait);
                _ = obj(device, 107, waiting_shader);
                _ = com.method(*const fn (usize, u32, u32, *const [4]Vertex, u32) callconv(.winapi) i32, device, 83)(device, 5, 2, &icon, @sizeOf(Vertex));
                _ = obj(device, 107, shader);
            }
            drawn += 1;
        }
    }
    diagnostics.vertices = drawn * 4;
    diagnostics.draws +%= 1;
    return true;
}
