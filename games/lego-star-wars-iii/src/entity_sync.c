#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <string.h>
#include "entity_sync.h"
#include "entity_match.h"
#include "lan.h"
#include "game_state.h"

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
#ifndef ENTITY_SYNC_API
#define ENTITY_SYNC_API __declspec(dllexport)
#endif
ENTITY_SYNC_API volatile uint32_t clonewars_entity_debug[12];
static int valid(const void *p,SIZE_T size) {
    MEMORY_BASIC_INFORMATION m;
    return p && VirtualQuery(p,&m,sizeof(m)) && m.State==MEM_COMMIT &&
           !(m.Protect&(PAGE_GUARD|PAGE_NOACCESS)) &&
           (uintptr_t)p+size<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static int local_player(int slot) {
    void *actor=pool+slot*0x1440;
    for (int player=0;player<2;++player) if (ENTITY_PLAYER(player)==actor) return player;
    return -1;
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
}
static int raw_slot(const void *actor) {
    uintptr_t offset=(uintptr_t)actor-(uintptr_t)pool;
    return actor && pool && offset%0x1440==0 && offset/0x1440<SYNC_MAX_ACTORS ? (int)(offset/0x1440) : -1;
}
static char *create_hook(void) {
    uintptr_t caller=(uintptr_t)__builtin_return_address(0);
    char *actor=original_create();
    current_pool(); int slot=raw_slot(actor);
    if (slot>=0) {
        LocalEntity *entry=local+slot;
        memset(entry,0,sizeof(*entry));
        entry->key.generation=generation();
        entry->key.spawn_tag=caller>=0x400000 && caller<0x1100000 ? (uint32_t)(caller-0x400000) : 0;
        ++clonewars_entity_debug[0];
    }
    return actor;
}
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
            memset(entry,0,sizeof(*entry)); entry->key.generation=generation();
        }
        if (!entry->origin_ready) {
            entry->model=model;
            entry->key.character=*(short *)(actor+0xdc0);
            memcpy(entry->key.origin,actor+0x24,12);
            entry->origin_ready=1;
        }
    }
}
void entities_describe(SyncActor *state,const void *actor) {
    int slot=raw_slot(actor);
    if (slot<0) return;
    const EntityKey *key=&local[slot].key;
    state->generation=key->generation; state->spawn_tag=key->spawn_tag;
    memcpy(state->spawn_position,key->origin,12);
    state->player=-1; state->party_slot=-1;
    for (int party=0;party<8;++party) if (ENTITY_PLAYER(party)==actor) {
        state->party_slot=(int16_t)party;
        if (party<2) state->player=party;
    }
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
            local[slot].key.character!=state->character || (*(uint32_t *)(pool+slot*0x1440+0x50)&3)!=3) return NULL;
    } else {
        unsigned char unavailable[SYNC_MAX_ACTORS]={0};
        for (int i=0;i<count;++i) {
            keys[i]=local[i].key;
            if ((*(uint32_t *)(pool+i*0x1440+0x50)&3)!=3) keys[i].generation=0;
            if (assigned[i].local_generation==keys[i].generation &&
                (assigned[i].remote_slot!=network_slot || assigned[i].remote_generation!=wanted_generation)) unavailable[i]=1;
        }
        EntityKey key={.generation=wanted_generation,.spawn_tag=state->spawn_tag,.character=state->character};
        memcpy(key.origin,state->spawn_position,12);
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
int entities_party_matches(const SyncFrame *frame) {
    void *desired[8]={0};
    for (uint32_t i=0;i<frame->actor_count;++i) {
        const SyncActor *state=frame->actors+i;
        if (state->party_slot<0) continue;
        if (state->party_slot>=8 || desired[state->party_slot]) return 0;
        desired[state->party_slot]=entities_resolve_identity(frame,state->slot,state->generation);
        if (!desired[state->party_slot]) return 0;
    }
    for (int party=0;party<8;++party) {
        char *actor=ENTITY_PLAYER(party);
        if (actor!=desired[party] || (actor && *(int8_t *)(actor+0x55)!=party)) return 0;
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
int entities_bind(const SyncFrame *frame) {
    entities_update(); int count=game_actor_count();
    unsigned char claimed[SYNC_MAX_ACTORS]={0};
    uint32_t wanted[SYNC_MAX_ACTORS]={0};
    int wanted_player[SYNC_MAX_ACTORS]; memset(wanted_player,0xff,sizeof(wanted_player));
    for (unsigned i=0;i<frame->actor_count;++i) { retire(frame->actors+i); wanted[frame->actors[i].slot]=frame->actors[i].generation; wanted_player[frame->actors[i].slot]=frame->actors[i].player; }
    for (int slot=0;slot<SYNC_MAX_ACTORS;++slot) {
        Binding *b=bindings+slot;
        if (!b->remote_generation || wanted[slot]!=b->remote_generation || b->local_slot<0 || b->local_slot>=count ||
            local[b->local_slot].key.generation!=b->local_generation || local_player(b->local_slot)!=wanted_player[slot] ||
            (*(uint32_t *)(pool+b->local_slot*0x1440+0x50)&3)!=3) {
            memset(b,0,sizeof(*b)); b->local_slot=-1;
        } else claimed[b->local_slot]=1;
    }
    for (int slot=0;slot<count;++slot) {
        keys[slot]=local[slot].key;
        if ((*(uint32_t *)(pool+slot*0x1440+0x50)&3)!=3) keys[slot].generation=0;
    }
    int missing=0;
    for (int pass=0;pass<2;++pass) {
    if (pass) for (int player=0;player<2;++player) {
        int slot=raw_slot(ENTITY_PLAYER(player));
        if (slot>=0 && slot<count) claimed[slot]=1;
    }
    for (unsigned i=0;i<frame->actor_count;++i) {
        if ((frame->actors[i].player<0)!=(pass==1)) continue;
        const SyncActor *state=frame->actors+i; Binding *b=bindings+state->slot;
        if (b->remote_generation && b->local_slot>=0 && keys[b->local_slot].character==state->character) continue;
        if (b->local_slot>=0 && b->local_slot<count) claimed[b->local_slot]=0;
        memset(b,0,sizeof(*b)); b->local_slot=-1;
        int slot=-1;
        const Binding *history=known+state->slot;
        if (state->player>=0) {
            slot=raw_slot(ENTITY_PLAYER(state->player));
            if (slot<0 || slot>=count || !keys[slot].generation || keys[slot].character!=state->character || claimed[slot]) slot=-1;
        } else if (history->remote_generation==state->generation) {
            slot=history->local_slot;
            if (slot<0 || slot>=count || keys[slot].generation!=history->local_generation ||
                keys[slot].character!=state->character || claimed[slot]) slot=-1;
        } else {
            EntityKey key={.generation=state->generation,.spawn_tag=state->spawn_tag,.character=state->character};
            memcpy(key.origin,state->spawn_position,12);
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
    unsigned char *trampoline=VirtualAlloc(NULL,10,MEM_COMMIT|MEM_RESERVE,PAGE_EXECUTE_READWRITE);DWORD old;
    if (!trampoline || !VirtualProtect(target,5,PAGE_EXECUTE_READWRITE,&old)) return 0;
    memcpy(trampoline,target,5); trampoline[5]=0xe9;
    *(int32_t *)(trampoline+6)=(int32_t)((uintptr_t)target+5-(uintptr_t)trampoline-10);
    original_create=(char *(*)(void))trampoline;
    target[0]=0xe9;*(int32_t *)(target+1)=(int32_t)((uintptr_t)create_hook-(uintptr_t)target-5);
    FlushInstructionCache(GetCurrentProcess(),trampoline,10);FlushInstructionCache(GetCurrentProcess(),target,5);
    VirtualProtect(target,5,old,&old);return 1;
}
