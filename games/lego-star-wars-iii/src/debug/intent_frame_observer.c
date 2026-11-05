#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "intent_frame_observer.h"
#include "intent_frame_thunk.h"
#include "../sync/entity_sync.h"
#include "../sync/game_sync.h"
_Static_assert(sizeof(IntentFrameSnapshot)==112,"intent snapshot");
_Static_assert(sizeof(IntentFrameRecord)==236,"intent record");
typedef struct AngleToken {uint32_t writer,heading,basis_valid,basis,kind,confidence;} AngleToken;
typedef struct IntentCache {uint32_t epoch,generation,actor,controller;AngleToken current,previous,last;} IntentCache;
typedef struct IntentScope {uint32_t token,actor,controller,path,native_caller;IntentCache *cache;AngleToken pending;IntentFrameSnapshot entry;} IntentScope;
static __thread IntentCache caches[4096];
static __thread IntentScope scopes[16];
static __thread unsigned depth;
__declspec(dllexport) volatile LONG clonewars_intent_frame_enabled,clonewars_intent_frame_installed,clonewars_intent_frame_scope_installed;
__declspec(dllexport) volatile LONG clonewars_intent_frame_count,clonewars_intent_frame_character=321,clonewars_intent_frame_slot=-1;
__declspec(dllexport) volatile uint32_t clonewars_intent_frame_protocol=SYNC_PROTOCOL_VERSION,clonewars_intent_frame_wire_version=SYNC_PROTOCOL_VERSION,clonewars_intent_frame_layout_version=SYNC_LAYOUT_VERSION;
__declspec(dllexport) volatile uint32_t clonewars_intent_frame_version=1,clonewars_intent_frame_stride=sizeof(IntentFrameRecord),clonewars_intent_frame_capacity=INTENT_FRAME_CAPACITY;
#ifdef STEERING_TRACE_ONLY
__declspec(dllexport) volatile uint32_t clonewars_intent_frame_trace_only=1;
#else
__declspec(dllexport) volatile uint32_t clonewars_intent_frame_trace_only=0;
#endif
__declspec(dllexport) volatile uint32_t clonewars_intent_frame_debug[8];
__declspec(dllexport) volatile IntentFrameRecord clonewars_intent_frame_records[INTENT_FRAME_CAPACITY];
__attribute__((used)) static volatile uintptr_t intent_transformed_resume=0x9bf5bf,intent_model_resume=0x9bf8c1,intent_special_resume=0x9bf8a0,intent_dummy_resume=0x9bf8d4;
__attribute__((used)) static volatile uintptr_t intent_previous_resume=0x9bf352,intent_last_resume=0x9c0332,intent_default_resume=0x9ab961,intent_callback_resume=0x9ab999;
#ifdef INTENT_FRAME_TEST
extern int intent_frame_test_read(uint32_t,void *,unsigned);
#define read_local intent_frame_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size){MEMORY_BASIC_INFORMATION m;
 if(!address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) || m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
 (uint64_t)address+size>(uintptr_t)m.BaseAddress+m.RegionSize)return 0;
 memcpy(out,(void *)(uintptr_t)address,size);return 1;}
#endif
static uint32_t word(uint32_t p){uint32_t v=0;read_local(p,&v,4);return v;}
static uint32_t raw32(const unsigned char *p){uint32_t v;memcpy(&v,p,4);return v;}
static uint32_t raw16(const unsigned char *p){uint16_t v;memcpy(&v,p,2);return v;}
static void snapshot(IntentFrameSnapshot *s,uint32_t actor,uint32_t controller){
 memset(s,0,sizeof(*s));s->actor_local=actor;s->controller_local=controller;s->slot=UINT32_MAX;
 unsigned char a[0x1440],c[0x60];if(!read_local(actor,a,sizeof(a)))return;
 s->valid=1;if(raw32(a+0x6cc)==controller)s->valid|=4;s->flags_50=raw32(a+0x50);s->character=raw16(a+0xdc0);
 if((s->flags_50&3)==3)s->identity_valid=entities_observed_identity((void *)(uintptr_t)actor,&s->slot,&s->generation);
 s->base_local=raw32(a+0xc08);s->has_base=s->base_local!=0;
 if(s->has_base)s->base_valid=read_local(s->base_local+0x224,&s->base_heading,4);else s->base_valid=1;
 if(read_local(controller,c,sizeof(c))){
  s->valid|=2;s->heading=raw16(c+0x26);s->magnitude=raw32(c+0x28);s->direction[0]=raw32(c+0x2c);s->direction[1]=raw32(c+0x30);
  s->previous_heading=raw16(c+0x5a);s->previous_magnitude=raw32(c+0x38);s->last_heading=raw16(c+0x5e);s->last_magnitude=raw32(c+0x34);
 }
 s->action=raw16(a+0x2f4);s->raw_2f1=a[0x2f1];s->c7c=raw32(a+0xc7c);s->c84=raw32(a+0xc84);s->c80=raw32(a+0xc80);
 s->period=a[0x138e];s->phase=a[0x57];s->elapsed=raw32(a+0xe28);
}
static void validate_cache_binding(IntentScope *scope,const IntentFrameSnapshot *s){
 if(scope->cache && ((s->valid&7)!=7 || !s->identity_valid || scope->cache->generation!=s->generation || scope->cache->actor!=s->actor_local || scope->cache->controller!=s->controller_local)){
  scope->cache=NULL;memset(&scope->pending,0,sizeof(scope->pending));
 }
}
static void resolve_pending(IntentScope *scope,const IntentFrameSnapshot *s){
 if(!scope->cache || scope->controller!=s->controller_local || !scope->pending.writer)return;
 if(scope->cache->current.writer>scope->pending.writer){memset(&scope->pending,0,sizeof(scope->pending));return;}
 if(s->heading==scope->pending.heading){scope->cache->current=scope->pending;scope->cache->current.confidence=2;}
 else memset(&scope->cache->current,0,sizeof(AngleToken));
 memset(&scope->pending,0,sizeof(scope->pending));
}
static uint32_t publish(IntentScope *scope,unsigned event,const IntentFrameSnapshot *s,const uint32_t *stack,uint32_t stack_valid,const uint32_t *regs,uint32_t regs_valid,const uint32_t *native_stack){
 IntentFrameRecord r={0};r.id=(uint32_t)InterlockedIncrement(&clonewars_intent_frame_count);r.parent=scope?scope->token:0;r.event=event;
 r.thread=GetCurrentThreadId();r.epoch=game_sync_epoch();r.sequence=game_sync_sequence();r.clock=word(0xfb4b6c);r.rng_game=word(0xe637b4);r.rng_engine=word(0xea178c);
 LARGE_INTEGER q;QueryPerformanceCounter(&q);r.qpc[0]=q.LowPart;r.qpc[1]=q.HighPart;r.snapshot=*s;
 if(event==INTENT_CONSUMER_CALLBACK && native_stack)r.callback_angle_valid=read_local((uint32_t)(uintptr_t)native_stack+0x30,&r.callback_angle,4);
 r.stack_valid=stack_valid;r.registers_valid=regs_valid;if(stack_valid)memcpy(r.native_words,stack,16);if(regs_valid)r.result_raw=regs[7];
 static const uint32_t checkpoint_sites[]={0,0,0,0x9bf5b8,0x9bf8bc,0x9bf89b,0x9bf8cd,0x9bf34b,0x9c032b,0x9ab957,0x9ab991};
 if(event<sizeof(checkpoint_sites)/sizeof(checkpoint_sites[0]))r.site=checkpoint_sites[event];
 if(scope){if(event==INTENT_SCOPE_BEGIN || event==INTENT_SCOPE_END)r.site=scope->native_caller;r.source_path=scope->path;if(scope->cache){IntentCache *c=scope->cache;r.current_writer=c->current.writer;r.previous_writer=c->previous.writer;r.last_writer=c->last.writer;
  r.angle_kind=c->current.kind;r.encoding_basis_valid=c->current.basis_valid;r.encoding_basis=c->current.basis;r.association_confidence=c->current.confidence;}
  r.pending_writer=scope->pending.writer;
  if(event==INTENT_WRITER_TRANSFORMED || event==INTENT_WRITER_MODEL || event==INTENT_WRITER_SPECIAL)r.pending_writer=r.id;
  if(event==INTENT_DUMMY_ZERO && scope->cache && (s->valid&7)==7){r.current_writer=r.id;r.angle_kind=INTENT_ANGLE_DUMMY;r.encoding_basis_valid=0;r.encoding_basis=0;r.association_confidence=2;}
 }
 volatile IntentFrameRecord *dst=clonewars_intent_frame_records+(r.id-1)%INTENT_FRAME_CAPACITY;
 dst->committed=0;memcpy((void *)dst,&r,sizeof(r));MemoryBarrier();dst->committed=r.id;++clonewars_intent_frame_debug[0];return r.id;
}
uint32_t intent_frame_scope_begin(void *actor,void *controller,uint32_t native_caller){
 if(!clonewars_intent_frame_enabled)return 0;DWORD error=GetLastError();IntentFrameSnapshot s;snapshot(&s,(uint32_t)(uintptr_t)actor,(uint32_t)(uintptr_t)controller);
 if(!(s.valid&1) || (clonewars_intent_frame_character>=0 && s.character!=(uint32_t)clonewars_intent_frame_character) ||
 (clonewars_intent_frame_slot>=0 && (!s.identity_valid || s.slot!=(uint32_t)clonewars_intent_frame_slot))){SetLastError(error);return 0;}
 if(depth==16){++clonewars_intent_frame_debug[4];SetLastError(error);return 0;}
 if(depth && scopes[depth-1].actor==s.actor_local && scopes[depth-1].controller==s.controller_local){validate_cache_binding(scopes+depth-1,&s);resolve_pending(scopes+depth-1,&s);}
 IntentScope *scope=scopes+depth++;memset(scope,0,sizeof(*scope));scope->actor=s.actor_local;scope->controller=s.controller_local;scope->native_caller=native_caller;scope->entry=s;
 if((s.valid&7)==7 && s.identity_valid && s.slot<4096 && s.generation){
  IntentCache *cache=caches+s.slot;uint32_t epoch=game_sync_epoch();
  if(cache->epoch!=epoch || cache->generation!=s.generation || cache->actor!=s.actor_local || cache->controller!=s.controller_local){
   memset(cache,0,sizeof(*cache));cache->epoch=epoch;cache->generation=s.generation;cache->actor=s.actor_local;cache->controller=s.controller_local;++clonewars_intent_frame_debug[5];
  }
  if(cache->current.writer && cache->current.heading!=s.heading)memset(&cache->current,0,sizeof(AngleToken));
  if(cache->current.writer)cache->current.confidence=1;
  scope->cache=cache;
 }
 scope->token=depth>1?scopes[depth-2].token:0;
 scope->token=publish(scope,INTENT_SCOPE_BEGIN,&s,NULL,0,NULL,0,NULL);++clonewars_intent_frame_debug[1];SetLastError(error);return scope->token;
}
void intent_frame_scope_model(void *actor,void *controller){
 if(!clonewars_intent_frame_enabled || !depth)return;IntentScope *scope=scopes+depth-1;
 if(scope->actor==(uint32_t)(uintptr_t)actor && scope->controller==(uint32_t)(uintptr_t)controller)scope->path=1;
}
void intent_frame_scope_end(uint32_t token){
 if(!token)return;
 if(!clonewars_intent_frame_enabled){if(depth && scopes[depth-1].token==token)--depth;return;}DWORD error=GetLastError();
 if(!depth || scopes[depth-1].token!=token){++clonewars_intent_frame_debug[4];SetLastError(error);return;}
 IntentScope *scope=scopes+depth-1;IntentFrameSnapshot s;snapshot(&s,scope->actor,scope->controller);validate_cache_binding(scope,&s);resolve_pending(scope,&s);
 if(scope->cache && scope->cache->current.writer && scope->cache->current.heading!=s.heading)memset(&scope->cache->current,0,sizeof(AngleToken));
 publish(scope,INTENT_SCOPE_END,&s,NULL,0,NULL,0,NULL);--depth;++clonewars_intent_frame_debug[2];SetLastError(error);
}
__attribute__((used,noinline)) void intent_frame_checkpoint(uint32_t event,const uint32_t *native_stack,const uint32_t *saved_regs){
 if(!clonewars_intent_frame_enabled)return;DWORD error=GetLastError();
 if(!depth){++clonewars_intent_frame_debug[3];SetLastError(error);return;}
 uint32_t regs[8]={0},args[4]={0};int rv=read_local((uint32_t)(uintptr_t)saved_regs,regs,sizeof(regs)),av=read_local((uint32_t)(uintptr_t)native_stack,args,sizeof(args));
 if(!rv || event<INTENT_WRITER_TRANSFORMED || event>INTENT_CONSUMER_CALLBACK){++clonewars_intent_frame_debug[4];SetLastError(error);return;}
 uint32_t actor=event>=INTENT_CONSUMER_DEFAULT?regs[1]:regs[4],controller=event>=INTENT_CONSUMER_DEFAULT?regs[0]:regs[1];
 IntentScope *scope=scopes+depth-1;if(scope->actor!=actor){++clonewars_intent_frame_debug[3];SetLastError(error);return;}
 IntentFrameSnapshot s;snapshot(&s,actor,controller);validate_cache_binding(scope,&s);
 if(event!=INTENT_WRITER_TRANSFORMED && event!=INTENT_WRITER_MODEL && event!=INTENT_WRITER_SPECIAL)resolve_pending(scope,&s);
 IntentCache *cache=scope->cache;
 if(cache && scope->controller==controller){
  if(event==INTENT_HISTORY_PREVIOUS){if(cache->current.writer && cache->current.heading==s.previous_heading)cache->previous=cache->current;else memset(&cache->previous,0,sizeof(AngleToken));}
  if(event==INTENT_HISTORY_LAST){if(cache->current.writer && cache->current.heading==s.last_heading)cache->last=cache->current;else memset(&cache->last,0,sizeof(AngleToken));}
 }
 uint32_t id=publish(scope,event,&s,args,av,regs,rv,native_stack);
 if(cache && scope->controller==controller){
  if(event==INTENT_WRITER_TRANSFORMED || event==INTENT_WRITER_MODEL || event==INTENT_WRITER_SPECIAL){
   scope->pending=(AngleToken){.writer=id,.heading=regs[7]&0xffff,.basis_valid=(uint32_t)av,.basis=args[1],.kind=INTENT_ANGLE_FRESH};
  }else if(event==INTENT_DUMMY_ZERO){cache->current=(AngleToken){.writer=id,.heading=s.heading,.kind=INTENT_ANGLE_DUMMY,.confidence=2};}
 }
 SetLastError(error);
}
#define THUNK(name,code) __attribute__((naked,used)) static void name(void){__asm__ volatile(code);}
THUNK(transformed_thunk,INTENT_TRANSFORMED_THUNK_ASM)
THUNK(model_thunk,INTENT_MODEL_THUNK_ASM)
THUNK(special_thunk,INTENT_SPECIAL_THUNK_ASM)
THUNK(dummy_thunk,INTENT_DUMMY_THUNK_ASM)
THUNK(previous_thunk,INTENT_PREVIOUS_THUNK_ASM)
THUNK(last_thunk,INTENT_LAST_THUNK_ASM)
THUNK(default_thunk,INTENT_DEFAULT_THUNK_ASM)
THUNK(callback_thunk,INTENT_CALLBACK_THUNK_ASM)
void intent_frame_scope_binding_ready(void){clonewars_intent_frame_scope_installed=1;}
int intent_frame_observer_install(void){
#ifdef INTENT_FRAME_TEST
 return 1;
#else
 unsigned char *sites[]={(void *)0x9bf5b8,(void *)0x9bf8bc,(void *)0x9bf89b,(void *)0x9bf8cd,(void *)0x9bf34b,(void *)0x9c032b,(void *)0x9ab957,(void *)0x9ab991};
 const unsigned char bytes[][10]={{0x83,0xc4,0x10,0x66,0x89,0x46,0x26},{0x83,0xc4,8,0xd9,0xee},{0x83,0xc4,8,0xd9,0xee},{0x66,0x89,0x46,0x26,0xd9,0x56,0x28},
 {0xd9,0x5e,0x38,0x66,0x89,0x4e,0x5a},{0xd9,0x5e,0x34,0x66,0x89,0x46,0x5e},{0x81,0x8e,0xd8,8,0,0,0,0,0x80,0},{0xd9,0xee,0xd8,0x96,0xac,7,0,0}};
 unsigned lengths[]={7,5,5,7,7,7,10,8};uintptr_t targets[]={(uintptr_t)transformed_thunk,(uintptr_t)model_thunk,(uintptr_t)special_thunk,(uintptr_t)dummy_thunk,(uintptr_t)previous_thunk,(uintptr_t)last_thunk,(uintptr_t)default_thunk,(uintptr_t)callback_thunk};DWORD old[8];
 for(unsigned i=0;i<8;++i)if(memcmp(sites[i],bytes[i],lengths[i])){clonewars_intent_frame_installed=-1;return 0;}
 unsigned protected=0;for(;protected<8;++protected)if(!VirtualProtect(sites[protected],lengths[protected],PAGE_EXECUTE_READWRITE,old+protected))break;
 if(protected<8){while(protected){--protected;DWORD ignored;VirtualProtect(sites[protected],lengths[protected],old[protected],&ignored);}clonewars_intent_frame_installed=-1;return 0;}
 for(unsigned i=0;i<8;++i){sites[i][0]=0xe9;*(int32_t *)(sites[i]+1)=(int32_t)(targets[i]-(uintptr_t)sites[i]-5);memset(sites[i]+5,0x90,lengths[i]-5);FlushInstructionCache(GetCurrentProcess(),sites[i],lengths[i]);}
 for(unsigned i=8;i>0;--i){DWORD ignored;VirtualProtect(sites[i-1],lengths[i-1],old[i-1],&ignored);}clonewars_intent_frame_installed=255;return 1;
#endif
}
