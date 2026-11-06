#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "spawn_observer.h"
#include "../sync/entity_sync.h"
#include "../sync/game_sync.h"
_Static_assert(sizeof(SpawnObservation)==204,"Spawn observer layout");
_Static_assert(sizeof(ProducerObservation)==224,"Producer observer layout");

typedef void *(*Spawn)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,
                      uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
__declspec(dllexport) volatile LONG clonewars_spawn_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_spawn_observer_count;
__declspec(dllexport) volatile LONG clonewars_spawn_observer_installed;
__declspec(dllexport) volatile DWORD clonewars_spawn_observer_install_thread;
__declspec(dllexport) volatile uint32_t clonewars_spawn_observer_stride=sizeof(SpawnObservation);
__declspec(dllexport) volatile SpawnObservation clonewars_spawn_observer[SPAWN_OBSERVER_CAPACITY];
static Spawn original_spawn;
typedef uint32_t (__attribute__((thiscall)) *Produce)(void *,uint32_t,uint32_t);
typedef void (__attribute__((thiscall)) *ProduceChild)(void *,uint32_t,uint32_t,uint32_t);
typedef unsigned char (__attribute__((thiscall)) *ProduceGroupMember)(void *,uint32_t);
typedef void (*ProduceMount)(void *);
typedef uint32_t (__attribute__((thiscall)) *ProduceCrew)(void *,void *);
typedef void *(__attribute__((thiscall)) *ConstructOrder)(void *,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef void (__attribute__((thiscall)) *ProduceOrder)(void *,uint32_t,uint32_t);
static Produce original_produce;
static ProduceChild original_produce_child;
static ProduceGroupMember original_group_member;
static ProduceMount original_mount;
static ProduceCrew original_crew;
static ConstructOrder original_order_constructor;
static ProduceOrder original_order_spawn;
__declspec(dllexport) volatile LONG clonewars_producer_observer_count;
__declspec(dllexport) volatile LONG clonewars_producer_observer_installed;
__declspec(dllexport) volatile uint32_t clonewars_producer_observer_stride=sizeof(ProducerObservation);
__declspec(dllexport) volatile uint32_t clonewars_producer_observer_capacity=PRODUCER_OBSERVER_CAPACITY;
__declspec(dllexport) volatile ProducerObservation clonewars_producer_observer[PRODUCER_OBSERVER_CAPACITY];
static __thread uint32_t active_observation;
static __thread uint32_t active_producer,active_transaction;
static __thread int flow_active;
static __thread SyncSpawnSource child_source;
static __thread void *mount_rider;
static __thread void *group_birth;
static __thread SyncSpawnSource order_source;
static uint32_t order_area,order_epoch,order_serial_base;

#ifdef SPAWN_OBSERVER_TEST
extern int spawn_test_read(uint32_t,void *,unsigned);
#define read_local spawn_test_read
#else
static int read_local(uint32_t address,void *out,unsigned size) {
    MEMORY_BASIC_INFORMATION region;
    if (!address || !VirtualQuery((void *)(uintptr_t)address,&region,sizeof(region)) ||
        region.State!=MEM_COMMIT || (region.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
        (uintptr_t)address+size<(uintptr_t)address ||
        (uintptr_t)address+size>(uintptr_t)region.BaseAddress+region.RegionSize) return 0;
    memcpy(out,(void *)(uintptr_t)address,size); return 1;
}
#endif
static uint32_t word(uint32_t address) {
    uint32_t value=0; read_local(address,&value,sizeof(value)); return value;
}
static SyncSpawnSource producer_source(uint32_t producer) {
    uint32_t registry_entry[5], serial;
    const uint32_t entry=word(producer+0x68);
    if (!read_local(entry,registry_entry,sizeof registry_entry) ||
        registry_entry[0]!=word(producer+8) || registry_entry[1]!=word(producer+0x6c) ||
        registry_entry[2]!=producer || registry_entry[3]!=4 ||
        !read_local(producer+0x374,&serial,sizeof serial)) return (SyncSpawnSource){0};
    return (SyncSpawnSource){registry_entry[0],serial};
}
static EntitySpawnIdentity spawn_identity(uint32_t caller,uint32_t party) {
    EntitySpawnIdentity identity={.site=caller-0x400000};
    if (caller==0x4df59a || caller==0x47e3df) {
        identity.source=entities_spawn_source(mount_rider,&identity.site);
        const uint32_t branch=caller==0x4df59a ? UINT32_C(0x80000000) : UINT32_C(0x40000000);
        identity.site|=branch;
    } else if (caller==0x5501f4 || caller==0x550729) {
        identity.source=order_source;
    } else if (caller==0x4e2788 || caller==0x4e2a80 || caller==0x4e2aed || caller==0x4e2b57) {
        identity.source=child_source;
    } else if (party<8) {
        identity.source=(SyncSpawnSource){1,party};
    }
    return identity;
}
static void *spawn_native(uint32_t caller,const uint32_t args[12]) {
    const EntitySpawnIdentity previous=entities_set_spawn_context(spawn_identity(caller,args[11]));
    void *actor;
    // Native initialization can create crew before the vehicle's spawn call returns.
    __try {
        actor=original_spawn(args[0],args[1],args[2],args[3],args[4],args[5],
                             args[6],args[7],args[8],args[9],args[10],args[11]);
    } __finally {
        entities_set_spawn_context(previous);
    }
    if (actor && caller==0x4cb8c1) group_birth=actor;
    return actor;
}
void spawn_observer_flow(int active) { flow_active=active; }
static void *spawn_hook(uint32_t a0,uint32_t a1,uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5,
                        uint32_t a6,uint32_t a7,uint32_t a8,uint32_t a9,uint32_t a10,uint32_t a11) {
    const uint32_t caller=(uint32_t)(uintptr_t)__builtin_return_address(0);
    const uint32_t arguments[12]={a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11};
    if (!clonewars_spawn_observer_enabled) return spawn_native(caller,arguments);
    uint32_t id=(uint32_t)InterlockedIncrement(&clonewars_spawn_observer_count);
    SpawnObservation observation={0};
    observation.id=id; observation.parent=active_observation;
    observation.thread=GetCurrentThreadId();
    observation.caller=caller;
    observation.phase=flow_active ? 0 : 1;
    observation.producer_event=active_producer; observation.producer_transaction=active_transaction;
    observation.clock=word(0xfb4b6c); observation.rng_game=word(0xe637b4); observation.rng_engine=word(0xea178c);
    memcpy(observation.arguments,arguments,sizeof(arguments));
    /* Other pointer-capable arguments require native scene identities and stay opaque here. */
    observation.position_valid=read_local(a1,observation.position,sizeof(observation.position));
    if (a3) observation.recipe_name_valid=read_local(a3,observation.recipe_name,sizeof(observation.recipe_name));
    uint32_t previous=active_observation; active_observation=id;
    void *result=spawn_native(caller,arguments);
    active_observation=previous;
    observation.result=(uint32_t)(uintptr_t)result;
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c),pointer=(uint32_t)(uintptr_t)result;
    uint32_t relative=pointer-pool;
    observation.slot=result && pool && relative%0x1440==0 && relative/0x1440<count ? relative/0x1440 : UINT32_MAX;
    observation.generation=entities_observed_generation(result);
    int16_t character=-1;
    if (result) read_local((uint32_t)(uintptr_t)result+0xdc0,&character,sizeof(character));
    observation.character=(uint32_t)(int32_t)character;
    observation.clock_after=word(0xfb4b6c); observation.rng_game_after=word(0xe637b4); observation.rng_engine_after=word(0xea178c);
    volatile SpawnObservation *record=clonewars_spawn_observer+(id-1)%SPAWN_OBSERVER_CAPACITY;
    record->committed=0;
    memcpy((void *)record,&observation,sizeof(observation));
    MemoryBarrier(); record->committed=id;
    return result;
}
static const unsigned producer_counter_offsets[]={0x360,0x374,0x348,0x350};
static void producer_begin(ProducerObservation *record,void *producer,uint32_t kind,uint32_t caller,
                           uint32_t a0,uint32_t a1,uint32_t a2) {
    memset(record,0,sizeof(*record));
    record->id=(uint32_t)InterlockedIncrement(&clonewars_producer_observer_count);
    record->parent=active_producer; record->kind=kind; record->caller=caller;
    record->thread=GetCurrentThreadId(); record->phase=flow_active ? 0 : 1;
    record->clock=word(0xfb4b6c); record->rng_game=word(0xe637b4); record->rng_engine=word(0xea178c);
    record->area_local=word(0xfb4a20);
    uint32_t definition=record->area_local ? word(record->area_local+0x220) : 0;
    int16_t native_level=-1;
    if (definition) read_local(definition+0x94,&native_level,sizeof(native_level));
    record->native_level=(uint32_t)(int32_t)native_level;
    uint32_t root=word(0xfb2e60); record->native_phase=root ? word(root+0x1b78) : UINT32_MAX;
    uint32_t pointer=(uint32_t)(uintptr_t)producer;
    record->producer=pointer; record->vtable=word(pointer);
    record->type_hash=word(pointer+4); record->module_id=word(pointer+8);
    record->script_reference=word(pointer+0x68); record->script_id=word(record->script_reference);
    record->generation=word(pointer+0x6c); record->base_recipe_pointer=word(pointer+0xb0);
    if (record->base_recipe_pointer) read_local(record->base_recipe_pointer,record->base_recipe_name,sizeof(record->base_recipe_name));
    record->arguments[0]=a0; record->arguments[1]=a1; record->arguments[2]=a2;
    if (kind==1) record->position_valid=read_local(a0,record->position,sizeof(record->position));
    for (unsigned i=0;i<4;++i) record->before[i]=word(pointer+producer_counter_offsets[i]);
}
static void producer_finish(ProducerObservation *record,uint32_t result) {
    record->result=result; record->clock_after=word(0xfb4b6c);
    record->rng_game_after=word(0xe637b4); record->rng_engine_after=word(0xea178c);
    for (unsigned i=0;i<4;++i) record->after[i]=word(record->producer+producer_counter_offsets[i]);
    volatile ProducerObservation *destination=clonewars_producer_observer+(record->id-1)%PRODUCER_OBSERVER_CAPACITY;
    destination->committed=0; memcpy((void *)destination,record,sizeof(*record));
    MemoryBarrier(); destination->committed=record->id;
}
static uint32_t __attribute__((fastcall)) produce_hook(void *producer,void *unused,uint32_t count,uint32_t initial) {
    (void)unused;
    if (!clonewars_spawn_observer_enabled) return original_produce(producer,count,initial);
    ProducerObservation record;
    producer_begin(&record,producer,0,(uint32_t)(uintptr_t)__builtin_return_address(0),count,initial,0);
    uint32_t previous=active_producer,transaction=active_transaction;
    active_producer=active_transaction=record.id;
    uint32_t result=original_produce(producer,count,initial);
    active_producer=previous; active_transaction=transaction;
    producer_finish(&record,result); return result;
}
static void __attribute__((fastcall)) produce_child_hook(void *producer,void *unused,uint32_t position,uint32_t yaw,uint32_t aux) {
    (void)unused;
    const int tracing=clonewars_spawn_observer_enabled;
    ProducerObservation record;
    const uint32_t previous=active_producer;
    const SyncSpawnSource previous_child=child_source;
    if (tracing) {
        producer_begin(&record,producer,1,(uint32_t)(uintptr_t)__builtin_return_address(0),position,yaw,aux);
        active_producer=record.id;
    }
    // Companion births share the serial captured before the primary child advances it.
    child_source=producer_source((uint32_t)(uintptr_t)producer);
    __try {
        original_produce_child(producer,position,yaw,aux);
    } __finally {
        child_source=previous_child;
        active_producer=previous;
    }
    if (tracing) producer_finish(&record,0);
}
#ifndef SPAWN_OBSERVER_TEST
static void mount_hook(void *rider) {
    void *previous=mount_rider;
    mount_rider=rider;
    __try {
        original_mount(rider);
    } __finally {
        mount_rider=previous;
    }
}
static uint32_t __attribute__((fastcall)) crew_hook(void *context,void *unused,void *vehicle) {
    (void)unused;
    void *previous=mount_rider;
    uint32_t result;
    mount_rider=vehicle;
    __try {
        result=original_crew(context,vehicle);
    } __finally {
        mount_rider=previous;
    }
    return result;
}
static void *__attribute__((fastcall)) order_constructor_hook(void *order,void *unused,uint32_t a0,uint32_t a1,
                                                              uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5,uint32_t a6) {
    (void)unused;
    const uint32_t area=word(0xfb4a20),epoch=game_sync_epoch();
    if (area!=order_area || epoch!=order_epoch) {
        order_area=area;
        order_epoch=epoch;
        order_serial_base=word(0xcec39c);
    }
    return original_order_constructor(order,a0,a1,a2,a3,a4,a5,a6);
}
static void __attribute__((fastcall)) order_spawn_hook(void *order,void *unused,uint32_t recipe,uint32_t transform) {
    (void)unused;
    const SyncSpawnSource previous=order_source;
    const uint32_t address=(uint32_t)(uintptr_t)order;
    const uint32_t team=word(address+0x80),descriptor=team ? word(team+0x1c) : 0;
    uint32_t team_slot,serial;
    order_source=(SyncSpawnSource){0};
    if (word(team)==0xaef0fc && descriptor && read_local(descriptor+0x30,&team_slot,sizeof team_slot) &&
        team_slot<SYNC_MAX_RTS_TEAMS && read_local(address+0x5e8,&serial,sizeof serial)) {
        // The native serial continues across areas. Normalize it to the area's first order.
        order_source=(SyncSpawnSource){team_slot+1,serial-order_serial_base};
    }
    __try {
        original_order_spawn(order,recipe,transform);
    } __finally {
        order_source=previous;
    }
}
static void note_group_member(uint32_t group,void *actor) {
    uint32_t manager=word(group+0xcc),bank=word(group+0x78);
    const uint32_t groups=word(manager+0x16dc),members=(word(group+0xec)>>24)&0xff;
    if (!manager || !bank || group<manager+0x16e0) return;
    const uint32_t offset=group-manager-0x16e0;
    if (offset%0x140 || offset/0x140>=groups) return;
    for (uint32_t member=0;member<members;++member) {
        if (word(bank+member*0x130+0x11c)!=(uintptr_t)actor) continue;
        entities_note_spawn_source(actor,0x4cb8c1-0x400000,(SyncSpawnSource){offset/0x140+1,member});
        return;
    }
}
static unsigned char __attribute__((fastcall)) group_member_hook(void *group,void *unused,uint32_t party) {
    (void)unused;
    void *previous=group_birth;
    unsigned char result;
    group_birth=NULL;
    __try {
        result=original_group_member(group,party);
        if (result && group_birth) note_group_member((uint32_t)(uintptr_t)group,group_birth);
    } __finally {
        group_birth=previous;
    }
    return result;
}
static void *install_entry(uintptr_t address,const unsigned char *prefix,unsigned size,void *hook) {
    unsigned char *entry=(unsigned char *)address;
    if (memcmp(entry,prefix,size)) return NULL;
    unsigned char *bridge=VirtualAlloc(NULL,size+5,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
    if (!bridge) return NULL;
    memcpy(bridge,prefix,size); bridge[size]=0xe9;
    *(int32_t *)(bridge+size+1)=(int32_t)((uintptr_t)entry-(uintptr_t)bridge-5);
    DWORD protection;
    if (!VirtualProtect(entry,size,PAGE_EXECUTE_READWRITE,&protection)) {
        VirtualFree(bridge,0,MEM_RELEASE);
        return NULL;
    }
    FlushInstructionCache(GetCurrentProcess(),bridge,size+5);
    entry[0]=0xe9; *(int32_t *)(entry+1)=(int32_t)((uintptr_t)hook-(uintptr_t)entry-5);
    memset(entry+5,0x90,size-5); FlushInstructionCache(GetCurrentProcess(),entry,size);
    VirtualProtect(entry,size,protection,&protection);
    return bridge;
}
static int producer_install(void) {
    static const unsigned char high_prefix[]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    static const unsigned char child_prefix[]={0x83,0xec,0x60,0xa1,0xbc,0xd2,0xe8,0x00};
    static const unsigned char group_prefix[]={0x55,0x8b,0xec,0x83,0xe4,0xf0};
    static const unsigned char mount_prefix[]={0x56,0x8b,0x35,0x20,0x4a,0xfb,0x00};
    static const unsigned char crew_prefix[]={0x6a,0xff,0x68,0x5c,0xd8,0xa9,0x00};
    const uintptr_t entries[]={0x4fd8f0,0x4e2730};
    const unsigned sizes[]={sizeof(high_prefix),sizeof(child_prefix)};
    const unsigned char *prefixes[]={high_prefix,child_prefix};
    void *hooks[]={(void *)produce_hook,(void *)produce_child_hook};
    if (memcmp((void *)entries[0],high_prefix,sizeof(high_prefix)) ||
        memcmp((void *)entries[1],child_prefix,sizeof(child_prefix)) ||
        memcmp((void *)0x4cb710,group_prefix,sizeof group_prefix) ||
        memcmp((void *)0x4df470,mount_prefix,sizeof mount_prefix) ||
        memcmp((void *)0x47e1a0,crew_prefix,sizeof crew_prefix) ||
        memcmp((void *)0x556d60,group_prefix,sizeof group_prefix) ||
        memcmp((void *)0x550df0,group_prefix,sizeof group_prefix)) return 0;
    for (unsigned i=0;i<2;++i) {
        void *bridge=install_entry(entries[i],prefixes[i],sizes[i],hooks[i]);
        if (!bridge) return 0;
        if (i) original_produce_child=(ProduceChild)bridge; else original_produce=(Produce)bridge;
        clonewars_producer_observer_installed|=1<<i;
    }
    original_group_member=(ProduceGroupMember)install_entry(0x4cb710,group_prefix,sizeof group_prefix,(void *)group_member_hook);
    original_mount=(ProduceMount)install_entry(0x4df470,mount_prefix,sizeof mount_prefix,(void *)mount_hook);
    original_crew=(ProduceCrew)install_entry(0x47e1a0,crew_prefix,sizeof crew_prefix,(void *)crew_hook);
    original_order_constructor=(ConstructOrder)install_entry(0x556d60,group_prefix,sizeof group_prefix,(void *)order_constructor_hook);
    original_order_spawn=(ProduceOrder)install_entry(0x550df0,group_prefix,sizeof group_prefix,(void *)order_spawn_hook);
    return original_group_member && original_mount && original_crew && original_order_constructor && original_order_spawn;
}
#endif
int spawn_observer_install(void) {
#ifdef SPAWN_OBSERVER_TEST
    return original_spawn!=NULL;
#else
    unsigned char *entry=(unsigned char *)0x9de240;
    static const unsigned char expected[]={0x83,0xec,0x20,0x53,0x55};
    if (memcmp(entry,expected,sizeof(expected))) { clonewars_spawn_observer_installed=-1; return 0; }
    unsigned char *trampoline=VirtualAlloc(NULL,10,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);
    if (!trampoline) { clonewars_spawn_observer_installed=-2; return 0; }
    memcpy(trampoline,entry,5); trampoline[5]=0xe9;
    *(int32_t *)(trampoline+6)=(int32_t)((uintptr_t)entry+5-(uintptr_t)trampoline-10);
    DWORD protection;
    if (!VirtualProtect(entry,5,PAGE_EXECUTE_READWRITE,&protection)) {
        VirtualFree(trampoline,0,MEM_RELEASE); clonewars_spawn_observer_installed=-3; return 0;
    }
    original_spawn=(Spawn)trampoline;
    FlushInstructionCache(GetCurrentProcess(),trampoline,10);
    entry[0]=0xe9; *(int32_t *)(entry+1)=(int32_t)((uintptr_t)spawn_hook-(uintptr_t)entry-5);
    FlushInstructionCache(GetCurrentProcess(),entry,5);
    VirtualProtect(entry,5,protection,&protection);
    clonewars_spawn_observer_install_thread=GetCurrentThreadId(); clonewars_spawn_observer_installed=1;
    return producer_install();
#endif
}
