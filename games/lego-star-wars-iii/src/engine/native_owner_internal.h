#pragma once
#include "native_owner.h"
struct __declspec(align(16)) NativeOwnerScope {
 unsigned char in_fx[512],out_fx[512];
 OwnerU32 in_regs[9],out_regs[9];
 OwnerU32 in_error,out_error,entry_esp,saved_esp;
 void *target;
 OwnerU32 reserved;
 unsigned char helper_fx[512];
 NativeOwnerScope *parent;
 OwnerU32 nonce,thread,depth,linked,usable,begin_entered,end_done;
 unsigned char storage[64];
 NativeOwnerCallbacks callbacks;
 OwnerU32 delegate_esp,delegate_active;
};
typedef char owner_layout_a[__builtin_offsetof(NativeOwnerScope,target)==1112?1:-1];
typedef char owner_layout_b[__builtin_offsetof(NativeOwnerScope,helper_fx)==1120?1:-1];
typedef char owner_layout_c[__builtin_offsetof(NativeOwnerScope,storage)==1664?1:-1];
typedef char owner_layout_size[sizeof(NativeOwnerScope)<=2048?1:-1];
typedef char owner_layout_delegate[__builtin_offsetof(NativeOwnerScope,delegate_esp)==1744?1:-1];
typedef char owner_layout_active[__builtin_offsetof(NativeOwnerScope,delegate_active)==1748?1:-1];
void __cdecl owner_c(NativeOwnerScope *);
void __cdecl inner_bridge(NativeOwnerScope *);
void __cdecl owner_enter(NativeOwnerScope *);
void __cdecl owner_leave(NativeOwnerScope *,int);
