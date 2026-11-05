#pragma once
#include <stdint.h>
#define COMBAT_OBSERVER_CAPACITY 4096
typedef struct CombatActorObservation {
    uint32_t pointer_local,raw_slot,local_generation,network_slot,network_generation,valid;
    int32_t character,health;
    uint32_t flags,life_54,state_2f4,c78,c80,c8c,c94,c98,ca0,invulnerability_d3c,death_de6,handle_142c;
} CombatActorObservation;
typedef struct CombatSourceObservation {
    uint32_t status,id,object_local,resource_local,owner_local;
    int32_t owner,weapon;
    uint32_t owner_generation,flags_160,flags_164,resource_74,damage_4a;
    float position[3];
    uint32_t after_status,origin;
    uint32_t instance_serial,creation_count;
} CombatSourceObservation;
typedef struct CombatObservation {
    uint32_t committed,id,parent,kind,thread,caller,phase;
    uint32_t qpc_before_low,qpc_before_high,qpc_after_low,qpc_after_high;
    uint32_t clock,rng_game,rng_engine,clock_after,rng_game_after,rng_engine_after;
    uint32_t arguments[6],result;
    CombatActorObservation before[2],after[2];
    CombatSourceObservation source;
    uint32_t descriptor_local,descriptor_valid,descriptor_words[11],heading_valid,heading;
    uint32_t native_level,native_phase;
    uint32_t tick_enter_low,tick_enter_high,tick_leave_low,tick_leave_high;
    uint32_t tick_sequence,tick_clock_enter,tick_clock_leave,tick_thread;
    uint32_t frame_queued_low,frame_queued_high,frame_queued_epoch,frame_queued_sequence;
} CombatObservation;
typedef struct CombatObservationScope { CombatObservation record; struct CombatObservationScope *previous; } CombatObservationScope;
int combat_observer_install(void);
void combat_observer_flow(int active);
void combat_observer_removal_ready(void);
void combat_observer_frame_queued(uint32_t epoch,uint32_t sequence);
void combat_observer_projectile_created(void);
void combat_observer_fire_requested(void);
int combat_observer_remove_begin(CombatObservationScope *scope,void *manager,void *object,uint32_t flags,int effects,uint32_t caller);
void combat_observer_remove_end(CombatObservationScope *scope,int removed);

void combat_observer_dispatch(void *dispatcher,void *packet);

uint32_t combat_damage_source_id(void);
int combat_damage_source_ready(void);

void combat_observer_remove_abort(CombatObservationScope *scope);

#ifdef CLONEWARS_HIT_ENTRY_OBSERVER
#include "coherent_frame_fence.h"
uint32_t combat_damage_native_caller(void);
int combat_hit_bridge_attach(const CoherentFrameToken*,void *interposer,void **continuation);
#endif
