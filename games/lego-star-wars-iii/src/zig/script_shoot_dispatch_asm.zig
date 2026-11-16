comptime {
    asm (
        \\.text
        \\.globl _script_shoot_dispatch_call_original
        \\_script_shoot_dispatch_call_original:
        \\pushfl
        \\    pushal
        \\    movl 40(%esp),%eax
        \\    pushl %eax
        \\    movl 516(%eax),%edx
        \\    leal 40(%edx),%esi
        \\    pushl 24(%esi)
        \\    pushl 20(%esi)
        \\    pushl 16(%esi)
        \\    pushl 12(%esi)
        \\    pushl 8(%esi)
        \\    pushl 4(%esi)
        \\    pushl 0(%esi)
        \\    fxrstor (%eax)
        \\    movl 512(%eax),%ecx
        \\    movl %ecx,%fs:0x34
        \\    pushl 32(%edx)
        \\    popfl
        \\    movl 0(%edx),%edi
        \\    movl 4(%edx),%esi
        \\    movl 8(%edx),%ebp
        \\    movl 16(%edx),%ebx
        \\    movl 24(%edx),%ecx
        \\    movl 28(%edx),%eax
        \\    movl 20(%edx),%edx
        \\    call *_script_shoot_dispatch_original
        \\    pushfl
        \\    pushal
        \\    cld
        \\    movl 36(%esp),%eax
        \\    movl 516(%eax),%edi
        \\    movl %esp,%esi
        \\    movl $9,%ecx
        \\    rep movsl
        \\    fxsave (%eax)
        \\    movl %fs:0x34,%edx
        \\    movl %edx,512(%eax)
        \\    addl $40,%esp
        \\    popal
        \\    popfl
        \\    ret
        \\    
        \\.text
        \\.globl _native_script_shoot_dispatch_entry
        \\_native_script_shoot_dispatch_entry:
        \\pushfl
        \\    pushal
        \\    movl %esp,%edx
        \\    subl $544,%esp
        \\    andl $-16,%esp
        \\    movl %edx,516(%esp)
        \\    fxsave (%esp)
        \\    movl %fs:0x34,%eax
        \\    movl %eax,512(%esp)
        \\    cld
        \\    movl %esp,%eax
        \\    subl $12,%esp
        \\    pushl %eax
        \\    call _script_shoot_dispatch_run
        \\    addl $16,%esp
        \\    fxrstor (%esp)
        \\    movl 512(%esp),%eax
        \\    movl %eax,%fs:0x34
        \\    movl 516(%esp),%esp
        \\    popal
        \\    popfl
        \\    ret $28
        \\    
    );
}
