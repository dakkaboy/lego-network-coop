#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "collision_observer.h"
#include "../sync/projectile_sync.h"
#include "../sync/entity_sync.h"
#include "../sync/game_sync.h"
#include "../sync/geometry_sync.h"
_Static_assert(sizeof(CollisionGeometry)==184,"Collision geometry layout");
_Static_assert(sizeof(CollisionShot)==568,"Collision shot layout");
_Static_assert(sizeof(CollisionObservation)==1648,"Collision query layout");
_Static_assert(sizeof(CollisionGeometryObservation)==448,"Collision phase geometry layout");
typedef void (__attribute__((thiscall)) *Query)(void *,void *,void *,const float *,int,uintptr_t);
typedef void (__attribute__((thiscall)) *Manager)(void *,void *,void *,void *);
static Query original_query;
static Manager original_manager;
extern volatile LONG clonewars_combat_observer_count;
__declspec(dllexport) volatile LONG clonewars_collision_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_collision_observer_installed;
__declspec(dllexport) volatile LONG clonewars_collision_observer_count;
__declspec(dllexport) volatile uint32_t clonewars_collision_observer_stride=sizeof(CollisionObservation);
__declspec(dllexport) volatile uint32_t clonewars_collision_observer_capacity=COLLISION_OBSERVER_CAPACITY;
__declspec(dllexport) volatile CollisionObservation clonewars_collision_observer[COLLISION_OBSERVER_CAPACITY];
__declspec(dllexport) volatile LONG clonewars_collision_geometry_count;
__declspec(dllexport) volatile uint32_t clonewars_collision_geometry_stride=sizeof(CollisionGeometryObservation);
__declspec(dllexport) volatile uint32_t clonewars_collision_geometry_capacity=COLLISION_GEOMETRY_CAPACITY;
__declspec(dllexport) volatile CollisionGeometryObservation clonewars_collision_geometry[COLLISION_GEOMETRY_CAPACITY];
__declspec(dllexport) volatile uint32_t clonewars_collision_debug[8];
static __thread uint32_t active_query,active_manager,active_ordinal,last_sequence,manager_ordinal;
#ifdef COLLISION_OBSERVER_TEST
extern int collision_test_read(uint32_t,void *,unsigned);
#define read_local collision_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size) {
    MEMORY_BASIC_INFORMATION m;
    if (!address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) || m.State!=MEM_COMMIT ||
        (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) || (uintptr_t)address+size<(uintptr_t)address ||
        (uintptr_t)address+size>(uintptr_t)m.BaseAddress+m.RegionSize) return 0;
    memcpy(out,(void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address) { uint32_t result=0;read_local(address,&result,4);return result; }
static void timestamp(uint32_t *low,uint32_t *high) { LARGE_INTEGER q;QueryPerformanceCounter(&q);*low=q.LowPart;*high=(uint32_t)q.HighPart; }
static void geometry(CollisionGeometry *out,void *actor) {
    memset(out,0,sizeof(*out));out->pointer_local=(uint32_t)(uintptr_t)actor;out->raw_slot=out->network_slot=UINT32_MAX;
    unsigned char raw[0x1440];if (!read_local(out->pointer_local,raw,sizeof(raw))) return;
    out->valid=1;out->local_generation=entities_observed_generation(actor);entities_observed_identity(actor,&out->network_slot,&out->network_generation);
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c),offset=out->pointer_local-pool;
    if (pool && offset%0x1440==0 && offset/0x1440<count) out->raw_slot=offset/0x1440;
    int16_t character,state;memcpy(&character,raw+0xdc0,2);memcpy(&state,raw+0x2f4,2);out->character=character;out->state=state;out->health=(int8_t)raw[0xdde];
    const unsigned offsets[]={0x4c,0x50,0xc78,0xc80,0xc8c,0xc94,0xce4,0xcea};
    for (unsigned i=0;i<8;++i) memcpy(out->flags+i,raw+offsets[i],4);
    memcpy(out->world,raw+0x24,12);memcpy(out->bounds,raw+0x30,24);memcpy(out->center,raw+0xf28,12);memcpy(out->extents,raw+0x1088,8);
    memcpy(&out->invulnerability,raw+0xd3c,4);memcpy(&out->elapsed,raw+0xe28,4);memcpy(out->facing,raw+0xf10,12);memcpy(&out->life,raw+0x54,4);memcpy(&out->heading,raw+0xf0c,4);
    memcpy(out->model,raw+8,4);unsigned char flags[2]={0};
    int model29=read_local(out->model[0]+0x29,flags,1),model42=read_local(out->model[0]+0x42,flags+1,1);
    out->model[1]=model29|(model42<<1);out->model[2]=flags[0];out->model[3]=flags[1];
    uint32_t resource;memcpy(&resource,raw+0xf08,4);out->definition[0]=word(resource+0x2c);
    uint32_t flag_dc=0,flag_ec=0;int dc=read_local(out->definition[0]+0xdc,&flag_dc,4),ec=read_local(out->definition[0]+0xec,&flag_ec,4);
    out->definition[1]=dc|(ec<<1);out->definition[2]=flag_dc;out->definition[3]=flag_ec;
}
static void shot_snapshot(CollisionShot *out,void *shot) {
    memset(out,0,sizeof(*out));out->pointer_local=(uint32_t)(uintptr_t)shot;out->owner=out->weapon=-1;
    ProjectileIdentityView identity;projectiles_observe_live(shot,&identity);out->status=identity.status;
    if (identity.status!=SHOT_LIVE) return;
    out->id=identity.id;out->owner=identity.owner;out->weapon=identity.weapon;out->owner_generation=identity.owner_generation;
    out->resource_local=identity.resource_local;out->instance_serial=identity.instance_serial;out->creation_count=identity.creation_count;
    out->raw_valid=read_local(out->pointer_local,out->raw,sizeof(out->raw));
}
static void __attribute__((fastcall)) query_hook(void *manager,void *unused,void *shot,void *target,const float *points,int index,uintptr_t extra) {
    (void)unused;
    if (!clonewars_collision_observer_enabled) { original_query(manager,shot,target,points,index,extra);return; }
    CollisionObservation r={0};r.id=(uint32_t)InterlockedIncrement(&clonewars_collision_observer_count);r.parent=active_query;
    r.manager_id=active_manager;r.manager_ordinal=active_ordinal;r.thread=GetCurrentThreadId();r.caller=(uint32_t)(uintptr_t)__builtin_return_address(0);r.sequence=game_sync_sequence();
    r.manager_local=(uint32_t)(uintptr_t)manager;r.arguments_local[0]=(uint32_t)(uintptr_t)shot;r.arguments_local[1]=(uint32_t)(uintptr_t)target;r.arguments_local[2]=(uint32_t)(uintptr_t)points;r.arguments_local[3]=(uint32_t)index;r.arguments_local[4]=(uint32_t)extra;
    timestamp(&r.qpc_before_low,&r.qpc_before_high);r.clock=word(0xfb4b6c);r.rng_game=word(0xe637b4);r.rng_engine=word(0xea178c);
    r.combat_before=(uint32_t)clonewars_combat_observer_count;r.points_valid=read_local((uint32_t)(uintptr_t)points,r.points,sizeof(r.points));
    geometry(&r.target_before,target);shot_snapshot(&r.shot_before,shot);
    uint32_t previous=active_query;active_query=r.id;
    original_query(manager,shot,target,points,index,extra);
    active_query=previous;geometry(&r.target_after,target);shot_snapshot(&r.shot_after,shot);
    r.clock_after=word(0xfb4b6c);r.rng_game_after=word(0xe637b4);r.rng_engine_after=word(0xea178c);r.combat_after=(uint32_t)clonewars_combat_observer_count;timestamp(&r.qpc_after_low,&r.qpc_after_high);
    volatile CollisionObservation *out=clonewars_collision_observer+(r.id-1)%COLLISION_OBSERVER_CAPACITY;
    out->committed=0;memcpy((void *)out,&r,sizeof(r));MemoryBarrier();out->committed=r.id;
    ++clonewars_collision_debug[0];if (!r.manager_id) ++clonewars_collision_debug[1];
}
static void __attribute__((fastcall)) manager_hook(void *manager,void *unused,void *packet,void *event,void *context) {
    (void)unused;
    if (!clonewars_collision_observer_enabled) { if (geometry_phase(word((uint32_t)(uintptr_t)packet+0xc))) original_manager(manager,packet,event,context);return; }
    uint32_t sequence=game_sync_sequence();if (last_sequence!=sequence) { last_sequence=sequence;manager_ordinal=0; }
    uint32_t id=(uint32_t)InterlockedIncrement((volatile LONG *)(clonewars_collision_debug+2)),ordinal=++manager_ordinal;
    uint32_t previous_manager=active_manager,previous_ordinal=active_ordinal;active_manager=id;active_ordinal=ordinal;
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c),saved_count=0;
    if (word((uint32_t)(uintptr_t)packet+0xc)!=0) { count=0;++clonewars_collision_debug[6]; }
    if (count>SYNC_MAX_ACTORS) { count=SYNC_MAX_ACTORS;++clonewars_collision_debug[4]; }
    CollisionGeometryObservation *scratch=count ? HeapAlloc(GetProcessHeap(),HEAP_ZERO_MEMORY,count*sizeof(*scratch)) : NULL;
    if (count && !scratch) ++clonewars_collision_debug[3];
    if (scratch) for (uint32_t slot=0;slot<count;++slot) {
        void *actor=(void *)(uintptr_t)(pool+slot*0x1440);
        if ((word((uint32_t)(uintptr_t)actor+0x50)&3)!=3) continue;
        CollisionGeometryObservation *r=scratch+saved_count++;
        r->id=(uint32_t)InterlockedIncrement(&clonewars_collision_geometry_count);r->manager_id=id;r->manager_ordinal=ordinal;r->thread=GetCurrentThreadId();r->sequence=sequence;
        r->manager_local=(uint32_t)(uintptr_t)manager;r->packet_mode=word((uint32_t)(uintptr_t)packet+0xc);r->event_word=word((uint32_t)(uintptr_t)event);r->ordinal=slot;
        timestamp(&r->qpc_before_low,&r->qpc_before_high);r->clock=word(0xfb4b6c);r->rng_game=word(0xe637b4);r->rng_engine=word(0xea178c);geometry(&r->before,actor);
    }
    if (geometry_phase(word((uint32_t)(uintptr_t)packet+0xc))) original_manager(manager,packet,event,context);
    else ++clonewars_collision_debug[7];
    for (uint32_t i=0;i<saved_count;++i) {
        CollisionGeometryObservation *r=scratch+i;geometry(&r->after,(void *)(uintptr_t)r->before.pointer_local);
        r->clock_after=word(0xfb4b6c);r->rng_game_after=word(0xe637b4);r->rng_engine_after=word(0xea178c);timestamp(&r->qpc_after_low,&r->qpc_after_high);
        volatile CollisionGeometryObservation *out=clonewars_collision_geometry+(r->id-1)%COLLISION_GEOMETRY_CAPACITY;
        out->committed=0;memcpy((void *)out,r,sizeof(*r));MemoryBarrier();out->committed=r->id;
        ++clonewars_collision_debug[5];
    }
    if (scratch) HeapFree(GetProcessHeap(),0,scratch);
    active_manager=previous_manager;active_ordinal=previous_ordinal;
}
int collision_observer_install(void) {
#ifdef COLLISION_OBSERVER_TEST
    return original_query && original_manager;
#else
    const uintptr_t entries[]={0x81e860,0x863410};
    static const unsigned char prefixes[2][6]={{0x55,0x8b,0xec,0x83,0xe4,0xf0},{0x81,0xec,0xcc,0,0,0}};
    void *hooks[]={(void *)query_hook,(void *)manager_hook};
    for (unsigned i=0;i<2;++i) if (memcmp((void *)entries[i],prefixes[i],6)) { clonewars_collision_observer_installed=-1;return 0; }
    for (unsigned i=0;i<2;++i) {
        unsigned char *entry=(unsigned char *)entries[i],*bridge=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);DWORD old;
        if (!bridge || !VirtualProtect(entry,6,PAGE_EXECUTE_READWRITE,&old)) { clonewars_collision_observer_installed=-1;return 0; }
        memcpy(bridge,entry,6);bridge[6]=0xe9;*(int32_t *)(bridge+7)=(int32_t)((uintptr_t)entry+6-(uintptr_t)bridge-11);
        if (i) original_manager=(Manager)bridge;else original_query=(Query)bridge;
        FlushInstructionCache(GetCurrentProcess(),bridge,11);entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)hooks[i]-(uintptr_t)entry-5);entry[5]=0x90;
        FlushInstructionCache(GetCurrentProcess(),entry,6);VirtualProtect(entry,6,old,&old);InterlockedOr(&clonewars_collision_observer_installed,1<<i);
    }
    geometry_manager_ready();return 1;
#endif
}
