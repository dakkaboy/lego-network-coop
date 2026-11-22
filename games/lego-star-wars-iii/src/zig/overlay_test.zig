const std = @import("std");
const ui = @import("overlay.zig");
const win = @import("win32.zig");
const check = @import("native_test_support.zig").check;
export var image: [0x1200000]u8 linksection(".text") = @splat(0);
extern "kernel32" fn Sleep(u32) callconv(.winapi) void;
var starts: u32 = 0;
var stops: u32 = 0;
var returns: u32 = 0;
var selected: c_int = -1;
var status: c_int = 0;
var host = false;
var last_address: [16]u8 = @splat(0);
export fn lan_status() c_int { return status; }
export fn lan_ping_us() u32 { return 1000; }
export fn lan_error() i32 { return 10061; }
export fn lan_is_host() c_int { return @intFromBool(host); }
export fn lan_start(role: c_int, address: [*:0]const u8) void {
    starts += 1; host = role != 0; status = if(host) 1 else 2;
    @memset(&last_address, 0); const text=std.mem.span(address); @memcpy(last_address[0..text.len],text);
}
export fn lan_stop() void { stops += 1; status = 0; }
export fn camera_select(value: c_int) void { selected = value; }
export fn camera_selected() c_int { return selected; }
export fn game_can_return_to_hub() c_int { return 1; }
export fn game_request_return_to_hub() c_int { returns += 1; return 1; }
export fn game_sync_status() c_int { return 0; }
export fn game_sync_restart_required() c_int { return 0; }
fn input(message: u32, wp: usize, lp: isize) void { _=ui.coop_input(0,message,wp,lp); }
fn key(code: usize) void { input(0x100,code,0); }
fn click(x: u16,y: u16) void {
    const point: isize=@intCast(@as(u32,x)|(@as(u32,y)<<16));
    input(0x200,0,point);input(0x201,1,point);input(0x202,0,point);
}
fn viewport(_: usize, _: usize) callconv(.winapi) i32 { return @bitCast(@as(u32,0x80004005)); }
var table: [49]usize=@splat(0);
const Device=extern struct { vtable: [*]usize };
var device: Device=.{.vtable=&table};
fn tick() void { Sleep(20);ui.coop_draw(@intFromPtr(&device),&@as([2]ui.Hud,@splat(std.mem.zeroes(ui.Hud)))); }
pub fn main() void {
    check(@src(),@sizeOf(ui.Hud)==24 and @offsetOf(ui.Hud,"studs")==16);
    check(@src(),@intFromPtr(&image)<0xf91eb4 and @intFromPtr(&image)+image.len>0xf91eb4);
    var old: u32=0;check(@src(),win.VirtualProtect(0xf91000,0x1000,4,&old)!=0);
    table[48]=@intFromPtr(&viewport);ui.audio.enabled=false;
    win.store(u8,0xf91eb4,0x80);ui.coop_toggle();
    check(@src(),win.load(u8,0xf91eb4)==0x82);
    click(880,488);check(@src(),ui.previewSnapshot().view==1);
    for("999.1.1.1") |c| input(0x102,c,0);key(13);
    check(@src(),ui.previewSnapshot().invalid and starts==0);
    for("10.2.3.4") |c| input(0x102,c,0);key(13);
    check(@src(),starts==1 and status==2 and std.mem.eql(u8,std.mem.sliceTo(&last_address,0),"10.2.3.4"));
    click(200,545);click(808,372);check(@src(),selected==1);
    key(27);check(@src(),ui.previewSnapshot().view==2 and stops==0);
    click(640,488);check(@src(),stops==1 and ui.previewSnapshot().view==0);
    click(400,488);check(@src(),starts==2 and host and status==1);
    click(200,545);click(640,487);check(@src(),returns==0);
    key(27);click(640,487);click(640,487);check(@src(),returns==1);
    for(0..20) |_| tick();
    check(@src(),!ui.previewSnapshot().menu and win.load(u8,0xf91eb4)==0x80);
    status=0;ui.coop_toggle();
    input(0x201,1,400|(488<<16));input(0x200,0,100|(100<<16));input(0x202,0,100|(100<<16));
    check(@src(),starts==2);
    click(1087,139);for(0..20) |_| tick();
    check(@src(),!ui.previewSnapshot().menu and win.load(u8,0xf91eb4)==0x80);
    check(@src(),ui.coop_input(0,0x100,13,0)==0);
    ui.padInput(0x30, 0);
    check(@src(), ui.previewSnapshot().menu and ui.previewSnapshot().gamepad);
    ui.padInput(2, 0);
    ui.padInput(2, 2);
    check(@src(), ui.previewSnapshot().focus == 2);
    ui.padInput(0x1000, 0);
    ui.padInput(0x1000, 0);
    ui.padInput(8, 0);
    ui.padInput(0x1000, 0); // 1
    ui.padInput(2, 0);
    for (0..3) |_| ui.padInput(8, 0);
    ui.padInput(0x1000, 0); // .
    input(0x102, '2', 0);
    check(@src(), !ui.previewSnapshot().gamepad and ui.previewSnapshot().focus == 0);
    for (".3.4") |character| input(0x102, character, 0);
    key(13);
    check(@src(), starts == 3 and std.mem.eql(u8, std.mem.sliceTo(&last_address, 0), "1.2.3.4"));
    key(9);
    check(@src(), !ui.previewSnapshot().gamepad);
    ui.coop_release_fonts();
    std.debug.print("Overlay live-action routing, validation, session preservation, hub confirmation and input restoration passed\n",.{});
}
