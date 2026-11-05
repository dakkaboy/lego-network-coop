#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "intent_scope_observer.h"
#include "intent_frame_observer.h"
typedef void (__attribute__((cdecl)) *IntentScopeProducer)(void *);
static IntentScopeProducer original_producer;
__declspec(dllexport) volatile LONG clonewars_intent_scope_installed;
__attribute__((used)) static volatile uintptr_t intent_scope_model_resume=0x9bf44d;
static int readable(const void *p,unsigned n){MEMORY_BASIC_INFORMATION m;return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uintptr_t)p+n>=(uintptr_t)p && (uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;}
static void __attribute__((cdecl,noinline)) producer_hook(void *actor){
 if(!clonewars_intent_frame_enabled){original_producer(actor);return;}
 unsigned char fx[512] __attribute__((aligned(16)));uint32_t mxcsr=0x1f80;
 DWORD error=GetLastError();
 __asm__ volatile("fxsave %0;fninit;ldmxcsr %1":"=m"(fx):"m"(mxcsr));
 void *controller=readable(actor,0x6d0)?*(void **)((unsigned char *)actor+0x6cc):NULL;
 uint32_t token=intent_frame_scope_begin(actor,controller,(uint32_t)(uintptr_t)__builtin_return_address(0));
 SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));
 original_producer(actor);
 __asm__ volatile("fxsave %0;fninit;ldmxcsr %1":"=m"(fx):"m"(mxcsr));
 error=GetLastError();intent_frame_scope_end(token);SetLastError(error);
 __asm__ volatile("fxrstor %0"::"m"(fx));
}
__attribute__((used,noinline)) static void intent_scope_model_witness(void *actor,void *controller,void *provider){
 (void)provider;DWORD error=GetLastError();
 if(clonewars_intent_frame_enabled)intent_frame_scope_model(actor,controller);
 SetLastError(error);
}
__attribute__((naked,used)) static void model_thunk(void){__asm__ volatile(INTENT_SCOPE_MODEL_THUNK_ASM);}
int intent_scope_observer_install(void){
 unsigned char *sites[]={(void *)0x9bf280,(void *)0x9bf443};unsigned lengths[]={6,10};
 const unsigned char prefix[2][10]={{0x55,0x8b,0xec,0x83,0xe4,0xf0},{0xf7,0x83,0x7c,0x0c,0,0,0,0,0x80,0}};
 DWORD old[2];unsigned protected_count=0;
 if(clonewars_intent_scope_installed==3)return 1;
 for(unsigned i=0;i<2;++i)if(!readable(sites[i],lengths[i])||memcmp(sites[i],prefix[i],lengths[i])){clonewars_intent_scope_installed=-1;return 0;}
 unsigned char *bridge=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
 if(!bridge){clonewars_intent_scope_installed=-1;return 0;}
 memcpy(bridge,prefix[0],6);bridge[6]=0xe9;*(int32_t *)(bridge+7)=(int32_t)((uintptr_t)sites[0]+6-(uintptr_t)bridge-11);
 for(unsigned i=0;i<2;++i){if(!VirtualProtect(sites[i],lengths[i],PAGE_EXECUTE_READWRITE,&old[i]))goto rollback;++protected_count;}
 original_producer=(IntentScopeProducer)bridge;
 uintptr_t targets[]={(uintptr_t)producer_hook,(uintptr_t)model_thunk};
 for(unsigned i=0;i<2;++i){sites[i][0]=0xe9;*(int32_t *)(sites[i]+1)=(int32_t)(targets[i]-(uintptr_t)sites[i]-5);memset(sites[i]+5,0x90,lengths[i]-5);FlushInstructionCache(GetCurrentProcess(),sites[i],lengths[i]);}
 for(unsigned i=2;i;--i){DWORD ignored;VirtualProtect(sites[i-1],lengths[i-1],old[i-1],&ignored);}
 FlushInstructionCache(GetCurrentProcess(),bridge,11);clonewars_intent_scope_installed=3;intent_frame_scope_binding_ready();return 1;
rollback:
 while(protected_count){DWORD ignored;--protected_count;VirtualProtect(sites[protected_count],lengths[protected_count],old[protected_count],&ignored);}
 VirtualFree(bridge,0,MEM_RELEASE);clonewars_intent_scope_installed=-1;return 0;
}
