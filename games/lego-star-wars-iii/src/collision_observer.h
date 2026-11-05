#pragma once
#include <stdint.h>
#define COLLISION_OBSERVER_CAPACITY 1024
#define COLLISION_GEOMETRY_CAPACITY 8192
typedef struct CollisionGeometry {
    uint32_t valid,pointer_local,raw_slot,local_generation,network_slot,network_generation;
    int32_t character,health,state;
    uint32_t flags[8];
    float world[3],bounds[6],center[3],extents[2],invulnerability,elapsed;
    uint32_t model[4],definition[4];
    float facing[3];
    uint32_t life,heading;
} CollisionGeometry;
typedef struct CollisionShot {
    uint32_t status,id;int32_t owner,weapon;
    uint32_t owner_generation,instance_serial,creation_count,pointer_local,resource_local,raw_valid;
    uint32_t raw[132];
} CollisionShot;
typedef struct CollisionObservation {
    uint32_t committed,id,parent,manager_id,manager_ordinal,thread,caller,sequence;
    uint32_t qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t clock,rng_game,rng_engine,clock_after,rng_game_after,rng_engine_after;
    uint32_t manager_local,arguments_local[5],points_valid;
    float points[9];
    uint32_t combat_before,combat_after;
    CollisionGeometry target_before,target_after;
    CollisionShot shot_before,shot_after;
} CollisionObservation;
typedef struct CollisionGeometryObservation {
    uint32_t committed,id,manager_id,manager_ordinal,thread,sequence,clock,clock_after;
    uint32_t qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t rng_game,rng_engine,rng_game_after,rng_engine_after;
    uint32_t manager_local,packet_mode,event_word,ordinal;
    CollisionGeometry before,after;
} CollisionGeometryObservation;
int collision_observer_install(void);
