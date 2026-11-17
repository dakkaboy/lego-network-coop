pub extern fn invoke_wait(usize) f32;
comptime {
    asm (
        \\.text
        \\_invoke_wait:
        \\pushl %esi
        \\movl 8(%esp),%esi
        \\call _native_rts_wait_seed_input
        \\popl %esi
        \\ret
    );
}
pub extern fn invoke_pickup_render(usize) u32;
comptime {
    asm (
        \\.text
        \\_invoke_pickup_render:
        \\pushl %ebx
        \\pushl %edi
        \\movl 12(%esp),%edi
        \\movl $0x1234babe,%ebx
        \\call _native_pickup_render_primary_bridge
        \\movl %ebx,%eax
        \\popl %edi
        \\popl %ebx
        \\ret
    );
}
pub extern fn invoke_actor_turn(usize, u32, *u16) u32;
comptime {
    asm (
        \\.text
        \\_invoke_actor_turn:
        \\pushl %ebx
        \\pushl %esi
        \\pushl %edi
        \\movl 16(%esp),%esi
        \\movl 20(%esp),%eax
        \\movl 24(%esp),%ebx
        \\movl $0x1234babe,%ecx
        \\movl $0x87654321,%edx
        \\call _native_actor_turn_input_bridge
        \\movl %eax,_actor_turn_bridge_observed
        \\movl %ecx,_actor_turn_bridge_observed+4
        \\movl %edx,_actor_turn_bridge_observed+8
        \\pushfl
        \\popl %edx
        \\movl %edx,_actor_turn_bridge_observed+12
        \\movl %edi,%eax
        \\popl %edi
        \\popl %esi
        \\popl %ebx
        \\ret
    );
}
pub extern fn invoke_turn(usize, u32, *u32) u32;
comptime {
    asm (
        \\.text
        \\_invoke_turn:
        \\pushl %ebx
        \\pushl %edi
        \\subl $32,%esp
        \\movl 44(%esp),%ebx
        \\movl 48(%esp),%eax
        \\movl 52(%esp),%edx
        \\movl (%edx),%ecx
        \\movl %ecx,24(%esp)
        \\movl $0x1234babe,%ecx
        \\cmpl %ecx,%ecx
        \\stc
        \\call _native_rts_turn_input_bridge
        \\movl %eax,_rts_turn_bridge_observed
        \\movl %edx,_rts_turn_bridge_observed+4
        \\movl %ecx,_rts_turn_bridge_observed+8
        \\pushfl
        \\popl %edx
        \\movl %edx,_rts_turn_bridge_observed+12
        \\movl 52(%esp),%edx
        \\movl 24(%esp),%ecx
        \\movl %ecx,(%edx)
        \\movl %edi,%eax
        \\addl $32,%esp
        \\popl %edi
        \\popl %ebx
        \\ret
    );
}
pub extern fn invoke_weapon_commands(usize) u32;
comptime {
    asm (
        \\.text
        \\_invoke_weapon_commands:
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\movl $0xcafebabe,%eax
        \\movl $0x12345678,%ecx
        \\movl $0x87654321,%edx
        \\call _native_weapon_commands_input
        \\pushfl
        \\cmpl $0xcafebabe,%eax
        \\jne 1f
        \\cmpl $0x12345678,%ecx
        \\jne 1f
        \\cmpl $0x87654321,%edx
        \\jne 1f
        \\popl %eax
        \\popl %ebx
        \\ret
        \\1: addl $4,%esp
        \\popl %ebx
        \\movl $-1,%eax
        \\ret
    );
}
pub extern fn invoke_gizmo_turret(usize) u32;
comptime {
    asm (
        \\.text
        \\_invoke_gizmo_turret:
        \\pushl %ebx
        \\movl 8(%esp),%ebx
        \\movl $0x12345678,%ecx
        \\movl $0x87654321,%edx
        \\cmpl %ecx,%ecx
        \\stc
        \\call _native_gizmo_turret_bridge
        \\pushfl
        \\cmpl $0x1234,%eax
        \\jne 1f
        \\cmpl $0x12345678,%ecx
        \\jne 1f
        \\cmpl $0x87654321,%edx
        \\jne 1f
        \\popl %eax
        \\popl %ebx
        \\ret
        \\1: addl $4,%esp
        \\popl %ebx
        \\movl $-1,%eax
        \\ret
    );
}
pub extern fn invoke_goal_move(usize, usize) f32;
comptime {
    asm (
        \\.text
        \\_invoke_goal_move:
        \\pushl %ebx; pushl %esi; pushl %edi; subl $128,%esp
        \\movl 148(%esp),%esi; leal 60(%esp),%edi; movl $8,%ecx; cld; rep movsl
        \\movl 144(%esp),%esi; leal 0x20(%esi),%edi; movl $0x11223344,%ebx
        \\movl $0x12345678,%eax; movl $0x87654321,%ecx; movl $0xcafebabe,%edx; stc
        \\call _native_pack_goal_move_bridge
        \\movl %eax,_goal_bridge_observed; movl %ecx,_goal_bridge_observed+4
        \\movl %edx,_goal_bridge_observed+8; pushfl; popl %eax; movl %eax,_goal_bridge_observed+12
        \\movl 148(%esp),%edi; leal 60(%esp),%esi; movl $8,%ecx; cld; rep movsl
        \\addl $128,%esp; popl %edi; popl %esi; popl %ebx; ret
    );
}
pub extern fn invoke_goal_active(usize, usize) f32;
comptime {
    asm (
        \\.text
        \\_invoke_goal_active:
        \\pushl %ebx; pushl %esi; pushl %edi; subl $128,%esp
        \\movl 148(%esp),%esi; leal 92(%esp),%edi; movl $8,%ecx; cld; rep movsl
        \\movl 144(%esp),%esi; leal 0x20(%esi),%ebx; movl $0x11223344,%edi
        \\movl $0x12345678,%eax; movl $0x87654321,%ecx; movl $0xcafebabe,%edx; stc
        \\call _native_pack_goal_active_bridge
        \\movl %eax,_goal_bridge_observed; movl %ecx,_goal_bridge_observed+4
        \\movl %edx,_goal_bridge_observed+8; pushfl; popl %eax; movl %eax,_goal_bridge_observed+12
        \\movl 148(%esp),%edi; leal 92(%esp),%esi; movl $8,%ecx; cld; rep movsl
        \\addl $128,%esp; popl %edi; popl %esi; popl %ebx; ret
    );
}
pub export var actor_turn_bridge_observed: [4]u32 = @splat(0);
pub export var rts_turn_bridge_observed: [4]u32 = @splat(0);
pub export var goal_bridge_observed: [4]u32 = @splat(0);
extern fn native_pack_remove_observer() void;
extern fn native_pack_construct_observer() void;
extern fn native_pack_destroy_observer() void;
pub extern fn pack_remove_fixture_resume() void;
pub extern fn pack_construct_fixture_resume() void;
pub extern fn pack_destroy_fixture_resume() void;
pub extern fn invoke_pack_observer(u32) void;
export var pack_observer_fixture_targets: [3]@TypeOf(&native_pack_remove_observer) = .{ &native_pack_remove_observer, &native_pack_construct_observer, &native_pack_destroy_observer };
export var pack_observer_fixture_target: usize = 0;
pub export var pack_observer_fixture_observed: [12]u32 = @splat(0);
pub export var pack_observer_fpu_before: [512]u8 align(16) = @splat(0);
pub export var pack_observer_fpu_after: [512]u8 align(16) = @splat(0);
export var pack_observer_fpu_caller: [512]u8 align(16) = @splat(0);
comptime {
    asm (
        \\.text
        \\_invoke_pack_observer:
        \\pushal
        \\movl 36(%esp),%eax
        \\movl _pack_observer_fixture_targets(,%eax,4),%eax
        \\movl %eax,_pack_observer_fixture_target
        \\fxsave _pack_observer_fpu_caller
        \\fninit
        \\fld1
        \\fldpi
        \\fxsave _pack_observer_fpu_before
        \\movl $0x12345678,%eax
        \\movl $0x87654321,%ecx
        \\movl $0x13579bdf,%edx
        \\movl $0x2468ace0,%ebx
        \\movl $0x11223344,%esi
        \\movl $0x55667788,%edi
        \\movl $0x19283746,%ebp
        \\stc
        \\pushl $0x1badb002
        \\call *_pack_observer_fixture_target
        \\fxsave _pack_observer_fpu_after
        \\fxrstor _pack_observer_fpu_caller
        \\popal
        \\ret
        \\_pack_remove_fixture_resume:
        \\call _pack_observer_fixture_capture
        \\popl %ebx
        \\ret $4
        \\_pack_construct_fixture_resume:
        \\call _pack_observer_fixture_capture
        \\jmp _pack_observer_fixture_seh
        \\_pack_destroy_fixture_resume:
        \\call _pack_observer_fixture_capture
        \\_pack_observer_fixture_seh:
        \\pushl %eax
        \\movl 4(%esp),%eax
        \\movl %eax,_pack_observer_fixture_observed+40
        \\movl 8(%esp),%eax
        \\movl %eax,_pack_observer_fixture_observed+44
        \\popl %eax
        \\leal 8(%esp),%esp
        \\ret $4
        \\_pack_observer_fixture_capture:
        \\movl %eax,_pack_observer_fixture_observed
        \\movl %ecx,_pack_observer_fixture_observed+4
        \\movl %edx,_pack_observer_fixture_observed+8
        \\movl %ebx,_pack_observer_fixture_observed+12
        \\movl %esi,_pack_observer_fixture_observed+16
        \\movl %edi,_pack_observer_fixture_observed+20
        \\movl %ebp,_pack_observer_fixture_observed+24
        \\pushfl
        \\popl _pack_observer_fixture_observed+32
        \\ret
    );
}
