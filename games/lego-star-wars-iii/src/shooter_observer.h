#pragma once
#include <stdint.h>
#define SHOOTER_OBSERVER_CAPACITY 8192
#define SHOOTER_ACTOR_FIELDS 63
typedef struct ShooterActorObservation {
    uint32_t valid,pointer_local,raw_slot,local_generation,network_slot,network_generation;
    int32_t character;
    uint32_t words[SHOOTER_ACTOR_FIELDS];
    uint32_t controller_local,controller_valid,controller_words[16];
    uint32_t model_local,model_flags29,model_valid,resource24_local,actor100_word0,actor100_valid;
    uint32_t model_active42,model_active42_valid,global_fb32a8;
} ShooterActorObservation;
typedef struct ShooterObservation {
    uint32_t committed,id,parent,kind,thread,caller,sequence;
    uint32_t qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t clock,rng_game,rng_engine,clock_after,rng_game_after,rng_engine_after;
    uint32_t arguments_local[5],weapon_valid,weapon,child_fire_count;
    ShooterActorObservation before,after;
} ShooterObservation;
typedef struct ShooterObservationScope { ShooterObservation record; struct ShooterObservationScope *previous; } ShooterObservationScope;
int shooter_observer_install(void);
int shooter_observer_fire_begin(ShooterObservationScope *scope,void *actor,const char *weapon,int mode,void *out1,void *out2,uint32_t caller);
void shooter_observer_fire_end(ShooterObservationScope *scope);
void shooter_observer_actor_snapshot(ShooterActorObservation *out,void *actor);

void shooter_observer_fire_abort(ShooterObservationScope *scope);
