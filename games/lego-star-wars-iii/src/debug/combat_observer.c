#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "combat_observer.h"
#include "../sync/projectile_sync.h"
#include "../sync/entity_sync.h"
#include "../sync/game_sync.h"
#include "../sync/reaction_sync.h"
_Static_assert(sizeof(CombatActorObservation)==80,"Combat actor layout");
_Static_assert(sizeof(CombatSourceObservation)==76,"Combat source layout");
_Static_assert(sizeof(CombatObservation)==608,"Combat record layout");
typedef uint32_t (*Hit)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef void (*Death)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef void (__attribute__((thiscall)) *GlobalUpdate)(void *,void *);
typedef struct GlobalObservation {
    uint32_t committed,id,parent,thread,enter_low,enter_high,leave_low,leave_high;
    uint32_t dispatcher_local,packet_local,packet_vtable,packet_zero;
    uint32_t packet_delta_before,packet_delta_after,packet_mode,engine_root_local,engine_delta_before,engine_delta_after;
    uint32_t sequence_before,sequence_after,clock_before,clock_after,births_before,births_after,hits_before,hits_after;
    uint32_t level_before,level_after,phase_before,phase_after;
} GlobalObservation;
_Static_assert(sizeof(GlobalObservation)==120,"Global observer layout");
#define GLOBAL_OBSERVER_CAPACITY 512
static GlobalUpdate original_global=(GlobalUpdate)0x760d80;
extern volatile LONG clonewars_spawn_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_global_observer_installed;
__declspec(dllexport) volatile LONG clonewars_global_observer_count;
__declspec(dllexport) volatile uint32_t clonewars_global_observer_stride=sizeof(GlobalObservation);
__declspec(dllexport) volatile uint32_t clonewars_global_observer_capacity=GLOBAL_OBSERVER_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_global_observer_debug[14];
__declspec(dllexport) volatile GlobalObservation clonewars_global_observer[GLOBAL_OBSERVER_CAPACITY];
static __thread uint32_t global_depth,active_global_id;
static Hit original_hit;
#include "../engine/constructor_lexical_seh.h"
static volatile LONG combat_install_state __attribute__((unused));
#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
#include "../sync/coherent_frame_fence.h"
#include "../net/lan.h"
static Hit native_hit_bridge;
static void *hit_bridge_interposer;
#endif
static Death original_death;
static __thread CombatObservationScope *active_scope;
static __thread int flow_active;
static __thread uint32_t tick_enter_low,tick_enter_high,tick_leave_low,tick_leave_high;
static __thread uint32_t tick_sequence,tick_clock_enter,tick_clock_leave,tick_thread;
static __thread uint32_t queued_low,queued_high,queued_epoch,queued_sequence;
__declspec(dllexport) volatile LONG clonewars_combat_observer_enabled;
__declspec(dllexport) volatile LONG clonewars_combat_observer_installed;
__declspec(dllexport) volatile LONG clonewars_combat_observer_count;
__declspec(dllexport) volatile uint32_t clonewars_combat_observer_stride=sizeof(CombatObservation);
__declspec(dllexport) volatile uint32_t clonewars_combat_observer_capacity=COMBAT_OBSERVER_CAPACITY;
__declspec(dllexport) volatile uint32_t clonewars_combat_observer_install_thread;
__declspec(dllexport) volatile CombatObservation clonewars_combat_observer[COMBAT_OBSERVER_CAPACITY];
#ifdef COMBAT_OBSERVER_TEST
extern int combat_test_read(uint32_t,void *,unsigned);
#define read_local combat_test_read
#else
static int read_local(uint32_t address,void *output,unsigned size) {
    MEMORY_BASIC_INFORMATION region;
    if (!address || !VirtualQuery((void *)(uintptr_t)address,&region,sizeof(region)) ||
        region.State!=MEM_COMMIT || (region.Protect&(PAGE_GUARD|PAGE_NOACCESS)) ||
        (uintptr_t)address+size<(uintptr_t)address ||
        (uintptr_t)address+size>(uintptr_t)region.BaseAddress+region.RegionSize) return 0;
    memcpy(output,(void *)(uintptr_t)address,size);return 1;
}
#endif
static uint32_t word(uint32_t address) { uint32_t value=0;read_local(address,&value,4);return value; }
static uint32_t level_snapshot(void) {
    uint32_t area=word(0xfb4a20),definition=area ? word(area+0x220) : 0;
    int16_t level=-1;if (definition) read_local(definition+0x94,&level,2);return (uint32_t)(int32_t)level;
}
static uint32_t phase_snapshot(void) { uint32_t root=word(0xfb2e60);return root ? word(root+0x1b78) : UINT32_MAX; }
void combat_observer_projectile_created(void) {
    if (!clonewars_combat_observer_enabled) return;
    InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+(global_depth ? 1 : 2)));
    InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+(flow_active ? 12 : 13)));
    if (!global_depth) clonewars_global_observer_debug[5]=GetCurrentThreadId();
}
void combat_observer_fire_requested(void) {
    if (!clonewars_combat_observer_enabled) return;
    InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+(global_depth ? 8 : 9)));
    InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+(flow_active ? 10 : 11)));
    if (!global_depth) clonewars_global_observer_debug[5]=GetCurrentThreadId();
}
static void __attribute__((fastcall)) global_hook(void *dispatcher,void *unused,void *packet) {
    (void)unused;
    if (!clonewars_combat_observer_enabled && !clonewars_spawn_observer_enabled) { original_global(dispatcher,packet);return; }
    GlobalObservation r={0};r.id=(uint32_t)InterlockedIncrement(&clonewars_global_observer_count);
    r.parent=active_global_id;r.thread=GetCurrentThreadId();r.dispatcher_local=(uint32_t)(uintptr_t)dispatcher;r.packet_local=(uint32_t)(uintptr_t)packet;
    r.packet_vtable=word(r.packet_local);r.packet_zero=word(r.packet_local+4);
    r.packet_delta_before=word(r.packet_local+8);r.packet_mode=word(r.packet_local+0xc);
    r.engine_root_local=word(0xfb0afc);r.engine_delta_before=r.engine_root_local ? word(r.engine_root_local+0xe0c) : 0;
    r.sequence_before=game_sync_sequence();r.clock_before=word(0xfb4b6c);r.level_before=level_snapshot();r.phase_before=phase_snapshot();
    r.births_before=clonewars_global_observer_debug[1];r.hits_before=clonewars_global_observer_debug[3];
    if (r.packet_vtable!=0xc37cfc || r.packet_zero) InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+7));
    uint32_t previous=active_global_id;active_global_id=r.id;++global_depth;
    if (global_depth>clonewars_global_observer_debug[6]) clonewars_global_observer_debug[6]=global_depth;
    LARGE_INTEGER counter;QueryPerformanceCounter(&counter);r.enter_low=counter.LowPart;r.enter_high=(uint32_t)counter.HighPart;
    original_global(dispatcher,packet);
    QueryPerformanceCounter(&counter);r.leave_low=counter.LowPart;r.leave_high=(uint32_t)counter.HighPart;
    --global_depth;active_global_id=previous;
    r.packet_delta_after=word(r.packet_local+8);r.engine_delta_after=r.engine_root_local ? word(r.engine_root_local+0xe0c) : 0;
    r.sequence_after=game_sync_sequence();r.clock_after=word(0xfb4b6c);r.level_after=level_snapshot();r.phase_after=phase_snapshot();
    r.births_after=clonewars_global_observer_debug[1];r.hits_after=clonewars_global_observer_debug[3];
    volatile GlobalObservation *out=clonewars_global_observer+(r.id-1)%GLOBAL_OBSERVER_CAPACITY;
    out->committed=0;memcpy((void *)out,&r,sizeof(r));MemoryBarrier();out->committed=r.id;
    InterlockedIncrement((volatile LONG *)clonewars_global_observer_debug);
}
static void actor_snapshot(CombatActorObservation *out,uint32_t pointer) {
    memset(out,0,sizeof(*out));out->pointer_local=pointer;out->raw_slot=out->network_slot=UINT32_MAX;
    if (!pointer) return;
    unsigned char raw[0x1440];
    if (!read_local(pointer,raw,sizeof(raw))) return;
    out->valid=1;out->local_generation=entities_observed_generation((void *)(uintptr_t)pointer);
    entities_observed_identity((void *)(uintptr_t)pointer,&out->network_slot,&out->network_generation);
    uint32_t pool=word(0xfb2f60),count=word(0xfb2e3c),offset=pointer-pool;
    if (pool && offset%0x1440==0 && offset/0x1440<count) out->raw_slot=offset/0x1440;
    int16_t character,state;memcpy(&character,raw+0xdc0,2);memcpy(&state,raw+0x2f4,2);
    out->character=character;out->health=(int8_t)raw[0xdde];out->life_54=raw[0x54];out->death_de6=raw[0xde6];
    out->state_2f4=(uint32_t)(int32_t)state;
    memcpy(&out->flags,raw+0x50,4);memcpy(&out->invulnerability_d3c,raw+0xd3c,4);
    memcpy(&out->c78,raw+0xc78,4);memcpy(&out->c80,raw+0xc80,4);memcpy(&out->c8c,raw+0xc8c,4);
    memcpy(&out->c94,raw+0xc94,4);memcpy(&out->c98,raw+0xc98,4);memcpy(&out->ca0,raw+0xca0,4);
    memcpy(&out->handle_142c,raw+0x142c,4);
}
static void source_snapshot(CombatSourceObservation *out,uint32_t object,uint32_t origin) {
    memset(out,0,sizeof(*out));out->object_local=object;out->origin=origin;out->owner=-1;out->weapon=-1;
    ProjectileIdentityView identity;projectiles_observe_live((void *)(uintptr_t)object,&identity);
    out->status=identity.status;
    if (identity.status!=SHOT_LIVE) return;
    out->id=identity.id;out->resource_local=identity.resource_local;out->owner=identity.owner;
    out->owner_generation=identity.owner_generation;out->weapon=identity.weapon;
    out->instance_serial=identity.instance_serial;out->creation_count=identity.creation_count;
    unsigned char raw[0x210];
    if (!read_local(object,raw,sizeof(raw))) { out->status=SHOT_INVALID;out->id=0;return; }
    uint32_t actual_resource;memcpy(&actual_resource,raw+0x14,4);
    if (actual_resource!=identity.resource_local) { out->status=SHOT_RESOURCE_MISMATCH;out->id=0;return; }
    memcpy(&out->owner_local,raw+0x18,4);memcpy(&out->flags_160,raw+0x160,4);memcpy(&out->flags_164,raw+0x164,4);
    memcpy(out->position,raw+0xa4,12);out->resource_74=word(identity.resource_local+0x74);
    unsigned char damage=0;read_local(identity.resource_local+0x4a,&damage,1);out->damage_4a=damage;
}
static void clock_before(CombatObservation *record) {
    LARGE_INTEGER counter;QueryPerformanceCounter(&counter);
    record->qpc_before_low=counter.LowPart;record->qpc_before_high=(uint32_t)counter.HighPart;
    record->clock=word(0xfb4b6c);record->rng_game=word(0xe637b4);record->rng_engine=word(0xea178c);
    uint32_t area=word(0xfb4a20),definition=area ? word(area+0x220) : 0;
    int16_t level=-1;if (definition) read_local(definition+0x94,&level,2);
    record->native_level=(uint32_t)(int32_t)level;uint32_t root=word(0xfb2e60);
    record->native_phase=root ? word(root+0x1b78) : UINT32_MAX;
    record->tick_enter_low=tick_enter_low;record->tick_enter_high=tick_enter_high;
    record->tick_leave_low=tick_leave_low;record->tick_leave_high=tick_leave_high;
    record->tick_sequence=tick_sequence;record->tick_clock_enter=tick_clock_enter;
    record->tick_clock_leave=tick_clock_leave;record->tick_thread=tick_thread;
    record->frame_queued_low=queued_low;record->frame_queued_high=queued_high;
    record->frame_queued_epoch=queued_epoch;record->frame_queued_sequence=queued_sequence;
}
static void begin(CombatObservationScope *scope,uint32_t kind,uint32_t caller,const uint32_t arguments[6]) {
    memset(scope,0,sizeof(*scope));scope->previous=active_scope;
    CombatObservation *r=&scope->record;
    r->id=(uint32_t)InterlockedIncrement(&clonewars_combat_observer_count);
    if (kind==1) {
        InterlockedIncrement((volatile LONG *)(clonewars_global_observer_debug+(global_depth ? 3 : 4)));
        if (!global_depth) clonewars_global_observer_debug[5]=GetCurrentThreadId();
    }
    r->parent=active_scope ? active_scope->record.id : 0;r->kind=kind;r->caller=caller;
    r->thread=GetCurrentThreadId();r->phase=flow_active ? 0 : 1;
    memcpy(r->arguments,arguments,sizeof(r->arguments));clock_before(r);
    if (kind!=3) {
        actor_snapshot(r->before,kind==1 ? arguments[0] : arguments[2]);
        actor_snapshot(r->before+1,kind==1 ? arguments[1] : arguments[0]);
    }
    uint32_t object=kind==3 ? arguments[1] : word(0xfbcb2c),origin=kind==3 ? 3 : object ? 1 : 0;
    if (!object && active_scope && active_scope->record.source.object_local) { object=active_scope->record.source.object_local;origin=2; }
    source_snapshot(&r->source,object,origin);
    if (kind==2 && arguments[4]) {
        r->descriptor_local=arguments[4];r->descriptor_valid=read_local(arguments[4],r->descriptor_words,sizeof(r->descriptor_words));
        if (r->descriptor_valid && r->descriptor_words[7]) {
            uint16_t heading=0;r->heading_valid=read_local(r->descriptor_words[7],&heading,2);r->heading=heading;
        }
    }
    active_scope=scope;
}
static void finish(CombatObservationScope *scope,uint32_t result) {
    CombatObservation *r=&scope->record;r->result=result;
    if (r->kind!=3) {
        actor_snapshot(r->after,r->kind==1 ? r->arguments[0] : r->arguments[2]);
        actor_snapshot(r->after+1,r->kind==1 ? r->arguments[1] : r->arguments[0]);
    }
    if (r->kind==3 && result) r->source.after_status=SHOT_REMOVED;
    else {
        ProjectileIdentityView view;projectiles_observe_live((void *)(uintptr_t)r->source.object_local,&view);
        r->source.after_status=view.status==SHOT_LIVE && (view.id!=r->source.id || view.instance_serial!=r->source.instance_serial) ? SHOT_REPLACED : view.status;
    }
    r->clock_after=word(0xfb4b6c);r->rng_game_after=word(0xe637b4);r->rng_engine_after=word(0xea178c);
    LARGE_INTEGER counter;QueryPerformanceCounter(&counter);r->qpc_after_low=counter.LowPart;r->qpc_after_high=(uint32_t)counter.HighPart;
    active_scope=scope->previous;
    volatile CombatObservation *destination=clonewars_combat_observer+(r->id-1)%COMBAT_OBSERVER_CAPACITY;
    destination->committed=0;memcpy((void *)destination,r,sizeof(*r));MemoryBarrier();destination->committed=r->id;
}
typedef struct DamageCause { struct DamageCause *previous;uint32_t id,status,caller; } DamageCause;
static __thread DamageCause *active_damage;
uint32_t combat_damage_source_id(void) { return active_damage ? active_damage->id : 0; }
uint32_t combat_damage_native_caller(void) { return active_damage ? active_damage->caller : 0; }
int combat_damage_source_ready(void) { return clonewars_combat_observer_installed>=0&&(clonewars_combat_observer_installed&1)!=0; }
typedef struct HitLexical {DamageCause cause;CombatObservationScope scope;uint32_t args[6],caller,result;int observed;} HitLexical;
static void __cdecl hit_lexical_abort(void*raw){
 DWORD error=GetLastError();HitLexical*c=raw;
 if(c->observed&&active_scope==&c->scope)active_scope=c->scope.previous;
 if(active_damage==&c->cause)active_damage=c->cause.previous;
 SetLastError(error);
}
static void*__cdecl hit_lexical_invoke(void*raw){
 HitLexical*c=raw;ProjectileIdentityView source;
 projectiles_observe_live((void*)(uintptr_t)word(0xfbcb2c),&source);
 /* This native call ignores HIT's return value and retires the shot independently. */
 if(c->caller==0x884e5c && c->args[2]==1 && c->args[4]==0 && c->args[5]==1 &&
    source.status==SHOT_LIVE &&
    reaction_client_duplicate_projectile((void*)(uintptr_t)c->args[1],source.id))return NULL;
 c->cause=(DamageCause){active_damage,source.status==SHOT_LIVE?source.id:0,source.status,c->caller};active_damage=&c->cause;
 if(clonewars_combat_observer_enabled){begin(&c->scope,1,c->caller,c->args);c->observed=1;}
 c->result=original_hit(c->args[0],c->args[1],c->args[2],c->args[3],c->args[4],c->args[5]);
 if(c->observed)finish(&c->scope,c->result);
 active_damage=c->cause.previous;return (void*)(uintptr_t)c->result;
}
static uint32_t hit_hook(uint32_t a0,uint32_t a1,uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5){
 HitLexical c={.args={a0,a1,a2,a3,a4,a5},.caller=(uint32_t)(uintptr_t)__builtin_return_address(0)};
 return (uint32_t)(uintptr_t)constructor_lexical_seh(&c,hit_lexical_invoke,hit_lexical_abort);
}
static void death_hook(uint32_t a0,uint32_t a1,uint32_t a2,uint32_t a3,uint32_t a4,uint32_t a5) {
    if (!clonewars_combat_observer_enabled) { original_death(a0,a1,a2,a3,a4,a5);return; }
    CombatObservationScope scope;uint32_t args[]={a0,a1,a2,a3,a4,a5};
    begin(&scope,2,(uint32_t)(uintptr_t)__builtin_return_address(0),args);
    original_death(a0,a1,a2,a3,a4,a5);finish(&scope,0);
}
int combat_observer_remove_begin(CombatObservationScope *scope,void *manager,void *object,uint32_t flags,int effects,uint32_t caller) {
    if (!clonewars_combat_observer_enabled) return 0;
    uint32_t args[]={(uint32_t)(uintptr_t)manager,(uint32_t)(uintptr_t)object,flags,(uint32_t)effects,0,0};
    begin(scope,3,caller,args);return 1;
}
void combat_observer_remove_end(CombatObservationScope *scope,int removed) { finish(scope,(uint32_t)removed); }
void combat_observer_flow(int active) {
    if (clonewars_combat_observer_enabled) {
        LARGE_INTEGER counter;QueryPerformanceCounter(&counter);
        if (active) {
            tick_enter_low=counter.LowPart;tick_enter_high=(uint32_t)counter.HighPart;
            tick_leave_low=tick_leave_high=tick_clock_leave=0;
            tick_sequence=game_sync_sequence();tick_clock_enter=word(0xfb4b6c);tick_thread=GetCurrentThreadId();
        } else {
            tick_leave_low=counter.LowPart;tick_leave_high=(uint32_t)counter.HighPart;tick_clock_leave=word(0xfb4b6c);
        }
    }
    flow_active=active;
}
void combat_observer_frame_queued(uint32_t epoch,uint32_t sequence) {
    if (!clonewars_combat_observer_enabled) return;
    LARGE_INTEGER counter;QueryPerformanceCounter(&counter);queued_low=counter.LowPart;queued_high=(uint32_t)counter.HighPart;
    queued_epoch=epoch;queued_sequence=sequence;
}
void combat_observer_removal_ready(void) { InterlockedOr(&clonewars_combat_observer_installed,4); }

#ifndef COMBAT_OBSERVER_TEST
__declspec(dllexport) volatile uint32_t clonewars_arena_contact_count;
__declspec(dllexport) volatile uint32_t clonewars_arena_contact[8192][4];
__attribute__((used)) static const uintptr_t arena_contact_resume=0x410cdc;

__attribute__((naked)) static void arena_contact_tap(void) {
    __asm__ volatile(
        "pushfl\n\tpushl %eax\n\tpushl %edx\n\t"
        "movl _clonewars_arena_contact_count,%edx\n\t"
        "andl $8191,%edx\n\tshll $4,%edx\n\t"
        "movl 0xfb4b6c,%eax\n\tmovl %eax,_clonewars_arena_contact+4(%edx)\n\t"
        "movl 0xd3c(%ecx),%eax\n\tmovl %eax,_clonewars_arena_contact+8(%edx)\n\t"
        "movl 0x40(%esi),%eax\n\tmovl %eax,_clonewars_arena_contact+12(%edx)\n\t"
        "movl _clonewars_arena_contact_count,%eax\n\tincl %eax\n\t"
        "movl %eax,_clonewars_arena_contact(%edx)\n\tmovl %eax,_clonewars_arena_contact_count\n\t"
        "popl %edx\n\tpopl %eax\n\tpopfl\n\t"
        "fldz\n\tfcomps 0xd3c(%ecx)\n\tjmp *_arena_contact_resume\n\t");
}

static void arena_contact_install(void) {
    char setting[2];
    if (GetEnvironmentVariableA("CLONEWARS_ARENA_CONTACT_TRACE",setting,sizeof(setting))!=1 ||
        setting[0]!='1') return;
    unsigned char *site=(unsigned char *)0x410cd4;
    const unsigned char prefix[]={0xd9,0xee,0xd8,0x99,0x3c,0x0d,0,0};
    DWORD protection;
    if (memcmp(site,prefix,sizeof(prefix)) ||
        !VirtualProtect(site,sizeof(prefix),PAGE_EXECUTE_READWRITE,&protection)) return;
    int32_t relative=(int32_t)((uintptr_t)arena_contact_tap-(uintptr_t)site-5);
    site[0]=0xe9;
    memcpy(site+1,&relative,sizeof(relative));
    memset(site+5,0x90,sizeof(prefix)-5);
    FlushInstructionCache(GetCurrentProcess(),site,sizeof(prefix));
    VirtualProtect(site,sizeof(prefix),protection,&protection);
}
#endif
int combat_observer_install(void) {
#ifdef COMBAT_OBSERVER_TEST
    return original_hit && original_death;
#else
    LONG state=InterlockedCompareExchange(&combat_install_state,0,0);if(state)return state==1;
    static const unsigned char prefixes[2][6]={{0x55,0x8b,0xec,0x83,0xe4,0xf0},{0x81,0xec,0x80,0,0,0}};
    const uintptr_t addresses[]={0x96a4c0,0x968d60};void*hooks[]={(void*)hit_hook,(void*)death_hook};
    unsigned char*bridges[2]={0};DWORD protections[2]={0};unsigned writable=0;
    for(unsigned i=0;i<2;++i){unsigned char actual[6];if(!read_local((uint32_t)addresses[i],actual,6)||memcmp(actual,prefixes[i],6))goto before_publish;
        bridges[i]=VirtualAlloc(NULL,11,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);if(!bridges[i])goto before_publish;
        memcpy(bridges[i],prefixes[i],6);bridges[i][6]=0xe9;int32_t relative=(int32_t)(addresses[i]+6-(uintptr_t)bridges[i]-11);memcpy(bridges[i]+7,&relative,4);
        if(!FlushInstructionCache(GetCurrentProcess(),bridges[i],11))goto before_publish;
    }
    for(unsigned i=0;i<2;++i){if(!VirtualProtect((void*)addresses[i],6,PAGE_EXECUTE_READWRITE,&protections[i]))goto before_publish;++writable;}
    original_hit=(Hit)bridges[0];original_death=(Death)bridges[1];
#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
    native_hit_bridge=original_hit;
#endif
    clonewars_combat_observer_install_thread=GetCurrentThreadId();
    for(unsigned i=0;i<2;++i){unsigned char*entry=(void*)addresses[i];entry[0]=0xe9;int32_t relative=(int32_t)((uintptr_t)hooks[i]-addresses[i]-5);memcpy(entry+1,&relative,4);entry[5]=0x90;}
    int ok=1;for(unsigned i=0;i<2;++i)if(!FlushInstructionCache(GetCurrentProcess(),(void*)addresses[i],6))ok=0;
    for(unsigned i=2;i;--i){DWORD ignored;if(!VirtualProtect((void*)addresses[i-1],6,protections[i-1],&ignored))ok=0;}
    if(!ok){InterlockedExchange(&clonewars_combat_observer_enabled,0);InterlockedExchange(&clonewars_combat_observer_installed,-1);InterlockedExchange(&combat_install_state,-1);return 0;}
    arena_contact_install();
    InterlockedOr(&clonewars_combat_observer_installed,3);InterlockedExchange(&clonewars_global_observer_installed,1);InterlockedExchange(&combat_install_state,1);return 1;
 before_publish:
    {int restored=1;while(writable){--writable;DWORD ignored;if(!VirtualProtect((void*)addresses[writable],6,protections[writable],&ignored))restored=0;}
     for(unsigned i=0;i<2;++i)if(bridges[i])VirtualFree(bridges[i],0,MEM_RELEASE);
     if(!restored){InterlockedExchange(&clonewars_combat_observer_enabled,0);InterlockedExchange(&clonewars_combat_observer_installed,-1);InterlockedExchange(&combat_install_state,-1);}}
    return 0;
#endif
}

void combat_observer_dispatch(void *dispatcher,void *packet) { global_hook(dispatcher,NULL,packet); }

void combat_observer_remove_abort(CombatObservationScope *scope) {
    if (active_scope==scope) active_scope=scope->previous;
}

#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
int combat_hit_bridge_attach(const CoherentFrameToken*t,void*interposer,void**continuation){
 uint32_t session=lan_session_serial(),thread=GetCurrentThreadId();
 if(!session||!t||!interposer||!continuation||t->thread!=thread||thread!=clonewars_combat_observer_install_thread||
    combat_install_state!=1||(clonewars_combat_observer_installed&3)!=3||!coherent_frame_valid(t,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
 if(!native_hit_bridge)return 0;
 unsigned char entry[6],bridge[11];
 if(!read_local(0x96a4c0,entry,6)||!read_local((uint32_t)(uintptr_t)native_hit_bridge,bridge,11))return 0;
 static const unsigned char prefix[6]={0x55,0x8b,0xec,0x83,0xe4,0xf0};int32_t branch;
 memcpy(&branch,entry+1,4);
 if(entry[0]!=0xe9||entry[5]!=0x90||(uintptr_t)(0x96a4c5u+branch)!=(uintptr_t)hit_hook||memcmp(bridge,prefix,6)||bridge[6]!=0xe9)return 0;
 memcpy(&branch,bridge+7,4);
 if((uint32_t)((uintptr_t)native_hit_bridge+11+branch)!=0x96a4c6u)return 0;
 if(hit_bridge_interposer)return hit_bridge_interposer==interposer&&(void*)original_hit==interposer&&*continuation==(void*)native_hit_bridge;
 if((void*)original_hit!=(void*)native_hit_bridge||lan_session_serial()!=session||!coherent_frame_valid(t,COHERENT_PHASE_BIT(COHERENT_DISPATCH)))return 0;
 *continuation=(void*)native_hit_bridge;MemoryBarrier();
 if(InterlockedCompareExchangePointer((void*volatile*)&original_hit,interposer,(void*)native_hit_bridge)!=(void*)native_hit_bridge)return 0;
 hit_bridge_interposer=interposer;return 1;
}
#endif
