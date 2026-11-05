#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "shooter_observer.h"
#include "entity_sync.h"
#include "game_sync.h"
typedef void (*ActorLate)(void *);
static ActorLate original_actor_late,original_actor_parent,original_actor_update;
__declspec(dllexport) volatile LONG clonewars_shooter_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_shooter_observer_installed;
__declspec(dllexport) volatile LONG clonewars_shooter_observer_count;
__declspec(dllexport) volatile LONG clonewars_shooter_observer_character=321;
__declspec(dllexport) volatile uint32_t clonewars_shooter_actor_field_count=SHOOTER_ACTOR_FIELDS;
__declspec(dllexport) volatile uint32_t clonewars_shooter_observer_stride=sizeof(ShooterObservation);
__declspec(dllexport) volatile uint32_t clonewars_shooter_observer_capacity=SHOOTER_OBSERVER_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_shooter_actor_offsets[SHOOTER_ACTOR_FIELDS]={0x4c,0x50,0x54,0x100,0x108,0x10c,0x110,0x114,0x118,0x11c,0x120,0x124,0x128,0x12c,0x130,0x134,0x138,0x13c,0x140,0x144,0x180,0x2a0,0x2e8,0x2f4,0x346,0x348,0x55c,0x610,0x67c,0x680,0x6a8,0x6ac,0x6b0,0x6cc,0x8d8,0x8e8,0x8ec,0x8f8,0xbdc,0xbe0,0xbe4,0xbe8,0xc78,0xc80,0xc8c,0xc94,0xee0,0xee4,0xee8,0xeec,0xef0,0xef4,0xef8,0xefc,0xf00,0xf04,0xf08,0xe28,0x142c,0xd88,0x10ec,0xb80,0x760};
__declspec(dllexport) volatile ShooterObservation clonewars_shooter_observer[SHOOTER_OBSERVER_CAPACITY];
static __thread ShooterObservationScope *active_scope;
#ifdef SHOOTER_OBSERVER_TEST
extern int shooter_test_read(uint32_t,void *,unsigned);
#define read_local shooter_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size) {
    MEMORY_BASIC_INFORMATION m;
    if (!address || !VirtualQuery((void *)(uintptr_t)address,&m,sizeof(m)) || m.State!=MEM_COMMIT ||
        (m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) || (uintptr_t)address+size<(uintptr_t)address ||
        (uintptr_t)address+size>(uintptr_t)m.BaseAddress+m.RegionSize) return 0;
    memcpy(out,(void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address) { uint32_t value=0;read_local(address,&value,4);return value; }
static void actor_snapshot(ShooterActorObservation *out,void *actor) {
    memset(out,0,sizeof(*out));out->pointer_local=(uint32_t)(uintptr_t)actor;out->raw_slot=out->network_slot=UINT32_MAX;
    unsigned char raw[0x1440];if (!read_local(out->pointer_local,raw,sizeof(raw))) return;
    out->valid=1;out->local_generation=entities_observed_generation(actor);
    entities_observed_identity(actor,&out->network_slot,&out->network_generation);
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c),offset=out->pointer_local-pool;
    if (pool && offset%0x1440==0 && offset/0x1440<count) out->raw_slot=offset/0x1440;
    int16_t character;memcpy(&character,raw+0xdc0,2);out->character=character;
    for (unsigned i=0;i<SHOOTER_ACTOR_FIELDS;++i) memcpy(out->words+i,raw+clonewars_shooter_actor_offsets[i],4);
    memcpy(&out->controller_local,raw+0x6cc,4);
    out->controller_valid=read_local(out->controller_local,out->controller_words,sizeof(out->controller_words));
    memcpy(&out->model_local,raw+8,4);unsigned char model_flags=0;
    out->model_valid=read_local(out->model_local+0x29,&model_flags,1);out->model_flags29=model_flags;
    uint32_t resource,actor100;memcpy(&resource,raw+0xf08,4);out->resource24_local=word(resource+0x24);
    memcpy(&actor100,raw+0x100,4);out->actor100_valid=read_local(actor100,&out->actor100_word0,4);
    unsigned char active=0;out->model_active42_valid=read_local(out->model_local+0x42,&active,1);out->model_active42=active;
    out->global_fb32a8=word(0xfb32a8);
}
void shooter_observer_actor_snapshot(ShooterActorObservation *out,void *actor) { actor_snapshot(out,actor); }
static void begin(ShooterObservationScope *scope,uint32_t kind,void *actor,uint32_t caller) {
    memset(scope,0,sizeof(*scope));ShooterObservation *r=&scope->record;
    r->id=(uint32_t)InterlockedIncrement(&clonewars_shooter_observer_count);r->kind=kind;r->caller=caller;
    r->parent=active_scope ? active_scope->record.id : 0;r->thread=GetCurrentThreadId();r->sequence=game_sync_sequence();
    r->clock=word(0xfb4b6c);r->rng_game=word(0xe637b4);r->rng_engine=word(0xea178c);
    LARGE_INTEGER q;QueryPerformanceCounter(&q);r->qpc_before_low=q.LowPart;r->qpc_before_high=(uint32_t)q.HighPart;
    actor_snapshot(&r->before,actor);scope->previous=active_scope;active_scope=scope;
}
static void finish(ShooterObservationScope *scope) {
    ShooterObservation *r=&scope->record;actor_snapshot(&r->after,(void *)(uintptr_t)r->before.pointer_local);
    r->clock_after=word(0xfb4b6c);r->rng_game_after=word(0xe637b4);r->rng_engine_after=word(0xea178c);
    LARGE_INTEGER q;QueryPerformanceCounter(&q);r->qpc_after_low=q.LowPart;r->qpc_after_high=(uint32_t)q.HighPart;
    active_scope=scope->previous;
    volatile ShooterObservation *out=clonewars_shooter_observer+(r->id-1)%SHOOTER_OBSERVER_CAPACITY;
    out->committed=0;memcpy((void *)out,r,sizeof(*r));MemoryBarrier();out->committed=r->id;
}
static void observe_actor(uint32_t kind,ActorLate native,void *actor,uint32_t caller) {
    if (!clonewars_shooter_observer_enabled) { native(actor);return; }
    int16_t character=-1;read_local((uint32_t)(uintptr_t)actor+0xdc0,&character,2);
    if (clonewars_shooter_observer_character>=0 && character!=clonewars_shooter_observer_character) { native(actor);return; }
    ShooterObservationScope scope;begin(&scope,kind,actor,caller);
    native(actor);finish(&scope);
}
static void actor_late_hook(void *actor) { observe_actor(1,original_actor_late,actor,(uint32_t)(uintptr_t)__builtin_return_address(0)); }
static void actor_parent_hook(void *actor) { observe_actor(3,original_actor_parent,actor,(uint32_t)(uintptr_t)__builtin_return_address(0)); }
static void actor_update_hook(void *actor) { observe_actor(4,original_actor_update,actor,(uint32_t)(uintptr_t)__builtin_return_address(0)); }
int shooter_observer_fire_begin(ShooterObservationScope *scope,void *actor,const char *weapon,int mode,void *out1,void *out2,uint32_t caller) {
    if (!clonewars_shooter_observer_enabled) return 0;
    if (active_scope) ++active_scope->record.child_fire_count;
    begin(scope,2,actor,caller);ShooterObservation *r=&scope->record;
    r->arguments_local[0]=(uint32_t)(uintptr_t)actor;r->arguments_local[1]=(uint32_t)(uintptr_t)weapon;
    r->arguments_local[2]=(uint32_t)mode;r->arguments_local[3]=(uint32_t)(uintptr_t)out1;r->arguments_local[4]=(uint32_t)(uintptr_t)out2;
    int8_t value=-1;r->weapon_valid=read_local((uint32_t)(uintptr_t)weapon,&value,1);r->weapon=(uint32_t)(int32_t)value;return 1;
}
void shooter_observer_fire_end(ShooterObservationScope *scope) { finish(scope); }
int shooter_observer_install(void) {
#ifdef SHOOTER_OBSERVER_TEST
    return original_actor_late && original_actor_parent && original_actor_update;
#else
    const uintptr_t entries[]={0x9b5190,0x9bb240,0x9b5ce0};
    const unsigned sizes[]={8,5,6};
    static const unsigned char prefixes[3][8]={{0x53,0x55,0x8b,0x2d,0x20,0x4a,0xfb,0x00},{0x83,0xec,0x18,0xd9,0xe8},{0x55,0x8b,0xec,0x83,0xe4,0xf0}};
    void *hooks[]={(void *)actor_late_hook,(void *)actor_parent_hook,(void *)actor_update_hook};
    for (unsigned i=0;i<3;++i) if (memcmp((void *)entries[i],prefixes[i],sizes[i])) { clonewars_shooter_observer_installed=-1;return 0; }
    for (unsigned i=0;i<3;++i) {
        unsigned char *entry=(unsigned char *)entries[i];unsigned size=sizes[i];DWORD old;
        unsigned char *bridge=VirtualAlloc(NULL,size+5,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
        if (!bridge || !VirtualProtect(entry,size,PAGE_EXECUTE_READWRITE,&old)) { clonewars_shooter_observer_installed=-1;return 0; }
        memcpy(bridge,entry,size);bridge[size]=0xe9;*(int32_t *)(bridge+size+1)=(int32_t)((uintptr_t)entry+size-(uintptr_t)bridge-size-5);
        if (i==2) original_actor_update=(ActorLate)bridge;else if (i==1) original_actor_parent=(ActorLate)bridge;else original_actor_late=(ActorLate)bridge;
        FlushInstructionCache(GetCurrentProcess(),bridge,size+5);
        entry[0]=0xe9;*(int32_t *)(entry+1)=(int32_t)((uintptr_t)hooks[i]-(uintptr_t)entry-5);memset(entry+5,0x90,size-5);
        FlushInstructionCache(GetCurrentProcess(),entry,size);VirtualProtect(entry,size,old,&old);
        InterlockedOr(&clonewars_shooter_observer_installed,1<<i);
    }
    return 1;
#endif
}

void shooter_observer_fire_abort(ShooterObservationScope *scope) {
    if (active_scope==scope) active_scope=scope->previous;
}
