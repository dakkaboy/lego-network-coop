#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "world_contact_observer.h"
#include "world_contact_thunk.h"
#include "projectile_sync.h"
#include "game_sync.h"
_Static_assert(sizeof(WorldContactHeader)==104,"World contact header layout");
_Static_assert(sizeof(WorldContactObject)==364,"World contact object layout");
_Static_assert(sizeof(WorldContactEntry)==24620,"World contact entry layout");
_Static_assert(sizeof(WorldContactQuery)==1084,"World contact query layout");
typedef unsigned char (__attribute__((thiscall)) *Contact)(void *,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef struct ContactScope {WorldContactEntry record;struct ContactScope *previous;} ContactScope;
static Contact original_contact;
static __thread ContactScope *active_scope;
static __thread uint32_t last_epoch,last_sequence,frame_ordinal;
__attribute__((used)) static volatile uintptr_t world_contact_query_resume=0x81f7c4;
__declspec(dllexport) volatile LONG clonewars_world_contact_enabled,clonewars_world_contact_installed;
__declspec(dllexport) volatile LONG clonewars_world_contact_entry_count,clonewars_world_contact_query_count;
__declspec(dllexport) volatile uint32_t clonewars_world_contact_version=1;
__declspec(dllexport) volatile uint32_t clonewars_world_contact_entry_stride=sizeof(WorldContactEntry),clonewars_world_contact_query_stride=sizeof(WorldContactQuery);
__declspec(dllexport) volatile uint32_t clonewars_world_contact_entry_capacity=WORLD_CONTACT_ENTRY_CAPACITY,clonewars_world_contact_query_capacity=WORLD_CONTACT_QUERY_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_world_contact_object_stride=sizeof(WorldContactObject),clonewars_world_contact_max_candidates=WORLD_CONTACT_CANDIDATES;
__declspec(dllexport) volatile WorldContactEntry clonewars_world_contact_entries[WORLD_CONTACT_ENTRY_CAPACITY];
__declspec(dllexport) volatile WorldContactQuery clonewars_world_contact_queries[WORLD_CONTACT_QUERY_CAPACITY];
#ifdef WORLD_CONTACT_TEST
extern int world_contact_test_read(uint32_t,void *,unsigned);
#define read_local world_contact_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size){
    MEMORY_BASIC_INFORMATION m;
    if(!address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) || m.State!=MEM_COMMIT || (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
       (uintptr_t)address+size<(uintptr_t)address || (uintptr_t)address+size>(uintptr_t)m.BaseAddress+m.RegionSize)return 0;
    memcpy(out,(void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address){uint32_t value=0;read_local(address,&value,4);return value;}
static void timestamp(uint32_t *lo,uint32_t *hi){LARGE_INTEGER q;QueryPerformanceCounter(&q);*lo=q.LowPart;*hi=(uint32_t)q.HighPart;}
static void header_before(WorldContactHeader *h,uint32_t id,uint32_t parent,uint32_t caller,uint32_t manager,uint32_t ordinal,const uint32_t *args){
    h->id=id;h->parent=parent;h->thread=GetCurrentThreadId();h->caller=caller;h->epoch=game_sync_epoch();h->sequence=game_sync_sequence();h->ordinal=ordinal;
    h->manager_local=manager;memcpy(h->arguments,args,24);h->clock=word(0xfb4b6c);h->rng_game=word(0xe637b4);h->rng_engine=word(0xea178c);timestamp(&h->qpc_before_low,&h->qpc_before_high);
}
static void header_after(WorldContactHeader *h,uint32_t result){
    h->result=result;h->clock_after=word(0xfb4b6c);h->rng_game_after=word(0xe637b4);h->rng_engine_after=word(0xea178c);timestamp(&h->qpc_after_low,&h->qpc_after_high);
}
static void source_snapshot(CollisionShot *out,uint32_t pointer){
    memset(out,0,sizeof(*out));out->pointer_local=pointer;out->owner=out->weapon=-1;ProjectileIdentityView identity;
    projectiles_observe_live((void *)(uintptr_t)pointer,&identity);out->status=identity.status;
    if(identity.status==SHOT_LIVE){out->id=identity.id;out->owner=identity.owner;out->weapon=identity.weapon;out->owner_generation=identity.owner_generation;
        out->resource_local=identity.resource_local;out->instance_serial=identity.instance_serial;out->creation_count=identity.creation_count;}
    out->raw_valid=read_local(pointer,out->raw,sizeof(out->raw));
}
static void object_snapshot(WorldContactObject *out,uint32_t node,uint32_t object){
    memset(out,0,sizeof(*out));out->node_local=node;out->pointer_local=object;out->raw_valid=read_local(object,out->raw,sizeof(out->raw));
}
static void candidates_snapshot(WorldContactEntry *r){
    uint32_t node;
    if(!read_local(r->header.manager_local+0x34,&node,4)){r->candidate_status=2;return;}
    r->candidate_head=node;r->candidate_status=1;
    while(node){
        for(unsigned i=0;i<r->candidate_count;++i)if(r->candidates[i].node_local==node){r->candidate_status=3;return;}
        if(r->candidate_count==WORLD_CONTACT_CANDIDATES){r->candidate_status=4;return;}
        uint32_t links[3];if(!read_local(node,links,sizeof(links))){r->candidate_status=2;return;}
        WorldContactObject *candidate=r->candidates+r->candidate_count++;object_snapshot(candidate,node,links[2]);
        if(!candidate->raw_valid){r->candidate_status=2;return;}node=links[0];
    }
}
__attribute__((noinline)) static unsigned char observed_contact(void *manager,const uint32_t *args,uint32_t caller){
    DWORD error=GetLastError();ContactScope scope;memset(&scope,0,sizeof(scope));WorldContactEntry *r=&scope.record;
    uint32_t epoch=game_sync_epoch(),sequence=game_sync_sequence();
    if(last_epoch!=epoch || last_sequence!=sequence){last_epoch=epoch;last_sequence=sequence;frame_ordinal=0;}
    header_before(&r->header,(uint32_t)InterlockedIncrement(&clonewars_world_contact_entry_count),active_scope?active_scope->record.header.id:0,caller,(uint32_t)(uintptr_t)manager,++frame_ordinal,args);
    source_snapshot(&r->source_before,args[0]);r->points_valid=read_local(args[1],r->points,sizeof(r->points));
    r->bounds_valid=read_local(args[2],r->bounds,12)|(read_local(args[3],r->bounds+3,12)<<1);candidates_snapshot(r);
    scope.previous=active_scope;active_scope=&scope;SetLastError(error);
    unsigned char result=original_contact(manager,args[0],args[1],args[2],args[3],args[4],args[5]);error=GetLastError();
    active_scope=scope.previous;source_snapshot(&r->source_after,args[0]);header_after(&r->header,result);
    volatile WorldContactEntry *destination=clonewars_world_contact_entries+(r->header.id-1)%WORLD_CONTACT_ENTRY_CAPACITY;
    destination->header.committed=0;memcpy((void *)destination,r,sizeof(*r));MemoryBarrier();destination->header.committed=r->header.id;SetLastError(error);return result;
}
static unsigned char __attribute__((fastcall)) contact_hook(void *manager,void *unused,uint32_t a0,uint32_t a1,uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5){
    (void)unused;if(!clonewars_world_contact_enabled)return original_contact(manager,a0,a1,a2,a3,a4,a5);
    const uint32_t args[]={a0,a1,a2,a3,a4,a5};return observed_contact(manager,args,(uint32_t)(uintptr_t)__builtin_return_address(0));
}
__attribute__((used,noinline)) void world_contact_query_checkpoint(const uint32_t *native_stack,uint32_t result,uint32_t caller,const uint32_t *saved_context){
    if(!clonewars_world_contact_enabled || !active_scope)return;
    DWORD error=GetLastError();WorldContactQuery r={0};uint32_t args[6]={0},regs[8]={0};
    r.arguments_valid=read_local((uint32_t)(uintptr_t)native_stack,args,sizeof(args));r.context_valid=read_local((uint32_t)(uintptr_t)saved_context,regs,sizeof(regs));
    WorldContactEntry *parent=&active_scope->record;
    header_before(&r.header,(uint32_t)InterlockedIncrement(&clonewars_world_contact_query_count),parent->header.id,caller,parent->header.manager_local,parent->header.ordinal,args);
    source_snapshot(&r.source,parent->header.arguments[0]);object_snapshot(&r.object,0,r.context_valid?regs[1]:0);
    for(unsigned i=0;i<parent->candidate_count;++i)if(r.object.pointer_local && parent->candidates[i].pointer_local==r.object.pointer_local){r.object.node_local=parent->candidates[i].node_local;break;}
    r.sample_index=r.context_valid?regs[5]:UINT32_MAX;r.point_local=r.context_valid?regs[2]:0;r.center_valid=read_local(args[0],r.center,12);r.point_valid=read_local(args[3],r.point,12);header_after(&r.header,result);
    volatile WorldContactQuery *destination=clonewars_world_contact_queries+(r.header.id-1)%WORLD_CONTACT_QUERY_CAPACITY;
    destination->header.committed=0;memcpy((void *)destination,&r,sizeof(r));MemoryBarrier();destination->header.committed=r.header.id;SetLastError(error);
}
__attribute__((naked,used)) static void query_checkpoint_thunk(void){__asm__ volatile(WORLD_CONTACT_QUERY_THUNK_ASM);}
int world_contact_observer_install(void){
#ifdef WORLD_CONTACT_TEST
    return original_contact!=NULL;
#else
    unsigned char *entry=(unsigned char *)0x81f6c0,*site=(unsigned char *)0x81f7bf;
    const unsigned char prefix[]={0x51,0x8b,0x41,0x34,0x53,0x55,0x56,0x57},query[]={0x83,0xc4,0x18,0x85,0xc0};DWORD protection;
    if(memcmp(entry,prefix,8) || memcmp(site,query,5) || site[-5]!=0xe8 || (uintptr_t)site+*(int32_t *)(site-4)!=0x78e650){clonewars_world_contact_installed=-1;return 0;}
    unsigned char *bridge=VirtualAlloc(NULL,13,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
    if(!bridge || !VirtualProtect(entry,8,PAGE_EXECUTE_READWRITE,&protection)){clonewars_world_contact_installed=-1;return 0;}
    memcpy(bridge,entry,8);bridge[8]=0xe9;*(int32_t *)(bridge+9)=(int32_t)((uintptr_t)entry+8-(uintptr_t)bridge-13);original_contact=(Contact)bridge;
    entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)contact_hook-(uintptr_t)entry-5);memset(entry+5,0x90,3);
    FlushInstructionCache(GetCurrentProcess(),bridge,13);FlushInstructionCache(GetCurrentProcess(),entry,8);VirtualProtect(entry,8,protection,&protection);
    if(!VirtualProtect(site,5,PAGE_EXECUTE_READWRITE,&protection)){clonewars_world_contact_installed=-1;return 0;}
    site[0]=0xe9;*(int32_t *)(site+1)=(int32_t)((uintptr_t)query_checkpoint_thunk-(uintptr_t)site-5);FlushInstructionCache(GetCurrentProcess(),site,5);VirtualProtect(site,5,protection,&protection);
    clonewars_world_contact_installed=3;return 1;
#endif
}

