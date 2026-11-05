#include "native_owner_internal.h"
__declspec(noinline) void __cdecl owner_c(NativeOwnerScope *scope){
 int returned=0;
 __try {owner_enter(scope);inner_bridge(scope);returned=1;}
 __finally {owner_leave(scope,!returned);}
}
