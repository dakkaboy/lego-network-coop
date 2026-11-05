#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "hit_entry_observer.h"
#include "hit_entry_thunk.h"
#include "../sync/entity_sync.h"
#include "../sync/projectile_sync.h"
#include "../net/lan.h"
#include "combat_observer.h"
_Static_assert(sizeof(HitEntryRecord)==168,"Hit entry ABI");
__declspec(dllexport) volatile LONG clonewars_hit_entry_enabled;
__declspec(dllexport) volatile LONG clonewars_hit_entry_request;
__declspec(dllexport) volatile LONG clonewars_hit_entry_installed;
__declspec(dllexport) volatile LONG clonewars_hit_entry_count;
__declspec(dllexport) volatile uint32_t clonewars_hit_entry_version=3;
__declspec(dllexport) volatile uint32_t clonewars_hit_entry_stride=sizeof(HitEntryRecord);
__declspec(dllexport) volatile uint32_t clonewars_hit_entry_capacity=HIT_ENTRY_CAPACITY;
__declspec(dllexport) volatile HitEntryRecord clonewars_hit_entry_ring[HIT_ENTRY_CAPACITY];
void *hit_entry_original;
static uint32_t main_thread;
#ifdef HIT_ENTRY_TEST
extern int hit_entry_test_read(uint32_t,void*,unsigned);
#define read_local hit_entry_test_read
#else
static int read_local(uint32_t address,void*out,unsigned size){SIZE_T got=0;return address&&ReadProcessMemory(GetCurrentProcess(),(void*)(uintptr_t)address,out,size,&got)&&got==size;}
#endif
static int live(const CoherentFrameToken*t,uint32_t session){return session&&lan_session_serial()==session&&GetCurrentThreadId()==main_thread&&coherent_frame_valid(t,COHERENT_PHASE_BIT(COHERENT_DISPATCH));}
static int actor(HitEntryActor*a,uint32_t ptr,const CoherentFrameToken*t,uint32_t session){
 memset(a,0,sizeof(*a));a->local=ptr;a->slot=UINT32_MAX;
 if(!ptr)return 1;
 if(!live(t,session))return 0;
 void*p=(void*)(uintptr_t)ptr;uint32_t g=entities_observed_generation(p),slot,gen;
 if(!g||!entities_allocation_live(p,g)||!entities_observed_identity(p,&slot,&gen))return 0;
 uint32_t model=0;uint16_t character=0;uint8_t hp=0;
 if(!live(t,session)||!read_local(ptr+8,&model,4)||!live(t,session)||!read_local(ptr+0xdc0,&character,2)||!live(t,session)||!read_local(ptr+0xdde,&hp,1))return 0;
 if(!live(t,session)||!entities_allocation_live(p,g)||entities_observed_generation(p)!=g)return 0;
 uint32_t slot2,gen2;if(!entities_observed_identity(p,&slot2,&gen2)||slot!=slot2||gen!=gen2)return 0;
 a->slot=slot;a->generation=gen;a->allocation=g;a->character=character;a->health=(uint32_t)(int32_t)(int8_t)hp;a->model=model;a->valid=1;return 1;
}
void hit_entry_checkpoint(const uint32_t*b,const unsigned char*fx){
 if(!clonewars_hit_entry_enabled||GetCurrentThreadId()!=main_thread)return;
 uint32_t session=lan_session_serial();CoherentFrameToken token;
 if(!session||!coherent_frame_get(&token,COHERENT_PHASE_BIT(COHERENT_DISPATCH))||!live(&token,session))return;
 HitEntryRecord r={0};r.session=session;r.epoch=token.epoch;r.sequence=token.sequence;r.thread=GetCurrentThreadId();r.caller=combat_damage_native_caller();memcpy(r.arguments,b+10,sizeof(r.arguments));
 uint16_t cw;memcpy(&cw,fx,2);r.cw=cw;memcpy(&r.mxcsr,fx+24,4);
 if(!actor(&r.attacker,r.arguments[0],&token,session)||!actor(&r.victim,r.arguments[1],&token,session)||!live(&token,session))return;
 if(!read_local(0xfb4b6c,&r.clock,4)||!live(&token,session))return;
 uint32_t source=0;if(read_local(0xfbcb2c,&source,4)&&live(&token,session)){
  ProjectileIdentityView v={0};projectiles_observe_live((void*)(uintptr_t)source,&v);
  if(!live(&token,session))return;
  r.source_local=source;r.source_status=v.status;
  if(v.status==SHOT_LIVE){r.shot_id=v.id;r.shot_owner=(uint32_t)v.owner;r.shot_generation=v.owner_generation;r.weapon=(uint32_t)v.weapon;r.instance_serial=v.instance_serial;r.creation_count=v.creation_count;}
 }
 LARGE_INTEGER q;QueryPerformanceCounter(&q);r.qpc[0]=q.LowPart;r.qpc[1]=(uint32_t)q.HighPart;
 if(!clonewars_hit_entry_enabled||!live(&token,session))return;
 LONG old=InterlockedCompareExchange(&clonewars_hit_entry_count,0,0);if((uint32_t)old>=0x7ffffffeu)return;
 r.id=(uint32_t)InterlockedIncrement(&clonewars_hit_entry_count);volatile HitEntryRecord*out=&clonewars_hit_entry_ring[(r.id-1)%HIT_ENTRY_CAPACITY];
 out->committed=0;memcpy((void*)out,&r,sizeof(r));MemoryBarrier();if(!clonewars_hit_entry_enabled||!live(&token,session))return;out->committed=r.id;
}
__attribute__((naked)) static void hit_entry_thunk(void){__asm__ __volatile__(HIT_ENTRY_THUNK_ASM);}
int hit_entry_install(const CoherentFrameToken*original){
 int state=(int)InterlockedCompareExchange(&clonewars_hit_entry_installed,0,0);
 if(state)return state==1&&main_thread==GetCurrentThreadId();
 uint32_t session=lan_session_serial();
 if(!session||!original||original->thread!=GetCurrentThreadId()||!coherent_frame_valid(original,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
 if(lan_session_serial()!=session)return 0;
 if(!combat_hit_bridge_attach(original,(void*)hit_entry_thunk,&hit_entry_original))return 0;
 main_thread=GetCurrentThreadId();InterlockedExchange(&clonewars_hit_entry_installed,1);return 1;
}

void hit_entry_poll(const CoherentFrameToken*original){
 if(InterlockedCompareExchange(&clonewars_hit_entry_request,0,0)!=1)return;
 if(InterlockedCompareExchange(&clonewars_hit_entry_installed,0,0)!=0)return;
 hit_entry_install(original);
}
