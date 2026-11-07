#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "model_input_sync.h"
#include "../engine/context_relevance.h"
#include "../engine/model_input_thunk.h"
#include "../engine/request_mode_cmp_thunk.h"
#include "../engine/request_mode_mov_thunk.h"
#include "../engine/request_mode_join_thunk.h"
#include "entity_sync.h"
#include "game_sync.h"
#include "../engine/module_cohort_binding.h"
#include "../engine/model_producer_bridge.h"
#ifdef CLONEWARS_INTENT_OBSERVER
#include "../debug/intent_frame_observer.h"
#include "../debug/intent_scope_observer.h"
#endif
_Static_assert(SYNC_LAYOUT_VERSION==42,"actual layout42");
_Static_assert(sizeof(SyncModelInputContext)==124,"context");
_Static_assert(sizeof(SyncModelInput)==188,"request");
_Static_assert(offsetof(SyncModelInput,input_mode)==40,"mode");
_Static_assert(offsetof(SyncModelInput,context)==56,"context offset");
_Static_assert(offsetof(SyncFrame,actors)==208,"header");
_Static_assert(offsetof(SyncFrame,model_inputs)==2137872,"model input offset");
_Static_assert(sizeof(SyncFrame)==3317008,"capacity");
typedef struct ModelInputOutcome {uint32_t committed,sequence,ordinal,slot,generation,valid,reason,actor_local,controller_local,clock,qpc[2];uint32_t actor_heading,controller_heading,magnitude,direction[2],previous_heading,previous_magnitude,last_heading,last_magnitude;uint32_t action,substate,clip,timer,life_54,flags_50,hero_role;float position[3];} ModelInputOutcome;
typedef struct ProjectionRecord {
 uint32_t committed,id,epoch,sequence,ordinal,slot,generation,thread,clock,qpc[2],actor_local,controller_local,provider_local,native_frame;
 uint32_t source_local_mode,cmp_seen,mov_seen,cmp_native_flags,cmp_effective_flags,mov_native_mode,effective_mode;
 SyncModelInput request;
 uint32_t control_25,heading_26,magnitude,direction[2],c7c,base_valid,base_heading,actor_heading,action,life_54;
 SyncModelInputContext raw_source_context;uint32_t canonicalized_fields;
} ProjectionRecord;
typedef struct RequestScope {
 ModelInputFrameLease lease;uint32_t lexical_nonce,linked,usable;
 struct RequestScope *previous;void *actor,*controller,*provider;uint32_t generation,entry_generation,epoch,sequence,native_frame,ordinal,source,cmp_seen,mov_seen,projection_complete,local_mode,cmp_native_flags,cmp_effective_flags,mov_native_mode;
 SyncModelInput request;SyncModelInputContext raw_source_context;uint32_t canonicalized_fields;
} RequestScope;
typedef struct ProducerLocal {RequestScope scope;struct ProducerLocal *previous;uint32_t entered;} ProducerLocal;
_Static_assert(sizeof(ProducerLocal)<=1024,"producer lexical storage");
static __thread ProducerLocal *lexical;
static void disable_scopes(void);
typedef void (__attribute__((cdecl)) *MotionProducer)(void *);
static MotionProducer original_producer;
static __thread RequestScope *scope;
static __thread unsigned scope_depth;
static __thread uint32_t scope_serial;
static volatile LONG scope_disabled;
static ModuleCohortBinding binding;

static volatile LONG cancelled;
static ModelInputJournal journal;
static int op_live(const ModelInputFrameLease *op){return module_binding_live(&binding,op)&&journal.frame==op->cohort.frame;}
static int active;
static uint32_t initialized_serial;
static DWORD active_thread;
static uint32_t last_epoch,first_actor,first_controller,first_local_generation;
__attribute__((used)) static volatile uintptr_t model_input_resume=0x9bf6b0,request_mode_cmp_resume=0x9bf6d9,request_mode_mov_resume=0x9bf909,request_mode_join_resume=0x9bfa2a,request_priority_resume=0x9bf921;
__attribute__((used)) static volatile uintptr_t request_visibility_continue=0x9bf9ed,request_visibility_skip=0x9bfa25;
#ifdef CLONEWARS_INTENT_OBSERVER
__attribute__((used)) static volatile uintptr_t intent_scope_model_resume=0x9bf44d;
#endif
__declspec(dllexport) volatile LONG clonewars_model_input_installed;
__declspec(dllexport) volatile uint32_t clonewars_model_input_entry_stride=sizeof(SyncModelInput),clonewars_model_input_context_stride=sizeof(SyncModelInputContext),clonewars_model_input_outcome_stride=sizeof(ModelInputOutcome);
__declspec(dllexport) volatile uint32_t clonewars_model_input_frame_capacity=sizeof(SyncFrame),clonewars_model_input_frame_offset=offsetof(SyncFrame,model_inputs),clonewars_model_input_protocol=SYNC_PROTOCOL_VERSION,clonewars_model_input_layout=SYNC_LAYOUT_VERSION;
#ifdef STEERING_TRACE_ONLY
__declspec(dllexport) volatile uint32_t clonewars_model_input_authority=0;
#else
__declspec(dllexport) volatile uint32_t clonewars_model_input_authority=1;
#endif
__declspec(dllexport) volatile uint32_t clonewars_model_input_debug[16],clonewars_model_input_failure[16],clonewars_model_input_first_correction[8];
__declspec(dllexport) volatile uint32_t clonewars_model_visibility_debug[4];
__declspec(dllexport) volatile SyncModelInput clonewars_model_input_failed_host,clonewars_model_input_failed_local,clonewars_model_input_corrected_host,clonewars_model_input_corrected_local,clonewars_model_input_effective;
__declspec(dllexport) volatile ModelInputOutcome clonewars_model_input_first_outcome;
__declspec(dllexport) volatile uint32_t clonewars_model_input_context_encoding=1;
#define PROJECTION_CAPACITY 2048
__declspec(dllexport) volatile LONG clonewars_model_projection_enabled,clonewars_model_projection_count;
__declspec(dllexport) volatile uint32_t clonewars_model_projection_version=3,clonewars_model_projection_stride=sizeof(ProjectionRecord),clonewars_model_projection_capacity=PROJECTION_CAPACITY;
__declspec(dllexport) volatile ProjectionRecord clonewars_model_projection_records[PROJECTION_CAPACITY];
#ifdef MODEL_INPUT_TEST
extern int model_input_test_valid(const void *,unsigned);extern void *model_input_test_hero(unsigned);extern uint32_t model_input_test_word(uint32_t);
#define valid(p,n) model_input_test_valid(p,n)
#define hero(n) model_input_test_hero(n)
#define global_word(p) model_input_test_word(p)
#else
static int valid(const void *p,unsigned n){MEMORY_BASIC_INFORMATION m;return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT && !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uint64_t)(uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;}
static void *hero(unsigned n){return *(void **)(0xfb4940+n*4);}
static uint32_t global_word(uint32_t p){return *(uint32_t *)(uintptr_t)p;}
#endif
static uint32_t read32(const unsigned char *p){uint32_t v;memcpy(&v,p,4);return v;}
static uint32_t read16(const unsigned char *p){uint16_t v;memcpy(&v,p,2);return v;}
static void failed(const ModelInputFrameLease *op,void *actor,const SyncModelInput *host,const SyncModelInput *local,unsigned reason){
 if(!op_live(op))return;
 if(InterlockedCompareExchange((volatile LONG *)clonewars_model_input_failure,-1,0)==0){uint32_t slot=UINT32_MAX,gen=0;entities_observed_identity(actor,&slot,&gen);if(!op_live(op))return;uint32_t v[]={journal.frame->epoch,journal.frame->sequence,journal.host?journal.frame->model_input_count:journal.cursor,host?host->slot:UINT32_MAX,host?host->generation:0,slot,gen,reason,host?host->native_clock:0,local?local->native_clock:0,host?host->context.action:0,local?local->context.action:0,host?host->input_mode:0,local?local->input_mode:0,(uint32_t)(uintptr_t)actor,global_word(0xfb4b6c)};
  if(host)memcpy((void *)&clonewars_model_input_failed_host,host,sizeof(*host));if(local)memcpy((void *)&clonewars_model_input_failed_local,local,sizeof(*local));memcpy((void *)(clonewars_model_input_failure+1),v+1,sizeof(v)-4);MemoryBarrier();clonewars_model_input_failure[0]=v[0];}
 if(!op_live(op))return;++clonewars_model_input_debug[3];journal.failed=(int)reason;game_sync_native_fault(20);
}
static int eligible(unsigned char *p,void *controller,unsigned char *provider){
 if(!valid(p,0x1440)||!valid(controller,0x60)||!valid(provider,0x194))return 0;
 uint32_t f=read32(p+0x50);return (f&3)==3&&!(f&0x200)&&p!=hero(0)&&p!=hero(1)&&*(void **)(p+0x6cc)==controller&&p[0x54]==0&&p[0x1dd]==255&&!(read32(provider+0x190)&0x100)&&!*(void **)(p+0xc00)&&!(global_word(0xfc0e80)&255);
}
static int capture(SyncModelInput *e,unsigned char *p,unsigned char *provider,const uint32_t *x,const uint32_t *z,const unsigned char *fx){
 unsigned char *resource=*(unsigned char **)(p+0xf08),*model=*(unsigned char **)(p+8),*base=*(unsigned char **)(p+0xc08);
 if(!valid(resource,0x30)||!valid(model,0x43)||*(void **)(model+0x34)!=provider||!valid(base,0x228)||!valid(x,4)||!valid(z,4)||!fx)return 0;
 unsigned char *definition=*(unsigned char **)(resource+0x2c);if(!valid(definition,0xfc)||(read32(p+0xc7c)&0x20000000))return 0;
 memset(e,0,sizeof(*e));e->character=(int16_t)read16(p+0xdc0);e->native_clock=global_word(0xfb4b6c);memcpy(&e->input_x,x,4);memcpy(&e->input_z,z,4);e->input_mode=read32(provider+0xb0);e->period=p[0x138e];e->phase=p[0x57];memcpy(&e->elapsed,p+0xe28,4);
 SyncModelInputContext *c=&e->context;c->role_mask=read32(p+0x50)&0xa00;c->life_54=p[0x54];c->axis_1dd=p[0x1dd];c->provider_190_bit=!!(read32(provider+0x190)&0x100);c->normalization_mode=global_word(0xfb32a8);
 c->action=read16(p+0x2f4);c->substate_2fa=p[0x2fa];c->c7c_block=!!(read32(p+0xc7c)&0x800000);c->byte_110a=p[0x110a];c->c84_mask=read32(p+0xc84)&0x104000;c->c00_present=0;c->actor_76=read16(p+0x76);c->actor_1c8_mask=!!(read32(p+0x1c8)&0x400);c->override_c44=read32(p+0xc44);c->override_c48=read32(p+0xc48);
 const unsigned offsets[]={0x2c,0x30,0x34,0xf8};for(unsigned i=0;i<4;++i)c->resource_speed[i]=read32(definition+offsets[i]);c->motion_alternate=!!(read32(resource+0x14)&0x2000);c->resource_d8_bit=!!(read32(definition+0xd8)&0x100);
 c->actor_4c_mask=!!(read32(p+0x4c)&0x400);c->c7c_1000=!!(read32(p+0xc7c)&0x1000);c->cf4_raw=read32(p+0xcf4);c->model_42=model[0x42];c->actor_309_mask=!!(p[0x309]&2);c->global_e63e14_raw=global_word(0xe63e14);c->global_fbcb88_raw=global_word(0xfbcb88);c->global_fc0e80=global_word(0xfc0e80)&255;c->numeric_cw=read16(fx)&0x1f3f;c->numeric_mxcsr=read32(fx+24)&0xffc0;return 1;
}
static RequestScope *qualified_scope(ModelInputFrameLease *op){
 if(InterlockedCompareExchange(&scope_disabled,0,0)||!active||GetCurrentThreadId()!=active_thread)return NULL;
 ProducerLocal *l=lexical;if(!l)return NULL;RequestScope *s=&l->scope;if(scope!=s){disable_scopes();return NULL;}if(!s->linked||!s->usable)return NULL;
 *op=s->lease;if(!op_live(op))return NULL;return s;
}
static int scope_valid(const ModelInputFrameLease *op,RequestScope *s,void *actor,void *controller,uint32_t native_frame){
 return op_live(op)&&s==scope&&s&&s->source&&!s->projection_complete&&s->actor==actor&&s->controller==controller&&s->native_frame==native_frame&&s->epoch==journal.frame->epoch&&s->sequence==journal.frame->sequence&&GetCurrentThreadId()==active_thread&&valid(actor,0x1440)&&valid(controller,0x60)&&((read32((unsigned char *)actor+0x50)&3)==3)&&!(*(uint32_t *)((char *)actor+0x50)&0x200)&&actor!=hero(0)&&actor!=hero(1)&&entities_observed_generation(actor)==s->generation&&op_live(op)&&*(void **)((char *)actor+0x6cc)==controller;
}
__attribute__((used,noinline)) void request_mode_source_checkpoint(uint32_t *saved,const unsigned char *fx){
 ModelInputFrameLease op;RequestScope *s=qualified_scope(&op);if(!s)return;
 ++clonewars_model_input_debug[11];if(journal.failed)return;
 void *actor=(void *)(uintptr_t)saved[4],*controller=*(void **)((char *)saved+64),*provider=*(void **)((char *)saved+48);uint32_t *x=(uint32_t *)((char *)saved+68),*z=(uint32_t *)((char *)saved+76);
 if(!op_live(&op))return;
 if(!eligible(actor,controller,provider)){++clonewars_model_input_debug[5];return;}if(!op_live(&op)||scope!=s)return;
 if(s!=scope||s->actor!=actor||scope->source||!scope->entry_generation||entities_observed_generation(actor)!=scope->entry_generation){failed(&op,actor,NULL,NULL,11);return;}
 SyncModelInput local;if(!capture(&local,actor,provider,x,z,fx)){failed(&op,actor,NULL,NULL,4);return;}if(!op_live(&op)||scope!=s)return;
 SyncModelInput raw_local=local;uint32_t canonicalized_fields=0;
 const SyncModelInput *entry=NULL;
 if(journal.host){entities_update();if(!op_live(&op)||scope!=s)return;SyncActor identity={0};entities_describe(&identity,actor);if(!op_live(&op)||scope!=s)return;int slot=entities_slot(actor);if(!op_live(&op)||scope!=s)return;local.slot=(uint32_t)slot;local.generation=identity.generation;local.spawn_tag=identity.spawn_tag;local.spawn_source=identity.spawn_source;memcpy(local.origin,identity.spawn_position,12);raw_local=local;if(!model_context_canonicalize(&local,&raw_local.context,&local.context,&canonicalized_fields)){failed(&op,actor,&raw_local,&raw_local,4);return;}if(!model_input_journal_record(&journal,&local)){failed(&op,actor,&local,&raw_local,(unsigned)journal.failed);return;}entry=journal.frame->model_inputs+journal.frame->model_input_count-1;++clonewars_model_input_debug[0];scope->ordinal=journal.frame->model_input_count-1;}
 else{entry=model_input_journal_peek(&journal);SyncActor reference={0};if(entry){reference.slot=entry->slot;reference.generation=entry->generation;reference.spawn_tag=entry->spawn_tag;reference.spawn_source=entry->spawn_source;reference.character=entry->character;memcpy(reference.spawn_position,entry->origin,12);}void *resolved=entry?entities_resolve_reference(&reference):NULL;if(!op_live(&op)||scope!=s)return;local.slot=entry?entry->slot:UINT32_MAX;local.generation=entities_observed_generation(actor);raw_local=local;
  if(entry&&entry->context.actor_4c_mask!=raw_local.context.actor_4c_mask){failed(&op,actor,entry,&raw_local,9);return;}
  if(entry&&!model_context_canonicalize(entry,&raw_local.context,&local.context,&canonicalized_fields)){failed(&op,actor,entry,&raw_local,4);return;}
  if(entry) {
   local.context.actor_76=entry->context.actor_76;
   if(!local.context.actor_4c_mask) {
    local.context.cf4_raw=entry->context.cf4_raw;
    local.context.model_42=entry->context.model_42;
   }
  }
  if(!model_input_journal_validate(&journal,entry,entry&&resolved==actor,&local)){failed(&op,actor,entry,&raw_local,(unsigned)journal.failed);return;}++clonewars_model_input_debug[1];scope->ordinal=journal.cursor-1;}
 if(!op_live(&op)||scope!=s)return;
 uint32_t generation=entities_observed_generation(actor);if(!op_live(&op)||scope!=s)return;scope->controller=controller;scope->provider=provider;scope->generation=generation;scope->epoch=journal.frame->epoch;scope->sequence=journal.frame->sequence;scope->native_frame=saved[2];scope->source=1;scope->request=*entry;scope->local_mode=local.input_mode;scope->raw_source_context=raw_local.context;scope->canonicalized_fields=canonicalized_fields;
 if(!journal.host){
  if(!entry->context.actor_4c_mask && raw_local.context.cf4_raw!=entry->context.cf4_raw){
   // The native motion branch reads this visibility timer after the request.
   memcpy((unsigned char *)actor+0xcf4,&entry->context.cf4_raw,4);
   ++clonewars_model_visibility_debug[0];clonewars_model_visibility_debug[2]=entry->native_clock;
   clonewars_model_visibility_debug[3]=entry->slot;
  }
  int corrected=memcmp(&local.input_x,&entry->input_x,12)!=0;memcpy(x,&entry->input_x,4);memcpy(z,&entry->input_z,4);clonewars_model_input_debug[2]+=corrected;
  if(corrected&&InterlockedCompareExchange((volatile LONG *)clonewars_model_input_first_correction,-1,0)==0){memcpy((void *)&clonewars_model_input_corrected_host,entry,sizeof(*entry));memcpy((void *)&clonewars_model_input_corrected_local,&raw_local,sizeof(raw_local));SyncModelInput effective=local;effective.input_x=entry->input_x;effective.input_z=entry->input_z;effective.input_mode=entry->input_mode;memcpy((void *)&clonewars_model_input_effective,&effective,sizeof(effective));first_actor=(uint32_t)(uintptr_t)actor;first_controller=(uint32_t)(uintptr_t)controller;first_local_generation=scope->generation;LARGE_INTEGER q;QueryPerformanceCounter(&q);uint32_t v[]={journal.frame->epoch,journal.frame->sequence,scope->ordinal,entry->slot,entry->generation,local.native_clock,q.LowPart,(uint32_t)q.HighPart};memcpy((void *)(clonewars_model_input_first_correction+1),v+1,sizeof(v)-4);MemoryBarrier();clonewars_model_input_first_correction[0]=v[0];}
 }
 clonewars_model_input_debug[7]=journal.frame->sequence;clonewars_model_input_debug[8]=journal.host?journal.frame->model_input_count:journal.cursor;clonewars_model_input_debug[9]=entry->slot;clonewars_model_input_debug[10]=entry->generation;
}
static int request_zero(const SyncModelInput *r){uint32_t x,z;memcpy(&x,&r->input_x,4);memcpy(&z,&r->input_z,4);return !(x&0x7fffffffu)&&!(z&0x7fffffffu);}
static int consumer(uint32_t *saved,uint32_t *mode,int mov){
 ModelInputFrameLease op;RequestScope *s=qualified_scope(&op);if(!s||journal.failed||!s->source)return 0;void *actor=(void *)(uintptr_t)saved[4],*controller=*(void **)((char *)saved+64);
 if(!scope_valid(&op,s,actor,controller,saved[2])||*(void **)((char *)saved+48)!=s->provider){failed(&op,actor,&s->request,NULL,12);return 0;}
 unsigned char *p=s->provider;if(!valid(p,0x194)){failed(&op,actor,&s->request,NULL,12);return 0;}
 int zero=request_zero(&s->request);
 if(!mov){if(s->cmp_seen||s->mov_seen||zero||(void *)(uintptr_t)saved[7]!=s->provider){failed(&op,actor,&s->request,NULL,13);return 0;}s->cmp_seen=1;s->cmp_native_flags=saved[8]&0x8d5;uint32_t flags;uint32_t canonical=s->request.input_mode;__asm__ volatile("cmpl $1,%1;pushfl;popl %0":"=r"(flags):"r"(canonical):"cc");s->cmp_effective_flags=flags&0x8d5;}
 else{if(s->mov_seen||s->cmp_seen!=(unsigned)!zero){failed(&op,actor,&s->request,NULL,13);return 0;}s->mov_seen=1;s->mov_native_mode=saved[7];}
 *mode=s->request.input_mode;return 1;
}
__attribute__((used,noinline)) int request_mode_cmp_checkpoint(uint32_t *saved,uint32_t *mode){return consumer(saved,mode,0);}
__attribute__((used,noinline)) int request_priority_checkpoint(uint32_t *saved,uint32_t *priority){
 ModelInputFrameLease op;
 RequestScope *s=qualified_scope(&op);
 if(!s||journal.host||journal.failed||!s->source||!s->mov_seen||s->request.input_mode!=1)return 0;
 void *actor=(void *)(uintptr_t)saved[4],*controller=*(void **)((char *)saved+64);
 if(!scope_valid(&op,s,actor,controller,saved[2]))return 0;
 *priority=s->request.context.actor_76;
 return 1;
}
__attribute__((used,noinline)) int request_mode_mov_checkpoint(uint32_t *saved,uint32_t *mode){return consumer(saved,mode,1);}
__attribute__((used,noinline)) int request_visibility_checkpoint(uint32_t *saved,uint32_t *visibility) {
 ModelInputFrameLease op;
 RequestScope *s=qualified_scope(&op);
 if(!s || journal.host || journal.failed || !s->source || !s->mov_seen || s->request.context.actor_4c_mask)
  return 0;
 unsigned char *actor=(unsigned char *)(uintptr_t)saved[4],*model=(unsigned char *)(uintptr_t)saved[7];
 void *controller=*(void **)((char *)saved+64);
 if(!scope_valid(&op,s,actor,controller,saved[2]) || *(void **)(actor+8)!=model || !valid(model,0x43))
  return 0;
 *visibility=s->request.context.model_42;
 clonewars_model_visibility_debug[1]+=(model[0x42]!=0)!=(*visibility!=0);
 return 1;
}
_Static_assert(offsetof(ProjectionRecord,raw_source_context)==320,"raw diagnostic context offset");
_Static_assert(offsetof(ProjectionRecord,canonicalized_fields)==444,"canonicalization mask offset");
_Static_assert(sizeof(ProjectionRecord)==448,"projection record");
_Static_assert(offsetof(ProjectionRecord,request)==88,"projection request");
static void projection_record(const ModelInputFrameLease *op,RequestScope *s,unsigned char *p,unsigned char *c){
 if(!op_live(op)||!clonewars_model_projection_enabled)return;ProjectionRecord r={0};r.id=(uint32_t)InterlockedIncrement(&clonewars_model_projection_count);r.epoch=s->epoch;r.sequence=s->sequence;r.ordinal=s->ordinal;r.slot=s->request.slot;r.generation=s->request.generation;r.thread=GetCurrentThreadId();r.clock=global_word(0xfb4b6c);LARGE_INTEGER q;QueryPerformanceCounter(&q);r.qpc[0]=q.LowPart;r.qpc[1]=(uint32_t)q.HighPart;r.actor_local=(uint32_t)(uintptr_t)p;r.controller_local=(uint32_t)(uintptr_t)c;r.provider_local=(uint32_t)(uintptr_t)s->provider;r.native_frame=s->native_frame;r.source_local_mode=s->local_mode;r.cmp_seen=s->cmp_seen;r.mov_seen=s->mov_seen;r.cmp_native_flags=s->cmp_native_flags;r.cmp_effective_flags=s->cmp_effective_flags;r.mov_native_mode=s->mov_native_mode;r.effective_mode=s->request.input_mode;r.request=s->request;r.raw_source_context=s->raw_source_context;r.canonicalized_fields=s->canonicalized_fields;r.control_25=c[0x25];r.heading_26=read16(c+0x26);r.magnitude=read32(c+0x28);r.direction[0]=read32(c+0x2c);r.direction[1]=read32(c+0x30);r.c7c=read32(p+0xc7c);unsigned char *base=*(unsigned char **)(p+0xc08);r.base_valid=valid(base,0x228);r.base_heading=r.base_valid?read32(base+0x224):0;r.actor_heading=read16(p+0x6c);r.action=read16(p+0x2f4);r.life_54=p[0x54];if(!op_live(op)||scope!=s)return;volatile ProjectionRecord *out=clonewars_model_projection_records+(r.id-1)%PROJECTION_CAPACITY;out->committed=0;memcpy((void *)out,&r,sizeof(r));MemoryBarrier();out->committed=r.id;
}
__attribute__((used,noinline)) void request_mode_join_checkpoint(uint32_t *saved,const unsigned char *fx){
 (void)fx;ModelInputFrameLease op;RequestScope *s=qualified_scope(&op);if(!s||journal.failed||!s->source)return;void *actor=(void *)(uintptr_t)saved[4],*controller=*(void **)((char *)saved+64);
 if(!scope_valid(&op,s,actor,controller,saved[2])||!s->mov_seen||s->cmp_seen!=(unsigned)!(request_zero(&s->request))){failed(&op,actor,&s->request,NULL,14);return;}
 projection_record(&op,s,actor,controller);if(!op_live(&op)||scope!=s)return;s->projection_complete=1;++clonewars_model_input_debug[13];
}
const uint32_t model_producer_default_mxcsr=0x1f80;
static void disable_scopes(void){InterlockedExchange(&scope_disabled,1);coherent_frame_cancel_atomic(0x4000);}
void __cdecl model_producer_enter(ModelProducerBridge *b){
 b->target=(void *)original_producer;ProducerLocal *l=(void *)b->storage;memset(l,0,sizeof(*l));
 RequestScope *s=&l->scope;s->actor=(void *)(uintptr_t)b->actor;s->previous=scope;
 l->previous=lexical;lexical=l;s->linked=1;scope=s;++scope_depth;l->entered=1;
 if(scope_serial==UINT32_MAX){disable_scopes();return;}s->lexical_nonce=++scope_serial;
 ModelInputFrameLease op;if(!InterlockedCompareExchange(&scope_disabled,0,0)&&active&&GetCurrentThreadId()==active_thread&&model_input_frame_lease_get(&op)&&op_live(&op)){
  s->lease=op;s->usable=scope_depth<=32;
  if(s->usable&&valid(s->actor,0x1440)){s->entry_generation=entities_observed_generation(s->actor);if(!s->entry_generation){entities_update();if(op_live(&op))s->entry_generation=entities_observed_generation(s->actor);}}
  if(!op_live(&op))s->usable=0;
  if(scope_depth>32)failed(&op,s->actor,NULL,NULL,15);
 }

}
void __cdecl model_producer_leave(ModelProducerBridge *b,int unwind){
 DWORD e=GetLastError();unsigned char fx[512] __attribute__((aligned(16)));__asm__ volatile("fxsave %0;fninit;ldmxcsr %1;cld":"=m"(fx):"m"(model_producer_default_mxcsr):"cc");
 ProducerLocal *l=(void *)b->storage;RequestScope *s=&l->scope;
 if(unwind&&s->lease.serial&&module_lease_same(&binding,&s->lease)){coherent_frame_cancel_atomic(0x8000);model_input_abort_frame(&s->lease);}
 else if(l->entered&&scope==s&&s->usable&&op_live(&s->lease)&&active&&s->source&&!s->projection_complete&&!journal.failed)failed(&s->lease,s->actor,&s->request,NULL,14);

 if(l->entered){if(scope==s&&lexical==l){lexical=l->previous;scope=s->previous;if(scope_depth)--scope_depth;else disable_scopes();s->linked=0;}else disable_scopes();}
 __asm__ volatile("fxrstor %0"::"m"(fx));SetLastError(e);
}
#ifdef CLONEWARS_INTENT_OBSERVER
__declspec(dllexport) volatile uint32_t clonewars_model_input_observer_suppressed=1;
__attribute__((used,noinline)) static void intent_scope_model_witness(void *actor,void *controller,void *provider){(void)actor;(void)controller;(void)provider;}
__attribute__((naked,used)) static void model_witness_thunk(void){__asm__ volatile(INTENT_SCOPE_MODEL_THUNK_ASM);}
#endif
#include "../engine/model_request_outcome.inc"
__attribute__((naked,used)) static void source_thunk(void){__asm__ volatile(MODEL_INPUT_THUNK_ASM);}
__attribute__((naked,used)) static void cmp_thunk(void){__asm__ volatile(REQUEST_MODE_CMP_THUNK_ASM);}
__attribute__((naked,used)) static void mov_thunk(void){__asm__ volatile(REQUEST_MODE_MOV_THUNK_ASM);}
__attribute__((naked,used)) static void priority_thunk(void){__asm__ volatile(REQUEST_PRIORITY_THUNK_ASM);}
__attribute__((naked,used)) static void visibility_thunk(void){__asm__ volatile(REQUEST_VISIBILITY_THUNK_ASM);}
__attribute__((naked,used)) static void join_thunk(void){__asm__ volatile(REQUEST_MODE_JOIN_THUNK_ASM);}
int model_input_install(void){
 if(clonewars_model_input_installed==31)return 1;
#if defined(MODEL_INPUT_TEST) && !defined(MODEL_INPUT_TEST_INSTALL)
 clonewars_model_input_installed=31;return 1;
#else
 unsigned char *sites[]={(void *)0x9bf280,(void *)0x9bf6aa,(void *)0x9bf6d2,(void *)0x9bf903,(void *)0x9bfa25,(void *)0x9bf91c,(void *)0x9bf9e7
#ifdef CLONEWARS_INTENT_OBSERVER
 ,(void *)0x9bf443
#endif
 };unsigned sizes[]={6,6,7,6,5,5,6
#ifdef CLONEWARS_INTENT_OBSERVER
 ,10
#endif
 };const unsigned char prefixes[][10]={{0x55,0x8b,0xec,0x83,0xe4,0xf0},{0xd9,0xc0,0xd9,0x44,0x24,0x20},{0x83,0xb8,0xb0,0,0,0,1},{0x8b,0x80,0xb0,0,0,0},{0x8b,0x43,8,0x85,0xc0},{0x66,0x83,0x7b,0x76,0x00},{0x80,0x78,0x42,0x00,0x75,0x38}
#ifdef CLONEWARS_INTENT_OBSERVER
 ,{0xf7,0x83,0x7c,0x0c,0,0,0,0,0x80,0}
#endif
 };uintptr_t targets[]={(uintptr_t)producer_hook,(uintptr_t)source_thunk,(uintptr_t)cmp_thunk,(uintptr_t)mov_thunk,(uintptr_t)join_thunk,(uintptr_t)priority_thunk,(uintptr_t)visibility_thunk
#ifdef CLONEWARS_INTENT_OBSERVER
 ,(uintptr_t)model_witness_thunk
#endif
 };unsigned n=sizeof(sites)/sizeof(sites[0]),protected_count=0;DWORD old[sizeof(sites)/sizeof(sites[0])];
 for(unsigned i=0;i<n;++i)if(!valid(sites[i],sizes[i])||memcmp(sites[i],prefixes[i],sizes[i])){clonewars_model_input_installed=-1;return 0;}
 unsigned char *bridge=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);if(!bridge){clonewars_model_input_installed=-1;return 0;}
 memcpy(bridge,prefixes[0],6);bridge[6]=0xe9;*(int32_t *)(bridge+7)=(int32_t)((uintptr_t)sites[0]+6-(uintptr_t)bridge-11);
 for(unsigned i=0;i<n;++i){if(!VirtualProtect(sites[i],sizes[i],PAGE_EXECUTE_READWRITE,old+i))goto rollback;++protected_count;}
 original_producer=(MotionProducer)bridge;
 for(unsigned i=0;i<n;++i){sites[i][0]=0xe9;*(int32_t *)(sites[i]+1)=(int32_t)(targets[i]-(uintptr_t)sites[i]-5);memset(sites[i]+5,0x90,sizes[i]-5);FlushInstructionCache(GetCurrentProcess(),sites[i],sizes[i]);}
 for(unsigned i=n;i>0;--i){DWORD ignored;VirtualProtect(sites[i-1],sizes[i-1],old[i-1],&ignored);}FlushInstructionCache(GetCurrentProcess(),bridge,11);clonewars_model_input_installed=31;

 return 1;
rollback:
 while(protected_count){DWORD ignored;--protected_count;VirtualProtect(sites[protected_count],sizes[protected_count],old[protected_count],&ignored);}VirtualFree(bridge,0,MEM_RELEASE);clonewars_model_input_installed=-1;return 0;
#endif
}
int model_input_ready(void){return clonewars_model_input_installed==31;}
int model_input_bind_cohort(const CoherentFrameToken *original){
 if(InterlockedCompareExchange(&scope_disabled,0,0)||!module_binding_bind(&binding,original))return 0;initialized_serial=0;return 1;
}
int model_input_frame_lease_get(ModelInputFrameLease *out){return module_binding_get(&binding,out);}
int model_input_frame_cancelled(const ModelInputFrameLease *op){return module_binding_cancelled(&binding,op);}
int model_input_abort_frame(const ModelInputFrameLease *op){if(!module_binding_detach(&binding,op))return 0;active=0;InterlockedExchange(&cancelled,1);memset(&journal,0,sizeof(journal));return 1;}
void model_input_cancel(void){if(binding.bound)return;active=0;InterlockedExchange(&cancelled,1);++clonewars_model_input_debug[14];}
int model_input_begin(SyncFrame *frame,int host){
 if(InterlockedCompareExchange(&scope_disabled,0,0))return 0;ModelInputFrameLease op;if(!model_input_frame_lease_get(&op)||!module_binding_live(&binding,&op)||!coherent_frame_valid(&op.cohort,COHERENT_PHASE_BIT(COHERENT_PREPARE))||op.cohort.frame!=frame||initialized_serial==op.serial)return 0;initialized_serial=op.serial;
 if((scope||lexical)&&(!lexical||scope!=&lexical->scope)){disable_scopes();return 0;}
 InterlockedExchange(&cancelled,0);
 if(last_epoch!=op.cohort.epoch){memset((void *)clonewars_model_input_failure,0,sizeof(clonewars_model_input_failure));memset((void *)clonewars_model_input_first_correction,0,sizeof(clonewars_model_input_first_correction));memset((void *)&clonewars_model_input_first_outcome,0,sizeof(clonewars_model_input_first_outcome));last_epoch=op.cohort.epoch;first_actor=first_controller=first_local_generation=0;}
 model_input_journal_begin(&journal,frame,host);active_thread=GetCurrentThreadId();
#ifdef STEERING_TRACE_ONLY
 active=0;
#else
 active=1;
#endif
 return op_live(&op);
}
int model_input_cancelled(void){return InterlockedCompareExchange(&cancelled,0,0)!=0;}
int model_input_finish(void){DWORD e=GetLastError();ModelInputFrameLease op;if(!model_input_frame_lease_get(&op)||!op_live(&op)){SetLastError(e);return 0;}outcome(&op);if(!op_live(&op)){SetLastError(e);return 0;}if((scope||scope_depth)&&active&&!journal.failed)failed(&op,NULL,NULL,NULL,15);active=0;++clonewars_model_input_debug[4];int good=model_input_journal_finish(&journal);if(!good&&!journal.failed)failed(&op,NULL,model_input_journal_peek(&journal),NULL,3);SetLastError(e);return good;}
