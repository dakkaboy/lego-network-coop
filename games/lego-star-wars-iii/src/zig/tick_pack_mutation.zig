pub export var clonewars_pack_membership_revision: u32 = 0;
pub export var clonewars_pack_membership_observer_active: u32 = 0;
pub fn changed() void {
    _ = @atomicRmw(u32, &clonewars_pack_membership_revision, .Add, 1, .monotonic);
}
pub export var pack_remove_resume: usize = 0x40ab95;
pub export var pack_construct_resume: usize = 0x461e57;
pub export var pack_destroy_resume: usize = 0x4620e7;
comptime {
    asm (
        \\.text
        \\.globl _native_pack_remove_observer
        \\_native_pack_remove_observer:
        \\pushfl
        \\lock incl _clonewars_pack_membership_revision
        \\popfl
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\jmp *_pack_remove_resume
        \\.globl _native_pack_construct_observer
        \\_native_pack_construct_observer:
        \\pushfl
        \\lock incl _clonewars_pack_membership_revision
        \\popfl
        \\pushl $-1
        \\pushl $0xa9ce96
        \\jmp *_pack_construct_resume
        \\.globl _native_pack_destroy_observer
        \\_native_pack_destroy_observer:
        \\pushfl
        \\lock incl _clonewars_pack_membership_revision
        \\popfl
        \\pushl $-1
        \\pushl $0xa9ced6
        \\jmp *_pack_destroy_resume
    );
}
