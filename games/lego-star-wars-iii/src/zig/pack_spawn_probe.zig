const win = @import("win32.zig");
pub extern fn pack_spawn_probe() void;
pub extern fn pack_spawn_probe_after() void;
pub extern fn pack_spawn_probe_random() void;
pub extern fn pack_spawn_probe_allocate() void;
pub export var pack_spawn_probe_site: usize = 0;
pub export var pack_spawn_probe_original_rng: usize = 0x6d60d0;
pub export var pack_spawn_probe_source: usize = 0;
pub export var pack_spawn_probe_pool: usize = 0;
pub export var pack_spawn_probe_position: usize = 0;
pub export var pack_spawn_probe_kind: u32 = 0;
pub export var pack_spawn_probe_calls: u32 = 0;
pub export var pack_spawn_probe_regs: [9]u32 = @splat(0);
pub export var pack_spawn_probe_fx: [512]u8 align(16) = @splat(0);
pub export var pack_spawn_probe_cw: u32 = 0x37f;
pub export var pack_spawn_probe_mxcsr: u32 = 0x1f80;
pub export var pack_spawn_probe_xmm: [128]u8 align(16) = @splat(0);
export var pack_spawn_probe_saved_fx: [512]u8 align(16) = @splat(0);
pub fn original() void {
    const random = "\x51\xa1\x8c\x17\xea\x00\x69\xc0\x0d\x66\x19\x00\x05\x5f\xf3\x6e\x3c\xa3\x8c\x17\xea\x00\x25\xff\xff\x7f\x00\x0d\x00\x00\x80\x3f\x89\x04\x24\xd9\x04\x24\xdc\x25\xb8\x74\xad\x00\xd9\x1c\x24\xd9\x04\x24\x59\xc3";
    const bounded = "\xe8\x2b\xd0\xe9\xff\xd9\x44\x24\x08\xd9\xc0\xd9\x44\x24\x04\xd9\xc0\xde\xea\xd9\xc9\xdc\x05\x78\x7b\xad\x00\xd9\x5c\x24\x08\xd9\x44\x24\x08\xde\xcb\xd9\xc0\xde\xc3\xd9\xca\xd9\x5c\x24\x08\xd9\x44\x24\x08\xd8\xd2\xdf\xe0\xf6\xc4\x05\x7a\x22\xdd\xd8\xd9\xc9\xd9\x5c\x24\x08\xd9\x44\x24\x08\xd9\xc9\xd8\xd1\xdf\xe0\xf6\xc4\x05\x7a\x0f\xdd\xd9\xd9\x5c\x24\x08\xd9\x44\x24\x08\xc3\xdd\xda\xeb\xe8\xdd\xd8\xc3";
    @memcpy(@as([*]u8, @ptrFromInt(0x573100))[0..random.len], random);
    @memcpy(@as([*]u8, @ptrFromInt(0x6d60d0))[0..bounded.len], bounded);
    win.store(f64, 0xad74b8, 1);
    win.store(f64, 0xad7b78, 0.10000000149011612);
}
comptime {
    asm (
        \\.text
        \\.globl _pack_spawn_probe_random
        \\_pack_spawn_probe_random:
        \\pushfl
        \\incl _pack_spawn_probe_calls
        \\popfl
        \\jmp *_pack_spawn_probe_original_rng
        \\.globl _pack_spawn_probe_allocate
        \\_pack_spawn_probe_allocate:
        \\pushfl
        \\incl _pack_spawn_probe_calls
        \\popfl
        \\movl $0x13579bdf,%eax
        \\movl $0x2468ace0,%ecx
        \\movl $0x55667788,%edx
        \\stc
        \\ret $12
        \\.globl _pack_spawn_probe
        \\_pack_spawn_probe:
        \\pushfl
        \\pushal
        \\fxsave _pack_spawn_probe_saved_fx
        \\fninit
        \\fldcw _pack_spawn_probe_cw
        \\ldmxcsr _pack_spawn_probe_mxcsr
        \\fldpi
        \\fld1
        \\movdqa _pack_spawn_probe_xmm,%xmm0
        \\movdqa _pack_spawn_probe_xmm+16,%xmm1
        \\movdqa _pack_spawn_probe_xmm+32,%xmm2
        \\movdqa _pack_spawn_probe_xmm+48,%xmm3
        \\movdqa _pack_spawn_probe_xmm+64,%xmm4
        \\movdqa _pack_spawn_probe_xmm+80,%xmm5
        \\movdqa _pack_spawn_probe_xmm+96,%xmm6
        \\movdqa _pack_spawn_probe_xmm+112,%xmm7
        \\cmpl $0,_pack_spawn_probe_kind
        \\jne 1f
        \\pushl $0x3e000000
        \\pushl $0xbe000000
        \\jmp 2f
        \\1: pushl $123
        \\pushl _pack_spawn_probe_position
        \\pushl $0
        \\2: movl _pack_spawn_probe_pool,%ecx
        \\movl _pack_spawn_probe_source,%esi
        \\movl _pack_spawn_probe_pool,%edi
        \\movl $0x13579bdf,%edx
        \\movl $0x2468ace0,%ebx
        \\movl $0x19283746,%ebp
        \\movl $0x89abcdef,%eax
        \\pushl $0x646
        \\popfl
        \\jmp *_pack_spawn_probe_site
        \\.globl _pack_spawn_probe_after
        \\_pack_spawn_probe_after:
        \\fxsave _pack_spawn_probe_fx
        \\pushfl
        \\pushal
        \\movl %esp,%esi
        \\movl $_pack_spawn_probe_regs,%edi
        \\movl $9,%ecx
        \\cld
        \\rep movsl
        \\popal
        \\popfl
        \\cmpl $0,_pack_spawn_probe_kind
        \\jne 3f
        \\addl $8,%esp
        \\3: fxrstor _pack_spawn_probe_saved_fx
        \\popal
        \\popfl
        \\ret
    );
}
