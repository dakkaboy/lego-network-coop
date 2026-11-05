#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include <stddef.h>
#include "steering_sync.h"
#include "steering_thunk.h"
#include "entity_sync.h"
#include "game_sync.h"
#ifdef STEERING_TRACE_ONLY
#include "intent_frame_observer.h"
#endif
static SteeringJournal journal;
static int active;
typedef void (__attribute__((cdecl)) *MotionProducer)(void *);
static MotionProducer original_producer;
typedef struct SteeringScope {void *actor,*controller;uint32_t generation;unsigned witnessed,excluded,joined;SyncSteeringSource source;struct SteeringScope *previous;} SteeringScope;
static __thread SteeringScope *scope;
static __thread unsigned scope_depth;
__attribute__((used)) static volatile uintptr_t steering_model_resume=0x9bf44d;
static uint32_t last_epoch;
__attribute__((used)) static volatile uintptr_t steering_resume=0x9c02ba;
__declspec(dllexport) volatile LONG clonewars_steering_installed;
__declspec(dllexport) volatile uint32_t clonewars_steering_entry_stride=sizeof(SyncSteering),clonewars_steering_context_stride=sizeof(SyncSteeringSource);
__declspec(dllexport) volatile uint32_t clonewars_steering_frame_capacity=sizeof(SyncFrame),clonewars_steering_frame_offset=offsetof(SyncFrame,steering);
__declspec(dllexport) volatile uint32_t clonewars_steering_debug[16];
__declspec(dllexport) volatile uint32_t clonewars_steering_failure[16];
__declspec(dllexport) volatile SyncSteering clonewars_steering_failed_host,clonewars_steering_failed_local;
__declspec(dllexport) volatile uint32_t clonewars_steering_first_correction[8];
__declspec(dllexport) volatile SyncSteering clonewars_steering_corrected_host,clonewars_steering_corrected_local,clonewars_steering_effective;
#ifdef STEERING_SYNC_TEST
extern int steering_test_valid(const void *,unsigned);
extern void *steering_test_hero(unsigned);
#define valid steering_test_valid
#define hero steering_test_hero
#else
static void *hero(unsigned slot){return *(void **)(0xfb4940+slot*4);}
static int valid(const void *pointer,unsigned size) {
    MEMORY_BASIC_INFORMATION m;return pointer && VirtualQuery(pointer,&m,sizeof(m)) && m.State==MEM_COMMIT &&
        !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) && (uintptr_t)pointer+size>=(uintptr_t)pointer && (uintptr_t)pointer+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
#endif
static uint32_t read32(const unsigned char *p) {uint32_t v;memcpy(&v,p,4);return v;}
static uint32_t read16(const unsigned char *p) {uint16_t v;memcpy(&v,p,2);return v;}
static void failed(void *actor,const SyncSteering *host,const SyncSteering *local,unsigned reason) {
    if (!clonewars_steering_failure[0]) {
        uint32_t slot=UINT32_MAX,generation=0;entities_observed_identity(actor,&slot,&generation);
        uint32_t values[]={journal.frame->epoch,journal.frame->sequence,journal.host?journal.frame->steering_count:journal.cursor,
            host?host->slot:UINT32_MAX,host?host->generation:0,slot,generation,reason,
            host?host->base_heading:0,local?local->base_heading:0,host?host->heading:0,local?local->heading:0,
            host?host->period:0,local?local->period:0,host?host->phase:0,local?local->phase:0};
        if(host)memcpy((void *)&clonewars_steering_failed_host,host,sizeof(*host));
        if(local)memcpy((void *)&clonewars_steering_failed_local,local,sizeof(*local));
        memcpy((void *)(clonewars_steering_failure+1),values+1,sizeof(values)-4);MemoryBarrier();clonewars_steering_failure[0]=values[0];
    }
    ++clonewars_steering_debug[3];game_sync_native_fault(19);
}
static int source_capture(SyncSteeringSource *out,unsigned char *p,unsigned char *c,unsigned char *provider){
 unsigned char *resource=*(unsigned char **)(p+0xf08),*base=*(unsigned char **)(p+0xc08);
 if(!valid(provider,0x200) || !valid(resource,0x30) || (base && !valid(base,0x228)))return 0;
 unsigned char *definition=*(unsigned char **)(resource+0x2c);
 if(!valid(definition,0xfc))return 0;
 memset(out,0,sizeof(*out));out->path=1;out->role_mask=read32(p+0x50)&0xa00;out->life_54=p[0x54];out->c84_mask=read32(p+0xc84)&0x104000;
 out->c7c_block=!!(read32(p+0xc7c)&0x800000);out->byte_110a=p[0x110a];out->action=read16(p+0x2f4);out->c00_present=*(void **)(p+0xc00)!=NULL;
 out->provider_190_bit=!!(read32(provider+0x190)&0x100);out->provider_b0_mode=read32(provider+0xb0);
 out->source_has_base=base!=NULL;out->source_base_heading=base?read32(base+0x224):0;
 out->source_previous_heading=read16(c+0x5a);out->source_last_heading=read16(c+0x5e);
 out->source_previous_magnitude=read32(c+0x38);out->source_last_magnitude=read32(c+0x34);
 out->actor_76=read16(p+0x76);out->actor_1c8_mask=!!(read32(p+0x1c8)&0x400);out->override_c44=read32(p+0xc44);out->override_c48=read32(p+0xc48);
 const unsigned offsets[]={0x2c,0x30,0x34,0xf8};for(unsigned i=0;i<4;++i)out->resource_speed[i]=read32(definition+offsets[i]);
 return 1;
}
__attribute__((used,noinline)) void steering_model_witness(void *actor,void *controller,void *provider){
 DWORD error=GetLastError();
#ifdef STEERING_TRACE_ONLY
 intent_frame_scope_model(actor,controller);SetLastError(error);return;
#endif
 if(active && !journal.failed){
  if(!scope || scope->actor!=actor || scope->witnessed || !valid(actor,0x1440) || !valid(controller,0x60)){
   journal.failed=10;failed(actor,NULL,NULL,10);
  }else if(actor==hero(0) || actor==hero(1)){
   scope->excluded=1;scope->witnessed=1;++clonewars_steering_debug[12];
  }else{
   unsigned char *p=actor;
   if(*(void **)(p+0x6cc)!=controller || (read32(p+0x50)&3)!=3 || (read32(p+0x50)&0x200) || !source_capture(&scope->source,p,controller,provider)){
    journal.failed=10;failed(actor,NULL,NULL,10);
   }else{scope->controller=controller;scope->generation=entities_observed_generation(actor);scope->witnessed=1;}
  }
 }
 SetLastError(error);
}
static void __attribute__((cdecl,noinline)) producer_hook(void *actor){
#ifdef STEERING_TRACE_ONLY
 if(!clonewars_intent_frame_enabled){original_producer(actor);return;}
 unsigned char trace_fx[512] __attribute__((aligned(16)));uint32_t trace_mxcsr=0x1f80;DWORD trace_error=GetLastError();
 __asm__ volatile("fxsave %0; fninit; ldmxcsr %1":"=m"(trace_fx):"m"(trace_mxcsr));
 void *trace_controller=valid(actor,0x6d0)?*(void **)((unsigned char *)actor+0x6cc):NULL;
 uint32_t trace_token=intent_frame_scope_begin(actor,trace_controller,(uint32_t)(uintptr_t)__builtin_return_address(0));
 SetLastError(trace_error);__asm__ volatile("fxrstor %0"::"m"(trace_fx));original_producer(actor);
 __asm__ volatile("fxsave %0; fninit; ldmxcsr %1":"=m"(trace_fx):"m"(trace_mxcsr));trace_error=GetLastError();
 intent_frame_scope_end(trace_token);SetLastError(trace_error);__asm__ volatile("fxrstor %0"::"m"(trace_fx));return;
#else

 if(!active){original_producer(actor);return;}
 unsigned char fx[512] __attribute__((aligned(16)));uint32_t default_mxcsr=0x1f80;DWORD error=GetLastError();
 __asm__ volatile("fxsave %0; fninit; ldmxcsr %1":"=m"(fx):"m"(default_mxcsr));
 if(scope_depth>=16){journal.failed=10;failed(actor,NULL,NULL,10);SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));original_producer(actor);return;}
 SteeringScope local={.actor=actor,.previous=scope};scope=&local;++scope_depth;
 SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));original_producer(actor);
 __asm__ volatile("fxsave %0; fninit; ldmxcsr %1":"=m"(fx):"m"(default_mxcsr));error=GetLastError();
 if(local.witnessed && !local.excluded && !local.joined && !journal.failed){journal.failed=10;failed(actor,NULL,NULL,10);}
 --scope_depth;scope=local.previous;SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));
#endif
}
static void apply(void *actor,void *controller) {
    if(!active || journal.failed)return;
    if(!valid(actor,0x1440) || !valid(controller,0x60)){++clonewars_steering_debug[14];journal.failed=4;failed(actor,NULL,NULL,4);return;}
    unsigned char *p=actor,*c=controller;
    if(!scope || scope->actor!=actor){journal.failed=10;failed(actor,NULL,NULL,10);return;}
    if(scope->excluded){if(actor!=hero(0) && actor!=hero(1)){journal.failed=10;failed(actor,NULL,NULL,10);}return;}
    if(!scope->witnessed)return;
    if(scope->joined){journal.failed=10;failed(actor,NULL,NULL,10);return;}scope->joined=1;
    if(scope->controller!=controller || !scope->generation || entities_observed_generation(actor)!=scope->generation){journal.failed=10;failed(actor,NULL,NULL,10);return;}
    if(actor==hero(0) || actor==hero(1)){journal.failed=10;failed(actor,NULL,NULL,10);return;}
    if((read32(p+0x50)&3)!=3 || (read32(p+0x50)&0x200) || !(read32(p+0xc80)&0x02000000) || *(void **)(p+0x6cc)!=controller){++clonewars_steering_debug[14];journal.failed=8;failed(actor,NULL,NULL,8);return;}
    ++clonewars_steering_debug[13];
    unsigned char *base=*(unsigned char **)(p+0xc08);
    if(base && !valid(base,0x228)){journal.failed=4;failed(actor,NULL,NULL,4);return;}
    SyncSteering local={0};local.source=scope->source;
    local.source.derived_c7c_bit=!!(read32(p+0xc7c)&0x20000000);local.source.lock_10d8=read32(p+0x10d8);
    local.source.join_action=read16(p+0x2f4);local.source.substate_2fa=p[0x2fa];
    unsigned char *resource=*(unsigned char **)(p+0xf08);
    if(!valid(resource,0x30)){journal.failed=10;failed(actor,NULL,NULL,10);return;}
    unsigned char *definition=*(unsigned char **)(resource+0x2c);
    if(!valid(definition,0xdc)){journal.failed=10;failed(actor,NULL,NULL,10);return;}
    local.source.alternate_motion=!!(read32(resource+0x14)&0x2000);local.source.resource_d8_bit=!!(read32(definition+0xd8)&0x100);
    local.heading=read16(c+0x26);memcpy(&local.magnitude,c+0x28,4);memcpy(local.direction,c+0x2c,8);
    local.has_base=base!=NULL;local.base_heading=base?read32(base+0x224):0;local.previous_heading=read16(c+0x5a);local.last_heading=read16(c+0x5e);
    memcpy(&local.previous_magnitude,c+0x38,4);memcpy(&local.last_magnitude,c+0x34,4);
    local.period=p[0x138e];local.phase=p[0x57];memcpy(&local.elapsed,p+0xe28,4);
    if(journal.host){
        entities_update();SyncActor identity={0};entities_describe(&identity,actor);
        local.slot=(uint32_t)entities_slot(actor);local.generation=identity.generation;local.spawn_tag=identity.spawn_tag;
        local.character=*(int16_t *)(p+0xdc0);memcpy(local.origin,identity.spawn_position,12);
        if(!steering_journal_record(&journal,&local)){failed(actor,&local,&local,4);return;}
        ++clonewars_steering_debug[0];
    }else{
        const SyncSteering *entry=steering_journal_peek(&journal);SyncActor identity={0};
        if(entry){identity.slot=entry->slot;identity.generation=entry->generation;identity.spawn_tag=entry->spawn_tag;identity.character=entry->character;memcpy(identity.spawn_position,entry->origin,12);}
        local.slot=entry?entry->slot:UINT32_MAX;local.generation=entities_observed_generation(actor);local.character=*(int16_t *)(p+0xdc0);
        if(!steering_journal_validate(&journal,entry,entry && entities_resolve_reference(&identity)==actor,&local)){failed(actor,entry,&local,(unsigned)journal.failed);return;}
        ++clonewars_steering_debug[1];
        int corrected=local.heading!=entry->heading || memcmp(&local.magnitude,&entry->magnitude,12)!=0;
        clonewars_steering_debug[2]+=corrected;
        uint16_t heading=(uint16_t)entry->heading;memcpy(c+0x26,&heading,2);memcpy(c+0x28,&entry->magnitude,12);
        if(corrected && !clonewars_steering_first_correction[0]){
            memcpy((void *)&clonewars_steering_corrected_host,entry,sizeof(*entry));memcpy((void *)&clonewars_steering_corrected_local,&local,sizeof(local));
            SyncSteering effective=local;effective.heading=read16(c+0x26);memcpy(&effective.magnitude,c+0x28,12);memcpy((void *)&clonewars_steering_effective,&effective,sizeof(effective));
            uint32_t values[]={journal.frame->epoch,journal.frame->sequence,journal.cursor,entry->slot,entry->generation,local.heading,entry->heading,0};
            memcpy((void *)(clonewars_steering_first_correction+1),values+1,sizeof(values)-4);MemoryBarrier();clonewars_steering_first_correction[0]=values[0];
        }
        clonewars_steering_debug[4]=journal.frame->sequence;clonewars_steering_debug[5]=journal.cursor;
        clonewars_steering_debug[6]=entry->slot;clonewars_steering_debug[7]=entry->generation;
    }
}
__attribute__((used,noinline)) void steering_apply_intent(void *actor,void *controller) {
#ifdef STEERING_TRACE_ONLY
    (void)actor;(void)controller;return;
#endif
    DWORD error=GetLastError();++clonewars_steering_debug[9];
    if(active)++clonewars_steering_debug[10];else{++clonewars_steering_debug[11];clonewars_steering_debug[15]=game_sync_sequence();}
    apply(actor,controller);SetLastError(error);
}
__attribute__((naked,used)) static void steering_model_thunk(void){__asm__ volatile(STEERING_MODEL_THUNK_ASM);}
__attribute__((naked,used)) static void steering_thunk(void) {__asm__ volatile(STEERING_THUNK_ASM);}
int steering_install(void) {
#ifdef STEERING_SYNC_TEST
    clonewars_steering_installed=7;return 1;
#else
    unsigned char *entry=(unsigned char *)0x9bf280,*model=(unsigned char *)0x9bf443,*join=(unsigned char *)0x9c02b3;
    const unsigned char ep[]={0x55,0x8b,0xec,0x83,0xe4,0xf0},mp[]={0xf7,0x83,0x7c,0x0c,0,0,0,0,0x80,0},jp[]={0xf7,0x43,0x50,0,2,0,0};
    if(memcmp(entry,ep,6)||memcmp(model,mp,10)||memcmp(join,jp,7)){clonewars_steering_installed=-1;return 0;}
    unsigned char *bridge=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);DWORD old[3];
    if(!bridge){clonewars_steering_installed=-1;return 0;}
    if(!VirtualProtect(entry,6,PAGE_EXECUTE_READWRITE,old)){VirtualFree(bridge,0,MEM_RELEASE);clonewars_steering_installed=-1;return 0;}
    if(!VirtualProtect(model,10,PAGE_EXECUTE_READWRITE,old+1)){VirtualProtect(entry,6,old[0],old);VirtualFree(bridge,0,MEM_RELEASE);clonewars_steering_installed=-1;return 0;}
    if(!VirtualProtect(join,7,PAGE_EXECUTE_READWRITE,old+2)){DWORD ignored;VirtualProtect(model,10,old[1],&ignored);VirtualProtect(entry,6,old[0],&ignored);VirtualFree(bridge,0,MEM_RELEASE);clonewars_steering_installed=-1;return 0;}
    memcpy(bridge,entry,6);bridge[6]=0xe9;*(int32_t *)(bridge+7)=(int32_t)((uintptr_t)entry+6-(uintptr_t)bridge-11);original_producer=(MotionProducer)bridge;
    unsigned char *sites[]={entry,model,join};uintptr_t targets[]={(uintptr_t)producer_hook,(uintptr_t)steering_model_thunk,(uintptr_t)steering_thunk};unsigned lengths[]={6,10,7};
    for(unsigned i=0;i<3;++i){sites[i][0]=0xe9;*(int32_t *)(sites[i]+1)=(int32_t)(targets[i]-(uintptr_t)sites[i]-5);memset(sites[i]+5,0x90,lengths[i]-5);FlushInstructionCache(GetCurrentProcess(),sites[i],lengths[i]);}
    /* Entry and MODEL share a page; restore overlapping protections in reverse order after all writes. */
    for(unsigned i=3;i>0;--i){DWORD ignored;VirtualProtect(sites[i-1],lengths[i-1],old[i-1],&ignored);}
    FlushInstructionCache(GetCurrentProcess(),bridge,11);clonewars_steering_installed=7;
#ifdef STEERING_TRACE_ONLY
    intent_frame_scope_binding_ready();
#endif
    return 1;
#endif
}
int steering_ready(void) {return clonewars_steering_installed==7;}
void steering_begin(SyncFrame *frame,int host) {
    if(last_epoch!=frame->epoch){memset((void *)clonewars_steering_failure,0,sizeof(clonewars_steering_failure));memset((void *)&clonewars_steering_failed_host,0,sizeof(SyncSteering));memset((void *)&clonewars_steering_failed_local,0,sizeof(SyncSteering));memset((void *)clonewars_steering_first_correction,0,sizeof(clonewars_steering_first_correction));last_epoch=frame->epoch;}
    scope=NULL;scope_depth=0;steering_journal_begin(&journal,frame,host);
#ifdef STEERING_TRACE_ONLY
    active=0;
#else
    active=1;
#endif
}
int steering_finish(void) {
    if(scope || scope_depth){journal.failed=10;failed(NULL,NULL,NULL,10);}
    active=0;++clonewars_steering_debug[8];
    if(!steering_journal_finish(&journal)){if(!journal.failed){const SyncSteering *entry=steering_journal_peek(&journal);journal.failed=3;failed(NULL,entry,NULL,3);}return 0;}
    return 1;
}
