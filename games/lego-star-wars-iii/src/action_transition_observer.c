#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stddef.h>
#include <string.h>
#include "action_transition_observer.h"
#include "action_transition_thunk.h"
#include "entity_sync.h"
#define CAPACITY 2048
#define DEPTH 32
_Static_assert(sizeof(ActionTransitionRecord)==184,"action record layout");
__declspec(dllexport) volatile LONG clonewars_action_transition_enabled;
__declspec(dllexport) volatile uint32_t clonewars_action_transition_version=1;
__declspec(dllexport) volatile uint32_t clonewars_action_transition_stride=sizeof(ActionTransitionRecord),clonewars_action_transition_capacity=CAPACITY;
__declspec(dllexport) volatile LONG clonewars_action_transition_installed,clonewars_action_transition_count;
__declspec(dllexport) volatile uint32_t clonewars_action_transition_debug[8];
__declspec(dllexport) volatile ActionTransitionRecord clonewars_action_transition_records[CAPACITY];
void *action_transition_original;
static volatile LONG next_scope;
typedef struct Scope {uintptr_t continuation;void *actor;uint32_t release;ActionTransitionRecord record;} Scope;
static __thread Scope scopes[DEPTH];
static __thread unsigned depth;
static int readable(const void *p,SIZE_T n){
#ifdef ACTION_TRANSITION_TEST
 extern int action_test_readable(const void *,SIZE_T);return action_test_readable(p,n);
#else
 MEMORY_BASIC_INFORMATION m;return p&&VirtualQuery(p,&m,sizeof m)&&m.State==MEM_COMMIT&&!(m.Protect&(PAGE_GUARD|PAGE_NOACCESS))&&(uintptr_t)p+n>=(uintptr_t)p&&(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
#endif
}
static uint32_t clock_now(void){
#ifdef ACTION_TRANSITION_TEST
 return 123;
#else
 return *(volatile uint32_t *)0xfb4b6c;
#endif
}
static uint32_t word(const void *p){uint32_t x;memcpy(&x,p,4);return x;}
static uint32_t half(const void *p){uint16_t x;memcpy(&x,p,2);return x;}
static void stamp(uint32_t q[2]){LARGE_INTEGER x;QueryPerformanceCounter(&x);q[0]=x.LowPart;q[1]=(uint32_t)x.HighPart;}
static int sample(const void *state,ActionState *s){const unsigned char *p=state;if(!readable(p,0xa4))return 0;s->action=half(p+0x94);s->clip=half(p+0x88);s->timer=word(p+0x40);s->duration=word(p+0x4c);s->raw2f1=p[0x91];s->raw2f8=word(p+0x98);s->raw2fa=p[0x9a];s->raw2fb=p[0x9b];return 1;}
static int bound(Scope *s){ActionTransitionRecord *r=&s->record;uint32_t slot,g;
 return s->actor&&entities_allocation_live(s->actor,r->local_generation)&&entities_observed_identity(s->actor,&slot,&g)&&slot==r->slot&&g==r->generation&&readable(s->actor,0x1440)&&half((char*)s->actor+0xdc0)==(uint16_t)r->character;
}
void action_transition_return(void);
__attribute__((used,noinline)) void action_transition_enter(uint32_t *b){
 if(!clonewars_action_transition_enabled)return;
 if(depth==DEPTH){++clonewars_action_transition_debug[1];return;}
 Scope *s=scopes+depth;memset(s,0,sizeof *s);ActionTransitionRecord *r=&s->record;
 s->continuation=b[9];s->release=game_sync_action_lifecycle();r->caller=b[9];r->state_local=b[10];r->requested_raw=b[11];r->flags_before=b[8];
 r->scope=(uint32_t)InterlockedIncrement(&next_scope);r->parent=depth?scopes[depth-1].record.scope:0;r->thread=GetCurrentThreadId();r->slot=UINT32_MAX;
 r->keyed=game_sync_action_lease_get(&r->lease);r->clock_before=clock_now();stamp(r->qpc_before);
 if(!sample((void*)(uintptr_t)r->state_local,&r->before))r->reason=1;
 void *actor=(void*)((uintptr_t)r->state_local-0x260);uint32_t slot,g;uint32_t local=entities_observed_generation(actor);
 if(local&&entities_allocation_live(actor,local)&&entities_observed_identity(actor,&slot,&g)&&g&&readable(actor,0x1440)){
  s->actor=actor;r->slot=slot;r->generation=g;r->local_generation=local;r->character=(uint32_t)(int32_t)(int16_t)half((char*)actor+0xdc0);r->actor_valid=1;
 }
 ++depth;b[9]=(uint32_t)(uintptr_t)action_transition_return;
}
__attribute__((used,noinline)) void action_transition_leave(uint32_t *b){
 Scope *s=scopes+depth-1;ActionTransitionRecord *r=&s->record;b[3]=(uint32_t)s->continuation;
 r->returned_raw=b[7];r->flags_after=b[8];r->clock_after=clock_now();stamp(r->qpc_after);
 int publish=clonewars_action_transition_enabled&&s->release==game_sync_action_lifecycle()&&(!r->keyed||game_sync_action_lease_valid(&r->lease));
 if(publish&&r->actor_valid&&!bound(s)){publish=0;++clonewars_action_transition_debug[3];}
 if(publish&&!sample((void*)(uintptr_t)r->state_local,&r->after))r->reason|=2;
 if(s->release!=game_sync_action_lifecycle()||(r->keyed&&!game_sync_action_lease_valid(&r->lease)))publish=0;
 if(publish){r->id=(uint32_t)InterlockedIncrement(&clonewars_action_transition_count);volatile ActionTransitionRecord *out=clonewars_action_transition_records+(r->id-1)%CAPACITY;out->committed=0;memcpy((void*)out,r,sizeof *r);MemoryBarrier();out->committed=r->id;}
 else ++clonewars_action_transition_debug[2];
 --depth;
}
__attribute__((naked,used)) void action_transition_entry(void){__asm__ volatile(ACTION_TRANSITION_ENTRY_ASM);}
__attribute__((naked,used)) void action_transition_return(void){__asm__ volatile(ACTION_TRANSITION_RETURN_ASM);}
int action_transition_install(void){
 static const unsigned char prefix[5]={0x56,0x8b,0x74,0x24,0x08};
#ifdef ACTION_TRANSITION_TEST
 extern unsigned char *action_test_site;unsigned char *site=action_test_site;
#else
 unsigned char *site=(void*)0x89e430;
#endif
 if(clonewars_action_transition_installed)return 1;
 if(memcmp(site,prefix,5))return 0;
 unsigned char *bridge=VirtualAlloc(NULL,10,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);if(!bridge)return 0;
 memcpy(bridge,prefix,5);bridge[5]=0xe9;uint32_t rel=(uint32_t)((uintptr_t)site+5-(uintptr_t)(bridge+10));memcpy(bridge+6,&rel,4);
 DWORD old;if(!VirtualProtect(site,5,PAGE_EXECUTE_READWRITE,&old)){VirtualFree(bridge,0,MEM_RELEASE);return 0;}
 action_transition_original=bridge;site[0]=0xe9;rel=(uint32_t)((uintptr_t)action_transition_entry-(uintptr_t)(site+5));memcpy(site+1,&rel,4);FlushInstructionCache(GetCurrentProcess(),site,5);DWORD ignored;VirtualProtect(site,5,old,&ignored);clonewars_action_transition_installed=1;return 1;
}
