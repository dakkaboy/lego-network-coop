#pragma once
#include <stdint.h>
typedef struct EntityKey {
    uint32_t generation,spawn_tag;
    int32_t character;
    float origin[3];
} EntityKey;
int entity_match_unique(const EntityKey *wanted,const EntityKey *available,const unsigned char *claimed,unsigned count);
