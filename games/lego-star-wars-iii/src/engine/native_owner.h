#pragma once
typedef unsigned int OwnerU32;
typedef struct NativeOwnerScope NativeOwnerScope;
typedef struct NativeOwnerInput {
 const unsigned char *fx;
 const OwnerU32 *regs;
 OwnerU32 last_error,caller_esp;
} NativeOwnerInput;
typedef enum NativeOwnerExit {OWNER_NORMAL,OWNER_UNWIND} NativeOwnerExit;
typedef enum NativeOwnerReject {OWNER_DEPTH_BARRIER,OWNER_TLS_FAILURE,OWNER_NONCE_EXHAUSTED} NativeOwnerReject;
typedef struct NativeOwnerCallbacks {
 unsigned version;
 void (__cdecl *begin)(NativeOwnerScope *,const NativeOwnerInput *,void *);
 void (__cdecl *end)(NativeOwnerScope *,NativeOwnerExit,void *);
 void (__cdecl *reject)(NativeOwnerScope *,NativeOwnerScope *,NativeOwnerReject,void *);
} NativeOwnerCallbacks;
int native_owner_configure(void *,const NativeOwnerCallbacks *);
NativeOwnerScope *native_owner_current(void);
int native_owner_scope_valid(const NativeOwnerScope *,unsigned);
unsigned native_owner_scope_nonce(const NativeOwnerScope *);
int native_owner_scope_usable(const NativeOwnerScope *);
OwnerU32 native_owner_scope_delegate_esp(const NativeOwnerScope *,unsigned);
/* Helper-only: call under an already captured native GPR/flags context. */
int native_owner_poll_fault(void);
OwnerU32 __attribute__((thiscall)) native_owner_entry(void *);
