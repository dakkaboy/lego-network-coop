#pragma once
#include "../net/sync_wire.h"
typedef struct EntityKey {
    uint32_t generation,spawn_tag;
    int32_t character;
    SyncSpawnSource spawn_source;
} EntityKey;
int entity_match_unique(const EntityKey *wanted,const EntityKey *available,const unsigned char *claimed,unsigned count);
