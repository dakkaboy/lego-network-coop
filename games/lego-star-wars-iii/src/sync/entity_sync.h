#pragma once
#include "../net/sync_wire.h"
int entities_install(void);
typedef struct EntitySpawnIdentity {
    uint32_t site;
    SyncSpawnSource source;
} EntitySpawnIdentity;
EntitySpawnIdentity entities_set_spawn_context(EntitySpawnIdentity identity);
void entities_update(void);
void entities_describe(SyncActor *state,const void *actor);
void entities_note_spawn_source(const void *actor,uint32_t site,SyncSpawnSource source);
SyncSpawnSource entities_spawn_source(const void *actor,uint32_t *site);
int entities_bind(const SyncFrame *frame);
void *entities_actor(uint32_t network_slot,uint32_t generation);
uint32_t entities_generation(const void *actor);
int entities_slot(const void *actor);

int entities_is_retired(uint32_t slot,uint32_t generation);

uint32_t entities_local_generation(const void *actor);
uint32_t entities_observed_generation(const void *actor);
int entities_observed_identity(const void *actor,uint32_t *slot,uint32_t *generation);

void entities_reset_bindings(void);
void *entities_resolve_identity(const SyncFrame *frame,uint32_t slot,uint32_t generation);
int entities_collect_dormant_party(SyncFrame *frame);
int entities_party_matches(const SyncFrame *frame);

void *entities_resolve_reference(const SyncActor *state);

int entities_allocation_live(const void *actor,uint32_t generation);
