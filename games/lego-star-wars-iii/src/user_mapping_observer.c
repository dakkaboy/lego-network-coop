#include <windows.h>
#include <string.h>
#include "user_mapping_internal.h"
typedef struct MappingTicketRecord {volatile LONG committed,flags;UserMappingTicket data;} MappingTicketRecord;
typedef struct MappingEvent {uint32_t entered,site,mask,generation,acquired,locked;int32_t user;MappingMarker *marker;UserMappingKey claim;} MappingEvent;
_Static_assert(sizeof(MappingEvent)<=1024,"event storage");
static UserMappingConfig configuration;
static volatile LONG configured,enabled,disabled,coverage,next_id,ticket_count;
static volatile LONG generation[4],committed_generation[4],writer_depth[4],setter_depth[4],reset_generation,poller_depth;
static CRITICAL_SECTION mutation_lock;
static MappingTicketRecord tickets[UM_TICKETS];
static __thread MappingMarker *marker_head,*physical_marker;
const uint32_t user_mapping_default_mxcsr=0x1f80;
__declspec(dllexport) volatile uint32_t clonewars_user_mapping_observer_version=UM_OBSERVER_API_VERSION;
__declspec(dllexport) volatile LONG clonewars_user_mapping_observer_faults;
static uint32_t load(volatile LONG*p){return (uint32_t)InterlockedCompareExchange(p,0,0);}
static int main_now(void){return GetCurrentThreadId()==configuration.main_thread;}
static int domain(int32_t user){return user>=0&&user<4;}
static void disable(void){InterlockedExchange(&disabled,1);InterlockedIncrement(&clonewars_user_mapping_observer_faults);}
void user_mapping_invalidate_runtime(void){disable();}
static uint32_t advance(volatile LONG*p){for(;;){uint32_t prior=load(p);if(prior==UINT32_MAX){disable();return 0;}if((uint32_t)InterlockedCompareExchange(p,(LONG)(prior+1),(LONG)prior)==prior)return prior+1;}}
static void decrement(volatile LONG*p){for(;;){uint32_t prior=load(p);if(!prior){disable();return;}if((uint32_t)InterlockedCompareExchange(p,(LONG)(prior-1),(LONG)prior)==prior)return;}}
static int ready(void){return load(&configured)==1&&load(&enabled)&&!load(&disabled)&&(load(&coverage)&UM_REQUIRED_COVERAGE)==UM_REQUIRED_COVERAGE;}
int user_mapping_runtime_ready(void){DWORD e=GetLastError();int ok=main_now()&&ready();SetLastError(e);return ok;}
static MappingTicketRecord *record(UserMappingKey k){if(k.slot>=UM_TICKETS||!k.id)return NULL;MappingTicketRecord*r=tickets+k.slot;return r->data.key.id==k.id?r:NULL;}
static void flags(UserMappingKey k,uint32_t f){MappingTicketRecord*r=record(k);if(r)InterlockedOr(&r->flags,(LONG)f);}
static uint32_t invalidate(unsigned mask,int reset){if(reset&&!advance(&reset_generation))return 0;uint32_t last=0;for(unsigned i=0;i<4;++i)if(mask&(1u<<i)){last=advance(generation+i);InterlockedExchange(committed_generation+i,0);}return last;}
int user_mapping_configure(const UserMappingConfig *c){DWORD e=GetLastError();int ok=0;MEMORY_BASIC_INFORMATION m;if(!c||c->version!=UM_OBSERVER_API_VERSION||!c->main_thread||!c->native_table||!c->native_owners||!c->original_source_valid)goto done;for(unsigned i=0;i<UM_SITE_COUNT;++i)if(!c->targets[i])goto done;if(!VirtualQuery((const void*)c->native_table,&m,sizeof m)||m.State!=MEM_COMMIT||m.Protect&(PAGE_GUARD|PAGE_NOACCESS)||(uintptr_t)c->native_table+32>(uintptr_t)m.BaseAddress+m.RegionSize)goto done;if(InterlockedCompareExchange(&configured,-1,0))goto done;configuration=*c;InitializeCriticalSection(&mutation_lock);InterlockedExchange(&configured,1);ok=1;done:SetLastError(e);return ok;}
int user_mapping_binding_ready(uint32_t declared){DWORD e=GetLastError();int ok=load(&configured)==1&&main_now()&&!load(&enabled)&&!(declared&~127u);if(ok)InterlockedExchange(&coverage,(LONG)declared);SetLastError(e);return ok;}
int user_mapping_enable(void){DWORD e=GetLastError();int ok=load(&configured)==1&&main_now()&&!load(&disabled)&&(load(&coverage)&UM_REQUIRED_COVERAGE)==UM_REQUIRED_COVERAGE;if(ok)InterlockedExchange(&enabled,1);SetLastError(e);return ok;}
#ifdef USER_MAPPING_FIXTURE
static volatile LONG entry_count[UM_SITE_COUNT];
uint32_t user_mapping_test_entry_count(unsigned site){return site<UM_SITE_COUNT?load(entry_count+site):0;}
#endif
void __cdecl user_mapping_bridge_begin(UserMappingBridge*b){
 MappingEvent*l=(void*)b->storage;
#ifdef USER_MAPPING_FIXTURE
 InterlockedIncrement(entry_count+b->site);
#endif
 memset(l,0,sizeof(*l));l->site=b->site;l->user=-1;
 /* Native entrypoints are published only after immutable target configuration. */
 b->target=configuration.targets[b->site];b->args[0]=b->args[1]=0;
 const int32_t *args=(const void*)(uintptr_t)(b->entry_esp+4);
 if(b->site==UM_MAPPER||b->site==UM_SETTER){b->args[0]=args[0];b->args[1]=args[1];l->user=args[0];}else if(b->site==UM_RESET_01)b->args[0]=args[0];
 if(!load(&enabled))return;
 if(!main_now())disable();
#ifdef USER_MAPPING_SESSION_FIXTURE
 extern void user_mapping_test_admission_wait(unsigned);user_mapping_test_admission_wait(b->site);
#endif
 EnterCriticalSection(&mutation_lock);l->locked=1;
 if(b->site==UM_SETTER){if(domain(l->user)){l->mask=1u<<(unsigned)l->user;l->entered=1;if(advance(setter_depth+l->user))l->acquired=l->mask;}else disable();if(!main_now())disable();LeaveCriticalSection(&mutation_lock);l->locked=0;return;}
 if(b->site==UM_POLLER){l->entered=1;if(advance(&poller_depth))l->acquired=1;if(!main_now())disable();LeaveCriticalSection(&mutation_lock);l->locked=0;return;}
 if(b->site==UM_MAPPER){if(!domain(l->user)){disable();return;}l->mask=1u<<(unsigned)l->user;}
 else l->mask=b->site==UM_RESET_01?3u:(b->site==UM_USER0_A||b->site==UM_USER0_B)?1u:15u;
 l->entered=1;for(unsigned i=0;i<4;++i)if(l->mask&(1u<<i))if(advance(writer_depth+i))l->acquired|=1u<<i;
 if(!main_now())disable();if(!ready())return;
 invalidate(l->mask,b->site==UM_RESET_ALL||b->site==UM_RESET_01||b->site==UM_INITIALIZER);if(!ready())return;
 if(b->site!=UM_MAPPER)return;l->generation=load(generation+l->user);
 MappingMarker*m=physical_marker;if(marker_head!=m){disable();return;}if(!m||!m->linked||!m->admitted||m->claimed||m->request.user!=l->user||m->request.requested!=b->args[1])return;
 m->claimed=1;l->marker=m;l->claim=m->key;flags(m->key,UM_T_CLAIM_SEEN);
}
void __cdecl user_mapping_bridge_end(UserMappingBridge*b,int unwind){
 DWORD e=GetLastError();unsigned char fx[512] __attribute__((aligned(16)));__asm__ volatile("fxsave %0;fninit;ldmxcsr %1;cld":"=m"(fx):"m"(user_mapping_default_mxcsr):"cc");MappingEvent*l=(void*)b->storage;if(!l->entered)goto done;
 if(l->site==UM_SETTER||l->site==UM_POLLER){EnterCriticalSection(&mutation_lock);l->locked=1;if(l->acquired)decrement(l->site==UM_SETTER?setter_depth+l->user:&poller_depth);goto done;}
 for(unsigned i=0;i<4;++i)if(l->acquired&(1u<<i))decrement(writer_depth+i);
 if(unwind){invalidate(l->mask,1);goto done;}
 if(!ready())goto done;
 if(l->site==UM_MAPPER){
  if(load(generation+l->user)!=l->generation||load(writer_depth+l->user)){invalidate(l->mask,0);goto done;}
  int32_t actual=configuration.native_table[l->user*2];
  if(load(generation+l->user)!=l->generation||load(writer_depth+l->user)||!ready())goto done;
  InterlockedExchange(committed_generation+l->user,(LONG)l->generation);
  if(l->marker){MappingMarker*m=physical_marker;if(marker_head!=m||m!=l->marker||!m||!m->linked||m->key.id!=l->claim.id||m->key.slot!=l->claim.slot){disable();goto done;}
   MappingTicketRecord*r=record(l->claim);if(r&&actual>=12&&actual<=13){r->data.actual=actual;r->data.generation=l->generation;r->data.reset_generation=load(&reset_generation);MemoryBarrier();InterlockedOr(&r->flags,UM_T_MAPPING_COMMITTED);InterlockedExchange(&r->committed,(LONG)l->claim.id);}
  }
 }
 done:__asm__ volatile("fxrstor %0"::"m"(fx));SetLastError(e);
}
void __cdecl user_mapping_bridge_unlock(UserMappingBridge*b){DWORD e=GetLastError();unsigned char fx[512] __attribute__((aligned(16)));__asm__ volatile("fxsave %0;fninit;ldmxcsr %1;cld":"=m"(fx):"m"(user_mapping_default_mxcsr):"cc");MappingEvent*l=(void*)b->storage;if(l->locked){l->locked=0;LeaveCriticalSection(&mutation_lock);}__asm__ volatile("fxrstor %0"::"m"(fx));SetLastError(e);}
int user_mapping_mutation_try(void){DWORD e=GetLastError();int ok=main_now()&&ready()&&TryEnterCriticalSection(&mutation_lock);SetLastError(e);return ok;}
void user_mapping_mutation_unlock(void){DWORD e=GetLastError();LeaveCriticalSection(&mutation_lock);SetLastError(e);}
static int all_idle(void){if(load(&poller_depth))return 0;for(unsigned i=0;i<4;++i)if(load(setter_depth+i)||load(writer_depth+i))return 0;return 1;}
int user_mapping_cleanup_owned(UserMappingKey key,int32_t*negative){
 if(!main_now()||!ready()||!all_idle())return 0;MappingTicketRecord*r=record(key);if(!r||load(&r->committed)!=key.id||!(load(&r->flags)&UM_T_MAPPING_COMMITTED)||load(&r->flags)&UM_T_RETIRED)return -1;
 UserMappingTicket*t=&r->data;if(t->user!=1||t->saved_negative>=0||t->actual<12||t->actual>13)return -1;
 if(load(generation+1)!=t->generation||load(committed_generation+1)!=t->generation||load(&reset_generation)!=t->reset_generation)return -1;
 if(configuration.native_table[2]!=t->actual||*(const volatile int32_t*)(configuration.native_owners+t->actual*0x90)!=1)return -1;
 if(!ready()||!all_idle())return 0;*negative=t->saved_negative;return 1;
}
int user_mapping_cleanup_consume(UserMappingKey key){if(!main_now())return 0;MappingTicketRecord*r=record(key);if(!r||load(&r->flags)&UM_T_RETIRED)return 0;flags(key,UM_T_RETIRED);return 1;}
int user_mapping_native_saved_matches(int32_t negative){return main_now()&&negative<0&&configuration.native_table[2]==negative;}
void __cdecl user_mapping_request_begin(MappingMarker*m,const UserMappingRequest*r,UserMappingKey*out){
 DWORD e=GetLastError();unsigned char fx[512] __attribute__((aligned(16)));__asm__ volatile("fxsave %0;fninit;ldmxcsr %1;cld":"=m"(fx):"m"(user_mapping_default_mxcsr):"cc");
 memset(m,0,sizeof(*m));if(out)*out=(UserMappingKey){0,0};
 if(!r||!out||!ready()||!main_now()||r->user!=1||r->requested!=13||r->saved_negative>=0||!r->source.assignment||!r->source.epoch||!r->source.proof_bytes||r->source.proof_bytes>UM_PROOF_BYTES)goto done;
 if(marker_head!=physical_marker){disable();goto done;}m->request=*r;m->previous=marker_head;m->previous_physical=physical_marker;m->linked=1;marker_head=physical_marker=m;m->entered=1;
 uint32_t slot=advance(&ticket_count);if(!slot||slot>UM_TICKETS){disable();goto done;}uint32_t id=advance(&next_id);if(!id)goto done;
 m->key=(UserMappingKey){slot-1,id};*out=m->key;MappingTicketRecord*t=tickets+slot-1;t->data.key=m->key;memcpy(&t->data.source,&r->source,sizeof(UserMappingStamp));t->data.user=r->user;t->data.requested=r->requested;t->data.saved_negative=r->saved_negative;t->data.actual=-1;
 if(!configuration.original_source_valid(r->source.proof,r->source.proof_bytes)){flags(m->key,UM_T_SOURCE_EXPIRED);goto done;}if(!ready())goto done;if(configuration.native_table[2]!=r->saved_negative){flags(m->key,UM_T_MAPPING_PRECONDITION);goto done;}m->admitted=1;
 done:__asm__ volatile("fxrstor %0"::"m"(fx));SetLastError(e);
}
void __cdecl user_mapping_request_end(MappingMarker*m,int unwind){
 DWORD e=GetLastError();unsigned char fx[512] __attribute__((aligned(16)));__asm__ volatile("fxsave %0;fninit;ldmxcsr %1;cld":"=m"(fx):"m"(user_mapping_default_mxcsr):"cc");
 if(m->entered){flags(m->key,(unwind?UM_T_SETTER_UNWOUND:UM_T_SETTER_RETURNED)|(m->admitted?0:UM_T_NOT_SENT));if(marker_head==m&&physical_marker==m){physical_marker=m->previous_physical;marker_head=m->previous;m->linked=0;}else disable();}
 __asm__ volatile("fxrstor %0"::"m"(fx));SetLastError(e);
}
int user_mapping_ticket_get(UserMappingKey k,UserMappingTicket*out){DWORD e=GetLastError();int ok=0;if(out&&main_now()){MappingTicketRecord*r=record(k);if(r){*out=r->data;out->flags=load(&r->flags);ok=1;}}SetLastError(e);return ok;}
int user_mapping_inspect(UserMappingKey k,UserMappingObservation*out){DWORD e=GetLastError();int ok=0;if(!out||!main_now())goto done;MappingTicketRecord*r=record(k);if(!r)goto done;memset(out,0,sizeof(*out));out->ticket=r->data;out->ticket.flags=load(&r->flags);out->quality=UM_Q_METADATA;out->disabled=load(&disabled);unsigned u=(unsigned)r->data.user;out->generation=load(generation+u);out->committed_generation=load(committed_generation+u);out->reset_generation=load(&reset_generation);out->setter_depth=load(setter_depth+u);out->writer_depth=load(writer_depth+u);out->poller_depth=load(&poller_depth);out->current_actual=-1;
 if(out->ticket.flags&UM_T_RETIRED)goto have;
 if(!ready()||load(&r->committed)!=k.id||out->generation!=r->data.generation||out->committed_generation!=r->data.generation||out->reset_generation!=r->data.reset_generation)goto have;
 out->quality|=UM_Q_CURRENT_GENERATION;if(all_idle())out->quality|=UM_Q_IDLE;
 out->current_actual=configuration.native_table[u*2];if(out->current_actual==r->data.actual&&ready()&&load(generation+u)==out->generation&&load(&reset_generation)==out->reset_generation)out->quality|=UM_Q_CURRENT_VALUE;
 have:ok=1;done:SetLastError(e);return ok;}
int user_mapping_cancel(UserMappingKey k){DWORD e=GetLastError();int ok=main_now()&&record(k);if(ok)flags(k,UM_T_CANCELLED);SetLastError(e);return ok;}
int user_mapping_retire(UserMappingKey k){DWORD e=GetLastError();int ok=main_now()&&record(k);if(ok)flags(k,UM_T_RETIRED);SetLastError(e);return ok;}
void user_mapping_user0_store_event(void){DWORD e=GetLastError();if(load(&enabled)){if(!main_now())disable();else if(ready())invalidate(1,0);}SetLastError(e);}
#ifdef USER_MAPPING_FIXTURE

void user_mapping_test_id(uint32_t id){InterlockedExchange(&next_id,(LONG)id);}
void user_mapping_test_generation(unsigned user,uint32_t value){if(user<4)InterlockedExchange(generation+user,(LONG)value);}
int user_mapping_test_marker_empty(void){return marker_head==NULL&&physical_marker==NULL;}
void user_mapping_test_corrupt_marker(void){marker_head=(void*)0x11110000;}
#endif
