#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <string.h>
#include "base_aim_observer.h"
#include "base_aim_thunk.h"
#include "../sync/entity_sync.h"
_Static_assert(sizeof(BaseAimRecord)==228,"base aim record");
__declspec(dllexport) volatile LONG clonewars_base_aim_enabled;
__declspec(dllexport) volatile uint32_t clonewars_base_aim_version=1,clonewars_base_aim_stride=sizeof(BaseAimRecord),clonewars_base_aim_capacity=BASE_AIM_CAPACITY,clonewars_base_aim_installed;
__declspec(dllexport) volatile LONG clonewars_base_aim_count;
__declspec(dllexport) volatile uint32_t clonewars_base_aim_debug[8];
__declspec(dllexport) volatile BaseAimRecord clonewars_base_aim_records[BASE_AIM_CAPACITY];
uintptr_t base_aim_resume=0x879907;
static uint32_t word(const void *p){uint32_t x;memcpy(&x,p,4);return x;}
static uint32_t half(const void *p){uint16_t x;memcpy(&x,p,2);return x;}
static int readable(const void *p,SIZE_T n){
#ifdef BASE_AIM_TEST
 extern int base_aim_test_readable(const void *,SIZE_T);return base_aim_test_readable(p,n);
#else
 MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof(m))&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_NOACCESS|PAGE_GUARD))&&(uintptr_t)p+n>=(uintptr_t)p&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
#endif
}
static uint32_t native_global(uintptr_t p){
#ifdef BASE_AIM_TEST
 (void)p;return 0;
#else
 return *(volatile uint32_t *)p;
#endif
}
static uint32_t clock_now(void){
#ifdef BASE_AIM_TEST
 return 123;
#else
 return *(volatile uint32_t *)0xfb4b6c;
#endif
}
__attribute__((used,noinline)) void base_aim_checkpoint(uint32_t *b,const void *fx){
 if(!clonewars_base_aim_enabled)return;
 unsigned char *actor=(void *)(uintptr_t)b[4],*def=(void *)(uintptr_t)b[1];
 BaseAimRecord r={0};BaseAimContext after={0};r.slot=UINT32_MAX;
 if(!projectiles_base_aim_context(actor,&r.context)){++clonewars_base_aim_debug[0];return;}
 if(!readable(actor,0x1440)||!readable(def,0x78)){++clonewars_base_aim_debug[1];return;}
 r.version=1;r.thread=GetCurrentThreadId();LARGE_INTEGER q;QueryPerformanceCounter(&q);r.qpc[0]=q.LowPart;r.qpc[1]=(uint32_t)q.HighPart;r.clock=clock_now();
 r.actor_local=(uint32_t)(uintptr_t)actor;r.local_generation=entities_observed_generation(actor);r.character=half(actor+0xdc0);
 if(!r.local_generation||!entities_observed_identity(actor,&r.slot,&r.generation)||!r.generation||(word(actor+0x50)&3)!=3){++clonewars_base_aim_debug[2];return;}
 r.valid=1;r.action=half(actor+0x2f4);r.clip=half(actor+0x2e8);r.dda=actor[0xdda];r.heading_ax=b[7]&65535;
 memcpy(r.vector_bits,(unsigned char *)(b+9)+0x158,12);r.weapon_def_local=(uint32_t)(uintptr_t)def;r.weapon70=word(def+0x70);r.weapon74=word(def+0x74);
 unsigned char *model=*(void **)(actor+8);r.model_local=(uint32_t)(uintptr_t)model;if(readable(model,0x42)){r.model40=half(model+0x40);r.valid|=2;}
 unsigned char *resource=*(void **)(actor+0xf08);if(readable(resource,0x30)){r.resource14=word(resource+0x14);unsigned char *definition=*(void **)(resource+0x2c);if(readable(definition,0xe0)){r.character_d0=definition[0xd0];r.character_dc=word(definition+0xdc);r.valid|=4;}}
 const unsigned offsets[]={0x50,0xc8c,0x760,0x2a0,0x2ac,0x75c,0x6c,0xf0c,0xdda};
 for(unsigned i=0;i<9;++i)r.helper_actor_raw[i]=word(actor+offsets[i]);
 r.helper_globals[0]=native_global(0xe6af1c);r.helper_globals[1]=native_global(0xe6af18);r.helper_globals[2]=native_global(0xe6af84);
 uintptr_t actions=native_global(0xe75ef8);if((int16_t)r.action>=0&&actions&&readable((void *)(actions+(uint32_t)(int16_t)r.action*16+12),4)){r.action_flags=word((void *)(actions+(uint32_t)(int16_t)r.action*16+12));r.valid|=8;}
 unsigned char *mount=*(void **)(actor+0x75c);r.mount_local=(uint32_t)(uintptr_t)mount;if(readable(mount,0xf0e)){r.mount_f0c=half(mount+0xf0c);r.valid|=16;}
 r.f0c=half(actor+0xf0c);r.flags8d8=word(actor+0x8d8);r.c78=word(actor+0xc78);r.c7c=word(actor+0xc7c);r.bdc_local=word(actor+0xbdc);r.cca=actor[0xcca];r.control_word=half(fx)&0x1f3f;r.mxcsr_control=word((const unsigned char *)fx+24)&0xffc0;
 uint32_t slot=UINT32_MAX,generation=0;
 if(!projectiles_base_aim_context(actor,&after)||memcmp(&r.context,&after,sizeof(after))||entities_observed_generation(actor)!=r.local_generation||!entities_observed_identity(actor,&slot,&generation)||slot!=r.slot||generation!=r.generation||(word(actor+0x50)&3)!=3||half(actor+0xdc0)!=r.character){++clonewars_base_aim_debug[3];return;}
 r.id=(uint32_t)InterlockedIncrement(&clonewars_base_aim_count);volatile BaseAimRecord *out=clonewars_base_aim_records+(r.id-1)%BASE_AIM_CAPACITY;out->committed=0;memcpy((void *)out,&r,sizeof(r));MemoryBarrier();out->committed=r.id;
}
__attribute__((naked)) static void checkpoint(void){__asm__ volatile(BASE_AIM_THUNK_ASM);}
int base_aim_observer_install(void){
 if(clonewars_base_aim_installed)return 1;
 static const unsigned char prefix[]={0x66,0x83,0xbb,0xf4,2,0,0,0xff};unsigned char *p=(void *)0x8798ff;
#ifdef BASE_AIM_TEST
 extern unsigned char *base_aim_test_site;p=base_aim_test_site;
#endif

 if(!readable(p,8)||memcmp(p,prefix,8))return 0;DWORD old;if(!VirtualProtect(p,8,PAGE_EXECUTE_READWRITE,&old))return 0;
 p[0]=0xe9;*(int32_t *)(p+1)=(int32_t)((uintptr_t)checkpoint-(uintptr_t)p-5);memset(p+5,0x90,3);FlushInstructionCache(GetCurrentProcess(),p,8);DWORD unused;int ok=VirtualProtect(p,8,old,&unused)!=0;
 if(ok)clonewars_base_aim_installed=1;return ok;
}
