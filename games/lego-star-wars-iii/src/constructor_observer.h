#pragma once
#include <stdint.h>
#include "sync_wire.h"
#include "coherent_frame_fence.h"
#include "projectile_control.h"
enum ConstructorCapability {CONSTRUCTOR_CAP_NONE,CONSTRUCTOR_CAP_FRAME,CONSTRUCTOR_CAP_CONTROL,CONSTRUCTOR_CAP_REJECTED};
#define CONSTRUCTOR_CAPACITY 512
#define CONSTRUCTOR_OBJECT_WORDS 132
#define CONSTRUCTOR_RAY_WORDS 32
#define CONSTRUCTOR_DESCRIPTOR_WORDS 40
typedef struct ConstructorLease {uint32_t serial,nonce,frame_local,epoch,sequence,frame_valid;} ConstructorLease;
typedef struct ConstructorCall {ConstructorLease lease;const SyncShot *birth;void *manager,*owner;const float *origin,*transform;const char *weapon;uint32_t flags;void *target;uint32_t kind,caller;CoherentFrameToken cohort;RootControlLease control;ProjectileSessionContext control_session;uint64_t reset_generation;uint32_t capability;} ConstructorCall;
typedef struct ConstructorInput {ConstructorLease lease;uint32_t kind,caller,manager_local,owner_local,target_local,birth_known;SyncShot birth;uint32_t origin[3],transform[16],flags,weapon,input_valid,origin_local,transform_local,weapon_local;} ConstructorInput;
typedef struct ConstructorRecord {
 uint32_t committed,id,version,thread,qpc_before[2],qpc_after[2],before[4],after[4];
 ConstructorInput input;
 uint32_t owner_slot,owner_generation,owner_local_generation,owner_character;
 uint32_t returned_local,resource_local,valid,descriptor_local,descriptor_type,resolved_actor_local,resolved_slot,resolved_generation;
 uint32_t wrapper_local,wrapper40,wrapper44,resource20,resource70,resource74;
 uint32_t object_raw[CONSTRUCTOR_OBJECT_WORDS],ray_raw[CONSTRUCTOR_RAY_WORDS],descriptor_raw[CONSTRUCTOR_DESCRIPTOR_WORDS];
 uint32_t query_category,query_normal_raw[3];
} ConstructorRecord;
typedef struct ConstructorScope {uint32_t ready;ConstructorRecord record;CoherentFrameToken cohort;RootControlLease control;ProjectileSessionContext control_session;uint64_t reset_generation;uint32_t capability;} ConstructorScope;
int projectiles_constructor_hooks_ready(void);
int constructor_observer_install(void);
void constructor_observer_begin(ConstructorScope *,const ConstructorCall *);
void constructor_observer_end(ConstructorScope *,void *);
int projectiles_constructor_lease_valid(const ConstructorLease *);

int projectiles_constructor_cohort_valid(const ConstructorLease *,const CoherentFrameToken *);

int projectiles_constructor_control_valid(const ConstructorLease*,const RootControlLease*,const ProjectileSessionContext*,uint64_t);
