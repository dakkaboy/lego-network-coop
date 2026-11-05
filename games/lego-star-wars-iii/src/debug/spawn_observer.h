#pragma once
#include <stdint.h>
#define SPAWN_OBSERVER_CAPACITY 256
#define PRODUCER_OBSERVER_CAPACITY 4096
typedef struct SpawnObservation {
    uint32_t committed,id,parent,thread,caller,phase;
    uint32_t clock,rng_game,rng_engine;
    uint32_t arguments[12];
    float position[3];
    uint32_t position_valid,result,slot,generation,character;
    uint32_t clock_after,rng_game_after,rng_engine_after;
    uint32_t producer_event,producer_transaction;
    char recipe_name[64];
    uint32_t recipe_name_valid;
} SpawnObservation;
typedef struct ProducerObservation {
    uint32_t committed,id,parent,kind,thread,caller,phase;
    uint32_t clock,rng_game,rng_engine;
    uint32_t producer,type_hash,module_id,script_reference,script_id,generation,vtable,base_recipe_pointer;
    char base_recipe_name[64];
    uint32_t arguments[3];
    float position[3];
    uint32_t position_valid,before[4],after[4];
    uint32_t result,clock_after,rng_game_after,rng_engine_after;
    uint32_t native_level,native_phase,area_local;
} ProducerObservation;
int spawn_observer_install(void);
void spawn_observer_flow(int active);
