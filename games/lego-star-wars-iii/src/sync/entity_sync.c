#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "entity_sync.h"
#include "entity_match.h"
#include "native_tick_sync.h"
#include "tag_identity.h"
#include "../net/lan.h"
#include "../engine/game_state.h"
#include "../engine/native_roster_source.h"
#include "../engine/native_hub_source.h"
#include "../engine/native_roster_thunk.h"
#include "../engine/constructor_lexical_seh.h"

#ifdef ENTITY_SYNC_TEST
extern char *entity_test_pool,*entity_test_players[8];
#define ENTITY_POOL entity_test_pool
#define ENTITY_PLAYER(index) entity_test_players[index]
#else
#define ENTITY_POOL (*(char **)0xfb2f60)
#define ENTITY_PLAYER(index) (((char **)0xfb4940)[index])
#endif

typedef struct LocalEntity {
    EntityKey key;
    float origin[3];
    char *model;
    int origin_ready;
} LocalEntity;
typedef struct Binding { uint32_t remote_generation,local_generation; int local_slot; } Binding;
static LocalEntity local[SYNC_MAX_ACTORS];
static EntityKey keys[SYNC_MAX_ACTORS];
static Binding bindings[SYNC_MAX_ACTORS],known[SYNC_MAX_ACTORS];
static struct { uint32_t local_generation,remote_generation,remote_slot; } assigned[SYNC_MAX_ACTORS];
static int inverse[SYNC_MAX_ACTORS];
static char *pool;
static uint32_t birth_counter;
static struct { uint32_t slot,generation; } retired[SYNC_MAX_PROJECTILES];
static unsigned retired_head;
static char *(*original_create)(void);
static __thread EntitySpawnIdentity spawn_context;
typedef struct RosterSpawnScope {
    struct RosterSpawnScope *previous;
    NativeRosterSource source;
    NativeHubSource hub;
    char *created;
    uint32_t generation, allocations;
    int qualified,kind;
} RosterSpawnScope;
typedef struct RosterPending {
    NativeRosterSource source;
    char *actor;
    uint32_t generation;
    int active;
} RosterPending;
static __thread RosterSpawnScope *roster_scope;
static RosterPending roster_pending[NATIVE_SAVED_ROSTER_CAPACITY];
static void finalize_roster_sources(void);
#ifndef ENTITY_SYNC_API
#define ENTITY_SYNC_API __declspec(dllexport)
#endif
ENTITY_SYNC_API volatile uint32_t clonewars_entity_debug[12];
ENTITY_SYNC_API volatile uint32_t clonewars_roster_source_debug[8];
ENTITY_SYNC_API volatile uint32_t clonewars_hub_source_debug[16];
static int valid(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uintptr_t)p+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static uint32_t generation(void) { if (!++birth_counter) ++birth_counter; return birth_counter; }
void entities_reset_bindings(void) {
    memset(bindings,0,sizeof(bindings)); memset(known,0,sizeof(known)); memset(assigned,0,sizeof(assigned));
    memset(retired,0,sizeof(retired)); retired_head=0;
    memset(inverse,0xff,sizeof(inverse));
}
static void current_pool(void) {
    char *now=ENTITY_POOL;
    if (now==pool) return;
    pool=now;
    memset(local,0,sizeof(local)); entities_reset_bindings();
    memset(roster_pending,0,sizeof roster_pending);
}
static int raw_slot(const void *actor) {
    uintptr_t offset=(uintptr_t)actor-(uintptr_t)pool;
    return actor && pool && offset%0x1440==0 && offset/0x1440<SYNC_MAX_ACTORS ? (int)(offset/0x1440) : -1;
}
static char *create_actor(uint32_t site,SyncSpawnSource source) {
    char *actor=original_create();
    current_pool(); int slot=raw_slot(actor);
    if (slot>=0) {
        LocalEntity *entry=local+slot;
        memset(entry,0,sizeof(*entry));
        entry->key.generation=generation();
        entry->key.spawn_tag=site;
        entry->key.spawn_source=source;
        ++clonewars_entity_debug[0];
    }
    return actor;
}
EntitySpawnIdentity entities_set_spawn_context(EntitySpawnIdentity identity) {
    const EntitySpawnIdentity previous=spawn_context;
    spawn_context=identity;
    return previous;
}
static char *create_hook(void) {
    const uintptr_t caller=(uintptr_t)__builtin_return_address(0);
    SyncSpawnSource source={0};
#ifndef ENTITY_SYNC_TEST
    if (caller==0x9c5ce6 && roster_scope && roster_scope->qualified) {
        char *actor=create_actor((uint32_t)(caller-0x400000),(SyncSpawnSource){0});
        if (++roster_scope->allocations==1) {
            roster_scope->created=actor;
            int slot=raw_slot(actor);
            roster_scope->generation=slot>=0?local[slot].key.generation:0;
        }
        return actor;
    }
    if (caller==0x9c5ce6 && spawn_context.source.producer)
        return create_actor(spawn_context.site,spawn_context.source);
    if (caller==0x9c5ef6) {
        const uint32_t party=*(uint32_t *)0xfb4968;
        if (party<8) source=(SyncSpawnSource){1,party};
    }
#endif
    const uint32_t site=caller>=0x400000 && caller<0x1100000 ? (uint32_t)(caller-0x400000) : 0;
    return create_actor(site,source);
}
#ifndef ENTITY_SYNC_TEST
static char *__attribute__((used,noinline)) create_placement(uint32_t descriptor,uint32_t instance) {
    return create_actor(0x9c63b1-0x400000,(SyncSpawnSource){descriptor+1,instance});
}
static char *__attribute__((naked)) create_placement_thunk(void) {
    // The loader keeps the descriptor and copy indices at ESP+14h and ESP+18h before the call.
    __asm__ volatile(
        "pushl 0x1c(%esp)\n\t"
        "pushl 0x1c(%esp)\n\t"
        "call _create_placement\n\t"
        "addl $8, %esp\n\t"
        "ret");
}
#endif
void entities_update(void) {
    current_pool(); int count=game_actor_count();
    if (!valid(pool,(SIZE_T)count*0x1440)) return;
    for (int slot=0;slot<count;++slot) {
        char *actor=pool+slot*0x1440; LocalEntity *entry=local+slot;
        uint32_t flags=*(uint32_t *)(actor+0x50);
        if (!(flags&1)) { memset(entry,0,sizeof(*entry)); continue; }
        if ((flags&3)!=3) continue;
        char *model=*(char **)(actor+8);
        if (!entry->key.generation || (entry->model && entry->model!=model) ||
            (entry->origin_ready && entry->key.character!=*(short *)(actor+0xdc0))) {
            entry->key.generation=generation();
            entry->origin_ready=0;
        }
        if (!entry->origin_ready) {
            entry->model=model;
            entry->key.character=*(short *)(actor+0xdc0);
            memcpy(entry->origin,actor+0x24,sizeof entry->origin);
            entry->origin_ready=1;
        }
    }
    finalize_roster_sources();
}
static void finalize_roster_sources(void) {
#ifndef ENTITY_SYNC_TEST
    for (unsigned i=0;i<NATIVE_SAVED_ROSTER_CAPACITY;++i) {
        RosterPending *pending=roster_pending+i;
        if (!pending->active) continue;
        int slot=raw_slot(pending->actor);
        if (slot<0 || slot>=game_actor_count() || local[slot].key.generation!=pending->generation ||
            !entities_allocation_live(pending->actor,pending->generation)) {
            pending->active=0;++clonewars_roster_source_debug[5];continue;
        }
        if (native_roster_source_revalidate(&pending->source,pending->actor)) {
            local[slot].key.spawn_tag=0x5c5ce6;
            local[slot].key.spawn_source=(SyncSpawnSource){NATIVE_SAVED_ROSTER_PRODUCER,
                ((uint32_t)pending->source.level<<3)|i};
            pending->active=0;++clonewars_roster_source_debug[2];
        } else if (!native_roster_source_revalidate(&pending->source,NULL)) {
            pending->active=0;++clonewars_roster_source_debug[5];
        }
    }
#endif
}

#ifndef ENTITY_SYNC_TEST
typedef char *(__cdecl *RosterConstructor)(uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,
    uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t);
typedef struct RosterConstructorCall {
    RosterSpawnScope scope;
    volatile uint32_t arguments[12];
    unsigned char incoming[512] __attribute__((aligned(16))),outgoing[512] __attribute__((aligned(16)));
    DWORD incoming_error,outgoing_error;
    int linked;
} RosterConstructorCall;
static void __cdecl roster_constructor_abort(void *raw) {
    RosterConstructorCall *call=raw;
    unsigned char fx[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(fx));
    DWORD error=GetLastError();
    if (call->linked && roster_scope==&call->scope) roster_scope=call->scope.previous;
    call->linked=0;
    if(call->scope.kind)++clonewars_hub_source_debug[4];else ++clonewars_roster_source_debug[4];
    SetLastError(error);__asm__ volatile("fxrstor %0"::"m"(fx));
}
static void *__cdecl roster_constructor_invoke(void *raw) {
    RosterConstructorCall *call=raw;
    call->scope.previous=roster_scope;roster_scope=&call->scope;call->linked=1;
    SetLastError(call->incoming_error);__asm__ volatile("fxrstor %0"::"m"(call->incoming));
    char *actor=((RosterConstructor)0x9de240)(call->arguments[0],call->arguments[1],call->arguments[2],
        call->arguments[3],call->arguments[4],call->arguments[5],call->arguments[6],call->arguments[7],
        call->arguments[8],call->arguments[9],call->arguments[10],call->arguments[11]);
    __asm__ volatile("fxsave %0":"=m"(call->outgoing));call->outgoing_error=GetLastError();
    roster_scope=call->scope.previous;call->linked=0;
    if (call->scope.qualified) {
        volatile uint32_t *debug=call->scope.kind?clonewars_hub_source_debug:clonewars_roster_source_debug;
        ++debug[1];
        int slot=raw_slot(actor);
        if (actor && actor==call->scope.created && call->scope.allocations==1 && slot>=0 &&
            local[slot].key.generation==call->scope.generation &&
            (call->scope.kind?native_hub_source_revalidate(&call->scope.hub):native_roster_source_revalidate(&call->scope.source,NULL))) {
            entities_update();
            if (local[slot].key.generation==call->scope.generation &&
                entities_allocation_live(actor,call->scope.generation) &&
                *(int16_t *)(actor+0xdc0)==(int32_t)call->arguments[0] &&
                (call->scope.kind?native_hub_source_revalidate(&call->scope.hub):native_roster_source_revalidate(&call->scope.source,NULL))) {
                if(call->scope.kind){
                    local[slot].key.spawn_tag=0x5c5ce6;
                    local[slot].key.spawn_source=(SyncSpawnSource){call->scope.hub.owner_id,call->scope.hub.serial};
                    ++clonewars_hub_source_debug[2];
                }else{
                    unsigned ordinal=call->scope.source.ordinal;
                    RosterPending *pending=roster_pending+ordinal;
                    if (!pending->active) {
                        *pending=(RosterPending){call->scope.source,actor,call->scope.generation,1};
                        clonewars_roster_source_debug[6]=ordinal;clonewars_roster_source_debug[7]=call->scope.generation;
                    } else ++debug[5];
                }
            } else ++debug[5];
        } else ++debug[5];
    }
    return actor;
}
static char *__attribute__((used,noinline)) entity_roster_constructor(uint32_t *saved) {
    unsigned char incoming[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(incoming));DWORD error=GetLastError();
    RosterConstructorCall call;
    memset(&call,0,sizeof call);memcpy(call.incoming,incoming,sizeof incoming);call.incoming_error=error;
    memcpy((void *)call.arguments,(unsigned char *)saved+40,sizeof call.arguments);
    call.scope.qualified=native_roster_source_resolve((void *)(uintptr_t)saved[1],(const uint32_t *)call.arguments,&call.scope.source);
    ++clonewars_roster_source_debug[0];
    if (!call.scope.qualified) ++clonewars_roster_source_debug[3];
    char *actor=constructor_lexical_seh(&call,roster_constructor_invoke,roster_constructor_abort);
    SetLastError(call.outgoing_error);__asm__ volatile("fxrstor %0"::"m"(call.outgoing));
    return actor;
}
static void *__attribute__((naked)) entity_roster_thunk(void) {
    __asm__ volatile(NATIVE_ROSTER_SOURCE_THUNK_ASM);
}
static char *__attribute__((used,noinline)) entity_hub_constructor(uint32_t *saved) {
    unsigned char incoming[512] __attribute__((aligned(16)));
    __asm__ volatile("fxsave %0":"=m"(incoming));DWORD error=GetLastError();
    RosterConstructorCall call;
    memset(&call,0,sizeof call);memcpy(call.incoming,incoming,sizeof incoming);call.incoming_error=error;
    memcpy((void *)call.arguments,(unsigned char *)saved+40,sizeof call.arguments);call.scope.kind=1;
    uint32_t reason=0;
    call.scope.qualified=native_hub_source_resolve((void *)(uintptr_t)saved[1],(void *)(uintptr_t)saved[2],
        (const uint32_t *)call.arguments,&call.scope.hub,&reason);
    ++clonewars_hub_source_debug[0];clonewars_hub_source_debug[6]=reason;
    clonewars_hub_source_debug[7]=call.scope.hub.owner_id;clonewars_hub_source_debug[8]=(uint32_t)call.scope.hub.level;
    clonewars_hub_source_debug[9]=call.scope.hub.ordinal;clonewars_hub_source_debug[10]=call.scope.hub.manager_id;
    clonewars_hub_source_debug[11]=call.scope.hub.manager_generation;
    clonewars_hub_source_debug[12]=saved[1];clonewars_hub_source_debug[14]=saved[2];
    clonewars_hub_source_debug[13]=valid((void *)(uintptr_t)saved[2],0x18)?*(uint32_t *)(uintptr_t)(saved[2]+8):0;
    clonewars_hub_source_debug[15]=call.arguments[0];
    if(!call.scope.qualified)++clonewars_hub_source_debug[3];
    char *actor=constructor_lexical_seh(&call,roster_constructor_invoke,roster_constructor_abort);
    SetLastError(call.outgoing_error);__asm__ volatile("fxrstor %0"::"m"(call.outgoing));
    return actor;
}
static void *__attribute__((naked)) entity_hub_thunk(void) {
    __asm__ volatile(NATIVE_HUB_SOURCE_THUNK_ASM);
}
#endif
void entities_describe(SyncActor *state,const void *actor) {
    int slot=raw_slot(actor);
    if (slot<0) return;
    EntityKey key=local[slot].key;
    state->generation=key.generation; state->spawn_tag=key.spawn_tag; state->spawn_source=key.spawn_source;
    memcpy(state->spawn_position,local[slot].origin,sizeof state->spawn_position);
    state->player=-1; state->party_slot=-1;
    for (int party=0;party<8;++party) if (ENTITY_PLAYER(party)==actor) {
        state->party_slot=(int16_t)party;
        if (party<2) state->player=party;
    }
}
void entities_note_spawn_source(const void *actor,uint32_t site,SyncSpawnSource source) {
    if (!source.producer) return;
    current_pool();
    const int slot=raw_slot(actor);
    if (slot>=0 && local[slot].key.generation) {
        local[slot].key.spawn_tag=site;
        local[slot].key.spawn_source=source;
    }
}
SyncSpawnSource entities_spawn_source(const void *actor,uint32_t *site) {
    current_pool();
    const int slot=raw_slot(actor);
    if (slot<0 || slot>=game_actor_count() || !local[slot].key.generation)
        return (SyncSpawnSource){0};
    *site=local[slot].key.spawn_tag;
    return local[slot].key.spawn_source;
}
static int reference_matches(const EntityKey *local_key,const SyncActor *state) {
    return local_key->character==state->character &&
        local_key->spawn_source.producer==state->spawn_source.producer &&
        local_key->spawn_source.serial==state->spawn_source.serial &&
        (!state->spawn_source.producer || local_key->spawn_tag==state->spawn_tag);
}
void *entities_resolve_reference(const SyncActor *state) {
    if (!state || state->slot>=SYNC_MAX_ACTORS || !state->generation) return NULL;
    uint32_t network_slot=state->slot,wanted_generation=state->generation;
    entities_update();
    int count=game_actor_count(),slot=-1;
    const Binding *history=known+network_slot;
    if (history->remote_generation==wanted_generation) {
        slot=history->local_slot;
        if (slot<0 || slot>=count || local[slot].key.generation!=history->local_generation ||
            !reference_matches(&local[slot].key,state) || (*(uint32_t *)(pool+slot*0x1440+0x50)&3)!=3) return NULL;
    } else {
        unsigned char unavailable[SYNC_MAX_ACTORS]={0};
        for (int i=0;i<count;++i) {
            keys[i]=local[i].key;
            if ((*(uint32_t *)(pool+i*0x1440+0x50)&3)!=3) keys[i].generation=0;
            if (assigned[i].local_generation==keys[i].generation &&
                (assigned[i].remote_slot!=network_slot || assigned[i].remote_generation!=wanted_generation)) unavailable[i]=1;
        }
        EntityKey key={.generation=wanted_generation,.spawn_tag=state->spawn_tag,.character=state->character,.spawn_source=state->spawn_source};
        slot=entity_match_unique(&key,keys,unavailable,(unsigned)count);
        if (slot<0) return NULL;
    }
    return pool+slot*0x1440;
}
void *entities_resolve_identity(const SyncFrame *frame,uint32_t network_slot,uint32_t wanted_generation) {
    if (network_slot>=SYNC_MAX_ACTORS || !wanted_generation) return NULL;
    const SyncActor *state=NULL;
    for (uint32_t i=0;i<frame->actor_count;++i) if (frame->actors[i].slot==network_slot && frame->actors[i].generation==wanted_generation) {
        state=frame->actors+i; break;
    }
    return entities_resolve_reference(state);
}
static int dormant_party_character(char *actor,int party,int count) {
    if (!actor) return 0;
    const int slot=raw_slot(actor);
    if (slot<0 || slot>=count || !valid(actor,0x1440) || *(int8_t *)(actor+0x55)!=party) return -1;
    const uint32_t flags=*(uint32_t *)(actor+0x50)&3;
    if (flags==3) return 0;
    const int character=*(int16_t *)(actor+0xdc0);
    return flags==1 && character>=0 && character<4096 ? character+1 : -1;
}
int entities_collect_dormant_party(SyncFrame *frame) {
    current_pool();
    const int count=game_actor_count();
    for (int party=0;party<8;++party) {
        const int character=dormant_party_character(ENTITY_PLAYER(party),party,count);
        if (character<0) return 0;
        frame->dormant_party[party]=(uint16_t)character;
    }
    return 1;
}
int entities_party_matches(const SyncFrame *frame) {
    void *desired[8]={0};
    for (uint32_t i=0;i<frame->actor_count;++i) {
        const SyncActor *state=frame->actors+i;
        if (state->party_slot<0) continue;
        if (state->party_slot>=8 || desired[state->party_slot]) return 0;
        desired[state->party_slot]=entities_resolve_identity(frame,state->slot,state->generation);
        if (!desired[state->party_slot]) return 0;
    }
    current_pool();
    const int count=game_actor_count();
    for (int party=0;party<8;++party) {
        char *actor=ENTITY_PLAYER(party);
        if (dormant_party_character(actor,party,count)!=frame->dormant_party[party]) return 0;
        if (!frame->dormant_party[party] && actor!=desired[party]) return 0;
    }
    return 1;
}
int entities_is_retired(uint32_t slot,uint32_t generation) {
    if (!generation) return 0;
    for (unsigned i=0;i<SYNC_MAX_PROJECTILES;++i)
        if (retired[i].slot==slot && retired[i].generation==generation) return 1;
    return 0;
}
static void retire(const SyncActor *state) {
    if (state->player>=0 || state->health!=0 || entities_is_retired(state->slot,state->generation)) return;
    const Binding *previous=known+state->slot;
    if (previous->remote_generation!=state->generation || previous->local_slot<0 || previous->local_slot>=game_actor_count()) return;
    int slot=previous->local_slot;
    if (local[slot].key.generation==previous->local_generation && (*(uint32_t *)(pool+slot*0x1440+0x50)&3)==3) return;
    retired[retired_head].slot=state->slot; retired[retired_head].generation=state->generation;
    retired_head=(retired_head+1)%SYNC_MAX_PROJECTILES;
    ++clonewars_entity_debug[8];
}
static int bind_frame(const SyncFrame *frame,int before_tick) {
    if(before_tick && !native_tick_stream_valid(frame->tick_gates,frame->tick_gate_count))return 0;
    entities_update(); int count=game_actor_count();
    unsigned char claimed[SYNC_MAX_ACTORS]={0};
    uint32_t wanted[SYNC_MAX_ACTORS]={0};
    for (unsigned i=0;i<frame->actor_count;++i) { retire(frame->actors+i); wanted[frame->actors[i].slot]=frame->actors[i].generation; }
    // The post-tick roster can go dormant after native queries have already used its actors.
    for (int party=0;party<8;++party) {
        if (!frame->dormant_party[party]) continue;
        char *actor=ENTITY_PLAYER(party);
        const int local_slot=raw_slot(actor);
        if (local_slot<0 || local_slot>=count) continue;
        const int remote=inverse[local_slot];
        if (remote<0 || remote>=SYNC_MAX_ACTORS || wanted[remote]) continue;
        const Binding *binding=bindings+remote;
        if (binding->local_slot==local_slot && entities_allocation_live(actor,binding->local_generation) &&
            *(int8_t *)(actor+0x55)==party && *(int16_t *)(actor+0xdc0)+1==frame->dormant_party[party])
            wanted[remote]=binding->remote_generation;
    }
    if (frame->tag_count>SYNC_MAX_TAGS) return 0;
    for (unsigned i=0;i<frame->tag_count;++i) {
        const SyncTag *tag=frame->tags+i;
        const int32_t slots[2]={tag->from,tag->to};
        const uint32_t generations[2]={tag->from_generation,tag->to_generation};
        for (unsigned side=0;side<2;++side) {
            int32_t slot=slots[side];uint32_t generation=generations[side];
            if (slot>=0 && slot<SYNC_MAX_ACTORS && generation && (!wanted[slot] || wanted[slot]==generation))
                wanted[slot]=generation;
        }
    }
    if(before_tick)for(uint32_t i=0;i<frame->tick_gate_count;++i) {
        if(frame->tick_gates[i].site!=NATIVE_TICK_WEAPON_COMMAND_ACTOR)continue;
        const uint32_t slot=frame->tick_gates[i].value,generation=frame->tick_gates[i+1].value;
        const Binding *binding=bindings+slot;
        if(binding->remote_generation==generation && binding->local_slot>=0 && binding->local_slot<count &&
           entities_allocation_live(pool+binding->local_slot*0x1440,binding->local_generation))
            wanted[slot]=generation;
        i+=2;
    }
    // PREPARE sees post-tag roles before in-tick Tag replay; that handoff does not retire an allocation.
    for (int slot=0;slot<SYNC_MAX_ACTORS;++slot) {
        Binding *b=bindings+slot;
        if (!b->remote_generation || wanted[slot]!=b->remote_generation || b->local_slot<0 || b->local_slot>=count ||
            local[b->local_slot].key.generation!=b->local_generation ||
            (*(uint32_t *)(pool+b->local_slot*0x1440+0x50)&3)!=3) {
            memset(b,0,sizeof(*b)); b->local_slot=-1;
        } else claimed[b->local_slot]=1;
    }
    for (int slot=0;slot<count;++slot) {
        keys[slot]=local[slot].key;
        if ((*(uint32_t *)(pool+slot*0x1440+0x50)&3)!=3) keys[slot].generation=0;
    }
    for (unsigned i=0;i<frame->tag_count;++i) {
        const SyncTag *tag=frame->tags+i;
        const int32_t slots[2]={tag->from,tag->to};
        const uint32_t generations[2]={tag->from_generation,tag->to_generation};
        const SyncTagIdentity *identities[2]={&tag->from_identity,&tag->to_identity};
        for (unsigned side=0;side<2;++side) {
            SyncActor reference;
            if (!tag_identity_reference(&reference,slots[side],generations[side],identities[side]) ||
                wanted[reference.slot]!=reference.generation) continue;
            char *actor=entities_resolve_reference(&reference);
            int slot=raw_slot(actor);
            if (slot<0 || slot>=count || !keys[slot].generation || !reference_matches(&keys[slot],&reference)) continue;
            Binding *binding=bindings+reference.slot;
            if (claimed[slot] && (binding->local_slot!=slot || binding->local_generation!=keys[slot].generation ||
                binding->remote_generation!=reference.generation)) continue;
            if (assigned[slot].local_generation==keys[slot].generation &&
                (assigned[slot].remote_slot!=reference.slot || assigned[slot].remote_generation!=reference.generation)) continue;
            *binding=(Binding){reference.generation,keys[slot].generation,slot};
            known[reference.slot]=*binding;
            assigned[slot].local_generation=keys[slot].generation;
            assigned[slot].remote_generation=reference.generation;assigned[slot].remote_slot=reference.slot;
            claimed[slot]=1;
        }
    }
    const int initial_party=frame->sequence==1;
    const int native_party_count=initial_party ? 8 : 2;
    int missing=0;
    for (int pass=0;pass<2;++pass) {
    if (pass) for (int party=0;party<native_party_count;++party) {
        int slot=raw_slot(ENTITY_PLAYER(party));
        if (slot>=0 && slot<count) claimed[slot]=1;
    }
    for (unsigned i=0;i<frame->actor_count;++i) {
        const SyncActor *state=frame->actors+i;
        // The last native command precedes retirement or reuse represented by the post-tick roster.
        if(before_tick && wanted[state->slot] && wanted[state->slot]!=state->generation)continue;
        const int native_party=initial_party && state->party_slot>=2 ? state->party_slot : state->player;
        if ((native_party<0)!=(pass==1)) continue;
        Binding *b=bindings+state->slot;
        if (b->remote_generation && b->local_slot>=0 && reference_matches(&keys[b->local_slot],state)) continue;
        if (b->local_slot>=0 && b->local_slot<count) claimed[b->local_slot]=0;
        memset(b,0,sizeof(*b)); b->local_slot=-1;
        int slot=-1;
        const Binding *history=known+state->slot;
        if (native_party>=0 && native_party<native_party_count) {
            slot=raw_slot(ENTITY_PLAYER(native_party));
            if (slot<0 || slot>=count || !keys[slot].generation || !reference_matches(&keys[slot],state) || claimed[slot]) slot=-1;
            // Uncontrolled party members can start at different positions before formation settles.
            if (slot>=0 && native_party>=2 &&
                (keys[slot].spawn_tag!=state->spawn_tag || *(int8_t *)(pool+slot*0x1440+0x55)!=native_party)) slot=-1;
        } else if (history->remote_generation==state->generation) {
            slot=history->local_slot;
            if (slot<0 || slot>=count || keys[slot].generation!=history->local_generation ||
                !reference_matches(&keys[slot],state) || claimed[slot]) slot=-1;
        } else {
            EntityKey key={.generation=state->generation,.spawn_tag=state->spawn_tag,.character=state->character,.spawn_source=state->spawn_source};
            unsigned char unavailable[SYNC_MAX_ACTORS];memcpy(unavailable,claimed,sizeof(unavailable));
            for (int candidate=0;candidate<count;++candidate)
                if (assigned[candidate].local_generation==keys[candidate].generation &&
                    (assigned[candidate].remote_generation!=state->generation || assigned[candidate].remote_slot!=state->slot)) unavailable[candidate]=1;
            slot=entity_match_unique(&key,keys,unavailable,(unsigned)count);
        }
        if (slot>=0 && history->remote_generation==state->generation &&
            (history->local_slot!=slot || history->local_generation!=keys[slot].generation)) slot=-1;
        if (slot>=0 && assigned[slot].local_generation==keys[slot].generation &&
            (assigned[slot].remote_generation!=state->generation || assigned[slot].remote_slot!=state->slot)) slot=-1;
        if (slot<0 && state->player<0 && state->health==0 && entities_is_retired(state->slot,state->generation)) continue;
        if (slot<0) {
            missing=1;clonewars_entity_debug[2]=state->slot;clonewars_entity_debug[3]=(uint32_t)slot;
            continue;
        }
        b->remote_generation=state->generation; b->local_generation=keys[slot].generation; b->local_slot=slot;
        known[state->slot]=*b;
        assigned[slot].local_generation=b->local_generation; assigned[slot].remote_generation=state->generation; assigned[slot].remote_slot=state->slot;
        claimed[slot]=1;
        if ((unsigned)slot!=state->slot) ++clonewars_entity_debug[1];
    }
    }
    memset(inverse,0xff,sizeof(inverse));
    for (int slot=0;slot<SYNC_MAX_ACTORS;++slot) {
        Binding *b=bindings+slot;
        if (b->remote_generation && b->local_slot>=0) inverse[b->local_slot]=slot;
    }
    clonewars_entity_debug[4]=missing;
    clonewars_entity_debug[5]=(uint32_t)(uintptr_t)local;
    clonewars_entity_debug[6]=sizeof(LocalEntity);
    clonewars_entity_debug[7]=(uint32_t)(uintptr_t)bindings;
    return !missing;
}
int entities_bind(const SyncFrame *frame) {return bind_frame(frame,0);}
int entities_bind_tick(const SyncFrame *frame) {return bind_frame(frame,1);}
static int bind_native_actor(const SyncFrame *frame,const void *actor) {
    if(!frame || frame->actor_count>SYNC_MAX_ACTORS || lan_is_host())return 0;
    entities_update();const int slot=raw_slot(actor);
    if(slot<0 || slot>=game_actor_count() || !entities_allocation_live(actor,local[slot].key.generation))return 0;
    const int remote=inverse[slot];
    if(remote>=0 && remote<SYNC_MAX_ACTORS && bindings[remote].local_generation==local[slot].key.generation)return 1;
    if(!local[slot].key.spawn_source.producer)return 0;
    const SyncActor *match=NULL;
    for(uint32_t i=0;i<frame->actor_count;++i) {
        const SyncActor *state=frame->actors+i;
        if(!reference_matches(&local[slot].key,state))continue;
        if(match || state->slot>=SYNC_MAX_ACTORS || !state->generation)return 0;
        match=state;
    }
    if(!match || (assigned[slot].local_generation==local[slot].key.generation &&
       (assigned[slot].remote_slot!=match->slot || assigned[slot].remote_generation!=match->generation)))return 0;
    for(int other=0;other<game_actor_count();++other)
        if(other!=slot && reference_matches(&local[other].key,match) &&
           entities_allocation_live(pool+other*0x1440,local[other].key.generation))return 0;
    const Binding *previous=bindings+match->slot;
    if(previous->remote_generation && previous->local_slot!=slot && previous->local_slot>=0 &&
       previous->local_slot<game_actor_count() &&
       entities_allocation_live(pool+previous->local_slot*0x1440,previous->local_generation))return 0;
    Binding value={match->generation,local[slot].key.generation,slot};
    bindings[match->slot]=known[match->slot]=value;inverse[slot]=(int)match->slot;
    assigned[slot].local_generation=value.local_generation;assigned[slot].remote_slot=match->slot;
    assigned[slot].remote_generation=match->generation;return 1;
}
int entities_bind_native_actor(const SyncFrame *frame,const void *actor) {
    const DWORD error=GetLastError();const int result=bind_native_actor(frame,actor);SetLastError(error);return result;
}
void *entities_actor(uint32_t network_slot,uint32_t wanted_generation) {
    if (network_slot>=SYNC_MAX_ACTORS) return NULL;
    int slot=lan_is_host() ? (int)network_slot : bindings[network_slot].local_slot;
    if (slot<0 || slot>=game_actor_count() || !valid(pool+slot*0x1440,0x1440)) return NULL;
    if (!lan_is_host() && (!bindings[network_slot].remote_generation || bindings[network_slot].remote_generation!=wanted_generation || local[slot].key.generation!=bindings[network_slot].local_generation)) return NULL;
    if (lan_is_host() && local[slot].key.generation!=wanted_generation) return NULL;
    return pool+slot*0x1440;
}
int entities_allocation_live(const void *actor,uint32_t generation) {
    if (!generation || ENTITY_POOL!=pool) return 0;
    int slot=raw_slot(actor);
    if (slot<0 || slot>=game_actor_count() || !valid(actor,0x1440)) return 0;
    const char *p=actor;const LocalEntity *entry=local+slot;
    return entry->origin_ready && entry->key.generation==generation &&
        (*(const uint32_t *)(p+0x50)&3)==3 && entry->model==*(char *const *)(p+8) &&
        entry->key.character==*(const int16_t *)(p+0xdc0);
}
uint32_t entities_local_generation(const void *actor) {
    entities_update(); int slot=raw_slot(actor);
    return slot>=0 ? local[slot].key.generation : 0;
}
uint32_t entities_observed_generation(const void *actor) {
    int slot=raw_slot(actor);
    return slot>=0 ? local[slot].key.generation : 0;
}
int entities_observed_identity(const void *actor,uint32_t *network_slot,uint32_t *network_generation) {
    *network_slot=UINT32_MAX; *network_generation=0;
    int slot=raw_slot(actor);
    if (slot<0 || !local[slot].key.generation) return 0;
    if (lan_is_host()) { *network_slot=(uint32_t)slot; *network_generation=local[slot].key.generation; return 1; }
    int remote=inverse[slot];
    if (remote<0 || remote>=SYNC_MAX_ACTORS || bindings[remote].local_generation!=local[slot].key.generation || !bindings[remote].remote_generation) return 0;
    *network_slot=(uint32_t)remote; *network_generation=bindings[remote].remote_generation; return 1;
}
uint32_t entities_generation(const void *actor) {
    int slot=raw_slot(actor);
    if (slot<0) return 0;
    if (lan_is_host()) return local[slot].key.generation;
    int remote=inverse[slot];
    return remote>=0 && bindings[remote].local_generation==local[slot].key.generation ? bindings[remote].remote_generation : 0;
}
int entities_slot(const void *actor) {
    current_pool();int slot=raw_slot(actor);
    if (slot<0) return -1;
    return lan_is_host() ? slot : inverse[slot];
}
int entities_install(void) {
    unsigned char *target=(unsigned char *)0x7e53d0;
    const unsigned char expected[]={0xa1,0x20,0x4a,0xfb,0x00};
    if (!valid(target,5) || memcmp(target,expected,5)) return 0;
#ifndef ENTITY_SYNC_TEST
    unsigned char *placement=(unsigned char *)0x9c63ac;
    const unsigned char placement_call[]={0xe8,0x1f,0xf0,0xe1,0xff};
    if (!valid(placement,5) || memcmp(placement,placement_call,5)) return 0;
    unsigned char *roster_first=(unsigned char *)0x8afc3a,*roster_second=(unsigned char *)0x8afcbe;
    if (!valid(roster_first,5) || !valid(roster_second,5) || roster_first[0]!=0xe8 || roster_second[0]!=0xe8 ||
        (uintptr_t)(roster_first+5)+*(int32_t *)(roster_first+1)!=0x9de240 ||
        (uintptr_t)(roster_second+5)+*(int32_t *)(roster_second+1)!=0x9de240) return 0;
    unsigned char *hub=(unsigned char *)0x4eed96;
    if(!valid(hub,5)||hub[0]!=0xe8||(uintptr_t)(hub+5)+*(int32_t *)(hub+1)!=0x9de240)return 0;
#endif
    unsigned char *trampoline=VirtualAlloc(NULL,10,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);DWORD old;
    if (!trampoline || !VirtualProtect(target,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
    memcpy(trampoline,target,5); trampoline[5]=0xe9;
    *(int32_t *)(trampoline+6)=(int32_t)((uintptr_t)target+5-(uintptr_t)trampoline-10);
    original_create=(char *(*)(void))trampoline;
    target[0]=0xe9;*(int32_t *)(target+1)=(int32_t)((uintptr_t)create_hook-(uintptr_t)target-5);
    FlushInstructionCache(GetCurrentProcess(),trampoline,10);FlushInstructionCache(GetCurrentProcess(),target,5);
    VirtualProtect(target,5,old,&old);
#ifndef ENTITY_SYNC_TEST
    if (!VirtualProtect(placement,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
    *(int32_t *)(placement+1)=(int32_t)((uintptr_t)create_placement_thunk-(uintptr_t)placement-5);
    FlushInstructionCache(GetCurrentProcess(),placement,5);
    VirtualProtect(placement,5,old,&old);
    if (!VirtualProtect(roster_first,0x89,PAGE_EXECUTE_READWRITE,&old)) return 0;
    *(int32_t *)(roster_first+1)=(int32_t)((uintptr_t)entity_roster_thunk-(uintptr_t)roster_first-5);
    *(int32_t *)(roster_second+1)=(int32_t)((uintptr_t)entity_roster_thunk-(uintptr_t)roster_second-5);
    FlushInstructionCache(GetCurrentProcess(),roster_first,0x89);
    VirtualProtect(roster_first,0x89,old,&old);
    if(!VirtualProtect(hub,5,PAGE_EXECUTE_READWRITE,&old))return 0;
    *(int32_t *)(hub+1)=(int32_t)((uintptr_t)entity_hub_thunk-(uintptr_t)hub-5);
    FlushInstructionCache(GetCurrentProcess(),hub,5);VirtualProtect(hub,5,old,&old);
#endif
    return 1;
}
