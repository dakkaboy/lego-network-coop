#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "decision_observer.h"
#include "shooter_observer.h"
#include "../sync/entity_sync.h"
#include "../sync/game_sync.h"
#include "decision_checkpoint_thunk.h"
#define DECISION_CAPACITY 8192
#define DECISION_EXTRA_FIELDS 32
typedef struct DecisionIdentity { uint32_t pointer_local,valid,slot,generation,local_generation;int32_t character; } DecisionIdentity;
typedef struct DecisionActor {
    ShooterActorObservation common;
    uint32_t extra[DECISION_EXTRA_FIELDS];
    DecisionIdentity target_2bc,target_bdc;
    uint32_t pending_valid,pending[6];
    uint32_t held_weapon[8];
} DecisionActor;
typedef struct DecisionRecord {
    uint32_t committed,id,parent,kind,thread,caller,sequence;
    uint32_t qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t clock,rng_game,rng_engine,clock_after,rng_game_after,rng_engine_after;
    uint32_t context_local,arguments[10],result;
    DecisionActor before,after;
} DecisionRecord;
typedef struct DecisionScope { DecisionRecord record;struct DecisionScope *previous; } DecisionScope;
typedef unsigned char (__attribute__((thiscall)) *AttackSetup)(void *,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef char DecisionActorLayout[(sizeof(DecisionActor)==624)?1:-1];
typedef char DecisionRecordLayout[(sizeof(DecisionRecord)==1364)?1:-1];
static AttackSetup original_attack;
__attribute__((used)) static volatile uintptr_t decision_ammo_resume=0x878dc6,decision_compat_resume=0x878e07;
__attribute__((used)) static volatile uintptr_t decision_item_early_resume=0x8770cf,decision_item_late_resume=0x8789be;
__attribute__((used)) static volatile uintptr_t decision_cancel_pre_resume=0x878455,decision_cancel_post_resume=0x878478;
static __thread DecisionScope *active_scope;
__declspec(dllexport) volatile uint32_t clonewars_decision_observer_version=2;
__declspec(dllexport) volatile LONG clonewars_decision_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_decision_observer_installed;
__declspec(dllexport) volatile LONG clonewars_decision_checkpoint_installed;
__declspec(dllexport) volatile LONG clonewars_decision_observer_count;
__declspec(dllexport) volatile LONG clonewars_decision_observer_slot=7;
__declspec(dllexport) volatile LONG clonewars_decision_observer_character=321;
__declspec(dllexport) volatile uint32_t clonewars_decision_observer_stride=sizeof(DecisionRecord);
__declspec(dllexport) volatile uint32_t clonewars_decision_observer_capacity=DECISION_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_decision_actor_size=sizeof(DecisionActor);
__declspec(dllexport) volatile uint32_t clonewars_decision_extra_field_count=DECISION_EXTRA_FIELDS;
__declspec(dllexport) volatile uint32_t clonewars_decision_extra_offsets[DECISION_EXTRA_FIELDS]={0x24,0x28,0x2c,0x48,0x6c,0x2a0,0x2ac,0x2bc,0x2c0,0x2cc,0x2f0,0x2f4,0x2f8,0x2fc,0x7ec,0x7f8,0x8dc,0x8e0,0xbdc,0xc88,0xcfc,0xd04,0x530,0x540,0xe80,0x544,0x1088,0x108c,0x300,0x8e8,0xddc,0xd3c};
__declspec(dllexport) volatile DecisionRecord clonewars_decision_observer[DECISION_CAPACITY];
#ifdef DECISION_OBSERVER_TEST
extern int decision_test_read(uint32_t,void *,unsigned);
#define read_local decision_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size) {
    MEMORY_BASIC_INFORMATION m;
    if (!address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) || m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
        (uintptr_t)address+size<(uintptr_t)address || (uintptr_t)address+size>(uintptr_t)m.BaseAddress+m.RegionSize) return 0;
    memcpy(out,(void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address) { uint32_t value=0;read_local(address,&value,4);return value; }
static int actor_pointer(uint32_t pointer) {
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c);
    return pool && count<=4096 && pointer>=pool && (pointer-pool)%0x1440==0 && (pointer-pool)/0x1440<count;
}
static DecisionIdentity identity(uint32_t pointer) {
    DecisionIdentity value={.pointer_local=pointer,.slot=UINT32_MAX,.character=-1};int16_t character;
    if (!actor_pointer(pointer) || !read_local(pointer+0xdc0,&character,2)) return value;
    value.valid=1;value.character=character;value.local_generation=entities_observed_generation((void *)(uintptr_t)pointer);
    entities_observed_identity((void *)(uintptr_t)pointer,&value.slot,&value.generation);return value;
}
static void snapshot_held_weapon(uint32_t out[8],uint32_t held) {
    memset(out,0,8*sizeof(uint32_t));out[0]=held;
    unsigned char interaction[12],object[0x115],definition[0x139];
    if(read_local(held,interaction,sizeof(interaction))){
        out[3]|=1;memcpy(out+1,interaction+8,4);
        if(read_local(out[1],object,sizeof(object))){
            out[3]|=2;memcpy(out+2,object+0xac,4);out[5]=object[0x114];
            if(read_local(out[2],definition,sizeof(definition))){
                out[3]|=4;memcpy(out+4,definition+0x38,4);out[6]=definition[0x131];out[7]=definition[0x138];
            }
        }
    }
}
static void snapshot_actor(DecisionActor *out,void *actor) {
    memset(out,0,sizeof(*out));out->common.pointer_local=(uint32_t)(uintptr_t)actor;
    out->common.raw_slot=out->common.network_slot=UINT32_MAX;
    if (!actor_pointer((uint32_t)(uintptr_t)actor)) return;
    unsigned char raw[0x1440];if (!read_local((uint32_t)(uintptr_t)actor,raw,sizeof(raw))) return;
    shooter_observer_actor_snapshot(&out->common,actor);
    for (unsigned i=0;i<DECISION_EXTRA_FIELDS;++i)memcpy(out->extra+i,raw+clonewars_decision_extra_offsets[i],4);
    uint32_t target;memcpy(&target,raw+0x2bc,4);out->target_2bc=identity(target);memcpy(&target,raw+0xbdc,4);out->target_bdc=identity(target);
    uint32_t held;memcpy(&held,raw+0x528,4);snapshot_held_weapon(out->held_weapon,held);
    uint32_t pending;memcpy(&pending,raw+0x142c,4);unsigned char pending_raw[0x144];
    if (read_local(pending,pending_raw,sizeof(pending_raw))) {
        const unsigned offsets[]={0xbc,0xcc,0xd8,0xdc,0xe0,0x140};out->pending_valid=1;
        for(unsigned i=0;i<6;++i)memcpy(out->pending+i,pending_raw+offsets[i],4);
    }
}
static int selected(void *actor) {
    if (!clonewars_decision_observer_enabled) return 0;
    DecisionIdentity value=identity((uint32_t)(uintptr_t)actor);if (!value.valid) return 0;
    uint32_t slot=value.slot;
    if (slot==UINT32_MAX) { uint32_t pool=word(0xfb2f60);slot=((uint32_t)(uintptr_t)actor-pool)/0x1440; }
    return (clonewars_decision_observer_slot<0 || slot==(uint32_t)clonewars_decision_observer_slot) &&
        (clonewars_decision_observer_character<0 || value.character==clonewars_decision_observer_character);
}
static void begin(DecisionScope *scope,unsigned kind,void *actor,uint32_t context,const uint32_t *args,uint32_t caller) {
    memset(scope,0,sizeof(*scope));DecisionRecord *r=&scope->record;
    r->id=(uint32_t)InterlockedIncrement(&clonewars_decision_observer_count);r->parent=active_scope?active_scope->record.id:0;r->kind=kind;
    r->thread=GetCurrentThreadId();r->caller=caller;r->sequence=game_sync_sequence();r->context_local=context;
    if(args)memcpy(r->arguments,args,sizeof(r->arguments));
    r->clock=word(0xfb4b6c);r->rng_game=word(0xe637b4);r->rng_engine=word(0xea178c);
    LARGE_INTEGER qpc;QueryPerformanceCounter(&qpc);r->qpc_before_low=qpc.LowPart;r->qpc_before_high=(uint32_t)qpc.HighPart;
    snapshot_actor(&r->before,actor);scope->previous=active_scope;active_scope=scope;
}
static void finish(DecisionScope *scope,void *actor,uint32_t result) {
    DecisionRecord *r=&scope->record;snapshot_actor(&r->after,actor);r->result=result;
    r->clock_after=word(0xfb4b6c);r->rng_game_after=word(0xe637b4);r->rng_engine_after=word(0xea178c);
    LARGE_INTEGER qpc;QueryPerformanceCounter(&qpc);r->qpc_after_low=qpc.LowPart;r->qpc_after_high=(uint32_t)qpc.HighPart;
    active_scope=scope->previous;
    volatile DecisionRecord *destination=clonewars_decision_observer+(r->id-1)%DECISION_CAPACITY;
    destination->committed=0;memcpy((void *)destination,r,sizeof(*r));MemoryBarrier();destination->committed=r->id;
}
__attribute__((noinline)) static void observed_actor(unsigned kind,void *actor,void (*native)(void *),uint32_t caller) {
    DWORD error=GetLastError();DecisionScope scope;uint32_t args[10]={(uint32_t)(uintptr_t)actor};begin(&scope,kind,actor,(uint32_t)(uintptr_t)native,args,caller);SetLastError(error);
    native(actor);error=GetLastError();finish(&scope,actor,0);SetLastError(error);
}
void decision_observer_invoke_actor(unsigned kind,void *actor,void (*native)(void *),uint32_t caller) {
    if (!clonewars_decision_observer_enabled) { native(actor);return; }
    DWORD error=GetLastError();int observe=selected(actor);SetLastError(error);
    if (!observe) { native(actor);return; }
    observed_actor(kind,actor,native,caller);
}
__attribute__((noinline)) static unsigned char observed_attack(void *context,const uint32_t *args,uint32_t caller) {
    void *actor=(void *)(uintptr_t)args[0];DWORD error=GetLastError();DecisionScope scope;begin(&scope,1,actor,(uint32_t)(uintptr_t)context,args,caller);SetLastError(error);
    unsigned char result=original_attack(context,args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9]);
    error=GetLastError();finish(&scope,actor,result);SetLastError(error);return result;
}
static unsigned char __attribute__((fastcall)) attack_hook(void *context,void *unused,uint32_t a0,uint32_t a1,uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5,uint32_t a6,uint32_t a7,uint32_t a8,uint32_t a9) {
    (void)unused;
    if (!clonewars_decision_observer_enabled) return original_attack(context,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9);
    DWORD error=GetLastError();int observe=selected((void *)(uintptr_t)a0);SetLastError(error);
    if (!observe) return original_attack(context,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9);
    const uint32_t args[]={a0,a1,a2,a3,a4,a5,a6,a7,a8,a9};return observed_attack(context,args,(uint32_t)(uintptr_t)__builtin_return_address(0));
}
__attribute__((used,noinline)) void decision_observer_checkpoint(const uint32_t *native_stack,uint32_t result,uint32_t caller,const uint32_t *saved_context) {
    if(!clonewars_decision_observer_enabled || !active_scope || active_scope->record.kind!=1)return;
    DWORD error=GetLastError();DecisionScope scope;void *actor=(void *)(uintptr_t)active_scope->record.before.common.pointer_local;
    uint32_t args[10]={0};
    if(caller!=0x87844e && caller!=0x878472){
        read_local((uint32_t)(uintptr_t)native_stack,args,caller==0x878e02?8:4);
        if(saved_context){uint32_t regs[8];if(read_local((uint32_t)(uintptr_t)saved_context,regs,sizeof(regs))){args[2]=regs[0];args[3]=regs[1];args[4]=regs[4];args[5]=regs[6];args[6]=regs[5];args[7]=regs[2];}}
        args[8]=(uint32_t)(uintptr_t)native_stack;
    }
    uint8_t global=0;int global_known=read_local(0xe650e7,&global,1);args[9]=global_known?global:UINT32_MAX;
    if(caller==0x8770ca || caller==0x8789b9){
        actor=(void *)(uintptr_t)args[0];uint32_t held=0;uint8_t type=0;
        int readable=read_local((uint32_t)(uintptr_t)actor+0x528,&held,4) && held && read_local(held+0x48,&type,1);
        args[7]=readable!=0;args[8]=readable?type:UINT32_MAX;
    }
    if(caller==0x87844e || caller==0x878472){
        uint32_t regs[8]={0},native_args[2]={0},effective=0,magnitude=0,known=0;
        memset(args,0,sizeof(args));args[8]=(uint32_t)(uintptr_t)native_stack;args[9]=global_known?global:UINT32_MAX;
        if(saved_context && read_local((uint32_t)(uintptr_t)saved_context,regs,sizeof(regs))){
            known|=1;args[0]=regs[4];args[2]=regs[1];args[7]=regs[2];
            if(args[0]==(uint32_t)(uintptr_t)actor)known|=8;
            actor=(void *)(uintptr_t)regs[4];
            if(read_local(regs[2]+0xc,&effective,4)){known|=2;args[1]=effective;
                if(effective && read_local(effective+0x28,&magnitude,4)){known|=4;args[3]=magnitude;}}
        }
        if(caller==0x878472 && read_local((uint32_t)(uintptr_t)native_stack,native_args,8)){known|=16;args[5]=native_args[0];args[6]=native_args[1];}
        args[4]=known;
    }
    begin(&scope,4,actor,active_scope->record.context_local,args,caller);
    if(caller==0x878dc1)snapshot_held_weapon(scope.record.before.held_weapon,args[0]);
    finish(&scope,actor,result);SetLastError(error);
}
__attribute__((naked,used)) static void decision_ammo_thunk(void){__asm__ volatile(DECISION_CHECKPOINT_ASM("0x878dc1","4","decision_ammo_resume"));}
__attribute__((naked,used)) static void decision_compat_thunk(void){__asm__ volatile(DECISION_CHECKPOINT_ASM("0x878e02","8","decision_compat_resume"));}
__attribute__((naked,used)) static void decision_item_early_thunk(void){__asm__ volatile(DECISION_CHECKPOINT_AL_ASM("0x8770ca","4","decision_item_early_resume"));}
__attribute__((naked,used)) static void decision_item_late_thunk(void){__asm__ volatile(DECISION_CHECKPOINT_AL_ASM("0x8789b9","4","decision_item_late_resume"));}
__attribute__((naked,used)) static void decision_cancel_pre_thunk(void){__asm__ volatile(DECISION_CANCEL_PRE_ASM("decision_cancel_pre_resume"));}
__attribute__((naked,used)) static void decision_cancel_post_thunk(void){__asm__ volatile(DECISION_CANCEL_POST_ASM("decision_cancel_post_resume"));}
int decision_observer_install(void) {
#ifdef DECISION_OBSERVER_TEST
    return original_attack!=NULL;
#else
    unsigned char *sites[]={(void *)0x876a50,(void *)0x878dc1,(void *)0x878e02,(void *)0x8770ca,(void *)0x8789b9,(void *)0x87844e,(void *)0x878472};
    const unsigned char expected[][7]={{0x55,0x8b,0xec,0x83,0xe4,0xf0},{0x83,0xc4,4,0x85,0xc0},{0x83,0xc4,8,0x85,0xc0},{0x83,0xc4,4,0x84,0xc0},{0x83,0xc4,4,0x84,0xc0},{0xf6,0x83,0,3,0,0,8},{0x83,0xc4,8,0x83,0xf8,2}};
    unsigned lengths[]={6,5,5,5,5,7,6};uintptr_t native_calls[]={0,0x79d150,0x7b0390,0x7c7a70,0x7c7a70,0,0x88a120};
    uintptr_t hooks[]={(uintptr_t)attack_hook,(uintptr_t)decision_ammo_thunk,(uintptr_t)decision_compat_thunk,(uintptr_t)decision_item_early_thunk,(uintptr_t)decision_item_late_thunk,(uintptr_t)decision_cancel_pre_thunk,(uintptr_t)decision_cancel_post_thunk};DWORD old[7];
    for(unsigned i=0;i<7;++i)if(memcmp(sites[i],expected[i],lengths[i]) || (native_calls[i] && (sites[i][-5]!=0xe8 || (uintptr_t)sites[i]+*(int32_t *)(sites[i]-4)!=native_calls[i]))){clonewars_decision_observer_installed=-1;return 0;}
    unsigned char *bridge=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
    if(!bridge){clonewars_decision_observer_installed=-1;return 0;}
    unsigned protected=0;for(;protected<7;++protected)if(!VirtualProtect(sites[protected],lengths[protected],PAGE_EXECUTE_READWRITE,old+protected))break;
    if(protected<7){while(protected){--protected;DWORD ignored;VirtualProtect(sites[protected],lengths[protected],old[protected],&ignored);}VirtualFree(bridge,0,MEM_RELEASE);clonewars_decision_observer_installed=-1;return 0;}
    memcpy(bridge,sites[0],6);bridge[6]=0xe9;*(int32_t *)(bridge+7)=(int32_t)((uintptr_t)sites[0]+6-(uintptr_t)bridge-11);original_attack=(AttackSetup)bridge;
    for(unsigned i=0;i<7;++i){sites[i][0]=0xe9;*(int32_t *)(sites[i]+1)=(int32_t)(hooks[i]-(uintptr_t)sites[i]-5);memset(sites[i]+5,0x90,lengths[i]-5);FlushInstructionCache(GetCurrentProcess(),sites[i],lengths[i]);}
    for(unsigned i=7;i>0;--i){DWORD ignored;VirtualProtect(sites[i-1],lengths[i-1],old[i-1],&ignored);}FlushInstructionCache(GetCurrentProcess(),bridge,11);
    clonewars_decision_checkpoint_installed=63;clonewars_decision_observer_installed=1;return 1;
#endif
}
