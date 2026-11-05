#pragma once
#include <stdint.h>
#include "collision_observer.h"
#define WORLD_CONTACT_ENTRY_CAPACITY 128
#define WORLD_CONTACT_QUERY_CAPACITY 1024
#define WORLD_CONTACT_CANDIDATES 64
typedef struct WorldContactHeader {
    uint32_t committed,id,parent,thread,caller,epoch,sequence,ordinal;
    uint32_t clock,rng_game,rng_engine,qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t clock_after,rng_game_after,rng_engine_after,manager_local,result,arguments[6];
} WorldContactHeader;
typedef struct WorldContactObject {
    uint32_t node_local,pointer_local,raw_valid,raw[88];
} WorldContactObject;
typedef struct WorldContactEntry {
    WorldContactHeader header;
    CollisionShot source_before,source_after;
    uint32_t points_valid,points[9],bounds_valid,bounds[6];
    uint32_t candidate_head,candidate_count,candidate_status,candidate_reserved;
    WorldContactObject candidates[WORLD_CONTACT_CANDIDATES];
} WorldContactEntry;
typedef struct WorldContactQuery {
    WorldContactHeader header;
    CollisionShot source;
    WorldContactObject object;
    uint32_t arguments_valid,context_valid,sample_index,point_local,center_valid,point_valid,center[3],point[3];
} WorldContactQuery;
int world_contact_observer_install(void);
