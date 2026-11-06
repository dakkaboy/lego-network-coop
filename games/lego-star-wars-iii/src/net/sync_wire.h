#pragma once
#include <stdint.h>
#define SYNC_MAX_ACTORS 4096
#define SYNC_MAX_VARIABLES 1024
#define SYNC_MAX_SHOTS 128
#define SYNC_MAX_PROJECTILES 512
#define SYNC_MAX_TAGS 16
#define SYNC_MAX_SPAWN_TIMERS 192
#define SYNC_QUEUE_SIZE 64
#define SYNC_PROFILE_BYTES 0xb5c0
#define SYNC_LAYOUT_VERSION 31
#define SYNC_WIRE_VERSION 32
#define SYNC_NATIVE_SPAN_PLAN_MASK 7u
#define SYNC_NATIVE_SPAN_MAIN_CALL 1u
#define SYNC_NATIVE_SPAN_OPTIONAL_CALL 2u
#define SYNC_NATIVE_SPAN_CALLS_MASK 3u
#define SYNC_FIRE_TASK_QUEUES_SHOT 0x40u
#ifdef STEERING_TRACE_ONLY
#define SYNC_PROTOCOL_VERSION (SYNC_WIRE_VERSION|128)
#else
#define SYNC_PROTOCOL_VERSION SYNC_WIRE_VERSION
#endif

typedef struct SyncProfile {
    uint32_t epoch;
    uint32_t sequence;
    int32_t level;
    uint32_t checksum;
    uint8_t data[SYNC_PROFILE_BYTES];
} SyncProfile;

typedef struct SyncLoading {
    uint32_t epoch;
    int32_t level;
    uint32_t ready,skip,active;
    float elapsed;
} SyncLoading;
typedef struct SyncInput {
    uint32_t held;
    uint32_t pressed;
    uint8_t analog_x;
    uint8_t analog_y;
    uint8_t aim_x;
    uint8_t aim_y;
} SyncInput;
typedef struct SyncAnimation {
    float frames[5];
    int16_t current;
    uint16_t flags;
    int16_t clips[5];
    uint16_t reserved;
} SyncAnimation;

typedef struct SyncShot {
    uint32_t id;
    int32_t owner,weapon;
    uint32_t owner_generation;
    uint32_t flags;
    float origin[3],transform[16];
    uint32_t phase,clock,rng_game,rng_engine;
    float delta;
} SyncShot;

typedef struct SyncProjectile {
    uint32_t id;
    float transform[32];
    float position[3],previous[3],velocity[3],direction[3],previous_direction[3];
    float flight[14];
    uint32_t flags[3];
} SyncProjectile;

typedef struct SyncTag {
    uint32_t id,parent;
    int32_t from,to;
    uint32_t from_generation,to_generation;
    int32_t arguments[6];
    uint32_t clock,rng_game,rng_engine;
    float delta;
    uint32_t phase;
} SyncTag;

typedef struct SyncActor {
    uint32_t slot;
    uint32_t generation,spawn_tag;
    int32_t player;
    float spawn_position[3];
    int32_t character;
    uint32_t flags;
    float position[3];
    float previous_position[3];
    float render_position[3];
    float previous_render_position[3];
    float velocity[3];
    uint16_t heading;
    uint16_t render_heading;
    int8_t health;
    uint8_t max_health;
    int16_t party_slot;
    uint64_t wallet;
    uint32_t has_wallet;
    SyncAnimation animation;
} SyncActor;

typedef struct SyncVariable {
    char name[32];
    uint32_t scope;
    float value;
} SyncVariable;
typedef struct SyncActorInput {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint32_t held,pressed;
} SyncActorInput;

typedef struct SyncCadence {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint32_t period,phase;
    float elapsed;
} SyncCadence;

typedef struct SyncCollider {
    uint32_t manager_ordinal,slot,generation,spawn_tag;
    int32_t character;
    float origin[3],bounds[6],center[3],extents[2];
} SyncCollider;

typedef struct SyncReactionChoice {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    int32_t old_action,clip;
    uint32_t source_id;
    uint32_t arena_attacker_slot,arena_attacker_generation;
} SyncReactionChoice;

typedef struct SyncModelInputContext {
    uint32_t role_mask,life_54,axis_1dd,provider_190_bit,normalization_mode;
    uint32_t action,substate_2fa,c7c_block,byte_110a,c84_mask,c00_present;
    uint32_t actor_76,actor_1c8_mask,override_c44,override_c48,resource_speed[4];
    uint32_t motion_alternate,resource_d8_bit;
    uint32_t actor_4c_mask,c7c_1000,cf4_raw,model_42,actor_309_mask,global_e63e14_raw,global_fbcb88_raw,global_fc0e80;
    uint32_t numeric_cw,numeric_mxcsr;
} SyncModelInputContext;
typedef struct SyncModelInput {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint32_t native_clock;
    float input_x,input_z;
    uint32_t input_mode,period,phase;
    float elapsed;
    SyncModelInputContext context;
} SyncModelInput;

typedef struct SyncSpawnTimer {
    uint32_t id,type;
    float remaining;
} SyncSpawnTimer;
typedef struct SyncFireTaskGate {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint16_t flags,action;
    uint32_t allowed;
} SyncFireTaskGate;

typedef struct SyncFrame {
    uint32_t epoch;
    uint32_t sequence;
    int32_t level;
    uint32_t clock;
    uint32_t rng_game;
    uint32_t rng_engine;
    uint32_t rng_game_after,rng_engine_after;
    float delta,engine_delta;
    uint32_t engine_mode,world_calls,tick_calls;
    SyncInput inputs[2];
    uint32_t actor_count;
    uint32_t variable_count;
    uint32_t shot_count,projectile_count;
    uint32_t tag_count;
    uint32_t combat_ready;
    uint32_t actor_input_count,actor_input_reserved;
    uint32_t cadence_count,cadence_reserved;
    uint32_t geometry_count,geometry_calls;
    uint32_t reaction_count,reaction_reserved;
    uint32_t model_input_count,model_input_reserved;
    uint32_t checksum;
    uint32_t native_span_plan;
    uint32_t native_span_calls;
    uint32_t spawn_timer_count;
    uint32_t spawn_timer_reserved;
    uint32_t fire_task_gate_count,fire_task_gate_reserved;
    SyncActor actors[SYNC_MAX_ACTORS];
    SyncVariable variables[SYNC_MAX_VARIABLES];
    SyncShot shots[SYNC_MAX_SHOTS];
    SyncProjectile projectiles[SYNC_MAX_PROJECTILES];
    SyncTag tags[SYNC_MAX_TAGS];
    SyncActorInput actor_inputs[SYNC_MAX_ACTORS];
    SyncCadence cadence[SYNC_MAX_ACTORS];
    SyncCollider geometry[SYNC_MAX_ACTORS];
    SyncReactionChoice reactions[SYNC_MAX_ACTORS];
    SyncModelInput model_inputs[SYNC_MAX_ACTORS];
    SyncSpawnTimer spawn_timers[SYNC_MAX_SPAWN_TIMERS];
    SyncFireTaskGate fire_task_gates[SYNC_MAX_ACTORS];
} SyncFrame;
#ifdef __cplusplus
extern "C" {
#endif

int sync_frame_valid(const SyncFrame *frame, uint32_t bytes);
uint32_t sync_frame_size(const SyncFrame *frame);
uint32_t sync_checksum(const void *data,uint32_t size);
int sync_profile_valid(const SyncProfile *profile);
/* Source must be validated. Entries beyond each count are unspecified. */
void sync_frame_copy_valid(SyncFrame *destination, const SyncFrame *source);
uint32_t sync_frame_encode(const SyncFrame *frame,void *buffer,uint32_t capacity);
int sync_frame_decode(SyncFrame *frame,const void *buffer,uint32_t size);

#ifdef __cplusplus
}
#endif
