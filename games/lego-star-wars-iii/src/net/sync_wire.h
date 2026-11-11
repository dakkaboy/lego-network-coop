#pragma once
#include <stdint.h>
#define SYNC_MAX_ACTORS 4096
#define SYNC_MAX_VARIABLES 1024
#define SYNC_MAX_SHOTS 128
#define SYNC_MAX_PHYSICS_CHOICES 1024
#define SYNC_MAX_TICK_GATES (SYNC_MAX_ACTORS * 2)
#define SYNC_MAX_PROJECTILES 512
#define SYNC_MAX_TAGS 16
#define SYNC_MAX_SPAWN_TIMERS 192
#define SYNC_MAX_RTS_TEAMS 8
#define SYNC_MAX_SPAWN_TIMER_CHOICES (SYNC_MAX_SPAWN_TIMERS + SYNC_MAX_RTS_TEAMS * 4)
#define SYNC_QUEUE_SIZE 64
#define SYNC_PROFILE_BYTES 0xb5c0
#define SYNC_LAYOUT_VERSION 50
#define SYNC_WIRE_VERSION 122
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
typedef struct SyncPreloadInput {
    uint32_t epoch;
    int32_t level;
    uint32_t serial,root_phase;
    uint32_t clock,rng_game,rng_engine,rng_effects;
    float delta,engine_delta;
    uint32_t engine_mode;
} SyncPreloadInput;
#define SYNC_MAX_PRELOAD_FLOW_REQUESTS 64
typedef struct SyncPreloadTrack {
    uint32_t witness[2],time;
} SyncPreloadTrack;
typedef struct SyncPreloadReceipt {
    uint32_t serial,world_calls,end_phase,flow_count;
    uint32_t flow_requests[SYNC_MAX_PRELOAD_FLOW_REQUESTS];
    uint32_t track_count;
    SyncPreloadTrack tracks[SYNC_MAX_PRELOAD_FLOW_REQUESTS];
} SyncPreloadReceipt;
typedef struct SyncWorldReady {
    uint32_t epoch;
    int32_t level;
    uint32_t root_phase,completed_serial;
    uint32_t collider_count,collider_roster;
} SyncWorldReady;
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

typedef struct SyncProjectileSeed {
    float cast_origin[3];
    float age, expires_at, cast_countdown;
} SyncProjectileSeed;

enum SyncShotSource {
    SYNC_SHOT_WEAPON,
    SYNC_SHOT_ACTOR_FOLLOWUP,
    SYNC_SHOT_PROJECTILE_CHILD
};

typedef struct SyncShot {
    uint32_t id;
    int32_t owner,weapon;
    uint32_t owner_generation;
    uint32_t flags;
    float origin[3],transform[16];
    uint32_t phase,clock,rng_game,rng_engine;
    float delta;
    uint32_t has_launch_center;
    float launch_center[3];
    uint32_t has_projectile_seed;
    SyncProjectileSeed projectile_seed;
    uint8_t source, depth;
    uint16_t reserved;
    uint32_t has_launch_motion;
    float launch_motion[3];
} SyncShot;

typedef struct SyncProjectile {
    uint32_t id;
    float transform[32];
    float position[3],previous[3],velocity[3],direction[3],previous_direction[3];
    float flight[14];
    uint32_t flags[3];
    float cast_origin[3];
} SyncProjectile;

typedef struct SyncSpawnSource {
    uint32_t producer,serial;
} SyncSpawnSource;

typedef struct SyncTagIdentity {
    int32_t character;
    uint32_t spawn_tag;
    SyncSpawnSource spawn_source;
} SyncTagIdentity;

enum { SYNC_TAG_UNSCOPED, SYNC_TAG_ACTOR_UPDATE };

typedef struct SyncTag {
    uint32_t id,parent;
    int32_t from,to;
    uint32_t from_generation,to_generation;
    int32_t arguments[6];
    uint32_t clock,rng_game,rng_engine;
    float delta;
    uint32_t phase, source;
    SyncTagIdentity from_identity,to_identity;
} SyncTag;

typedef struct SyncActorBody {
    uint32_t active;
    float position[3],velocity[4];
    float floor_height;
} SyncActorBody;

typedef struct SyncRigidBody {
    uint32_t active,reserved;
    float transform[16];
} SyncRigidBody;

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
    SyncSpawnSource spawn_source;
    SyncActorBody body;
    SyncRigidBody rigid_body;
} SyncActor;

enum SyncVariableScope {
    SYNC_VARIABLE_GLOBAL,
    SYNC_VARIABLE_AREA,
    SYNC_VARIABLE_AREA_DECLARATION
};

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
    SyncSpawnSource spawn_source;
} SyncActorInput;

typedef struct SyncCadence {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint32_t period,phase;
    float elapsed;
    SyncSpawnSource spawn_source;
} SyncCadence;

typedef struct SyncCollider {
    uint32_t manager_ordinal,slot,generation,spawn_tag;
    int32_t character;
    float origin[3],bounds[6],center[3],extents[2];
    SyncSpawnSource spawn_source;
} SyncCollider;

enum SyncReactionKind { SYNC_REACTION_CLIP, SYNC_REACTION_DAMAGE_DRAW, SYNC_REACTION_ITEM_RANGE };
typedef struct SyncItemRange {
    uint32_t target_slot,target_generation;
    uint16_t heading,reverse;
    int16_t animation;
    uint16_t reserved;
    float actor_position[3],target_position[3];
    float actor_radius,target_radius,reach;
} SyncItemRange;
typedef struct SyncReactionChoice {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    int32_t old_action;
    uint32_t kind;
    SyncSpawnSource spawn_source;
    union {
        struct {
            union { int32_t clip; uint32_t damage_draw; };
            uint32_t source_id;
            uint32_t arena_attacker_slot,arena_attacker_generation;
        };
        SyncItemRange range;
    };
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
    SyncSpawnSource spawn_source;
} SyncModelInput;

typedef struct SyncSpawnTimer {
    uint32_t id,type;
    float remaining;
} SyncSpawnTimer;
enum SyncFireGateKind {
    SYNC_FIRE_TASK_VISIBILITY,
    SYNC_FIRE_ATTACK_SUPPORT,
    SYNC_ACTOR_BREAKUP_VISIBILITY,
    SYNC_ACTOR_DEATH_BREAKUP,
    SYNC_ACTOR_FALL_VISIBILITY,
    SYNC_ACTOR_AIM_TASK,
    SYNC_ACTOR_RTS_COMPETITOR,
    SYNC_ACTOR_FORCE_VISIBILITY,
    SYNC_ACTOR_AIM_BASE,
    SYNC_ACTOR_FORCE_GEOMETRY,
    SYNC_ACTOR_SPELLIT_QUERY,
    SYNC_ACTOR_CHARACTER_MOTION,
    SYNC_ACTOR_SPELLIT_NODE,
    SYNC_ACTOR_SCRIPT_SHOOT_VISIBILITY,
    SYNC_ACTOR_PRIMARY_PERCEPTION
};
typedef struct SyncFireTaskState {
    uint32_t repeat;
    float timers[4],target[3],delta;
} SyncFireTaskState;
typedef struct SyncAimTaskState {
    uint32_t target_slot,target_generation,rng_engine,clock;
    float remaining,minimum,maximum;
    uint32_t task_class,reserved;
} SyncAimTaskState;

typedef struct SyncAimBaseState {
    uint32_t rng_engine,rng_game,clock,task_class,callback_class;
    float elapsed,remaining,delta;
    uint32_t reserved;
} SyncAimBaseState;

typedef struct SyncForceQueryState {
    uint32_t caster_slot,caster_generation,mode,clock,reserved[5];
} SyncForceQueryState;

typedef struct SyncForceGeometryState {
    uint32_t caster_slot,caster_generation,mode,clock;
    float caster_position[3],candidate_position[3];
    uint32_t reserved;
} SyncForceGeometryState;

typedef struct SyncSpellItQueryState {
    uint32_t clock,manager_class,caller_site,heading;
    float position[3],limit;
    uint32_t reserved;
} SyncSpellItQueryState;

typedef struct SyncRtsCompetitorState {
    uint32_t rng_game,rng_engine,clock,competitor_class;
    float delta,timers[12];
} SyncRtsCompetitorState;

typedef struct SyncCharacterMotionState {
    uint32_t clock,body_class;
    float velocity[4];
    uint32_t rest_counter;
} SyncCharacterMotionState;

typedef struct SyncSpellItNodeState {
    uint32_t clock,gizmo_class,receiver_class,resource_name[4];
    uint32_t poi_ordinal,poi_count,poi_name,component_class,node_ordinal,gizmo_ordinal;
    float position[3];
    uint32_t reserved;
} SyncSpellItNodeState;

enum { SYNC_SCRIPT_SHOOT_MAX_ARGUMENTS=256 };
typedef struct SyncScriptShootState {
    uint32_t clock,model_class,brain_class,state_class,brain_admission,state_flags;
    uint32_t argument_count,initialize,caller_rva,argument_hash[4],reserved;
} SyncScriptShootState;

typedef struct SyncPrimaryPerceptionState {
    uint32_t clock,target_slot,target_generation,target_tag;
    int32_t target_character;
    SyncSpawnSource target_source;
    float target_origin[3],distance;
    uint32_t target_visible;
} SyncPrimaryPerceptionState;

typedef struct SyncFireTaskGate {
    uint32_t slot,generation,spawn_tag;
    int32_t character;
    float origin[3];
    uint16_t flags,action;
    int32_t value;
    uint32_t kind;
    SyncSpawnSource spawn_source;
    union { uint8_t storage[sizeof(SyncRtsCompetitorState)]; SyncFireTaskState state; SyncAimTaskState aim; SyncRtsCompetitorState competitor; SyncForceQueryState force; SyncAimBaseState aim_base; SyncForceGeometryState force_geometry; SyncSpellItQueryState spellit; SyncCharacterMotionState character_motion; SyncSpellItNodeState spellit_node; SyncScriptShootState script_shoot; SyncPrimaryPerceptionState perception; };
} SyncFireTaskGate;
typedef struct SyncRtsTeamTimers {
    uint32_t slot;
    float remaining[3];
} SyncRtsTeamTimers;
enum SyncSpawnTimerChoiceKind {
    SYNC_SPAWN_TIMER_RTS,
    SYNC_SPAWN_TIMER_MODULE
};
typedef struct SyncSpawnTimerChoice {
    uint32_t kind,owner,selector,serial;
    float remaining;
} SyncSpawnTimerChoice;

enum SyncPhysicsChoiceKind {
    SYNC_PHYSICS_AXIS_SPIN=1, SYNC_PHYSICS_ROTATION_SPIN=2, SYNC_PHYSICS_BREAKUP_LAUNCH=3,
    SYNC_PHYSICS_SPELLIT_SEED=4, SYNC_PHYSICS_SPELLIT_ENTITY=5, SYNC_PHYSICS_SPELLIT_ENABLED=6,
    SYNC_PHYSICS_MODULE_SEED=7, SYNC_PHYSICS_GUN_JAM_SEED=8
};
typedef struct SyncPhysicsWorldInput {
    uint32_t clock,value;
    uint32_t source_name[4],gizmo_class,gizmo_ordinal;
    uint32_t resource_name[4],poi_name[4],poi_ordinal,poi_count,receiver_class,piece_ordinal;
} SyncPhysicsWorldInput;
typedef struct SyncPhysicsModuleInput {
    uint32_t clock,value,module_id,module_type,module_generation,module_class;
    uint32_t burst_min,burst_max,channel_count;
    int32_t weapon;
    float intervals[3];
    uint32_t reserved[7];
} SyncPhysicsModuleInput;
typedef struct SyncPhysicsGunJamInput {
    uint32_t clock,value,module_id,module_type,module_generation;
    uint32_t member_count,candidate_count;
    int32_t clip;
    float remaining,minimum,maximum;
    uint32_t reserved[9];
} SyncPhysicsGunJamInput;
typedef struct SyncPhysicsChoice {
    uint32_t kind,site;
    union {
        struct {
            uint32_t flags,model,clock;
            uint32_t name_hash[2],recipe[6],rng;
        };
        SyncPhysicsWorldInput world;
        SyncPhysicsModuleInput module;
        SyncPhysicsGunJamInput gun_jam;
    };
} SyncPhysicsChoice;

typedef struct SyncTickGate { uint32_t site,clock,value; } SyncTickGate;
typedef struct SyncProjectileRetireRequest {
    uint32_t id,flags;
    int32_t effects;
    uint32_t caller;
} SyncProjectileRetireRequest;
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
    uint32_t rts_team_timer_count,spawn_timer_choice_count;
    uint32_t physics_choice_count,projectile_retire_count;
    uint32_t tick_gate_count,tick_gate_reserved;
    uint16_t dormant_party[8]; /* Zero for no dormant member, otherwise character + 1. */
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
    SyncRtsTeamTimers rts_team_timers[SYNC_MAX_RTS_TEAMS];
    SyncSpawnTimerChoice spawn_timer_choices[SYNC_MAX_SPAWN_TIMER_CHOICES];
    SyncPhysicsChoice physics_choices[SYNC_MAX_PHYSICS_CHOICES];
    SyncTickGate tick_gates[SYNC_MAX_TICK_GATES];
    SyncProjectileRetireRequest projectile_retires[SYNC_MAX_PROJECTILES];
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
